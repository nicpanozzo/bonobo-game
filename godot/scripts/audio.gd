# Suoni e musica, come src/client/render/audio.ts: partono dagli eventi di gioco.
# Qui si decide quale suono va con quale evento. Se c'è un file registrato (E13, game.audioFiles, copiato da
# public/assets/sfx con npm run export:godot) suona quello, con le varianti a rotazione casuale;
# altrimenti la ricetta sintetizzata qui sotto (synth.gd), che resta sempre il ripiego.
extends Node2D

const PLAYERS := 12 # suoni che possono sovrapporsi
const MUSIC_STEPS_PER_FRAME := 4 # la musica si calcola un pezzo per frame, senza bloccare il gioco
const STEPS := 16 # sedicesimi in una battuta
# Giro di quattro accordi della musica di sempre (La minore, Fa, Do, Sol), come in music.ts.
# Le arene possono averne un altro (E12 passo 4, StageSpec.music in stages.ts)
const DEFAULT_CHORDS := ["Am", "F", "C", "G"]
const NOTES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11} # semitoni sopra il Do
const LEAD_VOLUME := {"square": 0.05, "sawtooth": 0.04, "triangle": 0.09, "sine": 0.09} # le onde morbide si sentono meno

var game: Dictionary
var view_left := 0.0 # per sapere da che lato dello schermo arriva un suono

var _sounds := {} # nome -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer2D] = []
var _next := 0
var _files := {} # nome -> Array[AudioStream] dei campioni registrati
var _last := {} # nome -> indice dell'ultima variante suonata
var _music := AudioStreamPlayer.new() # la musica che si sente
var _music_out := AudioStreamPlayer.new() # quella che sta sfumando
var _music_synth: Synth # la musica che si sta calcolando, un pezzo per frame
var _music_step := 0
var _music_chords: Array # accordi in Hz della musica che si sta calcolando
var _synth_music: AudioStreamWAV # la musica sintetizzata di sempre, quando è pronta
var _to_render: Array[Dictionary] = [] # preset da calcolare: il primo è in corso
var _rendered := {} # chiave del preset -> AudioStreamWAV in loop
var _default_key := ""
var _stage_key := "" # preset dell'arena della partita ("" = la musica di sempre)
var _track := "" # "lobby" o "match"
var _music_files := {} # traccia -> AudioStream
var _fade: Tween
var _started := {} # nome -> ms di avvio delle ultime copie (tetto ai suoni uguali)
var _music_volume := 1.0 # volume della musica scelto nelle opzioni, da 0 a 1
var _duck_db := 0.0 # quanto è abbassata adesso la musica (0 = niente)
var _duck: Tween
var _announcer := AudioStreamPlayer.new() # la voce dell'annunciatore, sul bus Voci
var _phrases := {} # frase -> Array[AudioStream] (game.audioFiles.announcer)
var _queue: AnnouncerQueue
var _time_left := -1.0 # tempo rimasto nell'ultimo snapshot, ms (-1 = senza limite)
var _charges := {} # id -> carica della speciale nell'ultimo snapshot (E10)

const AnnouncerQueue := preload("res://scripts/announcer_queue.gd")


func setup(game_data: Dictionary) -> void:
	game = game_data
	for bus in ["Effetti", "Musica", "Voci"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	set_volumes(game.audio.master, game.audio.sfx, game.audio.music, true, game.audio.get("voices", 0.8))
	for i in PLAYERS:
		var p := AudioStreamPlayer2D.new()
		p.bus = "Effetti"
		p.max_distance = 100000 # niente attenuazione con la distanza, solo destra/sinistra
		p.attenuation = 0
		_pool.append(p)
		add_child(p)
	for m in [_music, _music_out]:
		m.bus = "Musica"
		add_child(m)
	_announcer.bus = "Voci"
	_announcer.finished.connect(_on_phrase_finished)
	add_child(_announcer)
	_queue = AnnouncerQueue.new(game.audio.get("announcerPriority", {}), game.audio.get("announcerInterrupt", 3), game.audio.get("announcerMaxWaitMs", 1500))
	_build_sounds()
	_load_files(game.get("audioFiles", {}))
	var preset := normalize_music({}, game.audio)
	_default_key = music_key(preset)
	_queue_music(preset)


# Volumi da 0 a 1, come nelle opzioni del gioco web
func set_volumes(master: float, sfx: float, music: float, music_on: bool, voices := 0.8) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voci"), linear_to_db(voices))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effetti"), linear_to_db(sfx))
	_music_volume = music
	_apply_music_volume()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Musica"), not music_on)


func music_on() -> bool:
	return not AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica"))


func on_event(e: Dictionary) -> void:
	match e.type:
		"dash":
			_play("doubleJump", {"volume": 0.45, "pitch": 0.75}) # scatto (#199): uno slancio più grave del doppio salto
		"attack":
			# Le varianti direzionali (#2) usano il suono del colpo base, un po' più acuto in su e più grave in giù
			var kind: String = e.kind
			var tilt := 0.12 if kind.ends_with("Up") else (-0.12 if kind.ends_with("Down") else 0.0)
			if kind == "recovery":
				_play("doubleJump", {"volume": 0.7}) # il recupero (#11) suona come un doppio salto
			elif kind == "specialSide":
				_play("heavy", {"volume": 0.8, "pitch": 1.3}) # lo scatto: un fruscio lungo e acuto
			elif kind == "specialDown":
				_play("shield", {"volume": 0.5, "pitch": 1.4}) # il contrattacco si alza: un "tink" di guardia
			elif kind.begins_with("throw"):
				_play("throw") # lancio dalla presa (#109)
			elif kind == "supreme":
				_play("heavy", {"volume": 1.0, "pitch": 0.7}) # la suprema (#101): il pesante, più grave e pieno
			elif kind == "grab":
				_play("light", {"volume": 0.4, "pitch": 0.8}) # la mano che parte: un fruscio corto
			else:
				_play("heavy" if kind.begins_with("heavy") else "light", {"volume": 0.7, "pitch": randf_range(0.95, 1.05) + tilt})
		"hit":
			if e.kind == "grab":
				_play("hitLight", {"volume": 0.45, "x": e.x, "pitch": 1.3}) # colpetto durante la presa
				return
			# Più alta la percentuale del bersaglio, più forte e più grave il colpo
			var strength := minf(1.0, e.percent / game.audio.hitLoudPercent)
			_play("hitHeavy" if str(e.kind).begins_with("heavy") else "hitLight", {"volume": 0.6 + 0.4 * strength, "x": e.x, "pitch": 1.1 - 0.3 * strength})
		"hazard":
			_play("hitHeavy", {"volume": 0.8, "x": e.x, "pitch": 0.8})
		"jump":
			_play("doubleJump" if e.air else "jump", {"volume": 0.6, "x": e.x})
		"land":
			_play("land", {"volume": 0.5, "x": e.x})
		"ledgeGrab":
			_play("ledge", {"volume": 0.7, "x": e.x})
		"ledgeGetup":
			# Salto e attacco hanno già il loro suono; ci si lascia andare in silenzio
			if e.option == "roll":
				_play("roll", {"volume": 0.5})
			elif e.option == "climb":
				_play("land", {"volume": 0.3, "pitch": 1.3})
		"shield":
			# Colpo parato (#109): più grave quando lo scudo sta per rompersi
			var left: float = clampf(e.shieldHp / float(game.shield.maxHp), 0.0, 1.0)
			_play("shield", {"volume": 0.6, "x": e.x, "pitch": 0.75 + 0.35 * left})
		"shieldBreak":
			_play("shieldBreak", {"x": e.x})
		"grab":
			_play("grab", {"x": e.x})
		"counter":
			_play("counter", {"x": e.x})
		# Proiettili (E10): il colpo e lo scudo hanno già il loro suono, qui il tiro e lo schiocco contro un muro
		"projectile":
			_play("projectile", {"x": e.x, "pitch": randf_range(0.95, 1.05)})
		"projectileEnd":
			if e.reason == "wall" or e.reason == "hit":
				_play("projectilePop", {"x": e.x, "volume": 0.8 if e.reason == "wall" else 0.5})
		"grabRelease":
			_play("roll", {"volume": 0.4, "pitch": 1.2})
		"ko":
			_play("ko", {"x": e.x})
			duck()
			if int(e.get("stocksLeft", 0)) == 1:
				announce("lastLife")
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
			_queue.clear()
			_announcer.stop()
			_time_left = -1.0
			announce("go")
		"matchEnd":
			_play("victory")
			# Il server oggi decide sempre un vincitore; "draw" è pronta per quando ci sarà il pareggio
			announce("game" if e.get("winnerId") != null else "draw")


# Dallo snapshot l'annunciatore sente solo il tempo: "Dieci secondi!" quando scende sotto la soglia
func on_snapshot(data: Dictionary) -> void:
	var left: float = data.timeLeftMs if data.get("timeLeftMs") != null else -1.0
	var warning: float = game.audio.get("announcerTimeWarningMs", 10000)
	if crosses_warning(_time_left, left, warning) and data.get("winnerId") == null:
		announce("tenSeconds")
	_time_left = left
	# La carica (E10) non ha eventi: si sente quando parte e quando è piena
	for p in data.get("players", []):
		var now := float(p.get("charge", 0.0))
		var cue := charge_cue(float(_charges.get(p.id, 0.0)), now)
		if cue != "":
			_play(cue, {"x": p.x})
		_charges[p.id] = now


# "charge" quando la carica parte, "chargeFull" quando arriva in cima, "" altrimenti
static func charge_cue(before: float, now: float) -> String:
	if before <= 0.0 and now > 0.0:
		return "charge"
	if before < 0.99 and now >= 0.99:
		return "chargeFull"
	return ""


# Il tempo è appena sceso sotto la soglia (e non era già sotto, né la partita è senza tempo o finita)
static func crosses_warning(before: float, now: float, warning: float) -> bool:
	return before > warning and now <= warning and now > 0


# Una frase dell'annunciatore: senza il file registrato non si dice (niente ripiego sintetizzato)
func announce(phrase: String) -> void:
	if not _phrases.has(phrase):
		return
	if _queue.push(phrase, Time.get_ticks_msec()):
		_say(phrase)


func announcer_phrase() -> String:
	return _queue.speaking


func _say(phrase: String) -> void:
	var files: Array = _phrases[phrase]
	var i := pick_variant(files.size(), _last.get("announcer:" + phrase, -1), randi())
	_last["announcer:" + phrase] = i
	_announcer.stream = files[i]
	duck()
	if _announcer.is_inside_tree():
		_announcer.play()


func _on_phrase_finished() -> void:
	var next := _queue.finished(Time.get_ticks_msec())
	if next != "":
		_say(next)


func _play(name: String, opts := {}) -> void:
	var now := Time.get_ticks_msec()
	var recent: Array = _started.get(name, [])
	if not may_start(recent, now, game.audio.get("sameSoundMax", 3), game.audio.get("sameSoundWindowMs", 60)):
		return
	recent.append(now)
	_started[name] = recent
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream_for(name)
	p.volume_db = linear_to_db(opts.get("volume", 1.0))
	p.pitch_scale = opts.get("pitch", 1.0)
	# Il suono arriva dal lato dello schermo dove succede la cosa (al centro se non ha un punto)
	var w: float = game.world.width
	p.global_position = Vector2(clampf(opts.get("x", view_left + w / 2), view_left, view_left + w), game.world.height / 2.0)
	p.play()


func _process(_delta: float) -> void:
	if _to_render.is_empty():
		return
	var preset := _to_render[0]
	for i in MUSIC_STEPS_PER_FRAME:
		_music_play_step(_music_step, preset)
		_music_step += 1
		if _music_step >= STEPS * _music_chords.size():
			var key := music_key(preset)
			_rendered[key] = _music_synth.to_stream(true) # finita: da qui in poi gira in loop
			if key == _default_key:
				_synth_music = _rendered[key]
			_to_render.pop_front()
			_start_render()
			_update_music()
			return


# Tetto ai suoni uguali (E13): parte solo se entro window ms ne sono partite meno di max copie.
# Toglie da recent gli avvii vecchi
static func may_start(recent: Array, now: int, max_copies: int, window: int) -> bool:
	while not recent.is_empty() and now - int(recent[0]) >= window:
		recent.pop_front()
	return recent.size() < max_copies


# Sul KO (e quando parlerà l'annunciatore) la musica scende di colpo e risale piano
func duck() -> void:
	if _duck:
		_duck.kill()
	_set_duck(float(game.audio.get("duckDb", -8)))
	if is_inside_tree():
		_duck = create_tween()
		_duck.tween_method(_set_duck, _duck_db, 0.0, game.audio.get("duckMs", 1200) / 1000.0).set_ease(Tween.EASE_IN)


func music_duck_db() -> float:
	return _duck_db


func _set_duck(db: float) -> void:
	_duck_db = db
	_apply_music_volume()


func _apply_music_volume() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), linear_to_db(_music_volume) + _duck_db)


# Il suono da far partire: una variante registrata (mai la stessa due volte di fila), o la ricetta
func stream_for(name: String) -> AudioStream:
	var files: Array = _files.get(name, [])
	if files.is_empty():
		return _sounds[name]
	var i := pick_variant(files.size(), _last.get(name, -1), randi())
	_last[name] = i
	return files[i]


# Quale variante su count: a caso con roll, ma diversa da last quando ce n'è più d'una
static func pick_variant(count: int, last: int, roll: int) -> int:
	if count <= 1:
		return 0
	var i := absi(roll) % (count - 1)
	return i if i < last or last < 0 else i + 1


# I campioni elencati in game.json; un file che non si carica si salta (resta la ricetta)
func _load_files(files: Dictionary) -> void:
	var sfx: Dictionary = files.get("sfx", {})
	for name: String in sfx:
		var loaded: Array[AudioStream] = []
		for path: String in sfx[name]:
			var stream := _load_stream(path)
			if stream:
				loaded.append(stream)
		if not loaded.is_empty():
			_files[name] = loaded
	var announcer: Dictionary = files.get("announcer", {})
	for phrase: String in announcer:
		var loaded: Array[AudioStream] = []
		for path: String in announcer[phrase]:
			var stream := _load_stream(path)
			if stream:
				loaded.append(stream)
		if not loaded.is_empty():
			_phrases[phrase] = loaded
	var music: Dictionary = files.get("music", {})
	for track: String in music:
		var paths: Array = music[track]
		var stream := _load_stream(paths[0])
		if stream:
			_set_loop(stream)
			_music_files[track] = stream


static func _load_stream(path: String) -> AudioStream:
	var full := "res://data/" + path
	if not ResourceLoader.exists(full):
		push_warning("Audio mancante, uso il suono sintetizzato: " + full)
		return null
	return load(full) as AudioStream


static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)


# Musica della lobby o della partita: da file se c'è, altrimenti quella sintetizzata (uguale per tutte e due).
# In partita vince la musica dell'arena, se ne ha una (set_stage_music)
func play_music(track: String) -> void:
	if track == _track:
		return
	_track = track
	_update_music()


# La musica dell'arena della partita (E12 passo 4): il preset di StageSpec.music, o null per quella di sempre.
# Si calcola un pezzo per frame; finché non è pronta continua quella che suona
func set_stage_music(preset: Variant) -> void:
	_stage_key = ""
	if preset is Dictionary:
		var p := normalize_music(preset, game.audio)
		_stage_key = music_key(p)
		_queue_music(p)
	_update_music()


func stage_music_ready() -> bool:
	return _stage_key == "" or _rendered.has(_stage_key)


func _update_music() -> void:
	var stream: AudioStream = _music_files.get(_track, _synth_music)
	if _track == "match" and _stage_key != "":
		stream = _rendered.get(_stage_key)
	if stream and stream != _music.stream:
		_switch_music(stream)


func _queue_music(preset: Dictionary) -> void:
	var key := music_key(preset)
	if _rendered.has(key) or _to_render.any(func(q: Dictionary) -> bool: return music_key(q) == key):
		return
	_to_render.append(preset)
	if _to_render.size() == 1:
		_start_render()


# Prepara il calcolo del primo preset in coda
func _start_render() -> void:
	if _to_render.is_empty():
		return
	var preset := _to_render[0]
	_music_chords = preset.chords.map(chord_hz)
	var bar: float = 60.0 / preset.bpm / 4.0 * STEPS
	_music_synth = Synth.new(bar * _music_chords.size())
	_music_step = 0


# Il preset completo: quello che manca o non va prende il valore della musica di sempre
static func normalize_music(preset: Dictionary, audio: Dictionary) -> Dictionary:
	var bpm := clampf(float(preset.get("bpm", audio.musicBpm)), audio.get("musicBpmMin", 70), audio.get("musicBpmMax", 190))
	var chords: Array = []
	for c: Variant in preset.get("chords", []):
		if c is String and not chord_hz(c).is_empty():
			chords.append(c)
	if chords.is_empty():
		chords = DEFAULT_CHORDS.duplicate()
	var lead: String = preset.get("lead", "square")
	if not LEAD_VOLUME.has(lead):
		lead = "square"
	return {"bpm": bpm, "chords": chords, "lead": lead}


static func music_key(preset: Dictionary) -> String:
	return "%d|%s|%s" % [roundi(preset.bpm), ",".join(preset.chords), preset.lead]


# Le tre note in Hz di un accordo per nome ("Am", "F#", "Bbm"), o [] se il nome non va.
# Fondamentale tra Fa3 e Mi4, come il giro di sempre (La3, Fa3, Do4, Sol3)
static func chord_hz(name: String) -> Array:
	if name.is_empty() or not NOTES.has(name[0]):
		return []
	var rest := name.substr(1)
	var semi: int = NOTES[name[0]]
	if rest.begins_with("#"):
		semi += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		semi -= 1
		rest = rest.substr(1)
	if rest != "" and rest != "m":
		return []
	semi = posmod(semi, 12)
	var root := 261.63 * pow(2.0, (semi - (12 if semi >= 5 else 0)) / 12.0)
	var third := 3 if rest == "m" else 4
	return [root, root * pow(2.0, third / 12.0), root * pow(2.0, 7 / 12.0)]


func music_track() -> String:
	return _track


# Dissolvenza incrociata: la musica che suona sfuma via, la nuova sale
func _switch_music(stream: AudioStream) -> void:
	if _fade:
		_fade.kill()
	var seconds: float = game.audio.get("musicFadeMs", 1500) / 1000.0
	var had_music := _music.playing
	var tmp := _music_out
	_music_out = _music
	_music = tmp
	_music.stream = stream
	if not is_inside_tree():
		# Non ancora nella scena: partirà appena entra, senza dissolvenza
		_music_out.autoplay = false
		_music.autoplay = true
		_music.volume_db = 0.0
		return
	_music.volume_db = -40.0 if had_music else 0.0
	_music.play()
	_fade = create_tween().set_parallel()
	_fade.tween_property(_music, "volume_db", 0.0, seconds)
	if had_music:
		_fade.tween_property(_music_out, "volume_db", -40.0, seconds)
		_fade.chain().tween_callback(_music_out.stop)


# Un sedicesimo della musica: cassa, rullante, charleston, basso e accordi (playStep in music.ts)
func _music_play_step(step: int, preset: Dictionary) -> void:
	var s := _music_synth
	var t: float = step * 60.0 / preset.bpm / 4.0
	var chord: Array = _music_chords[step / STEPS]
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
		s.tone(t, preset.lead, f, f, 0.09, LEAD_VOLUME[preset.lead], true)


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
	# Presa del bordo (#110): un colpo sordo di mano sul legno, più corto e più tonale dell'atterraggio
	_sounds.ledge = make.call(0.12, func(s):
		s.tone(0, "sine", 170, 80, 0.09, 0.7)
		s.noise(0, "lowpass", 600, 150, 0.05, 0.5))
	# Rotolata dal bordo: un fruscio che scende
	_sounds.roll = make.call(0.3, func(s): s.noise(0, "bandpass", 900, 350, 0.26, 0.4))
	# Scudo colpito (#109): un "tonk" metallico e corto
	_sounds.shield = make.call(0.18, func(s):
		s.tone(0, "triangle", 520, 480, 0.15, 0.35)
		s.noise(0, "bandpass", 2500, 1500, 0.06, 0.3))
	# Scudo rotto: vetro che si spezza e un tonfo che scende
	_sounds.shieldBreak = make.call(0.6, func(s):
		s.noise(0, "highpass", 6000, 2500, 0.35, 0.6)
		s.tone(0, "square", 900, 120, 0.5, 0.25)
		s.tone(0.02, "sine", 160, 50, 0.45, 0.5))
	# Presa (#109): una mano che stringe, tonfo sordo e stoffa
	_sounds.grab = make.call(0.16, func(s):
		s.tone(0, "sine", 220, 110, 0.1, 0.6)
		s.noise(0, "bandpass", 1800, 900, 0.08, 0.45))
	# Contrattacco (E10): un colpo di metallo che risuona, poi uno schiocco
	_sounds.counter = make.call(0.5, func(s):
		s.tone(0, "triangle", 1320, 1250, 0.4, 0.3)
		s.tone(0, "square", 660, 640, 0.12, 0.12)
		s.noise(0.06, "lowpass", 4000, 600, 0.12, 0.6))
	# Tiro (E10): un "piu" corto che scende, con un soffio
	_sounds.projectile = make.call(0.14, func(s):
		s.tone(0, "square", 880, 520, 0.1, 0.16)
		s.noise(0, "bandpass", 3000, 1500, 0.06, 0.25))
	# Proiettile che sbatte: uno schiocco sordo
	_sounds.projectilePop = make.call(0.1, func(s):
		s.noise(0, "lowpass", 3000, 400, 0.07, 0.5)
		s.tone(0, "sine", 300, 150, 0.06, 0.3))
	# Carica che sale (E10): due toni che crescono per quasi tutta la carica
	_sounds.charge = make.call(1.0, func(s):
		s.tone(0, "sawtooth", 160, 480, 0.95, 0.12)
		s.tone(0, "sine", 320, 960, 0.95, 0.12))
	# Carica piena: un "ding" doppio
	_sounds.chargeFull = make.call(0.3, func(s):
		s.tone(0, "triangle", 1320, 1320, 0.12, 0.25)
		s.tone(0.08, "triangle", 1760, 1760, 0.2, 0.25))
	# Lancio: un "whoop" che sale, come qualcosa che parte in aria
	_sounds.throw = make.call(0.32, func(s):
		s.noise(0, "bandpass", 600, 2600, 0.28, 0.55)
		s.tone(0.02, "triangle", 200, 520, 0.22, 0.25))
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
