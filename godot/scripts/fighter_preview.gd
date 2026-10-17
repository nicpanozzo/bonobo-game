# L'anteprima del lottatore nella lobby (#339): il lottatore intero che respira (l'animazione idle), sotto
# un faro, con l'ombra sui piedi. Tutti alla stessa scala (quella del gioco), così si vede chi è grosso e chi
# no. Quando cambia il disegno (un altro lottatore o un'altra skin) entra scivolando dal lato giusto.
extends Control

const UI := preload("res://scripts/ui.gd")

const ZOOM := 1.6 # pixel dello schermo per pixel di mondo: i lottatori sono alti circa 90-110 px nel gioco
const FLOOR := 34.0 # spazio sotto i piedi, pixel
const SLIDE := 60.0 # di quanto scivola il disegno nuovo quando entra, pixel
const SLIDE_S := 0.22 # durata dell'entrata, secondi

var _tex: Texture2D
var _frames: Array[Rect2] = [] # le zone del PNG di ogni fotogramma dell'idle
var _fps := 12.0
var _foot := Vector2.ZERO # dove stanno i piedi dentro il fotogramma, pixel del PNG
var _scale := 1.0 # pixel dello schermo per pixel del PNG
var _t := 0.0
var _enter := 1.0 # 0 = appena cambiato, 1 = entrato
var _from := 1.0 # da che lato entra: 1 da destra, -1 da sinistra
var _color := UI.PRIMARY # senza disegno: il rettangolo del gioco
var _glow: GradientTexture2D # la luce del faro, un cerchio sfumato


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(UI.ACCENT, 0.22), Color(UI.ACCENT, 0.06), Color(UI.ACCENT, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 256
	_glow.height = 256


# look: il dizionario di FighterPose.look. side: da che lato entra il nuovo (1 destra, -1 sinistra, 0 subito)
func show_look(look: Dictionary, side := 0) -> void:
	_tex = null
	_frames.clear()
	var sp: Variant = look.get("sprite")
	if sp is Dictionary:
		var idle: Dictionary = sp.animations.get("idle", {})
		var fw := float(sp.frameWidth)
		var fh := float(sp.frameHeight)
		_fps = maxf(1.0, float(idle.get("fps", 8)))
		_foot = Vector2(fw / 2.0, float(sp.get("footY", fh)))
		_scale = float(sp.get("scale", 1.0)) * ZOOM
		if sp.has("dir"):
			# formato cartella: lo stato che si disegna davvero (src) ha i suoi fotogrammi in fila
			_tex = load("res://data/%s/%s.png" % [sp.dir, idle.get("src", "idle")])
			for i in int(idle.get("frames", 1)):
				_frames.append(Rect2(i * fw, 0, fw, fh))
		else:
			_tex = load("res://data/" + str(sp.path))
			for i in int(idle.get("frames", 1)):
				_frames.append(Rect2(i * fw, int(idle.get("row", 0)) * fh, fw, fh))
	_enter = 1.0 if side == 0 else 0.0
	_from = 1.0 if side >= 0 else -1.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_enter = minf(1.0, _enter + delta / SLIDE_S)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var feet := Vector2(w / 2.0, h - FLOOR)
	# il faro dall'alto e la pozza di luce sul pavimento, poi l'ombra del lottatore
	var d := minf(w, h * 1.3)
	draw_texture_rect(_glow, Rect2(Vector2(w / 2.0 - d / 2.0, h * 0.5 - d / 2.0), Vector2(d, d)), false)
	draw_texture_rect(_glow, Rect2(feet - Vector2(w * 0.4, 18), Vector2(w * 0.8, 36)), false)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO)
	var e := 1.0 - pow(1.0 - _enter, 3.0) # entra veloce e frena
	var shift := Vector2(_from * SLIDE * (1.0 - e), 0)
	var alpha := e
	if _tex == null:
		var body := Vector2(40, 88) * ZOOM * 0.9
		draw_rect(Rect2(feet + shift - Vector2(body.x / 2, body.y), body), Color(_color, alpha))
		return
	var r: Rect2 = _frames[int(_t * _fps) % _frames.size()] if not _frames.is_empty() else Rect2(Vector2.ZERO, _tex.get_size())
	var k := _scale
	var dest := Rect2(feet + shift - _foot * k, r.size * k)
	draw_texture_rect_region(_tex, dest, r, Color(1, 1, 1, alpha))
