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


func test_al_massimo_tre_suoni_uguali_insieme() -> void:
	var recent := []
	var started := 0
	for i in 6: # sei colpi nello stesso istante
		if Audio.may_start(recent, 1000, 3, 60):
			recent.append(1000)
			started += 1
	runner.check(started == 3, "partiti %d" % started)
	runner.check(Audio.may_start(recent, 1060, 3, 60), "dopo 60 ms si riparte")
	runner.check(recent.is_empty(), "gli avvii vecchi si dimenticano")


func test_il_ko_abbassa_la_musica() -> void:
	var a := _audio()
	var bus := AudioServer.get_bus_index("Musica")
	a.set_volumes(1.0, 1.0, 0.5, true)
	var before := AudioServer.get_bus_volume_db(bus)
	a.on_event({"type": "ko", "id": "a", "x": 100, "y": 100, "stocksLeft": 2})
	runner.check(a.music_duck_db() == -8.0, "musica abbassata di 8 dB")
	runner.check(is_equal_approx(AudioServer.get_bus_volume_db(bus), before - 8.0), "sul bus")
	a.set_volumes(1.0, 1.0, 0.5, true) # cambiare il volume nelle opzioni non perde l'abbassamento
	runner.check(is_equal_approx(AudioServer.get_bus_volume_db(bus), before - 8.0), "resta abbassata")
	a.free()


func test_presa_e_lancio_hanno_il_loro_suono() -> void:
	var a: Node = _audio()
	for name in ["grab", "throw", "counter"]:
		runner.check(a.stream_for(name) is AudioStreamWAV, "manca il suono %s" % name)
	# Gli eventi della presa non danno errori
	for e in [{"type": "grab", "id": "a", "targetId": "b", "x": 0, "y": 0}, {"type": "grabRelease", "id": "a", "targetId": "b"}, {"type": "attack", "id": "a", "kind": "throwUp"}, {"type": "hit", "kind": "grab", "x": 0, "percent": 3}, {"type": "counter", "id": "a", "attackerId": "b", "x": 0, "y": 0}, {"type": "attack", "id": "a", "kind": "specialDown"}]:
		a.on_event(e)
	a.free()


func test_proiettili_e_carica_hanno_il_loro_suono() -> void:
	var a: Node = _audio()
	for name in ["projectile", "projectilePop", "charge", "chargeFull"]:
		runner.check(a.stream_for(name) is AudioStreamWAV, "manca il suono %s" % name)
	runner.check(Audio.charge_cue(0.0, 0.05) == "charge", "la carica parte")
	runner.check(Audio.charge_cue(0.5, 0.6) == "", "mentre sale non si ripete")
	runner.check(Audio.charge_cue(0.95, 1.0) == "chargeFull", "carica piena")
	runner.check(Audio.charge_cue(1.0, 1.0) == "", "piena una volta sola")
	runner.check(Audio.charge_cue(1.0, 0.0) == "", "rilasciata: silenzio")
	for e in [{"type": "projectile", "id": "a", "projectileId": 1, "x": 0, "y": 0}, {"type": "projectileEnd", "projectileId": 1, "reason": "wall", "x": 0, "y": 0}]:
		a.on_event(e)
	a.on_snapshot({"timeLeftMs": null, "winnerId": null, "players": [{"id": "a", "x": 0, "charge": 0.3}]})
	a.free()


func test_accordi_per_nome() -> void:
	# Il giro di sempre (La minore, Fa, Do, Sol), in Hz come in music.ts
	var old := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [261.6, 329.6, 392.0], [196.0, 246.9, 293.7]]
	for i in old.size():
		var hz := Audio.chord_hz(Audio.DEFAULT_CHORDS[i])
		for j in 3:
			runner.check(absf(hz[j] - old[i][j]) < 0.2, "%s nota %d: %.1f invece di %.1f" % [Audio.DEFAULT_CHORDS[i], j, hz[j], old[i][j]])
	runner.check(absf(Audio.chord_hz("Bbm")[0] - 233.1) < 0.2, "Si bemolle")
	runner.check(absf(Audio.chord_hz("F#")[0] - 185.0) < 0.2, "Fa diesis")
	runner.check(Audio.chord_hz("H").is_empty() and Audio.chord_hz("Cmaj7").is_empty() and Audio.chord_hz("").is_empty(), "nomi sbagliati")


func test_preset_incompleto_prende_la_musica_di_sempre() -> void:
	var audio := {"musicBpm": 132, "musicBpmMin": 70, "musicBpmMax": 190}
	var p := Audio.normalize_music({"bpm": 400, "chords": ["X", "Dm"], "lead": "organo"}, audio)
	runner.check(p.bpm == 190.0 and p.chords == ["Dm"] and p.lead == "square", "%s" % p)
	var d := Audio.normalize_music({}, audio)
	runner.check(d.bpm == 132.0 and d.chords == Audio.DEFAULT_CHORDS and d.lead == "square", "%s" % d)


func test_ogni_arena_la_sua_musica() -> void:
	var a := _audio()
	var game: Dictionary = a.game
	runner.check(game.stages.isole.has("music") and not game.stages.palco.has("music"), "Le Isole hanno la loro musica, Il Palco no")
	a.set_stage_music(game.stages.isole.music)
	a.play_music("match")
	runner.check(not a.stage_music_ready(), "si calcola un pezzo per frame")
	for i in 100:
		a._process(0.016)
	runner.check(a.stage_music_ready(), "pronta")
	var isole: AudioStream = a._music.stream
	runner.check(isole is AudioStreamWAV and isole != a._synth_music, "in partita suona la musica delle Isole")
	runner.check(a._synth_music != null, "anche quella di sempre è pronta")
	a.set_stage_music(game.stages.palco.get("music"))
	runner.check(a._music.stream == a._synth_music, "su Il Palco torna quella di sempre")
	a.set_stage_music(game.stages.isole.music)
	runner.check(a._music.stream == isole, "la seconda volta è già pronta")
	a.play_music("lobby")
	runner.check(a._music.stream == a._synth_music, "nella lobby quella di sempre")
	a.free()
