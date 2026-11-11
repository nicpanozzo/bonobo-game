# Suprema "spin" (#358), DEMACIAAA di Bradipo Giallo: mentre gira, vortici d'aria intorno a lui che seguono dove va
# (il grido è il fumetto delle battute, quotes.supreme, con la sua voce). Solo disegno: parte dall'evento attack con kind "supreme" e segue i tempi del
# personaggio in game.json (characters.<id>.supreme). I colpi veri li decide il server.
extends Node2D

const ARCS := 3 # vortici intorno
const TURN_MS := 140.0 # un giro dei vortici: veloce, come la E di Garen
const WIND := Color(1, 1, 1) # aria bianca, niente contorno giallo (Nicola, 2026-10-24)
const AURA := Color(0.12, 0.04, 0.16) # l'Aura nera di Egiainuso
const PULL_MS := 500.0 # un anello dell'aura va dal bordo del risucchio a lui in tanto

var where: Callable # id giocatore -> Vector2 dei piedi, o null; lo imposta world_view
var fixed_now := -1.0 # per i test: se >= 0 è l'orologio in ms al posto di quello vero
var _runs: Array = [] # [{ id, sp, t0 }]


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
	if spin_ms >= 0 and spin_ms < dur and sp.get("pull") is Dictionary:
		_draw_pull(sp, spin_ms, feet)
	if spin_ms < 0 or not sp.get("whirl", true): # l'Elefante di Elvedeo si vede già nel disegno
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
		draw_polyline(pts, Color(WIND, 0.55 * alpha), 4.0, true)


# L'Aura nera di Egiainuso (pull): anelli a zig-zag scuri che si stringono dal bordo del risucchio verso di lui,
# così si vede fin dove tira e da che parte
func _draw_pull(sp: Dictionary, spin_ms: float, feet: Vector2) -> void:
	var radius := float(sp.pull.radius)
	var c := feet - Vector2(0, float(sp.height) * 0.45)
	var fade := clampf(minf(spin_ms, float(sp.durationMs) - spin_ms) / 150.0, 0.0, 1.0)
	for ring in 3:
		var k := fmod(spin_ms / PULL_MS + ring / 3.0, 1.0) # 0 al bordo, 1 addosso a lui
		var r := radius * (1.0 - k) + 30.0 * k
		var pts := PackedVector2Array()
		var teeth := 28
		for i in teeth + 1:
			var a := TAU * i / teeth + spin_ms * 0.002
			var jag := 1.0 + (0.08 if i % 2 == 0 else -0.08)
			pts.append(c + Vector2(cos(a), sin(a) * 0.7) * r * jag)
		draw_polyline(pts, Color(AURA, 0.55 * fade * (0.4 + 0.6 * k)), 3.0, true)
