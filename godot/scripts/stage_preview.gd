# Disegno in piccolo di un'arena, per la lobby. Senza dati (arena casuale) mostra un punto di domanda:
# le arene casuali le genera il server dal seme.
extends Control

const WORLD_WIDTH := 1280.0 # WORLD.width
const WORLD_HEIGHT := 720.0 # WORLD.height

var spec: Dictionary
static var _previews := {} # percorso -> Texture2D, le anteprime già caricate (E12)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if spec.is_empty():
		draw_rect(r, Color("1d2b3a"))
		var font := ThemeDB.fallback_font
		var s := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
		draw_string(font, Vector2((size.x - s.x) / 2, size.y / 2 + 14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.ACCENT)
		return
	# L'arena intera ci sta tutta, centrata nel riquadro
	var k := minf(size.x / WORLD_WIDTH, size.y / WORLD_HEIGHT)
	var o := Vector2((size.x - WORLD_WIDTH * k) / 2, (size.y - WORLD_HEIGHT * k) / 2)
	draw_rect(r, _c(spec.colors.sky))
	var preview := preview_texture(spec)
	if preview:
		draw_texture_rect(preview, Rect2(o, Vector2(WORLD_WIDTH, WORLD_HEIGHT) * k), false)
	for s in spec.solids:
		draw_rect(Rect2(o + Vector2(s.x, s.y) * k, Vector2(s.width, s.height) * k), _c(spec.colors.solid))
	for p in spec.platforms:
		draw_rect(Rect2(o + Vector2(p.x, p.y) * k, Vector2(p.width * k, 2)), _c(spec.colors.platform))
	# Ascensori (al primo punto, in giallo) e trappole (in rosso), #14
	for m in spec.get("movers", []):
		draw_rect(Rect2(o + Vector2(m.path[0].x, m.path[0].y) * k, Vector2(m.width * k, 3)), Color("f1c40f"))
	for h in spec.get("hazards", []):
		draw_rect(Rect2(o + Vector2(h.x, h.y) * k, Vector2(h.width, h.height) * k), Color(1, 0.25, 0.2))


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
