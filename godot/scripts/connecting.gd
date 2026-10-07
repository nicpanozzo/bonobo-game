# Schermata "Mi collego..." (E14 passo 2): al posto della riga dell'HUD mentre si entra in una stanza,
# quando il server non risponde e durante la riconnessione (E5). Annulla, Esc o B tornano alla lobby.
extends Control

signal cancelled

var _title := UI.header("")
var _detail := UI.label("", UI.SIZE_BODY, Color(UI.TEXT, 0.8))
var _cancel: Button


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(520)
	add_child(parts[0])
	var box: VBoxContainer = parts[1]
	box.add_child(_title)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail)
	var actions := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_cancel = UI.button("Annulla", func(): cancelled.emit())
	actions.add_child(_cancel)
	box.add_child(actions)
	UI.keep_focus(self, _cancel)


# title: cosa succede ("Mi collego..."); detail: dove e cosa si sta aspettando
func show_text(title: String, detail := "") -> void:
	_title.text = title
	_detail.text = detail
	_detail.visible = detail != ""


# Esc o B prima del menu di pausa di main.gd (che ascolta in _unhandled_key_input)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		cancelled.emit()
