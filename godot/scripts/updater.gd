# Prima scena dell'app desktop (#115): prende da sola l'ultima versione del gioco e poi apre main.tscn.
# Confronta la sua versione (data/build.json, scritto da app.yml) con bonobo-game-version.json dell'ultima
# Release; se è più nuova e il motore è lo stesso scarica bonobo-game.pck in user://update/ e riparte
# con quel pacchetto (--main-pack), così anche script, classi e impostazioni nuove valgono per intero.
# Offline, GitHub lento o download rotto: si gioca con quello che c'è. Nel web e nell'editor non fa niente.
# Per provarlo in locale: godot --path godot -- --update-from=http://localhost:8000/
# Va tenuto piccolo e stabile: è la versione vecchia di questo file a scaricare quella nuova.
extends Control

const RELEASE_URL := "https://github.com/nicpanozzo/bonobo-game/releases/latest/download/"
const VERSION_FILE := "bonobo-game-version.json"
const PACK_FILE := "bonobo-game.pck"
const UPDATE_DIR := "user://update/"
const CHECK_TIMEOUT_S := 5.0 # oltre, si gioca con la versione che c'è
const DOWNLOAD_TIMEOUT_S := 180.0 # il pacchetto intero, anche con una rete lenta
const MAIN_SCENE := "res://main.tscn"

var _http := HTTPRequest.new()
var _bar := ProgressBar.new()
var _label := Label.new()
var _base := RELEASE_URL
var _remote := {}


func _ready() -> void:
	set_process(false) # la barra si muove solo durante il download
	var build := read_json("res://data/build.json")
	if build.has("version"):
		get_window().title = "Bonobo Game · v%d" % int(build.version)
		print("Bonobo Game v%d" % int(build.version))
	var from := _user_arg("update-from")
	if OS.has_feature("web") or (not OS.has_feature("template") and from == ""):
		_start_game.call_deferred()
		return
	if from != "":
		_base = from if from.ends_with("/") else from + "/"
	var current := int(build.get("version", 0))
	# Un pacchetto già scaricato e più nuovo si usa subito, anche offline
	var saved := read_json(UPDATE_DIR + VERSION_FILE)
	if not _running_from_update() and use_saved(current, saved, engine_version()) and _relaunch():
		return
	_build_ui()
	add_child(_http)
	_http.timeout = CHECK_TIMEOUT_S
	_http.request_completed.connect(_on_version, CONNECT_ONE_SHOT)
	if _http.request(_base + VERSION_FILE) != OK:
		_start_game()


func _process(_delta: float) -> void:
	_bar.value = 100.0 * _http.get_downloaded_bytes() / float(_remote["size"])


func _on_version(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_remote = parse_remote(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else {}
	var current := int(read_json("res://data/build.json").get("version", 0))
	if decide(current, _remote, engine_version()) != "download":
		# "new_app" (motore diverso) arriva col passo 3: per ora si gioca con quello che c'è
		_start_game()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPDATE_DIR))
	_label.text = "Scarico la versione %s del gioco..." % _remote.version
	_bar.visible = true
	set_process(true)
	_http.timeout = DOWNLOAD_TIMEOUT_S
	_http.download_file = UPDATE_DIR + PACK_FILE + ".part" # mai il file vero, finché non è completo
	_http.request_completed.connect(_on_pack, CONNECT_ONE_SHOT)
	if _http.request(_base + PACK_FILE) != OK:
		_start_game()


func _on_pack(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var part := ProjectSettings.globalize_path(UPDATE_DIR + PACK_FILE + ".part")
	var size := FileAccess.get_size(UPDATE_DIR + PACK_FILE + ".part") if FileAccess.file_exists(UPDATE_DIR + PACK_FILE + ".part") else -1
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or size != int(_remote["size"]):
		DirAccess.remove_absolute(part)
		_start_game()
		return
	# Prima il pacchetto, poi la sua versione: se ci si ferma a metà resta la versione vecchia
	var pack := ProjectSettings.globalize_path(UPDATE_DIR + PACK_FILE)
	DirAccess.remove_absolute(pack)
	if DirAccess.rename_absolute(part, pack) != OK:
		_start_game()
		return
	var f := FileAccess.open(UPDATE_DIR + VERSION_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(_remote))
	f.close()
	if not _relaunch():
		_start_game()


# Riparte con il pacchetto scaricato al posto di quello dentro l'app, con gli stessi argomenti
func _relaunch() -> bool:
	var pack := ProjectSettings.globalize_path(UPDATE_DIR + PACK_FILE)
	if not FileAccess.file_exists(pack):
		return false
	var args := relaunch_args(OS.get_cmdline_args(), OS.get_cmdline_user_args(), pack)
	if DisplayServer.get_name() == "headless": # Godot non lo ripete in get_cmdline_args (prove e CI)
		args.insert(0, "--headless")
	if OS.create_process(OS.get_executable_path(), args) <= 0:
		return false
	print("Riparto con il gioco aggiornato: ", pack)
	get_tree().quit()
	return true


func _running_from_update() -> bool:
	return OS.get_cmdline_args().has("--main-pack")


func _start_game() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position -= box.custom_minimum_size / 2
	add_child(box)
	_label.text = "Cerco aggiornamenti..."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_bar.visible = false
	_bar.custom_minimum_size = Vector2(420, 24)
	box.add_child(_bar)


func _user_arg(key: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.split("=", true, 1)[1]
	return ""


# --- Logica pura, provata in tests/test_updater.gd ---

# La versione del motore scritta come GODOT_VERSION in app.yml: "4.5.1", oppure "4.5" se la patch è 0
static func engine_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d" % [v.major, v.minor] + (".%d" % v.patch if v.patch > 0 else "")


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


# {version, godot, size} se il file della Release è valido, altrimenti {}
static func parse_remote(text: String) -> Dictionary:
	var json := JSON.new() # non JSON.parse_string: una pagina d'errore non deve riempire il log
	if json.parse(text) != OK:
		return {}
	var data = json.data
	if not (data is Dictionary and data.get("version") is float and data.get("godot") is String and data.get("size") is float):
		return {}
	if data.version < 1 or data["size"] < 1:
		return {}
	return {"version": int(data.version), "godot": data.godot, "size": int(data["size"])}


# "download" se c'è un gioco più nuovo per questo motore, "new_app" se serve un motore diverso, altrimenti "none"
static func decide(current: int, remote: Dictionary, engine: String) -> String:
	if remote.is_empty() or int(remote.version) <= current:
		return "none"
	return "download" if remote.godot == engine else "new_app"


# Il pacchetto scaricato in un avvio precedente vale solo se è più nuovo dell'app e per lo stesso motore
static func use_saved(current: int, saved: Dictionary, engine: String) -> bool:
	return saved.has("version") and int(saved.version) > current and saved.get("godot") == engine


# Gli argomenti di questo avvio, senza --path o un --main-pack precedente, più il pacchetto nuovo
static func relaunch_args(args: PackedStringArray, user_args: PackedStringArray, pack: String) -> PackedStringArray:
	var out := PackedStringArray(["--main-pack", pack])
	var skip := false
	for a in args:
		if skip:
			skip = false
		elif a in ["--path", "--main-pack"]:
			skip = true
		elif not (a.begins_with("--path=") or a.begins_with("--main-pack=")):
			out.append(a)
	if not user_args.is_empty():
		out.append("--")
		out.append_array(user_args)
	return out
