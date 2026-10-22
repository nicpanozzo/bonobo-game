# Pezzi a tempo (#433): ci sono o no come pieceOn() in physics/timed.ts, sfumano nel disegno e la predizione li segue
extends RefCounted

var runner

const StageMotion := preload("res://scripts/stage_motion.gd")


func test_ci_sono_solo_nelle_finestre() -> void:
	var p := {"x": 0, "y": 400, "width": 200, "on": [[1000, 2000], [5000, 6000]]}
	runner.check(not PredictMovement.piece_on(p, 999) and PredictMovement.piece_on(p, 1000), "compare all'inizio della finestra")
	runner.check(not PredictMovement.piece_on(p, 2000), "e sparisce alla fine, esclusa")
	runner.check(PredictMovement.piece_on(p, 5500) and not PredictMovement.piece_on(p, 7000), "seconda finestra, poi più niente")
	runner.check(PredictMovement.piece_on({"x": 0}, 1e9), "senza finestre c'è sempre")


func test_sfumano_entrando_e_uscendo() -> void:
	var p := {"on": [[1000, 2000]]}
	var fade := StageMotion.PIECE_FADE_MS
	runner.check(StageMotion.piece_alpha(p, 1000 - fade - 1) == 0.0, "prima non si vede")
	runner.check(StageMotion.piece_alpha(p, 1000 - fade / 2.0) > 0.0 and not PredictMovement.piece_on(p, 1000 - fade / 2.0), "si annuncia prima di esserci")
	runner.check(StageMotion.piece_alpha(p, 1500) == 1.0, "piena in mezzo")
	runner.check(StageMotion.piece_alpha(p, 2000) == 0.0, "sparita alla fine")
	runner.check(StageMotion.piece_alpha({}, 0) == 1.0, "i pezzi di sempre restano pieni")


func test_la_predizione_cade_quando_la_piattaforma_sparisce() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var plat := {"x": 400, "y": 450, "width": 300, "on": [[0, 500]]}
	var m := PredictMovement.new(game, game.characters["default"].stats, [], [plat])
	var p := {"x": 550.0, "y": 450.0, "vx": 0.0, "vy": 0.0, "onGround": true, "facing": 1, "attack": null}
	var s := PredictMovement.state_from(p, {"jumps": 2, "coyote": 0, "rising": false, "drop": 0, "jumpBuffer": 0}, {})
	s.stageMs = 400.0
	m.step(s, 1000.0 / 60.0)
	runner.check(s.onGround and s.y == 450.0, "ci sta sopra finché c'è")
	s.stageMs = 500.0
	for i in 5:
		m.step(s, 1000.0 / 60.0)
	runner.check(not s.onGround and s.y > 450.0, "sparita: si cade, come sul server (%s)" % [s.y])


func test_i_pezzi_del_premio_ci_sono_solo_per_la_squadra_in_testa() -> void:
	var p := {"x": 0, "y": 400, "width": 200, "on": [[1000, 2000]], "forLeader": 1}
	runner.check(PredictMovement.piece_on(p, 1500, 1), "la squadra in testa li ha")
	runner.check(not PredictMovement.piece_on(p, 1500, 2) and not PredictMovement.piece_on(p, 1500), "l'altra e il pareggio no")
	runner.check(not PredictMovement.piece_on(p, 2500, 1), "e restano nelle loro finestre")
	runner.check(StageMotion.piece_alpha(p, 1500, 1) == 1.0 and StageMotion.piece_alpha(p, 1500, 2) == 0.0, "nel disegno compaiono solo per lei")


func test_la_predizione_usa_i_ponteggi_del_premio() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var plat := {"x": 400, "y": 450, "width": 300, "forLeader": 2}
	var m := PredictMovement.new(game, game.characters["default"].stats, [], [plat])
	var p := {"x": 550.0, "y": 440.0, "vx": 0.0, "vy": 0.0, "onGround": false, "facing": 1, "attack": null}
	var jumps := {"jumps": 2, "coyote": 0, "rising": false, "drop": 0, "jumpBuffer": 0}
	var s := PredictMovement.state_from(p, jumps, {})
	s.prizeTeam = 2
	for i in 10:
		m.step(s, 1000.0 / 60.0)
	runner.check(s.onGround and s.y == 450.0, "con la squadra giusta in testa ci si sta sopra")
	var q := PredictMovement.state_from(p, jumps, {})
	q.prizeTeam = 1
	for i in 10:
		m.step(q, 1000.0 / 60.0)
	runner.check(not q.onGround and q.y > 450.0, "con l'altra si cade attraverso")
