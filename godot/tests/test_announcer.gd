# Annunciatore (E13 passo 4): coda a priorità e momenti in cui parla
extends RefCounted

var runner

const Queue := preload("res://scripts/announcer_queue.gd")
const Audio := preload("res://scripts/audio.gd")
const PRIO := {"go": 1, "tenSeconds": 1, "lastLife": 2, "game": 3, "draw": 3}


func test_non_parla_sopra_se_stesso_e_poi_dice_la_piu_importante() -> void:
	var q := Queue.new(PRIO, 3, 1500)
	runner.check(q.push("go", 0), "da zitto parla subito")
	runner.check(not q.push("tenSeconds", 100), "mentre parla aspetta")
	runner.check(not q.push("lastLife", 200), "anche questa aspetta")
	runner.check(not q.push("lastLife", 250), "la stessa frase non si mette due volte")
	runner.check(q.waiting() == 2, "due in coda, non %d" % q.waiting())
	runner.check(q.finished(800) == "lastLife", "prima la più importante")
	runner.check(q.finished(1200) == "tenSeconds", "poi l'altra")
	runner.check(q.finished(1600) == "", "poi zitto")


func test_game_interrompe_tutto_e_dopo_non_si_dice_altro() -> void:
	var q := Queue.new(PRIO, 3, 1500)
	q.push("go", 0)
	q.push("tenSeconds", 10)
	runner.check(q.push("game", 20), "GAME! parla subito")
	runner.check(q.speaking == "game", "e si sente lui")
	runner.check(q.waiting() == 0, "la coda è vuota")
	runner.check(not q.push("lastLife", 30), "dopo GAME! niente ultima vita")
	runner.check(q.finished(900) == "", "e niente dopo")


func test_una_frase_vecchia_in_coda_si_salta() -> void:
	var q := Queue.new(PRIO, 3, 1500)
	q.push("go", 0)
	q.push("tenSeconds", 100)
	runner.check(q.finished(2000) == "", "dopo 1,9 s è fuori tempo")


func test_dieci_secondi_solo_quando_si_scende_sotto_la_soglia() -> void:
	runner.check(Audio.crosses_warning(10050, 9983, 10000), "si scende sotto")
	runner.check(not Audio.crosses_warning(9983, 9966, 10000), "già sotto: non si ripete")
	runner.check(not Audio.crosses_warning(-1, 9000, 10000), "primo snapshot già sotto (si entra a metà)")
	runner.check(not Audio.crosses_warning(-1, -1, 10000), "partita senza tempo")
	runner.check(not Audio.crosses_warning(10050, 0, 10000), "tempo finito")


func test_senza_file_l_annunciatore_tace_e_con_i_file_parla_al_momento_giusto() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	game.audioFiles = {}
	var a: Node = Audio.new()
	a.setup(game)
	a.on_event({"type": "matchStart"})
	runner.check(a.announcer_phrase() == "", "senza file non dice niente")
	var voice := AudioStreamWAV.new()
	for p in PRIO:
		a._phrases[p] = [voice]
	a.on_event({"type": "matchStart"})
	runner.check(a.announcer_phrase() == "go", "Via! all'inizio, non '%s'" % a.announcer_phrase())
	runner.check(a.music_duck_db() < 0, "la musica scende quando parla")
	a._on_phrase_finished()
	a.on_event({"type": "ko", "x": 0, "stocksLeft": 2})
	runner.check(a.announcer_phrase() == "", "con due vite non c'è l'ultima vita")
	a.on_event({"type": "ko", "x": 0, "stocksLeft": 1})
	runner.check(a.announcer_phrase() == "lastLife", "ultima vita")
	a._on_phrase_finished()
	a.on_snapshot({"timeLeftMs": 10020, "winnerId": null})
	a.on_snapshot({"timeLeftMs": 9990, "winnerId": null})
	runner.check(a.announcer_phrase() == "tenSeconds", "dieci secondi")
	a.on_event({"type": "matchEnd", "winnerId": "x"})
	runner.check(a.announcer_phrase() == "game", "GAME! interrompe")
	a.free()
