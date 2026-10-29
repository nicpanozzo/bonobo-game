# Schermata del titolo (E14 passo 2): logo, versione, "Premi un tasto", poi il menu principale.
# La apre main.gd all'avvio; con stanza e nome nell'indirizzo si salta e si entra subito.
# Il menu ha due strade grandi (#250): "Gioca con gli amici" e "Da solo", che apre il suo sottomenu
# (Contro un bot, Allenamento, Tutorial, Sfide). Esc o B dal sottomenu tornano al menu.
extends Control

signal play_requested
signal bot_requested # Da solo → Contro un bot: la lobby parte da "Contro un bot" (#250)
signal options_requested
signal credits_requested
signal leaderboard_requested # la classifica a punti (leaderboard_view.gd)
signal tutorial_requested # tutorial a tappe con lo sparring (E15)
signal training_requested # palestra col manichino e il pannello dell'allenamento (E15)
signal challenges_requested # sfide con medaglie (E15)
signal invite_requested(invite: Dictionary) # entra nella stanza del link copiato: {room, server?}

const Lobby := preload("res://scripts/lobby.gd")
const MenuTile := preload("res://scripts/menu_tile.gd")
const BLINK_S := 0.6 # mezzo giro del lampeggio di "Premi un tasto"
const MENU_W := 640.0 # larghezza del menu sul computer, pixel: i lottatori ai lati restano fuori
const PHONE_MENU_W := 440.0 # sul telefono il menu sta tra i due lottatori del fondo (title_backdrop.gd)
const PHONE_BLEED := 90.0 # sul telefono il fondo esce dallo schermo di tanto per lato: i lottatori finiscono sul bordo, pixel
const TILE_H := 124.0 # le due piastrelle grandi, pixel
const PHONE_TILE_H := 58.0
const SOLO_TILE := Vector2(314, 96) # le quattro di "Da solo", due per riga, pixel
const PHONE_SOLO_H := 56.0 # sul telefono due per riga anche lì, solo col nome
const LIFT := 96.0 # il menu sale di tanto: sotto c'è la fascia gialla che scorre, pixel
const PHONE_LIFT := 50.0
const PHONE_CARD_SIZE := Vector2(PHONE_MENU_W, PHONE_TILE_H) # la larghezza del riquadro dell'invito
const CARD_SIZE := Vector2(MENU_W, TILE_H)

var game: Dictionary
var _press := UI.label("Premi un tasto", UI.SIZE_BIG + 2, UI.PAPER)
var _menu := VBoxContainer.new() # il menu principale
var _solo := VBoxContainer.new() # il sottomenu "Da solo"
var _first: Button
var _solo_first: Button
var _blink := 0.0
var _invite_box: Control # il riquadro dell'invito quando negli appunti c'è il link di una serata
var _invite_card: Button # il suo "Entra"
var _invite := {}
var _own_room := "" # la stanza che si sta ospitando: il proprio link non è un invito


func setup(game_data: Dictionary, skip_press := false, own_room := "") -> void:
	game = game_data
	_own_room = own_room
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Il fondo animato: raggi, sagome, due lottatori ai lati e la fascia che scorre (title_backdrop.gd)
	var backdrop: Control = preload("res://scripts/title_backdrop.gd").new()
	add_child(backdrop)
	backdrop.setup(game)
	if Phone.active: # lo schermo è stretto: i due lottatori vanno verso i bordi e lasciano posto al menu
		backdrop.offset_left = -PHONE_BLEED
		backdrop.offset_right = PHONE_BLEED
	var lift := MarginContainer.new()
	lift.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lift.add_theme_constant_override("margin_bottom", roundi(PHONE_LIFT if Phone.active else LIFT))
	add_child(lift)
	var center := CenterContainer.new()
	lift.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UI.GAP_S if Phone.active else UI.GAP_L)
	center.add_child(box)
	# Sul telefono (Phone) il logo è più piccolo: sotto devono stare le quattro schede di "Da solo"
	var logo: Control = backdrop.make_logo(0.6 if Phone.active else 1.0)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(logo)
	var subtitle := UI.label("Il picchiaduro del nostro Discord", UI.SIZE_SUBTITLE, UI.PAPER)
	subtitle.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
	subtitle.add_theme_color_override("font_outline_color", UI.INK)
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4 if Phone.active else 30)
	box.add_child(spacer)
	# "Premi un tasto": grosso, col contorno a inchiostro, che lampeggia come nei cabinati
	_press.add_theme_font_override("font", UI.display())
	_press.add_theme_color_override("font_outline_color", UI.INK)
	_press.add_theme_constant_override("outline_size", 10)
	_press.add_theme_color_override("font_shadow_color", UI.INK)
	_press.add_theme_constant_override("shadow_offset_y", 4)
	_press.add_theme_constant_override("shadow_outline_size", 10)
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press.custom_minimum_size = Vector2(0, 60)
	if Phone.active:
		_press.text = "Tocca lo schermo"
	box.add_child(_press)
	var menu_w := PHONE_MENU_W if Phone.active else MENU_W
	for m in [_menu, _solo]:
		m.add_theme_constant_override("separation", UI.GAP_M if Phone.active else UI.GAP_L)
		m.custom_minimum_size = Vector2(menu_w, 0)
		m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		m.visible = false
		box.add_child(m)
	# Le due strade grandi: sul computer affiancate (la principale più larga), sul telefono una sopra l'altra
	var tiles: BoxContainer = VBoxContainer.new() if Phone.active else HBoxContainer.new()
	tiles.add_theme_constant_override("separation", UI.GAP_S if Phone.active else UI.GAP_M)
	_menu.add_child(tiles)
	var tile_h := PHONE_TILE_H if Phone.active else TILE_H
	_first = _tile(tiles, "Gioca con gli amici", "Crea una stanza o entra con il link del Discord", "VS", func(): play_requested.emit(), true, tile_h)
	var solo := _tile(tiles, "Da solo", "Bot, allenamento, tutorial e sfide", "1P", _show_solo, false, tile_h)
	if not Phone.active:
		_first.size_flags_stretch_ratio = 1.6
		_first.title_label.add_theme_font_size_override("font_size", Access.px(UI.SIZE_TITLE - 6))
		solo.title_label.add_theme_font_size_override("font_size", Access.px(UI.SIZE_TITLE - 6))
		for t in [_first, solo]:
			t.detail_label.add_theme_font_size_override("font_size", Access.px(UI.SIZE_SMALL))
		solo.detail_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING # col taglio un'etichetta a capo resta alta zero
		solo.detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		solo.detail_label.custom_minimum_size.x = 160.0
	# Le voci piccole in fila sotto le due grandi
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP_S if Phone.active else UI.GAP_M)
	row.add_child(_small("Classifica", func(): leaderboard_requested.emit()))
	row.add_child(_small("Opzioni", func(): options_requested.emit()))
	row.add_child(_small("Crediti", func(): credits_requested.emit()))
	if not OS.has_feature("web"): # nel browser si chiude la scheda
		row.add_child(_small("Esci", func(): get_tree().quit()))
	_menu.add_child(row)
	# Dal browser del telefono il gioco si installa come app (PWA): icona sulla schermata Home e schermo intero
	var install := Phone.install_state() if Phone.active else ""
	if install != "" and install != "installed":
		var hint := UI.note(Phone.install_hint(install))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if install == "ios":
			_menu.add_child(hint)
		else:
			var b := _small("Installa il gioco", func():
				if not Phone.install():
					hint.visible = true)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_menu.add_child(b)
			hint.visible = false
			_menu.add_child(hint)
	# "Da solo": quattro piastrelle, due per riga (sul telefono solo col nome: la spiegazione non ci sta)
	var solo_grid := GridContainer.new()
	solo_grid.columns = 2
	solo_grid.add_theme_constant_override("h_separation", UI.GAP_M)
	solo_grid.add_theme_constant_override("v_separation", UI.GAP_S if Phone.active else UI.GAP_M)
	_solo.add_child(solo_grid)
	var solo_h := PHONE_SOLO_H if Phone.active else SOLO_TILE.y
	_solo_first = _tile(solo_grid, "Contro un bot", "Una partita veloce contro il computer", "CPU", func(): bot_requested.emit(), true, solo_h)
	_tile(solo_grid, "Allenamento", "Le mosse sul manichino, coi numeri", "LAB", func(): training_requested.emit(), false, solo_h)
	_tile(solo_grid, "Tutorial", "I comandi un passo alla volta", "ABC", func(): tutorial_requested.emit(), false, solo_h)
	_tile(solo_grid, "Sfide", "Prove a tempo, con le medaglie", "TOP", func(): challenges_requested.emit(), false, solo_h)
	var back := _small("‹ Indietro", _show_main)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_solo.add_child(back)
	var version := UI.note(UI.version_text(game))
	version.add_theme_color_override("font_outline_color", UI.INK)
	version.add_theme_constant_override("outline_size", 4)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position -= Vector2(UI.GAP_L, UI.GAP_S)
	add_child(version)
	_refresh_invite()
	if skip_press or _invite_card != null: # col link negli appunti niente "Premi un tasto": si entra
		_open_menu()


# Una piastrella del menu (menu_tile.gd) con la sua spiegazione e la sigla; la principale è gialla
func _tile(parent: Control, text: String, detail: String, mark: String, on_press: Callable, primary: bool, height: float) -> Button:
	var b: Button = MenuTile.new().setup(text, detail, mark, on_press, primary)
	var w := 0.0 # nella fila delle due grandi decide la proporzione
	if parent is GridContainer:
		w = (PHONE_MENU_W - UI.GAP_M) / 2.0 if Phone.active else SOLO_TILE.x
		if Phone.active:
			b.detail_label.visible = false
			b.title_label.add_theme_font_size_override("font_size", Access.px(UI.SIZE_BODY + 3))
	elif Phone.active:
		w = PHONE_MENU_W
	b.custom_minimum_size = Vector2(w, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b


func _small(text: String, on_press: Callable) -> Button:
	var b := UI.small_button(text, on_press) if Phone.active else UI.button(text, on_press)
	b.custom_minimum_size = Vector2(0, 30 if Phone.active else 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _show_solo() -> void:
	_menu.visible = false
	_solo.visible = true
	UI.fade_in(_solo)
	_solo_first.grab_focus()


func _show_main() -> void:
	_solo.visible = false
	_menu.visible = true
	UI.fade_in(_menu)
	_first.grab_focus()


func _process(delta: float) -> void:
	if _press.visible:
		_blink += delta
		_press.modulate.a = 0.35 + 0.65 * absf(cos(_blink * PI / (BLINK_S * 2)))


func _open_menu() -> void:
	_press.visible = false
	_menu.visible = true
	_refresh_invite()
	(_invite_card if _invite_card != null else _first).grab_focus.call_deferred()


# Nell'app il link della serata si copia dal Discord e basta aprire il gioco: la prima scheda porta lì.
# Nel browser no: gli appunti non si leggono senza chiedere, e il link aperto porta già nella stanza
func _refresh_invite() -> void:
	if OS.has_feature("web") or not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return
	_show_invite(invite_from(DisplayServer.clipboard_get(), _own_room))


func _show_invite(found: Dictionary) -> void:
	if found == _invite:
		return
	_invite = found
	var had_focus := _invite_card != null and _invite_card.has_focus()
	if _invite_box != null:
		_invite_box.queue_free()
		_invite_box = null
		_invite_card = null
	if found.is_empty():
		if had_focus:
			_first.grab_focus()
		return
	# Un riquadro col bordo giallo sopra il menu, non un'altra scheda grande: si legge dove si entra
	# e si preme Entra; chi vuole fare altro ha il menu di sempre sotto
	_invite_box = PanelContainer.new()
	var frame := UI.panel_box(Color(UI.GRAPE, 0.97), 14)
	frame.border_color = UI.BANANA
	_invite_box.add_theme_stylebox_override("panel", frame)
	_invite_box.custom_minimum_size.x = (PHONE_CARD_SIZE if Phone.active else CARD_SIZE).x
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP_L)
	_invite_box.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var what := UI.label("Ti hanno invitato nella stanza «%s»" % found.room, UI.SIZE_BODY)
	what.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
	words.add_child(what)
	words.add_child(UI.note("Dal link che hai copiato · " + invite_detail(found)))
	_invite_card = UI.button("Entra ▸", func(): invite_requested.emit(_invite))
	UI.set_primary(_invite_card)
	_invite_card.custom_minimum_size = Vector2(110, 0)
	row.add_child(_invite_card)
	_menu.add_child(_invite_box)
	_menu.move_child(_invite_box, 0)
	if had_focus or _menu.visible:
		_invite_card.grab_focus.call_deferred()


# Il link copiato vale come invito se porta una stanza e non è quello appena copiato dal gioco stesso
static func invite_from(text: String, own_room := "") -> Dictionary:
	# Solo un link vero: un testo qualsiasi negli appunti ("ciao") non è un invito
	if text.length() > 2000 or text == UI.last_copied or not text.contains("room="):
		return {}
	var found: Dictionary = Lobby.read_invite(text)
	if not found.has("room") or (own_room != "" and found.room == own_room):
		return {}
	return found


# Dove si gioca: in casa (stesso Wi-Fi), sul computer di un amico (tunnel) o sul server di sempre
static func invite_detail(found: Dictionary) -> String:
	return Lobby.where_text(str(found.get("server", "")))


func _notification(what: int) -> void:
	# Si torna al gioco dopo aver copiato il link dal Discord: la scheda compare senza riaprirlo
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _menu.visible:
		_refresh_invite()


# Il clic se lo prendono i controlli della schermata e a _unhandled_input non arriva: risale fin qui
func _gui_input(event: InputEvent) -> void:
	if _press.visible and event is InputEventMouseButton and event.is_pressed():
		accept_event()
		_open_menu()


# Un tasto o un pulsante del pad: compare il menu (il tasto non fa altro). Esc o B: dal sottomenu al menu
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _solo.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_main()
		return
	if not _press.visible:
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed()
	if pressed:
		get_viewport().set_input_as_handled()
		_open_menu()


# Torna il fuoco al menu quando si chiudono opzioni, crediti o sfide
func restore_focus() -> void:
	if _menu.visible:
		(_invite_card if _invite_card != null else _first).grab_focus()
	elif _solo.visible:
		_solo_first.grab_focus()
