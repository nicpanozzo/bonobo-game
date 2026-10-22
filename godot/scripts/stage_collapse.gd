# Una torre che crolla (#433), solo grafica: la descrizione è `art.collapse` dell'arena (StageCollapse in stages.ts).
# Tutto si ricalcola dal tempo dell'arena (stageMs), senza stato: la sagoma ruota attorno al suo piede con partenza
# lenta e arrivo veloce, e polvere, mattoni e scossa sono funzioni di t. Prima della caduta, nell'avviso, ci sono
# crepe e un leggero tremito. I pezzi veri della torre li toglie `on` nell'arena: qui si disegna solo la caduta.
extends RefCounted

const WARN_MS := 6000.0 # avviso prima della caduta, se la descrizione non dice warnMs
const WOBBLE_DEG := 0.7 # ampiezza massima del tremito nell'avviso, gradi
const BRICK := Color("a24d38") # il rosso dei mattoni di Bologna
const BRICK_DARK := Color("7a3a2b")
const INK := Color("24161a") # il contorno scuro, come negli altri disegni dell'arena
const DUST := Color(0.8, 0.72, 0.62)
const COURSE_PX := 48.0 # distanza tra due file di mattoni
const TAPER := 0.18 # quanto si stringe la cima per lato, in frazione della larghezza
const DUST_TAIL_MS := 2400.0 # la polvere dell'impatto resta in aria per tanto, dopo la fine della caduta
const FADE_MS := 500.0 # a caduta finita la sagoma sfuma: lì sotto appare la rampa vera
const SHAKE_FALL := 5.0 # scossa a fine caduta (parte da 1,5 e sale col quadrato del tempo)
const SHAKE_IMPACT := 14.0 # scossa all'impatto
const SHAKE_IMPACT_MS := 600.0 # per quanto dura la scossa dell'impatto
const GRAVITY := 900.0 # pixel/s² dei mattoni che volano
const CRACKS := [ # crepe nel sistema locale (piede = 0,0; la torre va verso l'alto e a sinistra), in frazione di [larghezza, altezza]
	[Vector2(-0.3, -0.12), Vector2(-0.4, -0.18), Vector2(-0.33, -0.25), Vector2(-0.45, -0.31)],
	[Vector2(-0.7, -0.3), Vector2(-0.6, -0.37), Vector2(-0.68, -0.43)],
	[Vector2(-0.45, -0.52), Vector2(-0.55, -0.58), Vector2(-0.4, -0.64), Vector2(-0.5, -0.7)],
	[Vector2(-0.2, -0.45), Vector2(-0.3, -0.5), Vector2(-0.22, -0.57)],
	[Vector2(-0.65, -0.72), Vector2(-0.55, -0.78), Vector2(-0.62, -0.84)],
	[Vector2(-0.35, -0.86), Vector2(-0.45, -0.9), Vector2(-0.38, -0.95)],
]


# La descrizione del crollo dell'arena, o {} se non ne ha
static func config(stage: Dictionary) -> Dictionary:
	var art: Variant = stage.get("art")
	if art is Dictionary and art.get("collapse") is Dictionary:
		return art.collapse
	return {}


static func end_ms(c: Dictionary) -> float:
	return float(c.atMs) + float(c.durationMs)


# "idle" (lontano), "warn" (crepe e tremito), "fall" (cade), "after" (a terra, polvere e sfumo)
static func phase(c: Dictionary, t: float) -> String:
	if t < float(c.atMs) - float(c.get("warnMs", WARN_MS)):
		return "idle"
	if t < float(c.atMs):
		return "warn"
	if t < end_ms(c):
		return "fall"
	return "after" if t < end_ms(c) + DUST_TAIL_MS else "idle"


# Quanto è avanti l'avviso (0 a inizio, 1 quando comincia la caduta); -1 fuori dall'avviso
static func warn_k(c: Dictionary, t: float) -> float:
	var warn := float(c.get("warnMs", WARN_MS))
	var at := float(c.atMs)
	if t < at - warn or t >= at or warn <= 0.0:
		return -1.0
	return (t - (at - warn)) / warn


# L'angolo della torre in gradi (positivo = verso destra). Nell'avviso un tremito piccolo che parte e finisce a zero;
# nella caduta cresce con il quadrato del tempo (partenza lenta, arrivo veloce); dopo è fermo a toDeg
static func angle_deg(c: Dictionary, t: float) -> float:
	var k := warn_k(c, t)
	if k >= 0.0:
		return WOBBLE_DEG * sin(PI * k) * sin(t / 85.0)
	if t < float(c.atMs):
		return 0.0
	var dur := maxf(1.0, float(c.durationMs))
	var u := clampf((t - float(c.atMs)) / dur, 0.0, 1.0)
	return float(c.toDeg) * u * u


# La cima della torre (il centro del suo bordo alto) all'istante t
static func tip(c: Dictionary, t: float) -> Vector2:
	var pivot := Vector2(c.pivot.x, c.pivot.y)
	return pivot + Vector2(-float(c.width) * 0.5, -float(c.height)).rotated(deg_to_rad(angle_deg(c, t)))


# La scossa di telecamera chiesta all'istante t (0 se nessuna)
static func shake(c: Dictionary, t: float) -> float:
	match phase(c, t):
		"fall":
			var u := (t - float(c.atMs)) / maxf(1.0, float(c.durationMs))
			return 1.5 + (SHAKE_FALL - 1.5) * u * u
		"after":
			var age := t - end_ms(c)
			return SHAKE_IMPACT * (1.0 - age / SHAKE_IMPACT_MS) if age < SHAKE_IMPACT_MS else 0.0
	return 0.0


# Un numero pseudocasuale fisso da 0 a 1 per (i, k): le particelle sono funzioni del tempo, senza stato
static func _h(i: int, k: int) -> float:
	return fposmod(sin(float(i * 127 + k * 311) + 0.5) * 43758.5453, 1.0)


# Disegna la caduta all'istante t sul CanvasItem ci; view è la parte di mondo visibile. Restituisce la scossa da dare
static func draw(ci: CanvasItem, c: Dictionary, t: float, view: Rect2) -> float:
	var ph := phase(c, t)
	if ph == "idle":
		return 0.0
	var pivot := Vector2(c.pivot.x, c.pivot.y)
	var reach := float(c.height) + float(c.width)
	if not view.intersects(Rect2(pivot - Vector2(reach, reach), Vector2(reach, reach) * 2.0)):
		return shake(c, t)
	var alpha := 1.0
	var wk := warn_k(c, t)
	if ph == "warn":
		alpha = 0.35 * wk # nell'avviso la sagoma prende corpo piano piano, dietro ai pezzi veri
	elif ph == "after":
		alpha = clampf(1.0 - (t - end_ms(c)) / FADE_MS, 0.0, 1.0)
	if alpha > 0.0:
		_draw_tower(ci, c, t, ph, wk, alpha)
	if ph == "warn":
		_draw_grit(ci, c, t, wk)
	else:
		_draw_dust_and_bricks(ci, c, t)
	return shake(c, t)


static func _draw_tower(ci: CanvasItem, c: Dictionary, t: float, ph: String, wk: float, alpha: float) -> void:
	var w := float(c.width)
	var h := float(c.height)
	ci.draw_set_transform(Vector2(c.pivot.x, c.pivot.y), deg_to_rad(angle_deg(c, t)))
	var body := PackedVector2Array([
		Vector2(-w, 0), Vector2(0, 0), Vector2(-w * TAPER, -h * 0.94), Vector2(-w * 0.5, -h), Vector2(-w * (1.0 - TAPER), -h * 0.94),
	])
	ci.draw_colored_polygon(body, Color(BRICK.r, BRICK.g, BRICK.b, alpha))
	# Le file di mattoni, strette verso la cima come i fianchi
	var courses := int(h * 0.94 / COURSE_PX)
	for i in range(1, courses + 1):
		var y := -i * COURSE_PX
		var f := -y / (h * 0.94)
		ci.draw_line(Vector2(-w + w * TAPER * f, y), Vector2(-w * TAPER * f, y), Color(BRICK_DARK.r, BRICK_DARK.g, BRICK_DARK.b, alpha), 3.0)
	# Quattro finestre scure
	for i in 4:
		var wy := -h * (0.18 + 0.2 * i)
		ci.draw_rect(Rect2(-w * 0.58, wy, w * 0.16, 34.0), Color(INK.r, INK.g, INK.b, alpha * 0.85))
	var outline := PackedVector2Array(body)
	outline.append(body[0])
	ci.draw_polyline(outline, Color(INK.r, INK.g, INK.b, minf(1.0, alpha * 2.0)), 5.0)
	# Crepe: una in più a ogni sesto dell'avviso, tutte durante la caduta
	var shown := CRACKS.size() if ph != "warn" else int(ceil(wk * CRACKS.size()))
	for i in shown:
		var pts := PackedVector2Array()
		for p: Vector2 in CRACKS[i]:
			pts.append(Vector2(p.x * w, p.y * h))
		ci.draw_polyline(pts, Color(INK.r, INK.g, INK.b, minf(1.0, alpha * 2.5)), 3.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Nell'avviso: briciole che cadono dalla torre, sempre di più
static func _draw_grit(ci: CanvasItem, c: Dictionary, t: float, wk: float) -> void:
	var pivot := Vector2(c.pivot.x, c.pivot.y)
	var w := float(c.width)
	var h := float(c.height)
	for i in 8:
		var p := fposmod(t / 800.0 + _h(i, 1), 1.0)
		var pos := pivot + Vector2(-w * (0.15 + 0.7 * _h(i, 2)), -h * (0.25 + 0.65 * _h(i, 3)) + p * 150.0)
		ci.draw_rect(Rect2(pos, Vector2(5, 5)), Color(BRICK.r, BRICK.g, BRICK.b, (1.0 - p) * wk))


static func _puff(ci: CanvasItem, pos: Vector2, u: float, radius: float, strength: float) -> void:
	ci.draw_circle(pos, radius * (0.5 + 0.5 * u), Color(DUST.r, DUST.g, DUST.b, strength * (1.0 - u)))


# Polvere alla base durante la caduta e all'impatto, mattoni che si staccano e che schizzano via
static func _draw_dust_and_bricks(ci: CanvasItem, c: Dictionary, t: float) -> void:
	var at := float(c.atMs)
	var dur := float(c.durationMs)
	var end := end_ms(c)
	var pivot := Vector2(c.pivot.x, c.pivot.y)
	var w := float(c.width)
	var h := float(c.height)
	# Alla base: uno sbuffo ogni decimo della caduta, che si allarga ai lati
	for i in 8:
		var age := t - (at + dur * 0.1 * i)
		if age < 0.0 or age > 1600.0:
			continue
		var u := age / 1600.0
		var side := 1.0 if i % 2 == 0 else -1.0
		_puff(ci, pivot + Vector2(-w * 0.5 + (_h(i, 4) - 0.5) * w + side * u * 110.0, -12.0 - u * 50.0), u, 90.0, 0.5)
	# All'impatto: sulla cima che si appoggia e al piede, in raffica
	var tip_end := tip(c, end)
	for i in 12:
		var age := t - (end + (i % 3) * 70.0)
		if age < 0.0 or age > DUST_TAIL_MS:
			continue
		var u := age / DUST_TAIL_MS
		var dir := Vector2.from_angle(TAU * _h(i, 5))
		var origin := tip_end if i % 3 != 0 else pivot + Vector2(-w * 0.5, 0.0)
		_puff(ci, origin + dir * (30.0 + 160.0 * u * _h(i, 6)), u, 60.0 + 90.0 * _h(i, 7), 0.55)
	# Mattoni che si staccano durante la caduta e ricadono
	for i in 6:
		var born := at + dur * (0.25 + 0.12 * i)
		var age := (t - born) / 1000.0
		if age < 0.0 or age > 1.4:
			continue
		var local := Vector2(-w * (0.2 + 0.6 * _h(i, 8)), -h * (0.2 + 0.75 * _h(i, 9)))
		var p0 := pivot + local.rotated(deg_to_rad(angle_deg(c, born)))
		_brick(ci, p0 + Vector2((_h(i, 10) - 0.5) * 160.0 * age, 0.5 * GRAVITY * age * age), age * 6.0 * (_h(i, 11) - 0.5) * 2.0, 1.0 - age / 1.4)
	# Mattoni che schizzano via all'impatto
	for i in 16:
		var age := (t - end) / 1000.0
		if age < 0.0 or age > 1.8:
			continue
		var v := Vector2.from_angle(deg_to_rad(-160.0 + 140.0 * _h(i, 12))) * (250.0 + 400.0 * _h(i, 13))
		_brick(ci, tip_end + v * age + Vector2(0.0, 0.5 * GRAVITY * age * age), age * 8.0 * (_h(i, 14) - 0.5), 1.0 - age / 1.8)


static func _brick(ci: CanvasItem, pos: Vector2, spin: float, a: float) -> void:
	ci.draw_set_transform(pos, spin)
	ci.draw_rect(Rect2(-11, -6, 22, 12), Color(BRICK.r, BRICK.g, BRICK.b, a))
	ci.draw_rect(Rect2(-11, -6, 22, 12), Color(INK.r, INK.g, INK.b, a), false, 2.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
