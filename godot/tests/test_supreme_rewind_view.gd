# La suprema che torna indietro (#358): l'orologio mentre carica, l'onda quando torna, solo per la "rewind"
extends RefCounted

var runner

const RewindView := preload("res://scripts/supreme_rewind_view.gd")


func _game() -> Dictionary:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func test_cosa_di_marcomunista() -> void:
	var game := _game()
	var sp: Dictionary = game.characters.marcomunista.supreme
	runner.check(str(sp.type) == "rewind", "Marcomunista ha …COSA?")
	var v := RewindView.new()
	v.fixed_now = 1000.0
	v.start("m", game.characters.marcomunista)
	v.start("b", game.characters.bradipo)
	runner.check(v.phase("m") == "clock", "mentre carica, l'orologio")
	runner.check(v.phase("b") == "", "chi ha un'altra suprema niente")
	v.fixed_now = 1000.0 + float(sp.windupMs) + 10.0
	runner.check(v.phase("m") == "wave", "tornato indietro, l'onda")
	v.fixed_now = 1000.0 + float(sp.windupMs) + RewindView.WAVE_MS + 10.0
	runner.check(v.phase("m") == "", "poi finisce")
	v.free()
