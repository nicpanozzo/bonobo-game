# Sfondo vivo delle arene (#260): stormi, piccioni, passanti, veicoli e tramonto. Solo grafica: tutto si calcola
# dal tempo dell'arena (stageMs) e dalle posizioni dei lottatori che il client ha già, niente passa in rete.
# world_view.gd lo chiama dentro _draw: gli elementi con parallasse p si disegnano dopo gli strati più lontani di p.
extends RefCounted

const INK := Color("1e1a17")
# Colori spenti, lontani dai colori dei giocatori (style guide, sezione 7)
const CLOTHES := [Color("5b5650"), Color("6a5f52"), Color("4f5560"), Color("6b6058"), Color("585a50"), Color("625a62")]
const UMBRELLAS := [Color("4c4f5a"), Color("6a4f4a"), Color("4f5f58"), Color("5e5a4a"), Color("3f4048")]

var life: Dictionary = {}
var width := 1280.0 # larghezza dell'arena
var center := Vector2(640, 360) # centro dell'arena, dove sono centrati gli strati
var match_start := NAN # stageMs di inizio della partita, per il tramonto
var _pigeons: Array = [] # per ogni piccione: {x, y, away (ms dell'orologio del client in cui è scappato, -1 se posato)}


func setup(spec: Dictionary, stage_width: float, world_height: float) -> void:
	var art: Dictionary = spec.get("art", {}) if spec.get("art") is Dictionary else {}
	life = art.get("life", {}) if art.get("life") is Dictionary else {}
	width = stage_width
	center = Vector2(stage_width / 2.0, world_height / 2.0)
	match_start = NAN
	_pigeons = []
	for p in life.get("pigeons", []):
		_pigeons.append({"x": float(p.x), "y": float(p.y), "away": -1.0})


func is_empty() -> bool:
	return life.is_empty()


# Dove appare un punto che sta su uno strato con parallasse p: come gli strati, trascinato verso la vista
func offset(p: float, view_center: Vector2) -> Vector2:
	return (view_center - center) * (1.0 - p)


# Gli elementi con parallasse in [from, to): stormi, veicoli e passanti
func draw_band(ci: CanvasItem, from: float, to: float, t: float, view_center: Vector2, rain: float, amb := Color.WHITE) -> void:
	var birds: Variant = life.get("birds")
	if birds is Dictionary and float(birds.parallax) >= from and float(birds.parallax) < to:
		_draw_birds(ci, birds, t, offset(float(birds.parallax), view_center), amb)
	var veh: Variant = life.get("vehicles")
	if veh is Dictionary and float(veh.parallax) >= from and float(veh.parallax) < to:
		_draw_vehicle(ci, veh, t, offset(float(veh.parallax), view_center), amb)
	var walk: Variant = life.get("walkers")
	if walk is Dictionary and float(walk.parallax) >= from and float(walk.parallax) < to:
		_draw_walkers(ci, walk, t, offset(float(walk.parallax), view_center), rain, amb)


# --- stormi: ogni everyMs uno stormo a V attraversa il cielo in 10 s, un giro da sinistra e uno da destra ---
static func bird_flock(everyMs: float, t: float) -> Dictionary:
	var cycle := floorf(t / everyMs)
	var k := (t - cycle * everyMs) / 10000.0
	return {"k": k, "dir": 1 if int(cycle) % 2 == 0 else -1, "on": k < 1.0}


func _draw_birds(ci: CanvasItem, b: Dictionary, t: float, off: Vector2, amb: Color) -> void:
	if amb.v < 0.5:
		return # di notte gli uccelli dormono
	# tre stormi lontani con giri, quote e grandezze diverse (#267): il primo è quello dell'arena, gli altri più piccoli
	for j in 3:
		var every := float(b.everyMs) * (1.0 + 0.43 * j)
		var f := bird_flock(every, t + j * 5300.0)
		if not f.on:
			continue
		var size := 1.0 - 0.28 * j
		var span := width + 900.0
		var k: float = f.k
		var lead_x: float = -450.0 + span * k if int(f.dir) > 0 else width + 450.0 - span * k
		var n := 7 - j * 2
		for i in n:
			var row := (i + 1) / 2
			var side := 1 if i % 2 == 0 else -1
			var x: float = lead_x - float(f.dir) * row * 26.0 * size
			var y := float(b.y) + j * 70.0 + row * 12.0 * side * size + sin(t / 400.0 + i + j) * 4.0
			var flap := sin(t / 90.0 + i * 1.3 + j) * 5.0 * size
			var p := Vector2(x, y) + off * (1.0 - 0.3 * j)
			var col := Color(0.18, 0.2, 0.26, 0.85 - 0.2 * j) * Color(amb.r, amb.g, amb.b, 1.0)
			ci.draw_polyline(PackedVector2Array([p + Vector2(-8, -flap) * size, p, p + Vector2(8, -flap) * size]), col, 2.0 * size + 0.5)


# --- veicolo: ogni everyMs passa in 12 s, alternando il verso ---
func _draw_vehicle(ci: CanvasItem, v: Dictionary, t: float, off: Vector2, amb := Color.WHITE) -> void:
	var every := float(v.everyMs)
	var cycle := floorf(t / every)
	var k := (t - cycle * every) / 12000.0
	if k >= 1.0:
		return
	var dir := 1 if int(cycle) % 2 == 0 else -1
	var length := 300.0 if v.kind == "tram" else 150.0
	var span := width + 1400.0 + length
	var x: float = -700.0 - length + span * k if dir > 0 else width + 700.0 - span * k
	var base := float(v.y)
	var body := (Color("7a6a5c") if v.kind == "tram" else Color("6c7064")) * amb
	var h := 52.0
	var o := off + Vector2(x, base - h - 10)
	ci.draw_rect(Rect2(o, Vector2(length, h)), body)
	ci.draw_rect(Rect2(o + Vector2(0, h - 12), Vector2(length, 12)), body.darkened(0.25))
	ci.draw_rect(Rect2(o, Vector2(length, h)), INK, false, 2.0)
	var n := int(length / 34)
	for i in n:  # finestrini, con qualche passeggero in sagoma
		var wx := o.x + 10 + i * (length - 20) / n
		ci.draw_rect(Rect2(wx, o.y + 8, 22, 18), Color("3c3d40"))
		if (i * 7 + int(cycle)) % 3 != 0:
			ci.draw_circle(Vector2(wx + 11, o.y + 20), 4.0, Color("5a5550"))
	for wx in [o.x + 30, o.x + length - 30]:
		ci.draw_circle(Vector2(wx, o.y + h + 4), 7.0, INK)
	if v.kind == "tram":  # pantografo e filo
		ci.draw_polyline(PackedVector2Array([o + Vector2(length / 2 - 20, 0), o + Vector2(length / 2, -18), o + Vector2(length / 2 + 20, 0)]), INK, 2.0)


# --- passanti: ognuno con passo, verso e partenza suoi, sempre uguali per la stessa arena ---
static func walker_x(i: int, t: float, span: float) -> float:
	var speed := 26.0 + float((i * 37) % 30) # pixel/s
	var dir := 1.0 if i % 2 == 0 else -1.0
	return fposmod(float(i) * 397.0 + dir * speed * t / 1000.0, span)


func _draw_walkers(ci: CanvasItem, w: Dictionary, t: float, off: Vector2, rain: float, amb := Color.WHITE) -> void:
	var span := width + 600.0
	var base := float(w.y)
	var umbrellas: bool = w.get("umbrellas", false) and rain > 0.25
	for i in int(w.count):
		var x := walker_x(i, t, span) - 300.0
		var dir := 1.0 if i % 2 == 0 else -1.0
		var step := sin(t / 180.0 * (1.0 + 0.1 * (i % 3)) + i)
		var p := off + Vector2(x, base)
		var hgt := 34.0 + float(i % 3) * 3.0
		var col: Color = CLOTHES[i % CLOTHES.size()] * amb
		ci.draw_line(p, p + Vector2(-4 + step * 4, -hgt * 0.42), Color("3a3836"), 3.0) # gambe che camminano
		ci.draw_line(p, p + Vector2(4 - step * 4, -hgt * 0.42), Color("3a3836"), 3.0)
		ci.draw_rect(Rect2(p + Vector2(-5, -hgt * 0.86), Vector2(10, hgt * 0.46)), col)
		ci.draw_circle(p + Vector2(0, -hgt), 5.0, Color("8a7a6a"))
		if umbrellas and i % 4 != 3:
			var top := p + Vector2(dir * 2, -hgt - 16)
			ci.draw_line(p + Vector2(dir * 4, -hgt * 0.7), top, INK, 1.5)
			var arc := PackedVector2Array()
			for a in 9:
				var ang := PI + PI * a / 8.0
				arc.append(top + Vector2(cos(ang) * 16, sin(ang) * 9 + 4))
			ci.draw_colored_polygon(arc, UMBRELLAS[i % UMBRELLAS.size()] * amb)
		elif i % 5 == 1:  # qualcuno con il sacchetto del mercato
			ci.draw_rect(Rect2(p + Vector2(dir * 6, -hgt * 0.5), Vector2(7, 8)), Color("a49a86"))


# --- piccioni: posati finché nessuno arriva vicino; scappano verso l'alto e tornano dopo un po' ---
const PIGEON_NEAR := Vector2(110, 120) # pixel orizzontali e verticali da cui un lottatore li fa scappare
const PIGEON_FLY_MS := 1400.0
const PIGEON_BACK_MS := 7000.0


static func pigeon_scared(p: Dictionary, fighters: Array, threats: Array) -> bool:
	for f in fighters:
		if absf(f.x - p.x) < PIGEON_NEAR.x and absf(f.y - p.y) < PIGEON_NEAR.y:
			return true
	for r in threats:
		if (r as Rect2).grow(60).has_point(Vector2(p.x, p.y)):
			return true
	return false


func draw_pigeons(ci: CanvasItem, t: float, now: float, fighters: Array, threats: Array) -> void:
	for p in _pigeons:
		if p.away < 0 and pigeon_scared(p, fighters, threats):
			p.away = now
		var away: float = p.away
		var dt: float = now - away
		if p.away >= 0 and dt > PIGEON_BACK_MS and not pigeon_scared(p, fighters, threats):
			p.away = -1.0
		var pos := Vector2(p.x, p.y)
		var flying := false
		if p.away >= 0:
			if dt < PIGEON_FLY_MS:
				var k := dt / PIGEON_FLY_MS
				pos += Vector2(160.0 * k * (1 if int(p.x) % 2 == 0 else -1), -260.0 * k * k)
				flying = true
			else:
				continue # lontano, fuori scena
		_draw_pigeon(ci, pos, t + p.x, flying)


static func _draw_pigeon(ci: CanvasItem, pos: Vector2, t: float, flying: bool) -> void:
	var grey := Color("8d8f96")
	ci.draw_circle(pos + Vector2(0, -6), 6.0, grey) # corpo
	ci.draw_circle(pos + Vector2(5, -11), 3.5, Color("7c7e86")) # testa
	ci.draw_line(pos + Vector2(8, -11), pos + Vector2(11, -10), Color("c09060"), 1.5) # becco
	if flying:
		var flap := sin(t / 60.0) * 8.0
		ci.draw_polyline(PackedVector2Array([pos + Vector2(-10, -8 - flap), pos + Vector2(0, -7), pos + Vector2(10, -8 - flap)]), grey.darkened(0.2), 3.0)
	else:
		ci.draw_line(pos + Vector2(-2, -1), pos + Vector2(-2, 0), INK, 1.5)
		ci.draw_line(pos + Vector2(2, -1), pos + Vector2(2, 0), INK, 1.5)


# --- giorno e notte: un giro completo in cycleMs dall'inizio della partita, che riparte da startAt (0 = mezzogiorno) ---
# Fase del giorno da 0 a 1: 0 mezzogiorno, 0,25 tramonto, 0,5 mezzanotte, 0,75 alba
func day_phase(t: float) -> float:
	var d: Variant = life.get("daycycle")
	if not d is Dictionary:
		return 0.0
	if is_nan(match_start):
		match_start = t
	return fposmod((t - match_start) / float(d.cycleMs) + float(d.get("startAt", 0.0)), 1.0)


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
	if not life.get("daycycle") is Dictionary:
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
	var d: Variant = life.get("daycycle")
	if not d is Dictionary or not d.get("sky", false):
		return
	var phase := day_phase(t)
	var cols := sky_colors(phase)
	var top: Color = cols[0]
	var horizon: Color = cols[1]
	var vc := view.get_center()
	var hy := 470.0 + offset(0.08, vc).y # l'orizzonte, dietro i palazzi
	var r := view.grow(60)
	var mid := top.lerp(horizon, 0.45)
	var my := lerpf(r.position.y, hy, 0.55)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, my), Vector2(r.position.x, my)]), PackedColorArray([top, top, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(r.position.x, my), Vector2(r.end.x, my), Vector2(r.end.x, hy), Vector2(r.position.x, hy)]), PackedColorArray([mid, mid, horizon, horizon]))
	ci.draw_rect(Rect2(r.position.x, hy, r.size.x, maxf(0.0, r.end.y - hy)), horizon)
	var dark := darkness(phase)
	var off := offset(0.08, vc)
	# stelle, prima del resto
	if dark > 0.45:
		var a := clampf((dark - 0.45) / 0.4, 0.0, 1.0)
		for i in 90:
			var sx := fposmod(i * 0.6180339 * 3000.0, width + 1400.0) - 700.0
			var sy := -420.0 + fposmod(i * 0.4142136 * 1000.0, 700.0)
			var tw := 0.55 + 0.45 * sin(t / 280.0 + i * 1.7)
			ci.draw_circle(Vector2(sx, sy) + off, 1.2 + (i % 3) * 0.6, Color(1, 1, 0.92, a * tw))
	# sole di giorno, luna di notte
	var body := sky_body(phase, width) + off
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
	var span := width + 1600.0
	for i in 12:
		var c := cloud_at(i, t, span)
		var o := offset(float(c.parallax), vc)
		_draw_cloud(ci, Vector2(float(c.x) - 800.0, float(c.y)) + o, float(c.size), lit, shade, i)


static func _draw_cloud(ci: CanvasItem, pos: Vector2, w: float, lit: Color, shade: Color, seed: int) -> void:
	# prima la pancia in ombra (batuffoli bassi e larghi), poi i batuffoli in luce sopra, un po' spostati in alto
	for j in 4:
		var px := pos.x - w * 0.3 + j * w * 0.2
		ci.draw_circle(Vector2(px, pos.y + w * 0.02), w * 0.13, shade)
	for j in 5:
		var px := pos.x - w * 0.36 + j * w * 0.18
		var r := w * (0.12 + 0.06 * sin(seed * 1.3 + j * 2.1) + (0.07 if j == 2 else 0.0))
		ci.draw_circle(Vector2(px, pos.y - r * 0.45 - w * 0.02), r, lit)


# Di notte lampioni e finestre accese (dopo le decorazioni, che intanto la luce ambiente ha scurito)
func draw_daycycle(ci: CanvasItem, t: float, view: Rect2) -> void:
	var d: Variant = life.get("daycycle")
	if not d is Dictionary:
		return
	var dark := darkness(day_phase(t))
	var on := clampf((dark - 0.2) / 0.3, 0.0, 1.0) # i lampioni si accendono al tramonto e si spengono all'alba
	if on <= 0.0:
		return
	var view_center := view.get_center()
	for l in d.get("lamps", []):
		var p := Vector2(l.x, l.y) + offset(float(l.parallax), view_center)
		for j in 3:
			ci.draw_circle(p, 6.0 + j * 9.0, Color(1.0, 0.82, 0.5, (0.5 - j * 0.15) * on))
	var windows: Array = d.get("windows", [])
	for i in windows.size():
		# le finestre si accendono una alla volta, non tutte insieme
		var w: Dictionary = windows[i]
		var lit := clampf((dark - 0.25 - 0.06 * (i % 5)) / 0.15, 0.0, 1.0)
		if lit > 0.0:
			ci.draw_rect(Rect2(w.x, w.y, w.width, w.height), Color(1.0, 0.78, 0.42, 0.8 * lit))


# --- acqua intorno all'arena (#264): davanti a chi cade, con lo splash quando qualcuno ci finisce dentro ---
var _last_y := {} # id del lottatore -> y del frame prima
var _splashes: Array = [] # [x, y, ms dell'orologio del client]
const SPLASH_MS := 700.0


func outer_water_level(up: float) -> float:
	var w: Dictionary = life.get("outerWater", {})
	return lerpf(float(w.y), float(w.get("highY", w.y)), up)


func draw_outer_water(ci: CanvasItem, t: float, now: float, up: float, view: Rect2, fighters: Dictionary) -> void:
	if not life.get("outerWater") is Dictionary:
		return
	var level := outer_water_level(up)
	for id in fighters:
		var y: float = fighters[id].y
		if _last_y.has(id) and _last_y[id] < level and y >= level:
			_splashes.append([fighters[id].x, level, now])
		_last_y[id] = y
	var left := view.position.x - 40.0
	var right := view.end.x + 40.0
	var bottom := maxf(view.end.y, level) + 40.0
	var amb := ambient(t) # l'acqua prende la luce del momento: dorata al tramonto, scura di notte
	ci.draw_rect(Rect2(left, level, right - left, bottom - level), Color(0.27 * amb.r, 0.38 * amb.g, 0.4 * amb.b, 0.9))
	var wave := PackedVector2Array()
	var x := left
	while x <= right:
		wave.append(Vector2(x, level + 3.0 * sin(t / 300.0 + x / 41.0)))
		x += 18.0
	ci.draw_polyline(wave, Color("a9c2bf"), 2.5)
	for i in 4: # riflessi che scorrono
		var ry := level + 18.0 + i * 22.0
		var rx := left + fposmod(t / 30.0 + i * 140.0, 260.0)
		while rx < right:
			ci.draw_line(Vector2(rx, ry), Vector2(rx + 40.0, ry), Color(0.66, 0.76, 0.75, 0.25), 1.5)
			rx += 260.0
	var keep: Array = []
	for sp in _splashes:
		var k: float = (now - sp[2]) / SPLASH_MS
		if k >= 1.0:
			continue
		keep.append(sp)
		for j in 7: # gocce che saltano in alto e ricadono
			var ang := PI + PI * (j + 0.5) / 7.0
			var dist := 60.0 * k
			var p := Vector2(sp[0] + cos(ang) * dist, sp[1] + sin(ang) * dist * 1.4 + 90.0 * k * k)
			ci.draw_circle(p, 4.0 * (1.0 - k) + 1.0, Color(0.85, 0.93, 0.92, 1.0 - k))
		ci.draw_arc(Vector2(sp[0], sp[1]), 20.0 + 50.0 * k, PI, TAU, 16, Color(0.85, 0.93, 0.92, 0.8 * (1.0 - k)), 3.0)
	_splashes = keep
