# Client Socket.IO minimo, quanto basta per parlare con src/server/index.ts.
# Il server usa Socket.IO v4, che viaggia su Engine.IO v4: ogni messaggio WebSocket
# è un testo che comincia con un numero (il tipo di pacchetto). Usiamo solo:
#   0{...}       apertura (dal server)        2 / 3     ping del server / nostra risposta
#   40 / 40{...} entra nel namespace "/"      41        uscita dal namespace
#   42["evento", dati]                        un evento, in entrambe le direzioni
# Niente plugin: così funziona uguale nell'editor, su desktop e nell'export web.
class_name SocketIO
extends RefCounted

signal connected
signal disconnected
signal event_received(name: String, data: Variant)

var _ws := WebSocketPeer.new()
var _joined := false # siamo dentro il namespace e possiamo mandare eventi
var _open := false


# base_url: http(s)://host:porta, oppure ws(s)://
func connect_to(base_url: String) -> Error:
	var url := base_url.strip_edges().trim_suffix("/")
	if url.begins_with("https://"):
		url = "wss://" + url.substr(8)
	elif url.begins_with("http://"):
		url = "ws://" + url.substr(7)
	elif not (url.begins_with("ws://") or url.begins_with("wss://")):
		url = "ws://" + url
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20 # gli snapshot con 8 giocatori stanno comodi
	_joined = false
	_open = false
	return _ws.connect_to_url(url + "/socket.io/?EIO=4&transport=websocket")


func is_joined() -> bool:
	return _joined


func close() -> void:
	_ws.close()


func emit(name: String, data: Variant = null) -> void:
	if not _joined:
		return
	var payload: Array = [name] if data == null else [name, data]
	_ws.send_text("42" + JSON.stringify(payload))


# Da chiamare a ogni frame
func poll() -> void:
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_open = true
			while _ws.get_available_packet_count() > 0:
				_handle(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _open:
				_open = false
				_joined = false
				disconnected.emit()


func _handle(msg: String) -> void:
	if msg.is_empty():
		return
	match msg[0]:
		"0": # apertura Engine.IO: chiediamo di entrare nel namespace principale
			_ws.send_text("40")
		"2": # ping: se non rispondiamo il server chiude dopo pingTimeout
			_ws.send_text("3")
		"1": # il server chiude
			_ws.close()
		"4":
			_handle_socket_io(msg.substr(1))


func _handle_socket_io(msg: String) -> void:
	if msg.is_empty():
		return
	match msg[0]:
		"0":
			_joined = true
			connected.emit()
		"1":
			_joined = false
			disconnected.emit()
		"2":
			# Dopo il "2" può esserci un id di conferma (cifre) prima dell'array: lo saltiamo
			var start := msg.find("[")
			if start < 0:
				return
			var parsed: Variant = JSON.parse_string(msg.substr(start))
			if parsed is Array and parsed.size() > 0:
				event_received.emit(str(parsed[0]), parsed[1] if parsed.size() > 1 else null)
		"4":
			push_warning("Socket.IO: connessione rifiutata " + msg.substr(1))
