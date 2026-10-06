# Preferenze e tasti (settings.gd), salvati in un file di prova per non toccare quelle di chi lancia i test
extends RefCounted

var runner

const PATH := "user://test_bonobo.cfg"
const AUDIO := {"master": 0.8, "sfx": 0.7, "music": 0.35}


func _fresh() -> Settings:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return Settings.new(AUDIO, PATH)


func test_default_senza_file() -> void:
	var s := _fresh()
	runner.check(s.bindings == Settings.DEFAULT_BINDINGS, "tasti di default")
	runner.check(s.master == 0.8 and s.music_on, "audio di default")


func test_un_tasto_fa_una_sola_azione() -> void:
	var s := _fresh()
	s.assign("light", 0, KEY_K) # K era dell'attacco pesante
	runner.check(s.bindings.light[0] == KEY_K, "K ora è il leggero")
	runner.check(not s.bindings.heavy.has(KEY_K), "e non è più il pesante")


func test_al_massimo_max_keys() -> void:
	var s := _fresh()
	for k in [KEY_1, KEY_2, KEY_3, KEY_4]:
		s.assign("taunt", 99, k)
	runner.check(s.bindings.taunt.size() == Settings.MAX_KEYS, "tasti: %s" % [s.bindings.taunt])


func test_togliere_un_tasto() -> void:
	var s := _fresh()
	s.assign("left", 1, 0)
	runner.check(s.bindings.left == [KEY_A], "resta solo A: %s" % [s.bindings.left])


func test_salvato_e_ricaricato() -> void:
	var s := _fresh()
	s.master = 0.25
	s.assign("dodge", 0, KEY_SHIFT)
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.master == 0.25 and again.bindings.dodge[0] == KEY_SHIFT, "ricaricato: %s %s" % [again.master, again.bindings.dodge])


func test_file_salvato_male() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", 7.0)
	cfg.set_value("keys", "light", ["J", 3])
	cfg.set_value("keys", "heavy", "K")
	cfg.set_value("profile", "last", 42)
	cfg.save(PATH)
	var s := Settings.new(AUDIO, PATH)
	runner.check(s.master == 1.0, "volume riportato tra 0 e 1: %s" % s.master)
	runner.check(s.bindings.light == Settings.DEFAULT_BINDINGS.light, "tasti con stringhe: default")
	runner.check(s.bindings.heavy == Settings.DEFAULT_BINDINGS.heavy, "tasti non in lista: default")
	runner.check(s.profile == {}, "profilo non valido: vuoto")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_pad_di_default_e_salvato() -> void:
	var s := _fresh()
	runner.check(s.pad_bindings == Settings.DEFAULT_PAD_BINDINGS, "pad di default")
	s.pad_bindings.light = [JOY_BUTTON_Y]
	s.save()
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.pad_bindings.light == [JOY_BUTTON_Y], "pad ricaricato: %s" % [again.pad_bindings.light])
	runner.check(again.pad_bindings.heavy == [JOY_BUTTON_B], "il resto resta: %s" % [again.pad_bindings.heavy])


func test_pad_salvato_male() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("pad", "light", ["A"])
	cfg.set_value("pad", "heavy", [-3])
	cfg.save(PATH)
	var s := Settings.new(AUDIO, PATH)
	runner.check(s.pad_bindings.light == Settings.DEFAULT_PAD_BINDINGS.light, "pulsanti con stringhe: default")
	runner.check(s.pad_bindings.heavy == Settings.DEFAULT_PAD_BINDINGS.heavy, "pulsanti negativi: default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_levetta_con_zona_morta() -> void:
	var left := Settings.axis_input(JOY_AXIS_LEFT_X, false)
	runner.check(Settings.DEFAULT_PAD_BINDINGS.left.has(left), "levetta a sinistra nel default")
	runner.check(not Settings.axis_active(-0.2, left % 2, 0.35), "poco inclinata: non conta")
	runner.check(Settings.axis_active(-0.8, left % 2, 0.35), "inclinata a sinistra: conta")
	runner.check(not Settings.axis_active(0.8, left % 2, 0.35), "inclinata a destra: non è sinistra")
	runner.check(Settings.axis_active(0.5, 1, 0.35), "grilletto premuto")
