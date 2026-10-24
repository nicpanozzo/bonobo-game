# Chiama Bassanese: il telefono a terra e il Bassanese che attraversa l'arena cercando qualcosa (non si sa cosa).
# Solo disegno: dove sta, dove guarda e cosa fa arrivano nello snapshot (physics/bassanese.ts).
# world_view.gd lo chiama dentro _draw; i fumetti passano da say, con l'id "bassanese".
extends RefCounted

const INK := Color("1b1612")
const SKIN := Color("e8b48a")
const JACKET := Color("2f4f7a") # il giubbotto
const TROUSERS := Color("3d4f6b") # i jeans
const HAIR := Color("3a2a1e")
const PHONE := Color("3a4048")
const SCREEN := Color("9bc25b")

var list: Array = [] # Bassanesi dello snapshot
var _shown := {} # id -> posizione disegnata, per andare liscio tra uno snapshot e l'altro
var _phase := {} # id -> fase dell'ultimo snapshot: quando comincia a guardarsi in giro dice qualcosa
var _lines_said := 0
var say: Callable # (testo) -> fumetto sopra il Bassanese; lo imposta world_view
# TODO community: le frasi. Cerca qualcosa, ma non si capisce mai cosa
const LOOK_LINES := ["Dove l'ho messo...?", "Qui non c'è.", "Eppure era qui!", "Hai visto per caso...? No, niente.", "Mah..."]
const LEAVE_LINE := "Vabbè, lo cerco da un'altra parte."


func on_snapshot(snap: Dictionary) -> void:
	var b: Variant = snap.get("bassanese")
	list = b if b is Array else []
	for x: Dictionary in list:
		if x.phase == "look" and _phase.get(x.id) != "look" and say.is_valid() and _lines_said % 2 == 0:
			say.call(LOOK_LINES[(_lines_said / 2) % LOOK_LINES.size()])
		if x.phase == "look" and _phase.get(x.id) != "look":
			_lines_said += 1
		_phase[x.id] = x.phase


func clear() -> void:
	list = []
	_shown = {}
	_phase = {}


var last_head: Variant = null # dov'era la testa l'ultima volta che c'era: il saluto quando se ne va resta lì


# La testa del Bassanese più recente, per il fumetto; null se non c'è
func head() -> Variant:
	if list.is_empty():
		return null
	var b: Dictionary = list[-1]
	return _shown.get(b.id, Vector2(b.x, b.y)) - Vector2(0, 118)


func draw(canvas: CanvasItem, now: int) -> void:
	var seen := {}
	for b: Dictionary in list:
		var target := Vector2(float(b.x), float(b.y))
		var pos: Vector2 = _shown.get(b.id, target)
		pos = target if pos.distance_to(target) > 200.0 else pos.lerp(target, 0.5)
		_shown[b.id] = pos
		last_head = pos - Vector2(0, 118)
		seen[b.id] = true
		draw_man(canvas, pos, int(b.facing), str(b.phase), now)
	for id in _shown.keys():
		if not seen.has(id):
			_shown.erase(id)


# Il Bassanese, piedi in feet: giubbotto e jeans. Cammina col telefono all'orecchio e si guarda in giro
# arrivando su una superficie, con un "?" sopra la testa
static func draw_man(canvas: CanvasItem, feet: Vector2, facing: int, phase: String, now: int) -> void:
	var f := float(facing)
	if phase == "look":
		f = 1.0 if (now / 160) % 2 == 0 else -1.0 # si gira di qua e di là
	var swing := sin(now / 70.0) * 9.0 if phase == "walk" else 0.0
	var air := phase == "jump"
	# Gambe
	var hip := feet + Vector2(0, -44)
	var leg_l := feet + Vector2(-8 + swing, 0) if not air else feet + Vector2(-12, -10)
	var leg_r := feet + Vector2(8 - swing, 0) if not air else feet + Vector2(10, -4)
	canvas.draw_line(hip + Vector2(-5, 0), leg_l, TROUSERS, 9.0)
	canvas.draw_line(hip + Vector2(5, 0), leg_r, TROUSERS, 9.0)
	canvas.draw_rect(Rect2(leg_l + Vector2(-6 + 4 * f, -4), Vector2(14, 6)), INK) # scarpe
	canvas.draw_rect(Rect2(leg_r + Vector2(-6 + 4 * f, -4), Vector2(14, 6)), INK)
	# Giubbotto, un po' di pancia
	var body := PackedVector2Array([hip + Vector2(-15, 2), hip + Vector2(15, 2), hip + Vector2(17 + 3 * f, -20), hip + Vector2(13, -42), hip + Vector2(-13, -42), hip + Vector2(-16, -20)])
	canvas.draw_colored_polygon(body, JACKET)
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), INK, 2.0)
	canvas.draw_line(hip + Vector2(0, 0), hip + Vector2(0, -40), JACKET.darkened(0.35), 1.5) # la cerniera
	# Testa
	var head_c := hip + Vector2(2 * f, -56)
	canvas.draw_circle(head_c, 13.0, SKIN)
	canvas.draw_arc(head_c, 13.0, 0, TAU, 20, INK, 1.5)
	canvas.draw_circle(head_c + Vector2(5 * f, -2), 1.8, INK) # occhio
	canvas.draw_circle(head_c + Vector2(12 * f, 1), 3.0, SKIN.darkened(0.1)) # naso
	# Capelli corti
	canvas.draw_arc(head_c, 13.0, PI * 1.05, PI * 1.95, 12, HAIR, 7.0)
	canvas.draw_circle(head_c + Vector2(-8 * f, -4), 5.0, HAIR)
	# Braccia: una tiene il telefono all'orecchio
	var shoulder := hip + Vector2(10 * f, -36)
	var ear := head_c + Vector2(-2 * f, 6)
	var elbow := shoulder + Vector2(9 * f, 16)
	for pass_ in 2: # prima il contorno, poi la manica: si stacca dalla giacca
		var col := INK if pass_ == 0 else JACKET.lightened(0.12)
		var wid := 10.0 if pass_ == 0 else 7.0
		canvas.draw_line(shoulder, elbow, col, wid)
		canvas.draw_line(elbow, ear + Vector2(0, 6), col, wid)
	canvas.draw_circle(ear + Vector2(0, 6), 4.5, SKIN)
	canvas.draw_rect(Rect2(ear + Vector2(-3, -6), Vector2(6, 14)), PHONE)
	var back := hip + Vector2(-10 * f, -36)
	canvas.draw_line(back, back + Vector2(-4 * f + swing * 0.5, 30), JACKET.darkened(0.15), 7.0)
	if phase == "look":
		_question(canvas, head_c + Vector2(0, -38), now)


# Il punto di domanda di chi cerca
static func _question(canvas: CanvasItem, at: Vector2, now: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var bob := sin(now / 120.0) * 3.0
	canvas.draw_string_outline(font, at + Vector2(-7, bob), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color.WHITE)
	canvas.draw_string(font, at + Vector2(-7, bob), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)


# Il telefono a terra (centrato in zero, dentro w per h): un cellulare dei vecchi, che squilla e vibra
static func draw_phone(canvas: CanvasItem, w: float, h: float, now: int) -> void:
	var ring := (now / 90) % 12 < 6
	var shake := Vector2(sin(now / 22.0) * 2.0, 0) if ring else Vector2.ZERO
	var body := Rect2(Vector2(-w / 2, -h / 2) + shake, Vector2(w, h))
	canvas.draw_rect(body, PHONE)
	canvas.draw_rect(body, INK, false, 1.5)
	canvas.draw_line(Vector2(w * 0.25, -h / 2) + shake, Vector2(w * 0.25, -h / 2 - 7) + shake, INK, 2.5) # antenna
	canvas.draw_rect(Rect2(Vector2(-w / 2 + 3, -h / 2 + 4) + shake, Vector2(w - 6, h * 0.32)), SCREEN)
	for r in 3:
		for c in 3:
			canvas.draw_rect(Rect2(Vector2(-w / 2 + 3.5 + c * (w - 7) / 3.0, h * 0.02 + r * 4.5) + shake, Vector2((w - 7) / 3.0 - 1.5, 3)), Color("aeb5bd"))
	if ring:
		for k in 2:
			var r := w * (0.75 + 0.3 * k)
			canvas.draw_arc(shake, r, -PI * 0.25, PI * 0.25, 8, Color(1, 1, 1, 0.7), 2.0)
			canvas.draw_arc(shake, r, PI * 0.75, PI * 1.25, 8, Color(1, 1, 1, 0.7), 2.0)
