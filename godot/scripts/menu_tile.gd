# Una piastrella dei menu grandi (titolo, prima pagina della lobby), come nei menu dei picchiaduro:
# lastra storta a inchiostro con l'ombra dura, una fascia di colore a sinistra, il nome grande, una riga
# che spiega e una sigla enorme e trasparente sullo sfondo (VS, 1P, CPU...). Disegnata col codice, così
# scelta, fuoco, mouse sopra e pressione cambiano la lastra senza rifare i figli.
extends Button

const LEAN := 18.0 # di quanti pixel pende la cima a destra
const DROP := Vector2(6, 7) # l'ombra dura sotto la lastra, pixel
const STRIPE := 12.0 # la fascia di colore sul lato sinistro, pixel

var mark := "" # la sigla sullo sfondo
var fill := UI.GRAPE
var stripe := UI.BANANA
var primary := false # giallo pieno, scritte a inchiostro: la strada principale
var selected := false # scelta (lobby): diventa gialla come la principale
var title_label: Label
var detail_label: Label
var _font: Font = UI.display()


# Uso: MenuTile.new().setup(...). text: il nome; detail: la riga che spiega ("" = solo il nome);
# tile_mark: la sigla sullo sfondo. Restituisce la piastrella stessa
func setup(text: String, detail: String, tile_mark: String, on_press: Callable, is_primary := false, size_px := UI.SIZE_BIG) -> Button:
	mark = tile_mark
	primary = is_primary
	fill = UI.BANANA if is_primary else UI.GRAPE
	stripe = UI.PUNCH if is_primary else UI.BANANA
	pressed.connect(on_press)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new()) # la lastra la disegna _draw
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", roundi(LEAN + STRIPE + 14))
	m.add_theme_constant_override("margin_right", roundi(LEAN + DROP.x + 6))
	m.add_theme_constant_override("margin_bottom", roundi(DROP.y))
	add_child(m)
	m.minimum_size_changed.connect(_fit) # le scritte crescono (testo grande): la piastrella si allarga con loro
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	m.add_child(v)
	title_label = UI.label(text, size_px)
	title_label.add_theme_font_override("font", UI.display())
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title_label)
	detail_label = UI.note(detail)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.visible = detail != ""
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(detail_label)
	_recolor()
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	UI.juice(self)
	return self


# Il pulsante non guarda i figli per la sua misura minima: la allarga qui quanto serve alle scritte (mai meno)
func _fit() -> void:
	var need := (get_child(0) as Control).get_combined_minimum_size()
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, need.x), maxf(custom_minimum_size.y, need.y))


func set_selected(on: bool) -> void:
	selected = on
	_recolor()
	queue_redraw()


# Gialla (la principale o quella scelta) con le scritte a inchiostro, o viola con le scritte crema
func hot() -> bool:
	return primary or selected


func _recolor() -> void:
	title_label.add_theme_color_override("font_color", UI.INK if hot() else UI.PAPER)
	detail_label.add_theme_color_override("font_color", Color(UI.INK, 0.72) if hot() else Color(UI.LILAC, 0.9))


# Il riquadro dritto della lastra dentro il pulsante: la pendenza e l'ombra stanno nel margine
func plate_rect() -> Rect2:
	return Rect2(Vector2(LEAN / 2.0 + 2.0, 3.0), size - Vector2(LEAN + 4.0 + DROP.x, 6.0 + DROP.y))


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var mode := get_draw_mode()
	var down := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var hover := mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED
	var r := plate_rect()
	var drop := DROP
	if down: # premuta, la lastra scende sulla sua ombra
		r.position += DROP * 0.7
		drop = DROP * 0.3
	var color := UI.BANANA if hot() else fill
	if hover:
		color = color.lightened(0.18 if hot() else 0.1)
	var pts := UI.plate_points(r, LEAN)
	# L'ombra dura, poi la lastra e la fascia di colore lungo il lato sinistro
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + drop)
	draw_colored_polygon(shadow, UI.INK)
	draw_colored_polygon(pts, color)
	var band := UI.plate_points(Rect2(r.position, Vector2(STRIPE, r.size.y)), LEAN)
	draw_colored_polygon(band, UI.PUNCH if hot() else stripe)
	# Una luce in cima: la lastra ha uno spessore
	draw_line(pts[0] + Vector2(STRIPE + 4, 4), pts[1] + Vector2(-6, 4), Color(1, 1, 1, 0.22 if hot() else 0.08), 3.0)
	# La sigla enorme e trasparente sul lato destro, dentro la lastra
	if mark != "":
		var px := roundi(r.size.y * 0.92)
		var tw := _font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var base := Vector2(r.end.x - LEAN / 2.0 - tw - 10.0, r.end.y - r.size.y * 0.13)
		var tint := Color(UI.INK, 0.13) if hot() else Color(UI.PAPER, 0.07)
		draw_string(_font, base, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)
	draw_polyline(pts + PackedVector2Array([pts[0]]), UI.INK, 3.0, true)
	# Il fuoco del pad: un contorno bianco largo attorno alla lastra, come gli altri pulsanti
	if has_focus():
		var ring := UI.plate_points(r.grow(6.0), LEAN)
		draw_polyline(ring + PackedVector2Array([ring[0]]), UI.FOCUS, UI.FOCUS_WIDTH, true)
