# Contatore FPS (#529): in alto a destra, acceso da Opzioni → Video, per controllare le prestazioni.
# Conta i fotogrammi col tempo reale, non col delta: il rallentatore della palestra non lo falsa
class_name FpsCounter
extends Label

const UPDATE_S := 0.5 # ogni quanto si aggiorna il numero, secondi
const GOOD_FPS := 55.0 # da qui in su verde: un 60 fps che oscilla un poco resta buono
const OK_FPS := 30.0 # da qui a GOOD_FPS giallo, sotto rosso
const GOOD := Color("8fd18f")
const SLOW := Color("ffd166")
const BAD := Color("ff6b6b")
const MARGIN := 12 # distanza dagli angoli dello schermo, pixel

var _frames := 0
var _since_us := 0


static func text_for(frames: int, elapsed_s: float) -> String:
	if frames <= 0 or elapsed_s <= 0.0:
		return "-- FPS"
	return "%d FPS · %.1f ms" % [roundi(frames / elapsed_s), elapsed_s * 1000.0 / frames]


static func color_for(fps: float) -> Color:
	if fps >= GOOD_FPS:
		return GOOD
	return SLOW if fps >= OK_FPS else BAD


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS # conta anche a gioco in pausa
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", Access.px(UI.SIZE_SMALL))
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 5)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	text = text_for(0, 0.0)
	add_theme_color_override("font_color", UI.TEXT)
	_restart()


func set_enabled(on: bool) -> void:
	if on == visible:
		return
	visible = on
	set_process(on) # spento non costa niente
	_restart()


func _restart() -> void:
	_frames = 0
	_since_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_frames += 1
	var elapsed := (Time.get_ticks_usec() - _since_us) / 1000000.0
	if elapsed < UPDATE_S:
		return
	text = text_for(_frames, elapsed)
	add_theme_color_override("font_color", color_for(_frames / elapsed))
	_restart()
