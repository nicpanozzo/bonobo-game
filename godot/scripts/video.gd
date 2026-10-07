# Opzioni video dell'app desktop (E14, #112): schermo intero, finestra, vsync, FPS massimi.
# Nel browser non fa niente: finestra e frequenza le decide la pagina.
class_name Video
extends RefCounted

const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const WINDOW_NAMES := ["1280 × 720", "1920 × 1080"]
const FPS_LIMITS := [0, 30, 60, 120, 144] # 0 = senza limite
const FPS_NAMES := ["Senza limite", "30", "60", "120", "144"]

static var _window := -1 # ultima misura applicata: non si ridimensiona a ogni salvataggio


static func available() -> bool:
	return not OS.has_feature("web")


static func apply(s: Settings) -> void:
	if not available():
		return
	Engine.max_fps = FPS_LIMITS[clampi(s.video.max_fps, 0, FPS_LIMITS.size() - 1)]
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s.video.vsync else DisplayServer.VSYNC_DISABLED)
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if s.video.fullscreen != full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s.video.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var w := clampi(s.video.window, 0, WINDOW_SIZES.size() - 1)
	if not s.video.fullscreen and w != _window:
		_window = w
		var size: Vector2i = WINDOW_SIZES[w]
		var screen := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
