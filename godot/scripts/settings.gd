# Preferenze di chi gioca (volumi, tasti) e ultimo profilo usato (nome, stanza, lottatore, arena, regole),
# come src/client/settings.ts e network.ts. Si salvano in user://: nel browser finiscono
# nell'archivio della pagina, su desktop nella cartella dei dati di Godot.
class_name Settings
extends RefCounted

signal changed

const PATH := "user://bonobo.cfg"
# Le azioni che si possono assegnare a un tasto (le stesse di InputState)
const ACTIONS := ["left", "right", "up", "down", "light", "heavy", "taunt", "dodge"]
const LABELS := {
	"left": "Sinistra",
	"right": "Destra",
	"up": "Salto",
	"down": "Giù / scendi",
	"light": "Attacco leggero",
	"heavy": "Attacco pesante",
	"taunt": "Provocazione",
	"dodge": "Schivata",
}
# I tasti di default del gioco web (DEFAULT_BINDINGS), come tasti fisici: non dipendono dalla lingua della tastiera
const DEFAULT_BINDINGS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"up": [KEY_W, KEY_UP, KEY_SPACE],
	"down": [KEY_S, KEY_DOWN],
	"light": [KEY_J],
	"heavy": [KEY_K],
	"taunt": [KEY_T],
	"dodge": [KEY_L],
}
const MAX_KEYS := 3 # tasti per azione

var master := 0.8
var sfx := 0.7
var music := 0.35
var music_on := true
var bindings := {}
var profile := {} # name, room, char, stage, rules, server

var _defaults := {}
var _path := PATH


# path: dove salvare, cambiato solo dai test per non toccare le preferenze di chi li lancia
func _init(audio_defaults: Dictionary, path := PATH) -> void:
	_path = path
	_defaults = {"master": audio_defaults.master, "sfx": audio_defaults.sfx, "music": audio_defaults.music}
	reset(false)
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	master = clampf(cfg.get_value("audio", "master", master), 0, 1)
	sfx = clampf(cfg.get_value("audio", "sfx", sfx), 0, 1)
	music = clampf(cfg.get_value("audio", "music", music), 0, 1)
	music_on = bool(cfg.get_value("audio", "music_on", music_on))
	# Tasti: si tengono solo le azioni salvate bene, le altre restano al default
	for a in ACTIONS:
		# Con default null Godot lo considera "nessun default" e stampa un errore se la chiave manca
		var keys: Variant = cfg.get_value("keys", a) if cfg.has_section_key("keys", a) else null
		if keys is Array and keys.all(func(k): return k is int):
			bindings[a] = keys.slice(0, MAX_KEYS)
	var p: Variant = cfg.get_value("profile", "last", {})
	if p is Dictionary:
		profile = p


func reset(notify := true) -> void:
	master = _defaults.master
	sfx = _defaults.sfx
	music = _defaults.music
	music_on = true
	bindings = DEFAULT_BINDINGS.duplicate(true)
	if notify:
		save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "music_on", music_on)
	for a in ACTIONS:
		cfg.set_value("keys", a, bindings[a])
	cfg.set_value("profile", "last", profile)
	cfg.save(_path) # se non si può salvare, le preferenze valgono solo per questa volta
	changed.emit()


func is_pressed(action: String) -> bool:
	for k in bindings[action]:
		if Input.is_physical_key_pressed(k):
			return true
	return false


# Un tasto fa una sola azione: se era già usato altrove, lì si toglie.
# keycode = 0 toglie il tasto in quella posizione.
func assign(action: String, slot: int, keycode: int) -> void:
	for a in ACTIONS:
		bindings[a] = bindings[a].filter(func(k): return k != keycode)
	var list: Array = bindings[action]
	if keycode != 0:
		if slot < list.size():
			list[slot] = keycode
		else:
			list.append(keycode)
	elif slot < list.size():
		list.remove_at(slot)
	bindings[action] = list.slice(0, MAX_KEYS)
	save()


static func key_label(keycode: int) -> String:
	match keycode:
		# Le frecce disegnate mancano nel font di base: meglio a parole
		KEY_LEFT: return "Freccia sinistra"
		KEY_RIGHT: return "Freccia destra"
		KEY_UP: return "Freccia su"
		KEY_DOWN: return "Freccia giù"
		KEY_SPACE: return "Spazio"
	return OS.get_keycode_string(keycode)
