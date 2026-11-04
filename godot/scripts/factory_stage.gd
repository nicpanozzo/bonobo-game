# La Fabbrica di banane, viva come Sala Prove: un capannone a cartone animato dove tutto scorre. I nastri girano col
# loro verso (belt_velocity, lo stesso calcolo del server), gli ingranaggi dietro girano con loro, le banane ci viaggiano
# sopra, le impacchettatrici tremano e poi scendono e chi prendono finisce in una scatola di banane (finché il server lo
# tiene stordito), la gru porta la cassa, il vapore esce dai tubi. Prima che i nastri cambino
# verso suona la sirena e girano i lampeggianti; con le due leve tirate insieme arriva il TURBO. Sul muro il cartello
# "SECONDI SENZA INCIDENTI" torna a zero a ogni KO.
# Solo grafica: tutto dal tempo dell'arena e dalle pressioni delle leve dello snapshot. La chiama theme_stage.gd.
extends RefCounted

const StageMotion := preload("res://scripts/stage_motion.gd")
const INK := Color("1c1612")
const STEEL := Color("4a525c")
const STEEL_DARK := Color("2e3339")
const YELLOW := Color("ffc531")
const BANANA := Color("ffe14d")
const GLOW := Color("ff8a3d")
const CEILING := -420.0 # dove finiscono in alto cavi, pistoni e pilastri
const RAIL_Y := -40.0 # la rotaia della gru
const PRESS_RISE_MS := 700.0 # quanto ci mette una pressa a risalire dopo il colpo
const TURBO_SHOW_MS := 1800.0 # quanto resta la scritta TURBO!

var belts: Array = []
var pads: Array = []
var hazards: Array = []
var turbo_mult := 2.0
var warn_ms := 2000.0
var _offsets: Array = [] # quanto è scorso ogni nastro (px), accumulato frame per frame
var _gear := 0.0
var _last_t := -1.0
var _last_ko := -1.0 # orologio del client dell'ultimo KO: il cartello conta da lì
var _packed := {} # id -> orologio del client in cui l'impacchettatrice l'ha preso: la scatola si disegna finché è stordito
var _font: Font = ThemeDB.fallback_font


func setup(spec: Dictionary, game: Dictionary) -> void:
	belts = spec.get("belts", []) if spec.get("belts") is Array else []
	pads = spec.get("pads", []) if spec.get("pads") is Array else []
	hazards = spec.get("hazards", []) if spec.get("hazards") is Array else []
	var b: Dictionary = game.get("belt", {})
	turbo_mult = float(b.get("turboMult", 2.0))
	warn_ms = float(b.get("warnMs", 2000.0))
	_offsets = []
	for i in belts.size():
		_offsets.append(0.0)
	_gear = 0.0
	_last_t = -1.0
	_last_ko = -1.0
	_packed = {}


# --- Lo stato dei nastri, dal tempo dell'arena ---

func velocity(i: int, t: float, pressed: Array) -> float:
	return StageMotion.belt_velocity(belts[i], t, pads, pressed, turbo_mult)


func turbo(t: float, pressed: Array) -> bool:
	return not belts.is_empty() and StageMotion.belt_levers(belts[0], t, pads, pressed) >= 2


# Da 0 a 1 negli ultimi warn_ms prima del cambio di verso automatico, -1 fuori
static func siren(b: Dictionary, t: float, warn: float) -> float:
	var every: float = float(b.get("flipEveryMs", 0))
	if every <= 0.0:
		return -1.0
	var left := every - fposmod(t, every)
	return 1.0 - left / warn if left <= warn else -1.0


# Quando sono partite le leve tirate adesso (stageMs della seconda), per la scritta del turbo
func _turbo_since(t: float, pressed: Array) -> float:
	var start := -INF
	for i in mini(pads.size(), pressed.size()):
		if pressed[i] != null and t - float(pressed[i]) < float(pads[i].effect.durationMs):
			start = maxf(start, float(pressed[i]))
	return t - start


# Dove sta la testa di una pressa: il fondo, da appoggiata sul nastro (r.end.y) a ferma in alto; e quanto trema
static func press_bottom(h: Dictionary, r: Rect2, t: float) -> Array:
	var period: float = h.get("periodMs", 6000)
	var active: float = h.get("activeMs", 300)
	var warn: float = h.get("warnMs", 1000)
	var pos := fposmod(t + float(h.get("offsetMs", 0)), period)
	var rest := r.position.y - 40.0
	if pos < active:
		return [r.end.y, 0.0]
	if pos < active + PRESS_RISE_MS:
		var k := (pos - active) / PRESS_RISE_MS
		return [lerpf(r.end.y, rest, 1.0 - pow(1.0 - k, 2.0)), 0.0]
	var until := period - pos
	if until < warn:
		var k := 1.0 - until / warn
		return [rest + 8.0 * k, k]
	return [rest, 0.0]


func _advance(t: float, pressed: Array) -> void:
	var dt := clampf(t - _last_t, 0.0, 100.0) if _last_t >= 0.0 else 0.0
	_last_t = t
	for i in belts.size():
		_offsets[i] = fposmod(float(_offsets[i]) + velocity(i, t, pressed) * dt / 1000.0, 100000.0)
	if not belts.is_empty():
		_gear += velocity(0, t, pressed) * dt / 1000.0 / 90.0


func _belt_of(s: Dictionary) -> int:
	for i in belts.size():
		var b: Dictionary = belts[i]
		if absf(float(b.y) - float(s.y)) < 1.0 and float(b.x) >= float(s.x) - 1.0 and float(b.x) + float(b.width) <= float(s.x) + float(s.width) + 1.0:
			return i
	return -1


func _fire_on(t: float) -> bool:
	for h: Dictionary in hazards:
		if str(h.get("kind", "")) == "fuoco":
			return StageMotion.hazard_active(h, t)
	return false


# --- Disegno ---

func draw_back(c: CanvasItem, t: float, view: Rect2, pressed: Array, now_ms: float) -> void:
	_advance(t, pressed)
	var area := view.grow(80)
	var top := minf(area.position.y, CEILING)
	var bottom := maxf(area.end.y, 900.0)
	var warn := siren(belts[0], t, warn_ms) if not belts.is_empty() else -1.0
	var hot := turbo(t, pressed)
	# Il muro: mattoni scuri e caldi, più chiari in basso dove arriva la luce del forno
	var bands := 9
	for i in bands:
		var y0 := lerpf(top, 720.0, float(i) / bands)
		var y1 := lerpf(top, 720.0, float(i + 1) / bands) + 1.0
		c.draw_rect(Rect2(area.position.x, y0, area.size.x, y1 - y0), Color("2b2420").lerp(Color("5a4232"), float(i) / bands))
	c.draw_rect(Rect2(area.position.x, 720.0, area.size.x, bottom - 720.0), Color("1a1512"))
	var brick := Color(0, 0, 0, 0.16)
	var y := floorf(maxf(top, area.position.y) / 36.0) * 36.0
	while y < minf(720.0, area.end.y):
		c.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), brick, 2.0)
		var x := floorf(area.position.x / 84.0) * 84.0 + (42.0 if int(y / 36.0) % 2 == 0 else 0.0)
		while x < area.end.x:
			c.draw_line(Vector2(x, y), Vector2(x, y + 36.0), brick, 2.0)
			x += 84.0
		y += 36.0
	# Il bagliore del forno sul muro, che respira col fuoco
	var fire := 1.0 if _fire_on(t) else 0.35
	for k in 4:
		c.draw_circle(Vector2(640, 700), 260.0 - k * 50.0, Color(GLOW, 0.05 * fire))
	_draw_windows(c, t)
	for x: float in [40.0, 620.0, 1240.0]:
		_draw_pillar(c, x, warn, hot, t)
	_draw_sign(c, now_ms)
	_draw_pipes(c, t)
	for i in belts.size():
		var b: Dictionary = belts[i]
		var dir := 1.0 if float(b.dir) > 0.0 else -1.0
		_draw_gear(c, Vector2(float(b.x) + float(b.width) / 2.0, 520.0), 112.0, _gear * dir * (1.0 if i == 0 else -1.0) * dir, 12)
	# La rotaia della gru
	c.draw_rect(Rect2(110, RAIL_Y - 10, 1060, 14), STEEL_DARK)
	c.draw_rect(Rect2(110, RAIL_Y - 10, 1060, 3), STEEL.lightened(0.3))
	for x in range(130, 1170, 80):
		c.draw_line(Vector2(x, RAIL_Y - 10), Vector2(x, CEILING), Color(STEEL_DARK, 0.8), 3.0)
	# Lampade appese sopra i nastri: un cono di luce che dondola appena
	for x: float in [300.0, 980.0]:
		var sway := 6.0 * sin(t / 900.0 + x)
		var lamp := Vector2(x + sway, 150.0)
		c.draw_line(Vector2(x, CEILING), lamp, INK, 2.0)
		c.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-14, 4), lamp + Vector2(14, 4), lamp + Vector2(150, 410), lamp + Vector2(-150, 410)]), Color(1, 0.93, 0.7, 0.05))
		c.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-20, 8), lamp + Vector2(20, 8), lamp + Vector2(10, -6), lamp + Vector2(-10, -6)]), STEEL)
		c.draw_circle(lamp + Vector2(0, 9), 6.0, Color("fff3c4"))


func _draw_windows(c: CanvasItem, t: float) -> void:
	for cx: float in [180.0, 440.0, 840.0, 1100.0]:
		var r := Rect2(cx - 80.0, -230.0, 160.0, 260.0)
		c.draw_rect(r.grow(8), Color("231c18"))
		c.draw_rect(r, Color("ffe9a8").lerp(Color("ffcf7a"), 0.5 + 0.5 * sin(t / 5000.0 + cx)))
		c.draw_circle(Vector2(cx, r.position.y), 80.0, Color("ffe9a8"))
		for k in 3:
			c.draw_line(Vector2(r.position.x + 40.0 * (k + 1), r.position.y - 70.0), Vector2(r.position.x + 40.0 * (k + 1), r.end.y), Color("231c18"), 5.0)
		for k in 4:
			c.draw_line(Vector2(r.position.x, r.position.y + 65.0 * k), Vector2(r.end.x, r.position.y + 65.0 * k), Color("231c18"), 5.0)
		# La luce che entra in diagonale, con la polvere che ci balla dentro
		var shaft := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x + 180.0, 560.0), Vector2(r.position.x + 180.0, 560.0)])
		c.draw_colored_polygon(shaft, Color(1, 0.92, 0.7, 0.045 + 0.015 * sin(t / 1300.0 + cx)))
		for k in 6:
			var life := fposmod(t / 7000.0 + k * 0.17 + cx, 1.0)
			var at := Vector2(r.position.x + 30.0 + life * 200.0 + 20.0 * sin(t / 800.0 + k), r.end.y + life * 500.0)
			c.draw_circle(at, 1.6, Color(1, 0.95, 0.8, 0.5 * sin(life * PI)))


func _draw_sign(c: CanvasItem, now_ms: float) -> void:
	var box := Rect2(470, 70, 340, 104)
	c.draw_rect(box.grow(6), INK)
	c.draw_rect(box, Color("2d6b3f"))
	c.draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 52), Color("f2e3b3"))
	# La banana col sorriso, il marchio della fabbrica
	var b := Vector2(box.position.x + 40.0, box.position.y + 28.0)
	c.draw_arc(b + Vector2(0, -14), 22.0, 0.35, PI - 0.35, 12, BANANA, 11.0)
	c.draw_arc(b + Vector2(0, -14), 22.0, 0.35, PI - 0.35, 12, INK, 2.0)
	c.draw_string(_font, Vector2(box.position.x + 72.0, box.position.y + 38.0), "BANANE S.p.A.", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	var secs := 0 if _last_ko < 0.0 else int((now_ms - _last_ko) / 1000.0)
	if _last_ko < 0.0:
		secs = int(now_ms / 1000.0) % 1000
	c.draw_string(_font, Vector2(box.position.x + 12.0, box.position.y + 76.0), "SECONDI SENZA INCIDENTI", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2e3b3"))
	var digits := "%03d" % mini(secs, 999)
	var flash := _last_ko >= 0.0 and now_ms - _last_ko < 1500.0 and int(now_ms / 150.0) % 2 == 0
	c.draw_rect(Rect2(box.end.x - 92.0, box.position.y + 58.0, 80.0, 38.0), INK)
	c.draw_string(_font, Vector2(box.end.x - 86.0, box.position.y + 89.0), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("ff5a3d") if not flash else Color("fff3c4"))


func _draw_pillar(c: CanvasItem, x: float, warn: float, hot: bool, t: float) -> void:
	c.draw_rect(Rect2(x - 17.0, CEILING, 34.0, 740.0 - CEILING), STEEL_DARK)
	c.draw_rect(Rect2(x - 17.0, CEILING, 6.0, 740.0 - CEILING), STEEL)
	for k in range(int(CEILING), 700, 60):
		c.draw_circle(Vector2(x + 8.0, k), 2.5, STEEL.lightened(0.2))
	# Il lampeggiante: gira e illumina con la sirena o col turbo
	var lamp := Vector2(x, 300.0)
	var on := warn >= 0.0 or hot
	var col := Color("ff3b2f") if on else Color("7a2a24")
	c.draw_rect(Rect2(lamp.x - 12.0, lamp.y, 24.0, 10.0), INK)
	c.draw_circle(lamp, 11.0, col)
	if on:
		var a := t / (90.0 if hot else 160.0)
		for side in [0.0, PI]:
			var d := Vector2.from_angle(a + side)
			var tip := lamp + Vector2(d.x * 260.0, d.y * 70.0)
			c.draw_colored_polygon(PackedVector2Array([lamp, tip + Vector2(0, -40), tip + Vector2(0, 40)]), Color(1, 0.2, 0.15, 0.13))
		c.draw_circle(lamp, 22.0, Color(1, 0.25, 0.2, 0.25))


func _draw_pipes(c: CanvasItem, t: float) -> void:
	c.draw_rect(Rect2(-200, -110, 1680, 22), Color("6d4c3d"))
	c.draw_rect(Rect2(-200, -110, 1680, 5), Color("9a6f58"))
	for x in range(-200, 1480, 160):
		c.draw_rect(Rect2(x, -114, 12, 30), Color("4a3329"))
	# Sbuffi di vapore dalle valvole, uno ogni due secondi e mezzo, sfasati
	for v: Array in [[330.0, 0.0], [950.0, 1250.0]]:
		var at := Vector2(float(v[0]), -88.0)
		c.draw_circle(at, 9.0, Color("c0392b"))
		var age := fposmod(t + float(v[1]), 2500.0)
		if age < 1400.0:
			var k := age / 1400.0
			for p in 5:
				var pos := at + Vector2(10.0 * sin(p * 1.7 + k * 3.0), 10.0 + k * (90.0 + p * 18.0))
				c.draw_circle(pos, 8.0 + 22.0 * k, Color(0.95, 0.95, 0.92, 0.35 * (1.0 - k)))


func _draw_gear(c: CanvasItem, at: Vector2, r: float, angle: float, teeth: int) -> void:
	var col := Color("3a3330")
	for i in teeth:
		var a := angle + i * TAU / teeth
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		c.draw_colored_polygon(PackedVector2Array([at + d * (r - 4) + n * 12, at + d * (r + 16) + n * 8, at + d * (r + 16) - n * 8, at + d * (r - 4) - n * 12]), col)
	c.draw_circle(at, r, col)
	c.draw_circle(at, r * 0.72, Color("2a2421"))
	for i in 4:
		var d := Vector2.from_angle(angle + i * TAU / 4.0)
		c.draw_line(at, at + d * r * 0.72, col, 14.0)
	c.draw_circle(at, 16.0, Color("6b5d55"))


func draw_solid(c: CanvasItem, s: Dictionary, t: float, pressed: Array) -> bool:
	var i := _belt_of(s)
	if i >= 0:
		_draw_belt(c, s, i, t, pressed)
		return true
	_draw_furnace(c, s, t)
	return true


func _draw_belt(c: CanvasItem, s: Dictionary, i: int, t: float, pressed: Array) -> void:
	var r := Rect2(float(s.x), float(s.y), float(s.width), float(s.height))
	var v := velocity(i, t, pressed)
	var off: float = _offsets[i]
	var hot := turbo(t, pressed)
	var warn := siren(belts[i], t, warn_ms)
	# Il corpo della macchina, con i rivetti e le strisce di pericolo in basso
	c.draw_rect(r, STEEL_DARK)
	c.draw_rect(Rect2(r.position.x, r.position.y + 30.0, r.size.x, 4.0), STEEL)
	for x in range(int(r.position.x) + 12, int(r.end.x), 40):
		c.draw_circle(Vector2(x, r.position.y + 40.0), 2.5, STEEL.lightened(0.25))
	var stripe_y := r.end.y - 18.0
	c.draw_rect(Rect2(r.position.x, stripe_y, r.size.x, 18.0), YELLOW)
	var x0 := r.position.x
	while x0 < r.end.x:
		var poly := PackedVector2Array([Vector2(x0, stripe_y + 18), Vector2(x0 + 18, stripe_y), Vector2(minf(x0 + 32, r.end.x), stripe_y), Vector2(minf(x0 + 14, r.end.x), stripe_y + 18)])
		c.draw_colored_polygon(poly, INK)
		x0 += 36.0
	# Le frecce che dicono dove porta il nastro: verdi, arancio con la sirena, rosse col turbo; scorrono col nastro
	var col := Color("5fd068")
	if warn >= 0.0:
		col = Color("ff9f1a") if int(t / 180.0) % 2 == 0 else Color("ffd27a")
	if hot:
		col = Color("ff3b2f")
	var sign := 1.0 if v >= 0.0 else -1.0
	var span := r.size.x - 40.0
	for k in int(span / 60.0):
		var cx := r.position.x + 20.0 + fposmod(off * 0.5 + k * 60.0, span)
		var cy := r.position.y + 62.0
		c.draw_polyline(PackedVector2Array([Vector2(cx - 8 * sign, cy - 10), Vector2(cx + 8 * sign, cy), Vector2(cx - 8 * sign, cy + 10)]), col, 5.0)
	# Il nastro: gomma scura, le tacche che scorrono e i rulli sotto che girano
	c.draw_rect(Rect2(r.position.x - 8.0, r.position.y, r.size.x + 16.0, 22.0), Color("24272c"))
	for k in int(r.size.x / 22.0) + 1:
		var tx := r.position.x + fposmod(off + k * 22.0, r.size.x)
		c.draw_line(Vector2(tx, r.position.y + 2.0), Vector2(tx, r.position.y + 12.0), Color("3c424b"), 3.0)
	for k in int(r.size.x / 48.0) + 1:
		var rc := Vector2(r.position.x + 8.0 + k * 48.0, r.position.y + 16.0)
		c.draw_circle(rc, 7.0, Color("6b737d"))
		var d := Vector2.from_angle(off / 7.0)
		c.draw_line(rc - d * 6.0, rc + d * 6.0, INK, 2.0)
	c.draw_circle(Vector2(r.position.x - 8.0, r.position.y + 11.0), 11.0, Color("6b737d"))
	c.draw_circle(Vector2(r.end.x + 8.0, r.position.y + 11.0), 11.0, Color("6b737d"))
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), Color("c9ced4")) # il bordo calpestabile, chiaro
	# Le banane che viaggiano sul nastro (solo disegno: non si raccolgono)
	for k in int(r.size.x / 130.0):
		var bx := r.position.x + 20.0 + fposmod(off + k * 130.0 + i * 40.0, r.size.x - 40.0)
		_draw_banana(c, Vector2(bx, r.position.y - 5.0), sign, 1.0)
	# Col turbo le scintille dai rulli
	if hot:
		for k in 8:
			var life := fposmod(t / 420.0 + k * 0.137, 1.0)
			var from := Vector2(r.position.x + fposmod(k * 97.0, r.size.x), r.position.y + 18.0)
			var at := from + Vector2(-sign * 90.0 * life, -40.0 * life + 60.0 * life * life)
			c.draw_line(at, at + Vector2(-sign * 8.0, 3.0), Color(1, 0.85, 0.3, 1.0 - life), 2.0)


func _draw_banana(c: CanvasItem, at: Vector2, dir: float, size: float) -> void:
	var pts := PackedVector2Array()
	for k in 7:
		var a := lerpf(0.25, PI - 0.25, k / 6.0)
		pts.append(at + Vector2(cos(a) * 16.0 * dir, -sin(a) * 7.0 + 6.0) * size)
	for k in 7:
		var a := lerpf(PI - 0.25, 0.25, k / 6.0)
		pts.append(at + Vector2(cos(a) * 13.0 * dir, -sin(a) * 2.0 + 4.0) * size)
	c.draw_colored_polygon(pts, BANANA)
	c.draw_polyline(pts, Color(INK, 0.8), 1.5)
	c.draw_circle(at + Vector2(-15.0 * dir, 4.0) * size, 2.0 * size, Color("5a3d1e"))


func _draw_furnace(c: CanvasItem, s: Dictionary, t: float) -> void:
	var r := Rect2(float(s.x), float(s.y), float(s.width), float(s.height))
	var fire := _fire_on(t)
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, maxf(r.size.y, 120.0)), Color("3b1f17"))
	for row in 4:
		var yy := r.position.y + 10.0 + row * 24.0
		var xx := r.position.x + (0.0 if row % 2 == 0 else 22.0)
		while xx < r.end.x:
			c.draw_rect(Rect2(xx + 2, yy, 40, 20), Color("5a2e22"))
			xx += 44.0
	# La griglia del forno: rovente quando il fuoco è acceso
	var heat := 0.9 + 0.1 * sin(t / 80.0) if fire else 0.35 + 0.1 * sin(t / 400.0)
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8.0), GLOW.lerp(Color("ffe14d"), 0.5 * heat) * Color(1, 1, 1, 1))
	for x in range(int(r.position.x) + 10, int(r.end.x), 20):
		c.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + 8.0), Color(INK, 0.6), 3.0)
	c.draw_rect(Rect2(r.position.x, r.position.y - 30.0, r.size.x, 30.0), Color(GLOW, 0.12 * heat))


func draw_platform(c: CanvasItem, p: Dictionary, t: float) -> bool:
	# Passerella appesa: grigliato di metallo, corrimano e due tiranti fino al soffitto
	var x: float = p.x
	var y: float = p.y
	var w: float = p.width
	for side: float in [x + 12.0, x + w - 12.0]:
		c.draw_line(Vector2(side, CEILING), Vector2(side, y), Color(STEEL_DARK, 0.9), 3.0)
	c.draw_rect(Rect2(x, y, w, 12.0), STEEL_DARK)
	for k in range(0, int(w), 12):
		c.draw_line(Vector2(x + k, y + 12.0), Vector2(x + k + 12.0, y), Color(STEEL.lightened(0.15), 0.7), 1.5)
	c.draw_rect(Rect2(x, y, w, 4.0), Color("c9ced4"))
	c.draw_rect(Rect2(x, y + 12.0, w, 4.0), YELLOW)
	c.draw_line(Vector2(x, y - 30.0), Vector2(x + w, y - 30.0), Color(STEEL.lightened(0.2), 0.7), 3.0)
	for k in range(0, int(w) + 1, int(w / 4.0)):
		c.draw_line(Vector2(x + k, y), Vector2(x + k, y - 30.0), Color(STEEL.lightened(0.2), 0.7), 2.0)
	return true


func draw_mover(c: CanvasItem, m: Dictionary, pos: Vector2, t: float) -> bool:
	var w: float = m.width
	if str(m.get("kind", "")) == "gru":
		# La gru: il carrello sulla rotaia, il cavo e la cassa di banane su cui si sta in piedi
		var hook := Vector2(pos.x + w / 2.0, pos.y - 26.0)
		c.draw_rect(Rect2(hook.x - 26.0, RAIL_Y - 4.0, 52.0, 20.0), YELLOW)
		c.draw_rect(Rect2(hook.x - 26.0, RAIL_Y + 12.0, 52.0, 4.0), INK)
		c.draw_line(Vector2(hook.x, RAIL_Y + 16.0), hook, INK, 3.0)
		c.draw_line(hook, Vector2(pos.x + 8.0, pos.y), Color(INK, 0.8), 2.0)
		c.draw_line(hook, Vector2(pos.x + w - 8.0, pos.y), Color(INK, 0.8), 2.0)
		c.draw_arc(hook + Vector2(0, -4), 6.0, 0.0, PI * 1.5, 8, STEEL.lightened(0.3), 3.0)
		var box := Rect2(pos.x, pos.y, w, 46.0)
		c.draw_rect(box, Color("a8743f"))
		for k in 3:
			c.draw_line(Vector2(box.position.x, box.position.y + 15.0 * (k + 1)), Vector2(box.end.x, box.position.y + 15.0 * (k + 1)), Color("7a4f28"), 2.0)
		c.draw_line(box.position, box.end, Color("7a4f28"), 3.0)
		c.draw_rect(box, INK, false, 2.0)
		c.draw_rect(Rect2(box.position.x, box.position.y, w, 4.0), Color("f2e3b3"))
		c.draw_string(_font, Vector2(box.position.x + 14.0, box.position.y + 34.0), "BANANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("2b1a0c"))
		return true
	# L'ascensore: una gabbia coi cavi fino al soffitto e le strisce gialle e nere sotto
	for side: float in [pos.x + 10.0, pos.x + w - 10.0]:
		c.draw_line(Vector2(side, CEILING), Vector2(side, pos.y), Color(INK, 0.85), 2.0)
	c.draw_rect(Rect2(pos.x, pos.y, w, 12.0), STEEL)
	c.draw_rect(Rect2(pos.x, pos.y, w, 4.0), Color("c9ced4"))
	for x in range(0, int(w), 20):
		c.draw_rect(Rect2(pos.x + x, pos.y + 12.0, minf(10.0, w - x), 6.0), YELLOW)
	c.draw_circle(Vector2(pos.x + w / 2.0, pos.y + 22.0), 4.0, Color("5fd068") if int(t / 400.0) % 2 == 0 else Color("2f6b35"))
	return true


func draw_hazard(c: CanvasItem, h: Dictionary, r: Rect2, on: bool, t: float) -> bool:
	if str(h.get("kind", "")) != "pressa":
		return false
	var state := press_bottom(h, r, t)
	var bottom: float = state[0]
	var shake: float = state[1]
	var jitter := Vector2(sin(t / 25.0) * 2.5 * shake, 0)
	var cx := r.get_center().x
	# Le due guide ai lati, dal soffitto al nastro: si vede che è una macchina e non una piattaforma
	for gx: float in [r.position.x - 16.0, r.end.x + 10.0]:
		c.draw_rect(Rect2(gx, CEILING, 6.0, r.end.y - CEILING), Color(STEEL_DARK, 0.9))
		c.draw_rect(Rect2(gx, r.end.y - 90.0, 6.0, 90.0), Color(YELLOW, 0.7))
	# Il cilindro in alto e lo stelo lucido che scende
	c.draw_rect(Rect2(cx - 34.0, CEILING, 68.0, 300.0), STEEL_DARK)
	c.draw_rect(Rect2(cx - 34.0, CEILING + 290.0, 68.0, 14.0), YELLOW)
	c.draw_rect(Rect2(cx - 12.0 + jitter.x, CEILING + 300.0, 24.0, bottom - 46.0 - CEILING - 300.0), Color("b9c2cc"))
	c.draw_rect(Rect2(cx - 12.0 + jitter.x, CEILING + 300.0, 6.0, bottom - 46.0 - CEILING - 300.0), Color("e6ecf2"))
	# La testa, con le strisce di pericolo e la lampada rossa che lampeggia durante l'avviso
	var head := Rect2(r.position.x - 8.0 + jitter.x, bottom - 46.0, r.size.x + 16.0, 46.0)
	c.draw_rect(head, STEEL)
	c.draw_rect(Rect2(head.position.x, head.end.y - 12.0, head.size.x, 12.0), YELLOW)
	var sx := head.position.x
	while sx < head.end.x - 6.0:
		c.draw_colored_polygon(PackedVector2Array([Vector2(sx, head.end.y), Vector2(sx + 12, head.end.y - 12), Vector2(minf(sx + 20, head.end.x), head.end.y - 12), Vector2(minf(sx + 8, head.end.x), head.end.y)]), INK)
		sx += 22.0
	c.draw_rect(head, INK, false, 2.0)
	var blink := shake > 0.0 and int(t / (160.0 - 100.0 * shake)) % 2 == 0
	c.draw_circle(Vector2(cx + jitter.x, head.position.y + 16.0), 7.0, Color("ff3b2f") if blink or on else Color("6b2420"))
	# Il colpo: polvere e righe di velocità appena tocca il nastro
	var period: float = h.get("periodMs", 6000)
	var since := fposmod(t + float(h.get("offsetMs", 0)), period)
	if since < 260.0:
		var k := since / 260.0
		for side in [-1.0, 1.0]:
			for p in 3:
				var at := Vector2(cx + side * (r.size.x / 2.0 + 10.0 + 50.0 * k + p * 10.0), r.end.y - 6.0 - p * 6.0)
				c.draw_circle(at, 6.0 + 10.0 * k, Color(0.85, 0.82, 0.75, 0.6 * (1.0 - k)))
	return true


# La leva: una cassetta con la manopola rossa. Carica pende a sinistra e brilla; tirata va a destra con la luce verde
# per la durata dell'effetto; poi grigia, con la barra che si riempie finché si può ritirare
func draw_pad(c: CanvasItem, p: Dictionary, pressed_at: Variant, t: float) -> bool:
	if str(p.get("sound", "")) != "leva":
		return false
	var x: float = p.x
	var y: float = p.y
	var w: float = p.width
	var charge := StageMotion.pad_charge(p, pressed_at, t)
	var since := INF if pressed_at == null else t - float(pressed_at)
	var pulled := since < float(p.effect.durationMs)
	var box := Rect2(x - 2.0, y - 20.0, w + 4.0, 20.0)
	c.draw_rect(box, STEEL_DARK)
	c.draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 4.0), YELLOW)
	var pivot := Vector2(x + w / 2.0, box.position.y)
	var angle := deg_to_rad(35.0 if pulled else -35.0)
	if since < 160.0:
		angle = deg_to_rad(lerpf(-35.0, 35.0, since / 160.0))
	var tip := pivot + Vector2(sin(angle), -cos(angle)) * 34.0
	if charge >= 1.0:
		c.draw_circle(tip, 16.0 + 3.0 * sin(t / 200.0), Color(1, 0.3, 0.2, 0.22))
	c.draw_line(pivot, tip, Color("c9ced4"), 5.0)
	c.draw_circle(tip, 8.0, Color("e53935") if charge >= 1.0 or pulled else Color("7d7d85"))
	c.draw_circle(tip + Vector2(-2.5, -2.5), 2.5, Color(1, 1, 1, 0.6))
	c.draw_circle(pivot, 5.0, INK)
	c.draw_circle(Vector2(box.position.x + 9.0, box.position.y + 11.0), 4.0, Color("5fd068") if pulled else Color("2f3a33"))
	if charge < 1.0 and not pulled:
		c.draw_rect(Rect2(x, y - 3.0, w * charge, 3.0), YELLOW)
	return true


func draw_front(c: CanvasItem, t: float, view: Rect2, pressed: Array) -> void:
	var warn := siren(belts[0], t, warn_ms) if not belts.is_empty() else -1.0
	if warn >= 0.0:
		var pulse := 0.5 + 0.5 * sin(t / 90.0)
		var a := 0.1 * pulse * (0.5 + warn)
		c.draw_rect(Rect2(view.position.x, view.position.y, view.size.x, 26.0), Color(1, 0.15, 0.1, a * 2.0))
		c.draw_rect(Rect2(view.position.x, view.end.y - 26.0, view.size.x, 26.0), Color(1, 0.15, 0.1, a * 2.0))
		_shout(c, view, "CAMBIO VERSO!", 34, Color("ffb23e"), t, 0.32, 1.0)
	if turbo(t, pressed):
		var since := _turbo_since(t, pressed)
		if since < TURBO_SHOW_MS:
			var k := minf(1.0, since / 220.0)
			var alpha := minf(1.0, (TURBO_SHOW_MS - since) / 300.0)
			_shout(c, view, "TURBO!", int(lerpf(24.0, 72.0, k)), Color("ff4a2a"), t, 0.46, alpha)


func _shout(c: CanvasItem, view: Rect2, text: String, size: int, col: Color, t: float, at_y: float, alpha: float) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(view.get_center().x - tw / 2.0, view.position.y + view.size.y * at_y)
	c.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(INK, alpha))
	var x := at.x
	for i in text.length():
		var ch := text[i]
		var hop := -5.0 * absf(sin(t / 110.0 + i * 0.6))
		c.draw_string(_font, Vector2(x, at.y + hop), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.lightened(0.25 * (i % 2)), alpha))
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func on_event(e: Dictionary, now_ms: float) -> void:
	match str(e.get("type", "")):
		"ko":
			_last_ko = now_ms
			_packed.erase(str(e.get("id", "")))
		"hazard":
			var i := int(e.get("index", -1))
			if i >= 0 and i < hazards.size() and hazards[i].get("pack") is Dictionary:
				_packed[str(e.id)] = now_ms


# La scatola di banane sopra chi è impacchettato, davanti a lui: gli occhi spuntano dal buco della maniglia
func draw_over_fighters(c: CanvasItem, players: Dictionary, now_ms: float) -> void:
	for id: String in _packed.keys():
		var p: Variant = players.get(id)
		if p == null or (now_ms - float(_packed[id]) > 300.0 and not p.get("stunned", false)):
			_packed.erase(id)
			continue
		var since := now_ms - float(_packed[id])
		var drop := minf(1.0, since / 140.0) # la scatola cala dall'alto appena la pressa scende
		var wobble := sin(now_ms / 55.0) * 2.5
		var feet := Vector2(float(p.x), float(p.y))
		var box := Rect2(feet.x - 38.0 + wobble, feet.y - 84.0 - 60.0 * (1.0 - drop), 76.0, 84.0)
		c.draw_rect(box, Color("c99a5b"))
		c.draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 12.0), Color("b5864a")) # le alette chiuse
		c.draw_rect(Rect2(box.get_center().x - 6.0, box.position.y, 12.0, box.size.y), Color("e8d39a", 0.8)) # il nastro adesivo
		c.draw_rect(box, INK, false, 2.5)
		var hole := Rect2(box.position.x + 18.0, box.position.y + 24.0, 40.0, 14.0)
		c.draw_rect(hole, Color("1c1612"))
		var look := 4.0 * sin(now_ms / 300.0)
		for side in [-1.0, 1.0]:
			c.draw_circle(hole.get_center() + Vector2(side * 8.0 + look, 0), 4.0, Color.WHITE)
			c.draw_circle(hole.get_center() + Vector2(side * 8.0 + look * 1.3, 1.0), 2.0, INK)
		c.draw_string(_font, Vector2(box.position.x + 8.0, box.end.y - 26.0), "FRAGILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b3261e"))
		_draw_banana(c, Vector2(box.get_center().x, box.end.y - 12.0), 1.0, 0.7)
		# Premi i tasti! Il suggerimento sopra la scatola, che lampeggia
		if int(now_ms / 250.0) % 2 == 0:
			c.draw_string_outline(_font, Vector2(box.position.x - 6.0, box.position.y - 10.0), "PREMI!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, INK)
			c.draw_string(_font, Vector2(box.position.x - 6.0, box.position.y - 10.0), "PREMI!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, YELLOW)


# La sirena prima del cambio di verso, il colpo delle presse e il turbo quando parte
func cues(before: float, now: float, pressed: Array) -> Array:
	var out: Array = []
	if not belts.is_empty():
		var b: Dictionary = belts[0]
		if siren(b, before, warn_ms) < 0.0 and siren(b, now, warn_ms) >= 0.0:
			out.append(["siren", 640.0])
		if not turbo(before, pressed) and turbo(now, pressed):
			out.append(["turbo", 640.0])
	for h: Dictionary in hazards:
		if str(h.get("kind", "")) == "pressa" and not StageMotion.hazard_active(h, before) and StageMotion.hazard_active(h, now):
			out.append(["pressa", float(h.x) + float(h.width) / 2.0])
	return out
