# La suprema che afferra (#358): il braccio parte solo per chi ha una suprema "grab", si allunga e poi torna
extends RefCounted

var runner

const GrabView := preload("res://scripts/supreme_grab_view.gd")


func _game() -> Dictionary:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func test_il_braccio_di_lampione() -> void:
	var game := _game()
	var sp: Dictionary = game.characters.lampione.supreme
	runner.check(str(sp.type) == "grab" and str(sp.name) == "snaack", "Lampione ha snaack")
	var v := GrabView.new()
	v.fixed_now = 1000.0
	v.start("l", game.characters.lampione)
	v.start("b", game.characters.bradipo)
	runner.check(v.reaching("l") == 0.0, "all'inizio il braccio non c'è")
	v.fixed_now = 1000.0 + float(sp.windupMs) + 10.0
	runner.check(is_equal_approx(v.reaching("l"), float(sp.reach)), "quando afferra è tutto allungato")
	runner.check(v.reaching("b") == 0.0, "chi ha un'altra suprema non allunga il braccio")
	v.fixed_now = 1000.0 + float(sp.windupMs) + float(sp.reachMs) + float(sp.endLagMs)
	runner.check(v.reaching("l") < 1.0, "alla fine il braccio è tornato")
	v.free()


func test_il_filo_di_micelium() -> void:
	var game := _game()
	var sp: Dictionary = game.characters.drmicelium.supreme
	runner.check(str(sp.type) == "infect", "Dr. Micelium ha il filo di Kirschner")
	var v := GrabView.new()
	v.fixed_now = 1000.0
	v.start("m", game.characters.drmicelium)
	v.fixed_now = 1000.0 + float(sp.windupMs) + 10.0
	runner.check(is_equal_approx(v.reaching("m"), float(sp.reach)), "il filo arriva fin dove infetta")
	v.free()
