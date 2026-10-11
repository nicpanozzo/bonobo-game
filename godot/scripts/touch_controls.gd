# Comandi touch (E18): una levetta a sinistra e i tasti a destra, per giocare dal telefono.
# Diventano lo stesso InputState di tastiera e pad (main.gd._send_input): il server non sa da dove arrivano.
# La levetta è mobile: parte dove si appoggia il pollice, nella metà sinistra dello schermo.
# Ogni dito ha il suo controllo, così si può correre, saltare e attaccare insieme; scivolando
# da un tasto all'altro senza alzare il dito si passa al tasto nuovo.
# Compare con il primo tocco (o subito su un dispositivo touch) e sparisce usando tastiera o pad.
class_name TouchControls
extends Control

signal pause_pressed
signal free_tap # un tocco fuori dai comandi: a partita finita chiede la rivincita (main.gd)
signal extra_pressed(name: String) # un tasto in più, es. "panel" per il pannello dell'allenamento

# Coordinate nello schermo da 1280x720 del gioco (project.godot), centro e raggio di ogni tasto
const BUTTONS := {
	"jump": {"pos": Vector2(1180, 610), "r": 62.0, "label": "Salto"},
	"light": {"pos": Vector2(1050, 650), "r": 50.0, "label": "Leggero"},
	"heavy": {"pos": Vector2(1075, 525), "r": 50.0, "label": "Pesante"},
	"special": {"pos": Vector2(1195, 465), "r": 46.0, "label": "Speciale"},
	"shield": {"pos": Vector2(940, 560), "r": 42.0, "label": "Scudo"},
	"dodge": {"pos": Vector2(930, 670), "r": 42.0, "label": "Schiva"},
	"supreme": {"pos": Vector2(1210, 345), "r": 36.0, "label": "Suprema"},
}
const PAUSE := {"pos": Vector2(1236, 42), "r": 30.0} # in alto a destra, lontano dal tempo e dalla barra della suprema
const EXTRA_RECT := Rect2(1110, 92, 152, 46) # sotto la pausa: il primo tasto in più (gli altri scendono)
const STICK_HOME := Vector2(190, 560) # dove si disegna la levetta a riposo
const STICK_AREA_X := 560.0 # a sinistra di qui un tocco prende la levetta
const STICK_RADIUS := 110.0 # spostamento che conta come levetta tutta piegata
const STICK_DEAD := 0.35 # sotto questa frazione del raggio, in orizzontale, non si va da nessuna parte
const STICK_VERTICAL := 0.55 # su e giù vogliono una spinta più decisa, per non attaccare in su correndo
# Opzioni > Touch (E18 passo 3): indici salvati in Settings.touch
const SIZES := [0.8, 1.0, 1.25]
const SIZE_NAMES := ["Piccoli", "Normali", "Grandi"]
const OPACITIES := [0.5, 1.0, 1.6] # moltiplica la trasparenza di tasti e levetta
const OPACITY_NAMES := ["Leggeri", "Normali", "Marcati"]
const SCREEN := Vector2(1280, 720)

var active := false: # mostrati e letti: dopo un tocco, finché non si usa tastiera o pad
	set(v):
		if v != active:
			active = v
			queue_redraw()
var _stick_finger := -1
var _stick_origin := STICK_HOME
var _buttons: Dictionary = BUTTONS # i tasti con grandezza e lato scelti nelle opzioni
var _stick_home := STICK_HOME
var _stick_radius := STICK_RADIUS
var _alpha := 1.0
var _left_handed := false
var _stick_vec := Vector2.ZERO # spostamento del pollice dall'origine, al massimo STICK_RADIUS
var _fingers: Dictionary = {} # dito -> nome del tasto che tiene
var extras: Dictionary = {}: # tasti in più, nome -> scritta (main.gd li mette e li toglie)
	set(v):
		if v != extras:
			extras = v
			queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	active = DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		# Nei menu i tocchi sono dei bottoni: qui si ricorda solo con cosa si sta giocando
		if event is InputEventScreenTouch and event.pressed:
			active = true
		elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
			active = false
		if _stick_finger >= 0 or not _fingers.is_empty():
			release_all()
		return
	if handle(event):
		get_viewport().set_input_as_handled()


# Le preferenze di Settings.touch: grandezza (tasti e levetta crescono dal loro angolo), trasparenza e lato
func configure(prefs: Dictionary) -> void:
	var k: float = SIZES[clampi(int(prefs.get("size", 1)), 0, SIZES.size() - 1)]
	_alpha = OPACITIES[clampi(int(prefs.get("opacity", 1)), 0, OPACITIES.size() - 1)]
	_left_handed = bool(prefs.get("left_handed", false))
	_buttons = {}
	for action in BUTTONS:
		var b: Dictionary = BUTTONS[action]
		_buttons[action] = {"pos": _place(SCREEN + (b.pos - SCREEN) * k), "r": b.r * k, "label": b.label}
	_stick_home = _place(Vector2(0, SCREEN.y) + (STICK_HOME - Vector2(0, SCREEN.y)) * k)
	_stick_radius = STICK_RADIUS * k
	release_all()


# Per i mancini tutto a specchio, tranne pausa e tasti in più che restano in alto a destra
func _place(pos: Vector2) -> Vector2:
	return Vector2(SCREEN.x - pos.x, pos.y) if _left_handed else pos


func button_pos(action: String) -> Vector2:
	return _buttons[action].pos


# Un evento d'ingresso; true se l'ha usato un comando touch
func handle(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed() and active:
			active = false
			release_all()
		return false
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return false
	var pos := _local(event.position)
	if event is InputEventScreenTouch and event.pressed:
		active = true
		return _press(event.index, pos)
	if event is InputEventScreenTouch:
		var used: bool = event.index == _stick_finger or _fingers.has(event.index)
		_release(event.index)
		return used
	return _drag(event.index, pos)


func pressed(action: String) -> bool:
	if not active:
		return false
	match action:
		"left":
			return _stick_vec.x < -STICK_DEAD * _stick_radius
		"right":
			return _stick_vec.x > STICK_DEAD * _stick_radius
		"up":
			return _stick_vec.y < -STICK_VERTICAL * _stick_radius
		"down":
			return _stick_vec.y > STICK_VERTICAL * _stick_radius
	return _fingers.values().has(action)


func release_all() -> void:
	_stick_finger = -1
	_stick_vec = Vector2.ZERO
	_fingers.clear()
	queue_redraw()


static func extra_rect(i: int) -> Rect2:
	return Rect2(EXTRA_RECT.position + Vector2(0, i * (EXTRA_RECT.size.y + 10)), EXTRA_RECT.size)


# Dove sta un'azione sullo schermo, per le guide (primo avvio e tutorial)
static func hint(action: String) -> String:
	match action:
		"left":
			return "levetta a sinistra"
		"right":
			return "levetta a destra"
		"up":
			return "levetta in su"
		"down":
			return "levetta in giù"
	if BUTTONS.has(action):
		return "tasto %s" % BUTTONS[action].label
	return "solo da tastiera o pad" # la provocazione non ha un tasto a schermo


# Telefono in verticale: lo schermo da 16:9 diventa una striscia, meglio chiedere di girarlo
static func portrait(window: Vector2) -> bool:
	return window.y > window.x


# Il tasto sotto un punto, o "" se non ce n'è
func button_at(pos: Vector2) -> String:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if pos.distance_to(b.pos) <= b.r * 1.15: # un po' di margine: il pollice non è preciso
			return action
	return ""


func _press(finger: int, pos: Vector2) -> bool:
	if pos.distance_to(PAUSE.pos) <= PAUSE.r * 1.3:
		pause_pressed.emit()
		return true
	var i := 0
	for extra in extras:
		if extra_rect(i).grow(6).has_point(pos):
			extra_pressed.emit(extra)
			return true
		i += 1
	var action := button_at(pos)
	if action != "":
		_fingers[finger] = action
		queue_redraw()
		return true
	var stick_side := pos.x > SCREEN.x - STICK_AREA_X if _left_handed else pos.x < STICK_AREA_X
	if stick_side and _stick_finger < 0:
		_stick_finger = finger
		_stick_origin = pos
		_stick_vec = Vector2.ZERO
		queue_redraw()
		return true
	free_tap.emit()
	return false


func _drag(finger: int, pos: Vector2) -> bool:
	if finger == _stick_finger:
		_stick_vec = (pos - _stick_origin).limit_length(_stick_radius)
		queue_redraw()
		return true
	if _fingers.has(finger):
		var action := button_at(pos)
		if action != "" and action != _fingers[finger]:
			_fingers[finger] = action # scivolando su un altro tasto si passa a quello
			queue_redraw()
		return true
	return false


func _release(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		_stick_vec = Vector2.ZERO
	_fingers.erase(finger)
	queue_redraw()


func _white(a: float) -> Color:
	return Color(1, 1, 1, minf(1.0, a * _alpha))


func _local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _draw() -> void:
	if not active:
		return
	var font := get_theme_default_font()
	# Levetta: la base dove si è appoggiato il pollice, il pomello dove è adesso
	var held := _stick_finger >= 0
	var origin := _stick_origin if held else _stick_home
	draw_circle(origin, _stick_radius, _white(0.10 if held else 0.06))
	draw_arc(origin, _stick_radius, 0, TAU, 48, _white(0.35), 3.0, true)
	draw_circle(origin + _stick_vec, _stick_radius * 0.42, _white(0.45 if held else 0.25))
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		var down := _fingers.values().has(action)
		draw_circle(b.pos, b.r, _white(0.40 if down else 0.14))
		draw_arc(b.pos, b.r, 0, TAU, 40, _white(0.5), 2.5, true)
		var size := int(round((15.0 if b.r < 45.0 else 17.0) * b.r / BUTTONS[action].r))
		var w := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		draw_string(font, b.pos + Vector2(-w / 2.0, size * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, size, _white(0.85))
	var i := 0
	for extra in extras:
		var r := extra_rect(i)
		draw_rect(r, Color(1, 1, 1, 0.14))
		draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
		var w := font.get_string_size(extras[extra], HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
		draw_string(font, r.get_center() + Vector2(-w / 2.0, 6), extras[extra], HORIZONTAL_ALIGNMENT_CENTER, -1, 17, Color(1, 1, 1, 0.85))
		i += 1
	# Pausa: due sbarrette
	draw_circle(PAUSE.pos, PAUSE.r, Color(1, 1, 1, 0.14))
	for dx in [-7.0, 7.0]:
		draw_rect(Rect2(PAUSE.pos + Vector2(dx - 3.0, -10.0), Vector2(6, 20)), Color(1, 1, 1, 0.8))
