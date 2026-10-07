# Preferenze di chi gioca (volumi, tasti) e ultimo profilo usato (nome, stanza, lottatore, arena, regole),
# come src/client/settings.ts e network.ts. Si salvano in user://: nel browser finiscono
# nell'archivio della pagina, su desktop nella cartella dei dati di Godot.
class_name Settings
extends RefCounted

signal changed

const PATH := "user://bonobo.cfg"
# Le azioni che si possono assegnare a un tasto (le stesse di InputState)
const ACTIONS := ["left", "right", "up", "down", "light", "heavy", "taunt", "dodge", "shield"]
const LABELS := {
	"left": "Sinistra",
	"right": "Destra",
	"up": "Salto",
	"down": "Giù / scendi",
	"light": "Attacco leggero",
	"heavy": "Attacco pesante",
	"taunt": "Provocazione",
	"dodge": "Schivata",
	"shield": "Scudo",
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
	"shield": [KEY_I], # scudo (#109)
}
const MAX_KEYS := 3 # tasti per azione
# Pad (E6): un pulsante è il suo JOY_BUTTON_*; una levetta o un grilletto inclinati
# sono AXIS_BASE + asse * 2 (+1 se verso il positivo), vedi axis_input()
const AXIS_BASE := 1000
const DEFAULT_PAD_BINDINGS := {
	"left": [AXIS_BASE + JOY_AXIS_LEFT_X * 2, JOY_BUTTON_DPAD_LEFT],
	"right": [AXIS_BASE + JOY_AXIS_LEFT_X * 2 + 1, JOY_BUTTON_DPAD_RIGHT],
	"up": [JOY_BUTTON_A, AXIS_BASE + JOY_AXIS_LEFT_Y * 2, JOY_BUTTON_DPAD_UP],
	"down": [AXIS_BASE + JOY_AXIS_LEFT_Y * 2 + 1, JOY_BUTTON_DPAD_DOWN],
	"light": [JOY_BUTTON_X],
	"heavy": [JOY_BUTTON_B],
	"taunt": [JOY_BUTTON_BACK],
	# Y resta libero per la speciale (E10)
	"dodge": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER],
	# Lo scudo (#109) sui grilletti, come nei platform fighter
	"shield": [AXIS_BASE + JOY_AXIS_TRIGGER_LEFT * 2 + 1, AXIS_BASE + JOY_AXIS_TRIGGER_RIGHT * 2 + 1],
}
const MAX_PAD := 4 # pulsanti per azione
# Video (E14): solo su desktop, nel web decide il browser. Si applicano con Video.apply()
const VIDEO_DEFAULTS := {
	"fullscreen": false,
	"window": 0, # indice in Video.WINDOW_SIZES
	"vsync": true,
	"max_fps": 0, # indice in Video.FPS_LIMITS (0 = senza limite)
	"effects": true, # scie e polvere
}
# Accessibilità (E14): si applicano con Access.apply()
const ACCESS_DEFAULTS := {
	"calm": false, # meno scossa e lampi
	"colorblind": false, # palette per daltonici
	"text_size": 0, # indice in Access.TEXT_SCALES
}

var master := 0.8
var sfx := 0.7
var music := 0.35
var music_on := true
var voices := 0.8 # personaggi e annunciatore (E13)
var bindings := {}
var pad_bindings := {}
var rumble := Rumble.STRONG # vibrazione del pad: Rumble.OFF, WEAK o STRONG
var stick_deadzone := 0.35 # main.gd mette INPUT.stickDeadzone di game.json
var profile := {} # name, room, char, stage, rules, server
var first_run_done := false # primo avvio guidato (E14) già fatto o saltato: Ripristina non lo rimette
var video := {} # come VIDEO_DEFAULTS
var access := {} # come ACCESS_DEFAULTS
var medals := {} # sfide (E15): id → {"medal": 1-3, "best": punteggio migliore}, sezione [medals]

var _defaults := {}
var _path := PATH


# path: dove salvare, cambiato solo dai test per non toccare le preferenze di chi li lancia
func _init(audio_defaults: Dictionary, path := PATH) -> void:
	_path = path
	_defaults = {"master": audio_defaults.master, "sfx": audio_defaults.sfx, "music": audio_defaults.music, "voices": audio_defaults.get("voices", 0.8)}
	reset(false)
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	master = clampf(cfg.get_value("audio", "master", master), 0, 1)
	sfx = clampf(cfg.get_value("audio", "sfx", sfx), 0, 1)
	music = clampf(cfg.get_value("audio", "music", music), 0, 1)
	music_on = bool(cfg.get_value("audio", "music_on", music_on))
	voices = clampf(cfg.get_value("audio", "voices", voices), 0, 1)
	var r: Variant = cfg.get_value("pad_options", "rumble", rumble)
	if r is int and r >= Rumble.OFF and r <= Rumble.STRONG:
		rumble = r
	# Tasti: si tengono solo le azioni salvate bene, le altre restano al default
	for a in ACTIONS:
		# Con default null Godot lo considera "nessun default" e stampa un errore se la chiave manca
		var keys: Variant = cfg.get_value("keys", a) if cfg.has_section_key("keys", a) else null
		if keys is Array and keys.all(func(k): return k is int):
			bindings[a] = keys.slice(0, MAX_KEYS)
		var pad: Variant = cfg.get_value("pad", a) if cfg.has_section_key("pad", a) else null
		if pad is Array and pad.all(func(k): return k is int and k >= 0):
			pad_bindings[a] = pad.slice(0, MAX_PAD)
	for k in VIDEO_DEFAULTS:
		var v: Variant = cfg.get_value("video", k) if cfg.has_section_key("video", k) else null
		if typeof(v) == typeof(VIDEO_DEFAULTS[k]):
			video[k] = v
	for k in ACCESS_DEFAULTS:
		var v: Variant = cfg.get_value("access", k) if cfg.has_section_key("access", k) else null
		if typeof(v) == typeof(ACCESS_DEFAULTS[k]):
			access[k] = v
	# Un'azione nuova che non era salvata (es. lo scudo) prende i suoi tasti di default anche se
	# le preferenze vecchie li davano a un'altra: un tasto fa una sola azione
	for a in ACTIONS:
		for section in ["keys", "pad"]:
			if not cfg.has_section_key(section, a):
				var all: Dictionary = bindings if section == "keys" else pad_bindings
				for other in ACTIONS:
					if other != a:
						all[other] = all[other].filter(func(k): return not all[a].has(k))
	first_run_done = cfg.get_value("first_run", "done", false) == true
	var p: Variant = cfg.get_value("profile", "last", {})
	if p is Dictionary:
		profile = p
	if cfg.has_section("medals"):
		for id in cfg.get_section_keys("medals"):
			var m: Variant = cfg.get_value("medals", id)
			if m is Dictionary:
				medals[id] = m


func reset(notify := true) -> void:
	master = _defaults.master
	sfx = _defaults.sfx
	music = _defaults.music
	music_on = true
	voices = _defaults.voices
	rumble = Rumble.STRONG
	video = VIDEO_DEFAULTS.duplicate()
	access = ACCESS_DEFAULTS.duplicate()
	reset_bindings(false, false)
	reset_bindings(true, false)
	if notify:
		save()


# Tasti di default solo per la tastiera o solo per il pad ("Ripristina" nelle opzioni)
func reset_bindings(pad: bool, notify := true) -> void:
	if pad:
		pad_bindings = DEFAULT_PAD_BINDINGS.duplicate(true)
	else:
		bindings = DEFAULT_BINDINGS.duplicate(true)
	if notify:
		save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "voices", voices)
	cfg.set_value("pad_options", "rumble", rumble)
	for a in ACTIONS:
		cfg.set_value("keys", a, bindings[a])
		cfg.set_value("pad", a, pad_bindings[a])
	for k in video:
		cfg.set_value("video", k, video[k])
	for k in access:
		cfg.set_value("access", k, access[k])
	cfg.set_value("profile", "last", profile)
	cfg.set_value("first_run", "done", first_run_done)
	for id in medals:
		cfg.set_value("medals", id, medals[id])
	cfg.save(_path) # se non si può salvare, le preferenze valgono solo per questa volta
	changed.emit()


# Un tentativo di sfida finito: tiene il punteggio migliore e la medaglia migliore, e salva.
# Restituisce true se è il nuovo record. Ripristina nelle opzioni non tocca le medaglie
func record_medal(id: String, medal: int, score: float, lower_is_better: bool) -> bool:
	var old: Dictionary = medals.get(id, {})
	var best: bool = old.is_empty() or (score < float(old.best) if lower_is_better else score > float(old.best))
	if not best and medal <= int(old.get("medal", 0)):
		return false
	medals[id] = {"medal": maxi(medal, int(old.get("medal", 0))), "best": score if best else float(old.best)}
	save()
	return best


# Tastiera o qualsiasi pad collegato
func is_pressed(action: String) -> bool:
	for k in bindings[action]:
		if Input.is_physical_key_pressed(k):
			return true
	for device in Input.get_connected_joypads():
		for code in pad_bindings[action]:
			if code >= AXIS_BASE:
				if axis_active(Input.get_joy_axis(device, (code - AXIS_BASE) / 2), code % 2, stick_deadzone):
					return true
			elif Input.is_joy_button_pressed(device, code):
				return true
	return false


static func axis_input(axis: int, positive: bool) -> int:
	return AXIS_BASE + axis * 2 + (1 if positive else 0)


# positive: 1 se conta l'inclinazione verso il positivo (destra, giù, grilletto premuto), 0 verso il negativo
static func axis_active(value: float, positive: int, deadzone: float) -> bool:
	return value > deadzone if positive == 1 else value < -deadzone


# Un tasto fa una sola azione: se era già usato altrove, lì si toglie, e si dice da dove
# (nome dell'azione, "" se era libero). code = 0 toglie il tasto in quella posizione.
# pad: code è un pulsante o una levetta del pad (vedi AXIS_BASE) invece di un tasto.
# Nota: sul pad 0 è JOY_BUTTON_A, quindi per toglierlo si passa -1.
func assign(action: String, slot: int, code: int, pad := false) -> String:
	var all: Dictionary = pad_bindings if pad else bindings
	var none := -1 if pad else 0
	var taken_from := ""
	for a in ACTIONS:
		if a != action and code != none and all[a].has(code):
			taken_from = a
		all[a] = all[a].filter(func(k): return k != code)
	var list: Array = all[action]
	if code != none:
		if slot < list.size():
			list[slot] = code
		else:
			list.append(code)
	elif slot < list.size():
		list.remove_at(slot)
	all[action] = list.slice(0, MAX_PAD if pad else MAX_KEYS)
	save()
	return taken_from


# Che pad è: cambiano i nomi dei pulsanti, non la loro posizione (Godot usa quella di SDL)
static func pad_kind(joy_name: String) -> String:
	var n := joy_name.to_lower()
	for word in ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]:
		if word in n:
			return "ps"
	for word in ["nintendo", "switch", "joy-con", "pro controller"]:
		if word in n:
			return "switch"
	return "xbox"


const PAD_BUTTON_NAMES := {
	"xbox": ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB"],
	"ps": ["Croce", "Cerchio", "Quadrato", "Triangolo", "Share", "PS", "Options", "L3", "R3", "L1", "R1"],
	# Switch: le lettere sono scambiate rispetto alla posizione (in basso c'è B)
	"switch": ["B", "A", "Y", "X", "-", "Home", "+", "L3", "R3", "L", "R"],
}
const PAD_TRIGGER_NAMES := {"xbox": ["LT", "RT"], "ps": ["L2", "R2"], "switch": ["ZL", "ZR"]}


# Nome di un pulsante o di una levetta (code come in pad_bindings) per il tipo di pad
static func pad_label(code: int, kind := "xbox") -> String:
	if code >= AXIS_BASE:
		var axis := (code - AXIS_BASE) / 2
		var positive := code % 2 == 1
		match axis:
			JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT:
				return PAD_TRIGGER_NAMES[kind][axis - JOY_AXIS_TRIGGER_LEFT]
			JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X:
				return ("LS " if axis == JOY_AXIS_LEFT_X else "RS ") + ("destra" if positive else "sinistra")
			_:
				return ("LS " if axis == JOY_AXIS_LEFT_Y else "RS ") + ("giù" if positive else "su")
	match code:
		JOY_BUTTON_DPAD_UP: return "Dir. su"
		JOY_BUTTON_DPAD_DOWN: return "Dir. giù"
		JOY_BUTTON_DPAD_LEFT: return "Dir. sinistra"
		JOY_BUTTON_DPAD_RIGHT: return "Dir. destra"
	var names: Array = PAD_BUTTON_NAMES[kind]
	return names[code] if code < names.size() else "Pulsante %d" % code


static func key_label(keycode: int) -> String:
	match keycode:
		# Le frecce disegnate mancano nel font di base: meglio a parole
		KEY_LEFT: return "Freccia sinistra"
		KEY_RIGHT: return "Freccia destra"
		KEY_UP: return "Freccia su"
		KEY_DOWN: return "Freccia giù"
		KEY_SPACE: return "Spazio"
	return OS.get_keycode_string(keycode)
