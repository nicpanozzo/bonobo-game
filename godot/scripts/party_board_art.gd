# Bonobo Party (#579): il disegno del tabellone, separato dalla logica di party_view.gd. L'isola dei Bonobo nel mare
# di notte: la strada di sabbia che fa il giro, la giungla e le palme ai lati, le caselle a gettone con il loro simbolo
# disegnato (banana, buccia, carta, bottega, partenza). Tutto fatto col codice e fermo nel seme delle caselle, così
# ogni partita ha la sua isola ma le palme non saltano da un fotogramma all'altro. Solo funzioni statiche su un CanvasItem.
extends RefCounted

const UI := preload("res://scripts/ui.gd")

const SEA := Color("162a4a")
const SEA_DEEP := Color("0f1d36")
const WAVE := Color("2f4f7d")
const SAND := Color("e7c98a")
const SAND_DARK := Color("b9955a")
const GRASS := Color("3f8f4f")
const GRASS_DARK := Color("2d6b3b")
const TRUNK := Color("8a5a32")
const LEAF := Color("4fbf63")
const LEAF_DARK := Color("2f7f43")
const ROAD_W := 58.0 # la strada di sabbia, pixel
const LAND_W := 150.0 # l'erba attorno alla strada, pixel
const TILE_R := 19.0 # raggio di un gettone-casella, pixel
const TILT := 0.42 # quanto è schiacciato il gettone visto di sbieco (altezza/larghezza)


# Il mare: fondo a fasce e onde a mezzaluna che scorrono piano
static func sea(ci: CanvasItem, r: Rect2, t: float) -> void:
	ci.draw_rect(r, SEA_DEEP)
	var bands := 6
	for i in bands:
		var y := r.position.y + r.size.y * i / bands
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, r.size.y / bands + 1), SEA_DEEP.lerp(SEA, float(i) / (bands - 1)))
	var step := 120.0
	var row := 0
	var y0 := r.position.y + 40.0
	while y0 < r.end.y:
		var shift := fmod(t * 14.0 + row * 57.0, step)
		var x := r.position.x - step + shift
		while x < r.end.x + step:
			ci.draw_arc(Vector2(x, y0), 14.0, PI * 1.15, PI * 1.85, 8, WAVE, 2.0, true)
			x += step
		y0 += 70.0
		row += 1


# L'isola: un nastro d'erba largo attorno a ogni pezzo di strada, con la riva di sabbia sotto, poi la strada sopra.
# edges: [[a, b], ...] in pixel; centre: il centro dell'isola, riempito di giungla
static func island(ci: CanvasItem, edges: Array, centre_poly: PackedVector2Array) -> void:
	if centre_poly.size() >= 3:
		ci.draw_colored_polygon(centre_poly, GRASS_DARK)
	for e in edges:
		_band(ci, e[0], e[1], LAND_W + 26.0, SAND_DARK)
	for e in edges:
		_band(ci, e[0], e[1], LAND_W + 14.0, SAND)
	for e in edges:
		_band(ci, e[0], e[1], LAND_W, GRASS)
	for e in edges:
		_band(ci, e[0], e[1], ROAD_W + 8.0, SAND_DARK)
	for e in edges:
		_band(ci, e[0], e[1], ROAD_W, SAND)
	# Le orme sulla strada: trattini scuri, uno ogni 26 pixel
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := int(a.distance_to(b) / 26.0)
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			ci.draw_circle(p, 2.5, SAND_DARK)


# Un pezzo di strada largo w, con le punte tonde così i pezzi si attaccano senza buchi
static func _band(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, col, w)
	ci.draw_circle(a, w / 2, col)
	ci.draw_circle(b, w / 2, col)


# Una palma: tronco curvo a segmenti e cinque foglie che ondeggiano col vento
static func palm(ci: CanvasItem, base: Vector2, s: float, t: float, lean: float) -> void:
	var top := base + Vector2(lean * 26.0, -70.0) * s
	ci.draw_colored_polygon(_ellipse(base + Vector2(0, 3) * s, 22.0 * s, 7.0 * s), Color(0, 0, 0, 0.25))
	var prev := base
	for k in range(1, 7):
		var u := k / 6.0
		var p := base.lerp(top, u) + Vector2(sin(u * PI) * lean * 10.0 * s, 0)
		ci.draw_line(prev, p, UI.INK, 9.0 * s)
		ci.draw_line(prev, p, TRUNK, 6.0 * s)
		prev = p
	var sway := sin(t * 1.6 + base.x * 0.05) * 0.12
	for i in 5:
		var a := -PI / 2 + (i - 2) * 0.62 + sway
		var tip := top + Vector2.from_angle(a + PI / 2 * signf(i - 2.0) * 0.35) * 34.0 * s
		var mid := top.lerp(tip, 0.5) + Vector2(0, -8.0 * s)
		var leaf := PackedVector2Array([top, mid + Vector2(0, -6) * s, tip, mid + Vector2(0, 5) * s])
		ci.draw_colored_polygon(leaf, LEAF if i % 2 == 0 else LEAF_DARK)
		ci.draw_polyline(leaf + PackedVector2Array([leaf[0]]), UI.INK, 2.0 * s, true)
	ci.draw_circle(top + Vector2(3, 4) * s, 4.0 * s, Color("6b3f1f"))
	ci.draw_circle(top + Vector2(-4, 5) * s, 4.0 * s, Color("6b3f1f"))


# Un cespuglio della giungla: tre cerchi uno sull'altro
static func bush(ci: CanvasItem, c: Vector2, s: float) -> void:
	for k in 3:
		var o := Vector2((k - 1) * 11.0, -absf(k - 1.0) * -4.0) * s
		ci.draw_circle(c + o + Vector2(0, 2), 12.0 * s, UI.INK)
		ci.draw_circle(c + o, 11.0 * s, LEAF_DARK if k != 1 else LEAF)


# Una casella a gettone: lo spessore sotto, la faccia sopra col simbolo. glow: la casella illuminata (la Corona, il turno)
static func tile(ci: CanvasItem, c: Vector2, kind: String, col: Color, fork: bool) -> void:
	var rx := TILE_R
	var ry := TILE_R * TILT * 1.6
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, 9), rx + 2, ry + 2), UI.INK)
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, 6), rx, ry), col.darkened(0.45))
	ci.draw_colored_polygon(_ellipse(c, rx, ry), col)
	ci.draw_polyline(_ellipse(c, rx, ry, true), UI.INK, 2.5, true)
	ci.draw_polyline(_arc_points(c + Vector2(0, -1), rx - 4, ry - 3, PI * 1.1, PI * 1.6), Color(1, 1, 1, 0.45), 2.0, true)
	if fork:
		ci.draw_polyline(_ellipse(c, rx + 7, ry + 5, true), UI.PAPER, 2.0, true)
	icon(ci, c + Vector2(0, -2), kind)


# Il simbolo di una casella, disegnato sulla faccia del gettone
static func icon(ci: CanvasItem, c: Vector2, kind: String) -> void:
	match kind:
		"banana":
			_mini_banana(ci, c, Color("fff2a8"))
		"buccia":
			# Una buccia aperta: tre lembi marroni
			for i in 3:
				var a := -PI / 2 + (i - 1) * 0.9
				var tip := c + Vector2.from_angle(a) * 10.0 + Vector2(0, 4)
				ci.draw_line(c + Vector2(0, 4), tip, UI.INK, 5.0)
				ci.draw_line(c + Vector2(0, 4), tip, Color("ffe08a"), 3.0)
		"evento":
			var card := Rect2(c - Vector2(7, 9), Vector2(14, 16))
			ci.draw_rect(card.grow(1.5), UI.INK)
			ci.draw_rect(card, UI.PAPER)
			ci.draw_string(UI.display(), c + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6a3fc4"))
		"bottega":
			# Una bancarella: tetto a righe e banco
			var roof := Rect2(c - Vector2(11, 9), Vector2(22, 7))
			ci.draw_rect(roof.grow(1.5), UI.INK)
			for k in 4:
				ci.draw_rect(Rect2(roof.position + Vector2(k * 5.5, 0), Vector2(5.5, 7)), UI.PUNCH if k % 2 == 0 else UI.PAPER)
			ci.draw_rect(Rect2(c + Vector2(-9, 0), Vector2(18, 7)), UI.INK)
			ci.draw_rect(Rect2(c + Vector2(-8, 1), Vector2(16, 5)), Color("c98a4a"))
		"start":
			ci.draw_line(c + Vector2(-5, 9), c + Vector2(-5, -11), UI.INK, 3.0)
			var flag := PackedVector2Array([c + Vector2(-4, -11), c + Vector2(10, -7), c + Vector2(-4, -3)])
			ci.draw_colored_polygon(flag, UI.PUNCH)
			ci.draw_polyline(flag + PackedVector2Array([flag[0]]), UI.INK, 1.5, true)


static func _mini_banana(ci: CanvasItem, c: Vector2, col: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var hub := c + Vector2(0, -10)
	for k in 9:
		var u := k / 8.0
		var a := lerpf(PI * 0.2, PI * 0.8, u)
		var w := 4.0 * (0.3 + 0.7 * sin(PI * u))
		outer.append(hub + Vector2.from_angle(a) * (13.0 + w * 0.5))
		inner.append(hub + Vector2.from_angle(a) * (13.0 - w * 0.5))
	inner.reverse()
	var body := outer + inner
	for i in body.size(): # inclinata, come una banana appoggiata
		body[i] = c + (body[i] - c).rotated(-0.55) + Vector2(1, 2)
	ci.draw_colored_polygon(body, col)
	ci.draw_polyline(body + PackedVector2Array([body[0]]), UI.INK, 1.5, true)


# La Corona vera, sopra la sua casella: un raggio di luce che sale dal gettone e la corona che gira e brilla
static func crown_beam(ci: CanvasItem, c: Vector2, t: float) -> void:
	var h := 120.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var beam := PackedVector2Array([c + Vector2(-TILE_R, 0), c + Vector2(TILE_R, 0), c + Vector2(TILE_R * 0.5, -h), c + Vector2(-TILE_R * 0.5, -h)])
	ci.draw_colored_polygon(beam, Color(1.0, 0.85, 0.2, 0.12 + 0.1 * pulse))
	for k in 4:
		var a := t * 1.5 + k * TAU / 4
		var p := c + Vector2(cos(a) * 26.0, -50.0 + sin(a) * 6.0 - k * 10.0)
		ci.draw_circle(p, 2.5, Color(1, 0.95, 0.6, 0.8))


# L'ombra di una pedina sul tabellone: più piccola e chiara quando salta
static func shadow(ci: CanvasItem, c: Vector2, w: float, hop: float) -> void:
	var k := clampf(1.0 + hop / 40.0, 0.5, 1.0) # hop è negativo in salto
	ci.draw_colored_polygon(_ellipse(c, w * 0.5 * k, w * 0.16 * k), Color(0, 0, 0, 0.35 * k))


static func _ellipse(c: Vector2, rx: float, ry: float, closed := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 24
	for i in n + (1 if closed else 0):
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _arc_points(c: Vector2, rx: float, ry: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(from, to, i / 8.0)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# Dove mettere palme e cespugli: punti fermi (dal numero delle caselle) sull'erba ai lati della strada, lontani dalle
# caselle. Restituisce [[pos, scala, è_palma, pendenza], ...]
static func decor(points: Array, edges: Array, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		if a.distance_to(b) < 30.0:
			continue
		var n := (b - a).normalized().orthogonal()
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.6:
				continue
			var p: Vector2 = a.lerp(b, rng.randf_range(0.3, 0.7)) + n * float(side) * rng.randf_range(ROAD_W * 0.5 + 22.0, LAND_W * 0.5 - 4.0)
			var free := true
			for q in points:
				if (q as Vector2).distance_to(p) < 46.0:
					free = false
					break
			for o in out:
				if (o[0] as Vector2).distance_to(p) < 34.0:
					free = false
					break
			if free:
				out.append([p, rng.randf_range(0.6, 0.9), rng.randf() < 0.55, rng.randf_range(-0.6, 0.6)])
	out.sort_custom(func(x, y): return x[0].y < y[0].y) # dal fondo in avanti: quelle davanti coprono quelle dietro
	return out
