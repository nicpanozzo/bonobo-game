# Suprema "storm" (#547), Tempesta! di Capt. OrsoBlu: l'arena rolla come una nave, piove di traverso, lui sta al
# timone (disegnato qui, provvisorio finché non c'è la clip) e insulta tutti a nuvolette. Solo disegno: si parte
# dall'evento attack con kind "supreme" e si seguono i tempi in game.json, come il rollio di stormRoll in supreme.ts.
extends Node2D

const SHOUT_MS := 800.0 # quanto resta il nome gridato
const TILT_DEG := 3.0 # quanto si inclina l'arena nel punto più forte del rollio (world_view la gira)
const INSULT_MS := 1200.0 # una nuvoletta ogni tanto
const WOOD := Color(0.55, 0.35, 0.17)
const WOOD_DARK := Color(0.3, 0.18, 0.08)
const RAIN := Color(0.75, 0.85, 1.0, 0.45)
const SEA := Color(0.2, 0.45, 0.75)
const FOAM := Color(0.9, 0.96, 1.0)
const DECK_PX := 1300.0 # metà del ponte disegnato con l'acqua, intorno a lui
const WAVE_WARN_MS := 450.0 # l'onda si gonfia per tanto prima di colpire: si vede arrivare
const WAVE_GONE_MS := 500.0 # dopo il colpo si ritira in tanto
const SURGE_RISE_MS := 1000.0 # il maroso finale si alza alle sue spalle per tanto prima di rovesciarsi
const SURGE_CRASH_MS := 600.0 # e si rovescia su tutto il ponte in tanto

var where: Callable # id giocatore -> Vector2 dei piedi, o null; lo imposta world_view
var facing: Callable # id giocatore -> 1 o -1, dove guarda: il maroso finale va da quella parte; lo imposta world_view
var fighter_height := 96.0 # da game.fighter, lo imposta world_view
var fixed_now := -1.0 # per i test: se >= 0 è l'orologio in ms al posto di quello vero
var _runs: Array = [] # [{ id, sp, t0 }]
var _font: Font = ThemeDB.fallback_font


func _now() -> float:
	return fixed_now if fixed_now >= 0 else float(Time.get_ticks_msec())


static func total_ms(sp: Dictionary) -> float:
	return float(sp.windupMs) + float(sp.durationMs)


# Il rollio a ms dall'inizio della suprema: 0 mentre afferra il timone, poi da -1 a 1 (stormRoll in supreme.ts)
static func roll(sp: Dictionary, ms: float) -> float:
	var t := ms - float(sp.windupMs)
	if t < 0.0 or t > float(sp.durationMs):
		return 0.0
	return sin(TAU * t / float(sp.rollPeriodMs))


func start(id: String, character: Dictionary) -> void:
	var sp: Variant = character.get("supreme")
	if not (sp is Dictionary) or str(sp.get("type", "")) != "storm":
		return
	_runs = _runs.filter(func(r): return r.id != id)
	_runs.append({"id": id, "sp": sp, "t0": _now()})


func clear() -> void:
	_runs = []


# C'è una tempesta in corso (dalla presa del timone alla fine del rollio)
func active() -> bool:
	var now := _now()
	for r in _runs:
		if now - float(r.t0) < total_ms(r.sp):
			return true
	return false


# Di quanti radianti inclinare l'arena adesso (0 senza tempesta)
func tilt() -> float:
	var now := _now()
	var out := 0.0
	for r in _runs:
		out += roll(r.sp, now - float(r.t0)) * deg_to_rad(TILT_DEG)
	return out


# La nuvoletta che dice adesso, "" se nessuna
static func insult(sp: Dictionary, ms: float) -> String:
	var list: Array = sp.get("insults", [])
	var t := ms - float(sp.windupMs)
	if list.is_empty() or t < 0.0 or t > float(sp.durationMs):
		return ""
	return str(list[int(t / INSULT_MS) % list.size()])


func _process(_delta: float) -> void:
	if _runs.is_empty():
		return
	var now := _now()
	_runs = _runs.filter(func(r): return now - float(r.t0) < total_ms(r.sp) + SURGE_CRASH_MS)
	queue_redraw()


func _draw() -> void:
	var now := _now()
	for r in _runs:
		var feet: Variant = where.call(r.id) if where.is_valid() else null
		if feet != null:
			_draw_waves(r.sp, now - float(r.t0), feet)
			_draw_storm(r.sp, now - float(r.t0), feet)
			if r.sp.get("finisher") is Dictionary:
				var dir := int(facing.call(r.id)) if facing.is_valid() else 1
				_draw_surge(now - float(r.t0) - total_ms(r.sp), feet, dir)


# Le onde della Tempesta (stormWave in supreme.ts): una a ogni fine rollio, verso dove pende la nave.
# Restituisce [ms dall'inizio della suprema, verso] per ognuna
static func wave_times(sp: Dictionary) -> Array:
	var out: Array = []
	var period := float(sp.rollPeriodMs)
	var t := period / 4.0
	while t <= float(sp.durationMs):
		out.append([float(sp.windupMs) + t, 1 if sin(TAU * t / period) > 0.0 else -1])
		t += period / 2.0
	return out


# Una fascia d'acqua lungo il ponte, da x0 a x1, alta h sopra y: il pelo dell'acqua ondeggia e scorre verso dir.
# Sopra, la cresta di schiuma con i riccioli
func _draw_water(x0: float, x1: float, y: float, h: float, dir: int, ms: float, a: float) -> void:
	if h < 3.0 or a <= 0.0 or x1 - x0 < 20.0: # troppo piccola: il poligono si triangolerebbe male
		return
	var top := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps)
		var bob := sin((x * dir) / 90.0 - ms / 140.0) * 0.18 + sin((x * dir) / 37.0 - ms / 90.0) * 0.06
		top.append(Vector2(x, y - h * (1.0 + bob)))
	var body := top.duplicate()
	body.append(Vector2(x1, y + 26.0))
	body.append(Vector2(x0, y + 26.0))
	draw_colored_polygon(body, Color(SEA, 0.55 * a))
	draw_polyline(top, Color(SEA.darkened(0.35), 0.8 * a), 4.0, true)
	draw_polyline(top, Color(FOAM, 0.85 * a), 2.0, true)
	for i in range(2, steps - 1, 4): # riccioli di schiuma che si rompono verso dir
		var p: Vector2 = top[i]
		draw_arc(p + Vector2(dir * 7.0, 6.0), 8.0, PI if dir > 0 else 0.0, PI * 1.6 if dir > 0 else -PI * 0.6, 6, Color(FOAM, 0.9 * a), 3.0, true)


# Le onde normali: si gonfiano per WAVE_WARN_MS (si vede da che parte arrivano), corrono sul ponte verso dir
# quando colpiscono (il server, solo chi è a terra) e si ritirano in WAVE_GONE_MS
func _draw_waves(sp: Dictionary, ms: float, feet: Vector2) -> void:
	for w in wave_times(sp):
		var s: float = ms - float(w[0])
		if s < -WAVE_WARN_MS or s > WAVE_GONE_MS:
			continue
		var dir: int = w[1]
		var h: float
		var a := 1.0
		if s < 0.0:
			h = lerpf(6.0, 34.0, 1.0 - (-s / WAVE_WARN_MS))
		else:
			var k := s / WAVE_GONE_MS
			h = lerpf(34.0, 4.0, k)
			a = 1.0 - k * k
		# l'acqua entra dal bordo da cui viene e scorre: prima del colpo arriva a metà ponte, dopo lo copre tutto
		var reach := clampf((s + WAVE_WARN_MS) / (WAVE_WARN_MS + 200.0), 0.0, 1.0)
		var start := feet.x - dir * DECK_PX
		var front := start + dir * DECK_PX * 2.0 * reach
		_draw_water(minf(start, front), maxf(start, front), feet.y, h, dir, ms, a)


# Il maroso finale: un muro d'acqua che si alza dal bordo alle sue spalle per SURGE_RISE_MS, poi alla fine della
# tempesta (quando il server colpisce tutti) si rovescia su tutto il ponte verso dove guarda lui
func _draw_surge(t: float, feet: Vector2, dir: int) -> void:
	if t < -SURGE_RISE_MS or t > SURGE_CRASH_MS:
		return
	var back := feet.x - dir * DECK_PX
	if t < 0.0:
		var k := 1.0 - (-t / SURGE_RISE_MS) # 0 -> 1 mentre sale
		var wide := 180.0 + 220.0 * k
		_draw_water(minf(back, back + dir * wide), maxf(back, back + dir * wide), feet.y, fighter_height * 2.6 * k * k + 6.0, dir, t, 0.9)
		return
	var c := t / SURGE_CRASH_MS # 0 -> 1 mentre si rovescia
	var front := back + dir * (400.0 + DECK_PX * 2.0 * c)
	var h := fighter_height * 2.6 * (1.0 - c) + 10.0
	_draw_water(minf(back, front), maxf(back, front), feet.y, h, dir, t, 1.0 - c * c)
	# la schiuma che si rompe in testa
	for i in 6:
		var p := Vector2(front - dir * i * 26.0, feet.y - h * (1.0 - i * 0.12))
		draw_circle(p, 10.0 - i, Color(FOAM, 0.8 * (1.0 - c)))


func _draw_storm(sp: Dictionary, ms: float, feet: Vector2) -> void:
	var end := total_ms(sp)
	var alpha := clampf(minf(ms, end + 200.0 - ms) / 200.0, 0.0, 1.0)
	var k := roll(sp, ms)
	# Pioggia di traverso, che segue il rollio: righe fisse nel mondo intorno a lui
	if ms > float(sp.windupMs):
		var rain := Color(RAIN, RAIN.a * alpha)
		var slant := Vector2(-60.0 - 50.0 * k, 160.0)
		for i in 90:
			var x := feet.x - 1400.0 + fmod(i * 157.0 + ms * 0.9, 2800.0)
			var y := feet.y - 900.0 + fmod(i * 263.0 + ms * 1.6, 1300.0)
			draw_line(Vector2(x, y), Vector2(x, y) + slant * 0.25, rain, 2.0)
	# Il timone davanti a lui, all'altezza della pancia: gira col rollio
	var c := feet - Vector2(0, fighter_height * 0.45)
	var r := fighter_height * 0.32
	var turn := k * 1.2
	var wood := Color(WOOD, alpha)
	var dark := Color(WOOD_DARK, alpha)
	for i in 8:
		var d := Vector2.from_angle(turn + i * TAU / 8.0)
		draw_line(c, c + d * (r + 9.0), dark, 5.0)
		draw_circle(c + d * (r + 10.0), 4.0, wood)
	draw_arc(c, r, 0, TAU, 32, dark, 8.0)
	draw_arc(c, r, 0, TAU, 32, wood, 5.0)
	draw_circle(c, 6.0, dark)
	# Il nome gridato all'inizio, poi gli insulti a nuvoletta
	var px := Access.px(22)
	if ms < SHOUT_MS:
		var s := ms / SHOUT_MS
		var text := "%s!" % str(sp.name)
		var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(28))
		var at := Vector2(feet.x - size.x / 2, feet.y - fighter_height - 50.0 - 20.0 * s)
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(28), 6, Color(0, 0, 0, 0.7 * (1.0 - s * s)))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(28), Color(0.85, 0.92, 1.0, 1.0 - s * s))
		return
	var line := insult(sp, ms)
	if line == "":
		return
	var size2 := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var box := Rect2(feet.x - size2.x / 2 - 12.0, feet.y - fighter_height - 70.0, size2.x + 24.0, size2.y + 14.0)
	var paper := Color(1, 1, 1, 0.95 * alpha)
	var ink := Color(0, 0, 0, alpha)
	draw_rect(box, paper)
	draw_rect(box, ink, false, 2.0)
	var tail := PackedVector2Array([Vector2(feet.x - 8.0, box.end.y), Vector2(feet.x + 8.0, box.end.y), Vector2(feet.x + 2.0, box.end.y + 14.0)])
	draw_colored_polygon(tail, paper)
	draw_string(_font, Vector2(box.position.x + 12.0, box.end.y - 10.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
