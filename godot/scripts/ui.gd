# Aspetto dei menu (lobby, pausa, opzioni): gli stessi colori del gioco web, in un Theme di Godot.
class_name UI
extends RefCounted

const CARD := Color("16212e")
const BORDER := Color("3a5068")
const FIELD := Color("0d1520")
const ACCENT := Color("ffcf4a")
const PRIMARY := Color("e74c3c")
const TEXT := Color("eeeeee")


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_stylebox("panel", "PanelContainer", _box(Color(CARD, 0.95), BORDER, 16, 22))
	for state in ["normal", "focus"]:
		t.set_stylebox(state, "LineEdit", _box(FIELD, BORDER if state == "normal" else ACCENT, 8, 8))
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_font_size("font_size", "LineEdit", 18)
	t.set_stylebox("normal", "Button", _box(BORDER, BORDER, 8, 8))
	t.set_stylebox("hover", "Button", _box(BORDER.lightened(0.2), BORDER.lightened(0.2), 8, 8))
	t.set_stylebox("pressed", "Button", _box(BORDER.darkened(0.2), ACCENT, 8, 8))
	t.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, ACCENT, 8, 8))
	t.set_stylebox("normal", "OptionButton", _box(FIELD, BORDER, 8, 8))
	t.set_stylebox("hover", "OptionButton", _box(FIELD.lightened(0.1), BORDER, 8, 8))
	t.set_color("font_color", "Label", TEXT)
	return t


# Riquadro con bordo arrotondato
static func _box(bg: Color, border: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size := 17, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# Titoletto di sezione, maiuscolo come nel web
static func heading(text: String) -> Label:
	return label(text.to_upper(), 13, Color(TEXT, 0.8))


static func button(text: String, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	if primary:
		b.add_theme_stylebox_override("normal", _box(PRIMARY, PRIMARY, 8, 12))
		b.add_theme_stylebox_override("hover", _box(PRIMARY.lightened(0.15), PRIMARY.lightened(0.15), 8, 12))
		b.add_theme_font_size_override("font_size", 22)
	return b


# Riquadro selezionabile (lottatore, arena): bordo giallo quando è scelto
static func set_selected(b: Button, selected: bool) -> void:
	var border := ACCENT if selected else BORDER
	var bg := Color("2a2a10") if selected else FIELD
	b.add_theme_stylebox_override("normal", _box(bg, border, 10, 6))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.1), border, 10, 6))
	b.add_theme_stylebox_override("pressed", _box(bg, ACCENT, 10, 6))


# Schermo scuro con un riquadro centrato, per pausa e opzioni
static func overlay(width: float) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return [dim, box]


# Copia negli appunti (nel browser passa da navigator.clipboard)
static func copy(text: String) -> void:
	DisplayServer.clipboard_set(text)
