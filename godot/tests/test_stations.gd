# Postazioni (#433): i numeri in game.json, la vista dallo snapshot, la canna come in physics/stations.ts,
# la predizione che lascia decidere al server e i punti torre dell'HUD
extends RefCounted

var runner

const StationView := preload("res://scripts/station_view.gd")
const Predictor := preload("res://scripts/predictor.gd")
const Hud := preload("res://scripts/hud.gd")


func test_numeri_nei_dati() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(game.get("station") is Dictionary and float(game.station.barrelPx) > 0.0, "i numeri delle postazioni in game.json")


func test_vista_dallo_snapshot() -> void:
	var view: RefCounted = StationView.new()
	view.setup({"stations": [{"kind": "bombarda", "x": 100, "y": 650, "width": 80}, {"kind": "munizioni", "x": 400, "y": 650, "width": 80, "feeds": 0}]}, {})
	runner.check(not view.is_empty(), "l'arena ha postazioni")
	view.on_snapshot({"stations": [{"user": null, "aim": 30, "ammo": 2, "readyAt": 0}, {"user": "p1", "crates": []}], "cannonballs": [{"id": 1, "ownerId": "p0", "x": 200, "y": 500, "vx": 900, "vy": -300}]}, 0)
	runner.check(view.station_of("p1") == 1 and view.station_of("p0") == -1, "chi usa quale postazione")
	runner.check(view.balls.size() == 1, "le palle in volo")
	view.on_snapshot({}, 0)
	runner.check(view.states.is_empty() and view.balls.is_empty(), "senza postazioni nello snapshot niente")
	runner.check(StationView.new().is_empty(), "un'arena senza postazioni")


func test_canna_come_la_fisica() -> void:
	var b: Array = StationView.barrel({"x": 100, "y": 650, "width": 80, "dir": -1}, 0.0, 46.0)
	runner.check(b[0] == Vector2(140, 604), "il perno sopra il centro della pedana")
	runner.check(b[1].is_equal_approx(Vector2(-1, 0)), "dritta verso sinistra")
	var up: Array = StationView.barrel({"x": 100, "y": 650, "width": 80}, 90.0, 46.0)
	runner.check(up[1].is_equal_approx(Vector2(0, -1)), "a 90 gradi punta in alto")


func test_alla_postazione_decide_il_server() -> void:
	var p := {"x": 140, "y": 650, "predict": {"seq": 1}, "attack": null, "ledge": null, "grabbedBy": null, "powerup": null, "charge": 0}
	runner.check(Predictor.predictable(p, {}), "a terra si predice")
	p.station = 0
	runner.check(not Predictor.predictable(p, {}), "alla postazione no")


func test_punti_torre_per_squadra() -> void:
	var parts: Array = Hud.tower_parts({"2": 3}, [{"team": 2}, {"team": 1}, {"team": 2}])
	runner.check(parts == [[1, 0], [2, 3]], "ogni squadra in campo, in ordine, anche a zero")
