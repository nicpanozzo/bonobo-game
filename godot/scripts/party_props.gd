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
			"crate", "brick", "bus", "wall":
				_box(pos, float(p.get("w", 40)), float(p.get("h", 40)), col)
			"ball":
				_coin(pos, col, float(p.get("w", 16)))
			"trail":
				_trail(p.get("pts", []), col)


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


func _coin(c: Vector2, col: Color, r := 12.0) -> void:
	draw_circle(c, r, col)
	draw_arc(c, r, 0, TAU, 20, INK, 2.0, true)


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
	draw_rect(r, Color(col, 0.28 + 0.12 * sin(_t * 5.0)))
	draw_rect(r, Color(col, 0.9), false, 3.0)


func _box(c: Vector2, w: float, h: float, col: Color) -> void:
	var r := Rect2(c.x - w / 2, c.y - h / 2, w, h)
	draw_rect(r, col)
	draw_rect(r, INK, false, 2.5)


func _trail(pts: Variant, col: Color) -> void:
	if not (pts is Array) or (pts as Array).size() < 4:
		return
	var line := PackedVector2Array()
	for i in range(0, (pts as Array).size() - 1, 2):
		line.append(Vector2(float(pts[i]), float(pts[i + 1])))
	draw_polyline(line, INK, 9.0, true)
	draw_polyline(line, col, 5.0, true)
