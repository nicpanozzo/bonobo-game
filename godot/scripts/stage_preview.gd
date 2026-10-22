# Disegno in piccolo di un'arena, per la lobby. Senza dati (arena casuale) mostra un punto di domanda:
# le arene casuali le genera il server dal seme.
extends Control

const WORLD_WIDTH := 1280.0 # WORLD.width
const WORLD_HEIGHT := 720.0 # WORLD.height

var spec: Dictionary
const StageMotion := preload("res://scripts/stage_motion.gd")
static var _previews := {} # percorso -> Texture2D, le anteprime già caricate (E12)


func _init() -> void:
	clip_contents = true # le arene più grandi dello schermo (#240) non escono dal riquadro (#284)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if spec.is_empty():
		draw_rect(r, Color("1d2b3a"))
		var font := ThemeDB.fallback_font
		var s := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
		draw_string(font, Vector2((size.x - s.x) / 2, size.y / 2 + 14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.ACCENT)
		return
	# L'arena intera ci sta tutta, centrata nel riquadro, anche se è più larga dello schermo (#240)
	var w := float(spec.get("width", WORLD_WIDTH))
	var k := minf(size.x / w, size.y / WORLD_HEIGHT)
	var o := Vector2((size.x - w * k) / 2, (size.y - WORLD_HEIGHT * k) / 2)
	draw_rect(r, _c(spec.colors.sky))
	var preview := preview_texture(spec)
	if preview:
		# L'immagine disegnata è 16:9 e riempie il riquadro
		var ph := minf(size.y, size.x * 9.0 / 16.0)
		draw_texture_rect(preview, Rect2((size.x - ph * 16.0 / 9.0) / 2, (size.y - ph) / 2, ph * 16.0 / 9.0, ph), false)
		if not draws_pieces(spec):
			return # l'immagine mostra già il palco (#284): i pezzi in tinta unita la coprirebbero
	# L'arena com'è all'inizio (#433): i pezzi a tempo che arrivano dopo non si mostrano
	for s in spec.solids:
		if not PredictMovement.piece_on(s, 0.0):
			continue
		draw_rect(Rect2(o + Vector2(s.x, s.y) * k, Vector2(s.width, s.height) * k), _c(spec.colors.solid))
	for p in spec.platforms:
		if not PredictMovement.piece_on(p, 0.0):
			continue
		if PredictMovement.curved(p):
			draw_colored_polygon(StageMotion.arch_polygon(p, 2.0 / k, k, o), _c(spec.colors.platform)) # ponte ad arco (#244) o scala (#246)
		else:
			draw_rect(Rect2(o + Vector2(p.x, p.y) * k, Vector2(p.width * k, 2)), _c(spec.colors.platform))
	# Ascensori (al primo punto, in giallo) e trappole (in rosso), #14
	for m in spec.get("movers", []):
		draw_rect(Rect2(o + Vector2(m.path[0].x, m.path[0].y) * k, Vector2(m.width * k, 3)), Color("f1c40f"))
	for h in spec.get("hazards", []):
		if h.get("travel") is Dictionary:
			# Trappola che viaggia (#229): il suo percorso, in arancio
			var line := PackedVector2Array()
			for pt in h.travel.path:
				line.append(o + Vector2(pt.x + h.width / 2.0, pt.y + h.height) * k)
			draw_polyline(line, Color("e67e22"), 1.5)
			continue
		if h.kind == "acqua":
			# Acqua alta (#228): l'acqua bassa piena, il livello alto come una riga
			draw_rect(Rect2(o + Vector2(h.x, h.y) * k, Vector2(h.width, h.height) * k), Color("4a6466"))
			var flood: Dictionary = h.get("flood", {})
			if flood.has("highY"):
				draw_line(o + Vector2(h.x, flood.highY) * k, o + Vector2(h.x + h.width, flood.highY) * k, Color("a9c2bf"), 1.0)
			continue
		draw_rect(Rect2(o + Vector2(h.x, h.y) * k, Vector2(h.width, h.height) * k), Color(1, 0.25, 0.2))


# Sopra l'anteprima si disegnano i pezzi del palco, tranne quando l'immagine li mostra già (art.previewFull, #284)
static func draws_pieces(stage: Dictionary) -> bool:
	var art: Dictionary = stage.get("art", {}) if stage.get("art") is Dictionary else {}
	return not (art.get("preview", "") != "" and art.get("previewFull", false))


# L'immagine dell'arena disegnata (StageSpec.art.preview), o null
static func preview_texture(stage: Dictionary) -> Texture2D:
	var file: String = stage.get("art", {}).get("preview", "")
	if file == "":
		return null
	var path := "res://data/assets/stages/%s/%s" % [stage.get("art", {}).get("dir", stage.id), file]
	if not _previews.has(path):
		_previews[path] = load(path) if ResourceLoader.exists(path) else null
	return _previews[path]


static func _c(n: Variant) -> Color:
	return Color.hex((int(n) << 8) | 0xff)
