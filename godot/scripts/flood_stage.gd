# Il Diluvio, vivo come Sala Prove: il mare sale per tutta la partita e la telecamera con lui. Più si sale più il cielo
# si apre: in basso tempesta, pioggia fitta e fulmini, in cima il tramonto e l'Arca con gli animali che aspettano. I
# relitti su cui si sta (assi, porte, casse, pezzi di tetto) dondolano, le zattere hanno la vela, in acqua galleggiano
# paperelle e botti. Il mare si disegna davanti ai lottatori: chi ci cade sparisce sotto la schiuma.
# Solo grafica: tutto dal tempo dell'arena (stageMs) e da `rise` dell'arena (StagePhases.water_y, come physics/timed.ts).
# La chiama theme_stage.gd.
extends RefCounted

const StagePhases := preload("res://scripts/stage_phases.gd")
const INK := Color("17202a")
const STORM := Color("27313d")
const STORM_LOW := Color("3d4a57")
const CLEAR := Color("8fb8e8")
const SUNSET := Color("ffb27a")
const SEA := Color("2f6170")
const SEA_DEEP := Color("173540")
const FOAM := Color("e8f3f2")
const WOOD := Color("8a5a32")
const WOOD_LIGHT := Color("e2c08d")
const FLASH_EVERY_MS := 8500.0
const FLASH_MS := 200.0
const BANNER_MS := 3000.0

var rise: Dictionary = {}
var _kinds := {} # "x,y" di un pezzo -> come si disegna: "isola", "arca", "tetto", "campanile", "collina"
var _ark_y := 0.0
var _top_ms := INF # quando il mare si ferma, per la scritta dell'Arca
var _splashes: Array = [] # {x, at}: dove qualcuno è finito in mare (orologio del client)
var _font: Font = ThemeDB.fallback_font


func setup(spec: Dictionary, _game: Dictionary) -> void:
	rise = spec.get("rise", {}) if spec.get("rise") is Dictionary else {}
	_kinds = {}
	_splashes = []
	var solids: Array = spec.get("solids", [])
	for i in solids.size():
		var s: Dictionary = solids[i]
		var kind: String = ["tetto", "campanile", "collina"][i % 3]
		if i == 0:
			kind = "isola"
		elif i == solids.size() - 1:
			kind = "arca"
			_ark_y = float(s.y)
		_kinds[_key(s)] = kind
	_top_ms = time_at(rise, float(rise.get("maxPx", 0))) if not rise.is_empty() else INF


static func _key(p: Dictionary) -> String:
	return "%d,%d" % [int(p.x), int(p.y)]


# Quando il mare è salito di px (ms), come riseTimeMs in physics/timed.ts
static func time_at(r: Dictionary, px: float) -> float:
	if px <= 0.0:
		return 0.0
	var a := float(r.get("accelPxPerS2", 0.0))
	var v := float(r.pxPerS)
	var s := (-v + sqrt(v * v + 2.0 * a * px)) / a if a > 0.0 else px / v
	return float(r.startMs) + s * 1000.0


func water(t: float) -> float:
	return StagePhases.water_y(rise, t) if not rise.is_empty() else 1e9


# Da 0 (in fondo, tempesta) a 1 (all'Arca, cielo aperto) per un'altezza del mondo
func altitude(y: float) -> float:
	if rise.is_empty() or _ark_y == 0.0:
		return 0.0
	return clampf((float(rise.waterY) - y) / (float(rise.waterY) - _ark_y), 0.0, 1.0)


static func flash(t: float) -> float:
	var p := fposmod(t, FLASH_EVERY_MS)
	if p > FLASH_MS:
		return 0.0
	return 1.0 - p / FLASH_MS


# --- Disegno ---

func draw_back(c: CanvasItem, t: float, view: Rect2, _pressed: Array, _now_ms: float) -> void:
	var area := view.grow(80)
	# Il cielo a fasce: il colore dipende dall'altezza del mondo, così salendo si esce dalla tempesta
	var bands := 12
	for i in bands:
		var y0 := area.position.y + area.size.y * i / bands
		var y1 := area.position.y + area.size.y * (i + 1) / bands + 1.0
		var k := altitude((y0 + y1) / 2.0)
		var col := STORM.lerp(STORM_LOW, float(i) / bands)
		col = col.lerp(CLEAR, smoothstep(0.35, 0.8, k)).lerp(SUNSET, smoothstep(0.75, 1.0, k) * (float(i) / bands))
		c.draw_rect(Rect2(area.position.x, y0, area.size.x, y1 - y0), col)
	var k_view := altitude(view.get_center().y)
	# Il sole che spunta quando si è in alto
	if k_view > 0.6:
		var sun := Vector2(view.position.x + view.size.x * 0.78, view.position.y + view.size.y * 0.25)
		var a := smoothstep(0.6, 0.95, k_view)
		c.draw_circle(sun, 90.0, Color(1, 0.85, 0.55, 0.18 * a))
		c.draw_circle(sun, 52.0, Color(1, 0.9, 0.6, 0.9 * a))
	# Montagne lontane che affondano: si muovono piano rispetto alla vista (parallasse) e il mare lontano le copre
	var w := water(t)
	var far_sea := w - 70.0 # l'orizzonte, poco sopra il mare vero: le montagne lontane ci affondano
	for layer in 2:
		var par := 0.15 + 0.15 * layer
		var pts := PackedVector2Array()
		var base := far_sea + 30.0
		var x := area.position.x - 40.0
		while x <= area.end.x + 40.0:
			var wx := x + view.get_center().x * par
			var h := 160.0 + 90.0 * sin(wx / 230.0 + layer) + 50.0 * sin(wx / 71.0)
			pts.append(Vector2(x, base - h * (1.0 - 0.3 * layer)))
			x += 40.0
		pts.append(Vector2(area.end.x + 40.0, base + 400.0))
		pts.append(Vector2(area.position.x - 40.0, base + 400.0))
		c.draw_colored_polygon(pts, Color("394754").lerp(Color("6f8aa6"), k_view).darkened(0.15 * layer))
	c.draw_rect(Rect2(area.position.x, far_sea, area.size.x, area.end.y - far_sea + 200.0), Color("4d6f7c").lerp(Color("9cc3cf"), k_view))
	# Nuvoloni che corrono, più scuri e fitti in basso
	var dark := 1.0 - smoothstep(0.4, 0.9, k_view)
	for i in 6:
		var cx := area.position.x + fposmod(i * 311.0 + t / (30.0 + i * 4.0), area.size.x + 400.0) - 200.0
		var cy := view.position.y + 30.0 + fposmod(i * 67.0, view.size.y * 0.22)
		var col := Color("1c242d").lerp(Color("f4f1ea"), 1.0 - dark)
		col.a = 0.22
		for b in 5:
			var bc := Vector2(cx + b * 46.0 - 92.0, cy + 6.0 * sin(b * 2.0 + i))
			c.draw_colored_polygon(_ellipse(bc, 60.0 + 12.0 * ((b + i) % 3), 26.0), col)
	# Il fulmine, lontano, nella tempesta
	var f := flash(t) * dark
	if f > 0.0:
		var bx := area.position.x + fposmod(floorf(t / FLASH_EVERY_MS) * 397.0, area.size.x)
		var pts := PackedVector2Array([Vector2(bx, view.position.y)])
		var y := view.position.y
		var i := 0
		while y < far_sea:
			y += 60.0
			i += 1
			pts.append(Vector2(bx + (24.0 if i % 2 == 0 else -18.0) + 10.0 * sin(i * 3.1), y))
		c.draw_polyline(pts, Color(1, 1, 0.9, f), 3.0)
	# La pioggia, fitta in basso e che smette salendo
	var drops := int(120.0 * dark)
	for i in drops:
		var x := view.position.x + fposmod(i * 73.3 + t * 0.35, view.size.x + 100.0) - 50.0
		var y := view.position.y + fposmod(i * 131.7 + t * 1.3, view.size.y)
		c.draw_line(Vector2(x, y), Vector2(x - 6.0, y + 18.0), Color(0.75, 0.82, 0.9, 0.35), 1.5)


func draw_solid(c: CanvasItem, s: Dictionary, t: float, _pressed: Array) -> bool:
	var r := Rect2(float(s.x), float(s.y), float(s.width), float(s.height))
	match str(_kinds.get(_key(s), "tetto")):
		"isola":
			c.draw_rect(Rect2(r.position.x + 20.0, r.position.y + 20.0, r.size.x - 40.0, r.size.y), Color("8a6b45"))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 26.0), Color("e9d39b"))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5.0), Color("fff0c4"))
			for px: float in [r.position.x + 90.0, r.end.x - 120.0]:
				_draw_palm(c, Vector2(px, r.position.y), t)
		"arca":
			_draw_ark(c, r, t)
		"campanile":
			c.draw_rect(Rect2(r.position.x + 30.0, r.position.y, r.size.x - 60.0, r.size.y + 300.0), Color("b9a58a"))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 14.0), Color("8f7b62"))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), Color("f2e6cf"))
			for k in 3:
				var arch := Vector2(r.position.x + r.size.x * (k + 1) / 4.0, r.position.y + 70.0)
				c.draw_rect(Rect2(arch.x - 16.0, arch.y - 20.0, 32.0, 50.0), Color("3a3027"))
				c.draw_circle(arch + Vector2(0, -20), 16.0, Color("3a3027"))
			# La campana dondola nell'arco di mezzo
			var bell := Vector2(r.get_center().x + 6.0 * sin(t / 500.0), r.position.y + 62.0)
			c.draw_colored_polygon(PackedVector2Array([bell + Vector2(-12, 14), bell + Vector2(12, 14), bell + Vector2(7, -6), bell + Vector2(-7, -6)]), Color("d6a33c"))
		"collina":
			var pts := PackedVector2Array([Vector2(r.position.x - 30.0, r.end.y + 300.0), Vector2(r.position.x, r.position.y + 8.0), Vector2(r.end.x, r.position.y + 8.0), Vector2(r.end.x + 30.0, r.end.y + 300.0)])
			c.draw_colored_polygon(pts, Color("4f7a3a"))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 12.0), Color("7cbf5a"))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), Color("d8f0a8"))
			var tree := Vector2(r.position.x + r.size.x * 0.75, r.position.y)
			c.draw_rect(Rect2(tree.x - 5.0, tree.y - 50.0, 10.0, 50.0), Color("5a3d22"))
			c.draw_circle(tree + Vector2(0, -60), 30.0, Color("3f7d34"))
			c.draw_circle(tree + Vector2(-18, -48), 20.0, Color("4a8f3c"))
		_:
			# Un tetto di coppi con il comignolo che fuma
			c.draw_rect(Rect2(r.position.x + 20.0, r.position.y + 30.0, r.size.x - 40.0, r.size.y + 300.0), Color("d8c7a8"))
			for k in 4:
				c.draw_rect(Rect2(r.position.x + 40.0 + k * (r.size.x - 80.0) / 4.0, r.position.y + 60.0, 26.0, 34.0), Color("4a5d6e"))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 30.0), Color("b5452f"))
			for x in range(int(r.position.x), int(r.end.x), 22):
				c.draw_arc(Vector2(x + 11, r.position.y + 30.0), 11.0, PI, TAU, 6, Color("8e3322"), 2.0)
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), Color("f3c1a8"))
			var chimney := Vector2(r.position.x + r.size.x * 0.2, r.position.y)
			c.draw_rect(Rect2(chimney.x, chimney.y - 34.0, 22.0, 34.0), Color("8e3322"))
			for k in 3:
				var life := fposmod(t / 1800.0 + k / 3.0, 1.0)
				c.draw_circle(chimney + Vector2(11.0 + 14.0 * life, -40.0 - 50.0 * life), 6.0 + 10.0 * life, Color(0.85, 0.85, 0.85, 0.5 * (1.0 - life)))
	return true


func _draw_palm(c: CanvasItem, foot: Vector2, t: float) -> void:
	var sway := 8.0 * sin(t / 700.0 + foot.x)
	var top := foot + Vector2(sway, -120.0)
	c.draw_line(foot, foot + Vector2(sway * 0.4, -60.0), Color("7a5530"), 10.0)
	c.draw_line(foot + Vector2(sway * 0.4, -60.0), top, Color("7a5530"), 8.0)
	for k in 5:
		var a := -PI / 2.0 + (k - 2) * 0.6 + 0.08 * sin(t / 400.0 + k)
		var tip := top + Vector2(cos(a) * 60.0, sin(a) * 30.0 + 24.0)
		c.draw_line(top, tip, Color("3f8a3a"), 9.0)
	c.draw_circle(top + Vector2(4, 8), 6.0, Color("6b4a2a"))
	c.draw_circle(top + Vector2(-6, 9), 6.0, Color("6b4a2a"))


# L'Arca: lo scafo di legno, la cabina, gli animali che guardano chi arriva e l'arcobaleno quando il mare si ferma
func _draw_ark(c: CanvasItem, r: Rect2, t: float) -> void:
	var hull := PackedVector2Array([Vector2(r.position.x - 60.0, r.position.y), Vector2(r.end.x + 60.0, r.position.y), Vector2(r.end.x - 40.0, r.end.y + 60.0), Vector2(r.position.x + 40.0, r.end.y + 60.0)])
	if t >= _top_ms:
		var colors := [Color("ff5252"), Color("ffab40"), Color("ffee58"), Color("69f0ae"), Color("40c4ff"), Color("b388ff")]
		var k := minf(1.0, (t - _top_ms) / 2000.0)
		for i in colors.size():
			c.draw_arc(Vector2(r.get_center().x, r.position.y + 200.0), 640.0 - i * 20.0, PI, TAU, 48, Color(colors[i], 0.5 * k), 20.0)
	c.draw_colored_polygon(hull, Color("6e4526"))
	for k in 5:
		var y := r.position.y + 14.0 + k * 24.0
		c.draw_line(Vector2(r.position.x - 50.0 + k * 18.0, y), Vector2(r.end.x + 50.0 - k * 18.0, y), Color("4f2f17"), 3.0)
	c.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[0]]), INK, 3.0)
	c.draw_rect(Rect2(r.position.x - 60.0, r.position.y, r.size.x + 120.0, 6.0), WOOD_LIGHT)
	# La cabina (il suo tetto è la piattaforma sottile sopra il ponte)
	var cab := Rect2(r.get_center().x - 110.0, r.position.y - 120.0, 220.0, 120.0)
	c.draw_rect(cab, Color("9a6a3e"))
	c.draw_rect(cab, INK, false, 2.0)
	for k in 3:
		c.draw_circle(Vector2(cab.position.x + 50.0 + k * 60.0, cab.position.y + 50.0), 14.0, Color("ffe7a8"))
	# Gli animali: una giraffa, un elefante e due bonobo che salutano
	var g := Vector2(r.position.x + 70.0, r.position.y)
	c.draw_line(g, g + Vector2(10, -150), Color("e3b04b"), 14.0)
	c.draw_circle(g + Vector2(14, -156), 14.0, Color("e3b04b"))
	c.draw_circle(g + Vector2(20, -158), 2.5, INK)
	var el := Vector2(r.end.x - 90.0, r.position.y - 40.0)
	c.draw_circle(el, 40.0, Color("9aa3ad"))
	c.draw_circle(el + Vector2(-34, -6), 22.0, Color("858e98"))
	c.draw_line(el + Vector2(-38, 10), el + Vector2(-50, 40 + 6.0 * sin(t / 300.0)), Color("9aa3ad"), 12.0)
	c.draw_circle(el + Vector2(-26, -14), 3.0, INK)
	for k in 2:
		var b := Vector2(cab.position.x - 40.0 + k * 300.0, r.position.y)
		var wave := sin(t / 160.0 + k * 2.0)
		c.draw_circle(b + Vector2(0, -26), 18.0, Color("4a3328"))
		c.draw_circle(b + Vector2(0, -24), 11.0, Color("c9a27e"))
		c.draw_circle(b + Vector2(-4, -27), 2.0, INK)
		c.draw_circle(b + Vector2(4, -27), 2.0, INK)
		c.draw_line(b + Vector2(14, -30), b + Vector2(26 + 4.0 * wave, -54), Color("4a3328"), 6.0)


func draw_platform(c: CanvasItem, p: Dictionary, t: float) -> bool:
	var x: float = p.x
	var y: float = p.y
	var w: float = p.width
	var bob := 1.5 * sin(t / 600.0 + x * 0.05) # solo il disegno: la superficie vera resta y
	var kind := int(absf(x * 7.0 + y * 3.0)) % 4
	if _ark_y > 0.0 and y < _ark_y:
		kind = 9 # il tetto della cabina dell'Arca
	match kind:
		0: # un'asse con i chiodi
			c.draw_rect(Rect2(x, y + bob, w, 14.0), WOOD)
			c.draw_line(Vector2(x, y + 7.0 + bob), Vector2(x + w, y + 7.0 + bob), Color("6b4325"), 1.5)
			for k in 3:
				c.draw_circle(Vector2(x + 8.0 + k * (w - 16.0) / 2.0, y + 7.0 + bob), 2.0, Color("c0c4c8"))
		1: # una porta col pomello
			c.draw_rect(Rect2(x, y + bob, w, 18.0), Color("2e6b8a"))
			c.draw_rect(Rect2(x + 8.0, y + 4.0 + bob, w * 0.4, 10.0), Color("255773"))
			c.draw_rect(Rect2(x + w * 0.55, y + 4.0 + bob, w * 0.38, 10.0), Color("255773"))
			c.draw_circle(Vector2(x + w - 10.0, y + 9.0 + bob), 3.5, Color("e3b04b"))
		2: # una cassa
			c.draw_rect(Rect2(x, y + bob, w, 30.0), Color("a8743f"))
			c.draw_line(Vector2(x, y + bob), Vector2(x + w, y + 30.0 + bob), Color("7a4f28"), 3.0)
			c.draw_rect(Rect2(x, y + bob, w, 30.0), INK, false, 1.5)
		9:
			c.draw_rect(Rect2(x - 10.0, y, w + 20.0, 16.0), Color("b5452f"))
		_: # un pezzo di tetto
			c.draw_rect(Rect2(x, y + bob, w, 16.0), Color("b5452f"))
			for k in range(0, int(w), 18):
				c.draw_arc(Vector2(x + k + 9.0, y + 16.0 + bob), 9.0, PI, TAU, 5, Color("8e3322"), 2.0)
	c.draw_rect(Rect2(x, y + bob, w, 3.0), WOOD_LIGHT) # il bordo calpestabile, chiaro
	return true


func draw_mover(c: CanvasItem, m: Dictionary, pos: Vector2, t: float) -> bool:
	if str(m.get("kind", "")) != "zattera":
		return false
	var w: float = m.width
	var bob := 2.0 * sin(t / 450.0 + pos.x * 0.01)
	for k in 5:
		var lx := pos.x + k * w / 5.0
		c.draw_rect(Rect2(lx + 1.0, pos.y + bob, w / 5.0 - 2.0, 20.0), Color("8a5a32").lightened(0.06 * (k % 2)))
		c.draw_circle(Vector2(lx + w / 10.0, pos.y + 10.0 + bob), 7.0, Color("6b4325"))
	c.draw_line(Vector2(pos.x + 6.0, pos.y + 6.0 + bob), Vector2(pos.x + w - 6.0, pos.y + 6.0 + bob), Color("d9c49a"), 2.0)
	c.draw_rect(Rect2(pos.x, pos.y + bob, w, 3.0), WOOD_LIGHT)
	# La vela, gonfia dal vento
	var mast := Vector2(pos.x + w * 0.5, pos.y + bob)
	c.draw_line(mast, mast + Vector2(0, -90), Color("5a3d22"), 4.0)
	var puff := 10.0 + 4.0 * sin(t / 300.0)
	c.draw_colored_polygon(PackedVector2Array([mast + Vector2(3, -86), mast + Vector2(3 + 40 + puff, -50), mast + Vector2(3, -20)]), Color("f2e6cf"))
	c.draw_colored_polygon(PackedVector2Array([mast + Vector2(0, -90), mast + Vector2(18, -84), mast + Vector2(0, -78)]), Color("e53935"))
	return true


func draw_hazard(_c: CanvasItem, _h: Dictionary, _r: Rect2, _on: bool, _t: float) -> bool:
	return false


func draw_pad(_c: CanvasItem, _p: Dictionary, _pressed_at: Variant, _t: float) -> bool:
	return false


func draw_over_fighters(_c: CanvasItem, _players: Dictionary, _now_ms: float) -> void:
	pass


# Davanti a tutto: il mare (chi ci cade sparisce sotto), le cose che galleggiano, gli schizzi dei KO, la quota e le scritte
func draw_front(c: CanvasItem, t: float, view: Rect2, _pressed: Array) -> void:
	if rise.is_empty():
		return
	var area := view.grow(80)
	var w := water(t)
	if w < area.end.y:
		var pts := PackedVector2Array()
		var x := floorf(area.position.x / 20.0) * 20.0
		while x <= area.end.x + 20.0:
			pts.append(Vector2(x, w + 5.0 * sin(t / 300.0 + x / 45.0) + 3.0 * sin(t / 170.0 - x / 23.0)))
			x += 20.0
		var body := pts.duplicate()
		body.append(Vector2(area.end.x + 20.0, area.end.y + 400.0))
		body.append(Vector2(area.position.x, area.end.y + 400.0))
		c.draw_colored_polygon(body, Color(SEA, 0.93))
		c.draw_rect(Rect2(area.position.x, w + 60.0, area.size.x, area.end.y - w + 400.0), Color(SEA_DEEP, 0.6))
		c.draw_polyline(pts, FOAM, 4.0)
		for i in 3:
			var ry := w + 20.0 + i * 22.0
			var off := fposmod(t / 30.0 + i * 70.0, 140.0)
			var rx := area.position.x + off
			while rx < area.end.x:
				c.draw_line(Vector2(rx, ry), Vector2(rx + 40.0, ry), Color(1, 1, 1, 0.18), 2.0)
				rx += 140.0
		# Paperelle, botti e una sedia che galleggiano trascinate dalla corrente
		for i in 6:
			var fx := area.position.x + fposmod(i * 263.0 + t / (14.0 + i * 3.0), area.size.x + 200.0) - 100.0
			var fy := w - 4.0 + 4.0 * sin(t / 280.0 + i)
			match i % 3:
				0:
					c.draw_circle(Vector2(fx, fy), 11.0, Color("ffd54f"))
					c.draw_circle(Vector2(fx + 9, fy - 10), 7.0, Color("ffd54f"))
					c.draw_colored_polygon(PackedVector2Array([Vector2(fx + 15, fy - 11), Vector2(fx + 22, fy - 8), Vector2(fx + 15, fy - 6)]), Color("ff8f00"))
					c.draw_circle(Vector2(fx + 11, fy - 12), 1.8, INK)
				1:
					c.draw_rect(Rect2(fx - 14, fy - 14, 28, 24), Color("7a4f28"))
					c.draw_line(Vector2(fx - 14, fy - 6), Vector2(fx + 14, fy - 6), Color("3a3a3a"), 2.0)
				_:
					c.draw_line(Vector2(fx - 12, fy), Vector2(fx + 12, fy), Color("c08a52"), 4.0)
					c.draw_line(Vector2(fx - 12, fy), Vector2(fx - 12, fy - 22), Color("c08a52"), 4.0)
		# Gli schizzi di chi ci è finito dentro
		var now := Time.get_ticks_msec()
		for sp: Dictionary in _splashes:
			var k := (now - float(sp.at)) / 900.0
			if k < 1.0:
				for d in 7:
					var a := PI + PI * (d + 0.5) / 7.0
					var at := Vector2(float(sp.x) + cos(a) * 60.0 * k, w + sin(a) * 120.0 * k + 160.0 * k * k)
					c.draw_circle(at, 8.0 * (1.0 - k) + 2.0, Color(FOAM, 1.0 - k))
	# La quota: una barra a destra con l'Arca in cima e il mare che sale
	var bar := Rect2(view.end.x - 34.0, view.position.y + view.size.y * 0.18, 12.0, view.size.y * 0.5)
	var up := StagePhases.rise_offset(rise, t) / maxf(1.0, float(rise.maxPx))
	c.draw_rect(bar.grow(3), Color(INK, 0.6))
	c.draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * up, bar.size.x, bar.size.y * up), Color("4fb3d9"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(bar.position.x - 8, bar.position.y - 8), Vector2(bar.end.x + 8, bar.position.y - 8), Vector2(bar.end.x + 2, bar.position.y), Vector2(bar.position.x - 2, bar.position.y)]), Color("8a5a32"))
	var meters := int(StagePhases.rise_offset(rise, t) / 40.0)
	var label := "%d m" % meters
	var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string_outline(_font, Vector2(bar.end.x - lw, bar.end.y + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, INK)
	c.draw_string(_font, Vector2(bar.end.x - lw, bar.end.y + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, FOAM)
	# Le scritte: quando comincia a salire e quando si ferma sotto l'Arca
	var start := float(rise.startMs)
	if t >= start - 2500.0 and t < start + 1500.0:
		_shout(c, view, "IL MARE SALE!", 52, Color("7fd3ee"), t, minf(1.0, (start + 1500.0 - t) / 400.0))
	elif t >= _top_ms and t < _top_ms + BANNER_MS:
		_shout(c, view, "TERRA! TUTTI SULL'ARCA!", 44, Color("ffd54f"), t, minf(1.0, (_top_ms + BANNER_MS - t) / 400.0))
	# Il lampo del fulmine schiarisce tutto un attimo
	var f := flash(t) * (1.0 - smoothstep(0.4, 0.9, altitude(view.get_center().y)))
	if f > 0.0:
		c.draw_rect(area, Color(1, 1, 1, 0.22 * f))


func _shout(c: CanvasItem, view: Rect2, text: String, size: int, col: Color, t: float, alpha: float) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(view.get_center().x - tw / 2.0, view.position.y + view.size.y * 0.3)
	c.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(INK, alpha))
	var x := at.x
	for i in text.length():
		var ch := text[i]
		c.draw_string(_font, Vector2(x, at.y - 5.0 * absf(sin(t / 120.0 + i * 0.5))), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, alpha))
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func on_event(e: Dictionary, now_ms: float) -> void:
	if str(e.get("type", "")) == "ko" and e.get("x") != null:
		_splashes.append({"x": float(e.x), "at": now_ms})
		if _splashes.size() > 6:
			_splashes.pop_front()


# Il tuono coi fulmini (finché si è nella tempesta) e l'onda quando il mare comincia a salire
func cues(before: float, now: float, _pressed: Array) -> Array:
	var out: Array = []
	if rise.is_empty():
		return out
	var start := float(rise.startMs)
	if before < start - 2500.0 and now >= start - 2500.0:
		out.append(["splash", 640.0])
	if floorf(before / FLASH_EVERY_MS) != floorf(now / FLASH_EVERY_MS) and StagePhases.rise_offset(rise, now) < float(rise.maxPx) * 0.6:
		out.append(["thunder", 640.0])
	if before < _top_ms and now >= _top_ms:
		out.append(["wonder", 640.0])
	return out


static func _ellipse(at: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
