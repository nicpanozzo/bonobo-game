# Postazioni dell'arena (#433): la bombarda con la canna che segue la mira e le palle che ha dentro, le munizioni
# con la pila di casse e la barra della carica, le palle di mortadella in volo.
# Solo disegno: stato e palle arrivano nello snapshot (stations, cannonballs), calcolati dal server in physics/stations.ts.
# world_view.gd lo chiama dentro _draw.
extends RefCounted

const INK := Color("1c1410")
const MORTADELLA := Color("f2a7b0")
const BRONZE := Color("8a6a3a")
const WOOD := Color("a0703c")

var stations: Array = [] # stage.stations
var states: Array = [] # snapshot.stations, stesso ordine
var balls: Array = [] # snapshot.cannonballs
var game: Dictionary = {}
var _balls_ms := 0 # quando sono arrivate le palle: tra uno snapshot e l'altro avanzano da sole
var _k: Dictionary = {} # i numeri di STATION


func setup(spec: Dictionary, game_data: Dictionary) -> void:
	game = game_data
	stations = spec.get("stations") if spec.get("stations") is Array else []
	_k = game.get("station", {})
	clear()


func clear() -> void:
	states = []
	balls = []


func on_snapshot(snap: Dictionary, now: int) -> void:
	states = snap.get("stations") if snap.get("stations") is Array else []
	balls = snap.get("cannonballs") if snap.get("cannonballs") is Array else []
	_balls_ms = now


func is_empty() -> bool:
	return stations.is_empty()


# Indice della postazione che usa id, -1 se nessuna
func station_of(id: String) -> int:
	for i in states.size():
		if states[i].get("user") == id:
			return i
	return -1


# Il perno della canna e la direzione in cui punta, come barrel() in physics/stations.ts
static func barrel(s: Dictionary, aim: float, pivot: float) -> Array:
	var a := deg_to_rad(aim)
	var dir := float(s.get("dir", 1))
	return [Vector2(float(s.x) + float(s.width) / 2.0, float(s.y) - pivot), Vector2(dir * cos(a), -sin(a))]


func draw(canvas: CanvasItem, t: float) -> void:
	for i in stations.size():
		var s: Dictionary = stations[i]
		var st: Dictionary = states[i] if i < states.size() else {}
		var on := PredictMovement.piece_on(s, t)
		var alpha := 1.0 if on else 0.3
		var tint := Access.team_color(game, int(s.team)) if s.get("team") != null else Color("d8c8a0")
		# La pedana: si capisce dove mettersi, del colore della squadra; più chiara se c'è qualcuno sopra
		var used: bool = st.get("user") != null
		canvas.draw_rect(Rect2(float(s.x), float(s.y) - 6.0, float(s.width), 6.0), Color(tint.lightened(0.3 if used else 0.0), alpha))
		if s.kind == "bombarda":
			_draw_cannon(canvas, s, st, t, alpha)
		else:
			_draw_crates(canvas, s, st, t, alpha)


func _draw_cannon(canvas: CanvasItem, s: Dictionary, st: Dictionary, t: float, alpha: float) -> void:
	var lo := float(s.get("aimMinDeg", _k.get("aimMinDeg", 5)))
	var hi := float(s.get("aimMaxDeg", _k.get("aimMaxDeg", 60)))
	var b := barrel(s, float(st.get("aim", (lo + hi) / 2.0)), float(_k.get("pivotPx", 46)))
	var pivot: Vector2 = b[0]
	var dir: Vector2 = b[1]
	var length := float(_k.get("barrelPx", 56))
	# Pronta a sparare: la bocca è accesa
	var can_fire := t >= float(st.get("readyAt", 0)) and int(st.get("ammo", 0)) > 0
	canvas.draw_line(pivot, pivot + dir * length, Color(BRONZE, alpha), 22.0)
	canvas.draw_line(pivot + dir * (length - 6.0), pivot + dir * length, Color(BRONZE.lightened(0.3), alpha), 26.0)
	canvas.draw_circle(pivot + dir * length, 7.0, Color(Color("ffcf5a") if can_fire else INK, alpha))
	# Il carrello con la ruota
	canvas.draw_rect(Rect2(pivot.x - 22.0, pivot.y, 44.0, float(s.y) - 6.0 - pivot.y), Color(WOOD, alpha))
	canvas.draw_circle(Vector2(pivot.x, float(s.y) - 16.0), 14.0, Color(INK, alpha))
	canvas.draw_circle(Vector2(pivot.x, float(s.y) - 16.0), 8.0, Color(WOOD.lightened(0.2), alpha))
	# Le palle dentro: piene quelle che ci sono, vuote le altre
	var full := int(s.get("ammoMax", _k.get("ammoMax", 6)))
	var have := int(st.get("ammo", 0))
	for k in full:
		var c := Vector2(float(s.x) + 8.0 + k * 12.0, float(s.y) + 14.0)
		canvas.draw_circle(c, 5.0, Color(MORTADELLA if k < have else Color(0, 0, 0, 0.35), alpha))


func _draw_crates(canvas: CanvasItem, s: Dictionary, st: Dictionary, t: float, alpha: float) -> void:
	var base := Vector2(float(s.x) + float(s.width) / 2.0, float(s.y) - 6.0)
	# La pila di casse da caricare
	for at: Vector2 in [Vector2(-28, -26), Vector2(2, -26), Vector2(-13, -52)]:
		var c := Rect2(base + at, Vector2(26, 26))
		canvas.draw_rect(c, Color(WOOD, alpha))
		canvas.draw_rect(c, Color(INK, alpha), false, 2.0)
		canvas.draw_line(c.position, c.end, Color(INK, alpha * 0.6), 2.0)
	# La carica in corso: una barra sopra che si riempie
	var loaded_at: Variant = st.get("load")
	if loaded_at != null:
		var load_ms := float(s.get("loadMs", _k.get("loadMs", 1500)))
		var k := clampf(1.0 - (float(loaded_at) - t) / load_ms, 0.0, 1.0)
		var bar := Rect2(base + Vector2(-30, -70), Vector2(60, 7))
		canvas.draw_rect(bar, Color(0, 0, 0, 0.5 * alpha))
		canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(Color("ffcf5a"), alpha))
	# Le casse in salita: una per freccia
	var crates: Array = st.get("crates") if st.get("crates") is Array else []
	for k in crates.size():
		var c := base + Vector2(-20.0 + k * 14.0, -84.0)
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 4), c + Vector2(5, 4), c + Vector2(0, -5)]), Color(Color.WHITE, alpha))


# Le palle di mortadella: rosa con i puntini bianchi del grasso, avanzano da sole tra uno snapshot e l'altro
func draw_balls(canvas: CanvasItem, now: int) -> void:
	var dt := minf((now - _balls_ms) / 1000.0, 0.1)
	var g := float(_k.get("ballGravityPxS2", 1300))
	var r := float(_k.get("ballRadiusPx", 15))
	for b: Dictionary in balls:
		var v := Vector2(float(b.vx), float(b.vy))
		var c := Vector2(float(b.x), float(b.y)) + v * dt + Vector2(0, 0.5 * g * dt * dt)
		canvas.draw_circle(c - v * 0.02, r * 0.8, Color(MORTADELLA, 0.3))
		canvas.draw_circle(c, r, MORTADELLA)
		canvas.draw_arc(c, r, 0, TAU, 20, Color("c76f7c"), 2.0)
		for d: Vector2 in [Vector2(-5, -4), Vector2(4, -6), Vector2(6, 3), Vector2(-3, 5), Vector2(0, 0)]:
			canvas.draw_circle(c + d, 1.8, Color("fff3ee"))
