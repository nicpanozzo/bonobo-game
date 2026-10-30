# Selettore a frecce "◀ 3 vite ▶" (#250), al posto dei menu a tendina della lobby.
# Ha gli stessi nomi di OptionButton (add_item, select, selected, item_selected...), così si scambiano.
# Col pad o la tastiera: sinistra e destra cambiano il valore quando ha il fuoco; A, Invio o un clic
# sul valore passano al successivo. Le frecce si toccano anche col dito (comandi touch, E18).
class_name Stepper
extends HBoxContainer

signal item_selected(index: int)

const ARROW_W := 40 # larghezza delle frecce, pixel

var selected := -1
var _items: Array[String] = []
var _value: Button
var _caption := ""


# caption: la parola davanti al valore ("Vite"), vuota per mostrare solo il valore
func _init(caption := "") -> void:
	_caption = caption
	add_theme_constant_override("separation", 4)
	var prev := _arrow(-1)
	add_child(prev)
	_value = Button.new()
	_value.custom_minimum_size = Vector2(150, 0)
	# Il valore è un campo incavato col bordo lilla, le frecce due lastre storte come i pulsanti
	var field := UI.button_box(UI.FIELD, false, 8, 0.0, UI.BORDER)
	field.shadow_size = 0
	_value.add_theme_stylebox_override("normal", field)
	var lit := UI.button_box(UI.FIELD.lightened(0.08), false, 8, 0.0, UI.LILAC)
	lit.shadow_size = 0
	_value.add_theme_stylebox_override("hover", lit)
	_value.add_theme_stylebox_override("pressed", lit)
	_value.add_theme_stylebox_override("focus", UI.focus_box(UI.RADIUS))
	_value.add_theme_color_override("font_hover_color", UI.PAPER)
	_value.pressed.connect(func(): _step(1))
	_value.gui_input.connect(_on_value_input)
	add_child(_value)
	add_child(_arrow(1))


# Le frecce sono triangoli disegnati, non i caratteri ◀ ▶: nel browser non c'è un font di riserva che li abbia
func _arrow(delta: int) -> Button:
	var b := Button.new()
	b.icon = arrow_icon(delta)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(ARROW_W, 0)
	b.focus_mode = Control.FOCUS_NONE # col pad si usa sinistra e destra sul valore
	b.add_theme_stylebox_override("normal", _arrow_box(UI.GRAPE_HI, false))
	b.add_theme_stylebox_override("hover", _arrow_box(UI.BANANA, false))
	b.add_theme_stylebox_override("pressed", _arrow_box(UI.BANANA.darkened(0.15), true))
	b.add_theme_color_override("icon_hover_color", UI.INK)
	b.add_theme_color_override("icon_pressed_color", UI.INK)
	b.pressed.connect(func(): _step(delta))
	return b


static func _arrow_box(fill: Color, pressed: bool) -> StyleBoxFlat:
	var s := UI.button_box(fill, pressed, 6, UI.SKEW * 0.75)
	s.content_margin_left = 6
	s.content_margin_right = 6
	return s


static var _arrows := {}


# Triangolo crema verso sinistra (-1) o destra (1); il colore lo cambia il pulsante (icon_*_color)
static func arrow_icon(dir: int) -> Texture2D:
	var k := Access.text_scale
	var key := "%d:%.2f" % [dir, k]
	if _arrows.has(key):
		return _arrows[key]
	var n := roundi(14 * k)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := absf((y + 0.5) / n - 0.5) * 2.0 # 0 al centro, 1 in cima e in fondo
			var along := u if dir > 0 else 1.0 - u # 0 alla base, 1 alla punta
			var inside := (1.0 - along) - v * 0.92 # > 0 dentro il triangolo
			img.set_pixel(x, y, Color(UI.PAPER, clampf(inside * n * 0.9, 0.0, 1.0)))
	_arrows[key] = ImageTexture.create_from_image(img)
	return _arrows[key]


func add_item(text: String) -> void:
	_items.append(text)
	if selected < 0:
		select(0)


func item_count() -> int:
	return _items.size()


func get_item_text(i: int) -> String:
	return _items[i]


func set_item_text(i: int, text: String) -> void:
	_items[i] = text
	_refresh()


# Come OptionButton.select: non manda item_selected
func select(i: int) -> void:
	selected = clampi(i, 0, _items.size() - 1)
	_refresh()


# Il controllo che prende il fuoco del pad (per focus_neighbor e grab_focus)
func focus_target() -> Control:
	return _value


func _step(delta: int) -> void:
	if _items.is_empty():
		return
	select(posmod(selected + delta, _items.size()))
	item_selected.emit(selected)


func _on_value_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_step(-1)
		_value.accept_event()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		_value.accept_event()


func _refresh() -> void:
	if _value == null or selected < 0:
		return
	_value.text = ("%s: %s" % [_caption, _items[selected]]) if _caption != "" else _items[selected]
