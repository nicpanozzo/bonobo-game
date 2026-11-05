# Oggetti pesanti e da cavalcare (physics/ride.ts): il disegno di casse, lavatrici, monopattini e carrelli, dove stanno
# quando qualcuno li porta e gli effetti (schegge della cassa, schiuma, polvere dell'investimento). Solo disegno:
# tutto arriva da snapshot ed eventi. world_view.gd lo chiama dentro _draw_items, _draw_item e on_event.
extends RefCounted

const RARE_GOLD := Color("ffd34d")
const WOOD := Color("a86b32")
const GOLD := Color("f2c230")
const ENAMEL := Color("e8ecef")
const CRAZY := Color("ff6fb5")
const GLASS := Color("8fd3f4")
const FIRE := Color("ff8a1f")

# Gli oggetti che sa disegnare
const KINDS := ["cassa", "cassaOro", "lavatrice", "lavatriceMatta", "monopattino", "monopattinoRazzo", "carrello", "carrelloTurbo"]
const HEAVY := ["cassa", "cassaOro", "lavatrice", "lavatriceMatta"]
const MOUNTS := ["monopattino", "monopattinoRazzo", "carrello", "carrelloTurbo"]

var shards: Array = [] # schegge delle casse rotte: [{x, y, vx, vy, age, col}]
var puffs: Array = [] # schiuma, polvere e scintille: [{x, y, r, age, col}]


static func draws(kind: String) -> bool:
	return kind in KINDS


# Dove poggia (la base) un oggetto in mano: i pesanti sopra la testa, i mezzi sotto i piedi. Gli altri dove dice world_view
static func held_pos(kind: String, feet: Vector2, fh: float, fallback: Vector2) -> Vector2:
	if kind in HEAVY:
		return feet + Vector2(0, -fh - 2.0)
	if kind in MOUNTS:
		return feet + Vector2(0, 6.0)
	return fallback


# Il mio lottatore porta un pesante o cavalca: la predizione non sa delle velocità diverse, decide il server
static func carrying(items: Array, id: String) -> bool:
	for it in items:
		if it.get("heldBy") == id and (str(it.kind) in HEAVY or str(it.kind) in MOUNTS):
			return true
	return false


static func _shade(c: Color, lit: Color) -> Color:
	return Color(c.r * lit.r, c.g * lit.g, c.b * lit.b, c.a)


# L'oggetto centrato in (0, 0), grande w x h. load: centrifuga o razzo che restano, da 1 a 0 (-1 se niente)
static func draw_item(ci: CanvasItem, kind: String, w: float, h: float, load: float, now: int, ink: Color, lit: Color, rare: bool) -> void:
	if rare and not Access.calm:
		var pulse := 0.5 + 0.5 * sin(now / 260.0)
		ci.draw_circle(Vector2.ZERO, maxf(w, h) * (0.72 + 0.08 * pulse), Color(RARE_GOLD, 0.16 + 0.1 * pulse))
	match kind:
		"cassa", "cassaOro":
			_crate(ci, w, h, GOLD if kind == "cassaOro" else WOOD, ink, lit, kind == "cassaOro", now)
		"lavatrice", "lavatriceMatta":
			_washer(ci, w, h, ink, lit, load, now, kind == "lavatriceMatta")
		"monopattino", "monopattinoRazzo":
			_scooter(ci, w, h, ink, lit, load, now, kind == "monopattinoRazzo")
		"carrello", "carrelloTurbo":
			_cart(ci, w, h, ink, lit, kind == "carrelloTurbo")


# La cassa di legno: assi, le due diagonali e i chiodi. Quella d'oro luccica
static func _crate(ci: CanvasItem, w: float, h: float, col: Color, ink: Color, lit: Color, gold: bool, now: int) -> void:
	var r := Rect2(-w / 2, -h / 2, w, h)
	ci.draw_rect(r, _shade(col, lit))
	for k in range(1, 3):
		var y := -h / 2 + h * k / 3.0
		ci.draw_line(Vector2(-w / 2, y), Vector2(w / 2, y), _shade(col.darkened(0.3), lit), 1.5)
	ci.draw_line(Vector2(-w / 2 + 4, -h / 2 + 4), Vector2(w / 2 - 4, h / 2 - 4), _shade(col.darkened(0.25), lit), 4.0)
	ci.draw_line(Vector2(-w / 2 + 4, h / 2 - 4), Vector2(w / 2 - 4, -h / 2 + 4), _shade(col.darkened(0.25), lit), 4.0)
	ci.draw_rect(Rect2(-w / 2 + 2, -h / 2 + 2, w - 4, h - 4), _shade(col.darkened(0.35), lit), false, 3.0)
	ci.draw_rect(r, ink, false, 2.0)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		ci.draw_circle(c * Vector2(w / 2 - 5, h / 2 - 5), 1.6, ink)
	if gold and not Access.calm:
		var t := fmod(now / 900.0, 1.0)
		var x := -w / 2 + w * t
		ci.draw_line(Vector2(x - 6, -h / 2), Vector2(x + 6, h / 2), Color(1, 1, 0.9, 0.5), 4.0)
	else:
		ci.draw_string(ThemeDB.fallback_font, Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ink, 0.7))


# La lavatrice: cassa smaltata, pannello coi pomelli e l'oblò. In centrifuga trema, il cestello gira e c'è la schiuma
static func _washer(ci: CanvasItem, w: float, h: float, ink: Color, lit: Color, load: float, now: int, crazy: bool) -> void:
	var on := load > 0.0
	var o := Vector2(sin(now / 22.0), cos(now / 17.0)) * 2.0 if on and not Access.calm else Vector2.ZERO
	var col := CRAZY if crazy else ENAMEL
	var body := Rect2(o.x - w / 2, o.y - h / 2, w, h)
	ci.draw_rect(body, _shade(col, lit))
	ci.draw_rect(Rect2(o.x - w / 2, o.y - h / 2, w, h * 0.2), _shade(col.darkened(0.12), lit))
	for k in 2:
		ci.draw_circle(o + Vector2(w * (0.18 + 0.15 * k), -h * 0.4), 2.6, ink)
	ci.draw_rect(Rect2(o.x - w * 0.42, o.y - h * 0.44, w * 0.3, h * 0.08), Color("2d3436"))
	var c := o + Vector2(0, h * 0.1)
	var rr := minf(w, h) * 0.3
	ci.draw_circle(c, rr + 3.0, _shade(Color("b2bec3"), lit))
	ci.draw_circle(c, rr, _shade(Color("74b9ff") if on else GLASS.darkened(0.2), lit))
	var a := now / 60.0 if on else 0.4
	var socks := [Color("fd79a8"), Color("ffeaa7"), Color("55efc4")]
	for k in 3:
		ci.draw_circle(c + Vector2.from_angle(a + TAU * k / 3.0) * rr * 0.55, rr * 0.28, socks[k])
	ci.draw_arc(c, rr * 0.75, -2.4, -1.4, 8, Color(1, 1, 1, 0.6), 2.0)
	ci.draw_arc(c, rr + 3.0, 0, TAU, 24, ink, 2.0)
	ci.draw_rect(body, ink, false, 2.0)
	if crazy:
		# occhi matti sopra l'oblò
		for side in [-1.0, 1.0]:
			ci.draw_circle(o + Vector2(side * w * 0.2, -h * 0.18), 4.0, Color.WHITE)
			ci.draw_circle(o + Vector2(side * w * 0.2 + sin(now / 90.0 + side) * 1.5, -h * 0.18), 1.8, ink)
	if on and not Access.calm:
		for k in 5:
			var t := fmod(now / 700.0 + k / 5.0, 1.0)
			ci.draw_circle(o + Vector2((k - 2) * w * 0.2, -h / 2 - 4 - t * 18.0), 3.0 + 3.0 * t, Color(1, 1, 1, 0.8 * (1.0 - t)))


# Il monopattino: pedana, due ruote, piantone e manubrio. A razzo: il razzo dietro con la fiamma finché c'è carburante
static func _scooter(ci: CanvasItem, w: float, h: float, ink: Color, lit: Color, load: float, now: int, rocket: bool) -> void:
	var col := Color("e74c3c") if rocket else Color("2ecc71")
	var wr := h * 0.2
	var deck_y := h * 0.5 - wr * 2.0
	for x in [-w * 0.36, w * 0.36]:
		ci.draw_circle(Vector2(x, h * 0.5 - wr), wr, Color("2d3436"))
		ci.draw_circle(Vector2(x, h * 0.5 - wr), wr * 0.45, _shade(Color("b2bec3"), lit))
	ci.draw_rect(Rect2(-w * 0.42, deck_y - 4, w * 0.75, 6), _shade(col, lit))
	ci.draw_rect(Rect2(-w * 0.42, deck_y - 4, w * 0.75, 6), ink, false, 1.5)
	ci.draw_line(Vector2(w * 0.33, deck_y), Vector2(w * 0.36, h * 0.5 - wr), ink, 3.0)
	ci.draw_line(Vector2(w * 0.33, deck_y), Vector2(w * 0.28, -h * 0.5), _shade(col.darkened(0.2), lit), 4.0)
	ci.draw_line(Vector2(w * 0.18, -h * 0.5), Vector2(w * 0.4, -h * 0.5), ink, 4.0)
	if rocket:
		var r := Rect2(-w * 0.62, deck_y - 12, w * 0.24, 10)
		ci.draw_rect(r, _shade(Color("b2bec3"), lit))
		ci.draw_rect(r, ink, false, 1.5)
		if load > 0.0 and not Access.calm:
			var flick := 0.7 + 0.3 * sin(now / 30.0)
			var tip := Vector2(r.position.x - (10.0 + 14.0 * load) * flick, deck_y - 7)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, deck_y - 12), tip, Vector2(r.position.x, deck_y - 2)]), FIRE)
			ci.draw_circle(Vector2(r.position.x - 4, deck_y - 7), 3.0, Color("ffe066"))
		if load >= 0.0 and load < 0.25 and int(now / 120.0) % 2 == 0:
			ci.draw_circle(Vector2(-w * 0.5, deck_y - 18), 4.0, Color(1, 0.2, 0.1))


# Il carrello della spesa: cesto a griglia, maniglia e ruotine. Quello da tre è più lungo, arancione, con le fiamme
static func _cart(ci: CanvasItem, w: float, h: float, ink: Color, lit: Color, turbo: bool) -> void:
	var col := Color("f39c12") if turbo else Color("95a5a6")
	var top := -h * 0.45
	var bottom := h * 0.18
	var basket := PackedVector2Array([Vector2(-w * 0.4, top), Vector2(w * 0.5, top), Vector2(w * 0.38, bottom), Vector2(-w * 0.3, bottom)])
	ci.draw_colored_polygon(basket, Color(_shade(col, lit), 0.35))
	for k in range(1, 6):
		var t := k / 6.0
		ci.draw_line(basket[0].lerp(basket[1], t), basket[3].lerp(basket[2], t), _shade(col, lit), 1.5)
	ci.draw_line(Vector2(-w * 0.36, (top + bottom) / 2), Vector2(w * 0.44, (top + bottom) / 2), _shade(col, lit), 1.5)
	ci.draw_polyline(basket + PackedVector2Array([basket[0]]), ink, 2.0)
	ci.draw_line(Vector2(-w * 0.4, top), Vector2(-w * 0.52, top - 8), ink, 3.0)
	ci.draw_line(Vector2(-w * 0.58, top - 8), Vector2(-w * 0.46, top - 8), Color("c0392b"), 4.0)
	ci.draw_line(Vector2(-w * 0.3, bottom), Vector2(-w * 0.3, h * 0.42), ink, 2.0)
	ci.draw_line(Vector2(w * 0.38, bottom), Vector2(w * 0.38, h * 0.42), ink, 2.0)
	ci.draw_line(Vector2(-w * 0.3, h * 0.3), Vector2(w * 0.38, h * 0.3), ink, 2.0)
	for x in [-w * 0.3, w * 0.38]:
		ci.draw_circle(Vector2(x, h * 0.44), 4.0, Color("2d3436"))
	if turbo:
		for k in 3:
			var y := top + 6 + k * 7
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, y), Vector2(w * 0.3, y + 3), Vector2(w * 0.1, y + 6)]), Color("e74c3c"))


# Gli eventi di ride.ts (fasi di "gear"): restituisce quanto far tremare la telecamera
func on_event(e: Dictionary) -> float:
	var x := float(e.x)
	var y := float(e.y)
	match str(e.phase):
		"break":
			var gold: bool = str(e.kind) == "cassaOro"
			for k in 10:
				var a := -PI * (0.1 + 0.8 * k / 9.0)
				shards.append({"x": x, "y": y - 16.0, "vx": cos(a) * (180.0 + 40.0 * (k % 3)), "vy": sin(a) * 380.0, "age": 0.0, "col": GOLD if gold else WOOD})
			puffs.append({"x": x, "y": y - 16.0, "r": 34.0, "age": 0.0, "col": Color(0.85, 0.75, 0.6)})
			return 5.0
		"spin", "hop":
			puffs.append({"x": x, "y": y - 8.0, "r": 22.0, "age": 0.0, "col": Color(1, 1, 1)})
			return 2.0 if e.phase == "hop" else 3.0
		"charge":
			puffs.append({"x": x, "y": y - 6.0, "r": 18.0, "age": 0.0, "col": Color(0.85, 0.8, 0.7)})
		"ram":
			puffs.append({"x": x, "y": y - 30.0, "r": 30.0, "age": 0.0, "col": Color(1, 0.9, 0.4)})
			return 4.0
		"scoop":
			puffs.append({"x": x, "y": y - 30.0, "r": 26.0, "age": 0.0, "col": Color(0.7, 0.9, 1)})
			return 3.0
		"launch":
			puffs.append({"x": x, "y": y - 40.0, "r": 40.0, "age": 0.0, "col": Color(1, 0.75, 0.3)})
			return 6.0
	return 0.0


func step(dt_ms: float) -> void:
	var dt := dt_ms / 1000.0
	for s in shards:
		s.age += dt_ms
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.vy += 1400.0 * dt
	for p in puffs:
		p.age += dt_ms
	shards = shards.filter(func(s): return s.age < 700.0)
	puffs = puffs.filter(func(p): return p.age < 380.0)


func draw(ci: CanvasItem) -> void:
	for s in shards:
		var t: float = s.age / 700.0
		var d := Vector2(cos(s.age / 60.0), sin(s.age / 60.0)) * 6.0
		ci.draw_line(Vector2(s.x, s.y) - d, Vector2(s.x, s.y) + d, Color(s.col, 1.0 - t), 4.0)
	for p in puffs:
		var t: float = p.age / 380.0
		ci.draw_circle(Vector2(p.x, p.y), p.r * (0.5 + 0.7 * t), Color(p.col, 0.6 * (1.0 - t)))
		ci.draw_arc(Vector2(p.x, p.y), p.r * (0.7 + 0.8 * t), 0, TAU, 20, Color(p.col, 0.8 * (1.0 - t)), 3.0)
