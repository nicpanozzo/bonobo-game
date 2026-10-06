# Suoni e musica, come src/client/render/audio.ts: partono dagli eventi di gioco.
# Qui si decide quale suono va con quale evento; come suona sta nelle ricette qui sotto (synth.gd).
# I suoni registrati da noi (TODO community, #6) potranno sostituire le ricette con un file.
extends Node2D

const PLAYERS := 12 # suoni che possono sovrapporsi
const MUSIC_STEPS_PER_FRAME := 4 # la musica si calcola un pezzo per frame, senza bloccare il gioco
const STEPS := 16 # sedicesimi in una battuta
# Giro di quattro accordi (La minore, Fa, Do, Sol): note in Hz, come in music.ts
const CHORDS := [
	[220.0, 261.6, 329.6],
	[174.6, 220.0, 261.6],
	[261.6, 329.6, 392.0],
	[196.0, 246.9, 293.7],
]

var game: Dictionary
var view_left := 0.0 # per sapere da che lato dello schermo arriva un suono

var _sounds := {} # nome -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer2D] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _music_synth: Synth
var _music_step := 0


func setup(game_data: Dictionary) -> void:
	game = game_data
	for bus in ["Effetti", "Musica"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	set_volumes(game.audio.master, game.audio.sfx, game.audio.music, true)
	for i in PLAYERS:
		var p := AudioStreamPlayer2D.new()
		p.bus = "Effetti"
		p.max_distance = 100000 # niente attenuazione con la distanza, solo destra/sinistra
		p.attenuation = 0
		_pool.append(p)
		add_child(p)
	_music.bus = "Musica"
	add_child(_music)
	_build_sounds()
	var bar: float = 60.0 / game.audio.musicBpm / 4.0 * STEPS
	_music_synth = Synth.new(bar * CHORDS.size())


# Volumi da 0 a 1, come nelle opzioni del gioco web
func set_volumes(master: float, sfx: float, music: float, music_on: bool) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effetti"), linear_to_db(sfx))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), linear_to_db(music))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Musica"), not music_on)


func music_on() -> bool:
	return not AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica"))


func on_event(e: Dictionary) -> void:
	match e.type:
		"attack":
			# Le varianti direzionali (#2) usano il suono del colpo base, un po' più acuto in su e più grave in giù
			var kind: String = e.kind
			var tilt := 0.12 if kind.ends_with("Up") else (-0.12 if kind.ends_with("Down") else 0.0)
			if kind == "recovery":
				_play("doubleJump", {"volume": 0.7}) # il recupero (#11) suona come un doppio salto
			else:
				_play("heavy" if kind.begins_with("heavy") else "light", {"volume": 0.7, "pitch": randf_range(0.95, 1.05) + tilt})
		"hit":
			# Più alta la percentuale del bersaglio, più forte e più grave il colpo
			var strength := minf(1.0, e.percent / game.audio.hitLoudPercent)
			_play("hitHeavy" if str(e.kind).begins_with("heavy") else "hitLight", {"volume": 0.6 + 0.4 * strength, "x": e.x, "pitch": 1.1 - 0.3 * strength})
		"hazard":
			_play("hitHeavy", {"volume": 0.8, "x": e.x, "pitch": 0.8})
		"jump":
			_play("doubleJump" if e.air else "jump", {"volume": 0.6, "x": e.x})
		"land":
			_play("land", {"volume": 0.5, "x": e.x})
		"ko":
			_play("ko", {"x": e.x})
		"checkpoint":
			_play("point", {"volume": 0.5, "pitch": 1.3})
		"flag":
			_play("point")
		"taunt":
			_play("taunt")
		# Oggetti (#17): finché non hanno suoni loro, si riusano quelli che ci sono
		"itemPick":
			_play("point", {"volume": 0.4, "pitch": 1.6})
		"itemThrow":
			_play("light", {"volume": 0.7, "x": e.x, "pitch": 0.8})
		"matchStart":
			_play("start")
		"matchEnd":
			_play("victory")


func _play(name: String, opts := {}) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _sounds[name]
	p.volume_db = linear_to_db(opts.get("volume", 1.0))
	p.pitch_scale = opts.get("pitch", 1.0)
	# Il suono arriva dal lato dello schermo dove succede la cosa (al centro se non ha un punto)
	var w: float = game.world.width
	p.global_position = Vector2(clampf(opts.get("x", view_left + w / 2), view_left, view_left + w), game.world.height / 2.0)
	p.play()


func _process(_delta: float) -> void:
	if _music_step < 0:
		return
	for i in MUSIC_STEPS_PER_FRAME:
		_music_play_step(_music_step)
		_music_step += 1
		if _music_step >= STEPS * CHORDS.size():
			_music.stream = _music_synth.to_stream(true)
			_music.play()
			_music_step = -1 # finita: da qui in poi gira in loop
			return


# Un sedicesimo della musica: cassa, rullante, charleston, basso e accordi (playStep in music.ts)
func _music_play_step(step: int) -> void:
	var s := _music_synth
	var t: float = step * 60.0 / game.audio.musicBpm / 4.0
	var chord: Array = CHORDS[step / STEPS]
	var k := step % STEPS
	if k % 4 == 0:
		s.tone(t, "sine", 140, 40, 0.15, 0.7, true) # cassa
	if k % 8 == 4:
		s.noise(t, "highpass", 1800, 1800, 0.12, 0.25, true) # rullante
	if k % 2 == 1:
		s.noise(t, "highpass", 7000, 7000, 0.03, 0.08, true) # charleston
	if k % 4 == 0 or k == 6 or k == 14:
		s.tone(t, "triangle", chord[0] / 2, chord[0] / 2, 0.18, 0.35, true)
	if k in [0, 3, 6, 10, 12]:
		var f: float = chord[int(k / 3.0) % 3] * 2
		s.tone(t, "square", f, f, 0.09, 0.05, true)


# Le ricette di src/client/audio/sfx.ts
func _build_sounds() -> void:
	var make := func(seconds: float, recipe: Callable) -> AudioStreamWAV:
		var s := Synth.new(seconds)
		recipe.call(s)
		return s.to_stream()
	# Colpo che parte: un fruscio d'aria, più grave per il pesante
	_sounds.light = make.call(0.12, func(s): s.noise(0, "bandpass", 3000, 1200, 0.08, 0.5))
	_sounds.heavy = make.call(0.26, func(s): s.noise(0, "bandpass", 1400, 300, 0.22, 0.7))
	# Colpo a segno: schiocco + tonfo; il pesante ha anche un "boom" basso
	_sounds.hitLight = make.call(0.12, func(s):
		s.noise(0, "lowpass", 5000, 800, 0.09, 0.6)
		s.tone(0, "square", 320, 90, 0.08, 0.25))
	_sounds.hitHeavy = make.call(0.4, func(s):
		s.noise(0, "lowpass", 4000, 200, 0.25, 0.8)
		s.tone(0, "sawtooth", 180, 45, 0.3, 0.45)
		s.tone(0, "sine", 90, 35, 0.35, 0.6))
	_sounds.jump = make.call(0.15, func(s): s.tone(0, "square", 280, 560, 0.12, 0.12))
	_sounds.doubleJump = make.call(0.15, func(s): s.tone(0, "square", 420, 900, 0.12, 0.1))
	_sounds.land = make.call(0.13, func(s): s.noise(0, "lowpass", 900, 120, 0.1, 1.0))
	# Fuori dall'arena: esplosione e fischio che scende
	_sounds.ko = make.call(0.95, func(s):
		s.noise(0, "lowpass", 2500, 60, 0.9, 1.0)
		s.tone(0, "sine", 70, 30, 0.8, 0.9)
		s.tone(0.05, "triangle", 1400, 200, 0.6, 0.25))
	_sounds.taunt = make.call(0.35, func(s):
		s.tone(0, "triangle", 660, 640, 0.12, 0.2)
		s.tone(0.13, "triangle", 880, 860, 0.18, 0.2))
	_sounds.start = make.call(0.45, func(s):
		for i in 4:
			var f: float = [392, 523, 659, 784][i]
			s.tone(i * 0.09, "square", f, f, 0.14, 0.13))
	# Punto in Bandiera: due note che salgono, più brevi della vittoria
	_sounds.point = make.call(0.45, func(s):
		s.tone(0, "square", 659, 659, 0.1, 0.14)
		s.tone(0.1, "square", 988, 988, 0.3, 0.14))
	_sounds.victory = make.call(1.15, func(s):
		var notes := [523, 659, 784, 1047, 784, 1047]
		for i in notes.size():
			s.tone(i * 0.12, "square", notes[i], notes[i], 0.5 if i == 5 else 0.14, 0.14))
