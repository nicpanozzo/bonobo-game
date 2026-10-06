# Aggiornamento dell'app (updater.gd, #115): quando scaricare, quando usare il pacchetto già scaricato
extends RefCounted

var runner

const Updater := preload("res://scripts/updater.gd")


func test_versione_della_release() -> void:
	var r := Updater.parse_remote('{"version": 28, "godot": "4.5.1", "size": 1234}')
	runner.check(r == {"version": 28, "godot": "4.5.1", "size": 1234}, "letta: %s" % [r])
	runner.check(Updater.parse_remote("<html>404</html>").is_empty(), "una pagina d'errore non è una versione")
	runner.check(Updater.parse_remote('{"version": 28, "godot": "4.5.1"}').is_empty(), "senza dimensione non si scarica")
	runner.check(Updater.parse_remote('{"version": 28, "godot": "4.5.1", "size": 0}').is_empty(), "pacchetto vuoto")


func test_scarica_solo_se_piu_nuova_e_stesso_motore() -> void:
	var r := {"version": 28, "godot": "4.5.1", "size": 10}
	runner.check(Updater.decide(27, r, "4.5.1") == "download", "più nuova")
	runner.check(Updater.decide(28, r, "4.5.1") == "none", "uguale")
	runner.check(Updater.decide(30, r, "4.5.1") == "none", "più vecchia")
	runner.check(Updater.decide(27, r, "4.6") == "new_app", "motore diverso")
	runner.check(Updater.decide(27, {}, "4.5.1") == "none", "offline")


func test_pacchetto_gia_scaricato() -> void:
	var saved := {"version": 28, "godot": "4.5.1", "size": 10}
	runner.check(Updater.use_saved(27, saved, "4.5.1"), "più nuovo dell'app: si usa")
	runner.check(not Updater.use_saved(29, saved, "4.5.1"), "l'app riscaricata è più nuova: no")
	runner.check(not Updater.use_saved(27, saved, "4.6"), "motore diverso: no")
	runner.check(not Updater.use_saved(27, {}, "4.5.1"), "niente scaricato")


func test_argomenti_per_ripartire() -> void:
	var a := Updater.relaunch_args(PackedStringArray(["--path", "godot", "--main-pack", "/vecchio.pck", "--verbose"]), PackedStringArray(["--room=test"]), "/u/bonobo-game.pck")
	runner.check(a == PackedStringArray(["--main-pack", "/u/bonobo-game.pck", "--verbose", "--", "--room=test"]), "argomenti: %s" % [a])
	var b := Updater.relaunch_args(PackedStringArray(), PackedStringArray(), "/p.pck")
	runner.check(b == PackedStringArray(["--main-pack", "/p.pck"]), "senza argomenti: %s" % [b])


func test_versione_del_motore() -> void:
	runner.check(Engine.get_version_info().string.begins_with(Updater.engine_version()), Updater.engine_version())
