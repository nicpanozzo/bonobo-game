# Scelta della squadra (#409): una fila di pulsanti pieni del colore di ogni squadra, più "Automatica"
# (si entra in quella con meno giocatori). La usano la lobby e il menu di pausa.
# Il pad ci passa sopra con sinistra e destra, come in ogni fila di pulsanti.
extends HBoxContainer

signal chosen(team: int)

const CHIP := Vector2(112, 52) # un pulsante della fila, pixel
const AUTO_COLOR := Color("5a5f6b") # "Automatica" è grigia: non è una squadra

var game: Dictionary
var selected := 0 # 0 = automatica
var _with_auto := true
var _chip_size := CHIP


func setup(game_data: Dictionary, count: int, team: int, with_auto := true, chip_width := CHIP.x) -> void:
	game = game_data
	_with_auto = with_auto
	_chip_size = Vector2(chip_width, CHIP.y)
	add_theme_constant_override("separation", UI.GAP_S)
	set_count(count, team)


# Rifà i pulsanti per count squadre; la squadra scelta resta, se c'è ancora
func set_count(count: int, team := -1) -> void:
	if team >= 0:
		selected = team
	if selected > count or (selected == 0 and not _with_auto):
		selected = 0 if _with_auto else 1
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if _with_auto:
		add_child(_chip(0, "Automatica", AUTO_COLOR))
	for t in range(1, count + 1):
		add_child(_chip(t, str(game.teamNames[str(t)]), Access.team_color(game, t)))
	_refresh()


func choose(team: int) -> void:
	selected = team
	_refresh()
	chosen.emit(team)


func _chip(team: int, text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = _chip_size
	b.set_meta("team", team)
	b.set_meta("color", color)
	b.tooltip_text = "Entri nella squadra con meno giocatori" if team == 0 else "Squadra %s" % text
	b.pressed.connect(func(): choose(team))
	return b


# La scelta è piena e bordata di bianco, le altre più scure: il colore si vede sempre
func _refresh() -> void:
	for b in get_children():
		var color: Color = b.get_meta("color")
		var on: bool = int(b.get_meta("team")) == selected
		var bg := color if on else color.darkened(0.45)
		var border := Color.WHITE if on else color.darkened(0.2)
		b.add_theme_stylebox_override("normal", _box(bg, border, 4 if on else 2))
		b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), border, 4 if on else 2))
		b.add_theme_stylebox_override("pressed", _box(bg, Color.WHITE, 4))
		b.add_theme_stylebox_override("focus", UI.focus_box(UI.RADIUS_CARD))
		var text := text_on(bg)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, text)
		b.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD if on else UI.WEIGHT_BODY))
		b.text = ("✓ " if on else "") + str(b.text).trim_prefix("✓ ")


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(UI.RADIUS_CARD)
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


# Testo scuro sui colori chiari (Gialla, Verde) e bianco sugli altri
static func text_on(c: Color) -> Color:
	return Color(0.08, 0.08, 0.08) if c.get_luminance() > 0.55 else Color.WHITE
