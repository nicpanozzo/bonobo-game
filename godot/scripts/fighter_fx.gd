# Il sapore di un lottatore negli effetti di movimento. La polvere a terra la decide la superficie (terrain_fx.gd); il
# lottatore ci mette solo un accento piccolo del suo stile, mentre il doppio salto, che è in aria, è tutto suo.
# Sui colpi niente sapori: stella, scintille e fumo restano uguali per tutti, perché in una zuffa si legga chi ha preso cosa.
# Solo disegno, come particle_fx.gd: funzioni pure che restituiscono particelle (Dictionary) per particle_view.gd.
#   Marcomunista: energia verde del kung fu (la sua GIF) e stelline rosse
#   Egiainuso: "è già in uso", un errore da username: quadratini di pixel che sfarfallano, anello sdoppiato
#   Capt. OrsoBlu: acqua della barchetta: gocce, schiuma, onda piatta ai piedi

const ParticleFx := preload("res://scripts/particle_fx.gd")

const STYLES := {"marcomunista": "chi", "egiainuso": "glitch", "orsoblu": "water"}
const CHI_GREEN := Color("6bff8a")
const CHI_RED := Color("e8352b")
const GLITCH := [Color("2ef2ff"), Color("ff3df2"), Color("ffffff"), Color("b6ff3d")]
const WATER := [Color("bfe9ff"), Color("6ec8ff"), Color("ffffff")]
const FOAM := Color("d8f1ff")


static func style_of(character_id: String) -> String:
	return STYLES.get(character_id, "")


static func _rng(key: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = key * 2654435761 + 17
	return r


# A terra (atterraggio, salto da terra, scatto, inversione): power come in dust_burst, kick spinge di lato
static func ground(style: String, key: int, x: float, y: float, power := 1.0, kick := 0.0) -> Array:
	match style:
		"chi":
			return _chi_wisps(key, x, y, roundi(2 * power), kick) + (_red_stars(key, x, y, 1) if power >= 1.3 else [])
		"glitch":
			return _pixels(key, x, y, roundi(4 * power), kick, false)
		"water":
			return _drops(key, x, y, roundi(3 * power), kick) + (_foam(key, x, y, 2, kick) if power >= 1.3 else [])
	return []


# I segni disegnati da particle_view (anelli) che accompagnano ground: l'onda d'acqua ai piedi di OrsoBlu, solo
# quando atterra pesante
static func ground_marks(style: String, x: float, y: float, power := 1.0) -> Array:
	if style == "water" and power >= 1.3:
		return [{"kind": "ring", "x": x, "y": y, "r0": 10.0, "r1": 46.0 * sqrt(power), "squash": 0.22, "width": 3.0,
			"life_ms": 420.0, "col": WATER[1], "alpha": 0.8}]
	return []


# Doppio salto: sopra l'anello d'aria di tutti
static func air_jump(style: String, key: int, x: float, y: float) -> Array:
	match style:
		"chi":
			return _chi_wisps(key, x, y, 8, 0.0, true)
		"glitch":
			return _pixels(key, x, y, 14, 0.0, true)
		"water":
			return _drops(key, x, y, 10, 0.0, true)
	return []


static func air_jump_marks(style: String, x: float, y: float, life_ms: float) -> Array:
	match style:
		"chi":
			return [{"kind": "ring", "x": x, "y": y, "r0": 12.0, "r1": 60.0, "squash": 0.3, "width": 5.0, "life_ms": life_ms, "col": CHI_GREEN}]
		"glitch": # l'anello sdoppiato come un'immagine fuori registro
			return [{"kind": "ring", "x": x - 4.0, "y": y, "r0": 16.0, "r1": 70.0, "squash": 0.3, "width": 4.0, "life_ms": life_ms, "col": GLITCH[0]},
				{"kind": "ring", "x": x + 4.0, "y": y + 2.0, "r0": 16.0, "r1": 70.0, "squash": 0.3, "width": 4.0, "life_ms": life_ms, "col": GLITCH[1]}]
		"water":
			return [{"kind": "ring", "x": x, "y": y, "r0": 14.0, "r1": 64.0, "squash": 0.3, "width": 4.0, "life_ms": life_ms, "col": WATER[1]}]
	return []


# Corsa: un pizzico dietro ai piedi a ogni passo (dir = verso dove corre)
static func run_step(style: String, key: int, x: float, y: float, dir: float) -> Array:
	match style:
		"chi":
			return _chi_wisps(key, x - dir * 14.0, y - 10.0, 1, -dir * 40.0)
		"glitch":
			return _pixels(key, x - dir * 14.0, y - 6.0, 2, -dir * 30.0, false)
		"water":
			return _drops(key, x - dir * 10.0, y, 2, -dir * 50.0)
	return []


# Fili di energia verde che salgono ondeggiando, luminosi (fusione additiva). down: spinti in giù dal doppio salto
static func _chi_wisps(key: int, x: float, y: float, n: int, kick: float, down := false) -> Array:
	var r := _rng(key)
	var out: Array = []
	for i in n:
		var sd := 1.0 if i % 2 == 1 else -1.0
		out.append({"x": x, "ox": sd * r.randf_range(2, 10), "y": y, "oy": -r.randf_range(2, 6),
			"vx": sd * r.randf_range(10, 45) + kick * 0.4, "vy": r.randf_range(10, 40) if down else -r.randf_range(25, 60),
			"drag": 2.5, "gy": -40.0, "s0": r.randf_range(4.5, 6), "s1": r.randf_range(1.2, 2), "life": r.randf_range(0.45, 0.75),
			"rot": r.randf_range(-0.2, 0.2), "v": i % ParticleFx.VARIANTS, "shape": "flame", "stretch": r.randf_range(1.8, 2.6),
			"ramp": ["tint"], "tint": CHI_GREEN, "add": true, "alpha": 1.0})
	return out


# Stelline rosse a cinque punte che saltano su e ricadono (kind "star5", le disegna particle_view)
static func _red_stars(key: int, x: float, y: float, n: int) -> Array:
	var r := _rng(key + 1)
	var out: Array = []
	for i in n:
		var sd := 1.0 if i % 2 == 0 else -1.0
		out.append({"kind": "star5", "x": x, "y": y, "oy": -4.0, "vx": sd * r.randf_range(25, 60), "vy": -r.randf_range(70, 110),
			"drag": 1.2, "gy": 260.0, "life": r.randf_range(0.45, 0.6), "s": r.randf_range(2.6, 3.4), "spin": sd * r.randf_range(4, 8),
			"col": CHI_RED, "floor": y})
	return out


# Quadratini di pixel che saltano a scatti sulla griglia e sfarfallano (kind "pixel")
static func _pixels(key: int, x: float, y: float, n: int, kick: float, down: bool) -> Array:
	var r := _rng(key + 2)
	var out: Array = []
	for i in n:
		var a := PI * (0.05 + 0.9 * r.randf()) if down else -PI * (0.1 + 0.8 * r.randf())
		var sp := r.randf_range(40, 120)
		out.append({"kind": "pixel", "x": x, "ox": r.randf_range(-10, 10), "y": y, "oy": -r.randf_range(2, 14),
			"vx": cos(a) * sp + kick * 0.5, "vy": sin(a) * sp * (0.8 if down else 0.6), "drag": 4.0, "gy": 0.0,
			"life": r.randf_range(0.35, 0.6), "s": [2.0, 3.0, 4.0][i % 3], "col": GLITCH[i % GLITCH.size()], "seed": key * 31 + i})
	return out


# Gocce che schizzano su e ricadono: tratti azzurri (kind "spark" disegnato sopra, luminoso)
static func _drops(key: int, x: float, y: float, n: int, kick: float, down := false) -> Array:
	var r := _rng(key + 3)
	var out: Array = []
	for i in n:
		var sd := 1.0 if i % 2 == 1 else -1.0
		var vy := r.randf_range(20, 80) if down else -r.randf_range(90, 190)
		out.append({"kind": "spark", "x": x, "ox": sd * r.randf_range(2, 9), "y": y, "oy": -2.0,
			"vx": sd * r.randf_range(25, 85) + kick * 0.6, "vy": vy, "drag": 1.4, "gy": 520.0,
			"life": r.randf_range(0.35, 0.55), "w": r.randf_range(1.5, 2.2), "col": WATER[i % WATER.size()]})
	return out


# Schiuma: sbuffi chiari e azzurrini che scivolano bassi
static func _foam(key: int, x: float, y: float, n: int, kick: float) -> Array:
	var r := _rng(key + 4)
	var out: Array = []
	for i in n:
		var sd := 1.0 if i % 2 == 1 else -1.0
		out.append({"x": x, "ox": sd * r.randf_range(4, 12), "y": y, "oy": -2.0, "vx": sd * r.randf_range(30, 70) + kick,
			"vy": -r.randf_range(2, 10), "drag": 5.0, "gy": -4.0, "s0": 3.0, "s1": r.randf_range(6, 9),
			"life": r.randf_range(0.35, 0.55), "rot": r.randf() * TAU, "v": i % ParticleFx.VARIANTS, "ramp": ["tint"],
			"tint": FOAM, "alpha": 0.8})
	return out


# Dove sta un quadratino all'età a: si muove a scatti di 4 px (come un'immagine che si blocca)
static func pixel_at(p: Dictionary, a: float) -> Vector2:
	var pos := ParticleFx.at(p, floorf(a * 24.0) / 24.0)
	return Vector2(snappedf(pos.x, 4.0), snappedf(pos.y, 4.0))


# Se un quadratino si vede all'età a: sfarfalla, di più verso la fine
static func pixel_visible(p: Dictionary, a: float) -> bool:
	var k := a / float(p.life)
	if k < 0.0 or k >= 1.0:
		return false
	var tick := int(a * 30.0) + int(p.get("seed", 0))
	return k < 0.5 or (tick * 7) % 10 >= int(k * 8.0)
