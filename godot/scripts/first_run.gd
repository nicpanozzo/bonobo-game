# Primo avvio guidato (E14 passo 4): nome, comandi, poi una prova veloce contro il manichino.
# main.gd lo apre al posto della lobby finché in bonobo.cfg manca [first_run] done.
# "Salta" porta alla lobby; tutto si usa anche col pad (A conferma, B torna indietro).
extends Control

signal try_requested(player_name: String) # prova veloce: stanza nuova con il manichino
signal skipped(player_name: String)

const STEPS := 3
# Le azioni mostrate nello schema dei comandi, nell'ordine in cui servono la prima volta
const SHOWN := ["left", "right", "jump", "light", "heavy", "dodge"]

var settings: Settings
var _step := 0
var _pad := false # schema dei comandi del pad invece che della tastiera
var _box: VBoxContainer
var _page := VBoxContainer.new()
var _dots := UI.note("")
var _name := LineEdit.new()
var _next: Button


func setup(s: Settings) -> void:
	settings = s
	_pad = not Input.get_connected_joypads().is_empty()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var parts := UI.overlay(560)
	add_child(parts[0])
	_box = parts[1]
	var top := HBoxContainer.new()
	var title := UI.title("Benvenuto in Bonobo Game")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UI.small_button("Salta", _skip))
	_box.add_child(top)
	_page.add_theme_constant_override("separation", UI.GAP_M)
	_box.add_child(_page)
	var actions := HBoxContainer.new()
	actions.add_child(_dots)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_next = UI.button("Avanti", _forward, true)
	actions.add_child(_next)
	_box.add_child(actions)
	_name.placeholder_text = "Il tuo nome"
	_name.max_length = 16
	_name.text = str(settings.profile.get("name", ""))
	_name.text_submitted.connect(func(_t): _forward())
	UI.keep_focus(self, _next)
	_show_step(0)


func _show_step(step: int) -> void:
	_step = step
	if _name.get_parent() != null: # il campo del nome resta vivo tra un passo e l'altro
		_name.get_parent().remove_child(_name)
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	_dots.text = "Passo %d di %d" % [step + 1, STEPS]
	match step:
		0:
			_page.add_child(UI.label("Come ti chiami? Il nome si vede sopra il tuo lottatore."))
			var row := HBoxContainer.new()
			_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(_name)
			row.add_child(UI.button("Nome a caso", func(): _name.text = random_name()))
			_page.add_child(row)
			_next.text = "Avanti"
		1:
			var tabs := HBoxContainer.new()
			for pad in [false, true]:
				var b := UI.button("Pad" if pad else "Tastiera", func():
					_pad = pad
					_show_step(1))
				UI.set_selected(b, pad == _pad)
				tabs.add_child(b)
			_page.add_child(tabs)
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", UI.GAP_L * 3)
			for row in controls(settings, _pad, _pad_kind()):
				grid.add_child(UI.label(row[0]))
				grid.add_child(UI.label(row[1], UI.SIZE_BODY, UI.ACCENT))
			_page.add_child(grid)
			_page.add_child(UI.note("Si cambiano quando vuoi da Opzioni → Comandi."))
			_next.text = "Avanti"
		2:
			var hit: String = controls(settings, _pad, _pad_kind())[SHOWN.find("light")][1]
			var l := UI.label("Prova veloce: entri in una stanza tutta tua con un manichino. Avvicinati e colpiscilo con %s. Per tornare alla lobby premi Esc." % hit)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_page.add_child(l)
			_page.add_child(UI.note("Per giocare con gli amici, dalla lobby crei una stanza e mandi il link sul Discord."))
			_next.text = "Gioca"


func _exit_tree() -> void:
	if _name.get_parent() == null:
		_name.free() # fuori dalla scena non lo libera nessun altro


func _forward() -> void:
	if _step < STEPS - 1:
		_show_step(_step + 1)
		_next.grab_focus.call_deferred()
	else:
		try_requested.emit(_player_name())


func _skip() -> void:
	skipped.emit(_player_name())


func _player_name() -> String:
	var n := _name.text.strip_edges().left(16)
	return n if n != "" else random_name()


func _pad_kind() -> String:
	var pads := Input.get_connected_joypads()
	return Settings.pad_kind(Input.get_joy_name(pads[0])) if not pads.is_empty() else "xbox"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step > 0: # B o Esc: un passo indietro
		get_viewport().set_input_as_handled()
		_show_step(_step - 1)
		_next.grab_focus.call_deferred()


static func random_name() -> String:
	var names: Array = preload("res://scripts/lobby.gd").RANDOM_NAMES
	return "%s%d" % [names[randi() % names.size()], randi() % 100]


# [nome dell'azione, primo o primi due tasti] per lo schema dei comandi, dai tasti salvati (E6)
static func controls(s: Settings, pad: bool, kind := "xbox") -> Array:
	var out := []
	for a in SHOWN:
		var codes: Array = (s.pad_bindings if pad else s.bindings)[a].slice(0, 2)
		var names := codes.map(func(c): return Settings.pad_label(c, kind) if pad else Settings.key_label(c))
		out.append([Settings.LABELS[a], " o ".join(PackedStringArray(names)) if not names.is_empty() else "nessun tasto"])
	return out
