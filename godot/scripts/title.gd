# Schermata del titolo (E14 passo 2): logo, versione, "Premi un tasto", poi il menu principale.
# La apre main.gd all'avvio; con stanza e nome nell'indirizzo si salta e si entra subito.
extends Control

signal play_requested
signal options_requested
signal credits_requested

const BLINK_S := 0.6 # mezzo giro del lampeggio di "Premi un tasto"

var game: Dictionary
var _press := UI.label("Premi un tasto", UI.SIZE_BIG, UI.TEXT)
var _menu := VBoxContainer.new()
var _first: Button
var _blink := 0.0


func setup(game_data: Dictionary, skip_press := false) -> void:
	game = game_data
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UI.GAP_L)
	center.add_child(box)
	var logo := UI.title("BONOBO GAME")
	logo.add_theme_font_size_override("font_size", Access.px(UI.SIZE_TITLE * 2))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(logo)
	var subtitle := UI.label("Il picchiaduro del nostro Discord", UI.SIZE_SUBTITLE, Color(UI.TEXT, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_press)
	_menu.add_theme_constant_override("separation", UI.GAP_M)
	_menu.visible = false
	box.add_child(_menu)
	_first = _menu_button("Gioca online", func(): play_requested.emit(), true)
	# TODO E15: "Allenamento" quando la palestra (#113) è in main
	_menu_button("Opzioni", func(): options_requested.emit())
	_menu_button("Crediti", func(): credits_requested.emit())
	if not OS.has_feature("web"): # nel browser si chiude la scheda
		_menu_button("Esci", func(): get_tree().quit())
	var version := UI.note(UI.version_text(game))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position -= Vector2(UI.GAP_L, UI.GAP_L)
	add_child(version)
	if skip_press:
		_open_menu()


func _menu_button(text: String, on_press: Callable, primary := false) -> Button:
	var b := UI.button(text, on_press, primary)
	b.custom_minimum_size = Vector2(280, 0)
	_menu.add_child(b)
	return b


func _process(delta: float) -> void:
	if _press.visible:
		_blink += delta
		_press.modulate.a = 0.35 + 0.65 * absf(cos(_blink * PI / (BLINK_S * 2)))


func _open_menu() -> void:
	_press.visible = false
	_menu.visible = true
	_first.grab_focus.call_deferred()


# Il clic se lo prendono i controlli della schermata e a _unhandled_input non arriva: risale fin qui
func _gui_input(event: InputEvent) -> void:
	if _press.visible and event is InputEventMouseButton and event.is_pressed():
		accept_event()
		_open_menu()


# Un tasto o un pulsante del pad: compare il menu (il tasto non fa altro)
func _unhandled_input(event: InputEvent) -> void:
	if not _press.visible or not is_visible_in_tree():
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed()
	if pressed:
		get_viewport().set_input_as_handled()
		_open_menu()


# Torna il fuoco al menu quando si chiudono opzioni o crediti
func restore_focus() -> void:
	if _menu.visible:
		_first.grab_focus()
