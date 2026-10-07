# Design system dei menu (E14, #112): colori, testi, spaziature e componenti in un posto solo.
# Gli script dei menu usano queste costanti e funzioni, mai un Color("...") o una dimensione a mano.
class_name UI
extends RefCounted

# Colori
const CARD := Color("16212e")
const BORDER := Color("3a5068")
const FIELD := Color("0d1520")
const BG := FIELD # sfondo della lobby
const ACCENT := Color("ffcf4a")
const PRIMARY := Color("e74c3c")
const TEXT := Color("eeeeee")
const OK := Color("8fd18f") # conferme ("Link copiato")
const WARN := Color("ff6b6b") # avvisi (azione senza tasti)
const TITLE_SHADOW := Color("7a3b00")
const SELECTED := Color("2a2a10") # fondo di una scheda scelta
const FOCUS := Color.WHITE # contorno del fuoco (pad e Tab), diverso dalla scelta gialla

# Scala dei testi, in pixel
const SIZE_TITLE := 34
const SIZE_HEADER := 28 # titolo di un menu sopra il gioco (Menu, Opzioni)
const SIZE_BIG := 22 # pulsante principale
const SIZE_BODY := 17
const SIZE_SUBTITLE := 16
const SIZE_SMALL := 14 # nomi sotto le schede, tasti nelle opzioni
const SIZE_NOTE := 13

# Spaziature e raggi, in pixel
const GAP_S := 5
const GAP_M := 10
const GAP_L := 12
const RADIUS := 8
const RADIUS_CARD := 10
const RADIUS_PANEL := 16
const FOCUS_WIDTH := 3

const TOAST_S := 2.5 # secondi di un avviso a tempo
const FADE_S := 0.18 # secondi della dissolvenza quando compare una schermata (titolo, lobby, primo avvio)

# Font provvisorio con licenza OFL (godot/assets/fonts/OFL.txt).
# TODO community: si cambia qui quando E7 (#41) sceglie la direzione artistica.
const FONT_FILE := "res://assets/fonts/Nunito.ttf"
const WEIGHT_BODY := 600
const WEIGHT_BOLD := 800

static var _fonts := {}


# Il font del gioco nel peso chiesto (Nunito è un font variabile)
static func font(weight := WEIGHT_BODY) -> Font:
	if not _fonts.has(weight):
		var f := FontVariation.new()
		f.base_font = load(FONT_FILE)
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		_fonts[weight] = f
	return _fonts[weight]


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = Access.px(SIZE_BODY) # testo più grande: opzioni → Accessibilità
	t.set_stylebox("panel", "PanelContainer", _box(Color(CARD, 0.95), BORDER, RADIUS_PANEL, 22))
	for state in ["normal", "focus"]:
		t.set_stylebox(state, "LineEdit", _box(FIELD, BORDER if state == "normal" else ACCENT, RADIUS, 8))
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_font_size("font_size", "LineEdit", Access.px(SIZE_BODY + 1))
	t.set_stylebox("normal", "Button", _box(BORDER, BORDER, RADIUS, 8))
	t.set_stylebox("hover", "Button", _box(BORDER.lightened(0.2), BORDER.lightened(0.2), RADIUS, 8))
	t.set_stylebox("pressed", "Button", _box(BORDER.darkened(0.2), ACCENT, RADIUS, 8))
	t.set_stylebox("normal", "OptionButton", _box(FIELD, BORDER, RADIUS, 8))
	t.set_stylebox("hover", "OptionButton", _box(FIELD.lightened(0.1), BORDER, RADIUS, 8))
	# Le caselle ereditano dai pulsanti: senza questo una casella spuntata ha il riquadro di "premuto"
	for state in ["normal", "pressed", "hover", "hover_pressed"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
		t.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	# Lo stesso contorno di fuoco, spesso e bianco, su tutto quello che si sceglie col pad (E6)
	for type in ["Button", "OptionButton", "CheckBox", "CheckButton", "HSlider"]:
		t.set_stylebox("focus", type, focus_box(RADIUS))
	t.set_color("font_color", "Label", TEXT)
	return t


# Contorno del fuoco, un po' fuori dal controllo per non coprirne il testo
static func focus_box(radius: int) -> StyleBoxFlat:
	var s := _box(Color.TRANSPARENT, FOCUS, radius, 0)
	s.set_border_width_all(FOCUS_WIDTH)
	s.set_expand_margin_all(FOCUS_WIDTH)
	return s


# Riquadro con bordo arrotondato
static func _box(bg: Color, border: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size := SIZE_BODY, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Access.px(size))
	l.add_theme_color_override("font_color", color)
	return l


# "v0.2.0 · build 28": la versione da package.json (game.json) e il numero della Release (build.json,
# scritto da app.yml; manca nell'editor e nel web)
static func version_text(game: Dictionary) -> String:
	var text := "v%s" % game.get("version", "?")
	if FileAccess.file_exists("res://data/build.json"):
		var build = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
		if build is Dictionary and build.has("version"):
			text += " · build %d" % int(build.version)
	return text


# true se a (es. "0.3.0", la versione del server) è più nuova di b: si confrontano i numeri uno a uno
static func newer_version(a: String, b: String) -> bool:
	var x := a.split(".")
	var y := b.split(".")
	for i in maxi(x.size(), y.size()):
		var n := int(x[i]) if i < x.size() else 0
		var m := int(y[i]) if i < y.size() else 0
		if n != m:
			return n > m
	return false


# Avviso in alto sopra lobby e partita, con un pulsante (se button_text non è vuoto) e la ×; sparisce da solo dopo seconds
static func banner(text: String, button_text := "", on_press := Callable(), seconds := 30.0) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var bar := PanelContainer.new()
	bar.theme = theme()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.position.y = GAP_L
	layer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_L)
	bar.add_child(row)
	row.add_child(label(text))
	if button_text != "":
		row.add_child(small_button(button_text, on_press))
	row.add_child(small_button("×", layer.queue_free))
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(layer.queue_free)
	layer.add_child(timer)
	return layer


# Dissolvenza in entrata di una schermata appena aggiunta alla scena: breve, non rallenta chi va di fretta
static func fade_in(screen: CanvasItem) -> void:
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, FADE_S)


# Titoletto di sezione, maiuscolo come nel web
static func heading(text: String) -> Label:
	return label(text.to_upper(), SIZE_NOTE, Color(TEXT, 0.8))


# Titolo grande del gioco, con l'ombra
static func title(text: String) -> Label:
	var l := label(text, SIZE_TITLE, ACCENT)
	l.add_theme_font_override("font", font(WEIGHT_BOLD))
	l.add_theme_color_override("font_shadow_color", TITLE_SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


# Titolo di un menu (Menu, Opzioni, Crediti)
static func header(text: String) -> Label:
	var l := label(text, SIZE_HEADER, ACCENT)
	l.add_theme_font_override("font", font(WEIGHT_BOLD))
	return l


# Nota piccola e smorzata (piede della lobby, spiegazioni)
static func note(text: String, alpha := 0.7) -> Label:
	return label(text, SIZE_NOTE, Color(TEXT, alpha))


static func button(text: String, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	if primary:
		b.add_theme_stylebox_override("normal", _box(PRIMARY, PRIMARY, RADIUS, 12))
		b.add_theme_stylebox_override("hover", _box(PRIMARY.lightened(0.15), PRIMARY.lightened(0.15), RADIUS, 12))
		b.add_theme_font_size_override("font_size", Access.px(SIZE_BIG))
		b.add_theme_font_override("font", font(WEIGHT_BOLD))
	return b


# Pulsante piccolo e basso (i tasti nella tabella delle opzioni)
static func small_button(text: String, on_press: Callable) -> Button:
	var b := button(text, on_press)
	b.add_theme_font_size_override("font_size", Access.px(SIZE_SMALL + 1))
	b.add_theme_stylebox_override("normal", _box(BORDER, BORDER, RADIUS, 4))
	b.add_theme_stylebox_override("hover", _box(BORDER.lightened(0.2), BORDER.lightened(0.2), RADIUS, 4))
	return b


# Interruttore sì/no con la sua scritta
static func toggle(text: String, on: bool, on_change: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(on_change)
	return c


# Cursore da 0 a max_value (volumi da 0 a 100)
static func slider(value: float, on_change: Callable, max_value := 100.0, step := 1.0) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = max_value
	s.step = step
	s.value = value
	s.value_changed.connect(on_change)
	return s


# Avviso a tempo in fondo allo schermo: compare sopra parent e sparisce da solo
static func toast(parent: Node, text: String, color := OK, seconds := TOAST_S) -> Label:
	var l := label(text, SIZE_BODY, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position.y -= 48
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	parent.get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(l):
			l.queue_free())
	return l


# Riquadro selezionabile (lottatore, arena): bordo giallo quando è scelto
static func set_selected(b: Button, selected: bool) -> void:
	var border := ACCENT if selected else BORDER
	var bg := SELECTED if selected else FIELD
	b.add_theme_stylebox_override("normal", _box(bg, border, RADIUS_CARD, 6))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.1), border, RADIUS_CARD, 6))
	b.add_theme_stylebox_override("pressed", _box(bg, ACCENT, RADIUS_CARD, 6))
	# Il fuoco del pad (E6) si distingue dalla scelta: bordo bianco invece che giallo
	b.add_theme_stylebox_override("focus", focus_box(RADIUS_CARD))


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
	box.add_theme_constant_override("separation", GAP_M)
	panel.add_child(box)
	return [dim, box]


# Menu sopra altri menu (opzioni sopra la lobby): col pad il fuoco non deve scappare
# sui controlli di sotto. Dà il fuoco a first e ce lo riporta se esce dal menu.
static func keep_focus(menu: Control, first: Control) -> void:
	first.grab_focus.call_deferred()
	var viewport := menu.get_viewport()
	var back := func(c: Control) -> void:
		if is_instance_valid(menu) and not menu.is_queued_for_deletion() and not menu.is_ancestor_of(c):
			first.grab_focus.call_deferred()
	viewport.gui_focus_changed.connect(back)
	menu.tree_exiting.connect(func(): viewport.gui_focus_changed.disconnect(back))


# Copia negli appunti (nel browser passa da navigator.clipboard)
static func copy(text: String) -> void:
	DisplayServer.clipboard_set(text)
