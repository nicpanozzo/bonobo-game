# Schermata del titolo (E14 passo 2): logo, versione, "Premi un tasto", poi il menu principale.
# La apre main.gd all'avvio; con stanza e nome nell'indirizzo si salta e si entra subito.
# Il menu ha due strade grandi (#250): "Gioca con gli amici" e "Da solo", che apre il suo sottomenu
# (Contro un bot, Allenamento, Tutorial, Sfide). Esc o B dal sottomenu tornano al menu.
extends Control

signal play_requested
signal bot_requested # Da solo → Contro un bot: la lobby parte da "Contro un bot" (#250)
signal options_requested
signal credits_requested
signal tutorial_requested # tutorial a tappe con lo sparring (E15)
signal training_requested # palestra col manichino e il pannello dell'allenamento (E15)
signal challenges_requested # sfide con medaglie (E15)
signal invite_requested(invite: Dictionary) # entra nella stanza del link copiato: {room, server?}

const Lobby := preload("res://scripts/lobby.gd")
const BLINK_S := 0.6 # mezzo giro del lampeggio di "Premi un tasto"
const CARD_SIZE := Vector2(460, 76) # schede del menu, pixel
const PHONE_CARD_SIZE := Vector2(460, 64) # sul telefono un po' più basse: il sottomenu "Da solo" ne ha quattro

var game: Dictionary
var _press := UI.label("Premi un tasto", UI.SIZE_BIG, UI.TEXT)
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
	# Sul telefono (Phone) il logo è più piccolo: sotto devono stare le quattro schede di "Da solo"
	logo.add_theme_font_size_override("font_size", Access.px(roundi(UI.SIZE_TITLE * (1.4 if Phone.active else 2.0))))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(logo)
	var subtitle := UI.label("Il picchiaduro del nostro Discord", UI.SIZE_SUBTITLE, Color(UI.TEXT, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8 if Phone.active else 40)
	box.add_child(spacer)
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Phone.active:
		_press.text = "Tocca lo schermo"
	box.add_child(_press)
	for m in [_menu, _solo]:
		m.add_theme_constant_override("separation", UI.GAP_M)
		m.visible = false
		box.add_child(m)
	_first = _card(_menu, "Gioca con gli amici", "Crea una stanza o entra con il link del Discord", func(): play_requested.emit(), true)
	_card(_menu, "Da solo", "Contro un bot, allenamento, tutorial e sfide", _show_solo)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UI.GAP_M)
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
	_solo_first = _card(_solo, "Contro un bot", "Una partita veloce contro il computer", func(): bot_requested.emit(), true)
	_card(_solo, "Allenamento", "Prova le mosse sul manichino, con i numeri dei colpi", func(): training_requested.emit())
	_card(_solo, "Tutorial", "Impara i comandi un passo alla volta", func(): tutorial_requested.emit())
	_card(_solo, "Sfide", "Prove a tempo, con le medaglie", func(): challenges_requested.emit())
	var back := _small("‹ Indietro", _show_main)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_solo.add_child(back)
	var version := UI.note(UI.version_text(game))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position -= Vector2(UI.GAP_L, UI.GAP_L)
	add_child(version)
	_refresh_invite()
	if skip_press or _invite_card != null: # col link negli appunti niente "Premi un tasto": si entra
		_open_menu()


# Scheda del menu con la sua spiegazione; quella principale è rossa come i pulsanti per giocare
func _card(menu: Control, text: String, detail: String, on_press: Callable, primary := false) -> Button:
	var b := UI.choice_card(text, detail, on_press)
	b.custom_minimum_size = PHONE_CARD_SIZE if Phone.active else CARD_SIZE
	if primary:
		UI.set_primary(b)
	menu.add_child(b)
	return b


func _small(text: String, on_press: Callable) -> Button:
	var b := UI.button(text, on_press)
	b.custom_minimum_size = Vector2(140, 0)
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
	_invite_box.add_theme_stylebox_override("panel", UI._box(UI.CARD, UI.ACCENT, UI.RADIUS_CARD, UI.GAP_L))
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
