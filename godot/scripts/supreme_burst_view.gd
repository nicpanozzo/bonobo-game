# Suprema "burst" (#358), IRA di Lendmar: mentre si arrabbia e tira le raffiche, una vampata rossa che pulsa
# intorno a lui e il nome della mossa gridato sopra. Solo disegno: i proiettili li disegna già world_view come quelli
# della sua speciale neutra; qui si parte dall'evento attack con kind "supreme" e si seguono i tempi in game.json.
extends Node2D

const SHOUT_MS := 800.0 # quanto resta il nome gridato
const PULSE_MS := 130.0 # un battito della vampata
const RAGE := Color(0.9, 0.12, 0.08)

var where: Callable # id giocatore -> Vector2 dei piedi, o null; lo imposta world_view
var fighter_height := 96.0 # da game.fighter, lo imposta world_view
var fixed_now := -1.0 # per i test: se >= 0 è l'orologio in ms al posto di quello vero
var _runs: Array = [] # [{ id, sp, t0 }]
var _font: Font = ThemeDB.fallback_font


func _now() -> float:
	return fixed_now if fixed_now >= 0 else float(Time.get_ticks_msec())


static func total_ms(sp: Dictionary) -> float:
	return float(sp.windupMs) + float(sp.waves) * float(sp.waveEveryMs)


func start(id: String, character: Dictionary) -> void:
	var sp: Variant = character.get("supreme")
	if not (sp is Dictionary) or str(sp.get("type", "")) != "burst":
		return
	_runs = _runs.filter(func(r): return r.id != id)
	_runs.append({"id": id, "sp": sp, "t0": _now()})


func clear() -> void:
	_runs = []


# È arrabbiato adesso: dalla carica all'ultima raffica
func raging(id: String) -> bool:
	for r in _runs:
		if r.id == id and _now() - float(r.t0) < total_ms(r.sp):
			return true
	return false


func _process(_delta: float) -> void:
	if _runs.is_empty():
		return
	var now := _now()
	_runs = _runs.filter(func(r): return now - float(r.t0) < total_ms(r.sp) + 200.0)
	queue_redraw()


func _draw() -> void:
	var now := _now()
	for r in _runs:
		var feet: Variant = where.call(r.id) if where.is_valid() else null
		if feet != null:
			_draw_rage(r.sp, now - float(r.t0), feet)


func _draw_rage(sp: Dictionary, ms: float, feet: Vector2) -> void:
	var end := total_ms(sp)
	var alpha := clampf(minf(ms, end + 200.0 - ms) / 150.0, 0.0, 1.0)
	var c := feet - Vector2(0, fighter_height * 0.5)
	var beat := 0.5 + 0.5 * sin(ms / PULSE_MS * TAU)
	for i in 3:
		var r := fighter_height * (0.55 + 0.12 * i + 0.06 * beat)
		draw_circle(c, r, Color(RAGE, (0.16 - 0.04 * i) * alpha))
	if ms < SHOUT_MS:
		var k := ms / SHOUT_MS
		var px := Access.px(28)
		var text := "%s!" % str(sp.name)
		var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var at := Vector2(c.x - size.x / 2 + sin(ms / 30.0) * 3.0, feet.y - fighter_height - 50.0 - 20.0 * k) # trema dalla rabbia
		var a := 1.0 - k * k
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color(0, 0, 0, 0.7 * a))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 0.3, 0.2, a))
