# Arena musicale viva (#423), nello spirito di Mario Wonder: tutto balla a tempo del brano. Cielo stellato, luna con
# la faccia, colline che rimbalzano, fiori che cantano le note della melodia e commentano i bottoni, casse che pompano,
# note che volano, la tastiera del pianoforte sul palco e le piattaforme con gli occhi. Con i tre bottoni sonori attivi
# insieme arriva la "Meraviglia!": arcobaleno, coriandoli e la mappa che cambia colore.
# Solo grafica: tutto si calcola dal tempo dell'arena (stageMs), dai bpm del brano e dalle pressioni dei bottoni dello
# snapshot, come il resto delle arene (stage_motion.gd). world_view.gd lo chiama dentro _draw.
extends RefCounted

const StageMotion := preload("res://scripts/stage_motion.gd")
const INK := Color("1a1030")
const PETALS := [Color("ffd54f"), Color("ff8ab3"), Color("ffb74d"), Color("80deea"), Color("ce93d8"), Color("aed581")]
const LINES := ["Che ritmo!", "Ancora!", "Bum bum!", "Che salto!", "Musica!", "Oooh!", "Bravo!"]
const BUBBLE_MS := 1800.0 # quanto resta il fumetto di un fiore
const SINGING_MS := 260.0 # per quanto un fiore tiene la bocca aperta dopo una nota

var active := false
var bpm := 120.0
var pads: Array = []
var _melody: Array = [] # le piattaforme della melodia (group "melodia"): accendono la tastiera e fanno cantare i fiori
var _flowers: Array = [] # {x, y, petal, size, phase}
var _bubble := {} # {flower, text, at (ms dell'orologio del client)}
var _font: Font = ThemeDB.fallback_font


func setup(spec: Dictionary) -> void:
	var song: Variant = spec.get("song")
	active = song is Dictionary
	_bubble = {}
	if not active:
		return
	bpm = float((song as Dictionary).get("bpm", 120))
	pads = spec.get("pads", []) if spec.get("pads") is Array else []
	_melody = []
	for m: Dictionary in spec.get("movers", []) if spec.get("movers") is Array else []:
		if str(m.get("group", "")) == "melodia":
			_melody.append(m)
	_flowers = []
	for i in 11:
		var x := -160.0 + i * 160.0 + 40.0 * sin(i * 2.3)
		_flowers.append({"x": x, "y": front_hill_y(x), "petal": PETALS[i % PETALS.size()], "size": 15.0 + 5.0 * fposmod(i * 0.37, 1.0), "phase": i % 2})


# --- Il tempo della musica ---

# Da 0 a 1 dentro il battito, e quale battito è
static func beat_phase(t: float, beats_per_minute: float) -> float:
	var beat := 60000.0 / beats_per_minute
	return fposmod(t, beat) / beat


static func beat_index(t: float, beats_per_minute: float) -> int:
	return int(floorf(t / (60000.0 / beats_per_minute)))


# Il colpo del battito: 1 appena arriva, poi si spegne
static func bop(t: float, beats_per_minute: float) -> float:
	return exp(-beat_phase(t, beats_per_minute) * 6.0)


# La "Meraviglia" (#423): da 0 a 1 quando gli effetti di tutti i bottoni sono attivi insieme, con 400 ms di entrata e
# uscita. Restituisce [k, quando è cominciata (stageMs)]
static func wonder(t: float, pad_specs: Array, pressed: Array) -> Array:
	if pad_specs.is_empty() or pressed.size() < pad_specs.size():
		return [0.0, 0.0]
	var k := 1.0
	var start := -INF
	for i in pad_specs.size():
		if pressed[i] == null:
			return [0.0, 0.0]
		var since := t - float(pressed[i])
		var dur: float = pad_specs[i].effect.durationMs
		if since < 0.0 or since >= dur:
			return [0.0, 0.0]
		start = maxf(start, float(pressed[i]))
		k = minf(k, minf(1.0, (dur - since) / 400.0))
	return [minf(k, (t - start) / 400.0), start]


# Da quanto la piattaforma è accesa (ms), INF se è spenta o non ha finestre
static func since_on(m: Dictionary, t: float) -> float:
	if not (m.get("on") is Array):
		return INF
	var left := fposmod(t + float(m.get("offsetMs", 0)), float(m.periodMs))
	for w: Array in m.on:
		if left >= float(w[0]) and left < float(w[1]):
			return left - float(w[0])
	return INF


static func front_hill_y(x: float) -> float:
	return 520.0 + 26.0 * sin(x / 120.0 + 2.0) + 12.0 * sin(x / 47.0)


static func back_hill_y(x: float) -> float:
	return 430.0 + 45.0 * sin(x / 170.0) + 22.0 * sin(x / 63.0 + 1.0)


# Il colore del cielo durante la Meraviglia: gira per tutto l'arcobaleno
static func rainbow(t: float, offset := 0.0) -> Color:
	return Color.from_hsv(fposmod(t / 4000.0 + offset, 1.0), 0.55, 1.0)


# --- Disegno ---

func on_pad(e: Dictionary, now_ms: float) -> void:
	if not active or _flowers.is_empty():
		return
	var best := 0
	for i in _flowers.size():
		if absf(float(_flowers[i].x) - float(e.x)) < absf(float(_flowers[best].x) - float(e.x)):
			best = i
	_bubble = {"flower": best, "text": LINES[int(now_ms / 7.0) % LINES.size()], "at": now_ms}


# Dietro a tutto: cielo, stelle, luna, arcobaleno, colline, casse, note e fiori
func draw_back(c: CanvasItem, t: float, view: Rect2, pressed: Array, now_ms: float) -> void:
	if not active:
		return
	var w := wonder(t, pads, pressed)
	var wk: float = w[0]
	var b := bop(t, bpm)
	var area := view.grow(60)
	# Cielo a fasce, dal viola profondo al magenta vicino all'orizzonte; con la Meraviglia si colora d'arcobaleno
	var bands := 10
	var top := minf(area.position.y, -400.0)
	var bottom := maxf(area.end.y, 1000.0)
	for i in bands:
		var y0 := lerpf(top, 560.0, float(i) / bands)
		var y1 := lerpf(top, 560.0, float(i + 1) / bands) + 1.0
		var col := Color("170f2e").lerp(Color("6a2c7a"), float(i) / bands)
		if wk > 0.0:
			col = col.lerp(rainbow(t, i * 0.06), wk * 0.6)
		c.draw_rect(Rect2(area.position.x, y0, area.size.x, y1 - y0), col)
	c.draw_rect(Rect2(area.position.x, 560.0, area.size.x, bottom - 560.0), Color("6a2c7a").lerp(rainbow(t, 0.6), wk * 0.6))
	# Stelle: brillano piano e saltano a ogni battito
	for i in 48:
		var sx := fposmod(i * 271.3, 1800.0) - 260.0
		var sy := fposmod(i * 157.7, 760.0) - 360.0
		var tw := 0.5 + 0.5 * sin(t / 600.0 + i)
		var r := 1.2 + 1.3 * tw + 1.5 * b * float(i % 3 == beat_index(t, bpm) % 3)
		c.draw_circle(Vector2(sx, sy), r, Color(1, 1, 0.85, 0.4 + 0.5 * tw))
	_draw_moon(c, Vector2(1010, 40), 58.0 * (1.0 + 0.05 * b), t)
	if wk > 0.0:
		_draw_rainbow(c, wk)
	# Colline dietro, poi davanti: rimbalzano a tempo, a battiti alterni
	var odd := beat_index(t, bpm) % 2 == 1
	_draw_hill(c, area, func(x: float) -> float: return back_hill_y(x), Color("3b2466").lerp(rainbow(t, 0.3), wk * 0.4), b * (0.6 if odd else 1.0), 4.0)
	_draw_speaker(c, Vector2(20, 640), t, b)
	_draw_speaker(c, Vector2(1260, 640), t, b)
	_draw_flying_notes(c, t, wk)
	_draw_hill(c, area, func(x: float) -> float: return front_hill_y(x), Color("4e2a7f").lerp(rainbow(t, 0.15), wk * 0.4), b * (1.0 if odd else 0.6), 6.0)
	var singing := _melody_singing(t)
	for i in _flowers.size():
		_draw_flower(c, _flowers[i], t, b, singing, wk)
	if not _bubble.is_empty() and now_ms - float(_bubble.at) < BUBBLE_MS:
		var f: Dictionary = _flowers[int(_bubble.flower)]
		_draw_bubble(c, Vector2(float(f.x), float(f.y) - 70.0), str(_bubble.text), now_ms - float(_bubble.at))


# Sopra al pavimento: la tastiera del pianoforte, che si illumina con la melodia e i bottoni
func draw_floor(c: CanvasItem, s: Dictionary, t: float, pressed: Array, fx: Callable) -> void:
	if not active:
		return
	var x0: float = s.x
	var y0: float = float(s.y) + 8.0
	var h: float = float(s.height) - 12.0
	var keys := 20
	var kw: float = float(s.width) / keys
	var lit := {}
	for i in _melody.size():
		var m: Dictionary = _melody[i]
		if StageMotion.mover_on(m, t) or fx.call(m, t).on:
			lit[2 + i * 2] = _hex(m.get("tint", 0xffb74d))
	for k in keys:
		var r := Rect2(x0 + k * kw + 1, y0, kw - 2, h)
		var col: Color = lit.get(k, Color("f4efe6"))
		c.draw_rect(r, col)
		if lit.has(k):
			c.draw_rect(r.grow(2), Color(col, 0.35), false, 3.0)
	for k in keys - 1:
		if k % 7 in [2, 6]:
			continue # come su un pianoforte vero: tra Mi e Fa e tra Si e Do non c'è il tasto nero
		c.draw_rect(Rect2(x0 + (k + 1) * kw - kw * 0.3, y0, kw * 0.6, h * 0.58), INK)
	# Il bordo del palco pulsa con la cassa
	var b := bop(t, bpm)
	c.draw_rect(Rect2(x0, float(s.y), float(s.width), 6), Color("ff4fd8").lightened(0.4 * b))


# La faccia di una piattaforma della musica: due occhi che guardano il lottatore più vicino e una bocca che canta
# quando la piattaforma si accende. Sotto la superficie, dentro una nuvoletta: la superficie su cui si sta resta pos.y
func draw_face(c: CanvasItem, pos: Vector2, w: float, tint: Color, t: float, look: Variant, since: float) -> void:
	if not active:
		return
	var squash := 1.0 + 0.12 * bop(t, bpm)
	var body := Rect2(pos.x + 6, pos.y + 8, w - 12, 16 * squash)
	c.draw_rect(body, tint.darkened(0.15))
	c.draw_circle(Vector2(body.position.x, body.get_center().y), body.size.y / 2.0, tint.darkened(0.15))
	c.draw_circle(Vector2(body.end.x, body.get_center().y), body.size.y / 2.0, tint.darkened(0.15))
	var center := body.get_center()
	var dir := Vector2.ZERO
	if look is Vector2:
		dir = ((look as Vector2) - center).limit_length(1.0) if ((look as Vector2) - center).length() > 1.0 else Vector2.ZERO
	var blink := fposmod(t + pos.x * 13.0, 3700.0) < 120.0
	for side in [-1, 1]:
		var e := center + Vector2(side * 9.0, -2.0)
		if blink:
			c.draw_line(e + Vector2(-3, 0), e + Vector2(3, 0), INK, 2.0)
		else:
			c.draw_circle(e, 4.0, Color.WHITE)
			c.draw_circle(e + dir * 1.8, 2.2, INK)
	if since < SINGING_MS:
		var open := 1.0 - since / SINGING_MS
		c.draw_circle(center + Vector2(0, 5), 2.0 + 3.0 * open, INK)
	else:
		c.draw_arc(center + Vector2(0, 3), 3.5, 0.2, PI - 0.2, 6, INK, 1.5)


# Davanti a tutto, nell'inquadratura: coriandoli e la scritta della Meraviglia
func draw_front(c: CanvasItem, t: float, view: Rect2, pressed: Array) -> void:
	if not active:
		return
	var w := wonder(t, pads, pressed)
	var wk: float = w[0]
	if wk <= 0.0:
		return
	for i in 70:
		var speed := 0.12 + 0.08 * fposmod(i * 0.61, 1.0)
		var y := view.position.y + fposmod(t * speed + i * 97.0, view.size.y + 40.0) - 20.0
		var x := view.position.x + fposmod(i * 211.7, view.size.x) + 18.0 * sin(t / 300.0 + i)
		var col := rainbow(t, i * 0.13)
		col.a = wk
		var spin := sin(t / 150.0 + i)
		c.draw_rect(Rect2(x - 4.0 * spin, y - 3, 8.0 * absf(spin) + 1.0, 6), col)
	var since := t - float(w[1])
	if since < 2200.0:
		var k := minf(1.0, since / 250.0)
		var size := int(lerpf(20.0, 64.0, k) * (1.0 + 0.08 * sin(since / 60.0)))
		var text := "MERAVIGLIA!"
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(view.get_center().x - tw / 2.0, view.position.y + view.size.y * 0.28)
		var alpha := minf(1.0, (2200.0 - since) / 400.0)
		c.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(INK, alpha))
		var x := at.x
		for ch_i in text.length():
			var ch := text[ch_i]
			var col := rainbow(t, ch_i * 0.08)
			col.a = alpha
			var hop := -6.0 * absf(sin(since / 120.0 + ch_i * 0.5))
			c.draw_string(_font, Vector2(x, at.y + hop), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _melody_singing(t: float) -> float:
	var best := INF
	for m: Dictionary in _melody:
		best = minf(best, since_on(m, t))
	return best


func _draw_moon(c: CanvasItem, at: Vector2, r: float, t: float) -> void:
	c.draw_circle(at, r + 14.0, Color(1, 0.95, 0.7, 0.12))
	c.draw_circle(at, r, Color("fff3c4"))
	c.draw_circle(at + Vector2(-r * 0.35, r * 0.35), r * 0.16, Color("f1dfa0"))
	c.draw_circle(at + Vector2(r * 0.4, -r * 0.3), r * 0.1, Color("f1dfa0"))
	# Occhi chiusi felici e un sorriso; ogni tanto fa l'occhiolino
	var wink := fposmod(t, 9000.0) < 500.0
	c.draw_arc(at + Vector2(-r * 0.3, -r * 0.1), r * 0.14, PI + 0.3, TAU - 0.3, 8, INK, 3.0)
	if wink:
		c.draw_line(at + Vector2(r * 0.18, -r * 0.1), at + Vector2(r * 0.42, -r * 0.1), INK, 3.0)
	else:
		c.draw_arc(at + Vector2(r * 0.3, -r * 0.1), r * 0.14, PI + 0.3, TAU - 0.3, 8, INK, 3.0)
	c.draw_arc(at + Vector2(0, r * 0.15), r * 0.3, 0.3, PI - 0.3, 10, INK, 3.0)
	c.draw_circle(at + Vector2(-r * 0.5, r * 0.15), r * 0.1, Color(1, 0.6, 0.6, 0.5))
	c.draw_circle(at + Vector2(r * 0.5, r * 0.15), r * 0.1, Color(1, 0.6, 0.6, 0.5))


func _draw_rainbow(c: CanvasItem, k: float) -> void:
	var colors := [Color("ff5252"), Color("ffab40"), Color("ffee58"), Color("69f0ae"), Color("40c4ff"), Color("b388ff")]
	for i in colors.size():
		var col: Color = colors[i]
		col.a = 0.55 * k
		c.draw_arc(Vector2(640, 600), 560.0 - i * 18.0, PI, TAU, 48, col, 18.0)


func _draw_hill(c: CanvasItem, area: Rect2, height: Callable, col: Color, b: float, amp: float) -> void:
	var pts := PackedVector2Array()
	var x := floorf(area.position.x / 40.0) * 40.0
	var base := 760.0
	while x <= area.end.x + 40.0:
		var y: float = height.call(x)
		pts.append(Vector2(x, y - amp * b))
		x += 40.0
	pts.append(Vector2(pts[pts.size() - 1].x, maxf(base, area.end.y)))
	pts.append(Vector2(pts[0].x, maxf(base, area.end.y)))
	c.draw_colored_polygon(pts, col)
	c.draw_polyline(pts.slice(0, pts.size() - 2), col.lightened(0.25), 3.0)


func _draw_speaker(c: CanvasItem, foot: Vector2, t: float, b: float) -> void:
	var kick := b if beat_index(t, bpm) % 2 == 0 else b * 0.5 # la cassa batte sull'1 e sul 3
	var box := Rect2(foot.x - 55, foot.y - 190, 110, 190)
	c.draw_rect(box, Color("221836"))
	c.draw_rect(box, Color("ff4fd8", 0.6), false, 3.0)
	for cone in [[Vector2(0, -135), 30.0], [Vector2(0, -60), 40.0]]:
		var at: Vector2 = foot + (cone[0] as Vector2)
		var r: float = cone[1] * (1.0 + 0.12 * kick)
		c.draw_circle(at, r, Color("3a2a55"))
		c.draw_circle(at, r * 0.6, Color("120c22"))
		c.draw_circle(at, r * 0.2 + 3.0 * kick, Color("ff4fd8").lightened(0.3 * kick))


# Note che escono dalle casse e salgono ondeggiando; con la Meraviglia sono il doppio e d'arcobaleno
func _draw_flying_notes(c: CanvasItem, t: float, wk: float) -> void:
	var count := 10 if wk <= 0.0 else 20
	for i in count:
		var from_x := 20.0 if i % 2 == 0 else 1260.0
		var life := fposmod(t / 3200.0 + i * 0.173, 1.0)
		var at := Vector2(from_x + (1 if i % 2 == 0 else -1) * life * 260.0 + 20.0 * sin(t / 400.0 + i), 520.0 - life * 520.0)
		var col := Color("ffe082") if wk <= 0.0 else rainbow(t, i * 0.1)
		col.a = sin(life * PI)
		c.draw_circle(at, 6.0, col)
		c.draw_line(at + Vector2(5, 0), at + Vector2(5, -18), col, 2.5)
		if i % 3 == 0:
			c.draw_line(at + Vector2(5, -18), at + Vector2(13, -12), col, 2.5)


func _draw_flower(c: CanvasItem, f: Dictionary, t: float, b: float, singing: float, wk: float) -> void:
	var on_beat: bool = beat_index(t, bpm) % 2 == int(f.phase)
	var size: float = float(f.size) * (1.0 + 0.4 * wk)
	var sway := 6.0 * sin(t / 500.0 + float(f.x)) * (1.0 + 2.0 * wk)
	var root := Vector2(float(f.x), float(f.y))
	var head := root + Vector2(sway, -size * 2.6 - (8.0 * b if on_beat else 0.0))
	c.draw_line(root, head, Color("2e7d32"), 4.0)
	c.draw_circle(root + (head - root) * 0.5 + Vector2(8, 0), 5.0, Color("43a047")) # una foglia
	var petal: Color = f.petal
	if wk > 0.0:
		petal = petal.lerp(rainbow(t, float(f.x) / 900.0), wk)
	for i in 6:
		var a := i * TAU / 6.0 + t / 2000.0
		c.draw_circle(head + Vector2(cos(a), sin(a)) * size * 0.75, size * 0.48, petal)
	c.draw_circle(head, size * 0.62, Color("fff8e1"))
	var blink := fposmod(t + float(f.x) * 7.0, 4100.0) < 130.0
	for side in [-1, 1]:
		var e := head + Vector2(side * size * 0.24, -size * 0.12)
		if blink:
			c.draw_line(e + Vector2(-2.5, 0), e + Vector2(2.5, 0), INK, 2.0)
		else:
			c.draw_circle(e, size * 0.1 + 1.0, INK)
	# Canta quando suona una nota della melodia (o con la Meraviglia): la bocca si apre
	if singing < SINGING_MS or wk > 0.0:
		var open := maxf(1.0 - singing / SINGING_MS, wk * (0.6 + 0.4 * b))
		c.draw_circle(head + Vector2(0, size * 0.25), size * (0.1 + 0.16 * open), Color("b71c1c"))
	else:
		c.draw_arc(head + Vector2(0, size * 0.15), size * 0.2, 0.3, PI - 0.3, 6, INK, 2.0)


func _draw_bubble(c: CanvasItem, at: Vector2, text: String, age: float) -> void:
	var size := 20
	var pop := minf(1.0, age / 120.0)
	var alpha := minf(1.0, (BUBBLE_MS - age) / 300.0)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var box := Rect2(at.x - tw / 2.0 - 10, at.y - 30 * pop, tw + 20, 30)
	c.draw_rect(box, Color(1, 1, 1, alpha))
	c.draw_rect(box, Color(INK, alpha), false, 2.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(at.x - 6, box.end.y), Vector2(at.x + 6, box.end.y), Vector2(at.x, box.end.y + 10)]), Color(1, 1, 1, alpha))
	c.draw_string(_font, Vector2(box.position.x + 10, box.end.y - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, alpha))


static func _hex(n: Variant) -> Color:
	return Color.hex((int(n) << 8) | 0xff)
