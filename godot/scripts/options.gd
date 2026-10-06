# Il menu opzioni (come src/client/OptionsPanel.ts): volumi, musica e tasti.
# Lo aprono la lobby e il menu di pausa.
extends Control

signal closed

const SLOTS := 2 # tasti per azione mostrati nel menu

var settings: Settings
var _keys := GridContainer.new()
var _waiting := {} # { action, slot } mentre si aspetta il tasto nuovo
var _box: VBoxContainer


func setup(s: Settings) -> void:
	settings = s
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(540)
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
	_box.add_child(music)
	_box.add_child(UI.heading("Tasti"))
	_keys.columns = 1 + SLOTS
	_keys.add_theme_constant_override("h_separation", 10)
	_box.add_child(_keys)
	_box.add_child(UI.label("Clicca un tasto e premi quello nuovo. Canc lo toglie, Esc annulla.", 13, Color(UI.TEXT, 0.7)))
	var actions := HBoxContainer.new()
	actions.add_child(UI.button("Ripristina", func():
		settings.reset()
		_draw_keys()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	actions.add_child(UI.button("Fatto", close, true))
	_box.add_child(actions)
	_draw_keys()


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
	for c in _keys.get_children():
		c.queue_free()
	for action in Settings.ACTIONS:
		var name := UI.label(Settings.LABELS[action])
		name.custom_minimum_size = Vector2(160, 0)
		_keys.add_child(name)
		for slot in SLOTS:
			var list: Array = settings.bindings[action]
			var waiting: bool = _waiting.get("action") == action and _waiting.get("slot") == slot
			var text := "Premi un tasto..." if waiting else (Settings.key_label(list[slot]) if slot < list.size() else "—")
			var b := UI.button(text, func():
				_waiting = {"action": action, "slot": slot}
				_draw_keys())
			b.custom_minimum_size = Vector2(160, 0)
			b.focus_mode = Control.FOCUS_NONE # così spazio e invio diventano tasti da assegnare
			if waiting:
				b.add_theme_color_override("font_color", UI.ACCENT)
			_keys.add_child(b)


# I tasti premuti mentre il menu è aperto servono solo qui
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if _waiting.is_empty():
		if key.keycode == KEY_ESCAPE:
			close()
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if key.keycode != KEY_ESCAPE:
		settings.assign(_waiting.action, _waiting.slot, 0 if key.keycode in [KEY_DELETE, KEY_BACKSPACE] else code)
	_waiting = {}
	_draw_keys()
