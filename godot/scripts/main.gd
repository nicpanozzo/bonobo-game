# Client Godot di Bonobo Game. Come il client web, non decide niente: manda solo i tasti
# premuti (InputState) al server Node e disegna gli snapshot che riceve.
# Server, stanza e nome arrivano dall'indirizzo (?server=...&room=...&name=...) nella versione web,
# o dalla riga di comando (-- --server=... --room=... --name=...) su desktop; altrimenti dalla lobby.
extends Node2D

const DEFAULT_SERVER := "http://localhost:3000" # npm run dev
const RECONNECT_MS := 1500 # attesa prima di riprovare a collegarsi

# I tasti di default del gioco web (src/client/settings.ts)
const BINDINGS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"up": [KEY_W, KEY_UP, KEY_SPACE],
	"down": [KEY_S, KEY_DOWN],
	"light": [KEY_J],
	"heavy": [KEY_K],
	"taunt": [KEY_T],
}

var game: Dictionary
var socket := SocketIO.new()
var params := {}
var world: Node2D
var camera := Camera2D.new()
var audio: Node2D
var hud: Control
var lobby: Control
var playing := false
var _last_input := ""
var _retry_at := -1


func _ready() -> void:
	game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	params = _read_params()
	world = preload("res://scripts/world_view.gd").new()
	world.setup(game)
	add_child(world)
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	audio = preload("res://scripts/audio.gd").new()
	add_child(audio)
	audio.setup(game)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = game
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	lobby = preload("res://scripts/lobby.gd").new()
	layer.add_child(lobby)
	lobby.setup(game, params)
	lobby.join_requested.connect(_join)

	socket.connected.connect(_on_connected)
	socket.disconnected.connect(_on_disconnected)
	socket.event_received.connect(_on_event)

	# Con stanza e nome nell'indirizzo si entra subito, come nel gioco web
	if params.has("room") and params.has("name"):
		_join(params)


func _join(choice: Dictionary) -> void:
	params.merge(choice, true)
	lobby.hide()
	playing = true
	_connect()


func _connect() -> void:
	hud.set_status("Mi collego a %s..." % params.server)
	var err := socket.connect_to(params.server)
	if err != OK:
		hud.set_status("Non riesco a collegarmi (%s)" % error_string(err))
		_retry_at = Time.get_ticks_msec() + RECONNECT_MS


func _on_connected() -> void:
	hud.set_status("")
	var data := {"room": params.room, "name": params.name}
	if params.get("stage", "") != "":
		data.stageId = params.stage # conta solo se la stanza è nuova
	if params.get("char", "") != "":
		data.characterId = params.char # per ora si disegna comunque un rettangolo
	socket.emit("join", data)
	_last_input = ""


func _on_disconnected() -> void:
	hud.set_status("Connessione persa, riprovo...")
	_retry_at = Time.get_ticks_msec() + RECONNECT_MS


func _on_event(name: String, data: Variant) -> void:
	match name:
		"welcome":
			world.my_id = data.id
			hud.my_id = data.id
			# Server vecchi non mandano l'arena intera: allora si cerca tra quelle fisse per id
			if data.get("stage") is Dictionary:
				world.set_stage_spec(data.stage)
			else:
				world.set_stage(data.stageId)
			hud.rules = data.rules
			camera.limit_left = 0
			camera.limit_right = int(world.stage_width())
			camera.position = Vector2.ZERO
		"snapshot":
			for e in data.events:
				world.on_event(e)
				audio.on_event(e)
			world.on_snapshot(data)
			hud.on_snapshot(data)
		"roomFull":
			hud.set_status("Stanza piena! Prova con un'altra stanza")


func _process(_delta: float) -> void:
	socket.poll()
	if _retry_at > 0 and Time.get_ticks_msec() >= _retry_at:
		_retry_at = -1
		_connect()
	if playing:
		_send_input()
		_follow(_delta)
		world.view_left = camera.position.x
		audio.view_left = camera.position.x


# Nei percorsi della Corsa, più larghi dello schermo, la telecamera segue il proprio lottatore
# (come src/client/render/camera.ts): un po' a sinistra del centro, per vedere la strada davanti
func _follow(delta: float) -> void:
	var w: float = game.world.width
	if world.stage_width() <= w or not world.positions.has(world.my_id):
		return
	var target: float = world.positions[world.my_id].x - w * 0.4
	target = clampf(target, 0, world.stage_width() - w)
	var k := 1.0 - exp(-delta * 1000.0 / 120.0)
	camera.position.x += (target - camera.position.x) * k


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not playing or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R:
		socket.emit("rematch") # il server lo accetta solo a partita finita
	elif key.keycode == KEY_M:
		# M accende e spegne la musica, come nel gioco web
		audio.set_volumes(game.audio.master, game.audio.sfx, game.audio.music, not audio.music_on())


func _send_input() -> void:
	var input := {}
	var focused := get_viewport().gui_get_focus_owner() != null
	for action in BINDINGS:
		var on := false
		if not focused:
			for k in BINDINGS[action]:
				on = on or Input.is_physical_key_pressed(k)
		input[action] = on
	# Come il client web: si manda l'input solo quando cambia
	var key := JSON.stringify(input)
	if key != _last_input and socket.is_joined():
		_last_input = key
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
	if not out.has("server"):
		out.server = DEFAULT_SERVER
	return out
