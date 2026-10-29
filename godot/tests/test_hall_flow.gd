# Sala d'attesa 3D lato main.gd (hall_flow.gd) e i suoi suoni (audio.gd): chi chiede la sala, welcome e stage, punti
extends RefCounted

var runner

const HallFlow := preload("res://scripts/hall_flow.gd")
const Audio := preload("res://scripts/audio.gd")


func test_chi_chiede_la_sala() -> void:
	runner.check(HallFlow.wants_hall({"hall": true}), "dalla lobby")
	runner.check(HallFlow.wants_hall({"hall": "1"}), "dall'indirizzo")
	runner.check(not HallFlow.wants_hall({"hall": "0"}), "--hall=0 entra dritto in partita")
	runner.check(not HallFlow.wants_hall({}), "senza niente no (prova del primo avvio, client di prima)")
	runner.check(not HallFlow.wants_hall({"hall": true, "tutorial": true}), "il tutorial no")
	runner.check(not HallFlow.wants_hall({"hall": true, "challenge": {"id": "x"}}), "le sfide no")
	runner.check(HallFlow.wants_hall({"hall": true, "challenge": {}, "gym": true}), "gym resta da prima: non conta")


func test_welcome_e_stage() -> void:
	runner.check(HallFlow.phase_of({"phase": "hall"}) == "hall", "in sala")
	runner.check(HallFlow.phase_of({"phase": "match"}) == "match", "in partita")
	runner.check(HallFlow.phase_of({}) == "match", "server di prima: si gioca")
	var welcome := {"id": "p1", "room": "serata", "stageId": "palco", "rules": {"mode": "ffa"}, "hall": true}
	var w := HallFlow.stage_welcome(welcome, {"stageId": "padova", "rules": {"mode": "teams", "teamCount": 2}, "stage": {"id": "padova"}})
	runner.check(w.id == "p1" and w.room == "serata", "id e stanza dal welcome: %s" % [w])
	runner.check(w.stageId == "padova" and w.rules.mode == "teams" and w.stage.id == "padova", "arena e regole nuove: %s" % [w])
	runner.check(welcome.stageId == "palco", "il welcome resta com'era")
	runner.check(HallFlow.stage_welcome({}, {"stageId": "x"}).rules.mode == "ffa", "senza regole: tutti contro tutti")


func test_punti_e_ritorno_in_sala() -> void:
	var changes := [{"id": "a", "rating": 1163, "delta": 18, "tier": "Gorilla", "rank": 2}, {"id": "b", "rating": 990, "delta": -12, "tier": "Babbuino", "rank": null}]
	runner.check(HallFlow.my_rating(changes, "b").delta == -12, "i miei punti")
	runner.check(HallFlow.my_rating(changes, "").is_empty() and HallFlow.my_rating(changes, "z").is_empty(), "nessuno se non ci sono")
	runner.check(HallFlow.rating_toast(changes[0]) == "Gorilla · 1163 punti (+18) · 2° in classifica", HallFlow.rating_toast(changes[0]))
	runner.check(HallFlow.rating_toast(changes[1]) == "Babbuino · 990 punti (-12)", HallFlow.rating_toast(changes[1]))
	runner.check(HallFlow.delta_text(0) == "±0", "pari")
	runner.check(HallFlow.return_note(9200).ends_with("tra 10 s"), HallFlow.return_note(9200))
	runner.check(HallFlow.return_note(-5) == "Si torna in sala...", "a tempo scaduto")


func test_suoni_della_sala() -> void:
	for type in ["hop", "land", "bounce", "shove", "vote", "pick", "gong", "throne", "bot", "join", "leave", "countdown", "cancel", "go"]:
		runner.check(not Audio.hall_cue({"type": type, "id": "a", "targets": [], "added": true}).is_empty(), "%s suona" % type)
	runner.check(Audio.hall_cue({"type": "boh"}).is_empty(), "un evento che non conosce tace")
	runner.check(Audio.hall_cue({"type": "gong", "id": "x"}).get("loud", false), "il gong si sente forte anche se lo suona un altro")
	runner.check(Audio.hall_cue({"type": "bot", "added": false}).sound != Audio.hall_cue({"type": "bot", "added": true}).sound, "bot che arriva e che va via")
