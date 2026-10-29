# Piccole immagini disegnate a mano per la sala d'attesa (spunta dei pronti, fiammella delle serie, bagliori):
# il font non ha questi simboli. Si disegnano una volta sola, alla prima richiesta, e poi si riusano.
extends RefCounted

const SIZE := 64

static var _cache := {}


# Spunta bianca su un tondo verde: chi è nel cerchio dei pronti
static func check() -> Texture2D:
	return _make("check", func(p: Vector2) -> Color:
		var d := p.length()
		var a := clampf((0.96 - d) * 24.0, 0.0, 1.0)
		var mark := minf(_seg(p, Vector2(-0.45, 0.02), Vector2(-0.12, 0.34)), _seg(p, Vector2(-0.12, 0.34), Vector2(0.48, -0.32)))
		var white := clampf((0.13 - mark) * 24.0, 0.0, 1.0)
		var green := Color("2ecc71").lerp(Color("8fd18f"), clampf(-p.y, 0.0, 1.0) * 0.6)
		var ring := clampf((d - 0.8) * 10.0, 0.0, 1.0)
		var c := green.lerp(Color.WHITE, maxf(white, ring * 0.7))
		return Color(c, a))


# Fiammella delle serie di vittorie (3 di fila o più)
static func flame() -> Texture2D:
	return _make("flame", func(p: Vector2) -> Color:
		# goccia rovesciata: tonda in basso, a punta in alto
		var q := Vector2(p.x * (1.0 + maxf(0.0, -p.y) * 0.9), p.y - 0.15)
		var d := q.length()
		var a := clampf((0.62 - d) * 12.0, 0.0, 1.0) * clampf((p.y + 0.95) * 8.0, 0.0, 1.0)
		var inner := clampf((0.36 - Vector2(p.x * 1.4, p.y - 0.32).length()) * 6.0, 0.0, 1.0)
		var c := Color("e74c3c").lerp(Color("ff9a1f"), clampf(0.6 - d, 0.0, 1.0) * 1.6).lerp(Color("ffe27a"), inner)
		return Color(c, a))


# Bagliore tondo e morbido, bianco: ombre (tinto di nero), luci a terra, particelle
static func glow() -> Texture2D:
	return _make("glow", func(p: Vector2) -> Color:
		var k := clampf(1.0 - p.length(), 0.0, 1.0)
		return Color(1, 1, 1, k * k * (3.0 - 2.0 * k)))


# Stellina a quattro punte, per scintille e fanfare
static func sparkle() -> Texture2D:
	return _make("sparkle", func(p: Vector2) -> Color:
		var ax := absf(p.x)
		var ay := absf(p.y)
		var star := clampf(1.0 - (ax * ay * 30.0 + (ax + ay) * 0.9), 0.0, 1.0)
		var core := clampf(1.0 - p.length() * 2.2, 0.0, 1.0)
		return Color(1, 1, 1, clampf(star + core, 0.0, 1.0)))


# p va da (-1, -1) a (1, 1), y in giù come nelle immagini
static func _make(key: String, shade: Callable) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0)
			img.set_pixel(x, y, shade.call(p))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - a - ab * t).length()
