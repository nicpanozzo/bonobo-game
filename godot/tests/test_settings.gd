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


func test_conflitto_dice_da_dove() -> void:
	var s := _fresh()
	runner.check(s.assign("light", 0, KEY_K) == "heavy", "K tolto dall'attacco pesante")
	runner.check(s.bindings.heavy.is_empty(), "il pesante resta senza tasti: %s" % [s.bindings.heavy])
	runner.check(s.assign("taunt", 1, KEY_Y) == "", "Y era libero")


func test_rimappare_il_pad() -> void:
	var s := _fresh()
	runner.check(s.assign("light", 0, JOY_BUTTON_B, true) == "heavy", "B tolto dal pesante")
	runner.check(s.pad_bindings.light == [JOY_BUTTON_B], "B ora è il leggero: %s" % [s.pad_bindings.light])
	runner.check(s.bindings == Settings.DEFAULT_BINDINGS, "la tastiera non cambia")
	s.assign("up", 0, -1, true) # toglie A (che è 0)
	runner.check(not s.pad_bindings.up.has(JOY_BUTTON_A), "A tolto dal salto: %s" % [s.pad_bindings.up])
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.pad_bindings.light == [JOY_BUTTON_B], "salvato: %s" % [again.pad_bindings.light])


func test_ripristina_un_dispositivo_alla_volta() -> void:
	var s := _fresh()
	s.assign("light", 0, KEY_K)
	s.assign("light", 0, JOY_BUTTON_Y, true)
	s.reset_bindings(true)
	runner.check(s.pad_bindings == Settings.DEFAULT_PAD_BINDINGS, "pad ripristinato")
	runner.check(s.bindings.light == [KEY_K], "tastiera intatta: %s" % [s.bindings.light])


func test_nomi_dei_pulsanti() -> void:
	runner.check(Settings.pad_kind("PS5 Controller") == "ps", "PlayStation")
	runner.check(Settings.pad_kind("Nintendo Switch Pro Controller") == "switch", "Switch")
	runner.check(Settings.pad_kind("") == "xbox", "sconosciuto: Xbox")
	runner.check(Settings.pad_label(JOY_BUTTON_A, "ps") == "Croce", "A su PlayStation")
	runner.check(Settings.pad_label(JOY_BUTTON_A, "switch") == "B", "A su Switch")
	runner.check(Settings.pad_label(Settings.axis_input(JOY_AXIS_TRIGGER_RIGHT, true), "ps") == "R2", "grilletto destro")
	runner.check(Settings.pad_label(Settings.axis_input(JOY_AXIS_LEFT_Y, false)) == "LS su", "levetta su")


func test_vibrazione_salvata() -> void:
	var s := _fresh()
	runner.check(s.rumble == Rumble.STRONG, "forte di default")
	s.rumble = Rumble.OFF
	s.save()
	runner.check(Settings.new(AUDIO, PATH).rumble == Rumble.OFF, "spenta ricaricata")
	var cfg := ConfigFile.new()
	cfg.set_value("pad_options", "rumble", 9)
	cfg.save(PATH)
	runner.check(Settings.new(AUDIO, PATH).rumble == Rumble.STRONG, "valore sbagliato: default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_scudo_nuovo_con_preferenze_vecchie() -> void:
	# Preferenze salvate prima dello scudo (#109): la schivata aveva anche i grilletti
	var cfg := ConfigFile.new()
	var triggers := [Settings.axis_input(JOY_AXIS_TRIGGER_LEFT, true), Settings.axis_input(JOY_AXIS_TRIGGER_RIGHT, true)]
	cfg.set_value("pad", "dodge", [JOY_BUTTON_LEFT_SHOULDER] + triggers)
	cfg.set_value("keys", "dodge", [KEY_L, KEY_I])
	cfg.save(PATH)
	var s := Settings.new(AUDIO, PATH)
	runner.check(s.pad_bindings.shield == triggers, "scudo sui grilletti: %s" % [s.pad_bindings.shield])
	runner.check(s.pad_bindings.dodge == [JOY_BUTTON_LEFT_SHOULDER], "schivata senza grilletti: %s" % [s.pad_bindings.dodge])
	runner.check(s.bindings.shield == [KEY_I] and s.bindings.dodge == [KEY_L], "I passa allo scudo: %s %s" % [s.bindings.shield, s.bindings.dodge])
