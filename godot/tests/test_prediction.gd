# Predizione del proprio lottatore (E17)
extends RefCounted

var runner
const Main := preload("res://scripts/main.gd")


func test_numero_dell_input_e_il_tick_locale() -> void:
	runner.check(Main.local_tick(1000, 60.0) == 60, "1 s a 60 tick/s: 60, avuto %s" % Main.local_tick(1000, 60.0))
	runner.check(Main.local_tick(1016, 60.0) == 60 and Main.local_tick(1017, 60.0) == 61, "si passa al tick dopo a 1016,7 ms")


# E17 passo 3: movement.gd rigioca le tracce della fisica TypeScript (src/shared/predictionTraces.ts)
const KEYS := {"l": "left", "r": "right", "j": "jump", "d": "down", "x": "dodge"}
const FIELDS := ["x", "y", "vx", "vy", "onGround", "facing", "jumps", "coyote", "rising", "drop", "jumpBuffer",
	"dashing", "dash", "tapDir", "tapTimer", "tapHold", "dodge", "dodgeCooldown", "airDodge", "dodgeBuffer"]


func _input(keys: String) -> Dictionary:
	var input := {"left": false, "right": false, "jump": false, "down": false, "dodge": false}
	for k in keys:
		input[KEYS[k]] = true
	return input


func _differs(a: Variant, b: Variant) -> bool:
	if a is bool or b is bool:
		return bool(a) != bool(b)
	return absf(float(a) - float(b)) > 0.01


func test_il_movimento_rigioca_le_tracce() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var traces: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/prediction-traces.json"))
	runner.check(traces.size() >= 4, "servono le tracce: npm run export:godot")
	var dt := 1000.0 / float(game.tickRate)
	for t in traces:
		var m := PredictMovement.new(game, t.stats, t.solids, t.platforms)
		var s := PredictMovement.state_from(t.start, t.start, _input(""))
		var i := 0
		for tick in t.ticks:
			m.set_input(s, _input(tick.input))
			m.step(s, dt)
			for field in FIELDS:
				if _differs(s[field], tick.state[field]):
					runner.check(false, "%s, tick %d, %s: atteso %s, avuto %s" % [t.stage, i, field, tick.state[field], s[field]])
					return
			i += 1


# E17 passo 4: il predittore rigioca dal server i tick che il server non ha ancora visto
func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func _predictor(game: Dictionary) -> Predictor:
	var pr := Predictor.new()
	pr.setup(game)
	pr.set_stage(game.stages.palco)
	return pr


func _server_me(game: Dictionary, seq: int, ticks: int, extra := {}) -> Dictionary:
	var ground: float = game.stages.palco.solids[0].y
	var p := {"id": "me", "characterId": "default", "x": 640.0, "y": ground, "vx": 0.0, "vy": 0.0, "facing": 1,
		"onGround": true, "attack": null, "ledge": null, "grabbedBy": null, "hitstun": false, "respawning": false,
		"predict": {"seq": seq, "ticks": ticks, "jumps": 2, "coyote": 0, "rising": false, "drop": 0, "jumpBuffer": 0}}
	p.merge(extra, true)
	return p


func _ms(tick: int) -> float:
	return tick * 1000.0 / 60.0 + 1.0


func test_il_predittore_va_avanti_con_i_tasti_non_ancora_visti() -> void:
	var game := _game()
	var pr := _predictor(game)
	var right := {"left": false, "right": true, "jump": false, "down": false}
	pr.record_input(right, 100)
	pr.on_server(_server_me(game, 100, 2), _ms(110))
	var s: Variant = pr.sample(_ms(110))
	# Il server ha fatto 2 tick con la destra, qui se ne rigiocano altri 9 (102..110): x cresce di 380/60 a tick
	var step: float = float(game.fighter.groundSpeed) / 60.0
	runner.check(s != null and absf(s.x - (640.0 + 8.0 * step)) < step, "atteso circa %s, avuto %s" % [640.0 + 9.0 * step, s])
	runner.check(s.onGround and s.facing == 1, "a terra e girato a destra")


func test_il_salto_si_vede_subito() -> void:
	var game := _game()
	var pr := _predictor(game)
	pr.record_input({"jump": false}, 100)
	pr.record_input({"jump": true}, 105) # premuto, il server non lo sa ancora
	pr.on_server(_server_me(game, 100, 4), _ms(106))
	var s: Variant = pr.sample(_ms(108))
	runner.check(s != null and not s.onGround and s.vy < 0, "il salto parte prima che il server lo veda: %s" % [s])


func test_fuori_dal_movimento_decide_il_server() -> void:
	var game := _game()
	var pr := _predictor(game)
	pr.on_server(_server_me(game, 100, 2, {"attack": "light"}), _ms(104))
	runner.check(pr.sample(_ms(104)) == null, "attacco in corso: niente predizione")
	pr.on_server(_server_me(game, 100, 2, {"hitstun": true}), _ms(104))
	runner.check(pr.sample(_ms(104)) == null, "colpito: niente predizione")
	var old := _server_me(game, 100, 2)
	old.erase("predict")
	pr.on_server(old, _ms(104))
	runner.check(pr.sample(_ms(104)) == null, "server senza predict: niente predizione")
	pr.on_server(_server_me(game, 100, 2), _ms(200))
	runner.check(pr.sample(_ms(200)) == null, "troppo indietro rispetto al server: niente predizione")
	pr.set_stage(game.stages.fabbrica)
	pr.on_server(_server_me(game, 100, 2), _ms(104))
	runner.check(pr.sample(_ms(104)) == null, "arena con ascensori: niente predizione")


func test_un_attacco_premuto_ferma_la_predizione() -> void:
	var game := _game()
	var pr := _predictor(game)
	pr.record_input({"light": false}, 100)
	pr.record_input({"light": true}, 103)
	pr.on_server(_server_me(game, 100, 2), _ms(104))
	runner.check(pr.sample(_ms(104)) == null, "il server sta per far partire un attacco che il port non fa")


func test_la_correzione_si_spalma() -> void:
	var game := _game()
	var pr := _predictor(game)
	pr.record_input({}, 100)
	pr.on_server(_server_me(game, 100, 2), _ms(104), Vector2(600, game.stages.palco.solids[0].y))
	var first: Variant = pr.sample(_ms(104))
	runner.check(absf(first.x - 600.0) < 1.0, "subito si resta dove si era: %s" % [first.x])
	var later: Variant = pr.sample(_ms(104) + 500.0)
	runner.check(absf(later.x - 640.0) < 1.0, "dopo mezzo secondo si è sul previsto: %s" % [later.x])
	pr.enabled = false
	pr.on_server(_server_me(game, 100, 2), _ms(104))
	runner.check(pr.sample(_ms(104)) == null, "opzione spenta: niente predizione")


# E17 passo 5: smettere di predire non fa saltare indietro il lottatore
func test_quando_si_smette_di_predire_non_si_salta_indietro() -> void:
	var game := _game()
	var pr := _predictor(game)
	pr.record_input({"right": true}, 100)
	pr.on_server(_server_me(game, 100, 2), _ms(118))
	var predicted: Variant = pr.sample(_ms(118))
	pr.on_server(_server_me(game, 100, 2, {"attack": "light"}), _ms(119))
	var behind := _server_me(game, 100, 2, {"attack": "light"}) # il server è indietro di un viaggio di rete
	var first: Variant = pr.sample(_ms(119), behind)
	runner.check(absf(first.x - predicted.x) < 2.0, "si riparte da dove si era (%s), non dal server (%s)" % [first.x, behind.x])
	var later: Variant = pr.sample(_ms(119) + 500.0, behind)
	runner.check(absf(later.x - behind.x) < 1.0, "poi si arriva al server: %s" % [later.x])


func test_scatto_e_schivata_si_predicono() -> void:
	var game := _game()
	var pr := _predictor(game)
	pr.record_input({"dodge": true}, 103)
	pr.on_server(_server_me(game, 100, 2, {"dashing": true}), _ms(104))
	runner.check(pr.is_active(), "lo scatto non spegne la predizione")
	pr.on_server(_server_me(game, 100, 2), _ms(104))
	runner.check(pr.is_active(), "la schivata premuta non spegne la predizione")
