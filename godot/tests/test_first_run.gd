# Primo avvio guidato (first_run.gd, E14): schema dei comandi e "fatto" salvato in bonobo.cfg
extends RefCounted

var runner

const FirstRun := preload("res://scripts/first_run.gd")
const PATH := "user://test_first_run.cfg"
const AUDIO := {"master": 0.8, "sfx": 0.7, "music": 0.35}


func _fresh() -> Settings:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return Settings.new(AUDIO, PATH)


func test_resta_fatto_dopo_il_riavvio() -> void:
	var s := _fresh()
	runner.check(not s.first_run_done, "la prima volta parte")
	s.first_run_done = true
	s.save()
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.first_run_done, "al secondo avvio no")
	again.reset()
	runner.check(again.first_run_done, "Ripristina non lo rimette")


func test_schema_dei_comandi() -> void:
	var s := _fresh()
	var keys := FirstRun.controls(s, false)
	runner.check(keys.size() == FirstRun.SHOWN.size(), "una riga per azione")
	runner.check(keys[FirstRun.SHOWN.find("light")] == ["Attacco leggero", "J"], "tastiera: %s" % [keys])
	var pad := FirstRun.controls(s, true, "ps")
	runner.check(pad[FirstRun.SHOWN.find("light")][1] == "Quadrato", "pad PlayStation: %s" % [pad])
	s.assign("light", 0, 0) # tolto l'unico tasto
	runner.check(FirstRun.controls(s, false)[FirstRun.SHOWN.find("light")][1] == "nessun tasto", "senza tasti")


func test_nome_a_caso() -> void:
	runner.check(FirstRun.random_name().length() > 3, "un nome")
