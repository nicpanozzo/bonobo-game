# Bonobo Party (#579): gli oggetti di scena dei minigiochi (snapshot.party.props), sopra l'arena e sotto i lottatori.
# Niente animazioni nuove: forme semplici a inchiostro, come gli oggetti del gioco, che si muovono solo perché il server
# le sposta. Sta dentro world (stesse coordinate dell'arena). Non decide niente: disegna quello che arriva.
extends Node2D

const UI := preload("res://scripts/ui.gd")
const INK := Color("140c1f")
const BANANA := Color("f4c81c")
const GOLD := Color("ffd700")

var props: Array = []
var _display: Font
var _t := 0.0


func _ready() -> void:
	_display = UI.display()
	z_index = 5 # sopra il palco, sotto scritte e lampi


func set_props(list: Variant) -> void:
	props = list if list is Array else []
	queue_redraw()


func clear() -> void:
	props = []
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not props.is_empty():
		queue_redraw() # le crepe tremano e le scritte pulsano anche tra uno snapshot e l'altro


func _draw() -> void:
	for p in props:
		if not (p is Dictionary):
			continue
		var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		var col: Color = Access.color(p.get("color")) if p.get("color") != null else Color.WHITE
		match str(p.get("kind", "")):
			"banana":
				_banana(pos, p.get("color") != null)
			"coin":
				_coin(pos, col)
			"marker":
				_marker(pos, col, str(p.get("text", "")))
			"sign":
				_sign(pos, col, str(p.get("text", "")))
			"goal":
				_goal(pos, float(p.get("w", 200)), str(p.get("text", "")))
			"crack":
				_crack(pos, float(p.get("w", 120)))
			"zone":
				_zone(pos, float(p.get("w", 160)), float(p.get("h", 20)), col)
			"crate":
				_crate(pos, float(p.get("w", 40)), float(p.get("h", 40)), col)
			"brick":
				_brick(pos, float(p.get("w", 40)), float(p.get("h", 20)), col)
			"wall":
				_wall(pos, float(p.get("w", 36)), float(p.get("h", 100)), col)
			"atm":
				_atm(pos, float(p.get("w", 76)), float(p.get("h", 120)), col, str(p.get("text", "")))
			"bus":
				_bus(pos, float(p.get("w", 120)), float(p.get("h", 100)), col)
			"ball":
				_ball(pos, col, float(p.get("w", 16)))
			"trail":
				_trail(p.get("pts", []), col)
		if str(p.get("kind", "")) == "goal":
			_pointer(pos + Vector2(0, -40))


# Dove la retta dal centro del riquadro verso target esce dal riquadro
static func edge_point(r: Rect2, target: Vector2) -> Vector2:
	var from := r.get_center()
	var dir := (target - from).normalized()
	var tx := INF if is_zero_approx(dir.x) else ((r.end.x if dir.x > 0 else r.position.x) - from.x) / dir.x
	var ty := INF if is_zero_approx(dir.y) else ((r.end.y if dir.y > 0 else r.position.y) - from.y) / dir.y
	return from + dir * minf(tx, ty)


# L'arrivo fuori dall'inquadratura (la CIMA della Scalata, #621 "non si è visto nulla"): una freccia sul bordo dello
# schermo che lo indica, coi metri che mancano. view_rect è la parte di mondo che la telecamera inquadra (world_view.gd)
func _pointer(target: Vector2) -> void:
	var view: Variant = get_parent().get("view_rect") if get_parent() != null else null
	if not (view is Rect2) or (view as Rect2).has_point(target):
		return
	var r: Rect2 = view
	var k := r.size.x / 1280.0 # le misure sono di schermo: con la telecamera lontana si ingrandiscono
	var from := r.get_center()
	var dir := (target - from).normalized()
	var at := edge_point(r.grow(-60.0 * k), target)
	var bob := sin(_t * 6.0) * 6.0 * k
	at += dir * bob
	var side := dir.orthogonal()
	var tip := at + dir * 30.0 * k
	var tri := PackedVector2Array([tip, at - dir * 14.0 * k + side * 24.0 * k, at - dir * 14.0 * k - side * 24.0 * k])
	draw_colored_polygon(tri, UI.BANANA)
	draw_polyline(tri + PackedVector2Array([tri[0]]), INK, 4.0 * k, true)
	var metres := "%d m" % ceili(from.distance_to(target) / 100.0)
	var px := int(24 * k)
	var tw := _display.get_string_size(metres, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	UI.draw_sticker(self, _display, at - dir * 50.0 * k + Vector2(-tw / 2, px * 0.35), metres, px, UI.BANANA, int(5 * k), Vector2(0, 3) * k)


# Una banana a terra (x, y = base): dorata quando vale di più
func _banana(base: Vector2, gold: bool) -> void:
	var hub := base + Vector2(0, -22)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 11:
		var u := k / 10.0
		var a := lerpf(PI * 0.2, PI * 0.8, u)
		var t := 9.0 * (0.3 + 0.7 * sin(PI * u))
		outer.append(hub + Vector2.from_angle(a) * (20.0 + t * 0.5))
		inner.append(hub + Vector2.from_angle(a) * (20.0 - t * 0.5))
	inner.reverse()
	var body := outer + inner
	draw_colored_polygon(body, GOLD if gold else BANANA)
	draw_polyline(body + PackedVector2Array([body[0]]), INK, 1.6, true)
	if gold:
		var glow := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(hub + Vector2(0, 18), 16.0 + glow * 3.0, 0, TAU, 20, Color(1, 0.95, 0.5, 0.5 * glow), 2.0)


# Una moneta che gira: si schiaccia e si allarga, col bordo in rilievo e un luccichio
func _coin(c: Vector2, col: Color, r := 12.0) -> void:
	var k := absf(cos(_t * 5.0 + c.x * 0.03)) * 0.75 + 0.25
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r * k, sin(a) * r))
	draw_colored_polygon(pts, col.darkened(0.25))
	var inner := PackedVector2Array()
	for q in pts:
		inner.append(c + (q - c) * 0.72)
	draw_colored_polygon(inner, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 2.0, true)
	if k > 0.6:
		draw_line(c + Vector2(-r * 0.3 * k, -r * 0.4), c + Vector2(-r * 0.1 * k, -r * 0.55), Color(1, 1, 1, 0.8), 2.0)


# Una palla con la luce in alto a sinistra
func _ball(c: Vector2, col: Color, r: float) -> void:
	draw_circle(c + Vector2(2, 3), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, col)
	draw_circle(c + Vector2(r * 0.15, r * 0.15), r * 0.7, col.darkened(0.12))
	draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.75))
	draw_arc(c, r, 0, TAU, 24, INK, 2.5, true)


# Una freccia sopra la testa con la scritta (es. INFETTO)
func _marker(c: Vector2, col: Color, text: String) -> void:
	var tip := c + Vector2(0, 14)
	var tri := PackedVector2Array([tip, tip + Vector2(-9, -14), tip + Vector2(9, -14)])
	draw_colored_polygon(tri, col)
	draw_polyline(tri + PackedVector2Array([tri[0]]), INK, 2.0)
	if text != "":
		var px := 14
		var w := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		UI.draw_sticker(self, _display, c + Vector2(-w / 2, -4), text, px, col, 4, Vector2(0, 2))


# Una scritta grande in mezzo all'arena (VAI!)
func _sign(c: Vector2, col: Color, text: String) -> void:
	var px := 72 + int(6 * sin(_t * 12.0))
	var w := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	UI.draw_sticker(self, _display, c + Vector2(-w / 2, px * 0.35), text, px, col, 9, Vector2(0, 6))


# La cima della Scalata: una bandiera a scacchi sul bordo e la scritta
func _goal(c: Vector2, w: float, text: String) -> void:
	var pole := c + Vector2(w / 2 - 16, 0)
	draw_line(pole, pole + Vector2(0, -90), INK, 4.0)
	for i in 3:
		for j in 4:
			var sq := Rect2(pole + Vector2(2 + j * 10, -90 + i * 10), Vector2(10, 10))
			draw_rect(sq, Color.WHITE if (i + j) % 2 == 0 else INK)
	draw_rect(Rect2(pole + Vector2(2, -90), Vector2(40, 30)), INK, false, 2.0)
	if text != "":
		var px := 26
		var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		UI.draw_sticker(self, _display, c + Vector2(-tw / 2, -24), text, px, UI.BANANA, 5, Vector2(0, 3))


# Una piattaforma che sta per cadere: una crepa a zig-zag che trema
func _crack(c: Vector2, w: float) -> void:
	var shake := sin(_t * 50.0) * 1.5
	var pts := PackedVector2Array()
	var n := 7
	for i in n + 1:
		var x := c.x - w / 2 + 10 + (w - 20) * i / n
		pts.append(Vector2(x + shake, c.y + 3 + (6 if i % 2 == 0 else -2)))
	draw_polyline(pts, INK, 3.0)
	draw_polyline(pts, Color("ff4560"), 1.4)


func _zone(c: Vector2, w: float, h: float, col: Color) -> void:
	var r := Rect2(c.x - w / 2, c.y - h, w, h)
	if h > 80.0:
		_water(r, col) # una zona alta è acqua che sale (Acqua Alta): onde in cima, non un riquadro
		return
	draw_rect(r, Color(col, 0.28 + 0.12 * sin(_t * 5.0)))
	draw_rect(r, Color(col, 0.9), false, 3.0)


# L'acqua: corpo trasparente, cresta a onde che scorrono e qualche bolla
func _water(r: Rect2, col: Color) -> void:
	var top := PackedVector2Array()
	var x := r.position.x
	while x <= r.end.x:
		top.append(Vector2(x, r.position.y + sin(x * 0.03 + _t * 3.0) * 6.0 + sin(x * 0.011 - _t * 1.7) * 4.0))
		x += 16.0
	var body := top.duplicate()
	body.append(r.end)
	body.append(Vector2(r.position.x, r.end.y))
	draw_colored_polygon(body, Color(col, 0.55))
	draw_polyline(top, Color(1, 1, 1, 0.85), 4.0, true)
	draw_polyline(top, col.lightened(0.4), 2.0, true)
	for i in 14:
		var bx := r.position.x + fposmod(i * 197.0 + _t * 20.0, r.size.x)
		var by := r.position.y + 30.0 + fposmod(i * 71.0 - _t * 60.0, maxf(30.0, minf(r.size.y - 40.0, 400.0)))
		draw_arc(Vector2(bx, by), 4.0, 0, TAU, 10, Color(1, 1, 1, 0.5), 1.5)


func _box(c: Vector2, w: float, h: float, col: Color) -> void:
	var r := Rect2(c.x - w / 2, c.y - h / 2, w, h)
	draw_rect(r, col)
	draw_rect(r, INK, false, 2.5)


# Una cassa di legno: assi orizzontali, cornice più scura e la croce di rinforzo coi chiodi
func _crate(c: Vector2, w: float, h: float, col: Color) -> void:
	var r := Rect2(c.x - w / 2, c.y - h / 2, w, h)
	draw_rect(r, col)
	for i in range(1, 3):
		var y := r.position.y + h * i / 3.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), col.darkened(0.3), 2.0)
	var b := minf(w, h) * 0.16
	draw_rect(r.grow(-b / 2), col.darkened(0.35), false, b)
	draw_line(r.position + Vector2(b, b), r.end - Vector2(b, b), col.darkened(0.2), b * 0.9)
	draw_line(Vector2(r.position.x + b, r.end.y - b), Vector2(r.end.x - b, r.position.y + b), col.darkened(0.2), b * 0.9)
	for q in [r.position + Vector2(b, b) / 2, Vector2(r.end.x - b / 2, r.position.y + b / 2), r.end - Vector2(b, b) / 2, Vector2(r.position.x + b / 2, r.end.y - b / 2)]:
		draw_circle(q, 2.0, INK)
	draw_line(r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2), col.lightened(0.3), 2.0)
	draw_rect(r, INK, false, 2.5)


# Un mattone (o una fila di mattoni): il colore con le righe di malta sfalsate e la luce sul bordo di sopra
func _brick(c: Vector2, w: float, h: float, col: Color) -> void:
	var r := Rect2(c.x - w / 2, c.y - h / 2, w, h)
	draw_rect(r, col)
	_mortar(r, col, 14.0)
	draw_line(r.position + Vector2(1, 1.5), Vector2(r.end.x - 1, r.position.y + 1.5), col.lightened(0.35), 2.0)
	draw_rect(r, INK, false, 2.0)


# Le righe di malta di un muro di mattoni alti row pixel
func _mortar(r: Rect2, col: Color, row: float) -> void:
	var mortar := col.darkened(0.35)
	var rows := maxi(1, roundi(r.size.y / row))
	var rh := r.size.y / rows
	var bw := rh * 2.2
	for i in rows:
		var y := r.position.y + i * rh
		if i > 0:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), mortar, 1.5)
		var x := r.position.x + (bw / 2 if i % 2 == 1 else bw)
		while x < r.end.x - 2:
			draw_line(Vector2(x, y), Vector2(x, y + rh), mortar, 1.5)
			x += bw


# Un pezzo del Muro che avanza: mattoni, e strisce gialle e nere sul bordo del buco
func _wall(c: Vector2, w: float, h: float, col: Color) -> void:
	var r := Rect2(c.x - w / 2, c.y - h / 2, w, h)
	draw_rect(r.grow(3), Color(0, 0, 0, 0.25))
	draw_rect(r, col)
	_mortar(r, col, 16.0)
	for edge in [r.position.y, r.end.y - 10.0]:
		var band := Rect2(r.position.x, edge, w, 10)
		draw_rect(band, Color("ffd23a"))
		var x := r.position.x - 10.0
		while x < r.end.x:
			var a := Vector2(maxf(x, r.position.x), edge + 10)
			var b := Vector2(minf(x + 10, r.end.x), edge)
			draw_line(a, b, INK, 4.0)
			x += 14.0
	draw_rect(r, INK, false, 2.5)


# Il bancomat rotto: cassa di metallo con l'insegna, lo schermo (verde se è pronto a sputare), la tastiera e la
# fessura delle monete. c è il centro, w e h la grandezza della macchina
func _atm(c: Vector2, w: float, h: float, screen: Color, text: String) -> void:
	var r := Rect2(c.x - w / 2, c.y - h / 2, w, h)
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Color("5a6b7d"))
	draw_rect(Rect2(r.position.x + w - 10, r.position.y, 10, h), Color("46566a")) # il fianco in ombra
	var sign := Rect2(r.position.x - 4, r.position.y - 4, w + 8, 18)
	draw_rect(sign, Color("2f6fd8"))
	draw_rect(sign, INK, false, 2.0)
	var px := 12
	var label := "BANCOMAT"
	var lw := _display.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_display, Vector2(c.x - lw / 2, sign.position.y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	var glass := Rect2(r.position.x + 9, r.position.y + 22, w - 18, 30)
	var ready := screen.g > screen.r + 0.2
	var glow := screen if not ready else screen.lerp(Color.WHITE, 0.15 + 0.15 * sin(_t * 8.0))
	draw_rect(glass.grow(2), INK)
	draw_rect(glass, glow)
	if text != "":
		var tpx := 13 # rimpicciolita finché ci sta nello schermo della macchina
		while tpx > 8 and _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > glass.size.x - 6:
			tpx -= 1
		var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
		draw_string(_display, Vector2(c.x - tw / 2, glass.position.y + 19), text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, INK if ready else Color("ff6b6b"))
	for i in 3:
		for j in 3:
			var key := Rect2(r.position.x + 14 + j * 14, r.position.y + 60 + i * 10, 10, 7)
			draw_rect(key, Color("c9d3de") if (i + j) % 4 != 0 else Color("ffc928"))
			draw_rect(key, INK, false, 1.0)
	var slot := Rect2(r.position.x + 12, r.end.y - 22, w - 24, 8)
	draw_rect(slot, INK)
	draw_line(slot.position + Vector2(2, 4), Vector2(slot.end.x - 2, slot.position.y + 4), Color("ffd700"), 2.0)
	# Rotto: una crepa sul fianco e un filo di fumo
	draw_polyline(PackedVector2Array([r.position + Vector2(4, 30), r.position + Vector2(12, 42), r.position + Vector2(6, 52), r.position + Vector2(14, 64)]), INK, 2.0)
	for k in 3:
		var u := fposmod(_t * 0.6 + k / 3.0, 1.0)
		draw_circle(Vector2(r.end.x - 8 + sin(u * 6.0 + k) * 6.0, r.position.y - 6 - u * 50.0), 5.0 + u * 8.0, Color(0.7, 0.7, 0.75, 0.35 * (1.0 - u)))
	draw_rect(r, INK, false, 2.5)


# L'autobus di Attraversa la Strada visto di muso: la scatola col parabrezza e i fari
func _bus(c: Vector2, w: float, h: float, col: Color) -> void:
	_box(c, w, h, col)
	# La targa della linea in alto, il paraurti, le ruote che spuntano sotto
	var line_box := Rect2(c.x - 18, c.y - h / 2 - 16, 36, 16)
	draw_rect(line_box, INK)
	draw_string(_display, Vector2(c.x - 11, line_box.position.y + 13), "27", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffb000"))
	draw_rect(Rect2(c.x - w / 2 - 3, c.y + h / 2 - 8, w + 6, 8), Color("2b2b33"))
	for side in [-1, 1]:
		draw_circle(Vector2(c.x + side * (w / 2 - 12), c.y + h / 2 + 2), 9.0, INK)
		draw_circle(Vector2(c.x + side * (w / 2 - 12), c.y + h / 2 + 2), 4.0, Color("8a8a95"))
	var glass := Rect2(c.x - w / 2 + 8, c.y - h / 2 + 10, w - 16, h * 0.38)
	draw_rect(glass, Color("bfe3ff"))
	draw_rect(glass, INK, false, 2.0)
	for side in [-1, 1]:
		draw_circle(Vector2(c.x + side * (w / 2 - 14), c.y + h / 2 - 16), 7.0, Color("fff3a0"))
		draw_arc(Vector2(c.x + side * (w / 2 - 14), c.y + h / 2 - 16), 7.0, 0, TAU, 14, INK, 1.6)


func _trail(pts: Variant, col: Color) -> void:
	if not (pts is Array) or (pts as Array).size() < 4:
		return
	var line := PackedVector2Array()
	for i in range(0, (pts as Array).size() - 1, 2):
		line.append(Vector2(float(pts[i]), float(pts[i + 1])))
	draw_polyline(line, INK, 9.0, true)
	draw_polyline(line, col, 5.0, true)
