# Il Palco, cambio di genere, vivo come Sala Prove: un concerto di notte dove il genere che suona cambia l'arena.
# Dietro c'è il maxischermo col genere e l'equalizzatore, i tralicci coi fari che girano, il DJ (un bonobo con le cuffie)
# alla consolle che muove la testa a tempo; davanti il pubblico che salta. Ogni genere ha la sua luce: il metal rosso
# con le braci e le colonne di fiamme ai bordi, il reggae verde e oro con la luna grande (la gravità da luna), la techno
# viola e ciano con lo strobo e le piattaforme al neon che si scambiano a tempo. I tre dischi girano quando suona il
# loro genere; prima del cambio automatico il DJ lo annuncia.
# Solo grafica: tutto dal tempo dell'arena e dalle pressioni dei dischi dello snapshot (genre_at in stage_motion.gd,
# come physics/genre.ts). La chiama theme_stage.gd.
extends RefCounted

const StageMotion := preload("res://scripts/stage_motion.gd")
const HazardFx := preload("res://scripts/hazard_fx.gd")
const INK := Color("120e16")
const WOOD := Color("4a3222")
const WOOD_EDGE := Color("8b6a45")
const TRUSS := Color("8d929c")
const BANNER_MS := 2600.0
# I colori di ogni genere: [luce principale, seconda luce, cielo in alto, cielo in basso]
const LOOK := {
	"": [Color("f4e7c5"), Color("8fb3ff"), Color("10141f"), Color("1d2b3a")],
	"metal": [Color("ff3b1f"), Color("ff9d2e"), Color("120607"), Color("3b0d0c")],
	"reggae": [Color("3fbf5a"), Color("ffd23f"), Color("0e1d16"), Color("33401b")],
	"techno": [Color("c04bff"), Color("2ee6ff"), Color("0b0620"), Color("221046")],
}
const NAMES := {"": "PROVA DEL SUONO", "metal": "METAL!", "reggae": "REGGAE!", "techno": "TECHNO!"}
const RULES := {"metal": "colpi più forti, fiamme ai bordi", "reggae": "gravità da luna", "techno": "piattaforme a tempo"}

var stage: Dictionary = {}
var pads: Array = []
var hazards: Array = []
var blink_beats := 4.0
var warn_ms := 2000.0
var _pressed: Array = [] # le pressioni dei dischi dell'ultimo draw_back (draw_platform non le riceve)
var _genre := "" # il genere dell'ultimo disegno
var _changed_at := -INF # tempo dell'arena del cambio di genere, per la scritta
var _light := 0.0 # 0..1: quanto è arrivata la luce del genere nuovo (sfuma in ~0.5 s)
var _look_from: Array = LOOK[""]
var _last_t := -1.0
var _font: Font = ThemeDB.fallback_font


func setup(spec: Dictionary, game: Dictionary) -> void:
	stage = spec
	pads = spec.get("pads", []) if spec.get("pads") is Array else []
	hazards = spec.get("hazards", []) if spec.get("hazards") is Array else []
	var g: Dictionary = game.get("genre", {})
	blink_beats = float(g.get("technoBlinkBeats", 4))
	warn_ms = float(g.get("warnMs", 2000))
	_genre = ""
	_changed_at = -INF
	_light = 1.0
	_look_from = LOOK[""]
	_last_t = -1.0


func genre(t: float, pressed: Array) -> String:
	return StageMotion.genre_at(stage, t, pressed)


func beat_ms() -> float:
	return float(stage.genres.beatMs) if stage.get("genres") is Dictionary else 500.0


# Da 1 sul battito a 0 subito dopo: per far pulsare luci, teste e casse
func pulse(t: float) -> float:
	var b := beat_ms()
	return pow(1.0 - fposmod(t, b) / b, 3.0)


# Quanto manca al prossimo cambio automatico di genere (ms), se nessun disco lo copre; -1 se non arriva presto
func auto_change_in(t: float, pressed: Array) -> float:
	var g: Variant = stage.get("genres")
	if not (g is Dictionary):
		return -1.0
	var start := float(g.startMs)
	var every := float(g.everyMs)
	var next := start if t < start else start + (floorf((t - start) / every) + 1.0) * every
	var left := next - t
	if left > warn_ms:
		return -1.0
	# Se un disco suona ancora dopo il cambio, il DJ non cambia niente che si senta
	if genre(next + 1.0, pressed) != StageMotion.auto_genre(stage, next + 1.0):
		return -1.0
	return left


func _color(i: int) -> Color:
	var to: Array = LOOK.get(_genre, LOOK[""])
	return (_look_from[i] as Color).lerp(to[i], _light)


func _track(t: float, pressed: Array) -> void:
	_pressed = pressed
	var g := genre(t, pressed)
	if g != _genre:
		var now: Array = []
		for i in 4:
			now.append(_color(i))
		_look_from = now
		_light = 0.0
		_genre = g
		_changed_at = t if _last_t >= 0.0 else -INF # all'inizio della partita niente scritta
	if _last_t >= 0.0:
		_light = minf(1.0, _light + maxf(0.0, t - _last_t) / 500.0)
	else:
		_light = 1.0
	if t < _last_t: # si torna indietro (rivincita): niente scritta vecchia
		_changed_at = -INF
	_last_t = t


func draw_back(c: CanvasItem, t: float, view: Rect2, pressed: Array, _now_ms: float) -> void:
	_track(t, pressed)
	var area := view.grow(80)
	var p := pulse(t)
	# Il cielo della sera, del colore del genere
	var bands := 10
	for i in bands:
		var y0 := lerpf(area.position.y, 640.0, float(i) / bands)
		var y1 := lerpf(area.position.y, 640.0, float(i + 1) / bands) + 1.0
		c.draw_rect(Rect2(area.position.x, y0, area.size.x, y1 - y0), _color(2).lerp(_color(3), float(i) / bands))
	c.draw_rect(Rect2(area.position.x, 640.0, area.size.x, maxf(0.0, area.end.y - 640.0)), INK)
	if _genre == "reggae":
		_draw_moon(c, t)
	else:
		for k in 30: # le stelle
			var sx := fposmod(k * 397.0, 1500.0) - 110.0
			var sy := fposmod(k * 211.0, 300.0) - 160.0
			c.draw_circle(Vector2(sx, sy), 1.5, Color(1, 1, 1, 0.25 + 0.2 * sin(t / 600.0 + k)))
	_draw_city(c)
	_draw_screen(c, t, p)
	for side in [-1.0, 1.0]:
		_draw_tower(c, 640.0 + side * 560.0, t, p, side)
	_draw_beams(c, t)
	_draw_dj(c, t, p)
	if _genre == "metal":
		_draw_embers(c, t, area)


func _draw_moon(c: CanvasItem, t: float) -> void:
	var at := Vector2(1010, 110)
	for k in 4:
		c.draw_circle(at, 120.0 + k * 22.0, Color(1, 0.95, 0.7, 0.04 * _light))
	c.draw_circle(at, 100.0, Color("f6eecb", _light))
	for crater: Array in [[Vector2(-40, -30), 22.0], [Vector2(35, 20), 30.0], [Vector2(-10, 55), 14.0], [Vector2(60, -50), 12.0]]:
		c.draw_circle(at + crater[0], crater[1], Color("e2d5a6", _light))
	# Le bolle che salgono piano piano: col reggae si vola
	for k in 14:
		var bx := fposmod(k * 173.0 + 30.0 * sin(t / 1300.0 + k), 1400.0) - 60.0
		var by := 640.0 - fposmod(t * 0.03 + k * 97.0, 820.0)
		c.draw_arc(Vector2(bx, by), 7.0 + (k % 4) * 3.0, 0, TAU, 16, Color(1, 1, 1, 0.25 * _light), 1.5)


func _draw_city(c: CanvasItem) -> void:
	var col := _color(3).darkened(0.55)
	for k in 22:
		var x := -200.0 + k * 78.0
		var h := 70.0 + fposmod(k * 53.0, 140.0)
		c.draw_rect(Rect2(x, 470.0 - h, 70.0, h + 100.0), col)
		for wy in range(int(470.0 - h) + 12, 460, 22):
			if (k * 7 + wy) % 3 == 0:
				c.draw_rect(Rect2(x + 12.0, wy, 8.0, 10.0), Color(1, 0.85, 0.5, 0.25))


# Il maxischermo dietro la consolle: il nome del genere e l'equalizzatore a tempo
func _draw_screen(c: CanvasItem, t: float, p: float) -> void:
	var r := Rect2(430, 20, 420, 200)
	c.draw_rect(r.grow(10), Color("23202a"))
	c.draw_rect(r, Color("07060a"))
	var main := _color(0)
	var second := _color(1)
	var bars := 16
	for i in bars:
		var h := 12.0 + 48.0 * absf(sin(t / (180.0 + i * 23.0) + i * 1.7)) * (0.55 + 0.45 * p)
		if _genre == "":
			h = 8.0 + 10.0 * absf(sin(t / 700.0 + i))
		var x := r.position.x + 14.0 + i * (r.size.x - 28.0) / bars
		c.draw_rect(Rect2(x, r.end.y - 10.0 - h, (r.size.x - 28.0) / bars - 5.0, h), main.lerp(second, float(i) / bars))
	var text: String = NAMES.get(_genre, "")
	var size := 42
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string_outline(_font, Vector2(r.get_center().x - tw / 2.0, r.position.y + 112.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, INK)
	c.draw_string(_font, Vector2(r.get_center().x - tw / 2.0, r.position.y + 112.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE.lerp(second, 0.3))
	# Le righe dello schermo
	for y in range(int(r.position.y), int(r.end.y), 4):
		c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.25), 1.0)


# Un traliccio coi fari e la cassa appesa
func _draw_tower(c: CanvasItem, x: float, t: float, p: float, side: float) -> void:
	var top := -260.0
	var w := 46.0
	for edge in [x - w / 2.0, x + w / 2.0]:
		c.draw_line(Vector2(edge, top), Vector2(edge, 640.0), TRUSS, 4.0)
	var y := top
	var flip := false
	while y < 640.0:
		c.draw_line(Vector2(x - w / 2.0, y), Vector2(x + w / 2.0, y), TRUSS.darkened(0.2), 2.0)
		c.draw_line(Vector2(x - w / 2.0 if flip else x + w / 2.0, y), Vector2(x + w / 2.0 if flip else x - w / 2.0, y + 46.0), TRUSS.darkened(0.3), 2.0)
		flip = not flip
		y += 46.0
	# I fari in cima, che lampeggiano a tempo
	for k in 3:
		var lamp := Vector2(x - 26.0 + k * 26.0, top + 20.0)
		c.draw_circle(lamp, 9.0, Color("1d1b22"))
		c.draw_circle(lamp, 6.0, _color(k % 2).lerp(Color.WHITE, 0.4 * p))
	# La cassa appesa
	var box := Rect2(x - 40.0, 40.0, 80.0, 110.0)
	c.draw_rect(box, Color("1b1a1f"))
	c.draw_rect(box, Color("3a3842"), false, 3.0)
	for k in 2:
		var cone := Vector2(x, 72.0 + k * 50.0)
		c.draw_circle(cone, 18.0 + 3.0 * p, Color("2c2a33"))
		c.draw_circle(cone, 7.0, Color("4a4753"))


# I fasci di luce che partono dai tralicci e spazzano il palco
func _draw_beams(c: CanvasItem, t: float) -> void:
	var speed := {"": 2600.0, "metal": 700.0, "reggae": 2200.0, "techno": 420.0}.get(_genre, 1500.0) as float
	for k in 4:
		var side := -1.0 if k < 2 else 1.0
		var from := Vector2(640.0 + side * 560.0, -240.0)
		var swing := sin(t / speed + k * 1.9) * 0.55
		var dir := Vector2(-side * 0.55 + swing, 1.0).normalized()
		var tip := from + dir * 900.0
		var perp := Vector2(-dir.y, dir.x) * 90.0
		var col := _color(k % 2)
		c.draw_colored_polygon(PackedVector2Array([from - perp * 0.08, from + perp * 0.08, tip + perp, tip - perp]), Color(col, 0.07))
		c.draw_colored_polygon(PackedVector2Array([from - perp * 0.04, from + perp * 0.04, tip + perp * 0.4, tip - perp * 0.4]), Color(col, 0.07))


# Il DJ: un bonobo con le cuffie dietro la consolle, che muove la testa a tempo. Il cappello dice il genere
func _draw_dj(c: CanvasItem, t: float, p: float) -> void:
	var bob := 6.0 * p if _genre != "reggae" else 5.0 * sin(t / 600.0)
	var at := Vector2(640, 238 + bob) # la testa
	var fur := Color("3b2a22")
	c.draw_rect(Rect2(600, 250, 80, 60), fur) # le spalle
	c.draw_circle(at, 26.0, fur)
	c.draw_circle(at + Vector2(0, 6), 16.0, Color("c99a74")) # il muso
	for s in [-1.0, 1.0]:
		c.draw_circle(at + Vector2(s * 8.0, -2.0), 3.5, Color.WHITE)
		c.draw_circle(at + Vector2(s * 8.0, -1.0), 2.0, INK)
	c.draw_arc(at + Vector2(0, 10), 7.0, 0.3, PI - 0.3, 8, INK, 2.0)
	# Le cuffie
	c.draw_arc(at, 30.0, PI + 0.2, TAU - 0.2, 16, Color("222026"), 5.0)
	for s in [-1.0, 1.0]:
		c.draw_circle(at + Vector2(s * 29.0, 0), 9.0, _color(0))
	match _genre:
		"metal": # le corna con la mano alzata
			var hand := Vector2(700, 214 - 10.0 * p)
			c.draw_line(Vector2(672, 262), hand, fur, 9.0)
			c.draw_circle(hand, 9.0, Color("c99a74"))
			for s in [-1.0, 1.0]:
				c.draw_line(hand + Vector2(s * 5.0, -4), hand + Vector2(s * 8.0, -20), Color("c99a74"), 4.0)
		"reggae": # il berretto a righe
			for k in 3:
				c.draw_rect(Rect2(at.x - 26.0, at.y - 30.0 - k * 9.0, 52.0, 10.0), [Color("3fbf5a"), Color("ffd23f"), Color("e53935")][k])
		"techno": # gli occhiali da sole
			c.draw_rect(Rect2(at.x - 18.0, at.y - 7.0, 36.0, 9.0), INK)
			c.draw_line(Vector2(at.x - 18.0, at.y - 6.0), Vector2(at.x + 18.0, at.y - 6.0), _color(1), 1.5)


func _draw_embers(c: CanvasItem, t: float, area: Rect2) -> void:
	for k in 26:
		var x := fposmod(k * 151.0 + 20.0 * sin(t / 500.0 + k), 1400.0) - 60.0
		var y := 640.0 - fposmod(t * 0.12 + k * 83.0, 760.0)
		c.draw_circle(Vector2(x, y), 2.0 + (k % 3), Color(1, 0.5 + 0.1 * (k % 4), 0.1, 0.6 * _light))


# Il palco di legno col bordo di luci del genere
func draw_solid(c: CanvasItem, s: Dictionary, t: float, _pressed_now: Array) -> bool:
	var r := Rect2(float(s.x), float(s.y), float(s.width), float(s.height))
	c.draw_rect(r, WOOD)
	for k in range(1, 4):
		c.draw_line(Vector2(r.position.x, r.position.y + k * 20.0), Vector2(r.end.x, r.position.y + k * 20.0), WOOD.darkened(0.25), 2.0)
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6.0), WOOD_EDGE)
	var p := pulse(t)
	var n := int(r.size.x / 40.0)
	for k in n: # le luci sul bordo, che corrono col ritmo
		var x := r.position.x + 20.0 + k * 40.0
		var on := (k + int(t / beat_ms())) % 2 == 0
		var col := _color(k % 2)
		c.draw_circle(Vector2(x, r.position.y + 36.0), 6.0, Color(col, 0.95 if on else 0.3))
		if on:
			c.draw_circle(Vector2(x, r.position.y + 36.0), 11.0 + 4.0 * p, Color(col, 0.18))
	# I monitor a terra, sul bordo davanti
	for x: float in [r.position.x + 60.0, r.end.x - 120.0]:
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + 60, r.position.y), Vector2(x + 52, r.position.y - 26), Vector2(x + 8, r.position.y - 30)]), Color("1d1b22"))
		c.draw_circle(Vector2(x + 30, r.position.y - 14), 8.0 + 2.0 * p, Color("3a3842"))
	return true


func draw_platform(c: CanvasItem, p: Dictionary, t: float) -> bool:
	var x: float = p.x
	var y: float = p.y
	var w: float = p.width
	if p.get("genre") != null:
		_draw_neon(c, p, t)
		return true
	var pl := pulse(t)
	if y > 380.0: # le casse: un'impalcatura e sopra la cassa, che pulsa col basso
		for k in 2:
			var lx := x + 20.0 + k * (w - 40.0)
			c.draw_line(Vector2(lx, y + 40.0), Vector2(lx, 560.0), TRUSS.darkened(0.3), 4.0)
		c.draw_line(Vector2(x + 20.0, y + 40.0), Vector2(x + w - 20.0, 560.0), TRUSS.darkened(0.45), 2.0)
		c.draw_line(Vector2(x + w - 20.0, y + 40.0), Vector2(x + 20.0, 560.0), TRUSS.darkened(0.45), 2.0)
		var box := Rect2(x, y, w, 42.0)
		c.draw_rect(box, Color("1b1a1f"))
		c.draw_rect(box, Color("3a3842"), false, 2.0)
		for k in 3:
			c.draw_circle(Vector2(x + w * (0.2 + 0.3 * k), y + 22.0), 13.0 + 2.5 * pl, Color("2c2a33"))
			c.draw_circle(Vector2(x + w * (0.2 + 0.3 * k), y + 22.0), 5.0, Color("4a4753"))
	else: # la consolle del DJ: il banco coi piatti e le manopole
		var desk := Rect2(x, y, w, 46.0)
		c.draw_rect(desk, Color("2a2730"))
		c.draw_rect(Rect2(x, y, w, 5.0), Color("5b5866"))
		for k in 8:
			c.draw_circle(Vector2(x + 18.0 + k * (w - 36.0) / 7.0, y + 26.0), 3.0, _color(k % 2) if (k + int(t / 250.0)) % 3 == 0 else Color("55525e"))
	c.draw_line(Vector2(x, y), Vector2(x + w, y), _color(0).lightened(0.3), 2.0)
	return true


# Le piattaforme della techno: barre al neon. Accese quando ci sono, un contorno tratteggiato quando no
func _draw_neon(c: CanvasItem, p: Dictionary, t: float) -> void:
	var r := Rect2(float(p.x), float(p.y), float(p.width), 10.0)
	var beat := StageMotion.techno_beat(stage, t, blink_beats)
	var here := StageMotion.genre_ok(p, _genre, beat)
	var col := Color("2ee6ff") if int(p.get("beat", 0)) == 0 else Color("ff4bd8")
	if here:
		var flick := 1.0
		# Nell'ultimo battito prima dello scambio la barra sfarfalla: sta per sparire
		var cycle := beat_ms() * blink_beats
		if fposmod(t, cycle) > cycle - beat_ms():
			flick = 0.4 + 0.6 * float(int(t / 80.0) % 2)
		for k in 3:
			c.draw_rect(r.grow(4.0 + k * 5.0), Color(col, 0.08 * flick))
		c.draw_rect(r, Color(col, flick))
		c.draw_rect(Rect2(r.position.x, r.position.y + 2.0, r.size.x, 3.0), Color(1, 1, 1, 0.7 * flick))
	elif _genre == "techno":
		_dashed(c, r, Color(col, 0.35))
	else:
		_dashed(c, r, Color(col, 0.1))


func _dashed(c: CanvasItem, r: Rect2, col: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		c.draw_line(Vector2(x, r.position.y + 4.0), Vector2(minf(x + 10.0, r.end.x), r.position.y + 4.0), col, 2.0)
		x += 18.0


func draw_mover(_c: CanvasItem, _m: Dictionary, _pos: Vector2, _t: float) -> bool:
	return false


func draw_hazard(_c: CanvasItem, _h: Dictionary, _r: Rect2, _on: bool, _t: float) -> bool:
	return false


# I dischi: un vinile sul suo piedistallo, con l'etichetta del genere. Gira quando suona il suo genere
func draw_pad(c: CanvasItem, p: Dictionary, pressed_at: Variant, t: float) -> bool:
	var fx: Dictionary = p.get("effect", {})
	if fx.get("genre") == null:
		return false
	var g := str(fx.genre)
	var x: float = p.x
	var y: float = p.y
	var w: float = p.width
	var charge := StageMotion.pad_charge(p, pressed_at, t)
	var playing := _genre == g
	var center := Vector2(x + w / 2.0, y - 18.0)
	c.draw_rect(Rect2(x + 4.0, y - 8.0, w - 8.0, 8.0), Color("2a2730"))
	if charge >= 1.0 and not playing:
		c.draw_circle(center, 26.0 + 3.0 * sin(t / 200.0), Color((LOOK[g] as Array)[0], 0.25))
	c.draw_circle(center, 20.0, Color("111015"))
	for k in 3:
		c.draw_arc(center, 8.0 + k * 4.0, 0, TAU, 20, Color(1, 1, 1, 0.08), 1.0)
	c.draw_circle(center, 7.0, (LOOK[g] as Array)[0])
	var angle := t / 120.0 if playing else 0.0
	c.draw_line(center, center + Vector2(cos(angle), sin(angle)) * 7.0, Color(1, 1, 1, 0.8), 2.0)
	var label: String = {"metal": "M", "reggae": "R", "techno": "T"}.get(g, "?")
	c.draw_string(_font, center + Vector2(-5, -24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, (LOOK[g] as Array)[1])
	if charge < 1.0:
		c.draw_rect(Rect2(x, y - 3.0, w * charge, 3.0), (LOOK[g] as Array)[1])
	return true


func draw_front(c: CanvasItem, t: float, view: Rect2, pressed: Array) -> void:
	_draw_pyro(c, t)
	_draw_crowd(c, t, view)
	# Lo strobo della techno: un lampo leggero sul battito
	if _genre == "techno":
		var p := pulse(t)
		if p > 0.7:
			c.draw_rect(view, Color(1, 1, 1, 0.07 * p))
	var since := t - _changed_at
	if since >= 0.0 and since < BANNER_MS:
		var k := minf(1.0, since / 200.0)
		var alpha := minf(1.0, (BANNER_MS - since) / 400.0)
		_shout(c, view, NAMES.get(_genre, ""), int(lerpf(30.0, 76.0, k)), _color(0).lightened(0.2), t, 0.34, alpha)
		if RULES.has(_genre):
			_shout(c, view, RULES[_genre], 26, Color.WHITE, t, 0.42, alpha)
	var left := auto_change_in(t, pressed)
	if left >= 0.0:
		_shout(c, view, "IL DJ CAMBIA DISCO... %d" % int(ceilf(left / 1000.0)), 30, Color("ffd23f"), t, 0.24, 1.0)


# Le colonne di fiamme del metal (le trappole con genre "metal"): le scintille prima, poi la colonna
func _draw_pyro(c: CanvasItem, t: float) -> void:
	if _genre != "metal":
		return
	for h: Dictionary in hazards:
		if str(h.get("genre", "")) != "metal":
			continue
		var r := Rect2(float(h.x), float(h.y), float(h.width), float(h.height))
		var base := Vector2(r.get_center().x, r.end.y)
		c.draw_rect(Rect2(base.x - 16.0, base.y - 14.0, 32.0, 14.0), Color("2a2730")) # l'ugello
		var warn := HazardFx.warn_progress(h, t)
		if StageMotion.hazard_active(h, t):
			for k in 5:
				var wob := 6.0 * sin(t / 40.0 + k * 1.3)
				var top := r.position.y + k * 12.0 - 10.0 * absf(sin(t / 70.0 + k))
				var half := r.size.x / 2.0 * (1.0 - k * 0.15)
				c.draw_colored_polygon(PackedVector2Array([base + Vector2(-half, -10), base + Vector2(half, -10), Vector2(base.x + wob + half * 0.3, top), Vector2(base.x + wob - half * 0.3, top)]), [Color("ff3b1f"), Color("ff6a1f"), Color("ff9d2e"), Color("ffd23f"), Color("fff1b0")][k])
			c.draw_circle(base + Vector2(0, -r.size.y * 0.5), 70.0, Color(1, 0.4, 0.1, 0.12))
		elif warn >= 0.0:
			for k in 6:
				var a := t / 60.0 + k * 1.1
				var spark := base + Vector2(cos(a) * 10.0, -14.0 - absf(sin(a * 1.7)) * 40.0 * warn)
				c.draw_circle(spark, 2.5, Color(1, 0.8, 0.3, 0.9))


# Il pubblico davanti al palco: teste e braccia che saltano a tempo, ognuno a modo del genere
func _draw_crowd(c: CanvasItem, t: float, view: Rect2) -> void:
	var p := pulse(t)
	var base := 700.0
	for k in 34:
		var x := 150.0 + k * 30.0 + 8.0 * sin(k * 3.1)
		var phase := float(k % 3) * 0.33
		var hop := 0.0
		match _genre:
			"metal":
				hop = 14.0 * p if k % 2 == 0 else 8.0 * (1.0 - p)
			"reggae":
				hop = 4.0 * sin(t / 500.0 + k)
			"techno":
				hop = 10.0 * pow(1.0 - fposmod(t / beat_ms() + phase, 1.0), 2.0)
			_:
				hop = 2.0 * sin(t / 900.0 + k)
		var head := Vector2(x, base - 34.0 - hop - (k % 4) * 3.0)
		var col := Color("0b090e").lerp(_color(k % 2), 0.12)
		c.draw_rect(Rect2(x - 13.0, head.y + 10.0, 26.0, 60.0), col)
		c.draw_circle(head, 12.0, col)
		if k % 3 == 0: # le braccia alzate, con il telefono acceso qua e là
			var sway := 10.0 * sin(t / (beat_ms() * 2.0) + k) if _genre != "techno" else 0.0
			var hand := head + Vector2(10.0 + sway, -38.0 - hop * 0.5)
			c.draw_line(head + Vector2(8, 12), hand, col, 6.0)
			if k % 6 == 0:
				c.draw_rect(Rect2(hand.x - 4.0, hand.y - 9.0, 8.0, 12.0), Color(0.85, 0.95, 1.0, 0.85))


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


func on_event(_e: Dictionary, _now_ms: float) -> void:
	pass


# Il cambio automatico di genere (i dischi suonano già col loro bottone), l'avviso del DJ e le fiamme che partono
func cues(before: float, now: float, pressed: Array) -> Array:
	var out: Array = []
	var g0 := genre(before, pressed)
	var g1 := genre(now, pressed)
	if g0 != g1 and g1 != "":
		var by_pad := false
		for i in mini(pads.size(), pressed.size()):
			if pressed[i] != null and float(pressed[i]) > before and float(pressed[i]) <= now:
				by_pad = true
		if not by_pad:
			out.append(["pad_" + g1, 640.0])
	if auto_change_in(before, pressed) < 0.0 and auto_change_in(now, pressed) >= 0.0:
		out.append(["airhorn", 640.0])
	if g1 == "metal":
		for h: Dictionary in hazards:
			if str(h.get("genre", "")) == "metal" and not StageMotion.hazard_active(h, before) and StageMotion.hazard_active(h, now):
				out.append(["pyro", float(h.x)])
	return out
