# Dojo: l'elenco delle prove di un personaggio (combo, speciali, mosse di tutti) e i tasti della dimostrazione
extends RefCounted

var runner

const Dojo := preload("res://scripts/dojo.gd")
const KEYS := {"light": "J", "heavy": "K", "special": "U", "up": "W", "down": "S", "left": "A", "right": "D", "run": "Maiusc"}


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func test_prima_le_combo_del_personaggio() -> void:
	var game := _game()
	var lessons := Dojo.lessons_for(game, "orsoblu", KEYS)
	var combos: Array = game.characters.orsoblu.combos
	runner.check(lessons[0].section == "Combo" and lessons[0].name == combos[0].name, "prima la prima combo: %s" % [lessons[0]])
	runner.check(lessons[0].pick == {"combo": 0}, "si chiede per indice: %s" % [lessons[0].pick])
	runner.check(lessons[0].moves.size() == combos[0].steps.size(), "un colpo per passo: %s" % [lessons[0].moves])
	runner.check(lessons[0].keys.contains("  →  "), "i tasti in fila: %s" % lessons[0].keys)


func test_speciali_e_mosse_di_tutti() -> void:
	var game := _game()
	var lessons := Dojo.lessons_for(game, "bonobot", KEYS)
	var names := lessons.map(func(l): return l.name)
	runner.check(str(game.characters.bonobot.specials.neutral.name) in names, "la speciale neutra di Bonobot: %s" % [names])
	var up: Array = lessons.filter(func(l): return l.pick == {"move": "lightUp"})
	runner.check(up.size() == 1 and up[0].keys == "W+J", "leggero in su: %s" % [up])
	runner.check(lessons.all(func(l): return l.moves.size() >= 1), "ogni voce ha almeno una mossa")


func test_tasti_della_dimostrazione() -> void:
	# light è il bit 5, down il 3 (DEMO_KEYS in src/shared/dojo.ts)
	runner.check(Dojo.mask_actions((1 << 5) | (1 << 3)) == ["down", "light"], "%s" % [Dojo.mask_actions((1 << 5) | (1 << 3))])
	runner.check(Dojo.mask_actions(0).is_empty(), "nessun tasto")
