# Suprema "spin" (#358), DEMACIAAA di Bradipo Giallo: mentre gira, vortici intorno a lui che seguono dove va e il
# nome della mossa gridato sopra. Solo disegno: parte dall'evento attack con kind "supreme" e segue i tempi del
# personaggio in game.json (characters.<id>.supreme). I colpi veri li decide il server.
extends Node2D

const ARCS := 3 # vortici intorno
const TURN_MS := 260.0 # un giro dei vortici
const SHOUT_MS := 700.0 # quanto resta il nome gridato, dall'inizio del giro
const WIND := Color(1, 0.95, 0.7)
const WIND_SH := Color(0.95, 0.75, 0.25)

var where: Callable # id giocatore -> Vector2 dei piedi, o null; lo imposta world_view
var fixed_now := -1.0 # per i test: se >= 0 è l'orologio in ms al posto di quello vero
var _runs: Array = [] # [{ id, sp, t0 }]
var _font: Font = ThemeDB.fallback_font


func _now() -> float:
	return fixed_now if fixed_now >= 0 else float(Time.get_ticks_msec())


func start(id: String, character: Dictionary) -> void:
	var sp: Variant = character.get("supreme")
	if not (sp is Dictionary) or str(sp.get("type", "")) != "spin":
		return
	_runs = _runs.filter(func(r): return r.id != id)
	_runs.append({"id": id, "sp": sp, "t0": _now()})


func clear() -> void:
	_runs = []


# Sta girando adesso (dopo la carica e prima della fine)
func spinning(id: String) -> bool:
	for r in _runs:
		var ms := _now() - float(r.t0)
		if r.id == id and ms >= float(r.sp.windupMs) and ms < float(r.sp.windupMs) + float(r.sp.durationMs):
			return true
	return false


func _process(_delta: float) -> void:
	if _runs.is_empty():
		return
	var now := _now()
	_runs = _runs.filter(func(r): return now - float(r.t0) < float(r.sp.windupMs) + float(r.sp.durationMs) + 200.0)
	queue_redraw()


func _draw() -> void:
	var now := _now()
	for r in _runs:
		var feet: Variant = where.call(r.id) if where.is_valid() else null
		if feet == null:
			continue
		_draw_spin(r.sp, now - float(r.t0), feet)


func _draw_spin(sp: Dictionary, ms: float, feet: Vector2) -> void:
	var spin_ms := ms - float(sp.windupMs)
	var dur := float(sp.durationMs)
	if spin_ms < 0:
		return
	# compare e sparisce in fretta, in mezzo è pieno
	var alpha := clampf(minf(spin_ms, dur + 200.0 - spin_ms) / 150.0, 0.0, 1.0)
	var r := Vector2(float(sp.width) / 2.0, float(sp.height) * 0.42)
	var c := feet - Vector2(0, float(sp.height) * 0.45)
	var turn := spin_ms / TURN_MS * TAU
	for i in ARCS:
		var a0 := turn + TAU * i / ARCS
		var pts := PackedVector2Array()
		for k in 9:
			var a := a0 + k * 0.16
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_polyline(pts, Color(WIND_SH, 0.8 * alpha), 9.0, true)
		draw_polyline(pts, Color(WIND, 0.9 * alpha), 4.0, true)
	if spin_ms < SHOUT_MS:
		var k := spin_ms / SHOUT_MS
		var px := Access.px(26)
		var text := "%s!" % str(sp.name)
		var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var at := Vector2(c.x - size.x / 2, c.y - r.y - 40.0 - 20.0 * k)
		var a := 1.0 - k * k
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color(0, 0, 0, 0.7 * a))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 0.85, 0.2, a))
