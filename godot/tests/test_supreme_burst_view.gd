# La suprema a raffiche (#358): la vampata parte solo per chi ha una suprema "burst" e dura fino all'ultima raffica
extends RefCounted

var runner

const BurstView := preload("res://scripts/supreme_burst_view.gd")


func _game() -> Dictionary:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func test_la_rabbia_di_lendmar() -> void:
	var game := _game()
	var sp: Dictionary = game.characters.lendmar.supreme
	runner.check(str(sp.type) == "burst" and str(sp.name) == "IRA", "Lendmar ha IRA")
	var v := BurstView.new()
	v.fixed_now = 1000.0
	v.start("l", game.characters.lendmar)
	v.start("b", game.characters.bradipo)
	runner.check(v.raging("l"), "si arrabbia subito")
	runner.check(not v.raging("b"), "chi ha un'altra suprema no")
	v.fixed_now = 1000.0 + BurstView.total_ms(sp) + 10.0
	runner.check(not v.raging("l"), "dopo l'ultima raffica si calma")
	v.free()
