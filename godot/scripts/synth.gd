# Sintesi dei suoni nel client Godot: le stesse ricette di src/client/audio/sfx.ts e music.ts
# (oscillatori con curva di frequenza, rumore filtrato, inviluppi esponenziali),
# calcolate in un buffer e trasformate in AudioStreamWAV. Niente file audio da scaricare.
class_name Synth
extends RefCounted

const RATE := 22050 # campioni al secondo: basta per questi suoni e costa la metà
const SILENCE := 0.0001 # dove finiscono gli inviluppi esponenziali, come nel web

var buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _init(seconds: float) -> void:
	buf.resize(int(seconds * RATE))
	_rng.seed = 7 # il rumore è sempre lo stesso: i suoni non cambiano da una partita all'altra


# Un oscillatore che scivola da `from` a `to` Hz in `dur` secondi, con attacco di 5 ms.
# wrap = true fa ricominciare dall'inizio quello che esce dalla fine (per la musica in loop)
func tone(t: float, type: String, from: float, to: float, dur: float, vol: float, wrap := false) -> void:
	var start := int(t * RATE)
	var n := int((dur + 0.02) * RATE)
	var phase := 0.0
	to = maxf(20.0, to)
	for i in n:
		var tt := float(i) / RATE
		var f := from * pow(to / from, minf(tt / dur, 1.0))
		phase = fmod(phase + f / RATE, 1.0)
		var w := 0.0
		match type:
			"sine":
				w = sin(phase * TAU)
			"square":
				w = 1.0 if phase < 0.5 else -1.0
			"sawtooth":
				w = phase * 2.0 - 1.0
			"triangle":
				w = 1.0 - 4.0 * absf(phase - 0.5)
		_add(start + i, w * _envelope(tt, dur, vol, 0.005), wrap)


# Rumore bianco passato da un filtro (lowpass, highpass o bandpass) la cui frequenza scivola
func noise(t: float, filter: String, f_from: float, f_to: float, dur: float, vol: float, wrap := false) -> void:
	var start := int(t * RATE)
	var n := int((dur + 0.02) * RATE)
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0; var a1 := 0.0; var a2 := 0.0
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	f_to = maxf(20.0, f_to)
	for i in n:
		var tt := float(i) / RATE
		if i % 32 == 0:
			# Filtro biquad (le formule classiche di R. Bristow-Johnson), ricalcolato ogni 32 campioni
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
		_add(start + i, y * _envelope(tt, dur, vol, 0.0), wrap)


func to_stream(loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		# Saturazione morbida al posto del compressore del web: tanti suoni insieme non gracchiano
		var v := tanh(buf[i] * 0.9)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = buf.size()
	return s


func _envelope(tt: float, dur: float, vol: float, attack: float) -> float:
	if tt < attack:
		return SILENCE * pow(vol / SILENCE, tt / attack)
	if tt >= dur:
		return 0.0
	return vol * pow(SILENCE / vol, (tt - attack) / (dur - attack))


func _add(i: int, v: float, wrap: bool) -> void:
	if wrap:
		i = i % buf.size()
	elif i >= buf.size():
		return
	buf[i] += v
