# Postazioni (#433): i numeri in game.json, la vista dallo snapshot, la canna come in physics/stations.ts,
# la predizione che lascia decidere al server e i punti torre dell'HUD
extends RefCounted

var runner

const StationView := preload("res://scripts/station_view.gd")
const ArcadeView := preload("res://scripts/arcade_view.gd")
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


# La gru (#433): il pezzo appeso arriva dallo snapshot e i blocchi che restano non lampeggiano
func test_gru_dallo_snapshot() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(int(game.station.gruMaxBlocks) > 0 and float(game.station.gruCooldownMs) > 0.0, "i numeri della gru in game.json")
	var view: RefCounted = StationView.new()
	view.setup({"stations": [{"kind": "gru", "x": 100, "y": 650, "width": 80, "fromX": 400, "toX": 640, "dropY": 300, "landY": 600}]}, game)
	var cells := [[480, 260], [520, 260], [480, 300], [520, 300]]
	view.on_snapshot({"stations": [{"user": "p1", "readyAt": 0, "piece": {"kind": "O", "cells": cells}}]}, 0)
	runner.check(view.station_of("p1") == 0, "chi usa la gru")
	runner.check(view.states[0].piece.cells.size() == 4, "il pezzo appeso")
	var arcade: RefCounted = ArcadeView.new()
	arcade.setup(game)
	arcade.on_snapshot({"tetris": {"pieces": [], "blocks": [{"x": 400, "y": 560, "kind": "O", "ms": 100, "keep": true}]}})
	runner.check(arcade.blocks.size() == 1 and arcade.blocks[0].get("keep", false), "il blocco della gru resta")


# Una postazione fuori dalla sua finestra non si vede (prima restava una bombarda fantasma dove c'era la Garisenda)
func test_postazione_spenta_non_si_vede() -> void:
	var s := {"kind": "bombarda", "x": 100, "y": 650, "width": 80, "on": [[1000, 5000]]}
	runner.check(StationView.alpha_at(s, 3000.0) == 1.0, "dentro la finestra si vede tutta")
	runner.check(StationView.alpha_at(s, 6000.0) == 0.0, "dopo la finestra sparisce")
	runner.check(StationView.alpha_at(s, 0.0) == 0.0, "prima della finestra non c'è")
	runner.check(StationView.alpha_at({"kind": "munizioni", "x": 0, "y": 0, "width": 80}, 0.0) == 1.0, "senza finestre c'è sempre")


# La bombarda che spara (#470 fase 4): la canna rincula e torna, lo sparo sa dove punta, le palle avanzano da sole
func test_rinculo_e_direzione_dello_sparo() -> void:
	var view: RefCounted = StationView.new()
	view.setup({"stations": [{"kind": "bombarda", "x": 100, "y": 650, "width": 80}]}, {"station": {"pivotPx": 46}, "effects": {"cannonRecoilPx": 14, "cannonRecoilMs": 450}})
	runner.check(view.recoil(0, 1000) == 0.0, "prima dello sparo la canna è al suo posto")
	view.on_fire(0, 1000)
	runner.check(absf(view.recoil(0, 1050) - 14.0) < 0.01, "subito dopo è indietro di 14 px")
	runner.check(view.recoil(0, 1300) > 0.0 and view.recoil(0, 1300) < 14.0, "poi torna")
	runner.check(view.recoil(0, 1600) == 0.0, "e si rimette a posto")
	var dir: Vector2 = view.muzzle_dir(0, Vector2(140, 604) + Vector2(1, -1).normalized() * 56.0)
	runner.check(dir.is_equal_approx(Vector2(1, -1).normalized()), "la direzione dello sparo va dal perno alla bocca")
	view.on_snapshot({"cannonballs": [{"id": 1, "x": 200, "y": 500, "vx": 900, "vy": 0}]}, 0)
	var c: Array = view.ball_centers(50)
	runner.check(c.size() == 1 and c[0][0].x > 200.0 and c[0][0].y > 500.0, "la palla avanza e scende tra uno snapshot e l'altro")
