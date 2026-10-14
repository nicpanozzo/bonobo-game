# Il secondo giocatore sullo stesso schermo: un amico prende un pad e preme Start, e entra nella stessa stanza
# con un collegamento tutto suo, come se giocasse da un altro computer. Il server non vede differenze.
# Manda solo i tasti del suo pad; gli snapshot li disegna già il primo giocatore (la telecamera inquadra tutti).
class_name SecondPlayer
extends RefCounted

signal left(reason: String) # uscito o caduto: main.gd lo toglie e lo dice

const LEAVE_BUTTON := JOY_BUTTON_BACK # Select / View / Share / -: Start del secondo pad non apre il menu di nessuno

var device := -1
var id := "" # il suo lottatore, dal welcome
var _socket := SocketIO.new()
var _settings: Settings
var _game: Dictionary
var _join := {}
var _last_input := {}


func _init(pad: int, settings: Settings, game: Dictionary) -> void:
	device = pad
	_settings = settings
	_game = game
	_settings.p2_pad = pad
	_socket.connected.connect(func(): _socket.emit("join", _join))
	_socket.disconnected.connect(func(): stop("Giocatore 2 scollegato"))
	_socket.connect_failed.connect(func(): stop("Il giocatore 2 non riesce a entrare"))
	_socket.event_received.connect(_on_event)


# Entra nella stanza del primo giocatore; name e version come i suoi (main.gd)
func start(server: String, room: String, name: String, version: String, protocol: int) -> void:
	_join = {"room": room, "name": name, "version": version, "protocol": protocol}
	_socket.connect_to(server)


func stop(reason := "") -> void:
	if _settings.p2_pad == device:
		_settings.p2_pad = -1
	if device < 0:
		return
	device = -1
	_socket.close()
	left.emit(reason)


func poll() -> void:
	if device < 0:
		return
	_socket.poll()
	if not _socket.is_joined():
		return
	var input := {}
	for action in Settings.ACTIONS:
		input[action] = _settings.pad_pressed(action, device)
	if input != _last_input:
		_last_input = input
		var sent := input.duplicate()
		sent.seq = int(floor(Time.get_ticks_msec() * float(_game.get("tickRate", 60)) / 1000.0))
		_socket.emit("input", sent)


func rematch() -> void:
	_socket.emit("rematch")


func _on_event(name: String, data: Variant) -> void:
	match name:
		"welcome":
			id = str(data.get("id", ""))
		"roomFull":
			stop("Stanza piena: il giocatore 2 non entra")
		"refused":
			stop(str(data.get("message", "Il server non fa entrare il giocatore 2")))
