# Effetti a particelle (#470 passo 1): solo disegno, la fisica resta del server.
# Stile "Naturale morbido", scelto da Riccardo sul banco di prova: decine di particelle per effetto, ognuna con la sua
# velocità, un attrito lineare e una gravità (la polvere scivola a terra e rallenta, il fumo sale, le schegge ricadono),
# texture a tre toni con il bordo sfumato (tools/fx/texture_particelle.py) e, per fuoco ed esplosioni, una rampa di
# colori dal bianco al fumo.
# Funzioni pure, come strike_fx.gd: la posizione viene dal tempo in forma chiusa, senza stato da aggiornare a ogni
# frame. Le particelle sono Dictionary; particle_view.gd le tiene in vita e le disegna.
#
# Campi di una particella (tempi in secondi, distanze in pixel di mondo):
#   kind: "tex" (texture, il normale), "spark" (tratto luminoso), "grit" (granello scuro che rimbalza)
#   x, y, vx, vy, drag (1/s), gy (px/s², positiva verso il basso), life, delay (nasce più tardi del gruppo)
#   tex: s0, s1 (raggio iniziale e finale), rot, spin, v (variante della texture), ramp (toni), shape ("puff" o
#        "flame"), alpha, fade ("late" = resta piena e sparisce alla fine), grow, add (fusione additiva), stretch
#   spark: w (spessore), col; grit: s (grandezza), spin, col, floor (y del terreno su cui rimbalza)

const VARIANTS := 4
# Le misure sono quelle del banco di prova, dove il pupazzo era alto 44 px: nel gioco il lottatore è alto 88 (FIGHTER),
# quindi spostamenti, velocità e grandezze si raddoppiano. x, y sono assoluti (pixel di mondo); ox, oy lo scostamento
# iniziale in unità del banco
const SCALE := 2.0
const GRIT := [Color("9c8668"), Color("7a664c"), Color("57472f")]
const FIRE_RAMP := ["core", "yellow", "orange", "red", "dark"]


static func _rng(key: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = key
	return r


# Posizione all'età a (s): attrito lineare d e gravità g, in forma chiusa
# v(t) = g/d + (v0 - g/d)·e^(-dt)  →  x(t) = x0 + (g/d)·t + (v0 - g/d)·(1 - e^(-dt))/d
static func at(p: Dictionary, a: float) -> Vector2:
	var d: float = maxf(float(p.get("drag", 0.0)), 0.0001)
	var e := exp(-d * a)
	var gx: float = p.get("gx", 0.0)
	var gy: float = p.get("gy", 0.0)
	var dx: float = float(p.get("ox", 0.0)) + gx / d * a + (float(p.vx) - gx / d) * (1.0 - e) / d
	var dy: float = float(p.get("oy", 0.0)) + gy / d * a + (float(p.vy) - gy / d) * (1.0 - e) / d
	return Vector2(float(p.x) + dx * SCALE, float(p.y) + dy * SCALE)


static func _ease_out(k: float) -> float:
	return 1.0 - (1.0 - k) * (1.0 - k)


# Come appare una particella "tex" all'età a: vuoto se non c'è (non ancora nata o già finita).
# Restituisce pos, size (raggio), alpha, rot e la rampa: tone0, tone1 e f (quanto del secondo tono si vede)
static func sample(p: Dictionary, a: float) -> Dictionary:
	var life: float = p.life
	var k := a / life
	if k < 0.0 or k >= 1.0:
		return {}
	var grow: float = p.get("grow", 1.0)
	var s0: float = p.s0
	var size := (s0 + (float(p.s1) - s0) * _ease_out(minf(1.0, k * grow))) * SCALE
	var fade_in := minf(1.0, k / 0.06)
	var fade := (1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4) if p.get("fade", "") == "late" else pow(1.0 - k, 1.4)
	var alpha: float = float(p.get("alpha", 1.0)) * fade_in * fade
	var ramp: Array = p.ramp
	var pos := clampf(k * (ramp.size() - 1) * float(p.get("ramp_speed", 1.0)), 0.0, maxf(0.0, ramp.size() - 1.001))
	var i0 := int(pos)
	return {
		"pos": at(p, a), "size": size, "alpha": alpha,
		"rot": float(p.get("rot", 0.0)) + float(p.get("spin", 0.0)) * a,
		"tone0": ramp[i0], "tone1": ramp[mini(i0 + 1, ramp.size() - 1)], "f": pos - i0 if ramp.size() > 1 else 0.0,
	}


# Polvere ai piedi. power 1 normale, 2 e più pesante (più sbuffi, più larghi e alti, e un pennacchio al centro).
# side 0 = da tutte e due le parti, +1 o -1 = solo da quella; kick spinge tutto da una parte (scatto, inversione)
static func dust_burst(key: int, x: float, y: float, power := 1.0, side := 0, kick := 0.0, up := 1.0) -> Array:
	var r := _rng(key)
	var out: Array = []
	var n := roundi(12 * power)
	for i in n:
		var sd: float = side if side != 0 else (1 if i % 2 == 1 else -1)
		var sp := r.randf_range(35, 120) * pow(power, 0.6)
		out.append({"x": x, "ox": sd * r.randf_range(2, 8), "y": y, "oy": -(r.randf_range(1, 4)), "vx": sd * sp + kick,
			"vy": -r.randf_range(4, 28) * up * sqrt(power), "drag": r.randf_range(3.5, 5.5), "gy": -r.randf_range(6, 22),
			"s0": r.randf_range(3, 5) * pow(power, 0.3), "s1": r.randf_range(8, 14) * pow(power, 0.55),
			"life": r.randf_range(0.38, 0.7) * pow(power, 0.35), "rot": r.randf() * TAU, "spin": r.randf_range(-2, 2),
			"v": i % VARIANTS, "ramp": ["dust"], "alpha": r.randf_range(0.75, 0.95)})
	for i in roundi(5 * power): # sassolini che saltano e rimbalzano
		var sd: float = side if side != 0 else (1 if i % 2 == 1 else -1)
		out.append({"kind": "grit", "x": x, "y": y, "oy": -(2), "vx": sd * r.randf_range(25, 80) * sqrt(power) + kick * 0.5,
			"vy": -r.randf_range(50, 120) * sqrt(power), "drag": 0.8, "gy": 420.0, "life": r.randf_range(0.35, 0.55),
			"s": r.randf_range(0.9, 1.7) * pow(power, 0.3), "spin": r.randf_range(-12, 12), "col": GRIT[i % 3], "floor": y})
	if power > 1.5: # nel pesante un pennacchio che sale dal centro
		for i in 5:
			out.append({"x": x, "ox": r.randf_range(-8, 8), "y": y, "oy": -(4), "vx": r.randf_range(-20, 20), "vy": -r.randf_range(25, 55),
				"drag": 3.0, "gy": -10.0, "s0": 5.0, "s1": r.randf_range(12, 17), "life": r.randf_range(0.6, 0.85),
				"rot": r.randf() * TAU, "spin": r.randf_range(-1, 1), "v": i % VARIANTS, "ramp": ["dust"], "alpha": 0.7, "delay": 0.03})
	return out


# Frenata: uno sbuffetto davanti al piede che scivola (dir = verso dove si scivola) e un granello
static func brake_puff(key: int, x: float, y: float, dir: float) -> Array:
	var r := _rng(key)
	return [
		{"x": x, "y": y, "oy": -(2), "vx": dir * r.randf_range(15, 45), "vy": -r.randf_range(6, 20), "drag": 5.0, "gy": -12.0,
			"s0": 2.0, "s1": r.randf_range(4, 7), "life": r.randf_range(0.3, 0.5), "rot": r.randf() * TAU, "v": key % VARIANTS,
			"ramp": ["dust"], "alpha": 0.8},
		{"kind": "grit", "x": x, "y": y, "oy": -(1), "vx": dir * r.randf_range(20, 60), "vy": -r.randf_range(30, 70), "drag": 1.0,
			"gy": 420.0, "life": 0.35, "s": 1.0, "spin": 9.0, "col": GRIT[1], "floor": y},
	]


# Salto in aria: sbuffetti d'aria spinti verso il basso e di lato dal salto (l'anello lo disegna particle_view)
static func air_burst(key: int, x: float, y: float) -> Array:
	var r := _rng(key)
	var out: Array = []
	for i in 14:
		var a := PI * (0.05 + 0.9 * i / 13.0) + r.randf_range(-0.1, 0.1)
		var sp := r.randf_range(50, 110)
		out.append({"x": x, "y": y, "vx": cos(a) * sp * 1.4, "vy": sin(a) * sp * 0.45 + 25, "drag": 6.0,
			"s0": 2.0, "s1": r.randf_range(4, 7), "life": r.randf_range(0.25, 0.42), "rot": r.randf() * TAU,
			"v": i % VARIANTS, "ramp": ["air"], "alpha": 0.85})
	return out


# Impatto: scintille che schizzano dalla parte del colpo (face = +1 se spinge a destra) e ricadono, più numerose col
# danno; il pesante lascia fumo, il colpo da KO fumo arancio che diventa scuro. La stella la disegna particle_view
static func impact_burst(key: int, x: float, y: float, damage: float, heavy: bool, ko: bool, face: float) -> Array:
	var r := _rng(key)
	var out: Array = []
	var n := 6 + roundi(damage * (1.6 if ko else 0.9))
	for i in n:
		var a := r.randf_range(-PI, PI) * 0.55 + (0.0 if face > 0 else PI) # un cono di ±100° nella direzione del colpo
		var sp := r.randf_range(120, 330) * (1.5 if ko else 1.0)
		out.append({"kind": "spark", "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - 40, "drag": 7.0, "gy": 380.0,
			"life": r.randf_range(0.16, 0.34) * (1.4 if ko else 1.0), "w": r.randf_range(1, 2.2) * (1.4 if ko else 1.0),
			"col": Color("fff3c2") if r.randf() > 0.4 else (Color("ff8a4a") if ko else Color("ffd34a"))})
	if heavy or ko:
		for i in (9 if ko else 4):
			var a := r.randf() * TAU
			out.append({"x": x, "y": y, "vx": cos(a) * r.randf_range(20, 60), "vy": sin(a) * r.randf_range(20, 50) - 15,
				"drag": 4.0, "gy": -20.0, "s0": 4.0, "s1": r.randf_range(9, 15) * (1.3 if ko else 1.0),
				"life": r.randf_range(0.45, 0.8), "rot": r.randf() * TAU, "spin": r.randf_range(-2, 2), "v": i % VARIANTS,
				"ramp": ["orange", "red", "dark"] if ko else ["smoke"], "alpha": 0.75, "delay": 0.04})
	return out


# Fumo del lancio: uno sbuffo lasciato da chi vola via; vx, vy = un po' all'indietro rispetto al volo.
# fast da 0 a 1: più è veloce, più lo sbuffo è grosso
static func smoke_puff(key: int, x: float, y: float, vx: float, vy: float, fast: float) -> Dictionary:
	var r := _rng(key)
	return {"x": x, "ox": r.randf_range(-4, 4), "y": y, "oy": r.randf_range(-5, 5), "vx": vx + r.randf_range(-12, 12),
		"vy": vy - r.randf_range(4, 16), "drag": 3.2, "gy": -18.0, "s0": r.randf_range(3, 5),
		"s1": r.randf_range(8, 13) * (0.65 + 0.6 * clampf(fast, 0.0, 1.0)), "life": r.randf_range(0.55, 0.95),
		"rot": r.randf() * TAU, "spin": r.randf_range(-1.5, 1.5), "v": key % VARIANTS, "ramp": ["smoke"],
		"alpha": r.randf_range(0.65, 0.9)}


# Fuoco (pronto per la fase 4): le particelle che nascono al passo i di un fuoco acceso in (x, y), un passo ogni
# FIRE_STEP_MS. Lingue di fiamma che salgono ondeggiando, un cuore luminoso (additivo), ogni tanto fumo e faville
const FIRE_STEP_MS := 11
static func fire_step(i: int, x: float, y: float) -> Array:
	var r := _rng(i * 7919 + 13)
	var off := r.randf_range(-1, 1)
	var sway := sin(i * FIRE_STEP_MS / 160.0 + i) * 10.0
	var out: Array = [{"x": x, "ox": off * 12, "y": y, "oy": 2, "vx": -off * 18 + sway, "vy": -r.randf_range(70, 105) * (1.1 - absf(off) * 0.45),
		"drag": 1.1, "gy": -40.0, "s0": r.randf_range(9, 12) * (1.0 - absf(off) * 0.3), "s1": r.randf_range(1.5, 3),
		"life": r.randf_range(0.5, 0.75), "rot": r.randf_range(-0.15, 0.15), "v": i % VARIANTS, "shape": "flame",
		"stretch": r.randf_range(1.5, 2.1), "ramp": ["yellow", "orange", "red"], "alpha": 0.95}]
	if i % 2 == 0:
		out.append({"x": x, "ox": r.randf_range(-5, 5), "y": y, "oy": 1, "vx": r.randf_range(-6, 6), "vy": -r.randf_range(55, 80), "drag": 1.3,
			"gy": -35.0, "s0": r.randf_range(6, 8), "s1": r.randf_range(1.5, 2.5), "life": r.randf_range(0.26, 0.38),
			"rot": r.randf_range(-0.1, 0.1), "v": i % VARIANTS, "shape": "flame", "stretch": 1.8, "ramp": ["core", "yellow"],
			"alpha": 0.7, "add": true})
	if i % 10 == 0:
		out.append({"x": x, "ox": r.randf_range(-6, 6), "y": y, "oy": -(62), "vx": r.randf_range(-8, 8), "vy": -r.randf_range(18, 30), "drag": 1.2,
			"gy": -14.0, "s0": 6.0, "s1": r.randf_range(12, 18), "life": r.randf_range(1.0, 1.4), "rot": r.randf() * TAU,
			"v": i % VARIANTS, "ramp": ["smoke"], "alpha": 0.2, "fade": "late"})
	if i % 6 == 0 and r.randf() > 0.55:
		out.append({"kind": "spark", "x": x, "ox": r.randf_range(-9, 9), "y": y, "oy": -(6), "vx": r.randf_range(-25, 25), "vy": -r.randf_range(70, 130),
			"drag": 0.8, "gy": -20.0, "life": r.randf_range(0.6, 1.1), "w": r.randf_range(1, 1.8),
			"col": Color("ffd27a") if r.randf() > 0.5 else Color("ff8a3a")})
	return out


# Esplosione (pronta per la fase 4): palla di fuoco che passa dal bianco al fumo scuro, fumo che sale, scintille,
# schegge che ricadono fino a floor_y e polvere sollevata a terra. Lampo e onda d'urto li disegna particle_view
static func explosion_burst(key: int, x: float, y: float, floor_y: float) -> Array:
	var r := _rng(key)
	var out: Array = []
	for i in 26:
		var a := r.randf() * TAU
		var sp := r.randf_range(30, 150)
		out.append({"x": x, "ox": cos(a) * 3, "y": y, "oy": sin(a) * 3, "vx": cos(a) * sp, "vy": sin(a) * sp * 0.8 - 20,
			"drag": r.randf_range(4.5, 6.5), "gy": -35.0, "s0": r.randf_range(8, 13), "s1": r.randf_range(17, 27),
			"life": r.randf_range(0.55, 0.95), "rot": r.randf() * TAU, "spin": r.randf_range(-2.5, 2.5), "v": i % VARIANTS,
			"ramp": FIRE_RAMP, "ramp_speed": 1.1, "grow": 1.6})
	for i in 18:
		var a := -PI / 2 + r.randf_range(-1.2, 1.2)
		var sp := r.randf_range(15, 55)
		out.append({"x": x, "ox": r.randf_range(-14, 14), "y": y, "oy": r.randf_range(-10, 6), "vx": cos(a) * sp, "vy": sin(a) * sp,
			"drag": 2.0, "gy": -45.0, "s0": r.randf_range(10, 14), "s1": r.randf_range(24, 36), "life": r.randf_range(1.0, 1.5),
			"rot": r.randf() * TAU, "spin": r.randf_range(-0.8, 0.8), "v": i % VARIANTS, "ramp": ["dark", "smoke"],
			"alpha": 0.85, "delay": r.randf_range(0.12, 0.32), "fade": "late"})
	for i in 18:
		var a := -PI / 2 + r.randf_range(-1.4, 1.4)
		var sp := r.randf_range(160, 380)
		out.append({"kind": "spark", "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "drag": 3.5, "gy": 420.0,
			"life": r.randf_range(0.3, 0.6), "w": r.randf_range(1.2, 2.4), "col": Color("fff1b0") if r.randf() > 0.5 else Color("ff9a3c")})
	for i in 10:
		var a := -PI / 2 + r.randf_range(-1.1, 1.1)
		var sp := r.randf_range(110, 240)
		out.append({"kind": "grit", "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "drag": 0.6, "gy": 520.0,
			"life": r.randf_range(0.8, 1.1), "s": r.randf_range(1.6, 3.2), "spin": r.randf_range(-14, 14),
			"col": Color("3a3340") if i % 2 == 1 else Color("5a4a3c"), "floor": floor_y})
	for i in 14:
		var sd := 1.0 if i % 2 == 1 else -1.0
		out.append({"x": x, "ox": sd * r.randf_range(6, 20), "y": floor_y, "oy": -2.0, "vx": sd * r.randf_range(70, 170), "vy": -r.randf_range(5, 25),
			"drag": 4.0, "gy": -10.0, "s0": 4.0, "s1": r.randf_range(9, 15), "life": r.randf_range(0.5, 0.8), "rot": r.randf() * TAU,
			"v": i % VARIANTS, "ramp": ["dust"], "alpha": 0.85, "delay": 0.05})
	return out


# Quanto dura un gruppo di particelle (s): la vita più lunga contando il ritardo
static func span(list: Array) -> float:
	var m := 0.0
	for p in list:
		m = maxf(m, float(p.life) + float(p.get("delay", 0.0)))
	return m


# La stella d'impatto all'istante k (da 0 a 1 della sua vita): scala con un piccolo scatto oltre 1 e poi si ritira;
# zero alla fine
static func star_scale(k: float) -> float:
	if k < 0.0 or k >= 1.0:
		return 0.0
	return _ease_out(k / 0.15) * 1.1 if k < 0.15 else 1.1 - 0.5 * (k - 0.15) / 0.85


# I punti di una stella a punte irregolari attorno a c (raggio R, rapporto delle punte interne inner)
static func star_points(c: Vector2, radius: float, spikes: int, inner: float, key: int, wobble: float) -> PackedVector2Array:
	var r := _rng(key)
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var a := float(i) / (spikes * 2) * TAU - PI / 2 + key * 0.37
		var rr := radius * inner if i % 2 == 1 else radius * (1.0 + (r.randf() - 0.5) * wobble)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts
