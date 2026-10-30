# Il fondo del titolo (title_backdrop.gd): quali lottatori sceglie e il logo
extends RefCounted

var runner

const Backdrop := preload("res://scripts/title_backdrop.gd")


func test_solo_lottatori_disegnati() -> void:
	var game := {"characters": {
		"default": {"name": "Bonobo"},
		"a": {"name": "A", "portrait": "a.png", "sprite": {"dir": "a"}},
		"b": {"name": "B", "sprite": {"dir": "b"}},
	}}
	runner.check(Backdrop.drawn_fighters(game) == ["a"], "solo chi ha spritesheet e ritratto: %s" % [Backdrop.drawn_fighters(game)])


func test_stessa_locandina_con_lo_stesso_seme() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var a: Control = Backdrop.new()
	var b: Control = Backdrop.new()
	a.setup(game, 3)
	b.setup(game, 3)
	runner.check(a._front.size() <= 2 and a._back.size() <= 3, "due davanti, tre dietro")
	runner.check(a._front.size() == b._front.size() and (a._front.is_empty() or a._front[0].tex == b._front[0].tex), "stesso seme, stessi lottatori")
	var logo: Control = a.make_logo(0.5)
	runner.check(logo.custom_minimum_size.x > 200 and logo.custom_minimum_size.x < 620, "il logo si rimpicciolisce: %s" % logo.custom_minimum_size)
	logo.free()
	a.free()
	b.free()
