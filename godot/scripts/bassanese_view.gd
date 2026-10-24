# Chiama Bassanese: il telefono a terra, il Bassanese che gira l'arena in cerca della grappa e la grappa che cerca.
# Solo disegno: dove sta, dove guarda e cosa fa arrivano nello snapshot (physics/bassanese.ts).
# world_view.gd lo chiama dentro _draw; i fumetti li dice world_view con l'id "bassanese".
extends RefCounted

const INK := Color("1b1612")
const SKIN := Color("e8b48a")
const LODEN := Color("3f5a3a") # la giacca verde
const TROUSERS := Color("5b4632")
const HAT := Color("2f4a2c") # il cappello da alpino, con la penna nera
const GLASS := Color(0.85, 0.95, 1.0, 0.55)
const GRAPPA := Color(1.0, 0.97, 0.85, 0.8)
const PHONE := Color("3a4048")
const SCREEN := Color("9bc25b")

var list: Array = [] # Bassanesi dello snapshot
var _shown := {} # id -> posizione disegnata, per andare liscio tra uno snapshot e l'altro


func on_snapshot(snap: Dictionary) -> void:
	var b: Variant = snap.get("bassanese")
	list = b if b is Array else []


func clear() -> void:
	list = []
	_shown = {}


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
		seen[b.id] = true
		var g: Variant = b.get("grappa")
		if g is Array:
			draw_grappa(canvas, Vector2(float(g[0]), float(g[1])), now)
		draw_man(canvas, pos, int(b.facing), str(b.phase), not (g is Array), now)
	for id in _shown.keys():
		if not seen.has(id):
			_shown.erase(id)


# La bottiglia di grappa che aspetta su una superficie: brilla, così si capisce dove sta andando
static func draw_grappa(canvas: CanvasItem, feet: Vector2, now: int) -> void:
	var glow := 0.5 + 0.5 * sin(now / 240.0)
	canvas.draw_circle(feet - Vector2(0, 16), 20.0 + 3.0 * glow, Color(1, 0.95, 0.6, 0.12 + 0.12 * glow))
	_bottle(canvas, feet, 1.0)


static func _bottle(canvas: CanvasItem, feet: Vector2, s: float) -> void:
	canvas.draw_rect(Rect2(feet + Vector2(-7, -24) * s, Vector2(14, 24) * s), GLASS)
	canvas.draw_rect(Rect2(feet + Vector2(-6, -16) * s, Vector2(12, 15) * s), GRAPPA)
	canvas.draw_rect(Rect2(feet + Vector2(-3, -34) * s, Vector2(6, 10) * s), GLASS)
	canvas.draw_rect(Rect2(feet + Vector2(-3.5, -37) * s, Vector2(7, 4) * s), Color("8a5a2b")) # il tappo
	canvas.draw_rect(Rect2(feet + Vector2(-7, -24) * s, Vector2(14, 24) * s), INK, false, 1.5)
	canvas.draw_line(feet + Vector2(-4, -21) * s, feet + Vector2(-4, -5) * s, Color(1, 1, 1, 0.7), 1.5)


# Il Bassanese, piedi in feet: giacca verde, cappello da alpino, baffi. Cammina col telefono all'orecchio,
# si guarda in giro arrivando su una superficie, e trovata la grappa la alza al cielo
static func draw_man(canvas: CanvasItem, feet: Vector2, facing: int, phase: String, has_grappa: bool, now: int) -> void:
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
	canvas.draw_rect(Rect2(leg_l + Vector2(-6 + 4 * f, -4), Vector2(14, 6)), INK) # scarponi
	canvas.draw_rect(Rect2(leg_r + Vector2(-6 + 4 * f, -4), Vector2(14, 6)), INK)
	# Giacca, un po' di pancia
	var body := PackedVector2Array([hip + Vector2(-15, 2), hip + Vector2(15, 2), hip + Vector2(17 + 3 * f, -20), hip + Vector2(13, -42), hip + Vector2(-13, -42), hip + Vector2(-16, -20)])
	canvas.draw_colored_polygon(body, LODEN)
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), INK, 2.0)
	canvas.draw_line(hip + Vector2(0, 0), hip + Vector2(0, -40), LODEN.darkened(0.35), 1.5)
	for k in 3:
		canvas.draw_circle(hip + Vector2(3, -8 - 11 * k), 1.8, Color("c9a35a"))
	# Testa
	var head_c := hip + Vector2(2 * f, -56)
	canvas.draw_circle(head_c, 13.0, SKIN)
	canvas.draw_arc(head_c, 13.0, 0, TAU, 20, INK, 1.5)
	canvas.draw_circle(head_c + Vector2(5 * f, -2), 1.8, INK) # occhio
	canvas.draw_line(head_c + Vector2(1 * f, 5), head_c + Vector2(11 * f, 4), Color("4a3020"), 4.0) # baffi
	canvas.draw_circle(head_c + Vector2(12 * f, 1), 3.0, SKIN.darkened(0.1)) # naso
	# Cappello da alpino con la penna nera
	var brim := head_c + Vector2(0, -9)
	canvas.draw_line(brim + Vector2(-17, 1), brim + Vector2(17, -1), HAT, 4.0)
	canvas.draw_colored_polygon(PackedVector2Array([brim + Vector2(-11, 0), brim + Vector2(11, 0), brim + Vector2(7, -12), brim + Vector2(-7, -13)]), HAT)
	var quill := PackedVector2Array([brim + Vector2(-6 * f, -5), brim + Vector2(-13 * f, -18), brim + Vector2(-26 * f, -34), brim + Vector2(-17 * f, -15)])
	canvas.draw_colored_polygon(quill, INK) # la penna nera
	# Braccia: il telefono all'orecchio finché cerca, la grappa in alto quando l'ha trovata
	var shoulder := hip + Vector2(10 * f, -36)
	if has_grappa:
		var hand := shoulder + Vector2(6 * f, -30)
		canvas.draw_line(shoulder, hand, INK, 10.0)
		canvas.draw_line(shoulder, hand, LODEN.lightened(0.12), 7.0)
		_bottle(canvas, hand + Vector2(0, 12), 0.8)
	else:
		var ear := head_c + Vector2(-2 * f, 6)
		var elbow := shoulder + Vector2(9 * f, 16)
		for pass_ in 2: # prima il contorno, poi la manica: si stacca dalla giacca
			var col := INK if pass_ == 0 else LODEN.lightened(0.12)
			var wid := 10.0 if pass_ == 0 else 7.0
			canvas.draw_line(shoulder, elbow, col, wid)
			canvas.draw_line(elbow, ear + Vector2(0, 6), col, wid)
		canvas.draw_circle(ear + Vector2(0, 6), 4.5, SKIN)
		canvas.draw_rect(Rect2(ear + Vector2(-3, -6), Vector2(6, 14)), PHONE)
	var back := hip + Vector2(-10 * f, -36)
	canvas.draw_line(back, back + Vector2(-4 * f + swing * 0.5, 30), LODEN.darkened(0.15), 7.0)
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
