# Le battute dei lottatori (#13): la frase giusta dalla scheda, un fumetto per lottatore, che poi sparisce
extends RefCounted

var runner

const SpeechBubbles := preload("res://scripts/speech_bubbles.gd")


func _game() -> Dictionary:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func test_la_frase_dalla_scheda() -> void:
	var game := _game()
	runner.check(SpeechBubbles.quote(game.characters.coachcartier, "taunt") == "Va bene perdere se sei ricco!", "Electronmaster provoca")
	runner.check(SpeechBubbles.quote(game.characters.lampione, "ko") != "", "Lampione urla al KO")
	runner.check(SpeechBubbles.quote(game.characters["default"], "taunt") == "", "chi non ha battute non dice niente")


func test_un_fumetto_per_lottatore_che_poi_sparisce() -> void:
	var sb := SpeechBubbles.new()
	sb.fixed_now = 1000.0
	sb.say("a", "Viva il comunismo!")
	sb.say("a", "Di nuovo")
	sb.say("b", "")
	runner.check(sb.showing("a") == "Di nuovo", "la frase nuova prende il posto della vecchia")
	runner.check(sb.showing("b") == "", "una frase vuota non apre il fumetto")
	sb.fixed_now = 1000.0 + SpeechBubbles.SHOW_MS + 10
	runner.check(sb.showing("a") == "", "dopo un po' sparisce")
	sb.free()
