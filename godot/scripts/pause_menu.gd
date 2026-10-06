# Menu con Esc durante la partita (come src/client/PauseMenu.ts). La partita è online e non
# si ferma: il menu spegne solo i tasti di chi lo apre.
extends Control

signal resumed
signal left

var settings: Settings
var link := ""
var _note: Label
var _dim: Control
var _in_options := false


func setup(s: Settings, room_link: String) -> void:
	settings = s
	link = room_link
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(380)
	_dim = parts[0]
	add_child(_dim)
	var box: VBoxContainer = parts[1]
	box.add_child(UI.label("Menu", 28, UI.ACCENT))
	box.add_child(UI.button("Riprendi", resume, true))
	box.add_child(UI.button("Opzioni", _open_options))
	box.add_child(UI.button("Copia link della stanza", func():
		UI.copy(link)
		_note.text = "Link copiato: incollalo sul Discord"))
	box.add_child(UI.button("Esci alla lobby", func():
		queue_free()
		left.emit()))
	_note = UI.label("La partita continua mentre il menu è aperto.", 13, Color(UI.TEXT, 0.7))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_note)


func resume() -> void:
	queue_free()
	resumed.emit()


func _open_options() -> void:
	_in_options = true
	_dim.hide()
	var options := preload("res://scripts/options.gd").new()
	add_child(options)
	options.setup(settings)
	options.closed.connect(func():
		_in_options = false
		_dim.show())


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _in_options or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		resume()
