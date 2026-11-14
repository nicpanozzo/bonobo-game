# Il Dojo (arena "dojo"): la sala dove si imparano le mosse, disegnata col codice come le altre arene a tema.
# Pareti di carta illuminate da dietro tra pilastri di legno scuro, una trave in alto con le lanterne che dondolano,
# il rotolo appeso con la banana del maestro e il pavimento di tatami sopra il legno. Solo disegno: l'arena è un
# pavimento piatto (quello del laboratorio delle combo) e il disegno non deve suggerire piattaforme che non ci sono.
extends RefCounted

const INK := Color("1c1612")
const WOOD_DARK := Color("3a2416")
const WOOD := Color("6b4428")
const WOOD_LIGHT := Color("a8743f")
const PAPER := Color("dcc697") # un po' spenta: i lottatori davanti devono staccare
const PAPER_GLOW := Color("f2c472")
const TATAMI := Color("b9b46a")
const TATAMI_DARK := Color("8f8a48")
const BORDER := Color("2f3b2a") # il bordo di stoffa dei tatami
const LANTERN := Color("e8452f")
const BANANA := Color("ffc928")
const FLOOR_Y := 560.0
const BEAM_Y := 70.0 # la trave alta da cui pendono le lanterne
const BAY := 220.0 # pixel tra due pilastri
const TOP := -400.0 # fin dove si disegna la parete in alto (la telecamera può allontanarsi)

var width := 1580.0
var _font: Font = ThemeDB.fallback_font


func setup(spec: Dictionary, _game: Dictionary) -> void:
	width = float(spec.get("width", 1580.0))


func draw_back(c: CanvasItem, t: float, view: Rect2, _pressed: Array, _now_ms: float) -> void:
	var area := view.grow(80)
	var left := area.position.x
	var right := area.end.x
	# Il fondo: legno caldo in penombra, più chiaro dove la luce delle pareti di carta lo tocca
	c.draw_rect(Rect2(left, minf(area.position.y, TOP), right - left, FLOOR_Y - minf(area.position.y, TOP)), WOOD_DARK)
	# Le pareti di carta (shoji) tra i pilastri, accese da dietro: la luce respira piano
	var glow := 0.85 + 0.15 * sin(t / 1400.0)
	var x := floorf(left / BAY) * BAY
	while x < right:
		_draw_shoji(c, Rect2(x + 16.0, BEAM_Y + 40.0, BAY - 32.0, FLOOR_Y - BEAM_Y - 70.0), glow)
		x += BAY
	# I pilastri
	x = floorf(left / BAY) * BAY
	while x <= right:
		c.draw_rect(Rect2(x - 14.0, minf(area.position.y, TOP), 28.0, FLOOR_Y - minf(area.position.y, TOP)), WOOD)
		c.draw_rect(Rect2(x - 14.0, minf(area.position.y, TOP), 6.0, FLOOR_Y - minf(area.position.y, TOP)), WOOD_LIGHT.darkened(0.2))
		c.draw_rect(Rect2(x - 14.0, minf(area.position.y, TOP), 28.0, FLOOR_Y - minf(area.position.y, TOP)), INK, false, 2.0)
		x += BAY
	# La trave alta e quella sopra le pareti
	for y: float in [BEAM_Y, BEAM_Y + 30.0]:
		c.draw_rect(Rect2(left, y, right - left, 18.0), WOOD)
		c.draw_rect(Rect2(left, y, right - left, 4.0), WOOD_LIGHT)
		c.draw_line(Vector2(left, y + 18.0), Vector2(right, y + 18.0), INK, 2.0)
	# Il rotolo appeso al centro della sala, con la banana del maestro e il nome del Dojo
	_draw_scroll(c, Vector2(width / 2.0, BEAM_Y + 60.0), t)
	# Le lanterne di carta che dondolano, una ogni due campate (non sopra il rotolo)
	var i := int(floorf(left / BAY))
	while i * BAY <= right:
		var lx := i * BAY + BAY
		if i % 2 == 0 and absf(lx - width / 2.0) > BAY:
			_draw_lantern(c, Vector2(lx, BEAM_Y + 18.0), t, i)
		i += 1
	# Un'ombra morbida in fondo alla parete, dove incontra il pavimento
	for k in 4:
		c.draw_rect(Rect2(left, FLOOR_Y - 34.0 + k * 8.0, right - left, 8.0), Color(0, 0, 0, 0.06 * (k + 1)))


func _draw_shoji(c: CanvasItem, r: Rect2, glow: float) -> void:
	c.draw_rect(r, PAPER.lerp(PAPER_GLOW, 0.35 * glow))
	# La luce dietro la carta: più forte al centro
	c.draw_rect(r.grow(-r.size.x * 0.22), Color(PAPER_GLOW, 0.25 * glow))
	# Il reticolo di listelli
	var cols := 3
	var rows := 5
	for k in range(1, cols):
		var lx := r.position.x + r.size.x * k / cols
		c.draw_line(Vector2(lx, r.position.y), Vector2(lx, r.end.y), WOOD, 3.0)
	for k in range(1, rows):
		var ly := r.position.y + r.size.y * k / rows
		c.draw_line(Vector2(r.position.x, ly), Vector2(r.end.x, ly), WOOD, 3.0)
	c.draw_rect(r, WOOD, false, 6.0)


func _draw_scroll(c: CanvasItem, top: Vector2, t: float) -> void:
	var sway := 2.0 * sin(t / 1700.0)
	var r := Rect2(top.x - 70.0 + sway, top.y, 140.0, 250.0)
	c.draw_line(Vector2(top.x, BEAM_Y + 18.0), Vector2(top.x - 40.0 + sway, top.y), INK, 2.0)
	c.draw_line(Vector2(top.x, BEAM_Y + 18.0), Vector2(top.x + 40.0 + sway, top.y), INK, 2.0)
	c.draw_rect(r.grow(6.0), Color("7a2e22")) # la stoffa intorno
	c.draw_rect(r, Color("f6ecd2"))
	c.draw_rect(r.grow(6.0), INK, false, 2.0)
	for y: float in [r.position.y - 10.0, r.end.y + 4.0]: # i due bastoni
		c.draw_rect(Rect2(r.position.x - 14.0, y, r.size.x + 28.0, 8.0), WOOD_DARK)
	# La banana del maestro, a pennello
	var center := Vector2(r.get_center().x, r.position.y + 90.0)
	var pts := PackedVector2Array()
	for k in 13:
		var a := lerpf(PI * 0.15, PI * 0.85, k / 12.0)
		pts.append(center + Vector2(cos(a) * 48.0, sin(a) * 34.0 - 20.0))
	for k in range(12, -1, -1):
		var a := lerpf(PI * 0.15, PI * 0.85, k / 12.0)
		pts.append(center + Vector2(cos(a) * 34.0, sin(a) * 18.0 - 14.0))
	c.draw_colored_polygon(pts, BANANA)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 3.0)
	c.draw_circle(pts[0], 4.0, INK) # il picciolo
	for k in 3: # tre pennellate sotto, come una firma
		var y := r.position.y + 160.0 + k * 26.0
		c.draw_line(Vector2(r.position.x + 30.0 + k * 6.0, y), Vector2(r.end.x - 30.0 - k * 4.0, y + 4.0), INK, 6.0 - k)
	_text(c, Vector2(r.get_center().x, r.end.y - 14.0), "DOJO", 18, Color("7a2e22"))


func _draw_lantern(c: CanvasItem, hook: Vector2, t: float, seed_i: int) -> void:
	var swing := 0.06 * sin(t / 900.0 + seed_i * 1.7)
	var length := 46.0
	var at := hook + Vector2(sin(swing) * length, cos(swing) * length)
	c.draw_line(hook, at, INK, 2.0)
	var body := Rect2(at.x - 22.0, at.y, 44.0, 58.0)
	# Il bagliore intorno
	for k in 3:
		c.draw_circle(body.get_center(), 60.0 - k * 16.0, Color(1.0, 0.6, 0.3, 0.05))
	c.draw_rect(Rect2(body.position.x + 6.0, body.position.y - 6.0, body.size.x - 12.0, 8.0), INK)
	c.draw_rect(Rect2(body.position.x + 6.0, body.end.y - 2.0, body.size.x - 12.0, 8.0), INK)
	var pts := PackedVector2Array()
	for k in 17: # un ovale schiacciato: la lanterna di carta
		var a := TAU * k / 16.0
		pts.append(body.get_center() + Vector2(cos(a) * 24.0, sin(a) * 30.0))
	c.draw_colored_polygon(pts, LANTERN)
	for k in [-1, 0, 1]: # le costole di bambù
		c.draw_line(body.get_center() + Vector2(-23.0, k * 12.0), body.get_center() + Vector2(23.0, k * 12.0), Color(INK, 0.45), 1.5)
	c.draw_polyline(pts, INK, 2.0)
	c.draw_circle(body.get_center() + Vector2(-6.0, -8.0), 6.0, Color(1, 1, 0.8, 0.35))


# Il pavimento: tatami verdini con il bordo di stoffa sopra, e sotto il legno della pedana
func draw_solid(c: CanvasItem, s: Dictionary, _t: float, _pressed: Array) -> bool:
	var r := Rect2(float(s.x), float(s.y), float(s.width), float(s.height))
	c.draw_rect(r, WOOD)
	var plank := 26.0
	var y := r.position.y + 22.0
	while y < r.end.y:
		c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(INK, 0.35), 2.0)
		y += plank
	c.draw_rect(Rect2(r.position.x, r.position.y + 22.0, r.size.x, 4.0), Color(0, 0, 0, 0.3))
	# I tatami: due per campata, a giunti sfalsati
	var mat := BAY / 2.0
	var x := r.position.x
	var k := 0
	while x < r.end.x:
		var w := minf(mat, r.end.x - x)
		var col := TATAMI if k % 2 == 0 else TATAMI_DARK.lerp(TATAMI, 0.6)
		c.draw_rect(Rect2(x, r.position.y, w, 22.0), col)
		for g in range(1, 6): # la trama della paglia
			c.draw_line(Vector2(x + 2.0, r.position.y + g * 3.6), Vector2(x + w - 2.0, r.position.y + g * 3.6), Color(TATAMI_DARK, 0.35), 1.0)
		c.draw_rect(Rect2(x, r.position.y, 5.0, 22.0), BORDER)
		x += w
		k += 1
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3.0), BORDER)
	c.draw_line(Vector2(r.position.x, r.position.y + 22.0), Vector2(r.end.x, r.position.y + 22.0), INK, 2.0)
	c.draw_rect(r, INK, false, 3.0)
	return true


func _text(c: CanvasItem, center: Vector2, text: String, size: int, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(_font, Vector2(center.x - w / 2.0, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func draw_platform(_c: CanvasItem, _p: Dictionary, _t: float) -> bool:
	return false


func draw_mover(_c: CanvasItem, _m: Dictionary, _pos: Vector2, _t: float) -> bool:
	return false


func draw_hazard(_c: CanvasItem, _h: Dictionary, _r: Rect2, _on: bool, _t: float) -> bool:
	return false


func draw_pad(_c: CanvasItem, _p: Dictionary, _pressed_at: Variant, _t: float) -> bool:
	return false


func draw_front(_c: CanvasItem, _t: float, _view: Rect2, _pressed: Array) -> void:
	pass


func on_event(_e: Dictionary, _now_ms: float) -> void:
	pass


func cues(_before: float, _now: float, _pressed: Array) -> Array:
	return []
