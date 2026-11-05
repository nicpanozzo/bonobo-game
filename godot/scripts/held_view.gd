extends RefCounted
# Oggetti da impugnare e da sparo (physics/held.ts): disegno di scopa, ombrellone, pesce, anguilla, pistola, idrante,
# sparabolle e dei colpi sparati; il blocco di ghiaccio e la bolla attorno a chi ci è chiuso; scosse, getti e scoppi.
# Solo disegno: ascolta gli eventi "gear" e lo snapshot, non tocca la fisica.

const INK := Color("1b1612")
const WOOD := Color("a8743c")
const STRAW := Color("e0b85a")
const ICE := Color("bfe6ff")
const WATER := Color("7fd3ff")
const ZAP := Color("fff27a")

const KINDS := ["scopa", "ombrellone", "pesce", "anguilla", "pistola", "idrante", "sparabolle", "sparabolleTriplo", "goccia", "bolla", "bollaRimbalzina"]
const MELEE := ["scopa", "ombrellone", "pesce", "anguilla"]

var zaps: Array = [] # scosse dell'anguilla: [{x, y, id, age}], dalla vittima a chi la prende
var jets: Array = [] # getti dell'idrante: [{x, y, r, age}]
var pops: Array = [] # bolle scoppiate e armi rotte: [{x, y, age, col}]


static func draws(kind: String) -> bool:
	return kind in KINDS


# Le armi da impugnare in mano si inclinano in avanti quando il colpo è attivo
static func is_melee(kind: String) -> bool:
	return kind in MELEE


# L'oggetto centrato in (0, 0), grande w x h (stesso schema di GearView.draw_item, che gli passa questi tipi)
static func draw_item(ci: CanvasItem, kind: String, w: float, h: float, now: int, ink: Color, lit: Color) -> void:
	match kind:
		"scopa":
			_stick(ci, h, ink, lit)
			var head := PackedVector2Array([Vector2(-w * 0.9, h * 0.22), Vector2(w * 0.9, h * 0.22), Vector2(w * 1.3, h * 0.5), Vector2(-w * 1.3, h * 0.5)])
			ci.draw_colored_polygon(head, _shade(STRAW, lit))
			_outline(ci, head, ink)
			for k in 5:
				var x := lerpf(-w * 1.1, w * 1.1, k / 4.0)
				ci.draw_line(Vector2(x * 0.75, h * 0.26), Vector2(x, h * 0.48), _shade(STRAW.darkened(0.3), lit), 1.5)
		"ombrellone":
			_stick(ci, h, ink, lit)
			var top := PackedVector2Array()
			for k in 9:
				var a := PI + PI * k / 8.0
				top.append(Vector2(cos(a) * w * 1.9, -h * 0.32 + sin(a) * w * 1.1))
			ci.draw_colored_polygon(top, _shade(Color("e8483c"), lit))
			for k in 4: # spicchi bianchi
				var a0 := PI + PI * (2 * k + 0.5) / 8.0
				var a1 := PI + PI * (2 * k + 1.5) / 8.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -h * 0.32), Vector2(cos(a0) * w * 1.9, -h * 0.32 + sin(a0) * w * 1.1), Vector2(cos(a1) * w * 1.9, -h * 0.32 + sin(a1) * w * 1.1)]), _shade(Color("f6f1e7"), lit))
			_outline(ci, top, ink)
		"pesce", "anguilla":
			var col := _shade(Color("8fb8d8") if kind == "pesce" else Color("3c8f5a"), lit)
			var body := PackedVector2Array()
			for k in 12:
				var a := TAU * k / 12.0
				var wave := sin(now / 120.0 + a * 2.0) * 1.5 if kind == "anguilla" else 0.0
				body.append(Vector2(cos(a) * w * 0.4, sin(a) * h * 0.45 + wave))
			ci.draw_colored_polygon(body, col)
			_outline(ci, body, ink)
			var tail := PackedVector2Array([Vector2(w * 0.36, 0), Vector2(w * 0.5, -h * 0.5), Vector2(w * 0.5, h * 0.5)])
			ci.draw_colored_polygon(tail, col)
			_outline(ci, tail, ink)
			ci.draw_circle(Vector2(-w * 0.26, -h * 0.1), 2.0, INK)
			if kind == "pesce": # brina
				for k in 3:
					ci.draw_line(Vector2(-w * 0.1 + k * 6.0, -h * 0.3), Vector2(-w * 0.05 + k * 6.0, h * 0.2), Color(1, 1, 1, 0.7), 1.5)
			elif not Access.calm and int(now / 90.0) % 3 == 0: # scintille
				ci.draw_polyline(PackedVector2Array([Vector2(-w * 0.2, -h * 0.6), Vector2(-w * 0.1, -h * 0.9), Vector2(0, -h * 0.65), Vector2(w * 0.1, -h * 1.0)]), ZAP, 2.0)
		"pistola":
			_gun(ci, w, h, _shade(Color("2fb7e8"), lit), _shade(Color("ffd34d"), lit), ink)
		"sparabolle", "sparabolleTriplo":
			_gun(ci, w, h, _shade(Color("f2a6d8") if kind == "sparabolle" else Color("a66cf0"), lit), _shade(Color("7ee0c0"), lit), ink)
			var n := 3 if kind == "sparabolleTriplo" else 1
			for k in n:
				ci.draw_arc(Vector2(w * 0.55, -h * 0.35 + (k - (n - 1) / 2.0) * 7.0), 4.0, 0, TAU, 12, Color(1, 1, 1, 0.8), 1.5)
		"idrante":
			var body := PackedVector2Array([Vector2(-w * 0.35, h * 0.5), Vector2(-w * 0.35, -h * 0.2), Vector2(-w * 0.2, -h * 0.45), Vector2(w * 0.2, -h * 0.45), Vector2(w * 0.35, -h * 0.2), Vector2(w * 0.35, h * 0.5)])
			ci.draw_colored_polygon(body, _shade(Color("d8342c"), lit))
			_outline(ci, body, ink)
			var nozzle := PackedVector2Array([Vector2(w * 0.35, -h * 0.1), Vector2(w * 0.6, -h * 0.1), Vector2(w * 0.6, h * 0.12), Vector2(w * 0.35, h * 0.12)])
			ci.draw_colored_polygon(nozzle, _shade(Color("c0c4cc"), lit))
			_outline(ci, nozzle, ink)
			ci.draw_line(Vector2(-w * 0.45, h * 0.15), Vector2(w * 0.35, h * 0.15), ink, 2.0)
		"goccia":
			var drop := PackedVector2Array([Vector2(0, -h * 0.6), Vector2(w * 0.45, h * 0.1), Vector2(0, h * 0.5), Vector2(-w * 0.45, h * 0.1)])
			ci.draw_colored_polygon(drop, WATER)
			ci.draw_circle(Vector2(-w * 0.12, 0), w * 0.12, Color(1, 1, 1, 0.8))
		"bolla", "bollaRimbalzina":
			var tint := Color("f2a6d8") if kind == "bolla" else Color("a66cf0")
			_bubble(ci, Vector2.ZERO, w * 0.5, tint, now)


static func _stick(ci: CanvasItem, h: float, ink: Color, lit: Color) -> void:
	ci.draw_line(Vector2(0, -h * 0.5), Vector2(0, h * 0.25), ink, 6.0)
	ci.draw_line(Vector2(0, -h * 0.5), Vector2(0, h * 0.25), _shade(WOOD, lit), 3.5)


static func _gun(ci: CanvasItem, w: float, h: float, col: Color, tank: Color, ink: Color) -> void:
	var body := PackedVector2Array([Vector2(-w * 0.5, -h * 0.4), Vector2(w * 0.45, -h * 0.4), Vector2(w * 0.45, -h * 0.05), Vector2(-w * 0.05, -h * 0.05), Vector2(-w * 0.2, h * 0.5), Vector2(-w * 0.45, h * 0.5), Vector2(-w * 0.35, -h * 0.05), Vector2(-w * 0.5, -h * 0.05)])
	ci.draw_colored_polygon(body, col)
	_outline(ci, body, ink)
	ci.draw_circle(Vector2(-w * 0.12, -h * 0.55), h * 0.22, tank)
	ci.draw_arc(Vector2(-w * 0.12, -h * 0.55), h * 0.22, 0, TAU, 14, ink, 1.5)


# Una bolla di sapone: velo trasparente, riflesso e iridescenza che gira
static func _bubble(ci: CanvasItem, c: Vector2, r: float, tint: Color, now: float) -> void:
	ci.draw_circle(c, r, Color(tint, 0.18))
	ci.draw_arc(c, r, 0, TAU, 28, Color(tint.lightened(0.3), 0.85), 2.0, true)
	var a := now / 700.0
	ci.draw_arc(c, r * 0.88, a, a + 1.2, 10, Color(0.6, 1.0, 0.9, 0.6), 2.0, true)
	ci.draw_arc(c, r * 0.7, PI * 1.1, PI * 1.45, 6, Color(1, 1, 1, 0.9), 3.0, true)


static func _shade(c: Color, lit: Color) -> Color:
	return Color(c.r * lit.r, c.g * lit.g, c.b * lit.b, c.a)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, ink: Color, width := 2.0) -> void:
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), ink, width, true)


# Sopra al lottatore: il blocco di ghiaccio del pesce, la bolla dello sparabolle
static func draw_powerup(ci: CanvasItem, p: Dictionary, now: float, fw: float, fh: float) -> void:
	match str(p.get("powerup", "")):
		"gelo":
			var r := Rect2(float(p.x) - fw * 0.7, float(p.y) - fh * 1.05, fw * 1.4, fh * 1.08)
			ci.draw_rect(r, Color(ICE, 0.45))
			ci.draw_rect(r, Color(1, 1, 1, 0.9), false, 2.5)
			ci.draw_line(r.position + Vector2(6, 8), r.position + Vector2(r.size.x * 0.4, r.size.y * 0.35), Color(1, 1, 1, 0.8), 3.0)
			ci.draw_line(r.position + Vector2(r.size.x - 8, r.size.y * 0.6), r.position + Vector2(r.size.x * 0.75, r.size.y - 6), Color(1, 1, 1, 0.6), 2.0)
		"bolla":
			var c := Vector2(float(p.x), float(p.y) - fh * 0.5)
			var wob := 1.0 + 0.04 * sin(now / 90.0)
			_bubble(ci, c, maxf(fw, fh) * 0.75 * wob, Color("f2a6d8"), now)


# Gli eventi "gear" di held.ts; restituisce quanto far tremare lo schermo
func on_event(e: Dictionary) -> float:
	match str(e.phase):
		"zap":
			zaps.append({"x": float(e.x), "y": float(e.y), "id": str(e.id), "age": 0.0})
			return 3.0
		"jet":
			jets.append({"x": float(e.x), "y": float(e.y), "r": float(e.get("r", 900)), "age": 0.0})
			return 5.0
		"pop", "break", "freeze":
			var col := Color(1, 0.8, 0.95) if e.phase == "pop" else (ICE if e.phase == "freeze" else STRAW)
			pops.append({"x": float(e.x), "y": float(e.y) - (30.0 if e.phase == "freeze" else 0.0), "age": 0.0, "col": col})
	return 0.0


func step(dt_ms: float) -> void:
	for list in [zaps, jets, pops]:
		for z in list:
			z.age += dt_ms
	zaps = zaps.filter(func(z): return z.age < 260.0)
	jets = jets.filter(func(z): return z.age < 320.0)
	pops = pops.filter(func(z): return z.age < 300.0)


# positions: id giocatore -> piedi, per far arrivare la scossa addosso a chi la prende
func draw(ci: CanvasItem, positions: Dictionary, fh: float) -> void:
	for z in zaps:
		if not positions.has(z.id):
			continue
		var from := Vector2(z.x, z.y)
		var to: Vector2 = positions[z.id] + Vector2(0, -fh * 0.5)
		var pts := PackedVector2Array([from])
		for k in range(1, 6): # zig-zag che cambia a ogni fotogramma della scossa
			var t := k / 6.0
			var side := 9.0 if (k + int(z.age / 50.0)) % 2 == 0 else -9.0
			pts.append(from.lerp(to, t) + (to - from).orthogonal().normalized() * side)
		pts.append(to)
		ci.draw_polyline(pts, Color(ZAP, 1.0 - z.age / 260.0), 4.0)
		ci.draw_polyline(pts, Color(1, 1, 1, 1.0 - z.age / 260.0), 1.5)
	for j in jets:
		var t: float = j.age / 320.0
		var reach: float = j.r * minf(1.0, t * 4.0)
		var hgt := 26.0 * (1.0 - t * 0.6)
		ci.draw_rect(Rect2(j.x + minf(0.0, reach), j.y - hgt / 2.0, absf(reach), hgt), Color(WATER, 0.75 * (1.0 - t)))
		ci.draw_rect(Rect2(j.x + minf(0.0, reach), j.y - hgt / 6.0, absf(reach), hgt / 3.0), Color(1, 1, 1, 0.7 * (1.0 - t)))
	for p in pops:
		var t: float = p.age / 300.0
		for k in 8:
			var a := TAU * k / 8.0
			var c := Vector2(p.x, p.y) + Vector2.from_angle(a) * (10.0 + 30.0 * t)
			ci.draw_circle(c, 3.0 * (1.0 - t) + 1.0, Color(p.col, 1.0 - t))
