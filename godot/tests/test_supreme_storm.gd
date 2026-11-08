# Tempesta! di Capt. OrsoBlu (#547): rollio, inclinazione dell'arena e insulti (supreme_storm_view.gd)
extends RefCounted

var runner

const StormView := preload("res://scripts/supreme_storm_view.gd")

const SP := {"type": "storm", "name": "Tempesta", "windupMs": 500, "durationMs": 4800, "rollPeriodMs": 1600, "insults": ["A!", "B!"]}


func test_rollio_come_sul_server() -> void:
	runner.check(StormView.roll(SP, 300.0) == 0.0, "fermo mentre afferra il timone")
	runner.check(is_equal_approx(StormView.roll(SP, 500.0 + 400.0), 1.0), "a un quarto di giro tutto da una parte")
	runner.check(is_equal_approx(StormView.roll(SP, 500.0 + 1200.0), -1.0), "a tre quarti dall'altra")
	runner.check(StormView.roll(SP, 6000.0) == 0.0, "finita la tempesta si torna dritti")


func test_insulti_a_turno() -> void:
	runner.check(StormView.insult(SP, 200.0) == "", "prima del timone niente nuvolette")
	runner.check(StormView.insult(SP, 600.0) == "A!", "la prima")
	runner.check(StormView.insult(SP, 500.0 + 1300.0) == "B!", "poi la seconda")


func test_inclina_e_finisce() -> void:
	var v := StormView.new()
	v.fixed_now = 1000.0
	v.start("o", {"supreme": SP})
	v.start("x", {"supreme": {"type": "spin"}})
	v.fixed_now = 1000.0 + 900.0
	runner.check(v.active(), "in corso")
	runner.check(is_equal_approx(v.tilt(), deg_to_rad(StormView.TILT_DEG)), "l'arena si inclina (%s)" % v.tilt())
	v.fixed_now = 1000.0 + 5400.0
	runner.check(not v.active() and v.tilt() == 0.0, "finita")
	v.free()
