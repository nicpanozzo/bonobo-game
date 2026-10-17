# Suprema "grab" (#358), snaack di Lampione: il braccio che si allunga davanti fino a dove afferra, la mano aperta
# in fondo e il nome della mossa gridato sopra. Solo disegno: parte dall'evento attack con kind "supreme" e segue i
# tempi del personaggio in game.json (characters.<id>.supreme). Chi viene preso e dove vola lo decide il server.
extends Node2D

const SHOUT_MS := 700.0 # quanto resta il nome gridato
const ARM_W := 14.0 # spessore del braccio, pixel
const INK := Color("221c1a")
const SKIN := Color("e9c39b")

var where: Callable # id giocatore -> il suo campione (x, y dei piedi, facing), o null; lo imposta world_view
var fighter_width := 48.0 # da game.fighter, li imposta world_view
var fighter_height := 96.0
var fixed_now := -1.0 # per i test: se >= 0 è l'orologio in ms al posto di quello vero
var _runs: Array = [] # [{ id, sp, t0 }]
var _font: Font = ThemeDB.fallback_font


func _now() -> float:
	return fixed_now if fixed_now >= 0 else float(Time.get_ticks_msec())


func start(id: String, character: Dictionary) -> void:
	var sp: Variant = character.get("supreme")
	if not (sp is Dictionary) or str(sp.get("type", "")) != "grab":
		return
	_runs = _runs.filter(func(r): return r.id != id)
	_runs.append({"id": id, "sp": sp, "t0": _now()})


func clear() -> void:
	_runs = []


# Quanto è lungo il braccio ms dopo l'inizio, in pixel: cresce, resta tutto allungato mentre afferra, torna
static func arm_length(sp: Dictionary, ms: float) -> float:
	var windup := float(sp.windupMs)
	var reach := float(sp.reach)
	if ms < 0:
		return 0.0
	if ms < windup:
		var k := ms / windup
		return reach * (1.0 - (1.0 - k) * (1.0 - k))
	ms -= windup
	if ms < float(sp.reachMs):
		return reach
	ms -= float(sp.reachMs)
	return reach * maxf(0.0, 1.0 - ms / float(sp.endLagMs))


func reaching(id: String) -> float:
	for r in _runs:
		if r.id == id:
			return arm_length(r.sp, _now() - float(r.t0))
	return 0.0


func _process(_delta: float) -> void:
	if _runs.is_empty():
		return
	var now := _now()
	_runs = _runs.filter(func(r): return now - float(r.t0) < float(r.sp.windupMs) + float(r.sp.reachMs) + float(r.sp.endLagMs))
	queue_redraw()


func _draw() -> void:
	var now := _now()
	for r in _runs:
		var p: Variant = where.call(r.id) if where.is_valid() else null
		if p == null:
			continue
		_draw_arm(r.sp, now - float(r.t0), p)


func _draw_arm(sp: Dictionary, ms: float, p: Dictionary) -> void:
	var facing := float(p.get("facing", 1))
	var hand_y := float(p.y) - fighter_height * 0.7 + float(sp.height) / 2.0 # a metà del rettangolo della presa
	var from := Vector2(float(p.x) + facing * fighter_width * 0.3, hand_y)
	var length := arm_length(sp, ms)
	if length > 2.0:
		var to := from + Vector2(facing * (fighter_width * 0.2 + length), 0)
		draw_line(from, to, INK, ARM_W + 6.0)
		draw_line(from, to, SKIN, ARM_W)
		# la mano: aperta mentre si allunga, chiusa quando torna
		var open := ms < float(sp.windupMs) + float(sp.reachMs)
		draw_circle(to, 14.0, INK)
		draw_circle(to, 10.0, SKIN)
		for i in 3 if open else 0:
			var f := to + Vector2(facing * 12.0, (i - 1) * 9.0)
			draw_line(to, f, INK, 9.0)
			draw_line(to, f, SKIN, 5.0)
	if ms < SHOUT_MS:
		var k := ms / SHOUT_MS
		var px := Access.px(26)
		var text := "%s!" % str(sp.name).to_upper()
		var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var at := Vector2(float(p.x) - size.x / 2, float(p.y) - fighter_height - 50.0 - 20.0 * k)
		var a := 1.0 - k * k
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color(0, 0, 0, 0.7 * a))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 0.85, 0.2, a))
