# Client Godot di Bonobo Game. Come il client web, non decide niente: manda solo i tasti
# premuti (InputState) al server Node e disegna gli snapshot che riceve.
# Server, stanza e nome arrivano dall'indirizzo (?server=...&room=...&name=...) nella versione web,
# o dalla riga di comando (-- --server=... --room=... --name=...) su desktop; altrimenti dalla lobby,
# che parte dall'ultima scelta salvata. ?bot=manichino aggiunge un avversario del server (#20).
extends Node2D

const DEFAULT_SERVER := "http://localhost:3000" # npm run dev
const PRODUCTION_SERVER := "https://bonobo-game.onrender.com" # server fisso (render.yaml, #19): lo usa il gioco esportato
const RECONNECT_MS := 1500 # attesa prima di riprovare a collegarsi
const REMATCH_PAD_BUTTON := JOY_BUTTON_Y # rivincita dal pad: Y è libero finché non arriva la speciale (E10)
const PAGES_URL := "https://nicpanozzo.github.io/bonobo-game/godot/" # dove sta la versione web (pages.yml)

var game: Dictionary
var settings: Settings
var socket := SocketIO.new()
var params := {}
var url_params := {} # solo quelli dell'indirizzo o della riga di comando
var ui_layer := CanvasLayer.new()
var pause_menu: Control
var world: Node2D
var camera := Camera2D.new()
var audio: Node2D
var rumble: Rumble
var hud: Control
var lobby: Control
var title: Control # schermata del titolo (E14)
var connecting: Control # schermata "Mi collego..." (E14), null quando si è dentro
var playing := false
var _last_input := {}
var _retry_at := -1
var _token := "" # segreto del welcome: solo in memoria, vale per la stanza _token_room (#107)
var _token_room := ""
var _lost_at := -1 # ms in cui la connessione è caduta durante la partita, -1 se siamo collegati (#107)
var _attempt := 0 # tentativi di riconnessione da quando è caduta
var _version_warned := false # banner "versione nuova" già mostrato (E2)
var _try_hint := "" # prova del primo avvio (E14): si mostra appena si entra nella stanza
var _last_snapshot := 0 # ms dell'ultimo snapshot: in partita il silenzio dice che la rete è caduta


func _ready() -> void:
	game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	settings = Settings.new(game.audio)
	settings.stick_deadzone = game.input.stickDeadzone
	# Menu col pad (E6): A conferma e B torna indietro, oltre a Invio ed Esc.
	# Le frecce del pad e la levetta muovono già il fuoco (ui_up, ui_down... di Godot)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var e := InputEventJoypadButton.new()
		e.button_index = pair[1]
		e.device = -1 # tutti i pad
		InputMap.action_add_event(pair[0], e)
	url_params = _read_params()
	# Si riparte dall'ultima scelta; l'indirizzo vince
	params = settings.profile.duplicate()
	params.merge(url_params, true)
	# Nel gioco esportato anche un localhost salvato prima del server fisso diventa la produzione
	if not params.has("server") or (params.server == DEFAULT_SERVER and not url_params.has("server")):
		params.server = _default_server()
	world = preload("res://scripts/world_view.gd").new()
	world.setup(game)
	add_child(world)
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	audio = preload("res://scripts/audio.gd").new()
	add_child(audio)
	audio.setup(game)
	rumble = Rumble.new(game.rumble)
	settings.changed.connect(_apply_volumes)
	_apply_volumes()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = game
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	ui_layer.layer = 2 # menu sopra l'HUD
	add_child(ui_layer)
	# Prima volta: nome, comandi e una prova col manichino (E14). Con un link a una stanza si entra e basta
	if not settings.first_run_done and not (url_params.has("room") and url_params.has("name")):
		_show_first_run()
	elif url_params.has("room") and url_params.has("name"):
		_show_lobby() # si entra subito nella stanza, qui sotto
	else:
		_show_title()

	Input.joy_connection_changed.connect(_on_joy_changed)
	socket.connected.connect(_on_connected)
	socket.disconnected.connect(_on_disconnected)
	socket.connect_failed.connect(_on_connect_failed)
	socket.event_received.connect(_on_event)

	# Con stanza e nome nell'indirizzo si entra subito, come nel gioco web
	if url_params.has("room") and url_params.has("name"):
		_join(params)


func _show_lobby() -> void:
	audio.play_music("lobby")
	lobby = preload("res://scripts/lobby.gd").new()
	lobby.theme = UI.theme()
	ui_layer.add_child(lobby)
	lobby.setup(game, params, room_link, url_params.has("room"))
	UI.fade_in(lobby)
	lobby.join_requested.connect(_join)
	lobby.back_requested.connect(func():
		lobby.queue_free()
		_show_title(true))
	lobby.options_requested.connect(func():
		var options := preload("res://scripts/options.gd").new()
		options.theme = UI.theme()
		ui_layer.add_child(options)
		options.setup(settings)
		var scale := Access.text_scale
		options.closed.connect(func():
			if Access.text_scale != scale: # testo più grande o più piccolo: la lobby si rifà con le misure nuove
				lobby.queue_free()
				_show_lobby()
			else:
				lobby.restore_focus()))
	lobby.credits_requested.connect(func():
		var credits := preload("res://scripts/credits.gd").new()
		credits.theme = UI.theme()
		ui_layer.add_child(credits)
		credits.setup()
		credits.closed.connect(lobby.restore_focus))


# Titolo e menu principale (E14): Gioca online porta alla lobby. skip_press: si torna dalla lobby, niente "Premi un tasto"
func _show_title(skip_press := false) -> void:
	audio.play_music("lobby")
	title = preload("res://scripts/title.gd").new()
	title.theme = UI.theme()
	ui_layer.add_child(title)
	title.setup(game, skip_press)
	UI.fade_in(title)
	title.play_requested.connect(func():
		title.queue_free()
		_show_lobby())
	title.options_requested.connect(func():
		var options := preload("res://scripts/options.gd").new()
		options.theme = UI.theme()
		ui_layer.add_child(options)
		options.setup(settings)
		var scale := Access.text_scale
		options.closed.connect(func():
			if Access.text_scale != scale: # testo più grande o più piccolo: il titolo si rifà con le misure nuove
				title.queue_free()
				_show_title(true)
			else:
				title.restore_focus()))
	title.credits_requested.connect(func():
		var credits := preload("res://scripts/credits.gd").new()
		credits.theme = UI.theme()
		ui_layer.add_child(credits)
		credits.setup()
		credits.closed.connect(title.restore_focus))


func _show_first_run() -> void:
	var first := preload("res://scripts/first_run.gd").new()
	first.theme = UI.theme()
	ui_layer.add_child(first)
	first.setup(settings)
	UI.fade_in(first)
	var done := func(player_name: String) -> void:
		settings.first_run_done = true
		settings.profile["name"] = player_name
		params.name = player_name
		first.queue_free()
	first.skipped.connect(func(player_name: String):
		done.call(player_name)
		settings.save()
		_show_lobby())
	first.try_requested.connect(func(player_name: String):
		done.call(player_name)
		# Stanza nuova tutta sua, regole di sempre, con il manichino fermo da colpire (bot.ts, #20)
		_try_hint = "Prova: colpisci il manichino! Esc per tornare alla lobby"
		_join({"name": player_name, "room": "prova-" + str(randi() % 100000), "char": "", "stage": "", "rules": {}, "bot": "manichino"}))


func _join(choice: Dictionary) -> void:
	params.merge(choice, true)
	if params.server == "":
		params.server = _default_server()
	settings.profile = {"name": params.name, "room": params.room, "char": params.get("char", ""), "stage": params.get("stage", ""), "rules": params.get("rules", {}), "server": params.server}
	settings.save()
	_set_url(params.room)
	if is_instance_valid(lobby):
		lobby.queue_free()
	playing = true
	_connect()


# Esce dalla stanza e torna alla lobby (dal menu di pausa)
func _leave() -> void:
	playing = false
	_retry_at = -1
	_lost_at = -1
	_last_snapshot = 0
	socket.close()
	world.reset()
	hud.reset()
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	_hide_connecting()
	_show_lobby()


# Un avviso che sparisce da solo dopo qualche secondo, se nel frattempo non ne è arrivato un altro
func _flash_status(text: String) -> void:
	hud.set_status(text)
	get_tree().create_timer(4.0).timeout.connect(func():
		if hud.status == text:
			hud.set_status(""))


func _apply_volumes() -> void:
	audio.set_volumes(settings.master, settings.sfx, settings.music, settings.music_on, settings.voices)
	rumble.level = settings.rumble
	world.effects = settings.video.effects
	Video.apply(settings)
	Access.apply(game, settings.access)
	if hud != null:
		hud.queue_redraw()


# Il link da mandare agli amici porta la stanza (e il server, se la pagina non sta sul server)
func room_link(room: String) -> String:
	var base := PAGES_URL
	var same_origin := false
	if OS.has_feature("web"):
		base = str(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))
		same_origin = str(JavaScriptBridge.eval("window.location.origin", true)) == params.server
	var link := base + "?room=" + room.uri_encode()
	if not same_origin:
		link += "&server=" + str(params.server).uri_encode()
	return link


# Nella versione web la stanza va nell'indirizzo, così ricaricare la pagina riporta lì
func _set_url(room: String) -> void:
	if not OS.has_feature("web"):
		return
	var query := "?room=" + room.uri_encode()
	if url_params.has("server"):
		query += "&server=" + str(url_params.server).uri_encode()
	JavaScriptBridge.eval("history.replaceState(null, '', %s)" % JSON.stringify(query), true)


func _connect() -> void:
	if _lost_at < 0:
		_show_connecting("Mi collego...", "Stanza %s su %s" % [params.room, params.server])
	var err := socket.connect_to(params.server)
	if err != OK:
		_show_connecting("Non riesco a collegarmi", "%s (%s). Riprovo tra poco." % [params.server, error_string(err)])
		_retry_at = Time.get_ticks_msec() + RECONNECT_MS


func _on_connected() -> void:
	hud.set_status("")
	_last_snapshot = 0
	var data := {"room": params.room, "name": params.name}
	if params.get("stage", "") != "":
		data.stageId = params.stage # conta solo se la stanza è nuova
	if params.get("char", "") != "":
		data.characterId = params.char
	if params.get("rules") is Dictionary and not params.rules.is_empty():
		data.rules = params.rules # contano solo se la stanza è nuova
	if params.get("bot", "") != "":
		data.bot = params.bot
	if _token != "" and _token_room == str(params.room):
		data.token = _token # dopo una caduta di rete: rientra nello stesso lottatore se il posto è tenuto (#107)
	# Versione e protocollo (E2): un protocollo diverso viene rifiutato con refused, una versione diversa no.
	# Per provarlo: -- --version=0.0.1 oppure -- --protocol=99
	data.version = _my_version()
	data.protocol = int(params.get("protocol", game.protocol))
	socket.emit("join", data)
	_last_input = {}


func _my_version() -> String:
	return str(params.get("version", game.version))


# Server con un gioco più nuovo (E2): si avvisa una volta, senza bloccare la partita
func _check_server_version(server_version: String) -> void:
	if _version_warned or server_version == "" or not UI.newer_version(server_version, _my_version()):
		return
	_version_warned = true
	var web := OS.has_feature("web")
	var text := "C'è una versione nuova del gioco (v%s): %s" % [server_version, "ricarica la pagina" if web else "riapri l'app per averla"]
	add_child(UI.banner(text, "Ricarica" if web else "Scarica", func():
		if web:
			JavaScriptBridge.eval("location.reload()")
		else:
			OS.shell_open("https://nicpanozzo.github.io/bonobo-game/#gioca")))


func _on_disconnected() -> void:
	if not playing:
		return
	if _lost_at < 0:
		_lost_at = Time.get_ticks_msec()
		_attempt = 0
	_retry_later()


# Tentativi con attesa crescente (1, 2, 4, 5, 5... s): presto all'inizio, senza martellare dopo (#107)
func _retry_later() -> void:
	var delays: Array = game.reconnect.retryDelaysMs
	_retry_at = Time.get_ticks_msec() + int(delays[mini(_attempt, delays.size() - 1)])
	_attempt += 1
	_show_reconnecting()


# "Riconnessione... tentativo 2, posto tenuto ancora 14 s": quanto manca prima che il server liberi il posto
func _show_reconnecting() -> void:
	var left := ceili((float(game.reconnect.holdMs) - (Time.get_ticks_msec() - _lost_at)) / 1000.0)
	var text := "Tentativo %d" % _attempt
	if left > 0:
		text += ", il tuo posto è tenuto ancora %d s" % left
	_show_connecting("Riconnessione...", text)


# Schermata di collegamento: si crea la prima volta e poi si aggiorna il testo
func _show_connecting(title_text: String, detail := "") -> void:
	if not is_instance_valid(connecting):
		connecting = preload("res://scripts/connecting.gd").new()
		connecting.theme = UI.theme()
		ui_layer.add_child(connecting)
		connecting.setup()
		connecting.cancelled.connect(_leave)
	connecting.show_text(title_text, detail)


func _hide_connecting() -> void:
	if is_instance_valid(connecting):
		connecting.queue_free()
	connecting = null


# Indirizzo sbagliato o server spento: si riprova, ma si dice cosa succede e come uscirne
func _on_connect_failed() -> void:
	if not playing:
		return
	if _lost_at >= 0:
		_retry_later() # la rete non è ancora tornata
		return
	_show_connecting("Il server non risponde", "Non riesco a raggiungere %s: riprovo. Con Annulla torni alla lobby e puoi cambiare server." % params.server)
	_retry_at = Time.get_ticks_msec() + RECONNECT_MS * 2


func _on_event(name: String, data: Variant) -> void:
	match name:
		"welcome":
			audio.play_music("match")
			_token = str(data.get("token", ""))
			_token_room = str(params.room)
			# Dopo una caduta: o si torna nello stesso lottatore, o il posto era già scaduto
			if _lost_at >= 0 and not data.get("resumed", false):
				_flash_status("Posto perso, sei rientrato da capo")
			_lost_at = -1
			_attempt = 0
			_hide_connecting()
			if _try_hint != "":
				_flash_status(_try_hint)
				_try_hint = ""
			world.my_id = data.id
			hud.my_id = data.id
			rumble.my_id = data.id
			# Server vecchi non mandano l'arena intera: allora si cerca tra quelle fisse per id
			if data.get("stage") is Dictionary:
				world.set_stage_spec(data.stage)
			else:
				world.set_stage(data.stageId)
			hud.on_welcome(data, world.stage)
			_check_server_version(str(data.get("serverVersion", "")))
			camera.position = Vector2.ZERO
			camera.zoom = Vector2.ONE
		"snapshot":
			_last_snapshot = Time.get_ticks_msec()
			for e in data.events:
				world.on_event(e)
				audio.on_event(e)
				rumble.on_event(e)
			world.on_snapshot(data)
			hud.on_snapshot(data)
		"roomFull":
			_show_connecting("Stanza piena!", "Prova con un'altra stanza: Annulla torna alla lobby.")
		"refused": # il server non ci fa entrare e dice perché (E2): si torna alla lobby con il messaggio
			_leave()
			add_child(UI.banner(str(data.get("message", "Il server non ti fa entrare")), "", Callable(), 15.0))


func _process(_delta: float) -> void:
	socket.poll()
	if _retry_at > 0 and Time.get_ticks_msec() >= _retry_at:
		_retry_at = -1
		_connect()
	elif _retry_at > 0 and _lost_at >= 0:
		_show_reconnecting() # il conto alla rovescia del posto tenuto
	# In partita gli snapshot arrivano 30 volte al secondo: se tacciono la rete è caduta, senza aspettare i ping
	if playing and _last_snapshot > 0 and Time.get_ticks_msec() - _last_snapshot > int(game.reconnect.snapshotSilenceMs):
		_last_snapshot = 0
		socket.drop()
	if playing:
		_send_input()
		if world.stage_width() > game.world.width:
			_follow(_delta)
		else:
			_frame_fighters(_delta)
		var view := Rect2(camera.position, Vector2(game.world.width, game.world.height) / camera.zoom.x)
		world.view_rect = view
		audio.view_left = view.position.x


# Nei percorsi della Corsa, più larghi dello schermo, la telecamera segue il proprio lottatore
# (come src/client/render/camera.ts): un po' a sinistra del centro, per vedere la strada davanti
func _follow(delta: float) -> void:
	var w: float = game.world.width
	if not world.positions.has(world.my_id):
		return
	var target: float = world.positions[world.my_id].x - w * 0.4
	target = clampf(target, 0, world.stage_width() - w)
	var k := 1.0 - exp(-delta * 1000.0 / 120.0)
	camera.position.x += (target - camera.position.x) * k


# Nelle arene (#12) la telecamera inquadra tutti i lottatori vivi con un po' d'aria attorno:
# si avvicina quando sono vicini e si allontana quando si sparpagliano, ma non mostra mai
# più delle zone di espulsione. La posizione è l'angolo in alto a sinistra della vista.
func _frame_fighters(delta: float) -> void:
	var cam: Dictionary = game.camera
	var screen := Vector2(game.world.width, game.world.height)
	var bz: Dictionary = world.stage.get("blastZone", {"left": 0, "right": screen.x, "top": 0, "bottom": screen.y})
	var limits := Rect2(bz.left, bz.top, bz.right - bz.left, bz.bottom - bz.top)
	# Zoom più lontano possibile: quello che riempie le zone di espulsione, o minZoom se è più vicino
	var far: float = maxf(cam.minZoom, maxf(screen.x / limits.size.x, screen.y / limits.size.y))

	var box := Rect2()
	var first := true
	for pos in world.alive_positions():
		# Il lottatore va dai piedi (pos) alla testa
		var r := Rect2(pos.x - game.fighter.width / 2.0, pos.y - game.fighter.height, game.fighter.width, game.fighter.height)
		box = r if first else box.merge(r)
		first = false
	var target_zoom := 1.0
	var center := screen / 2
	if not first:
		box = box.grow(cam.margin)
		target_zoom = clampf(minf(screen.x / box.size.x, screen.y / box.size.y), far, cam.maxZoom)
		center = box.get_center()

	var k := 1.0 - exp(-delta * 1000.0 / float(cam.smoothingMs))
	var zoom := lerpf(camera.zoom.x, target_zoom, k)
	var size := screen / zoom
	var old_center := camera.position + screen / camera.zoom.x / 2
	var c := old_center.lerp(center, k)
	# La vista resta dentro le zone di espulsione
	c.x = clampf(c.x, limits.position.x + size.x / 2, limits.end.x - size.x / 2)
	c.y = clampf(c.y, limits.position.y + size.y / 2, limits.end.y - size.y / 2)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = c - size / 2


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_F11:
		_toggle_fullscreen() # anche nella lobby
		return
	if not playing or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R:
		socket.emit("rematch") # il server lo accetta solo a partita finita
	elif key.keycode == KEY_M:
		# M accende e spegne la musica, come nel gioco web
		settings.music_on = not settings.music_on
		settings.save()
	elif key.keycode == KEY_ESCAPE and not is_instance_valid(pause_menu):
		_open_pause()


# Un pad collegato o staccato si annuncia per un attimo, sopra lobby, menu e partita
func _on_joy_changed(device: int, connected: bool) -> void:
	var pad_name := Input.get_joy_name(device)
	var toast := UI.label(("Pad collegato: " + pad_name).trim_suffix(": ") if connected else "Pad scollegato")
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.8)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(10)
	toast.add_theme_stylebox_override("normal", box)
	ui_layer.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	get_tree().create_timer(game.input.padToastMs / 1000.0).timeout.connect(toast.queue_free)


# L'HUD mostra il tasto di rivincita del dispositivo usato per ultimo
func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > settings.stick_deadzone)
	if pad or event is InputEventKey:
		var kind := Settings.pad_kind(Input.get_joy_name(event.device))
		hud.rematch_key = Settings.pad_label(REMATCH_PAD_BUTTON, kind) if pad else "R"


# Pad in partita: Start apre il menu, il pulsante di rivincita la chiede a partita finita
func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventJoypadButton
	if b == null or not b.pressed or not playing:
		return
	if b.button_index == JOY_BUTTON_START and not is_instance_valid(pause_menu):
		_open_pause()
	elif b.button_index == REMATCH_PAD_BUTTON:
		socket.emit("rematch") # il server lo accetta solo a partita finita


# F11: schermo intero e ritorno, sia nell'app sia nel browser
func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if Video.available(): # sull'app resta anche al prossimo avvio (opzioni → Video)
		settings.video.fullscreen = not full
		settings.save()


# Esc: il menu spegne i tasti di chi lo apre, ma la partita online va avanti
func _open_pause() -> void:
	pause_menu = preload("res://scripts/pause_menu.gd").new()
	pause_menu.theme = UI.theme()
	ui_layer.add_child(pause_menu)
	pause_menu.setup(settings, room_link(params.room))
	pause_menu.left.connect(_leave)


func _send_input() -> void:
	var input := {}
	var off := get_viewport().gui_get_focus_owner() != null or is_instance_valid(pause_menu)
	for action in Settings.ACTIONS:
		input[action] = not off and settings.is_pressed(action)
	# Come il client web: si manda l'input solo quando cambia (== confronta i contenuti)
	if input != _last_input and socket.is_joined():
		_last_input = input
		socket.emit("input", input)


func _read_params() -> Dictionary:
	var out := {}
	if OS.has_feature("web"):
		var search: String = str(JavaScriptBridge.eval("window.location.search", true))
		for pair in search.trim_prefix("?").split("&", false):
			var kv := pair.split("=", true, 1)
			if kv.size() == 2 and kv[1] != "":
				out[kv[0].uri_decode()] = kv[1].uri_decode()
		# Servito dal server di gioco: ci si collega allo stesso indirizzo della pagina
		if not out.has("server") and not str(JavaScriptBridge.eval("window.location.hostname", true)).ends_with("github.io"):
			out.server = str(JavaScriptBridge.eval("window.location.origin", true))
	else:
		for arg in OS.get_cmdline_user_args():
			var kv := arg.trim_prefix("--").split("=", true, 1)
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out


# In editor si gioca con npm run dev; il gioco esportato (web, app) va sul server fisso
func _default_server() -> String:
	return PRODUCTION_SERVER if OS.has_feature("template") else DEFAULT_SERVER
