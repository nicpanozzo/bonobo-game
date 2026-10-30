# Il fondo animato della schermata del titolo: raggi che girano piano dietro il logo (shader ui_title),
# le sagome di tre lottatori in posa sullo sfondo, due lottatori veri ai lati che respirano (idle)
# e una fascia gialla storta in basso con la scritta che scorre. Solo disegno: niente input, niente stato del gioco.
# Uso in title.gd: add_child(backdrop) come primo figlio, poi backdrop.setup(game); il logo è make_logo().
# Leggero per web e telefoni: uno shader senza texture e una manciata di draw per fotogramma.
extends Control

const FRONT_H := 0.58 # altezza dei lottatori ai lati, parte dell'altezza dello schermo
const BACK_H := 0.5 # altezza delle sagome sullo sfondo
const FLOOR := 0.9 # dove poggiano i piedi, parte dell'altezza dello schermo
const PARALLAX := Vector2(18, 8) # di quanto si spostano i lottatori davanti seguendo il mouse, pixel
const MARQUEE := "BONOBO GAME  •  IL PICCHIADURO DEL NOSTRO DISCORD  •  " # solo caratteri che Lilita One ha: nel browser non ci sono font di riserva
const MARQUEE_SPEED := 40.0 # pixel al secondo della scritta che scorre
const FighterPose := preload("res://scripts/fighter_pose.gd")

var game: Dictionary
var _bg := ColorRect.new()
var _front: Array = [] # due lottatori ai lati: {tex, frames: Array[Rect2], pose, fps, foot: Vector2, flip, x} (da _load)
var _back: Array = [] # tre sagome in posa, ferme sul fotogramma pose: stessi campi
var _t := 0.0
var _mouse := Vector2.ZERO # da -1 a 1, dove sta il mouse rispetto al centro
var _font: Font = UI.display()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lo shader dei lottatori: serve per la sagoma bianca intorno ai due davanti (come la locandina del VS)
	var palette := ShaderMaterial.new()
	palette.shader = load("res://shaders/palette.gdshader")
	material = palette
	_bg.show_behind_parent = true # il fondo sotto ai disegni di _draw, che altrimenti coprirebbe
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ui_title.gdshader")
	m.set_shader_parameter("base", UI.NIGHT)
	m.set_shader_parameter("ray", UI.NIGHT.lerp(UI.GRAPE, 0.55))
	m.set_shader_parameter("glow", Color(UI.PUNCH, 0.2))
	m.set_shader_parameter("dots", Color(UI.INK, 0.55))
	_bg.material = m
	_bg.resized.connect(func(): m.set_shader_parameter("rect_size", _bg.size))
	add_child(_bg)


# game_data: game.json. seed sceglie i lottatori (0 = a caso a ogni avvio)
func setup(game_data: Dictionary, seed := 0) -> void:
	game = game_data
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_bg.material as ShaderMaterial).set_shader_parameter("spin", 0.0 if Access.calm else 0.025)
	var ids := drawn_fighters(game)
	var rng := RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	for i in range(ids.size() - 1, 0, -1): # mescolati: a ogni avvio una locandina diversa
		var j := rng.randi_range(0, i)
		var tmp: String = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	for i in mini(2, ids.size()):
		var f := _load(ids[i], "idle")
		if not f.is_empty():
			f.flip = i == 1 # quello a destra guarda verso il centro
			_front.append(f)
	for i in range(2, mini(5, ids.size())):
		var f := _load(ids[i], "heavy")
		if not f.is_empty():
			f.flip = i % 2 == 1
			f.x = [0.3, 0.7, 0.5][i - 2]
			_back.append(f)


# I personaggi disegnati (con lo spritesheet), nell'ordine di game.json: il bonobo fatto col codice no
static func drawn_fighters(game_data: Dictionary) -> Array:
	var out := []
	for id in game_data.get("characters", {}):
		var c: Dictionary = game_data.characters[id]
		if c.get("sprite") is Dictionary and c.get("portrait") != null:
			out.append(str(id))
	return out


# I fotogrammi di un'animazione: come fighter_preview.gd, formato cartella (un PNG per stato) o foglio unico
func _load(id: String, anim: String) -> Dictionary:
	var sp: Dictionary = game.characters[id].sprite
	var a: Dictionary = sp.animations.get(anim, sp.animations.get("idle", {}))
	var fw := float(sp.frameWidth)
	var fh := float(sp.frameHeight)
	var tex: Texture2D
	var frames: Array[Rect2] = []
	if sp.has("dir"):
		tex = load("res://data/%s/%s.png" % [sp.dir, a.get("src", anim)])
		for i in int(a.get("frames", 1)):
			frames.append(Rect2(i * fw, 0, fw, fh))
	else:
		tex = load("res://data/" + str(sp.path))
		for i in int(a.get("frames", 1)):
			frames.append(Rect2(i * fw, int(a.get("row", 0)) * fh, fw, fh))
	if tex == null or frames.is_empty():
		return {}
	# Le sagome stanno ferme sul fotogramma più ampio del colpo, a metà animazione
	var pose: Rect2 = frames[frames.size() / 2]
	return {"tex": tex, "frames": frames, "pose": pose, "fps": maxf(1.0, float(a.get("fps", 8))), "foot": Vector2(fw / 2.0, float(sp.get("footY", fh))), "flip": false, "x": 0.5}


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport()
	if vp != null and size.x > 0.0:
		var m := (vp.get_mouse_position() - size / 2.0) / (size / 2.0)
		_mouse = _mouse.lerp(m.clamp(Vector2(-1, -1), Vector2(1, 1)), minf(1.0, delta * 3.0))
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var calm := Access.calm
	var drift := 0.0 if calm else sin(_t * 0.4) * 6.0
	# Sagome sullo sfondo: inchiostro trasparente, in posa di colpo, si muovono poco (sono lontane)
	for f in _back:
		var at := Vector2(w * float(f.x) - _mouse.x * PARALLAX.x * 0.3 + drift, h * (FLOOR - 0.04))
		_draw_fighter(f, f.pose, at, h * BACK_H, Color(0.3, 0.2, 0.48, 0.5), false)
	_draw_band(w, h)
	# I due lottatori davanti, con la sagoma crema e l'ombra dura: adesivi staccati dal fondo
	for i in _front.size():
		var f: Dictionary = _front[i]
		var frames: Array = f.frames
		var frame: Rect2 = frames[int(_t * float(f.fps)) % frames.size()] if not calm else frames[0]
		var side := -1.0 if i == 0 else 1.0
		var at := Vector2(w * (0.13 if i == 0 else 0.87) - _mouse.x * PARALLAX.x, h * FLOOR - _mouse.y * PARALLAX.y)
		at.x += side * (w - 1280.0) * 0.1 # sugli schermi larghi si allargano un poco
		_draw_fighter(f, frame, at, h * FRONT_H, Color.WHITE, true)


# La fascia gialla storta in basso con la scritta che scorre, bordata a inchiostro
func _draw_band(w: float, h: float) -> void:
	var y0 := h * 0.84
	var tilt := h * 0.05
	var band := PackedVector2Array([Vector2(-10, y0 + tilt), Vector2(w + 10, y0 - tilt), Vector2(w + 10, y0 - tilt + 46), Vector2(-10, y0 + tilt + 46)])
	var shadow := PackedVector2Array()
	for p in band:
		shadow.append(p + Vector2(0, 10))
	draw_colored_polygon(shadow, Color(UI.INK, 0.8))
	draw_colored_polygon(band, UI.BANANA)
	draw_line(band[0], band[1], UI.INK, 4.0)
	draw_line(band[3], band[2], UI.INK, 4.0)
	# La scritta segue la pendenza della fascia
	var px := 26
	var span := _font.get_string_size(MARQUEE, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var shift := fmod(_t * (0.0 if Access.calm else MARQUEE_SPEED), span)
	var angle := atan2(-2.0 * tilt, w + 20)
	draw_set_transform(Vector2(-10, y0 + tilt + 33), angle)
	var x := -shift
	var length := (w + 40) / cos(angle)
	while x < length:
		draw_string(_font, Vector2(x, 0), MARQUEE, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(UI.INK, 0.88))
		x += span
	draw_set_transform(Vector2.ZERO)


# Un lottatore coi piedi in feet, alto circa height pixel. sticker: ombra dura e contorno crema
func _draw_fighter(f: Dictionary, frame: Rect2, feet: Vector2, height: float, tint: Color, sticker: bool) -> void:
	var foot: Vector2 = f.foot
	var k := height / maxf(foot.y, 1.0)
	var flip := -1.0 if f.flip else 1.0
	var tex: Texture2D = f.tex
	draw_set_transform(feet, 0.0, Vector2(flip * k, k))
	var dest := Rect2(-foot, frame.size)
	if sticker:
		var o := 5.0 / k # il contorno resta largo uguale in pixel dello schermo
		draw_texture_rect_region(tex, Rect2(dest.position + Vector2(9, 11) / k * Vector2(flip, 1), dest.size), frame, Color(UI.INK, 0.85))
		var white := FighterPose.sprite_modulate(0, 1.0, 1.0) # lo shader dei lottatori lo fa tutto bianco
		for d in [Vector2(o, 0), Vector2(-o, 0), Vector2(0, o), Vector2(0, -o), Vector2(o, o) * 0.7, Vector2(-o, o) * 0.7, Vector2(o, -o) * 0.7, Vector2(-o, -o) * 0.7]:
			draw_texture_rect_region(tex, Rect2(dest.position + d, dest.size), frame, white)
		draw_texture_rect_region(tex, dest, frame, FighterPose.sprite_modulate(0, 1.0))
	else:
		draw_texture_rect_region(tex, dest, frame, tint)
	draw_set_transform(Vector2.ZERO)


# Il logo "BONOBO GAME": da mettere al posto di UI.title nel titolo (title.gd). scale_k lo rimpicciolisce sul telefono
func make_logo(scale_k := 1.0) -> Control:
	var logo := Logo.new()
	logo.k = scale_k
	logo.custom_minimum_size = Vector2(620, 196) * scale_k
	return logo


# Il logo disegnato col codice: BONOBO enorme giallo con contorno a inchiostro e due ombre sfalsate
# (rossa e inchiostro), GAME bianco su una lastra rossa storta. Entra con uno scatto e poi respira piano
class Logo extends Control:
	var k := 1.0
	var _t := 0.0
	var _font: Font = UI.display()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pop := 1.0 + 0.35 * pow(1.0 - clampf(_t / 0.35, 0.0, 1.0), 3.0)
		var bob := 0.0 if Access.calm else sin(_t * 1.6) * 3.0
		var c := size / 2.0 + Vector2(0, bob)
		draw_set_transform(c, -0.05, Vector2(pop, pop) * k)
		var big := 118
		var word := "BONOBO"
		var bw := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		var at := Vector2(-bw / 2, 6)
		# Tre strati: ombra d'inchiostro lontana, ombra rossa vicina, lettere gialle
		for layer in [[Vector2(14, 18), UI.INK, UI.INK], [Vector2(7, 9), UI.PUNCH, UI.INK], [Vector2.ZERO, UI.BANANA, UI.INK]]:
			var off: Vector2 = layer[0]
			draw_string_outline(_font, at + off, word, HORIZONTAL_ALIGNMENT_LEFT, -1, big, 20, layer[2])
			draw_string(_font, at + off, word, HORIZONTAL_ALIGNMENT_LEFT, -1, big, layer[1])
		var gpx := 50
		var gw := _font.get_string_size("GAME", HORIZONTAL_ALIGNMENT_LEFT, -1, gpx).x
		var plate := Rect2(-gw / 2 - 30 + 40, 26, gw + 60, gpx + 16)
		UI.draw_plate(self, plate, UI.PUNCH, 22.0, UI.INK, 5.0, Vector2(6, 8))
		UI.draw_sticker(self, _font, Vector2(plate.position.x + 30, plate.end.y - 14), "GAME", gpx, UI.PAPER, 10, Vector2(0, 4))
		# Tre scintille gialle attorno alle lettere, che pulsano sfasate
		for sp in [[Vector2(-bw / 2 - 30, -72), 22.0, 0.0], [Vector2(bw / 2 + 24, -84), 17.0, 1.7], [Vector2(bw / 2 + 8, 58), 14.0, 3.1]]:
			var pulse := 1.0 if Access.calm else 0.75 + 0.25 * sin(_t * 3.0 + float(sp[2]))
			_spark(sp[0], float(sp[1]) * pulse)
		draw_set_transform(Vector2.ZERO)

	# Una stella a quattro punte col contorno a inchiostro
	func _spark(at: Vector2, r: float) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			var a := TAU * i / 8.0 - PI / 2.0
			pts.append(at + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.42))
		draw_colored_polygon(pts, UI.BANANA)
		draw_polyline(pts + PackedVector2Array([pts[0]]), UI.INK, 2.5, true)
