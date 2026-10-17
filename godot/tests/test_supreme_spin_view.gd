# La suprema che gira (#358): i vortici partono solo per chi ha una suprema "spin" e durano quanto il giro
extends RefCounted

var runner

const SpinView := preload("res://scripts/supreme_spin_view.gd")


func _game() -> Dictionary:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func test_bradipo_gira_gli_altri_no() -> void:
	var game := _game()
	var sp: Dictionary = game.characters.bradipo.supreme
	runner.check(str(sp.type) == "spin" and str(sp.name) == "DEMACIAAA", "Bradipo Giallo ha DEMACIAAA")
	var v := SpinView.new()
	v.fixed_now = 1000.0
	v.start("b", game.characters.bradipo)
	v.start("o", game.characters.bonobot)
	runner.check(not v.spinning("b"), "durante la carica non gira ancora")
	v.fixed_now = 1000.0 + float(sp.windupMs) + 10.0
	runner.check(v.spinning("b"), "dopo la carica gira")
	runner.check(not v.spinning("o"), "chi ha la suprema che cade non gira")
	v.fixed_now = 1000.0 + float(sp.windupMs) + float(sp.durationMs) + 10.0
	runner.check(not v.spinning("b"), "finito il giro si ferma")
	v.clear()
	v.free()
