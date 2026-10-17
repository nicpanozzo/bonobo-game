# Client Godot di Bonobo Game. Come il client web, non decide niente: manda solo i tasti
# premuti (InputState) al server Node e disegna gli snapshot che riceve.
# Server, stanza e nome arrivano dall'indirizzo (?server=...&room=...&name=...) nella versione web,
# o dalla riga di comando (-- --server=... --room=... --name=...) su desktop; altrimenti dalla lobby,
# che parte dall'ultima scelta salvata. ?bot=manichino aggiunge un avversario del server (#20).
extends Node2D

const GymFlow := preload("res://scripts/gym_flow.gd")
const DEFAULT_SERVER := "http://localhost:3000" # npm run dev
const LINK_BUTTON_POS := Vector2(12, 36) # "Copia link" in partita, sotto la riga della stanza, pixel
const HOST_LINK_TOAST_S := 10.0 # quanto resta l'avviso "link copiato" a chi ospita, secondi
const PRODUCTION_SERVER := "https://bonobo-game.onrender.com" # server fisso (render.yaml, #19): lo usa il gioco esportato
const RECONNECT_MS := 1500 # attesa prima di riprovare a collegarsi
const WAKE_HINT_MS := 5000 # dopo quanti ms senza risposta si avvisa che il server forse si sta svegliando
const REMATCH_PAD_BUTTON := JOY_BUTTON_Y # rivincita dal pad: Y è libero finché non arriva la speciale (E10)
const RESULTS_BAR_BOTTOM := 150 # distanza dal fondo dei pulsanti di fine partita, sopra le schede dei giocatori, pixel
const P2_NAME_CHARS := 13 # caratteri del nome tenuti per il secondo giocatore, che ci aggiunge " 2" (il server ne tiene 16)
const PAGES_URL := "https://nicpanozzo.github.io/bonobo-game/godot/" # dove sta la versione web (pages.yml)

var game: Dictionary
var settings: Settings
var socket := SocketIO.new()
var params := {}
var url_params := {} # solo quelli dell'indirizzo o della riga di comando
var ui_layer := CanvasLayer.new()
var _link_button: Button
var _lan_link_button: Button
var pause_menu: Control
var world: Node2D
var camera := Camera2D.new()
var audio: Node2D
var rumble: Rumble
var hud: Control
var touch: TouchControls # levetta e tasti a schermo per il telefono (E18)
var _rotate_hint: Label # "gira il telefono", sopra tutto, quando si tiene il telefono in verticale (E18)
var _fullscreen_asked := false
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
var _join_since := -1 # ms in cui si è cominciato a entrare nella stanza, -1 quando si è dentro o fuori
var _version_warned := false # banner "versione nuova" già mostrato (E2)
var _try_hint := "" # prova del primo avvio (E14): si mostra appena si entra nella stanza
var _last_snapshot := 0 # ms dell'ultimo snapshot: in partita il silenzio dice che la rete è caduta
var gym := GymFlow.new(self) # palestra, tutorial e sfide (E15): pannelli e stanze tutte proprie
var results_bar: Control # Rivincita e Cambia lottatore a fine partita (#250), null durante la partita
var _last_players: Array = [] # giocatori dell'ultimo snapshot, per il tasto Segnala (#214)
var p2: SecondPlayer # il secondo giocatore sullo stesso schermo, col suo pad; null se non c'è
var _p1_pad := -1 # l'ultimo pad usato dal primo giocatore: Start da un altro pad fa entrare il secondo
var _p2_hint: Label


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
	# In alto a sinistra, sotto la riga della stanza: il link per gli amici a portata di clic (#308)
	_link_button = UI.small_button("Copia link", func():
		UI.copy(room_link(params.room))
		UI.toast(ui_layer, "Link copiato: incollalo sul Discord"))
	_link_button.focus_mode = Control.FOCUS_NONE # niente fuoco: spazio e invio restano ai comandi
	_link_button.visible = false
	var link_row := HBoxContainer.new()
	link_row.position = LINK_BUTTON_POS
	link_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(link_row)
	link_row.add_child(_link_button)
	# Chi ospita (#308) ha anche il link per chi è sulla stessa rete: niente tunnel, niente lag
	_lan_link_button = UI.small_button("Copia link di casa", func():
		UI.copy(PAGES_URL + "?room=" + str(params.room).uri_encode() + "&server=" + str(HostServer.instance(get_tree()).info.get("lanServer", "")).uri_encode())
		UI.toast(ui_layer, "Link di casa copiato: per chi è sul tuo stesso Wi-Fi"))
	_lan_link_button.focus_mode = Control.FOCUS_NONE
	_lan_link_button.visible = false
	link_row.add_child(_lan_link_button)
	# Due sullo stesso schermo: chi ha un pad in mano lo deve sapere
	_p2_hint = UI.note("Secondo giocatore: prendi un pad e premi Start")
	_p2_hint.visible = false
	link_row.add_child(_p2_hint)
	touch = TouchControls.new()
	touch.visible = false
	layer.add_child(touch)
	touch.configure(settings.touch)
	settings.changed.connect(func(): touch.configure(settings.touch))
	touch.pause_pressed.connect(func(): if not is_instance_valid(pause_menu): _open_pause())
	touch.free_tap.connect(func(): socket.emit("rematch")) # come R: il server lo accetta solo a partita finita
	touch.extra_pressed.connect(func(extra: String):
		if extra == "panel" and is_instance_valid(gym.training):
			gym.training.toggle())
	ui_layer.layer = 2 # menu sopra l'HUD
	add_child(ui_layer)
	var top := CanvasLayer.new()
	top.layer = 3
	add_child(top)
	_rotate_hint = UI.label("Gira il telefono\nin orizzontale")
	_rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_hint.add_theme_font_size_override("font_size", 110) # in verticale lo schermo da 1280 diventa largo un terzo
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0.05, 0.05, 0.08, 0.94)
	_rotate_hint.add_theme_stylebox_override("normal", dark)
	_rotate_hint.visible = false
	top.add_child(_rotate_hint)
	_rotate_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


# kind: dove parte la prima pagina della lobby (create, join o bot, #250); con un link si entra in quella stanza.
# rejoin: si torna da una partita, quindi la lobby propone la stessa stanza (per rientrarci con un altro lottatore)
func _show_lobby(kind := "create", rejoin := false) -> void:
	audio.play_music("lobby")
	lobby = preload("res://scripts/lobby.gd").new()
	lobby.theme = UI.theme()
	ui_layer.add_child(lobby)
	var p := params.duplicate()
	p.rejoin = rejoin
	if _local_host():
		p.server = settings.profile.get("server", _default_server()) # nel campo Server non va 127.0.0.1
	lobby.setup(game, p, room_link, "join" if url_params.has("room") else (kind if kind != "" else "create"))
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
				var was: String = lobby._kind
				lobby.queue_free()
				_show_lobby(was)
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
	title.bot_requested.connect(func():
		title.queue_free()
		_show_lobby("bot"))
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
	title.tutorial_requested.connect(func():
		title.queue_free()
		gym.join_gym(true))
	title.training_requested.connect(func():
		title.queue_free()
		gym.join_gym(false))
	title.challenges_requested.connect(func():
		gym.show_challenges(func():
			title.queue_free()
			gym.join_challenge.call_deferred(gym.picked), title.restore_focus))
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
	params.tutorial = choice.get("tutorial", false) # vale solo per questa entrata
	params.challenge = choice.get("challenge", {})
	params.kind = choice.get("kind", "") # come si è entrati dalla lobby (#250): vale solo per questa entrata
	if params.server == "":
		params.server = _default_server()
	# La palestra (E15) non diventa l'ultima scelta: la lobby resta com'era
	if not choice.get("gym", false):
		# Ospitando (#308) il server è 127.0.0.1: si ricorda quello di prima, per quando non si ospita
		var saved_server: String = settings.profile.get("server", "") if _local_host() else params.server
		settings.profile = {"name": params.name, "room": params.room, "char": params.get("char", ""), "skin": params.get("skin", ""), "stage": params.get("stage", ""), "rules": params.get("rules", {}), "server": saved_server, "host": params.get("host", false)}
		settings.save()
	_set_url(params.room)
	if is_instance_valid(lobby):
		lobby.queue_free()
	playing = true
	_link_button.visible = not choice.get("gym", false) and not params.tutorial and params.challenge.is_empty()
	_lan_link_button.visible = _local_host() and str(HostServer.instance(get_tree()).info.get("lanServer", "")) != ""
	_connect()
	if _local_host(): # chi ospita (#308): il link per gli amici va negli appunti, e va detto
		# Solo qui: prima di _join params.server non è ancora 127.0.0.1 e il link uscirebbe con Render
		UI.copy(room_link(params.room))
		var lan_only := not HostServer.instance(get_tree()).info.has("server")
		UI.toast(ui_layer, "Link copiato: vale solo per chi è sul tuo Wi-Fi (il tunnel non è partito)" if lan_only \
				else "Link della serata copiato: incollalo sul Discord (anche da Esc → Copia link)", UI.WARN if lan_only else UI.OK, HOST_LINK_TOAST_S)


# Esce dalla stanza e torna alla lobby (dal menu di pausa o dalla fine della partita).
# page: la pagina della lobby da aprire, "fighter" per "Cambia lottatore" a fine partita (#250)
func _leave(page := "match") -> void:
	playing = false
	_link_button.visible = false
	_lan_link_button.visible = false
	if p2 != null:
		p2.stop()
	_retry_at = -1
	_lost_at = -1
	_join_since = -1
	_last_snapshot = 0
	socket.close()
	world.reset()
	hud.reset()
	gym.close_all()
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	_hide_connecting()
	_hide_results()
	_show_lobby(str(params.get("kind", "")), true)
	lobby.open_page(page)


# Un avviso che sparisce da solo dopo qualche secondo, se nel frattempo non ne è arrivato un altro
func _flash_status(text: String) -> void:
	hud.set_status(text)
	get_tree().create_timer(4.0).timeout.connect(func():
		if hud.status == text:
			hud.set_status(""))


# Predizione (E17): accesa dall'opzione, e solo a velocità normale (l'allenamento rallentato fa meno tick)
func _apply_prediction() -> void:
	world.predictor.enabled = bool(settings.video.get("predict", true)) and gym.speed == 1.0


func _apply_volumes() -> void:
	audio.set_volumes(settings.master, settings.sfx, settings.music, settings.music_on, settings.voices)
	rumble.level = settings.rumble
	world.effects = settings.video.effects
	world.attack_boxes = settings.video.hitboxes
	_apply_prediction()
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
		# Chi ospita dal suo computer (#308) gioca su 127.0.0.1: agli amici va il tunnel o l'indirizzo di casa
		var server := HostServer.instance(get_tree()).public_server() if _local_host() else str(params.server)
		link += "&server=" + server.uri_encode()
	return link


# Si gioca sul server acceso da questa app (#308)
func _local_host() -> bool:
	return str(params.get("server", "")).begins_with("http://127.0.0.1:") and get_tree().root.has_node("HostServer")


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
		if _join_since < 0:
			_join_since = Time.get_ticks_msec()
		_show_joining("Mi collego...", "Stanza %s su %s" % [params.room, params.server])
	socket.lag_ms = int(params.get("lag", "0")) # E17: --lag=150 o ?lag=150 per provare la predizione con un server lontano
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
	if params.get("skin", "") != "":
		data.skinId = params.skin # la controlla il server: se quel lottatore non ce l'ha, aspetto base (#339)
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
			UI.open_url("https://nicpanozzo.github.io/bonobo-game/#gioca")))


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


# Mentre si entra: dopo qualche secondo senza risposta si spiega che il server forse dormiva.
# Quello gratuito (Render) si spegne quando nessuno gioca e ci mette circa un minuto a ripartire.
func _show_joining(title_text: String, detail: String) -> void:
	if _join_since >= 0 and Time.get_ticks_msec() - _join_since >= WAKE_HINT_MS:
		var waited := int((Time.get_ticks_msec() - _join_since) / 1000.0)
		_show_connecting("Il server si sta svegliando...", "Se nessuno giocava da un po', il server dormiva: può volerci fino a un minuto. Resta qui, entri da solo appena è pronto (%d s). Con Annulla torni alla lobby." % waited)
	else:
		_show_connecting(title_text, detail)


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
	_show_joining("Il server non risponde", "Non riesco a raggiungere %s: riprovo. Con Annulla torni alla lobby e puoi cambiare server." % params.server)
	_retry_at = Time.get_ticks_msec() + RECONNECT_MS * 2


func _on_event(name: String, data: Variant) -> void:
	match name:
		"welcome":
			audio.play_music("match")
			gym.speed = 1.0
			_apply_prediction()
			_token = str(data.get("token", ""))
			_token_room = str(params.room)
			# Dopo una caduta: o si torna nello stesso lottatore, o il posto era già scaduto
			if _lost_at >= 0 and not data.get("resumed", false):
				_flash_status("Posto perso, sei rientrato da capo")
			_lost_at = -1
			_attempt = 0
			_join_since = -1
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
			audio.set_stage_music(world.stage.get("music")) # la musica dell'arena, se ne ha una (E12)
			audio.stage_hazards = world.stage.get("hazards", []) if world.stage.get("hazards") is Array else [] # il ciclista (#229)
			audio.stage_jets = world.stage.get("jets", []) if world.stage.get("jets") is Array else [] # i getti d'acqua (#253)
			gym.on_welcome(data)
			_check_server_version(str(data.get("serverVersion", "")))
			camera.position = Vector2.ZERO
			camera.zoom = Vector2.ONE
		"snapshot":
			_last_snapshot = Time.get_ticks_msec()
			_last_players = data.get("players", [])
			for e in data.events:
				world.on_event(e)
				audio.on_event(e)
				rumble.on_event(e)
				gym.on_event(e)
			world.on_snapshot(data)
			hud.on_snapshot(data)
			audio.on_snapshot(data)
			gym.on_snapshot(data)
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
	elif _join_since >= 0 and _lost_at < 0 and is_instance_valid(connecting) and Time.get_ticks_msec() - _join_since >= WAKE_HINT_MS:
		_show_joining("", "") # avviso del server che si sveglia, con i secondi che passano
	# In partita gli snapshot arrivano 30 volte al secondo: se tacciono la rete è caduta, senza aspettare i ping
	if playing and _last_snapshot > 0 and Time.get_ticks_msec() - _last_snapshot > int(game.reconnect.snapshotSilenceMs):
		_last_snapshot = 0
		socket.drop()
	var panel_open: bool = is_instance_valid(gym.training) and gym.training.is_open()
	touch.visible = playing and touch.active and not is_instance_valid(pause_menu) and not panel_open
	touch.extras = {"panel": "Pannello"} if is_instance_valid(gym.training) else {}
	_rotate_hint.visible = touch.active and TouchControls.portrait(Vector2(DisplayServer.window_get_size()))
	if touch.active and playing:
		hud.rematch_key = "Tocca lo schermo"
	# A fine partita i pulsanti Rivincita e Cambia lottatore; spariscono quando la rivincita comincia
	var over: bool = playing and hud._snap.get("winnerId") != null and not gym.hides_results()
	if over and not is_instance_valid(results_bar) and not is_instance_valid(pause_menu):
		_show_results()
	elif not over and is_instance_valid(results_bar):
		_hide_results()
	if p2 != null:
		p2.poll()
	_p2_hint.visible = _p2_allowed() and p2 == null and _free_pads().size() > 0
	if playing:
		_send_input()
		# Solo i percorsi della Corsa (con il traguardo) seguono il proprio lottatore; le arene,
		# anche quelle più larghe dello schermo (#240), inquadrano tutti
		if world.stage.get("goal") != null:
			_follow(_delta)
		else:
			_frame_fighters(_delta)
		var view := Rect2(camera.position, Vector2(game.world.width, game.world.height) / camera.zoom.x)
		world.view_rect = view
		audio.view_left = view.position.x


# Nei percorsi della Corsa, più larghi dello schermo, la telecamera segue il proprio lottatore:
# un po' a sinistra del centro, per vedere la strada davanti
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
	var aim := framing(world.stage, cam, game, world.alive_positions())
	var limits: Rect2 = aim.limits
	var target_zoom: float = aim.zoom
	var center: Vector2 = aim.center

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


# Dove punta la telecamera di un'arena: zoom e centro per inquadrare i lottatori vivi (posizioni ai piedi),
# e il rettangolo delle zone di espulsione da cui la vista non esce. L'arena può chiedere il suo
# zoom (camera.minZoom e maxZoom, #240): le arene più larghe dello schermo si allontanano di più.
static func framing(stage: Dictionary, cam: Dictionary, game: Dictionary, positions: Array) -> Dictionary:
	var screen := Vector2(game.world.width, game.world.height)
	var width := float(stage.get("width", screen.x))
	var bz: Dictionary = stage.get("blastZone", {"left": 0, "right": width, "top": 0, "bottom": screen.y})
	var limits := Rect2(bz.left, bz.top, bz.right - bz.left, bz.bottom - bz.top)
	var own: Dictionary = stage.get("camera") if stage.get("camera") is Dictionary else {}
	var min_zoom: float = own.get("minZoom", cam.minZoom)
	var max_zoom: float = own.get("maxZoom", cam.maxZoom)
	# Zoom più lontano possibile: quello che riempie le zone di espulsione, o minZoom se è più vicino
	var far: float = maxf(min_zoom, maxf(screen.x / limits.size.x, screen.y / limits.size.y))
	var box := Rect2()
	var first := true
	for pos in positions:
		# Il lottatore va dai piedi (pos) alla testa
		var r := Rect2(pos.x - game.fighter.width / 2.0, pos.y - game.fighter.height, game.fighter.width, game.fighter.height)
		box = r if first else box.merge(r)
		first = false
	if first:
		# Nessuno in campo: l'arena intera, al centro della sua larghezza
		return {"zoom": clampf(minf(1.0, screen.x / width), far, max_zoom), "center": Vector2(width / 2.0, screen.y / 2.0), "limits": limits}
	box = box.grow(cam.margin)
	var zoom := clampf(minf(screen.x / box.size.x, screen.y / box.size.y), far, max_zoom)
	return {"zoom": zoom, "center": box.get_center(), "limits": limits}


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
	if not connected and p2 != null and device == p2.device:
		p2.stop("Pad del giocatore 2 scollegato")
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
	if event is InputEventScreenTouch and event.pressed and not _fullscreen_asked:
		_fullscreen_asked = true
		_go_fullscreen()
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > settings.stick_deadzone)
	# Start non conta: è proprio il tasto con cui un secondo pad entra in partita
	if pad and event.device != settings.p2_pad and not (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START):
		_p1_pad = event.device
	if pad and event.device == settings.p2_pad:
		return # l'HUD mostra i tasti del primo giocatore
	if pad or event is InputEventKey:
		var kind := Settings.pad_kind(Input.get_joy_name(event.device))
		hud.rematch_key = Settings.pad_label(REMATCH_PAD_BUTTON, kind) if pad else "R"


# Sotto la classifica di fine partita: Rivincita (come R o Y) e Cambia lottatore, che torna alla lobby
# sulla stessa stanza e apre la pagina dei lottatori (#250)
func _show_results() -> void:
	results_bar = HBoxContainer.new()
	results_bar.add_theme_constant_override("separation", UI.GAP_L)
	var again := UI.button("Rivincita", func(): socket.emit("rematch"), true)
	again.custom_minimum_size = Vector2(220, 0)
	results_bar.add_child(again)
	var change := UI.button("Cambia lottatore", func(): _leave("fighter"))
	change.custom_minimum_size = Vector2(220, 0)
	results_bar.add_child(change)
	results_bar.theme = UI.theme()
	ui_layer.add_child(results_bar)
	results_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	results_bar.position.y -= RESULTS_BAR_BOTTOM * Access.text_scale
	UI.fade_in(results_bar)
	# Col pad il fuoco sta su Rivincita; con la tastiera R resta la scorciatoia
	if not Input.get_connected_joypads().is_empty():
		again.grab_focus()


func _hide_results() -> void:
	if is_instance_valid(results_bar):
		results_bar.queue_free()
	results_bar = null


# Pad in partita: Start apre il menu, il pulsante di rivincita la chiede a partita finita
func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventJoypadButton
	if b == null or not b.pressed or not playing:
		return
	if p2 != null and b.device == p2.device:
		if b.button_index == SecondPlayer.LEAVE_BUTTON:
			p2.stop("Giocatore 2 è uscito")
		elif b.button_index == REMATCH_PAD_BUTTON:
			p2.rematch()
		return
	if b.button_index == JOY_BUTTON_START and p2 == null and _p2_allowed() and _free_pads().has(b.device):
		_add_p2(b.device)
	elif b.button_index == JOY_BUTTON_START and not is_instance_valid(pause_menu):
		_open_pause()
	elif b.button_index == REMATCH_PAD_BUTTON:
		socket.emit("rematch") # il server lo accetta solo a partita finita


# Al primo tocco nel browser (E18): schermo intero e, dove il browser lo permette (Android), bloccato in orizzontale.
# Il browser lo concede solo subito dopo un gesto della persona, per questo si chiede qui e non all'avvio.
func _go_fullscreen() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			var el = document.documentElement;
			if (!el.requestFullscreen || document.fullscreenElement) return;
			el.requestFullscreen().then(function () {
				if (screen.orientation && screen.orientation.lock) return screen.orientation.lock("landscape");
			}).catch(function () {});
		})();
	""", true)


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
	pause_menu.setup(settings, room_link(params.room), {"server": params.server, "room": params.room, "stage": world.stage.get("name", ""), "rules": hud.rules, "players": _last_players, "me": world.my_id})
	pause_menu.left.connect(_leave)


func _send_input() -> void:
	var input := {}
	var off := get_viewport().gui_get_focus_owner() != null or is_instance_valid(pause_menu)
	for action in Settings.ACTIONS:
		input[action] = not off and (settings.is_pressed(action) or touch.pressed(action))
	input.jump = not off and (settings.jump_pressed() or touch.pressed("jump"))
	# Come il client web: si manda l'input solo quando cambia (== confronta i contenuti)
	if input != _last_input and socket.is_joined():
		_last_input = input
		# E17: il numero dell'input è il tick locale, così lo snapshot dice da dove rigiocare il proprio movimento
		var sent := input.duplicate()
		sent.seq = local_tick(Time.get_ticks_msec(), float(game.get("tickRate", 60)))
		socket.emit("input", sent)
		world.predictor.record_input(input, sent.seq)


# Il secondo giocatore entra solo nelle partite vere: non in palestra, tutorial e sfide
func _p2_allowed() -> bool:
	return playing and _link_button.visible and not is_instance_valid(pause_menu)


# I pad che non sono in mano al primo giocatore
func _free_pads() -> Array:
	return Input.get_connected_joypads().filter(func(d): return d != _p1_pad)


func _add_p2(device: int) -> void:
	p2 = SecondPlayer.new(device, settings, game)
	p2.left.connect(func(reason: String):
		p2 = null
		if reason != "":
			UI.toast(ui_layer, reason, UI.WARN))
	p2.start(params.server, params.room, str(params.name).left(P2_NAME_CHARS) + " 2", _my_version(), int(params.get("protocol", game.protocol)))
	UI.toast(ui_layer, "Giocatore 2 entra col pad (Select per uscire)")


static func local_tick(now_ms: int, tick_rate: float) -> int:
	return int(floor(now_ms * tick_rate / 1000.0))


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
