# Opzioni video (video.gd, settings.gd sezione [video], E14): si salvano e tornano al riavvio
extends RefCounted

var runner

const PATH := "user://test_video.cfg"
const AUDIO := {"master": 0.8, "sfx": 0.7, "music": 0.35}


func _fresh() -> Settings:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return Settings.new(AUDIO, PATH)


func test_default() -> void:
	var s := _fresh()
	runner.check(s.video == Settings.VIDEO_DEFAULTS, "video di default: %s" % [s.video])


func test_restano_dopo_il_riavvio() -> void:
	var s := _fresh()
	s.video.fullscreen = true
	s.video.window = 1
	s.video.max_fps = 2
	s.video.effects = false
	s.save()
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.video.fullscreen and again.video.window == 1, "finestra: %s" % [again.video])
	runner.check(again.video.max_fps == 2 and not again.video.effects, "fps ed effetti: %s" % [again.video])


func test_valori_sbagliati_restano_al_default() -> void:
	var s := _fresh()
	var cfg := ConfigFile.new()
	cfg.set_value("video", "vsync", "boh")
	cfg.save(PATH)
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.video.vsync == true, "vsync resta acceso")


func test_scelte_allineate() -> void:
	runner.check(Video.WINDOW_SIZES.size() == Video.WINDOW_NAMES.size(), "finestre")
	runner.check(Video.FPS_LIMITS.size() == Video.FPS_NAMES.size(), "fps")
