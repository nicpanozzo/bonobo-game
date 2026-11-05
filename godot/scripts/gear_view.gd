# Oggetti per categoria (physics/gear.ts): il disegno degli oggetti nuovi, i loro effetti sui lottatori
# (gigante, mini, caffè, razzo, brownie, sonno) e gli scoppi. Solo disegno: tutto arriva da snapshot ed eventi.
# world_view.gd lo chiama dentro _draw_item, _draw_fighter e on_event.
extends RefCounted

const INK := Color("1b1612")
const RARE_GOLD := Color("ffd34d")
const COFFEE := Color("6f4426")
const CREMA := Color("c8955c")
const CUP := Color("f4efe6")
const STEEL := Color("b8bcc4")
const FIRE := Color("ff8a1f")
const BROWNIE := Color("5b3a24")
const LEAF := Color("6cbf3f")

# Gli oggetti che sa disegnare
const KINDS := ["ciabatta", "ciabattaMamma", "petardo", "petardoGrappolo", "petardino", "caffe", "moka", "brownie", "brownieNonna"]

const HeldView := preload("res://scripts/held_view.gd")

var booms: Array = [] # scoppi dei petardi: [{x, y, r, age}]
var quakes: Array = [] # scosse del gigante della nonna: [{x, y, r, age}]


static func draws(kind: String) -> bool:
	return kind in KINDS or HeldView.draws(kind)


# Le versioni rare (ItemSpec.rareOf) brillano d'oro dietro, così si riconoscono a colpo d'occhio
static func is_rare(game: Dictionary, kind: String) -> bool:
	return game.get("items", {}).get(kind, {}).get("rareOf") != null


# L'oggetto centrato in (0, 0), grande w x h. ink: il contorno; lit: la luce dell'arena; load: la miccia da 0 a 1 (-1 spenta)
static func draw_item(ci: CanvasItem, kind: String, w: float, h: float, load: float, now: int, ink: Color, lit: Color, rare: bool) -> void:
	if rare and not Access.calm:
		var pulse := 0.5 + 0.5 * sin(now / 260.0)
		ci.draw_circle(Vector2.ZERO, maxf(w, h) * (0.75 + 0.08 * pulse), Color(RARE_GOLD, 0.18 + 0.12 * pulse))
		for k in 4:
			var a := now / 900.0 + TAU * k / 4.0
			_star(ci, Vector2.from_angle(a) * maxf(w, h) * 0.8, 3.0 + 1.5 * pulse, Color(RARE_GOLD, 0.9))
	match kind:
		"ciabatta", "ciabattaMamma":
			_ciabatta(ci, w, h, Color("3b82c4") if kind == "ciabatta" else Color("e85d9e"), ink, lit, kind == "ciabattaMamma")
		"petardo", "petardino":
			_petardo(ci, Vector2.ZERO, w, h, Color("d63a2f") if kind == "petardo" else Color("f08a24"), ink, lit, load, now)
		"petardoGrappolo":
			for k in 3:
				var off := Vector2((k - 1) * w * 0.32, absf(k - 1) * h * 0.08)
				_petardo(ci, off, w * 0.4, h * 0.85, Color("f08a24") if k != 1 else Color("d63a2f"), ink, lit, load if k == 1 else -1.0, now)
			ci.draw_line(Vector2(-w * 0.45, h * 0.1), Vector2(w * 0.45, h * 0.1), Color("f2e3b3"), 2.0) # lo spago
		"caffe":
			_caffe(ci, w, h, ink, lit, now)
		"moka":
			_moka(ci, w, h, ink, lit, now)
		"brownie", "brownieNonna":
			_brownie(ci, w, h, ink, lit, kind == "brownieNonna")
		_:
			HeldView.draw_item(ci, kind, w, h, now, ink, lit) # impugnatura e sparo (held_view.gd)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		pts.append(c + Vector2.from_angle(TAU * k / 8.0 - PI / 2) * (r if k % 2 == 0 else r * 0.4))
	ci.draw_colored_polygon(pts, col)


static func _shade(c: Color, lit: Color) -> Color:
	return Color(c.r * lit.r, c.g * lit.g, c.b * lit.b, c.a)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, ink: Color, width := 2.0) -> void:
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), ink, width, true)


static func _rounded(cx: float, cy: float, w: float, h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(cx + w / 2 - r, cy - h / 2 + r), Vector2(cx + w / 2 - r, cy + h / 2 - r), Vector2(cx - w / 2 + r, cy + h / 2 - r), Vector2(cx - w / 2 + r, cy - h / 2 + r)]
	for i in 4:
		for k in 5:
			pts.append(corners[i] + Vector2.from_angle(-PI / 2 + PI / 2 * i + PI / 2 * k / 4.0) * r)
	return pts


# La ciabatta di profilo: la suola spessa, la fascia sopra; quella della mamma rosa col fiore
static func _ciabatta(ci: CanvasItem, w: float, h: float, col: Color, ink: Color, lit: Color, mamma: bool) -> void:
	var sole := _rounded(0, h * 0.25, w, h * 0.5, h * 0.22)
	ci.draw_colored_polygon(sole, _shade(col.darkened(0.15), lit))
	ci.draw_line(Vector2(-w * 0.45, h * 0.12), Vector2(w * 0.45, h * 0.12), _shade(col.lightened(0.35), lit), 1.5)
	_outline(ci, sole, ink)
	var strap := PackedVector2Array()
	for k in 9:
		var a := PI + PI * k / 8.0
		strap.append(Vector2(w * 0.05 + cos(a) * w * 0.3, sin(a) * h * 0.55))
	ci.draw_polyline(strap, ink, 6.0, true)
	ci.draw_polyline(strap, _shade(col.lightened(0.15), lit), 3.5, true)
	if mamma:
		var c := Vector2(w * 0.05, -h * 0.5)
		for k in 5:
			ci.draw_circle(c + Vector2.from_angle(TAU * k / 5.0) * 3.2, 2.6, Color("fff1f6"))
		ci.draw_circle(c, 2.2, RARE_GOLD)


# Il petardo: un cilindro rosso con la fascia bianca e la miccia. Acceso, la scintilla in cima e lampeggia sul finire
static func _petardo(ci: CanvasItem, off: Vector2, w: float, h: float, col: Color, ink: Color, lit: Color, load: float, now: int) -> void:
	var blink := load > 0.65 and int(now / maxf(40.0, 160.0 * (1.0 - load))) % 2 == 0
	var body_col := Color.WHITE if blink else _shade(col, lit)
	var body := _rounded(off.x, off.y + h * 0.1, w, h * 0.8, w * 0.2)
	ci.draw_colored_polygon(body, body_col)
	ci.draw_rect(Rect2(off.x - w / 2, off.y - h * 0.05, w, h * 0.16), _shade(Color("f6f1e7"), lit))
	ci.draw_line(Vector2(off.x - w * 0.25, off.y - h * 0.22), Vector2(off.x - w * 0.25, off.y + h * 0.4), Color(1, 1, 1, 0.35), 2.0)
	_outline(ci, body, ink)
	var top := Vector2(off.x, off.y - h * 0.3)
	var tip := top + Vector2(w * 0.35, -h * 0.25)
	var left := 1.0 if load < 0.0 else 1.0 - load # la miccia si accorcia mentre brucia
	var end := top.lerp(tip, maxf(0.15, left))
	ci.draw_line(top, end, Color("3a2a1e"), 2.0)
	if load >= 0.0:
		var flick := 0.6 + 0.4 * sin(now / 35.0)
		ci.draw_circle(end, 4.0 * flick + 2.0, Color(FIRE, 0.85))
		ci.draw_circle(end, 2.0, Color("fff3a0"))
		for k in 3:
			var a := now / 70.0 + k * 2.1
			ci.draw_line(end, end + Vector2.from_angle(a) * (5.0 + 3.0 * flick), Color("ffe066"), 1.2)


# La tazzina di caffè: bianca col manico, il caffè con la crema e il fumo che sale
static func _caffe(ci: CanvasItem, w: float, h: float, ink: Color, lit: Color, now: int) -> void:
	var cup := PackedVector2Array([Vector2(-w * 0.4, -h * 0.15), Vector2(w * 0.32, -h * 0.15), Vector2(w * 0.22, h * 0.42), Vector2(-w * 0.3, h * 0.42)])
	ci.draw_arc(Vector2(w * 0.36, h * 0.08), h * 0.2, -PI / 2, PI / 2, 10, ink, 5.0)
	ci.draw_arc(Vector2(w * 0.36, h * 0.08), h * 0.2, -PI / 2, PI / 2, 10, _shade(CUP, lit), 2.5)
	ci.draw_colored_polygon(cup, _shade(CUP, lit))
	_outline(ci, cup, ink)
	var top := PackedVector2Array()
	for k in 12:
		top.append(Vector2(-w * 0.04 + cos(TAU * k / 12.0) * w * 0.34, -h * 0.15 + sin(TAU * k / 12.0) * h * 0.08))
	ci.draw_colored_polygon(top, _shade(CREMA, lit))
	ci.draw_rect(Rect2(-w * 0.5, h * 0.42, w * 0.95, h * 0.08), _shade(CUP.darkened(0.1), lit)) # il piattino
	if not Access.calm:
		for k in 2:
			var pts := PackedVector2Array()
			for i in 6:
				var t := i / 5.0
				pts.append(Vector2(-w * 0.12 + k * w * 0.18 + sin(now / 250.0 + t * 5.0 + k) * 3.0, -h * 0.25 - t * h * 0.6))
			ci.draw_polyline(pts, Color(1, 1, 1, 0.55), 1.5, true)


# La moka a razzo: argento a otto lati col manico nero, e sotto una fiammata
static func _moka(ci: CanvasItem, w: float, h: float, ink: Color, lit: Color, now: int) -> void:
	if not Access.calm:
		var flick := 0.7 + 0.3 * sin(now / 40.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.25, h * 0.5), Vector2(0, h * (0.5 + 0.45 * flick)), Vector2(w * 0.25, h * 0.5)]), Color(FIRE, 0.9))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.12, h * 0.5), Vector2(0, h * (0.5 + 0.25 * flick)), Vector2(w * 0.12, h * 0.5)]), Color("fff3a0"))
	var low := PackedVector2Array([Vector2(-w * 0.42, h * 0.5), Vector2(w * 0.42, h * 0.5), Vector2(w * 0.3, 0), Vector2(-w * 0.3, 0)])
	var up := PackedVector2Array([Vector2(-w * 0.3, 0), Vector2(w * 0.3, 0), Vector2(w * 0.4, -h * 0.4), Vector2(-w * 0.4, -h * 0.4)])
	for part in [low, up]:
		ci.draw_colored_polygon(part, _shade(STEEL, lit))
		_outline(ci, part, ink)
	ci.draw_line(Vector2(-w * 0.12, h * 0.45), Vector2(-w * 0.08, -h * 0.35), Color(1, 1, 1, 0.6), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.15, -h * 0.4), Vector2(w * 0.15, -h * 0.4), Vector2(0, -h * 0.52)]), _shade(STEEL.darkened(0.2), lit))
	ci.draw_polyline(PackedVector2Array([Vector2(w * 0.38, -h * 0.3), Vector2(w * 0.58, -h * 0.22), Vector2(w * 0.5, h * 0.05), Vector2(w * 0.32, 0)]), INK, 4.0, true)


# Il brownie: un quadrotto marrone con la crosta più chiara e una fogliolina; quello della nonna su un piattino a merletto
static func _brownie(ci: CanvasItem, w: float, h: float, ink: Color, lit: Color, nonna: bool) -> void:
	if nonna:
		var plate := PackedVector2Array()
		for k in 20:
			plate.append(Vector2(cos(TAU * k / 20.0) * w * 0.55, h * 0.42 + sin(TAU * k / 20.0) * h * 0.14))
		ci.draw_colored_polygon(plate, _shade(Color("fbf6ee"), lit))
		for k in 10:
			ci.draw_circle(Vector2(cos(TAU * k / 10.0) * w * 0.5, h * 0.42 + sin(TAU * k / 10.0) * h * 0.12), 1.6, Color("d9c7a8"))
	var bw := w * (0.75 if nonna else 0.9)
	var body := _rounded(0, h * 0.08, bw, h * 0.66, 3.0)
	ci.draw_colored_polygon(body, _shade(BROWNIE, lit))
	ci.draw_colored_polygon(_rounded(0, -h * 0.14, bw, h * 0.22, 3.0), _shade(BROWNIE.lightened(0.25), lit))
	for k in 3:
		ci.draw_circle(Vector2((k - 1) * bw * 0.28, h * 0.12 + (k % 2) * 3.0), 1.8, _shade(Color("2e1c10"), lit)) # pezzi di cioccolato
	_outline(ci, body, ink)
	var leaf_at := Vector2(bw * 0.12, -h * 0.3)
	if nonna:
		ci.draw_circle(leaf_at + Vector2(-3, -2), 3.5, Color("e23d5b")) # un cuoricino della nonna
		ci.draw_circle(leaf_at + Vector2(3, -2), 3.5, Color("e23d5b"))
		ci.draw_colored_polygon(PackedVector2Array([leaf_at + Vector2(-6.5, -1), leaf_at + Vector2(6.5, -1), leaf_at + Vector2(0, 6)]), Color("e23d5b"))
	else:
		for k in 5:
			var a := -PI / 2 + (k - 2) * 0.5
			ci.draw_line(leaf_at, leaf_at + Vector2.from_angle(a) * (7.0 - absf(k - 2) * 1.5), LEAF, 2.0)


# Giganti e mini (brownie): il lottatore si disegna più grande o più piccolo attorno ai piedi
static func size_scale(p: Dictionary, game: Dictionary) -> float:
	var size: Dictionary = game.get("gear", {}).get("size", {})
	match str(p.get("powerup", "")):
		"gigante", "colosso":
			return float(size.get("giant", 1.5))
		"mini":
			return float(size.get("mini", 0.6))
	return 1.0


static func size_transform(p: Dictionary, game: Dictionary) -> Transform2D:
	var s := size_scale(p, game)
	if s == 1.0:
		return Transform2D.IDENTITY
	var feet := Vector2(float(p.x), float(p.y))
	return Transform2D.IDENTITY.translated(-feet).scaled(Vector2(s, s)).translated(feet)


# Gli effetti sopra al lottatore: fumo del caffè, fiamma della moka, "?" del brownie che deve salire, zZz del sonno,
# corona d'oro del gigante della nonna
static func draw_powerup(ci: CanvasItem, p: Dictionary, now: float, fw: float, fh: float, font: Font, game: Dictionary) -> void:
	var kind := str(p.get("powerup", ""))
	var head := Vector2(float(p.x), float(p.y) - fh * size_scale(p, game))
	match kind:
		"caffe":
			for k in 3: # righe di velocità dietro e fumo di caffè
				var y := float(p.y) - fh * (0.25 + 0.25 * k)
				var x := float(p.x) - float(p.facing) * (fw * 0.6 + fmod(now / 6.0 + k * 13.0, 24.0))
				ci.draw_line(Vector2(x, y), Vector2(x - float(p.facing) * 14.0, y), Color(CREMA, 0.75), 2.5)
		"razzo":
			var feet := Vector2(float(p.x), float(p.y))
			var flick := 0.7 + 0.3 * sin(now / 40.0)
			ci.draw_colored_polygon(PackedVector2Array([feet + Vector2(-10, -4), feet + Vector2(0, 26.0 * flick), feet + Vector2(10, -4)]), Color(FIRE, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([feet + Vector2(-5, -4), feet + Vector2(0, 14.0 * flick), feet + Vector2(5, -4)]), Color("fff3a0"))
		"brownie":
			var bob := sin(now / 180.0) * 3.0
			ci.draw_string_outline(font, head + Vector2(-7, -14 + bob), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 5, INK)
			ci.draw_string(font, head + Vector2(-7, -14 + bob), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, LEAF)
		"sonno":
			for k in 3:
				var t := fmod(now / 1200.0 + k / 3.0, 1.0)
				var at := head + Vector2(10 + t * 22.0, -10 - t * 34.0)
				ci.draw_string_outline(font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 + 10 * t), 4, INK)
				ci.draw_string(font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 + 10 * t), Color(0.8, 0.9, 1.0, 1.0 - t))
		"colosso":
			var c := head + Vector2(0, -12.0)
			var pts := PackedVector2Array([c + Vector2(-16, 6), c + Vector2(-16, -6), c + Vector2(-8, 0), c + Vector2(0, -10), c + Vector2(8, 0), c + Vector2(16, -6), c + Vector2(16, 6)])
			ci.draw_colored_polygon(pts, RARE_GOLD)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 2.0, true)


# Gli eventi "gear" (physics/gear.ts): scoppi e scosse da disegnare, restituisce quanto far tremare lo schermo
func on_event(e: Dictionary) -> float:
	match str(e.phase):
		"boom":
			booms.append({"x": float(e.x), "y": float(e.y), "r": float(e.get("r", 90)), "age": 0.0})
			return 4.0 + float(e.get("r", 90)) / 12.0
		"quake":
			quakes.append({"x": float(e.x), "y": float(e.y), "r": float(e.get("r", 220)), "age": 0.0})
			return 7.0
	return 0.0


func step(dt_ms: float) -> void:
	for list in [booms, quakes]:
		for b in list:
			b.age += dt_ms
	booms = booms.filter(func(b): return b.age < 420.0)
	quakes = quakes.filter(func(b): return b.age < 520.0)


# Lo scoppio: un lampo bianco, una palla di fuoco che si allarga e un anello di fumo; la scossa: un'onda di polvere a terra
func draw(ci: CanvasItem) -> void:
	for b in booms:
		var t: float = b.age / 420.0
		var c := Vector2(b.x, b.y)
		if t < 0.25:
			ci.draw_circle(c, b.r * (0.4 + t * 2.0), Color(1, 1, 0.85, 0.9 * (1.0 - t * 4.0)))
		ci.draw_circle(c, b.r * (0.5 + 0.6 * t), Color(FIRE, 0.75 * (1.0 - t)))
		ci.draw_circle(c, b.r * (0.3 + 0.4 * t), Color("ffd34d", 0.8 * (1.0 - t)))
		ci.draw_arc(c, b.r * (0.7 + 0.6 * t), 0, TAU, 32, Color(0.3, 0.3, 0.3, 0.6 * (1.0 - t)), 6.0 * (1.0 - t) + 1.0)
		for k in 8:
			var a := TAU * k / 8.0 + 0.3
			ci.draw_line(c + Vector2.from_angle(a) * b.r * (0.4 + t), c + Vector2.from_angle(a) * b.r * (0.6 + 1.2 * t), Color("ffe066", 1.0 - t), 3.0)
	for q in quakes:
		var t: float = q.age / 520.0
		for side in [-1.0, 1.0]:
			for k in 5:
				var x: float = q.x + side * q.r * t * (0.4 + 0.15 * k)
				ci.draw_circle(Vector2(x, q.y - 6.0 - 10.0 * sin(t * PI) * (1.0 - k * 0.15)), 9.0 * (1.0 - t) + 2.0, Color(0.75, 0.65, 0.5, 0.7 * (1.0 - t)))
