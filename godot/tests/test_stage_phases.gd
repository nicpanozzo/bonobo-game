# Fasi di un'arena (#433): fase attiva, telecamera della fase, transizione morbida e testo grande
extends RefCounted

var runner

const Phases := preload("res://scripts/stage_phases.gd")
const Main := preload("res://scripts/main.gd")

const GAME := {"world": {"width": 1280, "height": 720}, "fighter": {"width": 44, "height": 88}}
const CAM := {"margin": 140, "minZoom": 0.7, "maxZoom": 1.3}
const STAGE := {
	"height": 1800,
	"camera": {"minZoom": 0.5, "floorY": 1640},
	"blastZone": {"left": -250, "right": 1530, "top": -350, "bottom": 2000},
	"phases": [
		{"id": "torri", "name": "Le due torri", "startMs": 0},
		{"id": "rissa", "name": "La rissa", "startMs": 60000, "announce": "Si sale!", "warnMs": 5000,
			"camera": {"minZoom": 0.8}, "blastZone": {"left": -250, "right": 1530, "top": -350, "bottom": 900}},
	],
}


func test_fase_attiva() -> void:
	runner.check(Phases.active(STAGE, 0.0).id == "torri", "a 0 ms la prima")
	runner.check(Phases.active(STAGE, 59999.0).id == "torri", "poco prima della seconda")
	runner.check(Phases.active(STAGE, 60000.0).id == "rissa", "alla soglia cambia")
	runner.check(Phases.active({}, 10.0).is_empty(), "senza fasi: vuoto")
	runner.check(Phases.active({"phases": [{"id": "x", "name": "X", "startMs": 500}]}, 100.0).is_empty(), "prima della prima fase: vuoto")


func test_telecamera_della_fase_sovrascrive_quella_dell_arena() -> void:
	var a := Phases.effective_stage(STAGE, 1000.0)
	runner.check(a.camera.minZoom == 0.5 and a.camera.floorY == 1640.0, "prima fase: quella dell'arena")
	var b := Phases.effective_stage(STAGE, 61000.0)
	runner.check(b.camera.minZoom == 0.8 and b.camera.floorY == 1640.0, "seconda: minZoom nuovo, floorY resta")
	runner.check(b.blastZone.bottom == 900, "e la sua zona di espulsione")
	runner.check(STAGE.camera.minZoom == 0.5, "l'arena originale non cambia")


func test_transizione_morbida() -> void:
	var cur := {"minZoom": 0.5, "maxZoom": 1.3, "floorY": 1640.0}
	var target := {"minZoom": 0.8, "maxZoom": 1.3}
	var step := Phases.blend_camera(cur, target, 0.1, 1000.0)
	runner.check(step.minZoom > 0.5 and step.minZoom < 0.8, "dopo 100 ms è a metà strada (%s)" % step.minZoom)
	var done := Phases.blend_camera(cur, target, 1.0, 1000.0)
	runner.check(done.minZoom > 0.78, "dopo 1 s è quasi arrivata (%s)" % done.minZoom)
	runner.check(not step.has("floorY"), "il pavimento non chiesto più cade")


func test_testo_grande() -> void:
	runner.check(Phases.banner(STAGE, 1000.0, 2500.0).text == "Le due torri", "all'inizio: il nome della prima fase")
	runner.check(Phases.banner(STAGE, 10000.0, 2500.0).is_empty(), "in mezzo alla fase: niente")
	var warn := Phases.banner(STAGE, 56000.0, 2500.0)
	runner.check(warn.text == "Si sale!" and warn.warn, "warnMs prima: l'avviso")
	runner.check(Phases.banner(STAGE, 61000.0, 2500.0).text == "La rissa", "alla soglia: il nome nuovo")
	runner.check(Phases.banner(STAGE, 63000.0, 2500.0).is_empty(), "dopo banner_ms sparisce")
	runner.check(Phases.banner({}, 0.0, 2500.0).is_empty(), "senza fasi: niente")


func test_arena_alta_inquadra_in_verticale() -> void:
	var empty := Main.framing(STAGE, CAM, GAME, [])
	runner.check(empty.center.y == 900.0 and empty.zoom >= 0.5, "senza lottatori: il centro dell'altezza (%s)" % empty.center)
	var top := Main.framing(STAGE, CAM, GAME, [Vector2(640, 300), Vector2(700, 500)])
	runner.check(top.center.y < 900.0, "in alto la telecamera sale (%s)" % top.center.y)
	var spread := Main.framing(STAGE, CAM, GAME, [Vector2(640, 300), Vector2(700, 1600)])
	runner.check(720.0 / spread.zoom >= 1300.0, "uno in cima e uno in fondo: li vede tutti e due")
	runner.check(spread.limits.end.y == 2000.0, "la vista resta nelle zone di espulsione")
