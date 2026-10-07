# Accessibilità (access.gd, settings.gd sezione [access], E14): palette per daltonici, testo e preferenze salvate
extends RefCounted

var runner

const PATH := "user://test_access.cfg"
const AUDIO := {"master": 0.8, "sfx": 0.7, "music": 0.35}


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func _fresh() -> Settings:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return Settings.new(AUDIO, PATH)


func test_restano_dopo_il_riavvio() -> void:
	var s := _fresh()
	runner.check(s.access == Settings.ACCESS_DEFAULTS, "default: %s" % [s.access])
	s.access.calm = true
	s.access.colorblind = true
	s.access.text_size = 2
	s.save()
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.access.calm and again.access.colorblind and again.access.text_size == 2, "salvate: %s" % [again.access])


func test_palette_rimappa_per_indice() -> void:
	var game := _game()
	Access.apply(game, {"calm": false, "colorblind": true, "text_size": 1})
	for i in game.colors.size():
		var want := Color.hex((int(game.colorsColorblind[i]) << 8) | 0xff)
		runner.check(Access.color(game.colors[i]) == want, "colore %d" % i)
	runner.check(Access.team_color(game, 2) == Color.hex((int(game.teamColorsColorblind["2"][0]) << 8) | 0xff), "squadra blu")
	runner.check(Access.px(20) == 25, "testo al 125%%: %d" % Access.px(20))
	Access.apply(game, Settings.ACCESS_DEFAULTS)
	runner.check(Access.color(game.colors[0]) == Color.hex((int(game.colors[0]) << 8) | 0xff), "palette normale")
	runner.check(Access.px(20) == 20, "testo al 100%")


func test_scelte_allineate() -> void:
	runner.check(Access.TEXT_SCALES.size() == Access.TEXT_NAMES.size(), "dimensioni del testo")
