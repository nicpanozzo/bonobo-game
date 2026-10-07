# Il menu opzioni (come src/client/OptionsPanel.ts): volumi, musica e comandi.
# Lo aprono la lobby e il menu di pausa. I comandi hanno due schede, Tastiera e Pad (E6).
extends Control

signal closed

const SLOTS := 2 # tasti per azione mostrati nel menu
const PAD_SLOTS := Settings.MAX_PAD # sul pad la schivata ne ha 4 di default: si vedono tutti
const WARN := Color("ff6b6b")

var settings: Settings
var _keys := GridContainer.new()
var _waiting := {} # { action, slot } mentre si aspetta il tasto nuovo
var _box: VBoxContainer
var _pad := false # scheda Pad aperta
var _tabs := {} # false/true -> pulsante della scheda
var _notice := HBoxContainer.new() # "B tolto da Attacco pesante" con Annulla, o l'avviso di azione senza tasti
var _hint := ""
var _undo := {} # tasti prima dell'ultimo spostamento, per Annulla


func setup(s: Settings) -> void:
	settings = s
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(680)
	add_child(parts[0])
	_box = parts[1]
	_box.add_child(UI.label("Opzioni", 28, UI.ACCENT))
	_box.add_child(UI.heading("Audio"))
	for v in [["master", "Generale"], ["sfx", "Effetti"], ["music", "Musica"]]:
		_box.add_child(_volume_row(v[0], v[1]))
	var music := CheckBox.new()
	music.text = "Musica accesa (anche con M)"
	music.button_pressed = settings.music_on
	music.toggled.connect(func(on):
		settings.music_on = on
		settings.save())
	# Vibrazione del pad sulla stessa riga della musica: il menu deve stare in 720 pixel
	var row := HBoxContainer.new()
	music.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(music)
	row.add_child(UI.label("Vibrazione"))
	var rumble := OptionButton.new()
	for name in Rumble.LEVEL_NAMES:
		rumble.add_item(name)
	rumble.select(settings.rumble)
	rumble.item_selected.connect(func(i):
		settings.rumble = i
		settings.save())
	row.add_child(rumble)
	_box.add_child(row)
	# Titoletto e schede sulla stessa riga: il menu deve stare in 720 pixel
	var tabs := HBoxContainer.new()
	var heading := UI.heading("Comandi")
	heading.custom_minimum_size = Vector2(160, 0)
	tabs.add_child(heading)
	for pad in [false, true]:
		var t := UI.button("Pad" if pad else "Tastiera", func(): _show_tab(pad))
		_tabs[pad] = t
		tabs.add_child(t)
	_box.add_child(tabs)
	_keys.add_theme_constant_override("h_separation", 8)
	_box.add_child(_keys)
	_notice.add_theme_constant_override("separation", 12)
	_notice.custom_minimum_size = Vector2(0, 36)
	_box.add_child(_notice)
	var actions := HBoxContainer.new()
	actions.add_child(UI.button("Ripristina", func():
		settings.reset_bindings(_pad)
		_waiting = {}
		_set_notice("")
		_draw_keys()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var done := UI.button("Fatto", close, true)
	actions.add_child(done)
	_box.add_child(actions)
	_show_tab(false)
	UI.keep_focus(self, done)


func _show_tab(pad: bool) -> void:
	_pad = pad
	_waiting = {}
	for p in _tabs:
		UI.set_selected(_tabs[p], p == pad)
	_keys.columns = 1 + (PAD_SLOTS if pad else SLOTS)
	_hint = ("Clicca un riquadro e premi un pulsante o inclina una levetta. Canc lo toglie, Esc annulla." if pad
		else "Clicca un tasto e premi quello nuovo. Canc lo toglie, Esc annulla.")
	_set_notice("")
	_draw_keys()


# Una riga sotto i tasti: testo e, se c'è da annullare, il pulsante Annulla
func _set_notice(text: String, color := UI.TEXT, can_undo := false) -> void:
	for c in _notice.get_children():
		_notice.remove_child(c)
		c.queue_free()
	if text == "": # senza niente da dire, la riga spiega come si cambia un tasto
		_notice.add_child(UI.label(_hint, 13, Color(UI.TEXT, 0.7)))
		return
	_notice.add_child(UI.label(text, 15, color))
	if can_undo:
		var b := UI.button("Annulla", func():
			settings.bindings = _undo.keys
			settings.pad_bindings = _undo.pad
			settings.save()
			_set_notice("")
			_draw_keys())
		_notice.add_child(b)


func close() -> void:
	queue_free()
	closed.emit()


func _volume_row(key: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UI.label(text)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = roundf(settings.get(key) * 100)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UI.label(str(int(slider.value)))
	value.custom_minimum_size = Vector2(40, 0)
	row.add_child(value)
	slider.value_changed.connect(func(v):
		value.text = str(int(v))
		settings.set(key, v / 100.0)
		settings.save())
	return row


func _draw_keys() -> void:
	# Col pad il fuoco resta sul riquadro appena cambiato, anche se i pulsanti si rifanno
	var had := get_viewport().gui_get_focus_owner()
	var keep: String = had.get_meta("slot", "") if had != null and _keys.is_ancestor_of(had) else ""
	for c in _keys.get_children():
		_keys.remove_child(c)
		c.queue_free()
	var all: Dictionary = settings.pad_bindings if _pad else settings.bindings
	var kind := Settings.pad_kind(_pad_name())
	var empty := []
	for action in Settings.ACTIONS:
		var list: Array = all[action]
		if list.is_empty():
			empty.append(Settings.LABELS[action])
		# Un'azione senza tasti resta in rosso finché non se ne assegna uno
		var name := UI.label(Settings.LABELS[action], 15, WARN if list.is_empty() else UI.TEXT)
		name.custom_minimum_size = Vector2(160, 0)
		_keys.add_child(name)
		for slot in (PAD_SLOTS if _pad else SLOTS):
			var waiting: bool = _waiting.get("action") == action and _waiting.get("slot") == slot
			var text := "—"
			if waiting:
				text = "Premi..." if _pad else "Premi un tasto..."
			elif slot < list.size():
				text = Settings.pad_label(list[slot], kind) if _pad else Settings.key_label(list[slot])
			var b := UI.button(text, func():
				_waiting = {"action": action, "slot": slot}
				_draw_keys())
			b.custom_minimum_size = Vector2(110 if _pad else 160, 0)
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 15)
			# Riquadri più bassi del solito, così otto righe di comandi stanno nello schermo
			b.add_theme_stylebox_override("normal", UI._box(UI.BORDER, UI.BORDER, 8, 4))
			b.add_theme_stylebox_override("hover", UI._box(UI.BORDER.lightened(0.2), UI.BORDER.lightened(0.2), 8, 4))
			# Spazio e invio non arrivano al pulsante (li prende _input come tasti da assegnare),
			# ma il pad ci si muove sopra e lo preme con A
			b.set_meta("slot", "%s:%d" % [action, slot])
			if b.get_meta("slot") == keep:
				b.grab_focus.call_deferred()
			if waiting:
				b.add_theme_color_override("font_color", UI.ACCENT)
			elif list.is_empty() and slot == 0:
				b.add_theme_color_override("font_color", WARN)
			_keys.add_child(b)
	if not empty.is_empty() and _notice.get_child_count() == 1 and _notice.get_child(0).text == _hint:
		_set_notice("Senza tasti: " + ", ".join(empty), WARN)


# Il primo pad collegato decide i nomi dei pulsanti (A/Croce, B/Cerchio...)
func _pad_name() -> String:
	var pads := Input.get_connected_joypads()
	return Input.get_joy_name(pads[0]) if not pads.is_empty() else ""


func _assign(code: int) -> void:
	_undo = {"keys": settings.bindings.duplicate(true), "pad": settings.pad_bindings.duplicate(true)}
	var from := settings.assign(_waiting.action, _waiting.slot, code, _pad)
	_waiting = {}
	if from != "":
		var name := Settings.pad_label(code, Settings.pad_kind(_pad_name())) if _pad else Settings.key_label(code)
		_set_notice("%s tolto da %s" % [name, Settings.LABELS[from]], UI.ACCENT, true)
	else:
		_set_notice("")
	_draw_keys()


# I tasti premuti mentre il menu è aperto servono solo qui. In attesa di un tasto
# si accetta solo il dispositivo della scheda aperta; Esc e Canc valgono per entrambe.
func _input(event: InputEvent) -> void:
	if _pad and not _waiting.is_empty():
		var code := _pad_code(event)
		if code >= 0:
			get_viewport().set_input_as_handled()
			_assign(code)
			return
	# B sul pad: annulla l'attesa o chiude, come Esc
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _waiting.is_empty():
			close()
		else:
			_waiting = {}
			_draw_keys()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if _waiting.is_empty():
		if key.keycode == KEY_ESCAPE:
			close()
		return
	if key.keycode == KEY_ESCAPE:
		_waiting = {}
		_draw_keys()
	elif key.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_assign(-1 if _pad else 0)
	elif not _pad:
		_assign(key.physical_keycode if key.physical_keycode != 0 else key.keycode)


# Pulsante premuto o levetta inclinata oltre la zona morta, come in pad_bindings; -1 se niente
func _pad_code(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index
	if event is InputEventJoypadMotion and absf(event.axis_value) > settings.stick_deadzone:
		return Settings.axis_input(event.axis, event.axis_value > 0)
	return -1
