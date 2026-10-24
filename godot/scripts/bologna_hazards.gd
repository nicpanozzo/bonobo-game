# Disegno delle trappole di Bologna (#433) che prima erano solo un rettangolo rosso: l'auto della piazza,
# l'ingorgo di via Rizzoli, i mattoni della Garisenda e la polvere della zuffa. Solo grafica, tutta da stageMs:
# la fisica è quella di hazardRect/hazardActive. Le macchine usano i fogli dipinti dello sfondo vivo (auto, furgone,
# bus di bologna.py) se l'arena li ha, altrimenti un disegno semplice col codice.
extends RefCounted

const JAM_KINDS := ["auto", "furgone", "auto", "bus", "auto", "furgone"] # la fila dell'ingorgo, ripetuta
const JAM_LENGTH := {"auto": 150.0, "furgone": 170.0, "bus": 300.0} # pixel di mondo: lunghi come l'auto della piazza
const JAM_GAP_PX := 14.0 # paraurti contro paraurti
const JAM_BUMP_PX := 4.0 # quanto sobbalzano quando l'ingorgo spinge
const BRICK := Color("9a4f38")
const MORTAR := Color("d9c4a0")
const INK := Color("2a2622")
const DUST := Color(0.62, 0.55, 0.45)


# L'auto che attraversa la piazza (travel): il modello cambia a ogni giro, girata nel verso in cui va
static func draw_car(ci: CanvasItem, life: RefCounted, r: Rect2, dir: int, lap: int, mod: Color) -> void:
	_car(ci, life, "auto", lap, Vector2(r.get_center().x, r.end.y), r.size.x, dir, mod)


# L'ingorgo: una fila di macchine ferme sulla corsia. Quando spinge (on) sobbalzano, avanzano di poco e suonano
static func draw_jam(ci: CanvasItem, life: RefCounted, h: Dictionary, r: Rect2, on: bool, t: float, mod: Color) -> void:
	var dir := 1 if r.get_center().x < 1100.0 else -1 # metà a sinistra verso destra, l'altra verso sinistra
	var x := r.position.x + 10.0
	var i := int(r.position.x / 100.0) # la fila non è uguale nelle due metà
	var dim := mod if on else mod.darkened(0.15)
	while x < r.end.x - 60.0:
		var kind: String = JAM_KINDS[posmod(i, JAM_KINDS.size())]
		var length: float = minf(JAM_LENGTH[kind], r.end.x - 10.0 - x)
		if length < 120.0:
			kind = "auto"
		var nudge := 0.0
		var bump := 0.0
		if on:
			nudge = dir * 6.0 * (0.5 + 0.5 * sin(t / 180.0 + i * 1.3))
			bump = -absf(sin(t / 90.0 + i * 2.1)) * JAM_BUMP_PX
		_car(ci, life, kind, i, Vector2(x + length / 2.0 + nudge, r.end.y + bump), length, dir, dim)
		if on and posmod(i, 3) == 0 and fposmod(t / 250.0 + i, 2.0) < 1.0:
			_honk(ci, Vector2(x + length / 2.0, r.end.y - _car_height(kind) - 14.0))
		x += length + JAM_GAP_PX
		i += 1


# Un mattone che cade dalla Garisenda: un blocco di mattoni che gira. Nell'avviso, l'ombra dove cadrà
static func draw_brick(ci: CanvasItem, h: Dictionary, r: Rect2, phase: String, k: float, t: float, mod: Color) -> void:
	if phase == "warn":
		var path: Array = h.travel.path
		var land := Vector2(float(path[path.size() - 1].x) + h.width / 2.0, float(path[path.size() - 1].y) + h.height)
		var w: float = h.width * (0.4 + 0.6 * k)
		_ellipse(ci, land, w / 2.0, w / 7.0, Color(0, 0, 0, 0.15 + 0.25 * k))
		for g in 3: # calcinacci che cadono prima del blocco
			var gy: float = r.position.y + fposmod(t / 2.0 + g * 37.0, 120.0)
			ci.draw_rect(Rect2(r.get_center().x - 12.0 + g * 11.0, gy, 4, 4), MORTAR * mod)
		return
	if phase != "cross":
		return
	var c := r.get_center()
	var a := t / 260.0 + float(h.travel.path[0].x) # gira mentre cade, ognuno da un angolo suo
	var xf := Transform2D(a, c)
	var half := r.size * 0.5
	var body := PackedVector2Array([xf * Vector2(-half.x, -half.y), xf * Vector2(half.x, -half.y), xf * Vector2(half.x, half.y), xf * Vector2(-half.x, half.y)])
	ci.draw_colored_polygon(body, BRICK * mod)
	# tre corsi di mattoni sfalsati
	for row in 3:
		var y := -half.y + (row + 1) * r.size.y / 3.0
		if row < 2:
			ci.draw_line(xf * Vector2(-half.x, y), xf * Vector2(half.x, y), MORTAR * mod, 2.0)
		var y0 := -half.y + row * r.size.y / 3.0
		var off := 0.0 if row % 2 == 0 else r.size.x / 4.0
		var bx := -half.x + off + r.size.x / 2.0
		while bx < half.x:
			ci.draw_line(xf * Vector2(bx, y0), xf * Vector2(bx, y0 + r.size.y / 3.0), MORTAR * mod, 2.0)
			bx += r.size.x / 2.0
	body.append(body[0])
	ci.draw_polyline(body, INK, 2.0)


# La polvere che sale: una nube color sabbia con il bordo che ribolle. Bassa e ferma non fa male e non si vede;
# nell'avviso compare una foschia sul fondo
static func draw_dust(ci: CanvasItem, r: Rect2, phase: String, k: float, t: float, mod: Color) -> void:
	if phase == "calm":
		return
	var alpha := 0.55
	var top := r.position.y
	if phase == "warn":
		alpha = 0.35 * k
		top = r.end.y - r.size.y * 0.3
	var col := Color(DUST.r * mod.r, DUST.g * mod.g, DUST.b * mod.b, alpha)
	ci.draw_rect(Rect2(r.position.x, top + 20.0, r.size.x, r.end.y - top - 20.0), col)
	var x := r.position.x
	var n := 0
	while x < r.end.x: # il bordo: sbuffi che salgono e scendono piano
		var rad := 34.0 + 12.0 * sin(n * 1.7)
		var y := top + 24.0 + 10.0 * sin(t / 400.0 + n * 0.9)
		ci.draw_circle(Vector2(x + fposmod(t / 60.0, 50.0), y), rad, col)
		x += 50.0
		n += 1
	# granelli più chiari che vorticano dentro
	for g in int(r.size.x / 90.0):
		var gx: float = r.position.x + fposmod(g * 97.0 + t / 25.0, r.size.x)
		var gy: float = top + 30.0 + fposmod(g * 53.0 - t / 40.0, maxf(1.0, r.end.y - top - 30.0))
		ci.draw_circle(Vector2(gx, gy), 3.0, Color(0.85, 0.78, 0.64, alpha * 0.8))


static func _car(ci: CanvasItem, life: RefCounted, kind: String, model: int, feet: Vector2, length: float, dir: int, mod: Color) -> void:
	var sh: Dictionary = life.sheet(kind) if life != null else {}
	if not sh.is_empty():
		var k := length / (float(sh.fw) * float(sh.scale))
		life.draw_frame(ci, kind, posmod(model, int(sh.frames)), feet, k, dir < 0, Color(mod.r, mod.g, mod.b, 1.0), true)
		return
	# senza foglio dipinto: carrozzeria grigia, abitacolo, ruote
	var h := _car_height(kind)
	var o := Vector2(feet.x - length / 2.0, feet.y)
	var body := Color("6d6a64") * mod
	ci.draw_rect(Rect2(o.x, o.y - 8.0 - h * 0.55, length, h * 0.55), body)
	ci.draw_rect(Rect2(o.x + length * (0.2 if dir > 0 else 0.3), o.y - 8.0 - h, length * 0.5, h * 0.45), body)
	ci.draw_rect(Rect2(o.x, o.y - 8.0 - h * 0.55, length, h * 0.55), INK, false, 2.0)
	for wx in [o.x + length * 0.18, o.x + length * 0.82]:
		ci.draw_circle(Vector2(wx, o.y - 8.0), 8.0, INK)


static func _car_height(kind: String) -> float:
	return 70.0 if kind == "bus" else (56.0 if kind == "furgone" else 44.0)


# Il clacson: tre trattini a ventaglio sopra la macchina
static func _honk(ci: CanvasItem, p: Vector2) -> void:
	for a in [-0.5, 0.0, 0.5]:
		var d := Vector2(sin(a), -cos(a))
		ci.draw_line(p + d * 6.0, p + d * 16.0, Color("f0d9b5"), 3.0)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)
