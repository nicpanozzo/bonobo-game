# Ospita la partita dal proprio computer (#308): l'app scarica una volta sola il server della sua stessa
# versione (bonobo-server-<sistema>.zip della Release app-N, quello di src/server/host.ts), lo avvia in
# sottofondo e ci entra da 127.0.0.1: chi ospita non ha latenza, gli amici entrano con il link del tunnel
# o, nella stessa rete, con l'indirizzo di casa. Il server si spegne da solo quando l'app si chiude.
# Vive sotto la radice della scena, così resta acceso tra lobby e partite.
# Per provarlo in locale: godot --path godot -- --host-from=http://localhost:8000/ (lì bonobo-server-<sistema>.zip)
class_name HostServer
extends Node

signal progress(text: String)
signal ready_to_play(info: Dictionary) # {room, port, server (tunnel, può mancare), lanServer}
signal failed(text: String)
signal tunnel_ready(info: Dictionary) # il tunnel arriva dopo che si gioca già in casa: c'è un link nuovo
signal tunnel_changed(info: Dictionary) # senza tunnel: riprova in corso, motivo nuovo o tunnel chiuso (#526)

const RELEASE_URL := "https://github.com/nicpanozzo/bonobo-game/releases/download/app-%d/bonobo-server-%s.zip"
const DIR := "user://server/"
const DOWNLOAD_TIMEOUT_S := 300.0 # il server pesa decine di MB, anche con una rete lenta
const START_TIMEOUT_S := 45.0 # il tunnel di Cloudflare da solo ne aspetta 30 (TUNNEL_TIMEOUT_MS in host.ts)
const POLL_S := 0.25
const FIRST_PORT := 3000 # la porta del server di sempre; se è occupata (npm run dev, un altro server) si va avanti
const PORT_TRIES := 20

var info := {} # l'ultimo stato letto dal server, vuoto finché non è pronto
var _pid := 0
var _http := HTTPRequest.new()
var _timer := Timer.new()
var _waited := 0.0
var _room := ""
var _shown_mb := -1
var _port := 0 # la porta provata per ultima, per ripartire dalla successiva se il server la trova occupata
var _retry_round := "" # "Riprova il tunnel" chiesto quando info.json era a questo giro: finché non cambia, si sta riprovando


# Il server che fa da host c'è solo nell'app scaricata per computer, con la sua versione
static func available() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web") and _build_version() > 0 and _platform() != ""


# L'unico host dell'app, creato al primo uso
static func instance(tree: SceneTree) -> HostServer:
	var found := tree.root.get_node_or_null("HostServer")
	if found is HostServer:
		return found
	var h := HostServer.new()
	h.name = "HostServer"
	tree.root.add_child(h)
	return h


# Il server da usare per entrare nella propria partita
func local_server() -> String:
	return "http://127.0.0.1:%d" % int(info.get("port", 3000))


# Il server da mettere nel link per gli amici: il tunnel, altrimenti l'indirizzo di casa
func public_server() -> String:
	return str(info.get("server", lan_server()))


# L'indirizzo di casa: lo scrive il server, ma sul Mac a volte arriva vuoto; allora lo si chiede a Godot
func lan_server() -> String:
	var lan := str(info.get("lanServer", ""))
	if lan == "" and not info.is_empty():
		var ip := lan_ip(IP.get_local_addresses())
		lan = "http://%s:%d" % [ip, int(info.get("port", 3000))] if ip != "" else ""
	return lan


# Il primo indirizzo IPv4 della rete di casa (192.168.x, 10.x, 172.16-31.x), vuoto se non c'è
static func lan_ip(addresses: PackedStringArray) -> String:
	for a in addresses:
		var parts := a.split(".")
		if parts.size() != 4 or not a.is_valid_ip_address():
			continue
		var second := int(parts[1])
		if parts[0] == "192" and parts[1] == "168" or parts[0] == "10" or parts[0] == "172" and second >= 16 and second <= 31:
			return a
	return ""


# Cosa dire a chi ospita quando il link per gli amici non è quello del tunnel (#526); vuoto se il tunnel c'è.
# retrying: chi ospita ha appena chiesto di riprovare e il server non ha ancora risposto
static func tunnel_note_text(server_info: Dictionary, retrying := false) -> String:
	if server_info.is_empty() or server_info.has("server"):
		return ""
	if retrying or str(server_info.get("tunnel", "")) == "trying":
		return "Cerco il tunnel per chi è lontano... intanto il link vale solo per il tuo Wi-Fi"
	var detail := str(server_info.get("detail", ""))
	return "Niente tunnel: il link vale solo per il tuo Wi-Fi. %s%s" % [str(server_info.get("error", "")), (" (" + detail + ")") if detail != "" else ""]


# Il pulsante "Riprova il tunnel" ha senso solo quando i tentativi del server sono finiti
static func tunnel_can_retry(server_info: Dictionary, retrying := false) -> bool:
	return not retrying and not server_info.is_empty() and not server_info.has("server") and str(server_info.get("tunnel", "failed")) != "trying"


func tunnel_note() -> String:
	return tunnel_note_text(info, _retry_round != "")


func can_retry_tunnel() -> bool:
	return running() and tunnel_can_retry(info, _retry_round != "")


# Chiede al server un giro nuovo di tentativi: lo legge da un file accanto a info.json (host.ts, RETRY_FILE)
func retry_tunnel() -> void:
	if not can_retry_tunnel():
		return
	var f := FileAccess.open(_dir() + "info.json.retry", FileAccess.WRITE)
	if f == null:
		return
	f.store_string("1")
	f.close()
	_retry_round = str(info.get("round", "?"))
	tunnel_changed.emit(info)


func running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid) and not info.is_empty()


func start(room: String) -> void:
	_room = room
	_port = 0
	if running():
		ready_to_play.emit(info)
		return
	if not available():
		failed.emit("Ospitare si può solo dall'app per computer.")
		return
	if FileAccess.file_exists(_exe()):
		_launch()
		return
	_download()


func _ready() -> void:
	set_process(false) # solo durante il download, per il conto dei MB
	add_child(_http)
	_http.timeout = DOWNLOAD_TIMEOUT_S
	_timer.wait_time = POLL_S
	_timer.timeout.connect(_poll)
	add_child(_timer)


func _exit_tree() -> void:
	stop()


func stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = 0
	info = {}
	_retry_round = ""


func _download() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir()))
	_http.download_file = _dir() + "server.zip.part"
	_http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	progress.emit("Scarico il server (solo la prima volta)...")
	_shown_mb = -1
	set_process(true)
	if _http.request(_url()) != OK:
		failed.emit("Non riesco a scaricare il server.")


func _process(_delta: float) -> void:
	var got := _http.get_downloaded_bytes()
	if got / 1048576 != _shown_mb:
		_shown_mb = got / 1048576
		progress.emit("Scarico il server (solo la prima volta)... %d MB" % _shown_mb)


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	var zip_path := ProjectSettings.globalize_path(_dir() + "server.zip.part")
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(zip_path)
		failed.emit("Download del server non riuscito (%d). Riprova più tardi." % code)
		return
	progress.emit("Preparo il server...")
	if not _unzip(zip_path):
		DirAccess.remove_absolute(zip_path)
		failed.emit("Il server scaricato è rotto. Riprova.")
		return
	DirAccess.remove_absolute(zip_path)
	_remove_old_versions()
	_launch()


func _unzip(zip_path: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return false
	var dir := ProjectSettings.globalize_path(_dir())
	for name in zip.get_files():
		if name.ends_with("/"):
			continue
		# Solo nomi semplici dentro la cartella del server: un "../" o un percorso assoluto nello zip
		# scriverebbe fuori (zip slip), quindi lo zip si scarta tutto
		if name.begins_with("/") or name.contains("..") or name.contains("\\") or name.contains(":"):
			zip.close()
			return false
		var out := dir.path_join(name)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			zip.close()
			return false
		f.store_buffer(zip.read_file(name))
		f.close()
		# Lo zip letto qui perde i permessi: server e tunnel devono tornare eseguibili
		if not OS.has_feature("windows") and not name.ends_with(".txt"):
			OS.execute("chmod", ["+x", out])
	zip.close()
	return FileAccess.file_exists(_exe())


# Solo il server della versione dell'app serve: gli altri sono decine di MB buttati
func _remove_old_versions() -> void:
	var keep := _dir().trim_suffix("/").get_file()
	for d in DirAccess.get_directories_at(DIR):
		if d != keep:
			OS.move_to_trash(ProjectSettings.globalize_path(DIR + d))


func _launch() -> void:
	progress.emit("Accendo il server e preparo il link per gli amici...")
	var info_path := ProjectSettings.globalize_path(_dir() + "info.json")
	DirAccess.remove_absolute(info_path)
	info = {}
	var port := _free_port(maxi(FIRST_PORT, _port + 1) if _port > 0 else FIRST_PORT)
	_port = port
	if port == 0:
		failed.emit("Le porte da %d a %d sono tutte occupate." % [FIRST_PORT, FIRST_PORT + PORT_TRIES - 1])
		return
	OS.set_environment("PORT", str(port)) # il server la legge da qui (src/server/index.ts), lo eredita da questo processo
	_pid = OS.create_process(ProjectSettings.globalize_path(_exe()), [
		"--app-info=" + info_path,
		"--parent-pid=%d" % OS.get_process_id(),
		"--room=" + _room,
	])
	if _pid <= 0:
		_pid = 0
		failed.emit("Il server non parte.")
		return
	_waited = 0.0
	_timer.start()


# Il server scrive info.json quando il link è pronto, o quando il tunnel non arriva (si gioca in casa)
func _poll() -> void:
	_waited += POLL_S
	var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir() + "info.json")) if FileAccess.file_exists(_dir() + "info.json") else null
	if not info.is_empty():
		# Si gioca già: il tunnel lento arriva dopo (host.ts riscrive "ready") e il link deve cambiare, oppure
		# il tunnel cambia stato (riprova, motivo nuovo, si chiude) e l'avviso per chi ospita va aggiornato (#526)
		if read is Dictionary and read.get("state") in ["ready", "lan"] and read != info:
			var was_ready: bool = info.has("server")
			info = read
			if _retry_round != "" and (str(read.get("round", "")) != _retry_round or read.has("server")):
				_retry_round = ""
			if read.has("server") and not was_ready:
				tunnel_ready.emit(info)
			else:
				tunnel_changed.emit(info)
		elif not OS.is_process_running(_pid):
			_timer.stop()
		return
	if read is Dictionary and read.get("state") in ["ready", "lan"]:
		info = read
		ready_to_play.emit(info)
	elif read is Dictionary and read.get("state") == "error" and str(read.get("busy", "")) == "true" and _port > 0:
		# La prova della porta non vede tutto (es. un server solo su IPv6): si riparte dalla porta dopo
		_timer.stop()
		_pid = 0
		_launch()
	elif (read is Dictionary and read.get("state") == "error") or not OS.is_process_running(_pid) or _waited > START_TIMEOUT_S:
		_timer.stop()
		stop()
		failed.emit(str(read.get("error", "")) if read is Dictionary and read.has("error") else "Il server non si è acceso.")


func _url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--host-from="):
			return a.trim_prefix("--host-from=").trim_suffix("/") + "/bonobo-server-%s.zip" % _platform()
	return RELEASE_URL % [_build_version(), _platform()]


# La prima porta libera da FIRST_PORT in su: si prova ad aprirla e la si richiude subito
static func _free_port(from: int) -> int:
	for port in range(from, FIRST_PORT + PORT_TRIES):
		var probe := TCPServer.new()
		if probe.listen(port) == OK:
			probe.stop()
			return port
	return 0


func _dir() -> String:
	return DIR + "v%d/" % _build_version()


func _exe() -> String:
	return _dir() + ("bonobo-server.exe" if OS.has_feature("windows") else "bonobo-server")


static func _build_version() -> int:
	if not FileAccess.file_exists("res://data/build.json"): # c'è solo nell'app costruita da app.yml
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
	return int(data.get("version", 0)) if data is Dictionary else 0


# Il nome dello zip nella Release (app.yml, job server)
static func _platform() -> String:
	if OS.has_feature("windows"):
		return "windows"
	if OS.has_feature("macos"):
		return "mac" if Engine.get_architecture_name() == "arm64" else "mac-intel"
	if OS.has_feature("linuxbsd") and Engine.get_architecture_name() == "x86_64":
		return "linux"
	return ""
