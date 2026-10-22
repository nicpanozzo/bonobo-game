# Power-up arcade (#427): i pezzi del Tetris che cadono, i blocchi posati e il cabinato di chi gioca;
# Pac-Man, i fantasmini spaventati al posto degli altri e le palline da mangiare.
# Solo disegno: pezzi, blocchi e Pac-Man arrivano nello snapshot, calcolati dal server in physics/arcade.ts.
# Le palline sono solo del client: spariscono dove passa Pac-Man e non contano per la partita.
# world_view.gd lo chiama dentro _draw.
extends RefCounted

# I colori classici delle sette forme
const COLORS := {"I": Color("29d3ea"), "O": Color("ffd23f"), "T": Color("b04df0"), "L": Color("ff9a1f"), "J": Color("3d6df2"), "S": Color("4ee05a"), "Z": Color("f2424a")}
const INK := Color("101018")
const PAC_YELLOW := Color("ffe11a")
const GHOST_BLUE := Color("2a3cff")
const PELLET := Color("ffd9b0")
const PELLET_STEP := 40.0 # pixel tra due palline

var cell := 40.0
var fade_ms := 1500.0
var pieces: Array = []
var blocks: Array = []
var fighter_h := 90.0
var pac_ms := 8000.0
var _pellets: Array = [] # [posizione, pallina grande]
var _lines: Array = [] # righe del Tetris che esplodono: [{ x, y, width, at }], x e y al centro
const LINE_MS := 450.0 # ms del lampo di una riga


func setup(game: Dictionary) -> void:
	var t: Dictionary = game.get("tetris", {})
	cell = float(t.get("cellPx", 40))
	fade_ms = float(t.get("fadeMs", 1500))
	fighter_h = float(game.get("fighter", {}).get("height", 90))
	pac_ms = float(game.get("pacman", {}).get("ms", 8000))


func on_snapshot(snap: Dictionary) -> void:
	var t: Variant = snap.get("tetris")
	pieces = t.pieces if t is Dictionary else []
	blocks = t.blocks if t is Dictionary else []


func clear() -> void:
	pieces = []
	blocks = []
	_pellets = []
	_lines = []


# Una riga completa (#427): lampo bianco lungo la riga, poi le schegge colorate volano via
func on_line(e: Dictionary, now: int) -> void:
	_lines.append({"x": float(e.x), "y": float(e.y), "width": float(e.get("width", cell)), "at": now})


func draw_lines(canvas: CanvasItem, now: int) -> void:
	_lines = _lines.filter(func(l): return now - int(l.at) < LINE_MS)
	for l: Dictionary in _lines:
		var k := (now - int(l.at)) / LINE_MS
		var h := cell * (1.0 + 2.0 * k)
		canvas.draw_rect(Rect2(l.x - l.width / 2.0 - 10.0 * k, l.y - h / 2.0, l.width + 20.0 * k, h), Color(1, 1, 1, 0.85 * (1.0 - k)))
		# Le schegge: un quadretto per cella, coi colori del Tetris, che sale e si spegne
		var n := int(l.width / cell)
		for i in n:
			var kind: String = COLORS.keys()[i % COLORS.size()]
			var pos := Vector2(l.x - l.width / 2.0 + (i + 0.5) * cell + (i - n / 2.0) * 30.0 * k, l.y - 160.0 * k + 220.0 * k * k)
			draw_cell(canvas, pos - Vector2(cell, cell) * 0.25, cell * 0.5, color_of(kind), 1.0 - k)


static func color_of(kind: String) -> Color:
	return COLORS.get(kind, Color.WHITE)


# Un quadretto col bordo chiaro in alto a sinistra e scuro in basso a destra, come sul Game Boy a colori
static func draw_cell(canvas: CanvasItem, pos: Vector2, size: float, col: Color, alpha := 1.0) -> void:
	var c := Color(col, alpha)
	canvas.draw_rect(Rect2(pos, Vector2(size, size)), c)
	var b := size * 0.14
	canvas.draw_rect(Rect2(pos, Vector2(size, b)), Color(col.lightened(0.45), alpha))
	canvas.draw_rect(Rect2(pos, Vector2(b, size)), Color(col.lightened(0.3), alpha))
	canvas.draw_rect(Rect2(pos + Vector2(0, size - b), Vector2(size, b)), Color(col.darkened(0.4), alpha))
	canvas.draw_rect(Rect2(pos + Vector2(size - b, 0), Vector2(b, size)), Color(col.darkened(0.3), alpha))
	canvas.draw_rect(Rect2(pos, Vector2(size, size)), Color(INK, alpha), false, 2.0)


# I blocchi posati, con il palco: negli ultimi fade_ms lampeggiano sempre più svelti
func draw_blocks(canvas: CanvasItem, now: int) -> void:
	for b: Dictionary in blocks:
		var ms := float(b.ms)
		var alpha := 1.0
		if ms < fade_ms:
			var speed := lerpf(5.0, 16.0, 1.0 - ms / fade_ms)
			alpha = 0.35 + 0.65 * (0.5 + 0.5 * cos(now / 1000.0 * TAU * speed / 2.0))
		draw_cell(canvas, Vector2(float(b.x), float(b.y)), cell, color_of(str(b.kind)), alpha)


# I pezzi che cadono, davanti ai lottatori: con una scia e l'ombra di dove si poserebbero in verticale
func draw_pieces(canvas: CanvasItem, players: Dictionary) -> void:
	for p: Dictionary in pieces:
		var col := color_of(str(p.kind))
		var driver: Variant = players.get(p.ownerId)
		# L'ombra: dove si poserà, così chi è sotto vede che deve spostarsi
		var fall := float(p.get("fall", 0))
		if fall > cell * 0.5:
			for c: Array in p.cells:
				var at := Rect2(Vector2(float(c[0]), float(c[1]) + fall) + Vector2(3, 3), Vector2(cell - 6, cell - 6))
				canvas.draw_rect(at, Color(col, 0.18))
				canvas.draw_rect(at, Color(col, 0.7), false, 2.0)
		for c: Array in p.cells:
			var pos := Vector2(float(c[0]), float(c[1]))
			canvas.draw_rect(Rect2(pos + Vector2(cell * 0.2, -cell * 0.6), Vector2(cell * 0.6, cell * 0.6)), Color(col, 0.18))
			draw_cell(canvas, pos, cell, col)
		# Il filo verso chi lo guida: si capisce di chi è il pezzo
		if driver is Dictionary and str(driver.get("powerup", "")) == "tetris" and not p.cells.is_empty():
			var top := Vector2(float(p.cells[0][0]) + cell / 2.0, float(p.cells[0][1]) + cell)
			var from := Vector2(float(driver.x), float(driver.y) - 110.0)
			var n := int(from.distance_to(top) / 18.0)
			for k in n:
				if k % 2 == 0:
					canvas.draw_line(from.lerp(top, k / float(n)), from.lerp(top, (k + 1) / float(n)), Color(col, 0.45), 2.0)


# Chi gioca a Tetris non è in partita: al suo posto un cabinato col suo colore e lo schermo acceso
static func draw_cabinet(canvas: CanvasItem, p: Dictionary, tint: Color, now: int) -> void:
	var base := Vector2(float(p.x), float(p.y))
	var w := 52.0
	var h := 96.0
	var body := PackedVector2Array([base + Vector2(-w / 2, 0), base + Vector2(w / 2, 0), base + Vector2(w / 2, -h * 0.55), base + Vector2(w / 2 - 6, -h), base + Vector2(-w / 2 + 6, -h), base + Vector2(-w / 2, -h * 0.55)])
	canvas.draw_colored_polygon(body, tint.darkened(0.25))
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), INK, 3.0)
	# Insegna in cima
	canvas.draw_rect(Rect2(base + Vector2(-w / 2 + 8, -h + 4), Vector2(w - 16, 12)), Color("ffd23f"))
	# Schermo con un pezzo che scende
	var screen := Rect2(base + Vector2(-w / 2 + 9, -h + 22), Vector2(w - 18, 34))
	canvas.draw_rect(screen, INK)
	var fall := fposmod(now / 600.0, 1.0)
	var mini := 6.0
	var kinds := COLORS.keys()
	var col: Color = COLORS[kinds[int(now / 600) % kinds.size()]]
	for k in 3:
		canvas.draw_rect(Rect2(screen.position + Vector2(8 + k * mini, 2 + fall * (screen.size.y - 2 * mini - 4)), Vector2(mini - 1, mini - 1)), col)
	for k in 5:
		canvas.draw_rect(Rect2(screen.position + Vector2(2 + k * mini, screen.size.y - mini - 1), Vector2(mini - 1, mini - 1)), COLORS.values()[k])
	# Leva e pulsanti
	var panel := base + Vector2(0, -h * 0.4)
	canvas.draw_line(panel + Vector2(-12, 0), panel + Vector2(-12 + 4 * sin(now / 120.0), -12), INK, 3.0)
	canvas.draw_circle(panel + Vector2(-12 + 4 * sin(now / 120.0), -12), 4.0, Color("f2424a"))
	canvas.draw_circle(panel + Vector2(8, -4), 3.5, Color("4ee05a") if int(now / 200) % 2 == 0 else Color("2a7a30"))
	canvas.draw_circle(panel + Vector2(17, -4), 3.5, Color("3d6df2"))
	# Note che escono: si sente il motivetto
	var font := ThemeDB.fallback_font
	var rise := fposmod(now / 900.0, 1.0)
	canvas.draw_string(font, base + Vector2(w / 2 + 2 + 8 * rise, -h + 10 - 26 * rise), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(tint.lightened(0.4), 1.0 - rise))


# Chi è Pac-Man (#427) nello snapshot campionato, con il centro della bocca
func pacmen(players: Dictionary) -> Array:
	var out := []
	for p: Variant in players.values():
		if p is Dictionary and p.get("powerup") == "pacman" and not p.get("respawning", false) and not p.get("eliminated", false):
			out.append(p)
	return out


# Le palline sulle superfici dell'arena, una ogni PELLET_STEP pixel, ogni tanto una grande
static func pellets_for(stage: Dictionary, width: float) -> Array:
	var out := []
	var tops := []
	for s: Dictionary in stage.get("solids", []):
		tops.append([float(s.x), float(s.width), float(s.y)])
	for p: Dictionary in stage.get("platforms", []):
		tops.append([float(p.x), float(p.width), float(p.y)])
	for t: Array in tops:
		var x: float = maxf(t[0], 0.0) + PELLET_STEP / 2.0
		var end: float = minf(t[0] + t[1], width) - PELLET_STEP / 2.0
		var i := 0
		while x <= end:
			out.append([Vector2(x, t[2] - 40.0), i % 8 == 4])
			x += PELLET_STEP
			i += 1
	return out


# Le palline compaiono quando qualcuno diventa Pac-Man e spariscono dove passa; finite, ricominciano
func draw_pellets(canvas: CanvasItem, stage: Dictionary, players: Dictionary, width: float, now: int) -> void:
	var mouths := pacmen(players).map(func(p): return Vector2(float(p.x), float(p.y) - fighter_h / 2.0))
	if mouths.is_empty():
		_pellets = []
		return
	if _pellets.is_empty():
		_pellets = pellets_for(stage, width)
	_pellets = _pellets.filter(func(q): return mouths.all(func(m): return m.distance_to(q[0]) > 34.0))
	var pulse := 0.5 + 0.5 * sin(now / 150.0)
	for q: Array in _pellets:
		canvas.draw_circle(q[0], 9.0 + 2.0 * pulse if q[1] else 4.0, PELLET)


# Pac-Man al posto del lottatore: giallo, la bocca verso dove va che si apre e chiude, una fascia del suo colore
func draw_pacman(canvas: CanvasItem, p: Dictionary, tint: Color, now: int, radius: float) -> void:
	var c := Vector2(float(p.x), float(p.y) - fighter_h / 2.0)
	var dir := Vector2(float(p.get("vx", 0)), float(p.get("vy", 0)))
	var angle := dir.angle() if dir.length() > 1.0 else (0.0 if int(p.get("facing", 1)) > 0 else PI)
	var open := 0.05 + 0.33 * absf(sin(now / 70.0))
	var pts := PackedVector2Array([c])
	for k in 25:
		var a := angle + open * PI + (TAU - 2.0 * open * PI) * k / 24.0
		pts.append(c + Vector2.from_angle(a) * radius)
	canvas.draw_colored_polygon(pts, PAC_YELLOW)
	canvas.draw_polyline(pts + PackedVector2Array([c]), INK, 2.5)
	# L'occhio sta sopra la bocca, dal lato giusto anche quando va a sinistra
	var up := Vector2.from_angle(angle - PI / 2.0) if cos(angle) >= -0.01 else Vector2.from_angle(angle + PI / 2.0)
	canvas.draw_circle(c + up * radius * 0.5 + Vector2.from_angle(angle) * radius * 0.12, radius * 0.11, INK)
	# La fascia del colore di chi è, come un cappellino
	canvas.draw_arc(c, radius + 4.0, -PI * 0.8, -PI * 0.2, 12, tint, 5.0)


# Gli altri, finché c'è un Pac-Man, sono fantasmini spaventati: blu, occhietti e bocca a zigzag. Lampeggiano
# di bianco quando Pac-Man sta per finire
func draw_ghosts(canvas: CanvasItem, players: Dictionary, now: int) -> void:
	var pacs := pacmen(players)
	if pacs.is_empty():
		return
	var ending := pacs.all(func(p): return float(p.get("powerupMs", pac_ms)) < 1500.0)
	var body := GHOST_BLUE if not ending or int(now / 200) % 2 == 0 else Color.WHITE
	for p: Variant in players.values():
		if not (p is Dictionary) or pacs.has(p) or p.get("respawning", false) or p.get("eliminated", false) or p.get("powerup") == "tetris":
			continue
		var w := 58.0
		var top := Vector2(float(p.x), float(p.y) - fighter_h - 8.0)
		var h := fighter_h + 8.0
		var pts := PackedVector2Array()
		for k in 13:
			pts.append(top + Vector2.from_angle(PI + PI * k / 12.0) * w / 2.0 + Vector2(0, w / 2.0))
		for k in 7:
			var x := w / 2.0 - w * k / 6.0
			pts.append(top + Vector2(x, h - (8.0 if (k + int(now / 150)) % 2 == 0 else 0.0)))
		canvas.draw_colored_polygon(pts, Color(body, 0.6))
		var face := Color("ffd9b0") if body == GHOST_BLUE else Color("f2424a")
		canvas.draw_circle(top + Vector2(-10, w / 2.0), 4.0, face)
		canvas.draw_circle(top + Vector2(10, w / 2.0), 4.0, face)
		var mouth := PackedVector2Array()
		for k in 7:
			mouth.append(top + Vector2(-15.0 + 5.0 * k, w / 2.0 + 18.0 + (4.0 if k % 2 == 0 else 0.0)))
		canvas.draw_polyline(mouth, face, 2.0)
