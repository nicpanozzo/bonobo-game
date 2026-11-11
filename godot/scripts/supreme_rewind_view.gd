# Suprema "rewind" (#358), …COSA? di Marcomunista: mentre carica, un orologio con le lancette che girano all'indietro
# e il nome della mossa sopra; quando torna indietro, un'onda color seppia larga quanto chi resta stordito.
# Solo disegno: lo spostamento e lo stordimento arrivano dallo snapshot; i tempi da game.json.
extends Node2D

const SHOUT_MS := 900.0 # quanto resta il nome
const WAVE_MS := 450.0 # quanto dura l'onda all'arrivo
const SEPIA := Color(0.86, 0.72, 0.5)
const INK := Color("221c1a")

var where: Callable # id giocatore -> Vector2 dei piedi, o null; lo imposta world_view
var fighter_height := 96.0 # da game.fighter, lo imposta world_view
var fixed_now := -1.0 # per i test: se >= 0 è l'orologio in ms al posto di quello vero
var _runs: Array = [] # [{ id, sp, t0 }]
var _font: Font = ThemeDB.fallback_font


func _now() -> float:
	return fixed_now if fixed_now >= 0 else float(Time.get_ticks_msec())


func start(id: String, character: Dictionary) -> void:
	var sp: Variant = character.get("supreme")
	if not (sp is Dictionary) or str(sp.get("type", "")) != "rewind":
		return
	_runs = _runs.filter(func(r): return r.id != id)
	_runs.append({"id": id, "sp": sp, "t0": _now()})


func clear() -> void:
	_runs = []


# "clock" mentre carica, "wave" appena tornato indietro, "" altrimenti
func phase(id: String) -> String:
	for r in _runs:
		if r.id == id:
			var ms := _now() - float(r.t0)
			if ms < float(r.sp.windupMs):
				return "clock"
			if ms < float(r.sp.windupMs) + WAVE_MS:
				return "wave"
	return ""


func _process(_delta: float) -> void:
	if _runs.is_empty():
		return
	var now := _now()
	_runs = _runs.filter(func(r): return now - float(r.t0) < maxf(float(r.sp.windupMs) + maxf(WAVE_MS, _fuse(r.sp)), SHOUT_MS))
	for r in _runs: # la bomba resta dove era prima di sparire: l'ultimo punto visto mentre caricava
		if now - float(r.t0) < float(r.sp.windupMs) and where.is_valid():
			var feet: Variant = where.call(r.id)
			if feet != null:
				r["bomb"] = feet
	queue_redraw()


static func _fuse(sp: Dictionary) -> float:
	return float(sp.get("bombFuseMs", 0))


func _draw() -> void:
	var now := _now()
	for r in _runs:
		var ms := now - float(r.t0)
		var feet: Variant = where.call(r.id) if where.is_valid() else null
		if feet != null:
			_draw_rewind(r.sp, ms, feet)
		var lit := ms - float(r.sp.windupMs)
		if r.has("bomb") and lit >= 0.0 and lit < _fuse(r.sp):
			_draw_bomb(r.bomb, lit / _fuse(r.sp), ms)


# La bomba lasciata da …COSA?: palla nera con la miccia che si accorcia e lampeggia sempre più in fretta.
# Lo scoppio lo disegna gear_view (evento gear "boom" del server)
func _draw_bomb(feet: Vector2, burnt: float, ms: float) -> void:
	var r := 16.0
	var c := feet - Vector2(0, r)
	draw_circle(c, r, INK)
	draw_circle(c + Vector2(-5, -5), 4.0, Color(1, 1, 1, 0.35))
	var top := c + Vector2(6, -r + 2)
	var tip := top + Vector2(8, -14) * (1.0 - burnt) # la miccia si accorcia
	draw_line(top, tip, SEPIA, 3.0)
	var blink := 0.5 + 0.5 * sin(ms * (0.02 + 0.06 * burnt))
	draw_circle(tip, 4.0 + 2.0 * blink, Color(1.0, 0.55 + 0.4 * blink, 0.1))


func _draw_rewind(sp: Dictionary, ms: float, feet: Vector2) -> void:
	var c := feet - Vector2(0, fighter_height * 0.5)
	var windup := float(sp.windupMs)
	if ms < windup:
		var r := fighter_height * 0.7
		var a := clampf(ms / 120.0, 0.0, 1.0)
		draw_arc(c, r, 0, TAU, 48, Color(SEPIA, 0.8 * a), 5.0)
		for i in 12: # le tacche delle ore
			var d := Vector2.from_angle(i * TAU / 12.0)
			draw_line(c + d * r * 0.86, c + d * r * 0.98, Color(INK, 0.6 * a), 3.0)
		var back := -ms / windup * TAU * 3.0 # tre giri all'indietro
		draw_line(c, c + Vector2.from_angle(back - PI / 2) * r * 0.8, Color(INK, a), 4.0)
		draw_line(c, c + Vector2.from_angle(back / 12.0 - PI / 2) * r * 0.5, Color(INK, a), 6.0)
	elif ms < windup + WAVE_MS:
		var k := (ms - windup) / WAVE_MS
		draw_arc(c, float(sp.stunRadius) * k, 0, TAU, 48, Color(SEPIA, 1.0 - k), 8.0 * (1.0 - k) + 2.0)
	if ms < SHOUT_MS:
		var k := ms / SHOUT_MS
		var px := Access.px(28)
		var text := str(sp.name)
		var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var at := Vector2(c.x - size.x / 2, feet.y - fighter_height - 60.0 - 16.0 * k)
		var a := 1.0 - k * k
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color(0, 0, 0, 0.7 * a))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(SEPIA.lightened(0.3), a))
