# Il Dojo ha il suo disegno a tema: lo sceglie theme_stage.gd dall'id dell'arena e disegna il pavimento di tatami
extends RefCounted

var runner

const ThemeStage := preload("res://scripts/theme_stage.gd")


func test_il_dojo_ha_il_suo_disegno() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var theme := ThemeStage.new()
	theme.setup(game.stages.dojo, game)
	runner.check(theme.active(), "il Dojo è un'arena a tema")
	runner.check(theme.current.width == float(game.stages.dojo.width), "larga come l'arena: %s" % theme.current.width)
	runner.check(theme.cues(0.0, 1000.0, []).is_empty(), "nessun suono a tempo")
