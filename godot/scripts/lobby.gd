# Lobby minima: nome, stanza, arena e indirizzo del server. Le regole restano quelle di default.
extends CenterContainer

signal join_requested(choice: Dictionary)

var _name := LineEdit.new()
var _room := LineEdit.new()
var _server := LineEdit.new()
var _stage := OptionButton.new()
var _stage_ids: Array = []


func setup(game: Dictionary, params: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Bonobo Game · prototipo Godot"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_name.placeholder_text = "Il tuo nome"
	_name.text = params.get("name", "")
	_name.max_length = 16
	_add_row(box, "Nome", _name)

	_room.placeholder_text = "Nome della stanza"
	_room.text = params.get("room", "amici")
	_add_row(box, "Stanza", _room)

	for id in game.stages:
		_stage_ids.append(id)
		_stage.add_item(game.stages[id].name)
	_stage.select(maxi(0, _stage_ids.find(params.get("stage", game.defaultStageId))))
	_add_row(box, "Arena", _stage)

	_server.text = params.server
	_add_row(box, "Server", _server)

	var hint := Label.new()
	hint.text = "A/D o frecce per muoversi, W/spazio per saltare, J e K per colpire"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	box.add_child(hint)

	var go := Button.new()
	go.text = "Entra"
	go.pressed.connect(_submit)
	box.add_child(go)
	_name.text_submitted.connect(func(_t): _submit())
	_room.text_submitted.connect(func(_t): _submit())


func _add_row(box: VBoxContainer, label: String, field: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	box.add_child(row)


func _submit() -> void:
	var name := _name.text.strip_edges()
	if name == "":
		_name.grab_focus()
		return
	get_viewport().gui_release_focus() # così i tasti tornano alla partita
	join_requested.emit({
		"name": name,
		"room": _room.text.strip_edges().to_lower(),
		"stage": _stage_ids[_stage.selected],
		"server": _server.text.strip_edges(),
	})
