# Predizione del proprio lottatore (E17)
extends RefCounted

var runner
const Main := preload("res://scripts/main.gd")


func test_numero_dell_input_e_il_tick_locale() -> void:
	runner.check(Main.local_tick(1000, 60.0) == 60, "1 s a 60 tick/s: 60, avuto %s" % Main.local_tick(1000, 60.0))
	runner.check(Main.local_tick(1016, 60.0) == 60 and Main.local_tick(1017, 60.0) == 61, "si passa al tick dopo a 1016,7 ms")


# E17 passo 3: movement.gd rigioca le tracce della fisica TypeScript (src/shared/predictionTraces.ts)
const KEYS := {"l": "left", "r": "right", "j": "jump", "d": "down"}
const FIELDS := ["x", "y", "vx", "vy", "onGround", "facing", "jumps", "coyote", "rising", "drop", "jumpBuffer"]


func _input(keys: String) -> Dictionary:
	var input := {"left": false, "right": false, "jump": false, "down": false}
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
		var m := PredictMovement.new(game.fighter, float(game.input.bufferMs), t.stats, t.solids, t.platforms)
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
