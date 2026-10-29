# Il menu opzioni, a schede: Audio, Voce (chat vocale), Comandi, Video (E14, solo nell'app) e Accessibilità.
# Lo aprono la lobby e il menu di pausa. I comandi hanno due schede, Tastiera e Pad (E6).
extends Control

signal closed

const SLOTS := 2 # tasti per azione mostrati nel menu
const PAD_SLOTS := Settings.MAX_PAD # sul pad la schivata ne ha 4 di default: si vedono tutti
const WARN := UI.WARN

var settings: Settings
var _keys := GridContainer.new()
var _waiting := {} # { action, slot } mentre si aspetta il tasto nuovo
var _box: VBoxContainer
var _pad := false # scheda Pad aperta
var _tabs := {} # false/true -> pulsante della scheda
var _notice := HBoxContainer.new() # "B tolto da Attacco pesante" con Annulla, o l'avviso di azione senza tasti
var _hint := ""
var _undo := {} # tasti prima dell'ultimo spostamento, per Annulla
var _pages := {} # "audio", "keys", "video", "access" -> contenuto della scheda
var _page_tabs := {} # stesse chiavi -> pulsante della scheda
var _reset_keys: Button
var _voice_waiting := "" # azione della voce (ptt, mute, deafen) che aspetta il tasto nuovo
var _voice_keys := {} # azione della voce -> pulsante del tasto
var _voice_notice: Label
var _voice_meter: LevelMeter
var _voice_test: Button
var _voice_devices: OptionButton
var _voice_modes := {} # "vad"/"ptt" -> pulsante
# Tasti che il gioco usa già fuori dalle azioni (musica, rivincita, pausa...): la voce non li prende
const VOICE_KEYS_HINT := "Clicca un tasto e premi quello nuovo: valgono anche in partita, dove il riquadro non ha pulsanti."
const VOICE_RESERVED := [KEY_ESCAPE, KEY_M, KEY_R, KEY_P, KEY_F11, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]


func setup(s: Settings) -> void:
	settings = s
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(680)
	add_child(parts[0])
	_box = parts[1]
	# Titolo e schede sulla stessa riga: il menu deve stare in 720 pixel
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UI.GAP_S)
	var title := UI.header("Opzioni")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_box.add_child(top)
	var pages := [["audio", "Audio", _audio_page()], ["voice", "Voce", _voice_page()], ["keys", "Comandi", _keys_page()], ["video", "Video", _video_page()]]
	pages.append(["touch", "Touch", _touch_page()])
	pages.append(["access", "Accessibilità", _access_page()])
	for page in pages:
		var b := UI.button(page[1], func(): _show_page(page[0]))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_page_tabs[page[0]] = b
		top.add_child(b)
		_pages[page[0]] = page[2]
		_box.add_child(page[2])
	var actions := HBoxContainer.new()
	_reset_keys = UI.button("Ripristina", func():
		settings.reset_bindings(_pad)
		_waiting = {}
		_set_notice("")
		_draw_keys())
	actions.add_child(_reset_keys)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var done := UI.button("Fatto", close, true)
	actions.add_child(done)
	_box.add_child(actions)
	_show_tab(false)
	_show_page("audio")
	UI.keep_focus(self, done)


# Apre il menu su una scheda (il riquadro della voce apre "voice")
func open_page(id: String) -> void:
	if _pages.has(id):
		_show_page(id)


# Una scheda alla volta: Audio, Comandi, Video o Accessibilità
func _show_page(id: String) -> void:
	if id != "voice":
		_stop_voice_test()
		if _voice_waiting != "":
			_voice_waiting = ""
			_draw_voice_keys()
	for p in _pages:
		_pages[p].visible = p == id
		UI.set_selected(_page_tabs[p], p == id)
	_reset_keys.visible = id == "keys" # Ripristina vale solo per i tasti
	if not _waiting.is_empty(): # si cambia scheda mentre si aspettava un tasto: si annulla
		_waiting = {}
		_draw_keys()


func _audio_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	for v in [["master", "Generale"], ["sfx", "Effetti"], ["music", "Musica"], ["voices", "Voci"]]:
		page.add_child(_volume_row(v[0], v[1]))
	page.add_child(UI.toggle("Musica accesa (anche con M)", settings.music_on, func(on):
		settings.music_on = on
		settings.save()))
	var row := HBoxContainer.new()
	row.add_child(UI.label("Vibrazione del pad"))
	var rumble := OptionButton.new()
	for name in Rumble.LEVEL_NAMES:
		rumble.add_item(name)
	rumble.select(settings.rumble)
	rumble.item_selected.connect(func(i):
		settings.rumble = i
		settings.save())
	row.add_child(rumble)
	page.add_child(row)
	return page


func _keys_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	var tabs := HBoxContainer.new()
	for pad in [false, true]:
		var t := UI.button("Pad" if pad else "Tastiera", func(): _show_tab(pad))
		_tabs[pad] = t
		tabs.add_child(t)
	# Predizione (E17): sulla riga delle schede, così c'è anche nel browser (che non ha la pagina Video)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	tabs.add_child(UI.toggle("Risposta immediata (predizione)", settings.video.predict, func(on):
		settings.video.predict = on
		settings.save()))
	page.add_child(tabs)
	_keys.add_theme_constant_override("h_separation", UI.GAP_M)
	# Col testo grande le tredici righe dei tasti devono stare in 720 pixel: righe attaccate
	_keys.add_theme_constant_override("v_separation", 4 if Access.text_scale <= 1.0 else 0)
	page.add_child(_keys)
	_notice.add_theme_constant_override("separation", UI.GAP_L)
	_notice.custom_minimum_size = Vector2(0, 36)
	page.add_child(_notice)
	return page


# Anche nel browser, ma lì finestra e frequenza le decide la pagina
func _video_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	var save := func(key: String, value: Variant) -> void:
		settings.video[key] = value
		settings.save()
	if Video.available():
		page.add_child(UI.toggle("Schermo intero (anche con F11)", settings.video.fullscreen, func(on): save.call("fullscreen", on)))
		page.add_child(_choice_row("Finestra", Video.WINDOW_NAMES, settings.video.window, func(i): save.call("window", i)))
		page.add_child(UI.toggle("Sincronizza con lo schermo (vsync)", settings.video.vsync, func(on): save.call("vsync", on)))
		page.add_child(_choice_row("FPS massimi", Video.FPS_NAMES, settings.video.max_fps, func(i): save.call("max_fps", i)))
	page.add_child(UI.toggle("Scie e polvere", settings.video.effects, func(on): save.call("effects", on)))
	page.add_child(UI.toggle("Luce e colori dell'arena", settings.video.post, func(on): save.call("post", on)))
	page.add_child(UI.toggle("Hitbox dei colpi", settings.video.hitboxes, func(on): save.call("hitboxes", on)))
	page.add_child(UI.toggle("Contatore FPS", settings.video.fps_counter, func(on): save.call("fps_counter", on)))
	return page


# Comandi a schermo per il telefono (E18): valgono dalla prossima volta che compaiono
func _touch_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	var save := func(key: String, value: Variant) -> void:
		settings.touch[key] = value
		settings.save()
	page.add_child(_choice_row("Tasti", TouchControls.SIZE_NAMES, settings.touch.size, func(i): save.call("size", i)))
	page.add_child(_choice_row("Trasparenza", TouchControls.OPACITY_NAMES, settings.touch.opacity, func(i): save.call("opacity", i)))
	page.add_child(_choice_row("Schermo", Phone.SCREEN_NAMES, settings.touch.screen, func(i): save.call("screen", i)))
	page.add_child(UI.toggle("Mancino: levetta a destra, tasti a sinistra", settings.touch.left_handed, func(on): save.call("left_handed", on)))
	page.add_child(UI.note("Levetta e tasti compaiono in partita quando tocchi lo schermo e spariscono se usi tastiera o pad. Schermo \"Telefono\" fa tutto più grande, come sul cellulare."))
	return page


func _access_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	var save := func(key: String, value: Variant) -> void:
		settings.access[key] = value
		settings.save()
	page.add_child(UI.toggle("Meno scossa e lampi", settings.access.calm, func(on): save.call("calm", on)))
	page.add_child(UI.toggle("Colori per daltonici", settings.access.colorblind, func(on): save.call("colorblind", on)))
	page.add_child(_choice_row("Testo", Access.TEXT_NAMES, settings.access.text_size, func(i):
		save.call("text_size", i)
		_rebuild.call_deferred()))
	page.add_child(UI.note("La dimensione del testo vale per i menu e per le scritte in partita."))
	return page


# Il testo ha cambiato misura: si rifà il menu con le misure nuove, sulla stessa scheda
func _rebuild() -> void:
	var fresh: Control = load("res://scripts/options.gd").new()
	fresh.theme = UI.theme()
	for c in closed.get_connections():
		fresh.closed.connect(c.callable)
	add_sibling(fresh)
	fresh.setup(settings)
	fresh._show_page("access")
	queue_free() # senza closed: il menu resta aperto, è solo nuovo


func _choice_row(text: String, names: Array, selected: int, on_select: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UI.label(text)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var choice := OptionButton.new()
	for n in names:
		choice.add_item(n)
	choice.select(clampi(selected, 0, names.size() - 1))
	choice.item_selected.connect(on_select)
	row.add_child(choice)
	return row


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
		_notice.add_child(UI.note(_hint))
		return
	_notice.add_child(UI.label(text, UI.SIZE_SMALL + 1, color))
	if can_undo:
		var b := UI.button("Annulla", func():
			settings.bindings = _undo.keys
			settings.voice_keys = _undo.get("voice", settings.voice_keys)
			_draw_voice_keys()
			settings.pad_bindings = _undo.pad
			settings.save()
			_set_notice("")
			_draw_keys())
		_notice.add_child(b)


func close() -> void:
	_stop_voice_test()
	queue_free()
	closed.emit()


func _volume_row(key: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UI.label(text)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var value := UI.label(str(roundi(settings.get(key) * 100)))
	var slider := UI.slider(roundf(settings.get(key) * 100), func(v):
		value.text = str(int(v))
		settings.set(key, v / 100.0)
		settings.save())
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	value.custom_minimum_size = Vector2(40, 0)
	value.add_theme_font_override("font", UI.numbers(UI.WEIGHT_BOLD, false))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
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
		var name := UI.label(Settings.LABELS[action], UI.SIZE_SMALL + 1, WARN if list.is_empty() else UI.TEXT)
		name.custom_minimum_size = Vector2(160, 0)
		_keys.add_child(name)
		for slot in (PAD_SLOTS if _pad else SLOTS):
			var waiting: bool = _waiting.get("action") == action and _waiting.get("slot") == slot
			var text := "—"
			if waiting:
				text = "Premi..." if _pad else "Premi un tasto..."
			elif slot < list.size():
				text = Settings.pad_label(list[slot], kind) if _pad else Settings.key_label(list[slot])
			# Riquadri più bassi del solito, così otto righe di comandi stanno nello schermo
			var b := UI.small_button(text, func():
				_waiting = {"action": action, "slot": slot}
				_draw_keys())
			b.custom_minimum_size = Vector2(110 if _pad else 160, 0)
			if Access.text_scale > 1.0:
				b.add_theme_font_size_override("font_size", Access.px(UI.SIZE_SMALL - 1))
			b.clip_text = true
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
	_undo = {"keys": settings.bindings.duplicate(true), "pad": settings.pad_bindings.duplicate(true), "voice": settings.voice_keys.duplicate(true)}
	var from := settings.assign(_waiting.action, _waiting.slot, code, _pad)
	_waiting = {}
	if from != "":
		var name := Settings.pad_label(code, Settings.pad_kind(_pad_name())) if _pad else Settings.key_label(code)
		_set_notice("%s tolto da %s" % [name, Settings.action_label(from)], UI.ACCENT, true)
		_draw_voice_keys() # il tasto poteva essere della voce
	else:
		_set_notice("")
	_draw_keys()


# I tasti premuti mentre il menu è aperto servono solo qui. In attesa di un tasto
# si accetta solo il dispositivo della scheda aperta; Esc e Canc valgono per entrambe.
func _input(event: InputEvent) -> void:
	if _voice_waiting != "" and _voice_key_input(event):
		return
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


# ---- Scheda Voce (chat vocale) ----

func _voice_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UI.GAP_S + 1)
	var vc := VoiceChat.current
	var on_web := vc != null and vc.supported
	var save := func(key: String, value: Variant) -> void:
		settings.voice[key] = value
		settings.save()
	if not on_web:
		var why := UI.label("La chat vocale funziona nel browser: apri il gioco dal link della stanza.", UI.SIZE_SMALL, UI.WARN)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(why)
	# Modalità: a voce (come Discord) o col tasto
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", UI.GAP_S)
	var mode_l := UI.label("Parli")
	mode_l.custom_minimum_size = Vector2(140, 0)
	mode_row.add_child(mode_l)
	for m in [["vad", "Quando parli"], ["ptt", "Col tasto premuto"]]:
		var b := UI.button(m[1], func():
			save.call("mode", m[0])
			_draw_voice_modes())
		b.disabled = not on_web
		_voice_modes[m[0]] = b
		mode_row.add_child(b)
	page.add_child(mode_row)
	# Tasti: come nella scheda Comandi, un clic e poi il tasto nuovo
	var keys_row := HBoxContainer.new()
	keys_row.add_theme_constant_override("separation", UI.GAP_S)
	var keys_l := UI.label("Tasti")
	keys_l.custom_minimum_size = Vector2(140, 0)
	keys_row.add_child(keys_l)
	for a in Settings.VOICE_KEY_DEFAULTS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UI.note(Settings.VOICE_LABELS[a]))
		var b := UI.small_button("", func():
			_voice_waiting = a
			_set_voice_notice("Premi il tasto nuovo. Canc lo toglie, Esc annulla.")
			_draw_voice_keys())
		b.custom_minimum_size = Vector2(150, 0)
		b.clip_text = true
		b.disabled = not on_web
		_voice_keys[a] = b
		cell.add_child(b)
		keys_row.add_child(cell)
	page.add_child(keys_row)
	_voice_notice = UI.note(VOICE_KEYS_HINT)
	page.add_child(_voice_notice)
	# Sensibilità con il misuratore dal vivo: la tacca è la soglia, la barra diventa verde quando passi
	var sens := HBoxContainer.new()
	var sens_l := UI.label("Sensibilità")
	sens_l.custom_minimum_size = Vector2(140, 0)
	sens.add_child(sens_l)
	var meter_box := VBoxContainer.new()
	meter_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_box.add_theme_constant_override("separation", 2)
	_voice_meter = LevelMeter.new()
	_voice_meter.custom_minimum_size = Vector2(0, 12)
	_voice_meter.threshold = float(settings.voice.vad_threshold)
	meter_box.add_child(_voice_meter)
	var slider := UI.slider(roundf(float(settings.voice.vad_threshold) * 100.0), func(v: float):
		_voice_meter.threshold = v / 100.0
		_voice_meter.queue_redraw()
		save.call("vad_threshold", v / 100.0))
	slider.editable = on_web
	meter_box.add_child(slider)
	sens.add_child(meter_box)
	_voice_test = UI.small_button("Prova il microfono", _toggle_voice_test)
	_voice_test.disabled = not on_web
	_voice_test.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sens.add_child(_voice_test)
	page.add_child(sens)
	page.add_child(UI.note("Nella prova ti senti in cuffia: senza cuffie abbassa il volume, se no fischia."))
	# Microfono
	var dev_row := HBoxContainer.new()
	var dev_l := UI.label("Microfono")
	dev_l.custom_minimum_size = Vector2(140, 0)
	dev_row.add_child(dev_l)
	_voice_devices = OptionButton.new()
	_voice_devices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice_devices.clip_text = true
	_voice_devices.disabled = not on_web
	_voice_devices.item_selected.connect(func(i: int):
		var id: String = _voice_devices.get_item_metadata(i)
		if vc != null:
			vc.set_input_device(id)
		else:
			save.call("device", id))
	dev_row.add_child(_voice_devices)
	page.add_child(dev_row)
	_fill_voice_devices()
	# Volume delle voci degli altri, fino al 200%
	var vol := HBoxContainer.new()
	var vol_l := UI.label("Volume delle voci")
	vol_l.custom_minimum_size = Vector2(140, 0)
	vol.add_child(vol_l)
	var vol_value := UI.label("%d%%" % roundi(float(settings.voice.volume) * 100.0))
	var vol_slider := UI.slider(roundf(float(settings.voice.volume) * 100.0), func(v: float):
		vol_value.text = "%d%%" % roundi(v)
		save.call("volume", v / 100.0), 200.0, 5.0)
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol_slider.editable = on_web
	vol.add_child(vol_slider)
	vol_value.custom_minimum_size = Vector2(52, 0)
	vol_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vol.add_child(vol_value)
	page.add_child(vol)
	var toggles := [
		["auto_join", "Entra in voce appena entri in una stanza"],
		["spatial", "In sala chi è lontano si sente più piano"],
		["sounds", "Bip quando qualcuno entra, esce o spegne il microfono"],
	]
	for t in toggles:
		var c := UI.toggle(t[1], bool(settings.voice[t[0]]), func(on: bool): save.call(t[0], on))
		c.disabled = not on_web
		page.add_child(c)
	_draw_voice_modes()
	_draw_voice_keys()
	if vc != null:
		vc.levels_changed.connect(_on_voice_levels)
		vc.devices_changed.connect(_fill_voice_devices)
		vc.refresh_devices()
	return page


func _draw_voice_modes() -> void:
	for m in _voice_modes:
		UI.set_selected(_voice_modes[m], m == str(settings.voice.mode))


func _draw_voice_keys() -> void:
	for a in _voice_keys:
		var b: Button = _voice_keys[a]
		var label := settings.voice_key_label(a)
		b.text = "Premi un tasto..." if _voice_waiting == a else (label if label != "" else "—")
		b.remove_theme_color_override("font_color")
		if _voice_waiting == a:
			b.add_theme_color_override("font_color", UI.ACCENT)


func _set_voice_notice(text: String, color := UI.LILAC) -> void:
	if _voice_notice != null:
		_voice_notice.text = text if text != "" else VOICE_KEYS_HINT
		_voice_notice.add_theme_color_override("font_color", color)


# Un tasto mentre la voce ne aspetta uno: true se l'ha preso
func _voice_key_input(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	get_viewport().set_input_as_handled()
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	var action := _voice_waiting
	if code == KEY_ESCAPE:
		_voice_waiting = ""
		_set_voice_notice("")
	elif code in [KEY_DELETE, KEY_BACKSPACE]:
		_voice_waiting = ""
		settings.assign_voice(action, 0)
		_set_voice_notice("")
	elif code in VOICE_RESERVED:
		_set_voice_notice("%s lo usa già il gioco: scegline un altro" % Settings.key_label(code), WARN)
		return true
	else:
		_voice_waiting = ""
		var from := settings.assign_voice(action, code)
		_set_voice_notice("%s tolto da %s" % [Settings.key_label(code), Settings.action_label(from)] if from != "" else "", UI.ACCENT)
		if from != "" and not from.begins_with(Settings.VOICE_PREFIX):
			_draw_keys() # la scheda Comandi perde quel tasto
	_draw_voice_keys()
	return true


func _toggle_voice_test() -> void:
	var vc := VoiceChat.current
	if vc == null:
		return
	vc.test_mic(not vc.testing)
	_voice_test.text = "Ferma la prova" if vc.testing else "Prova il microfono"


func _stop_voice_test() -> void:
	var vc := VoiceChat.current
	if vc != null and vc.testing:
		vc.test_mic(false)
	if _voice_test != null:
		_voice_test.text = "Prova il microfono"


func _on_voice_levels() -> void:
	var vc := VoiceChat.current
	if vc == null or _voice_meter == null:
		return
	_voice_meter.level = float(vc.levels.get(vc.my_id, 0.0))
	_voice_meter.queue_redraw()


func _fill_voice_devices() -> void:
	if _voice_devices == null:
		return
	_voice_devices.clear()
	_voice_devices.add_item("Quello di sistema")
	_voice_devices.set_item_metadata(0, "")
	var chosen := str(settings.voice.device)
	var vc := VoiceChat.current
	var list: Array = vc.devices if vc != null else []
	for d in list:
		if not d is Dictionary or str(d.get("id", "")) in ["", "default"]:
			continue
		_voice_devices.add_item(str(d.get("label", "Microfono")))
		_voice_devices.set_item_metadata(_voice_devices.item_count - 1, str(d.id))
		if str(d.id) == chosen:
			_voice_devices.select(_voice_devices.item_count - 1)
	if list.is_empty():
		_voice_devices.add_item("(gli altri compaiono dopo il primo permesso)")
		_voice_devices.set_item_disabled(1, true)
		_voice_devices.set_item_metadata(1, "")


# Il misuratore del microfono: barra del livello, tacca della soglia, verde quando la supera
class LevelMeter extends Control:
	var level := 0.0
	var threshold := 0.45

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UI.FIELD, true)
		var over := level > threshold
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(level, 0.0, 1.0), size.y)), UI.MINT if over else UI.LILAC.darkened(0.2), true)
		var tx := size.x * clampf(threshold, 0.0, 1.0)
		draw_line(Vector2(tx, -2), Vector2(tx, size.y + 2), UI.BANANA, 3.0)
		draw_rect(r, UI.INK, false, 2.0)
