# Design system dei menu (E14, #112): colori, testi, spaziature e componenti in un posto solo.
# Gli script dei menu usano queste costanti e funzioni, mai un Color("...") o una dimensione a mano.
# Lo stile è "inchiostro e banana": lastre storte con il contorno a inchiostro dei lottatori
# (docs/stile-grafico.md), ombre dure, giallo banana per quello che conta, viola notte come fondo.
class_name UI
extends RefCounted

# Palette di base: tutto il resto si ricava da qui
const INK := Color("140c1f") # contorni e ombre dure: quasi nero, come l'inchiostro dei lottatori
const NIGHT := Color("1c1230") # fondo delle schermate, più spento dei lottatori
const GRAPE := Color("2e1f4b") # superfici: pannelli e schede
const GRAPE_HI := Color("533a85") # pulsanti secondari, un gradino sopra le superfici
const LILAC := Color("bcaae6") # testo secondario e titoletti
const PAPER := Color("fff4de") # il testo: carta crema, meno dura del bianco puro
const BANANA := Color("ffc928") # il colore del gioco: azione principale, scelta, titoli
const PUNCH := Color("ff4560") # avvisi, VS, ultimi secondi
const MINT := Color("5ef0a0") # conferme, PRONTO!

# I nomi di sempre, usati da tutti i menu
const CARD := GRAPE
const BORDER := Color("5a4386") # linee leggere, binari delle barre, contorni a riposo
const FIELD := Color("150d25") # campi di testo e schede non scelte: incavati nel fondo
const BG := NIGHT # sfondo della lobby
const ACCENT := BANANA
const PRIMARY := BANANA # il pulsante che fa giocare: giallo pieno, scritta a inchiostro
const TEXT := PAPER
const OK := MINT # conferme ("Link copiato")
const WARN := Color("ff6b7d") # avvisi (azione senza tasti): il PUNCH schiarito, leggibile sul viola
const TITLE_SHADOW := Color("d62f55") # l'ombra rossa sotto il contorno dei titoli
const SELECTED := Color("3d2a4a") # fondo di una scheda scelta: viola scaldato dal giallo
const FOCUS := Color.WHITE # contorno del fuoco (pad e Tab), diverso dalla scelta gialla

# Scala dei testi, in pixel
const SIZE_TITLE := 40
const SIZE_HEADER := 30 # titolo di un menu sopra il gioco (Menu, Opzioni)
const SIZE_BIG := 24 # pulsante principale
const SIZE_BODY := 17
const SIZE_SUBTITLE := 16
const SIZE_SMALL := 14 # nomi sotto le schede, tasti nelle opzioni
const SIZE_NOTE := 13

# Spaziature, raggi e tratti, in pixel
const GAP_S := 5
const GAP_M := 10
const GAP_L := 12
const RADIUS := 6
const RADIUS_CARD := 8
const RADIUS_PANEL := 18 # angoli tagliati a 45 gradi (corner_detail 1): in alto a sinistra e in basso a destra
const FOCUS_WIDTH := 4 # il fuoco del pad si vede da lontano, anche dal divano
const OUTLINE := 3 # contorno a inchiostro di pulsanti e pannelli
const DROP := 5 # ombra dura sotto i pulsanti: sparisce quando si premono
const SKEW := 0.2 # quanto pendono i pulsanti (in avanti, come chi scatta)

const TOAST_S := 2.5 # secondi di un avviso a tempo
const FADE_S := 0.18 # secondi della dissolvenza quando compare una schermata (titolo, lobby, primo avvio)
const PUNCH_S := 0.12 # secondi dello scatto di un pulsante quando ci si passa sopra o prende il fuoco
const PUNCH_PX := 4.0 # di quanti pixel cresce per lato un pulsante col fuoco: poco, le schede stanno vicine

# Font con licenza OFL (godot/assets/fonts/OFL-*.txt, public/assets/CREDITS.md):
# Lilita One per titoli, pulsanti e numeri grandi; Rubik (variabile, con il corsivo) per i testi e l'HUD.
const FONT_FILE := "res://assets/fonts/Rubik.ttf"
const FONT_ITALIC_FILE := "res://assets/fonts/Rubik-Italic.ttf"
const DISPLAY_FILE := "res://assets/fonts/LilitaOne.ttf"
const WEIGHT_BODY := 500
const WEIGHT_BOLD := 700
const WEIGHT_BLACK := 900

static var _fonts := {}
static var _icons := {} # icone disegnate col codice (interruttori, cursori), per scala del testo
static var _hooked := false


# Il font dei testi nel peso chiesto (Rubik è un font variabile, da 300 a 900)
static func font(weight := WEIGHT_BODY) -> Font:
	return _variant(FONT_FILE, weight, false, 0)


# Il font dei titoli e dei pulsanti: grosso, tondo e allegro. Le lettere che non ha le prende da Rubik
static func display() -> Font:
	if not _fonts.has("display"):
		var f := FontVariation.new()
		f.base_font = load(DISPLAY_FILE)
		f.fallbacks = [font(WEIGHT_BOLD)]
		f.spacing_glyph = 1
		_fonts["display"] = f
	return _fonts["display"]


# Numeri che cambiano (percentuali, tempo): corsivo pesante a cifre tutte larghe uguali, così non ballano
static func numbers(weight := WEIGHT_BLACK, italic := true) -> Font:
	return _variant(FONT_ITALIC_FILE if italic else FONT_FILE, weight, true, 0)


# Maiuscoletto spaziato dei titoletti di sezione
static func caps(weight := WEIGHT_BOLD) -> Font:
	return _variant(FONT_FILE, weight, false, 1)


static func _variant(file: String, weight: int, tabular: bool, spacing: int) -> Font:
	var key := "%s:%d:%s:%d" % [file, weight, tabular, spacing]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load(file)
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		if tabular:
			f.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
		f.spacing_glyph = spacing
		_fonts[key] = f
	return _fonts[key]


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = Access.px(SIZE_BODY) # testo più grande: opzioni → Accessibilità
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	# Campi di testo: incavati, contorno giallo quando si scrive
	for state in ["normal", "focus", "read_only"]:
		var s := _box(FIELD, BANANA if state == "focus" else BORDER, RADIUS, 10)
		s.set_border_width_all(OUTLINE)
		t.set_stylebox(state, "LineEdit", s)
	t.set_font("font", "LineEdit", font(WEIGHT_BOLD))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("font_placeholder_color", "LineEdit", Color(LILAC, 0.55))
	t.set_color("caret_color", "LineEdit", BANANA)
	t.set_color("selection_color", "LineEdit", Color(BANANA, 0.35))
	t.set_font_size("font_size", "LineEdit", Access.px(SIZE_BODY + 1))
	# Pulsanti: lastre storte a inchiostro, scritta nel font dei titoli
	t.set_font("font", "Button", display())
	t.set_font_size("font_size", "Button", Access.px(SIZE_BODY + 1))
	t.set_stylebox("normal", "Button", button_box(GRAPE_HI))
	t.set_stylebox("hover", "Button", button_box(GRAPE_HI.lightened(0.14)))
	t.set_stylebox("pressed", "Button", button_box(GRAPE_HI.darkened(0.15), true))
	t.set_stylebox("hover_pressed", "Button", button_box(GRAPE_HI.darkened(0.05), true))
	t.set_stylebox("disabled", "Button", button_box(Color(GRAPE, 0.7)))
	_button_colors(t, "Button", PAPER, BANANA)
	t.set_color("font_disabled_color", "Button", Color(LILAC, 0.45))
	# Menu a tendina: come i pulsanti, ma dritti (dentro c'è la freccia) e scuri come i campi
	t.set_stylebox("normal", "OptionButton", button_box(FIELD.lightened(0.06), false, 8, 0.0))
	t.set_stylebox("hover", "OptionButton", button_box(FIELD.lightened(0.14), false, 8, 0.0))
	t.set_stylebox("pressed", "OptionButton", button_box(FIELD, true, 8, 0.0))
	t.set_stylebox("focus", "OptionButton", focus_box(RADIUS))
	t.set_font("font", "OptionButton", font(WEIGHT_BOLD))
	t.set_stylebox("panel", "PopupMenu", _popup_box())
	t.set_stylebox("hover", "PopupMenu", _box(BANANA, BANANA, 3, 4))
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font("font", "PopupMenu", font(WEIGHT_BOLD))
	# Le caselle ereditano dai pulsanti: senza questo una casella spuntata ha il riquadro di "premuto"
	for state in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
		t.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	for type in ["CheckBox", "CheckButton"]:
		t.set_font("font", type, font(WEIGHT_BODY))
		t.set_font_size("font_size", type, Access.px(SIZE_BODY))
		_button_colors(t, type, PAPER, BANANA)
		t.set_constant("h_separation", type, GAP_M)
	t.set_icon("checked", "CheckButton", _toggle_icon(true))
	t.set_icon("unchecked", "CheckButton", _toggle_icon(false))
	t.set_icon("checked_disabled", "CheckButton", _toggle_icon(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _toggle_icon(false, true))
	t.set_icon("checked_mirrored", "CheckButton", _toggle_icon(true))
	t.set_icon("unchecked_mirrored", "CheckButton", _toggle_icon(false))
	# Cursori: binario incavato, la parte piena gialla, la manopola tonda a inchiostro
	var track := _box(FIELD, INK, 5, 0)
	track.set_border_width_all(2)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(BANANA, INK, 5, 0)
	fill.set_border_width_all(2)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _knob_icon(false))
	t.set_icon("grabber_highlight", "HSlider", _knob_icon(true))
	# Barre di scorrimento sottili, la maniglia gialla quando la si tocca
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _box(Color(INK, 0.55), Color(INK, 0.55), 5, 3))
		t.set_stylebox("grabber", bar, _box(BORDER, BORDER, 5, 3))
		t.set_stylebox("grabber_highlight", bar, _box(LILAC, LILAC, 5, 3))
		t.set_stylebox("grabber_pressed", bar, _box(BANANA, BANANA, 5, 3))
	# Suggerimenti: un foglietto di carta con la scritta a inchiostro
	var tip := _box(PAPER, INK, 4, 8)
	tip.set_border_width_all(2)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", font(WEIGHT_BODY))
	# Lo stesso contorno di fuoco, spesso e bianco, su tutto quello che si sceglie col pad (E6)
	t.set_stylebox("focus", "Button", focus_box(RADIUS, SKEW))
	for type in ["CheckBox", "CheckButton", "HSlider"]:
		t.set_stylebox("focus", type, focus_box(RADIUS))
	return t


static func _button_colors(t: Theme, type: String, color: Color, hover: Color) -> void:
	t.set_color("font_color", type, color)
	t.set_color("font_focus_color", type, color)
	t.set_color("font_pressed_color", type, color)
	t.set_color("font_hover_color", type, hover)
	t.set_color("font_hover_pressed_color", type, hover)


# Contorno del fuoco, un po' fuori dal controllo per non coprirne il testo; skew per i pulsanti storti
static func focus_box(radius: int, skew := 0.0) -> StyleBoxFlat:
	var s := _box(Color.TRANSPARENT, FOCUS, radius, 0)
	s.draw_center = false
	s.set_border_width_all(FOCUS_WIDTH)
	s.set_expand_margin_all(FOCUS_WIDTH + 1)
	s.expand_margin_bottom += DROP # copre anche l'ombra dura sotto il pulsante
	s.skew = Vector2(skew, 0)
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


# Un pulsante: lastra storta con il contorno a inchiostro e l'ombra dura sotto. Premuto, la lastra
# scende sull'ombra (expand negativo sopra) e la scritta con lei: si sente lo scatto anche senza suono
static func button_box(fill: Color, pressed := false, pad := 10, skew := SKEW, edge := INK) -> StyleBoxFlat:
	var s := _box(fill, edge, RADIUS, pad)
	s.set_border_width_all(OUTLINE)
	s.skew = Vector2(skew, 0)
	s.anti_aliasing_size = 0.8
	var side := pad + 6 + roundi(skew * 22) # la pendenza mangia spazio ai lati
	s.content_margin_left = side
	s.content_margin_right = side
	s.content_margin_top = pad * 0.55
	s.content_margin_bottom = pad * 0.55
	s.shadow_color = INK
	s.shadow_size = 1
	if pressed:
		s.expand_margin_top = -DROP + 1
		s.expand_margin_bottom = DROP - 1
		s.content_margin_top += DROP - 1
		s.content_margin_bottom -= DROP - 1
		s.shadow_offset = Vector2(0, 1)
	else:
		s.shadow_offset = Vector2(2, DROP)
	return s


# Il fondo dei pannelli (menu, pausa, opzioni): viola, contorno a inchiostro, due angoli tagliati, ombra dura
static func panel_box(fill := Color(GRAPE, 0.97), pad := 22) -> StyleBoxFlat:
	var s := _box(fill, INK, 0, pad)
	s.content_margin_top = pad - 4 # sopra e sotto un po' meno: i menu lunghi (opzioni) stanno in 720 pixel
	s.content_margin_bottom = pad - 4
	s.set_border_width_all(OUTLINE)
	s.corner_detail = 1 # angoli tagliati dritti, non tondi
	s.corner_radius_top_left = RADIUS_PANEL
	s.corner_radius_bottom_right = RADIUS_PANEL
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.shadow_color = Color(INK, 0.85)
	s.shadow_size = 1
	s.shadow_offset = Vector2(8, 8)
	return s


static func _popup_box() -> StyleBoxFlat:
	var s := _box(GRAPE, INK, 4, 6)
	s.set_border_width_all(OUTLINE)
	s.shadow_color = INK
	s.shadow_size = 1
	s.shadow_offset = Vector2(4, 5)
	return s


# Il nastro giallo in cima ai pannelli e il tratteggio nell'angolo: la "texture" dei menu, disegnata
# sopra il fondo e sotto il contenuto (il segnale draw arriva dopo lo stilebox e prima dei figli)
static func decorate_panel(panel: Control) -> void:
	panel.draw.connect(func() -> void:
		var w := panel.size.x
		var h := panel.size.y
		if w <= 0.0 or h <= 0.0:
			return
		# Tratteggio diagonale nell'angolo in alto a destra, che sfuma verso il centro
		for i in 9:
			var a := 0.09 * (1.0 - i / 9.0)
			panel.draw_line(Vector2(w - 12.0 - i * 12.0, OUTLINE + 1.0), Vector2(w - OUTLINE - 1.0, 12.0 + i * 12.0), Color(LILAC, a), 3.0)
		# Il nastro: una lastra gialla storta appoggiata sul bordo in alto, dopo l'angolo tagliato
		var tape := PackedVector2Array([Vector2(RADIUS_PANEL + 18, -6), Vector2(RADIUS_PANEL + 104, -6), Vector2(RADIUS_PANEL + 96, 6), Vector2(RADIUS_PANEL + 10, 6)])
		panel.draw_colored_polygon(tape, BANANA)
		panel.draw_polyline(tape + PackedVector2Array([tape[0]]), INK, 2.0))


# Il fondo animato delle schermate (primo avvio, lobby): strisce diagonali lente e retino negli angoli
static func backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ui_backdrop.gdshader")
	m.set_shader_parameter("base", NIGHT)
	m.set_shader_parameter("stripe", NIGHT.lerp(GRAPE, 0.28))
	m.set_shader_parameter("dots", Color(BANANA, 0.09))
	m.set_shader_parameter("speed", 0.0 if Access.calm else 10.0)
	bg.material = m
	bg.resized.connect(func(): m.set_shader_parameter("rect_size", bg.size))
	return bg


# Un'icona disegnata pixel per pixel, con i bordi morbidi: l'interruttore sì/no
static func _toggle_icon(on: bool, disabled := false) -> Texture2D:
	var k := Access.text_scale
	var key := "toggle:%s:%s:%.2f" % [on, disabled, k]
	if _icons.has(key):
		return _icons[key]
	var w := roundi(48 * k)
	var h := roundi(26 * k)
	var r := h / 2.0
	var track := BANANA if on else FIELD.lightened(0.08)
	var knob := PAPER if on else LILAC
	if disabled:
		track = track.lerp(GRAPE, 0.6)
		knob = knob.lerp(GRAPE, 0.6)
	var knob_at := Vector2(w - r, r) if on else Vector2(r, r)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var pill := p.distance_to(Vector2(clampf(p.x, r, w - r), r)) - r + 0.5 # < 0 dentro
			var c := _over(Color(0, 0, 0, 0), INK, clampf(0.5 - pill, 0.0, 1.0))
			c = _over(c, track, clampf(0.5 - (pill + 2.5 * k), 0.0, 1.0))
			var dot := p.distance_to(knob_at) - (r - 3.5 * k)
			c = _over(c, INK, clampf(0.5 - dot, 0.0, 1.0))
			c = _over(c, knob, clampf(0.5 - (dot + 2.0 * k), 0.0, 1.0))
			img.set_pixel(x, y, c)
	_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


# La manopola del cursore: un tondo giallo a inchiostro, crema quando ci si passa sopra
static func _knob_icon(hover: bool) -> Texture2D:
	var k := Access.text_scale
	var key := "knob:%s:%.2f" % [hover, k]
	if _icons.has(key):
		return _icons[key]
	var n := roundi(24 * k)
	var r := n / 2.0
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r)) - r + 0.5
			var c := _over(Color(0, 0, 0, 0), INK, clampf(0.5 - d, 0.0, 1.0))
			c = _over(c, PAPER if hover else BANANA, clampf(0.5 - (d + 3.0 * k), 0.0, 1.0))
			img.set_pixel(x, y, c)
	_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


# src sopra dst con opacità a (per le icone disegnate a mano)
static func _over(dst: Color, src: Color, a: float) -> Color:
	var sa := src.a * a
	var oa := sa + dst.a * (1.0 - sa)
	if oa <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Color(src.r, src.g, src.b) * sa + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - sa)) / oa
	return Color(rgb.r, rgb.g, rgb.b, oa)


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
	var style := panel_box(Color(INK, 0.94), GAP_L)
	style.border_color = BANANA
	style.shadow_offset = Vector2(5, 5)
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.position.y = GAP_L
	layer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_L)
	bar.add_child(row)
	var l := label(text)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	if button_text != "":
		var b := small_button(button_text, on_press)
		set_primary(b)
		row.add_child(b)
	row.add_child(small_button("×", layer.queue_free))
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(layer.queue_free)
	layer.add_child(timer)
	return layer


# Dissolvenza in entrata di una schermata appena aggiunta alla scena: breve, non rallenta chi va di fretta.
# Arriva anche un poco dal basso, e da qui in poi i pulsanti scattano quando prendono il fuoco
static func fade_in(screen: CanvasItem) -> void:
	screen.modulate.a = 0.0
	var tw := screen.create_tween()
	tw.tween_property(screen, "modulate:a", 1.0, FADE_S)
	if screen.is_inside_tree():
		_hook(screen.get_tree())
		juice_all(screen)


# Titoletto di sezione: maiuscolo, spaziato, lilla
static func heading(text: String) -> Label:
	var l := label(text.to_upper(), SIZE_NOTE, LILAC)
	l.add_theme_font_override("font", caps())
	return l


# Titolo grande del gioco: giallo, contorno a inchiostro e l'ombra rossa sfalsata, come un adesivo
static func title(text: String) -> Label:
	var l := label(text, SIZE_TITLE, ACCENT)
	l.add_theme_font_override("font", display())
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", Access.px(10))
	l.add_theme_color_override("font_shadow_color", TITLE_SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 4)
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.add_theme_constant_override("shadow_outline_size", Access.px(10))
	return l


# Titolo di un menu (Menu, Opzioni, Crediti)
static func header(text: String) -> Label:
	var l := label(text, SIZE_HEADER, ACCENT)
	l.add_theme_font_override("font", display())
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", Access.px(7))
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", Access.px(7))
	return l


# Nota piccola e smorzata (piede della lobby, spiegazioni)
static func note(text: String, alpha := 0.7) -> Label:
	return label(text, SIZE_NOTE, Color(LILAC.lerp(TEXT, 0.35), alpha + (1.0 - alpha) * 0.4))


static func button(text: String, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	if primary:
		_primary_boxes(b, 12)
		b.add_theme_font_size_override("font_size", Access.px(SIZE_BIG))
	juice(b)
	return b


static func _primary_boxes(b: Button, pad: int, skew := SKEW) -> void:
	b.add_theme_stylebox_override("normal", button_box(PRIMARY, false, pad, skew))
	b.add_theme_stylebox_override("hover", button_box(PRIMARY.lightened(0.28), false, pad, skew))
	b.add_theme_stylebox_override("focus", focus_box(RADIUS, skew))
	b.add_theme_stylebox_override("pressed", button_box(PRIMARY.darkened(0.12), true, pad, skew))
	b.add_theme_stylebox_override("hover_pressed", button_box(PRIMARY.darkened(0.04), true, pad, skew))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, INK)


# Scheda grande con un titolo in grassetto e una riga che spiega cosa fa (menu principale, prima pagina della lobby)
static func choice_card(text: String, detail: String, on_press: Callable, size := SIZE_BIG) -> Button:
	var b := Button.new()
	b.pressed.connect(on_press)
	set_selected(b, false)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var t := label(text, size)
	t.add_theme_font_override("font", display())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := note(detail)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.visible = detail != "" # senza spiegazione il nome sta al centro
	v.add_child(d)
	juice(b)
	return b


# Giallo pieno come il pulsante principale (UI.button con primary), per una scheda (choice_card) che fa giocare.
# Sul giallo le scritte diventano d'inchiostro
static func set_primary(b: Button) -> void:
	var card := b.text == ""
	_primary_boxes(b, 6 if card else 8, 0.0 if card else SKEW)
	if card: # le schede tengono gli angoli dritti delle schede, con l'ombra dura
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var s: StyleBoxFlat = b.get_theme_stylebox(state)
			s.corner_radius_top_left = RADIUS_CARD * 2
			s.corner_radius_bottom_right = RADIUS_CARD * 2
			s.corner_detail = 1
		b.add_theme_stylebox_override("focus", focus_box(RADIUS_CARD))
	for l: Label in b.find_children("*", "Label", true, false):
		var main := l.get_index() == 0
		l.add_theme_color_override("font_color", INK if main else Color(INK, 0.72))


# Pulsante piccolo e basso (i tasti nella tabella delle opzioni)
static func small_button(text: String, on_press: Callable) -> Button:
	var b := button(text, on_press)
	b.add_theme_font_size_override("font_size", Access.px(SIZE_SMALL + 1))
	b.add_theme_stylebox_override("normal", _small_box(GRAPE_HI, false))
	b.add_theme_stylebox_override("hover", _small_box(GRAPE_HI.lightened(0.14), false))
	b.add_theme_stylebox_override("pressed", _small_box(GRAPE_HI.darkened(0.15), true))
	b.add_theme_stylebox_override("hover_pressed", _small_box(GRAPE_HI.darkened(0.05), true))
	return b


static func _small_box(fill: Color, pressed: bool) -> StyleBoxFlat:
	var s := button_box(fill, pressed, 6, SKEW * 0.75)
	s.content_margin_top = 3 + (DROP - 1 if pressed else 0)
	s.content_margin_bottom = 3 - (DROP - 1 if pressed else 0)
	return s


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


# Avviso a tempo in fondo allo schermo: compare sopra parent e sparisce da solo.
# Una targhetta storta a inchiostro con una fascia del colore dell'avviso; vuota resta invisibile
static func toast(parent: Node, text: String, color := OK, seconds := TOAST_S) -> Label:
	var l := label(text, SIZE_BODY, color)
	l.add_theme_font_override("font", font(WEIGHT_BOLD))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pill := _box(Color(INK, 0.92), color, RADIUS, GAP_M)
	pill.set_border_width_all(0)
	pill.border_width_left = 8
	pill.skew = Vector2(SKEW * 0.6, 0)
	pill.content_margin_left = 26
	pill.content_margin_right = 22
	pill.shadow_color = Color(INK, 0.8)
	pill.shadow_size = 1
	pill.shadow_offset = Vector2(4, 4)
	l.add_theme_stylebox_override("normal", pill)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.position.y -= 40
	l.self_modulate.a = 1.0 if text != "" else 0.0
	l.resized.connect(func(): l.self_modulate.a = 1.0 if l.text != "" else 0.0) # il testo arriva dopo (lobby: "Ospita")
	parent.add_child(l)
	if l.is_inside_tree():
		var tw := l.create_tween()
		var y := l.position.y
		l.position.y = y + 16
		tw.tween_property(l, "position:y", y, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Il timer sta dentro l'avviso: parte quando entra in scena e se ne va con lui
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(l.queue_free)
	l.add_child(timer)
	return l


# Riquadro selezionabile (lottatore, arena, schede delle opzioni): bordo giallo quando è scelto.
# Le schede con dentro un disegno restano dritte; i pulsanti con una scritta pendono come gli altri
static func set_selected(b: Button, selected: bool) -> void:
	if b.text != "":
		_set_tab(b, selected)
		return
	var border := ACCENT if selected else INK
	var bg := SELECTED if selected else GRAPE
	b.add_theme_stylebox_override("normal", _card_box(bg, border, selected))
	b.add_theme_stylebox_override("hover", _card_box(bg.lightened(0.1), ACCENT if selected else BORDER.lightened(0.2), selected))
	b.add_theme_stylebox_override("pressed", _card_box(bg.darkened(0.1), ACCENT, true))
	b.add_theme_stylebox_override("hover_pressed", _card_box(bg, ACCENT, true))
	# Il fuoco del pad (E6) si distingue dalla scelta: bordo bianco invece che giallo
	b.add_theme_stylebox_override("focus", focus_box(RADIUS_CARD))


static func _card_box(bg: Color, border: Color, strong: bool) -> StyleBoxFlat:
	var s := _box(bg, border, RADIUS_CARD, 6)
	s.set_border_width_all(4 if strong else OUTLINE)
	s.corner_detail = 1
	s.corner_radius_top_left = RADIUS_CARD * 2
	s.corner_radius_bottom_right = RADIUS_CARD * 2
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.shadow_size = 1
	s.shadow_color = INK
	s.shadow_offset = Vector2(3, 4)
	return s


# Una scheda con la scritta (Audio, Comandi, Tastiera, Pad): scelta è gialla piena, le altre incavate
static func _set_tab(b: Button, selected: bool) -> void:
	var fill := BANANA if selected else FIELD.lightened(0.05)
	b.add_theme_stylebox_override("normal", button_box(fill, false, 8))
	b.add_theme_stylebox_override("hover", button_box(fill.lightened(0.15), false, 8))
	b.add_theme_stylebox_override("pressed", button_box(fill.darkened(0.1), true, 8))
	b.add_theme_stylebox_override("hover_pressed", button_box(fill, true, 8))
	var text := INK if selected else LILAC
	for state in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, text)
	b.add_theme_color_override("font_hover_color", INK if selected else BANANA)


# Schermo scuro con un riquadro centrato, per pausa e opzioni
static func overlay(width: float) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ShaderMaterial.new()
	veil.shader = load("res://shaders/ui_dim.gdshader")
	veil.set_shader_parameter("ink", INK)
	dim.material = veil
	dim.resized.connect(func(): veil.set_shader_parameter("rect_size", dim.size))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	decorate_panel(panel)
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
	_hook(menu.get_tree())
	juice_all(menu)


# Lo scatto dei pulsanti: col fuoco o il mouse sopra crescono di PUNCH_PX per lato, premuti si
# schiacciano. Solo scala attorno al centro: i contenitori non si accorgono di niente
static func juice(b: Control) -> void:
	if b.has_meta("juice") or not b is BaseButton:
		return
	b.set_meta("juice", false) # false = a riposo, true = sotto il mouse
	b.mouse_entered.connect(func():
		b.set_meta("juice", true)
		_punch(b))
	b.mouse_exited.connect(func():
		b.set_meta("juice", false)
		_punch(b))
	b.focus_entered.connect(func(): _punch(b))
	b.focus_exited.connect(func(): _punch(b))
	(b as BaseButton).button_down.connect(func(): _punch(b, 0.96))
	(b as BaseButton).button_up.connect(func(): _punch(b))


static func _punch(b: Control, force := 0.0) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or b.size.x <= 0.0:
		return
	var up: bool = b.has_focus() or b.get_meta("juice", false)
	var target := force if force > 0.0 else (1.0 + minf(0.08, PUNCH_PX * 2.0 / b.size.x) if up and not (b as BaseButton).disabled else 1.0)
	if Access.calm and force == 0.0:
		target = 1.0 + (target - 1.0) * 0.5 # con "meno scossa" lo scatto è la metà
	b.pivot_offset = b.size / 2.0
	if b.has_meta("juice_tween"):
		var old: Tween = b.get_meta("juice_tween")
		if old.is_valid():
			old.kill()
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(target, target), PUNCH_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("juice_tween", tw)


static func juice_all(root: Node) -> void:
	for b in root.find_children("*", "BaseButton", true, false):
		juice(b)


# Una volta sola: ogni pulsante che entra in scena da qui in poi scatta da solo (anche quelli della lobby)
static func _hook(tree: SceneTree) -> void:
	if _hooked or tree == null:
		return
	_hooked = true
	tree.node_added.connect(func(n: Node):
		if n is BaseButton:
			juice(n))


# Lastra storta a inchiostro disegnata col codice (HUD, pre-partita, titolo): rect è il riquadro dritto,
# lean di quanti pixel pende a destra la cima. drop sposta l'ombra dura (zero = senza ombra)
static func draw_plate(ci: CanvasItem, rect: Rect2, fill: Color, lean := 10.0, outline := INK, width := 3.0, drop := Vector2.ZERO) -> void:
	var pts := plate_points(rect, lean)
	if drop != Vector2.ZERO:
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + drop)
		ci.draw_colored_polygon(shadow, Color(INK, fill.a * 0.9))
	ci.draw_colored_polygon(pts, fill)
	if width > 0.0:
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), outline, width, true)


static func plate_points(rect: Rect2, lean: float) -> PackedVector2Array:
	var h := lean / 2.0
	return PackedVector2Array([rect.position + Vector2(h, 0), Vector2(rect.end.x + h, rect.position.y), rect.end - Vector2(h, 0), Vector2(rect.position.x - h, rect.end.y)])


# Scritta "adesivo" disegnata col codice: ombra dura, contorno a inchiostro, colore. pos è la linea di base
static func draw_sticker(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, color: Color, outline := 6, shadow := Vector2(0, 4), shadow_color := INK) -> void:
	if shadow != Vector2.ZERO:
		var sc := Color(shadow_color, shadow_color.a * color.a)
		ci.draw_string_outline(f, pos + shadow, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, sc)
		ci.draw_string(f, pos + shadow, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, sc)
	if outline > 0:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(INK, color.a))
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static var last_copied := "" # l'ultimo testo copiato dal gioco: il proprio link non è un invito (title.gd)


# Copia negli appunti (nel browser passa da navigator.clipboard)
static func copy(text: String) -> void:
	last_copied = text
	DisplayServer.clipboard_set(text)


# Apre un link nel browser. Su Linux OS.shell_open aspetta che xdg-open finisca, e con alcuni browser
# vuol dire finché il browser resta aperto: il gioco si blocca (#321). Lì xdg-open parte staccato.
static func open_url(url: String) -> void:
	if OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"] and OS.create_process("xdg-open", [url]) != -1:
		return
	OS.shell_open(url)
