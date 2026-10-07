# Allenamento (E15, #113): conta combo sempre in vista e un pannello laterale, aperto con P (R3 sul pad),
# per la percentuale del bot, il rallentatore, le hitbox e Ricomincia. I comandi vanno al server
# (messaggio "training"), che li accetta solo in palestra e da soli: il client non cambia niente da sé.
extends Control

signal command(data: Dictionary) # da mandare al server così com'è
signal hitboxes_toggled(on: bool)

const PERCENT_STEP := 10.0 # di quanto si sposta il cursore della percentuale a ogni tocco
const PANEL_WIDTH := 320.0 # pixel

var game: Dictionary
var combo := Combo.new()
var _panel: PanelContainer
var _first: Control
var _combo_label: Label
var _percent_label: Label
var _speeds: Array = [1.0]


# Conta i colpi di fila su uno stesso bersaglio finché resta stordito.
# Lo stordimento si legge dallo snapshot (hitstun), i colpi dagli eventi: solo un numero per lo schermo.
class Combo:
	var hits := 0
	var damage := 0.0
	var target := ""
	var last_hits := 0 # l'ultima combo finita, che resta scritta finché non ne parte un'altra
	var last_damage := 0.0

	func on_event(e: Dictionary, my_id: String) -> void:
		if e.get("type") != "hit" or e.get("attackerId") != my_id:
			return
		if str(e.targetId) != target:
			_finish()
			target = str(e.targetId)
		hits += 1
		damage += float(e.get("damage", 0))

	func on_snapshot(snap: Dictionary) -> void:
		if target == "":
			return
		for p in snap.get("players", []):
			if p.id == target and p.hitstun:
				return
		_finish() # bersaglio non più stordito (o uscito): la combo è finita

	# "3 colpi · 27%": quella in corso, altrimenti l'ultima da almeno 2 colpi
	func text() -> String:
		if hits >= 2:
			return "%d colpi · %d%%" % [hits, roundi(damage)]
		if last_hits >= 2:
			return "Ultima combo: %d colpi · %d%%" % [last_hits, roundi(last_damage)]
		return ""

	func _finish() -> void:
		if hits >= 2:
			last_hits = hits
			last_damage = damage
		hits = 0
		damage = 0.0
		target = ""


func setup(game_data: Dictionary) -> void:
	game = game_data
	_speeds = game.get("training", {}).get("speeds", [1.0])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_combo_label = UI.label("", UI.SIZE_BIG, UI.ACCENT)
	_combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_combo_label.position = Vector2(24, 70)
	add_child(_combo_label)
	var hint := UI.note("P (o R3 sul pad): pannello dell'allenamento")
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hint.position = Vector2(24, 44)
	add_child(hint)

	_panel = PanelContainer.new()
	# Colonna a destra, sotto la riga della stanza e sopra le schede dei giocatori
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -PANEL_WIDTH - 16
	_panel.offset_right = -16
	_panel.offset_top = 56
	_panel.hide()
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.GAP_M)
	_panel.add_child(box)
	box.add_child(UI.header("Allenamento"))

	_percent_label = UI.label("Percentuale del bot: 0%")
	box.add_child(_percent_label)
	var max_percent: float = game.get("training", {}).get("maxPercent", 300)
	var slider := UI.slider(0.0, func(v: float):
		_percent_label.text = "Percentuale del bot: %d%%" % roundi(v)
		command.emit({"percent": v}), minf(max_percent, 300.0), PERCENT_STEP)
	box.add_child(slider)
	_first = slider

	box.add_child(UI.label("Velocità"))
	var speed := OptionButton.new()
	for s in _speeds:
		speed.add_item(speed_text(float(s)))
	speed.item_selected.connect(func(i: int): command.emit({"speed": float(_speeds[i])}))
	box.add_child(speed)

	box.add_child(UI.toggle("Mostra hitbox", false, func(on: bool): hitboxes_toggled.emit(on)))
	box.add_child(UI.button("Ricomincia", func(): command.emit({"reset": true})))
	box.add_child(UI.button("Chiudi", toggle))
	var note := UI.note("La partita resta in corso: col pannello aperto i tasti non muovono il lottatore.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD # senza, la riga lunga allarga il pannello fuori dallo schermo
	note.custom_minimum_size.x = PANEL_WIDTH - 48
	box.add_child(note)


# "Normale", "Rallentata ×0.5"...
static func speed_text(s: float) -> String:
	return "Normale" if is_equal_approx(s, 1.0) else "Rallentata ×%s" % str(s)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_first.grab_focus()
	elif get_viewport() and get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus() # i tasti tornano al lottatore


func on_event(e: Dictionary, my_id: String) -> void:
	combo.on_event(e, my_id)


func on_snapshot(snap: Dictionary) -> void:
	combo.on_snapshot(snap)
	_combo_label.text = combo.text()


# P, R3 sul pad (T e Select sono la provocazione) ed Esc col pannello aperto
func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var p_key := key != null and key.pressed and key.keycode == KEY_P
	var r3 := pad != null and pad.pressed and pad.button_index == JOY_BUTTON_RIGHT_STICK
	var back := is_open() and event.is_action_pressed("ui_cancel")
	if p_key or r3 or back:
		get_viewport().set_input_as_handled()
		toggle()
