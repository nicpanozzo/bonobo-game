# Preferenze di chi gioca (volumi, tasti) e ultimo profilo usato (nome, stanza, lottatore, arena, regole).
# Si salvano in user://: nel browser finiscono
# nell'archivio della pagina, su desktop nella cartella dei dati di Godot.
class_name Settings
extends RefCounted

signal changed

const PATH := "user://bonobo.cfg"
# Le azioni che si possono assegnare a un tasto (le stesse di InputState)
const ACTIONS := ["left", "right", "up", "jump", "down", "light", "heavy", "taunt", "dodge", "shield", "special", "supreme", "run"]
const LABELS := {
	"left": "Sinistra",
	"right": "Destra",
	"up": "Su",
	"jump": "Salto",
	"down": "Giù / scendi",
	"light": "Attacco leggero",
	"heavy": "Attacco pesante",
	"taunt": "Provocazione",
	"dodge": "Schivata",
	"shield": "Scudo",
	"special": "Speciale",
	"supreme": "Suprema",
	"run": "Corsa",
}
# I tasti di default del gioco web (DEFAULT_BINDINGS), come tasti fisici: non dipendono dalla lingua della tastiera
const DEFAULT_BINDINGS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"up": [KEY_W, KEY_UP], # sulla tastiera su fa anche saltare, vedi jump_pressed()
	"jump": [KEY_SPACE], # salto separato da su (E10)
	"down": [KEY_S, KEY_DOWN],
	"light": [KEY_J],
	"heavy": [KEY_K],
	"taunt": [KEY_T],
	"dodge": [], # la schivata è sullo scudo (scudo + direzione, scudo in aria): il tasto a parte resta per chi lo vuole
	"shield": [KEY_I], # scudo (#109)
	"special": [KEY_U], # mosse speciali (E10)
	"supreme": [KEY_O], # suprema con la barra piena (#101), scorciatoia di Speciale + Pesante insieme: I è già lo scudo
	"run": [KEY_SHIFT], # tenuto con una direzione si corre; il pesante correndo è l'attacco in corsa
}
const MAX_KEYS := 3 # tasti per azione
# Pad (E6): un pulsante è il suo JOY_BUTTON_*; una levetta o un grilletto inclinati
# sono AXIS_BASE + asse * 2 (+1 se verso il positivo), vedi axis_input()
const AXIS_BASE := 1000
const DEFAULT_PAD_BINDINGS := {
	"left": [AXIS_BASE + JOY_AXIS_LEFT_X * 2, JOY_BUTTON_DPAD_LEFT],
	"right": [AXIS_BASE + JOY_AXIS_LEFT_X * 2 + 1, JOY_BUTTON_DPAD_RIGHT],
	# Sul pad su è solo una direzione: la levetta in su per un attacco non fa saltare (E10)
	"up": [AXIS_BASE + JOY_AXIS_LEFT_Y * 2, JOY_BUTTON_DPAD_UP],
	"jump": [JOY_BUTTON_A],
	"down": [AXIS_BASE + JOY_AXIS_LEFT_Y * 2 + 1, JOY_BUTTON_DPAD_DOWN],
	"light": [JOY_BUTTON_X],
	"heavy": [JOY_BUTTON_B],
	"taunt": [JOY_BUTTON_BACK],
	"special": [JOY_BUTTON_Y], # mosse speciali (E10)
	"supreme": [], # suprema (#101): Speciale + Pesante insieme (Y + B), niente tasto a parte
	"dodge": [], # la schivata è sullo scudo, come in Smash
	"run": [JOY_BUTTON_RIGHT_SHOULDER], # la corsa sul dorsale destro, che prima era una seconda schivata
	# Lo scudo (#109) sui grilletti, come nei platform fighter
	"shield": [AXIS_BASE + JOY_AXIS_TRIGGER_LEFT * 2 + 1, AXIS_BASE + JOY_AXIS_TRIGGER_RIGHT * 2 + 1],
}
const MAX_PAD := 4 # pulsanti per azione
# Video (E14): finestra, vsync e FPS solo su desktop, nel web decide il browser. Si applicano con Video.apply()
const VIDEO_DEFAULTS := {
	"fullscreen": false,
	"window": 0, # indice in Video.WINDOW_SIZES
	"vsync": true,
	"max_fps": 0, # indice in Video.FPS_LIMITS (0 = senza limite)
	"effects": true, # scie e polvere
	"post": true, # luce e colori dell'arena (post_fx.gd): bagliore, colori per arena, vignetta e grana
	"predict": true, # il proprio lottatore previsto (E17): risponde subito anche con un server lontano
	"hitboxes": true, # rettangolo del colpo in corso sopra gli sprite
	"fps_counter": false, # FPS e ms per fotogramma in alto a destra (#529)
}
# Accessibilità (E14): si applicano con Access.apply()
const ACCESS_DEFAULTS := {
	"calm": false, # meno scossa e lampi
	"colorblind": false, # palette per daltonici
	"text_size": 0, # indice in Access.TEXT_SCALES
}
# Comandi touch (E18): si applicano con TouchControls.configure()
const TOUCH_DEFAULTS := {
	"size": 1, # indice in TouchControls.SIZES
	"opacity": 1, # indice in TouchControls.OPACITIES
	"left_handed": false, # levetta a destra e tasti a sinistra
	"screen": 0, # Phone.AUTO, PHONE o COMPUTER: la modalità telefono, con menu e scritte più grandi
}
# Chat vocale (voice.gd): si applicano subito, anche a chiamata in corso
const VOICE_DEFAULTS := {
	"auto_join": false, # entra in voce da solo appena entri in una stanza (il microfono si chiede solo allora)
	"mode": "vad", # "vad" parla e basta (a voce), "ptt" solo col tasto premuto: in partita le mani sono sui tasti
	"vad_threshold": 0.45, # soglia della voce, livello da 0 (-60 dB) a 1 (0 dB)
	"device": "", # id del microfono nel browser, "" = quello di sistema
	"volume": 1.0, # volume delle voci degli altri, da 0 a 2 (200%)
	"spatial": true, # in sala chi è lontano si sente più piano e da destra o sinistra
	"sounds": true, # i bip di entrata, uscita e microfono
}
# I tasti della voce, fuori da ACTIONS perché non vanno al server. N e B: M è già la musica
const VOICE_KEY_DEFAULTS := {"ptt": [KEY_V], "mute": [KEY_N], "deafen": [KEY_B]}
const VOICE_LABELS := {"ptt": "Parla (tieni premuto)", "mute": "Microfono sì/no", "deafen": "Audio sì/no"}
const VOICE_PREFIX := "voice:" # assign() dice "voice:ptt" quando toglie un tasto alla voce

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
var touch := {} # come TOUCH_DEFAULTS
var p2_pad := -1 # il pad del secondo giocatore sullo stesso schermo (second_player.gd): il primo non lo legge. Non si salva
var medals := {} # sfide (E15): id → {"medal": 1-3, "best": punteggio migliore}, sezione [medals]
var voice := {} # come VOICE_DEFAULTS
var voice_keys := {} # come VOICE_KEY_DEFAULTS
var voice_volumes := {} # nome del giocatore → volume da 0 a 2: per nome perché l'id cambia a ogni stanza
var voice_muted := {} # nome → true: silenziato solo per me

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
	for k in TOUCH_DEFAULTS:
		var v: Variant = cfg.get_value("touch", k) if cfg.has_section_key("touch", k) else null
		if typeof(v) == typeof(TOUCH_DEFAULTS[k]):
			touch[k] = v
	# Un'azione nuova che non era salvata (es. lo scudo) prende i suoi tasti di default anche se
	# le preferenze vecchie li davano a un'altra: un tasto fa una sola azione
	for a in ACTIONS:
		for section in ["keys", "pad"]:
			if not cfg.has_section_key(section, a):
				var all: Dictionary = bindings if section == "keys" else pad_bindings
				for other in ACTIONS:
					if other != a:
						all[other] = all[other].filter(func(k): return not all[a].has(k))
	for k in VOICE_DEFAULTS:
		var v: Variant = cfg.get_value("voice", k) if cfg.has_section_key("voice", k) else null
		if v != null and (typeof(v) == typeof(VOICE_DEFAULTS[k]) or (v is int and VOICE_DEFAULTS[k] is float)):
			voice[k] = float(v) if VOICE_DEFAULTS[k] is float else v
	for k in VOICE_KEY_DEFAULTS:
		var keys: Variant = cfg.get_value("voice_keys", k) if cfg.has_section_key("voice_keys", k) else null
		if keys is Array and keys.all(func(c): return c is int):
			voice_keys[k] = keys.slice(0, MAX_KEYS)
		elif keys == null: # mai salvato: V, N o B già dati a un'azione del gioco restano a lei
			voice_keys[k] = voice_keys[k].filter(func(c): return not _game_key_used(c))
	var vols: Variant = cfg.get_value("voice", "volumes", {}) if cfg.has_section_key("voice", "volumes") else {}
	if vols is Dictionary:
		for n in vols:
			if vols[n] is float or vols[n] is int:
				voice_volumes[str(n)] = clampf(float(vols[n]), 0.0, 2.0)
	var mutes: Variant = cfg.get_value("voice", "muted", {}) if cfg.has_section_key("voice", "muted") else {}
	if mutes is Dictionary:
		for n in mutes:
			if mutes[n] == true:
				voice_muted[str(n)] = true
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
	touch = TOUCH_DEFAULTS.duplicate()
	voice = VOICE_DEFAULTS.duplicate() # i volumi per giocatore restano, come le medaglie
	voice_keys = VOICE_KEY_DEFAULTS.duplicate(true)
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
		# I tasti del gioco tornano quelli di default: un tasto della voce spostato lì lascia il posto
		for a in voice_keys:
			voice_keys[a] = voice_keys[a].filter(func(k): return not _game_key_used(k))
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
	for k in touch:
		cfg.set_value("touch", k, touch[k])
	for k in voice:
		cfg.set_value("voice", k, voice[k])
	cfg.set_value("voice", "volumes", voice_volumes)
	cfg.set_value("voice", "muted", voice_muted)
	for k in voice_keys:
		cfg.set_value("voice_keys", k, voice_keys[k])
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


# Tastiera o qualsiasi pad collegato, tranne quello del secondo giocatore
func is_pressed(action: String) -> bool:
	for k in bindings[action]:
		if Input.is_physical_key_pressed(k):
			return true
	for device in Input.get_connected_joypads():
		if device != p2_pad and pad_pressed(action, device):
			return true
	return false


# Solo un pad: quello del secondo giocatore
func pad_pressed(action: String, device: int) -> bool:
	for code in pad_bindings[action]:
		if code >= AXIS_BASE:
			if axis_active(Input.get_joy_axis(device, (code - AXIS_BASE) / 2), code % 2, stick_deadzone):
				return true
		elif Input.is_joy_button_pressed(device, code):
			return true
	return false


# Il salto: il suo tasto, oppure su dalla tastiera (come in Brawlhalla: chi gioca con W salta con W)
func jump_pressed() -> bool:
	if is_pressed("jump"):
		return true
	for k in bindings.up:
		if Input.is_physical_key_pressed(k):
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
	if not pad and code != none: # anche la voce cede il tasto
		for a in voice_keys:
			if voice_keys[a].has(code):
				taken_from = VOICE_PREFIX + a
			voice_keys[a] = voice_keys[a].filter(func(k): return k != code)
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


# Un tasto per la voce (Parla, Microfono, Audio), come assign(): se era di un'altra azione lì si toglie.
# code = 0 toglie il tasto. Restituisce da dove l'ha preso (un'azione del gioco o "voice:...")
func assign_voice(action: String, code: int) -> String:
	var taken_from := ""
	if code != 0:
		for a in ACTIONS:
			if bindings[a].has(code):
				taken_from = a
			bindings[a] = bindings[a].filter(func(k): return k != code)
		for a in voice_keys:
			if a != action and voice_keys[a].has(code):
				taken_from = VOICE_PREFIX + a
			voice_keys[a] = voice_keys[a].filter(func(k): return k != code)
	voice_keys[action] = [code] if code != 0 else []
	save()
	return taken_from


# Un tasto della voce premuto (solo tastiera: sul pad i pulsanti sono tutti del gioco)
func voice_pressed(action: String) -> bool:
	for k in voice_keys.get(action, []):
		if Input.is_physical_key_pressed(k):
			return true
	return false


func _game_key_used(code: int) -> bool:
	for a in ACTIONS:
		if bindings[a].has(code):
			return true
	return false


# Nome da mostrare di un'azione del gioco o della voce ("voice:ptt")
static func action_label(action: String) -> String:
	if action.begins_with(VOICE_PREFIX):
		return "Voce: " + str(VOICE_LABELS.get(action.trim_prefix(VOICE_PREFIX), action)).to_lower()
	return str(LABELS.get(action, action))


# Il primo tasto di un'azione della voce, da scrivere negli avvisi ("Premi V per parlare"); "" se non ce l'ha
func voice_key_label(action: String) -> String:
	var keys: Array = voice_keys.get(action, [])
	return key_label(int(keys[0])) if not keys.is_empty() else ""


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
		KEY_SHIFT: return "Maiusc"
	return OS.get_keycode_string(keycode)
