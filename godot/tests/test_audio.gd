# Campioni registrati e ripiego al sintetizzatore (audio.gd, E13 passo 2)
extends RefCounted

var runner

const Audio := preload("res://scripts/audio.gd")


func _audio(files := {}) -> Node:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	game.audioFiles = files
	var a: Node = Audio.new()
	a.setup(game)
	return a


func test_la_variante_non_si_ripete_mai_due_volte_di_fila() -> void:
	var seen := {}
	var last := -1
	for roll in 200:
		var i := Audio.pick_variant(3, last, hash(roll))
		runner.check(i != last, "variante %d ripetuta" % i)
		runner.check(i >= 0 and i < 3, "variante %d fuori" % i)
		seen[i] = true
		last = i
	runner.check(seen.size() == 3, "escono tutte e tre")
	runner.check(Audio.pick_variant(1, 0, 5) == 0, "una sola variante")


func test_senza_file_suona_la_ricetta() -> void:
	var a := _audio()
	runner.check(a.stream_for("hitHeavy") is AudioStreamWAV, "suono sintetizzato")
	a.free()


func test_un_file_che_manca_torna_alla_ricetta() -> void:
	var a := _audio({"sfx": {"hitHeavy": ["assets/sfx/non-esiste_1.ogg"]}, "music": {"lobby": ["assets/music/non-esiste.ogg"]}})
	runner.check(a.stream_for("hitHeavy") is AudioStreamWAV, "ricetta al posto del file mancante")
	a.play_music("lobby") # senza file e con la musica sintetizzata non ancora pronta: non succede niente
	runner.check(a.music_track() == "lobby", "traccia ricordata")
	a.free()


func test_con_i_campioni_alterna_le_varianti() -> void:
	var a := _audio()
	var one := AudioStreamWAV.new()
	var two := AudioStreamWAV.new()
	a._files["light"] = [one, two]
	var prev: AudioStream = a.stream_for("light")
	for i in 10:
		var next: AudioStream = a.stream_for("light")
		runner.check(next != prev, "due varianti si alternano")
		runner.check(next == one or next == two, "solo i campioni")
		prev = next
	a.free()
