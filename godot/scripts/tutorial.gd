# Tutorial a tappe (E15, #113): un riquadro in alto con la tappa, i tasti del dispositivo in uso
# e "Fatto!" quando arriva l'evento giusto fatto da chi gioca. Le tappe sono dati di src/shared/tutorial.ts
# (game.json → tutorial.lessons); si avanza solo con gli eventi della fisica, mai con un tasto.
extends Control

signal lesson_done(index: int) # main.gd ci suona sopra
signal finished

const DONE_MS := 1200 # ms in cui resta scritto "Fatto!" prima della tappa dopo

var settings: Settings
var lessons: Array = []
var index := 0
var _done_at := -1 # ms in cui la tappa corrente è stata fatta, -1 se non ancora
var _pad := false # tasti del pad invece che della tastiera
var _pad_kind := "xbox"
var _step: Label
var _title: Label
var _text: Label
var _keys: Label


# La tappa è fatta da questo evento? Come lessonDone() in src/shared/tutorial.ts
static func done(lesson: Dictionary, e: Dictionary, my_id: String) -> bool:
	if e.get("type") != lesson.event or str(e.get(lesson.who, "")) != my_id:
		return false
	var want: Dictionary = lesson.get("match", {})
	for k in want:
		if e.get(k) != want[k]:
			return false
	return true


func setup(s: Settings, game: Dictionary) -> void:
	settings = s
	lessons = game.get("tutorial", {}).get("lessons", [])
	_pad = not Input.get_connected_joypads().is_empty()
	if _pad:
		_pad_kind = Settings.pad_kind(Input.get_joy_name(Input.get_connected_joypads()[0]))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 56)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	panel.add_child(box)
	_step = UI.note("")
	_title = UI.header("")
	_text = UI.label("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_keys = UI.label("", UI.SIZE_BODY, UI.ACCENT)
	for l in [_step, _title, _text, _keys]:
		box.add_child(l)
	_show()


func on_event(e: Dictionary, my_id: String) -> void:
	if index >= lessons.size() or _done_at >= 0:
		return
	if done(lessons[index], e, my_id):
		_done_at = Time.get_ticks_msec()
		_title.text = "Fatto!"
		lesson_done.emit(index)


func _process(_delta: float) -> void:
	if _done_at >= 0 and Time.get_ticks_msec() - _done_at >= DONE_MS:
		_done_at = -1
		index += 1
		_show()
		if index >= lessons.size():
			finished.emit()


# L'ultimo dispositivo toccato decide i tasti mostrati
func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	if (pad or event is InputEventKey) and pad != _pad:
		_pad = pad
		if pad:
			_pad_kind = Settings.pad_kind(Input.get_joy_name(event.device))
		_show()


func _show() -> void:
	if index >= lessons.size():
		_step.text = ""
		_title.text = "Tutorial finito!"
		_text.text = "Adesso sai tutto: resta ad allenarti o esci dal menu (Esc o Start)."
		_keys.text = ""
		return
	var l: Dictionary = lessons[index]
	_step.text = "Tappa %d di %d" % [index + 1, lessons.size()]
	_title.text = l.title
	_text.text = l.text
	_keys.text = keys_text(l.actions)


# "Salto: W · Attacco leggero: J" con i tasti salvati nelle opzioni (E6)
func keys_text(actions: Array) -> String:
	var parts := PackedStringArray()
	for a in actions:
		var codes: Array = (settings.pad_bindings if _pad else settings.bindings).get(a, []).slice(0, 1)
		var names: Array = codes.map(func(c): return Settings.pad_label(c, _pad_kind) if _pad else Settings.key_label(c))
		parts.append("%s: %s" % [Settings.LABELS.get(a, a), names[0] if not names.is_empty() else "nessun tasto"])
	return " · ".join(parts)
