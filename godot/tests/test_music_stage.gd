# Arena musicale (#423): le piattaforme a chiavi e a finestre come in physics/elements.ts, e il brano a tempo
extends RefCounted

var runner

const StageMotion := preload("res://scripts/stage_motion.gd")
const Audio := preload("res://scripts/audio.gd")


func test_chiavi_come_la_fisica() -> void:
	var m := {"width": 100, "path": [{"x": 100, "y": 500}, {"x": 100, "y": 300}], "periodMs": 4000,
		"keys": [[0, 100, 500], [1000, 100, 500], [1140, 100, 300]]}
	runner.check(StageMotion.mover_position(m, 500).y == 500.0, "ferma fino alla nota")
	runner.check(is_equal_approx(StageMotion.mover_position(m, 1070).y, 400.0), "a metà della scivolata")
	runner.check(StageMotion.mover_position(m, 1140).y == 300.0, "all'altezza della nota")
	# Dopo l'ultima chiave va verso la prima del giro dopo: a metà strada tra 1140 e 4000
	runner.check(is_equal_approx(StageMotion.mover_position(m, 2570).y, 400.0), "torna al primo posto per il giro dopo")
	runner.check(StageMotion.mover_position(m, 4500) == StageMotion.mover_position(m, 500), "il giro ricomincia")


func test_finestre_e_avviso() -> void:
	var m := {"width": 90, "path": [{"x": 300, "y": 300}, {"x": 300, "y": 300}], "periodMs": 4000, "on": [[500, 1400], [3000, 3900]]}
	runner.check(not StageMotion.mover_on(m, 400) and StageMotion.mover_on(m, 500), "si accende con la nota")
	runner.check(not StageMotion.mover_on(m, 1400), "e si spegne alla fine della finestra")
	runner.check(StageMotion.mover_on(m, 7100), "anche ai giri dopo")
	runner.check(is_equal_approx(StageMotion.mover_next_on(m, 2800), 200.0), "l'avviso sa quanto manca")
	runner.check(is_equal_approx(StageMotion.mover_next_on(m, 3950), 550.0), "anche a cavallo del giro")
	runner.check(StageMotion.mover_on({"periodMs": 1000}, 10), "senza finestre c'è sempre")


func test_fuori_tempo_sul_giro() -> void:
	runner.check(is_equal_approx(Audio.song_drift(1.0, 1.05, 32.0), 0.05), "un po' indietro")
	runner.check(is_equal_approx(Audio.song_drift(0.02, 31.98, 32.0), 0.04), "tra la fine e l'inizio del giro è vicino")


func test_sala_prove_nei_dati() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var stage: Dictionary = game.stages.musica
	runner.check(stage.song is Dictionary and game.audioFiles.music.has(stage.song.id), "il brano dell'arena è tra i file audio")
	for m: Dictionary in stage.movers:
		runner.check(m.kind == "nota" and float(m.periodMs) == float(stage.song.lengthMs), "ogni piattaforma gira col brano")


func test_bottoni_come_la_fisica() -> void:
	var pads := [
		{"sound": "cassa", "cooldownMs": 5000, "effect": {"group": "basso", "durationMs": 2000, "dy": -100}},
		{"sound": "accordo", "cooldownMs": 5000, "effect": {"group": "melodia", "durationMs": 2000, "on": true}},
	]
	var lift := {"group": "basso"}
	var key := {"group": "melodia"}
	var pressed := [1000, null]
	runner.check(StageMotion.pad_fx(lift, 900, pads, pressed, 250).dy == 0.0, "prima niente")
	runner.check(is_equal_approx(StageMotion.pad_fx(lift, 1125, pads, pressed, 250).dy, -50.0), "sale piano")
	runner.check(is_equal_approx(StageMotion.pad_fx(lift, 2000, pads, pressed, 250).dy, -100.0), "in alto")
	runner.check(StageMotion.pad_fx(lift, 3000, pads, pressed, 250).dy == 0.0, "finito")
	runner.check(not StageMotion.pad_fx(key, 2000, pads, pressed, 250).on, "l'accordo non premuto non accende")
	runner.check(StageMotion.pad_fx(key, 1500, pads, [null, 1000], 250).on, "premuto accende i tasti")
	runner.check(StageMotion.pad_charge(pads[0], null, 0) == 1.0, "mai premuto: carico")
	runner.check(is_equal_approx(StageMotion.pad_charge(pads[0], 1000, 3500), 0.5), "a metà dell'attesa")


func test_sala_prove_ha_i_bottoni() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var pads: Array = game.stages.musica.get("pads", [])
	runner.check(pads.size() == 3, "tre bottoni")
	runner.check(game.get("pad") is Dictionary and game.pad.has("rampMs"), "i numeri dei bottoni in game.json")
