# Sintesi dei suoni nel client Godot: le stesse ricette di src/client/audio/sfx.ts e music.ts
# (oscillatori con curva di frequenza, rumore filtrato, inviluppi esponenziali),
# calcolate in un buffer e trasformate in AudioStreamWAV. Niente file audio da scaricare.
class_name Synth
extends RefCounted

const RATE := 22050 # campioni al secondo: basta per questi suoni e costa la metà
const SILENCE := 0.0001 # dove finiscono gli inviluppi esponenziali, come nel web
const ATTACK := 0.005 # attacco degli oscillatori, secondi
const WAVES := {"sine": 0, "square": 1, "sawtooth": 2, "triangle": 3}

var buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _bytes := PackedByteArray() # i campioni in 16 bit, riempiti da encode()
var _encoded := 0 # quanti campioni di buf sono già in _bytes


func _init(seconds: float) -> void:
	buf.resize(int(seconds * RATE))
	_rng.seed = 7 # il rumore è sempre lo stesso: i suoni non cambiano da una partita all'altra


# Un oscillatore che scivola da `from` a `to` Hz in `dur` secondi, con attacco di 5 ms.
# wrap = true fa ricominciare dall'inizio quello che esce dalla fine (per la musica in loop).
# Curva di frequenza e inviluppo esponenziali si fanno con una moltiplicazione per campione invece di un pow():
# nel browser (WebAssembly, un thread solo) la musica si calcola mentre si gioca e ogni ms del frame conta
func tone(t: float, type: String, from: float, to: float, dur: float, vol: float, wrap := false) -> void:
	if vol <= 0.0 or dur <= 0.0:
		return
	var start := int(t * RATE)
	to = maxf(20.0, to)
	var wave: int = WAVES.get(type, -1)
	var size := buf.size()
	var sweep := int(dur * RATE) # campioni in cui la frequenza scivola: poi resta su `to`
	var f_mul := pow(to / from, 1.0 / (dur * RATE))
	var f := from
	var attack := int(ceilf(ATTACK * RATE))
	var env := SILENCE
	var env_mul := pow(vol / SILENCE, 1.0 / (ATTACK * RATE))
	var phase := 0.0
	# Dopo dur l'inviluppo è zero: i campioni in più (fino a dur + 0,02 s) non aggiungono niente
	for i in mini(int((dur + 0.02) * RATE), int(ceilf(dur * RATE))):
		if i == attack:
			# Da qui scende da vol a SILENCE in dur - ATTACK secondi, come _envelope()
			env = vol * pow(SILENCE / vol, (float(i) / RATE - ATTACK) / (dur - ATTACK))
			env_mul = pow(SILENCE / vol, 1.0 / ((dur - ATTACK) * RATE))
		phase += f / RATE
		if phase >= 1.0:
			phase -= 1.0
		var w := 0.0
		if wave == 0:
			w = sin(phase * TAU)
		elif wave == 1:
			w = 1.0 if phase < 0.5 else -1.0
		elif wave == 2:
			w = phase * 2.0 - 1.0
		elif wave == 3:
			w = 1.0 - 4.0 * absf(phase - 0.5)
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += w * env
		env *= env_mul
		if i < sweep:
			f *= f_mul
		else:
			f = to


# Rumore bianco passato da un filtro (lowpass, highpass o bandpass) la cui frequenza scivola
func noise(t: float, filter: String, f_from: float, f_to: float, dur: float, vol: float, wrap := false) -> void:
	if vol <= 0.0 or dur <= 0.0:
		return
	var start := int(t * RATE)
	var size := buf.size()
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0; var a1 := 0.0; var a2 := 0.0
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	f_to = maxf(20.0, f_to)
	var env := vol # senza attacco: scende da vol a SILENCE in dur secondi
	var env_mul := pow(SILENCE / vol, 1.0 / (dur * RATE))
	for i in mini(int((dur + 0.02) * RATE), int(ceilf(dur * RATE))):
		if i % 32 == 0:
			# Filtro biquad (le formule classiche di R. Bristow-Johnson), ricalcolato ogni 32 campioni
			var tt := float(i) / RATE
			var f := minf(f_from * pow(f_to / f_from, minf(tt / dur, 1.0)), RATE * 0.45)
			var w0 := TAU * f / RATE
			var alpha := sin(w0) / (2.0 * 0.707)
			var c := cos(w0)
			var a0 := 1.0 + alpha
			match filter:
				"lowpass":
					b0 = (1.0 - c) / 2.0; b1 = 1.0 - c; b2 = b0
				"highpass":
					b0 = (1.0 + c) / 2.0; b1 = -(1.0 + c); b2 = b0
				_:
					b0 = alpha; b1 = 0.0; b2 = -alpha
			b0 /= a0; b1 /= a0; b2 /= a0
			a1 = -2.0 * c / a0
			a2 = (1.0 - alpha) / a0
		var x := _rng.randf() * 2.0 - 1.0
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += y * env
		env *= env_mul


# Converte in 16 bit altri `count` campioni; true quando li ha fatti tutti. La musica lo fa a pezzi,
# un po' per frame: tutta insieme (8 s di musica) bloccava il gioco nel browser per un attimo
func encode(count: int) -> bool:
	if _bytes.size() != buf.size() * 2:
		_bytes.resize(buf.size() * 2)
	var end := mini(_encoded + count, buf.size())
	for i in range(_encoded, end):
		# Saturazione morbida al posto del compressore del web: tanti suoni insieme non gracchiano
		var v := tanh(buf[i] * 0.9)
		_bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	_encoded = end
	return _encoded >= buf.size()


func to_stream(loop := false) -> AudioStreamWAV:
	encode(buf.size())
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = _bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = buf.size()
	return s
