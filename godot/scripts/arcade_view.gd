# Power-up arcade (#427): i pezzi del Tetris che cadono, i blocchi posati e il cabinato di chi gioca.
# Solo disegno: pezzi e blocchi arrivano nello snapshot (tetris), calcolati dal server in physics/arcade.ts.
# world_view.gd lo chiama dentro _draw.
extends RefCounted

# I colori classici delle sette forme
const COLORS := {"I": Color("29d3ea"), "O": Color("ffd23f"), "T": Color("b04df0"), "L": Color("ff9a1f"), "J": Color("3d6df2"), "S": Color("4ee05a"), "Z": Color("f2424a")}
const INK := Color("101018")

var cell := 40.0
var fade_ms := 1500.0
var pieces: Array = []
var blocks: Array = []


func setup(game: Dictionary) -> void:
	var t: Dictionary = game.get("tetris", {})
	cell = float(t.get("cellPx", 40))
	fade_ms = float(t.get("fadeMs", 1500))


func on_snapshot(snap: Dictionary) -> void:
	var t: Variant = snap.get("tetris")
	pieces = t.pieces if t is Dictionary else []
	blocks = t.blocks if t is Dictionary else []


func clear() -> void:
	pieces = []
	blocks = []


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
