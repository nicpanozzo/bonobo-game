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
	add_theme_constant_override("separation", 2)
	var prev := _arrow("◀", -1)
	add_child(prev)
	_value = Button.new()
	_value.custom_minimum_size = Vector2(150, 0)
	# Il valore ha il fondo scuro dei campi, le frecce quello dei pulsanti
	_value.add_theme_stylebox_override("normal", UI._box(UI.FIELD, UI.BORDER, UI.RADIUS, 8))
	_value.add_theme_stylebox_override("hover", UI._box(UI.FIELD.lightened(0.1), UI.BORDER, UI.RADIUS, 8))
	_value.pressed.connect(func(): _step(1))
	_value.gui_input.connect(_on_value_input)
	add_child(_value)
	add_child(_arrow("▶", 1))


func _arrow(text: String, delta: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(ARROW_W, 0)
	b.focus_mode = Control.FOCUS_NONE # col pad si usa sinistra e destra sul valore
	b.pressed.connect(func(): _step(delta))
	return b


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
