# Giorno e notte delle arene (#267, #288): fase del giorno, cielo, sole e luna, nuvole, lampioni e finestre accese.
# Solo grafica, calcolata dal tempo dell'arena. Fa parte dello sfondo vivo (stage_life.gd), che la crea e le passa
# i dati dell'arena; world_view.gd la usa tramite stage_life.sky.
extends RefCounted

var _owner: WeakRef # debole: lo sfondo vivo tiene già questo oggetto, così nessuno dei due resta in memoria per sempre
# Lo sfondo vivo (stage_life.gd) a cui appartiene: dati dell'arena, fogli dipinti, parallasse
var _l: RefCounted:
	get:
		return _owner.get_ref()


func _init(owner_life: RefCounted) -> void:
	_owner = weakref(owner_life)


# --- giorno e notte: un giro completo in cycleMs dall'inizio della partita, che riparte da startAt (0 = mezzogiorno) ---
# Fase del giorno da 0 a 1: 0 mezzogiorno, 0,25 tramonto, 0,5 mezzanotte, 0,75 alba
func day_phase(t: float) -> float:
	var d: Variant = _l.life.get("daycycle")
	if not d is Dictionary:
		return 0.0
	if is_nan(_l.match_start):
		_l.match_start = t
	return fposmod((t - _l.match_start) / float(d.cycleMs) + float(d.get("startAt", 0.0)), 1.0)


# Quanto è buio (0 giorno pieno, 1 notte piena): sale tra il pomeriggio e il tramonto, scende all'alba
static func darkness(phase: float) -> float:
	var c := 0.5 - 0.5 * cos(phase * TAU) # 0 a mezzogiorno, 1 a mezzanotte
	return clampf((c - 0.25) / 0.5, 0.0, 1.0)


# I momenti del giorno (#267): [fase, cielo in alto, cielo all'orizzonte, luce sulle cose]
const SKY_KEYS := [
	[0.0, Color8(92, 140, 196), Color8(190, 212, 226), Color(1, 1, 1)], # mezzogiorno
	[0.15, Color8(98, 138, 190), Color8(218, 208, 190), Color(1, 0.96, 0.9)], # pomeriggio, luce dorata
	[0.25, Color8(84, 84, 140), Color8(248, 148, 88), Color(1, 0.78, 0.6)], # tramonto
	[0.31, Color8(40, 42, 92), Color8(160, 82, 108), Color(0.66, 0.56, 0.72)], # crepuscolo viola
	[0.4, Color8(12, 16, 40), Color8(34, 42, 76), Color(0.34, 0.38, 0.58)], # notte
	[0.6, Color8(12, 16, 40), Color8(34, 42, 76), Color(0.34, 0.38, 0.58)],
	[0.69, Color8(36, 40, 86), Color8(132, 92, 132), Color(0.52, 0.5, 0.66)], # prima dell'alba
	[0.75, Color8(112, 132, 182), Color8(252, 182, 150), Color(1, 0.84, 0.76)], # alba rosa
	[0.86, Color8(108, 158, 208), Color8(214, 222, 226), Color(1, 0.98, 0.95)], # mattina
	[1.0, Color8(92, 140, 196), Color8(190, 212, 226), Color(1, 1, 1)],
]


# I tre colori del momento (cielo in alto, all'orizzonte, luce), sfumando tra i momenti vicini
static func sky_colors(phase: float) -> Array:
	var p := fposmod(phase, 1.0)
	for i in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if p >= a[0] and p <= b[0]:
			var k: float = (p - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
			k = k * k * (3.0 - 2.0 * k) # sfumatura dolce
			return [(a[1] as Color).lerp(b[1], k), (a[2] as Color).lerp(b[2], k), (a[3] as Color).lerp(b[3], k)]
	return [SKY_KEYS[0][1], SKY_KEYS[0][2], SKY_KEYS[0][3]]


# La luce del momento, che moltiplica strati, decorazioni e sfondo vivo (bianca senza ciclo del giorno)
func ambient(t: float) -> Color:
	if not _l.life.get("daycycle") is Dictionary:
		return Color.WHITE
	return sky_colors(day_phase(t))[2]


# Il sole va dall'alba (0,75) al tramonto (0,25), la luna dal tramonto all'alba: k 0 sorge a sinistra, 0,5 in cima, 1 tramonta.
# Il cielo segue quasi la telecamera: l'arco sta dentro lo schermo e ai lati scende sotto l'orizzonte, dietro i palazzi
static func sky_body(phase: float, width_: float) -> Vector2:
	var k := fposmod(phase + 0.25, 0.5) / 0.5
	# in cima a destra del centro, così il palazzo di Padova non lo copre; la luna fa lo stesso giro
	return Vector2(width_ / 2.0 - 450.0 + 1500.0 * k, 30.0 + 510.0 * pow(absf(k - 0.5) * 2.0, 2.0))


# Le nuvole (#267): ognuna con quota, grandezza, velocità e profondità sue, sempre uguali per la stessa arena
static func cloud_at(i: int, t: float, span: float) -> Dictionary:
	var far := i % 2 == 0 # metà lontane (piccole e lente), metà più vicine
	var speed := (5.0 if far else 11.0) + float((i * 13) % 7) # pixel/s, verso destra
	var x := fposmod(float(i) * 731.0 + speed * t / 1000.0, span)
	var y := -260.0 + float((i * 97) % 300) + (0.0 if far else 60.0)
	return {"x": x, "y": y, "size": (110.0 if far else 190.0) + float((i * 53) % 90), "parallax": 0.06 if far else 0.16}


# Il cielo intero: gradiente, sole o luna, stelle e nuvole. Si disegna prima degli strati, che ci passano davanti
func draw_sky(ci: CanvasItem, t: float, view: Rect2) -> void:
	var d: Variant = _l.life.get("daycycle")
	if not d is Dictionary or not d.get("sky", false):
		return
	var phase := day_phase(t)
	var cols := sky_colors(phase)
	var top: Color = cols[0]
	var horizon: Color = cols[1]
	var vc := view.get_center()
	var hy: float = 470.0 + _l.offset(0.08, vc).y # l'orizzonte, dietro i palazzi
	var r := view.grow(60)
	var mid := top.lerp(horizon, 0.45)
	var my := lerpf(r.position.y, hy, 0.55)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, my), Vector2(r.position.x, my)]), PackedColorArray([top, top, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(r.position.x, my), Vector2(r.end.x, my), Vector2(r.end.x, hy), Vector2(r.position.x, hy)]), PackedColorArray([mid, mid, horizon, horizon]))
	ci.draw_rect(Rect2(r.position.x, hy, r.size.x, maxf(0.0, r.end.y - hy)), horizon)
	var dark := darkness(phase)
	var off: Vector2 = _l.offset(0.08, vc)
	# stelle, prima del resto
	if dark > 0.45:
		var a := clampf((dark - 0.45) / 0.4, 0.0, 1.0)
		for i in 90:
			var sx: float = fposmod(i * 0.6180339 * 3000.0, _l.width + 1400.0) - 700.0
			var sy := -420.0 + fposmod(i * 0.4142136 * 1000.0, 700.0)
			var tw := 0.55 + 0.45 * sin(t / 280.0 + i * 1.7)
			ci.draw_circle(Vector2(sx, sy) + off, 1.2 + (i % 3) * 0.6, Color(1, 1, 0.92, a * tw))
	# sole di giorno, luna di notte
	var body: Vector2 = sky_body(phase, _l.width) + off
	if phase < 0.25 or phase >= 0.75:
		var low := clampf(absf(fposmod(phase + 0.25, 0.5) / 0.5 - 0.5) * 2.0, 0.0, 1.0) # 1 vicino all'orizzonte
		var col := Color(1.0, 0.97, 0.82).lerp(Color(1.0, 0.55, 0.28), low * low)
		for j in 4:
			ci.draw_circle(body, 90.0 - j * 18.0, Color(col.r, col.g, col.b, 0.07 + j * 0.05))
		ci.draw_circle(body, 30.0, col)
	else:
		for j in 3:
			ci.draw_circle(body, 54.0 - j * 12.0, Color(0.85, 0.88, 1.0, 0.05 + j * 0.03))
		ci.draw_circle(body, 22.0, Color(0.95, 0.95, 0.9))
		ci.draw_circle(body + Vector2(-6, -4), 6.0, Color(0.82, 0.83, 0.82))
		ci.draw_circle(body + Vector2(7, 6), 4.0, Color(0.82, 0.83, 0.82))
	# nuvole che scorrono, colorate dalla luce: bianche di giorno, rosa e arancio all'alba e al tramonto, scure di notte
	var lit := Color(0.96, 0.97, 0.98).lerp(horizon.lightened(0.25), 0.5 * clampf(dark * 2.0, 0.0, 1.0))
	lit = lit.lerp(Color(0.32, 0.36, 0.5), clampf((dark - 0.5) * 2.0, 0.0, 1.0))
	var shade := lit.darkened(0.16).lerp(top, 0.25)
	var span: float = _l.width + 1600.0
	for i in 12:
		var c := cloud_at(i, t, span)
		var o: Vector2 = _l.offset(float(c.parallax), vc)
		var cp := Vector2(float(c.x) - 800.0, float(c.y)) + o
		var sh: Variant = _l._sheets.get("nuvole")
		if sh != null:
			# la nuvola dipinta, larga come quella di prima e colorata dalla luce del momento (#288)
			_l.draw_frame(ci, "nuvole", i, cp + Vector2(0, -float(c.size) * 0.12), float(c.size) * 1.35 / (float(sh.fw) * float(sh.scale)), i % 3 == 1, lit.lerp(Color.WHITE, 0.25))
		else:
			_draw_cloud(ci, cp, float(c.size), lit, shade, i)


static func _draw_cloud(ci: CanvasItem, pos: Vector2, w: float, lit: Color, shade: Color, seed: int) -> void:
	# prima la pancia in ombra (batuffoli bassi e larghi), poi i batuffoli in luce sopra, un po' spostati in alto
	for j in 4:
		var px := pos.x - w * 0.3 + j * w * 0.2
		ci.draw_circle(Vector2(px, pos.y + w * 0.02), w * 0.13, shade)
	for j in 5:
		var px := pos.x - w * 0.36 + j * w * 0.18
		var r := w * (0.12 + 0.06 * sin(seed * 1.3 + j * 2.1) + (0.07 if j == 2 else 0.0))
		ci.draw_circle(Vector2(px, pos.y - r * 0.45 - w * 0.02), r, lit)


# I lampioni accesi (#288) di uno strato, subito dopo di lui: l'alone attorno alla lanterna, il cono di luce che
# scende e la pozza chiara a terra (ground pixel sotto la lanterna). Così stanno dietro alle statue del palco
func draw_lamps(ci: CanvasItem, t: float, view: Rect2, parallax: float, ground := 101.0) -> void:
	var d: Variant = _l.life.get("daycycle")
	if not d is Dictionary:
		return
	var on := night_lights(t)
	if on <= 0.0:
		return
	for l in d.get("lamps", []):
		if absf(float(l.parallax) - parallax) > 0.001:
			continue
		var p: Vector2 = Vector2(l.x, l.y) + _l.offset(float(l.parallax), view.get_center())
		var warm := Color(1.0, 0.84, 0.55)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 8), p + Vector2(7, 8), p + Vector2(34, ground), p + Vector2(-34, ground)]), Color(warm, 0.12 * on))
		var pool := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pool.append(p + Vector2(cos(a) * 40.0, ground + sin(a) * 5.0))
		ci.draw_colored_polygon(pool, Color(warm, 0.22 * on))
		for j in 3:
			ci.draw_circle(p, 5.0 + j * 7.0, Color(warm, (0.32 - j * 0.09) * on))


# Quanto sono accese le luci della notte (#288): da 0 di giorno a 1 di sera, con la stessa soglia dei lampioni
func night_lights(t: float) -> float:
	if not _l.life.get("daycycle") is Dictionary:
		return 0.0
	return clampf((darkness(day_phase(t)) - 0.2) / 0.3, 0.0, 1.0)


# Di notte lampioni e finestre accese (dopo le decorazioni, che intanto la luce ambiente ha scurito)
func draw_daycycle(ci: CanvasItem, t: float, view: Rect2) -> void:
	var d: Variant = _l.life.get("daycycle")
	if not d is Dictionary:
		return
	var dark := darkness(day_phase(t))
	var on := clampf((dark - 0.2) / 0.3, 0.0, 1.0) # i lampioni si accendono al tramonto e si spengono all'alba
	if on <= 0.0:
		return
	var windows: Array = d.get("windows", [])
	for i in windows.size():
		# le finestre si accendono una alla volta, non tutte insieme
		var w: Dictionary = windows[i]
		var lit := clampf((dark - 0.25 - 0.06 * (i % 5)) / 0.15, 0.0, 1.0)
		if lit > 0.0:
			ci.draw_rect(Rect2(w.x, w.y, w.width, w.height), Color(1.0, 0.78, 0.42, 0.8 * lit))
