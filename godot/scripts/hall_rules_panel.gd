# La schermata del computer della sala d'attesa (#567): tutte le regole della prossima partita, come nella lobby,
# più il livello dei bot e le opzioni del gioco (volumi, tasti). La modalità e l'arena si votano sulle pedane.
# Chiunque nella sala le cambia: ogni modifica va al server (hallRules), che le ripulisce e le manda a tutti
# nello snapshot della sala; qui si mostrano quelle che arrivano. Gli oggetti sono quelli di game.json
# (droppableItems): un oggetto nuovo in src/shared/items.ts compare da solo.
extends Control

signal changed(rules: Dictionary, bot_level: String) # main.gd lo manda al server
signal closed

const LobbyScript := preload("res://scripts/lobby.gd")
const BOT_LEVELS := [["facile", "Facili"], ["semplice", "Normali"], ["difficile", "Difficili"]] # come BotLevel in src/server/bot.ts
const SEND_DELAY := 0.25 # s: le frecce premute di fila partono in un messaggio solo (il server ne accetta pochi al secondo)
const QUIET_AFTER_EDIT := 0.8 # s: dopo una modifica mia lo snapshot vecchio non rimette i valori di prima

var settings: Settings
var game: Dictionary
var _stocks := Stepper.new()
var _time := Stepper.new()
var _teams := Stepper.new()
var _ff := CheckButton.new()
var _supreme := Stepper.new()
var _amount := Stepper.new()
var _bots := Stepper.new()
var _checks := {} # id dell'oggetto -> CheckButton
var _dim: Control
var _note: Label
var _in_options := false
var _options_button: Button
var _filling := false # si scrivono i valori arrivati dal server: niente messaggi
var _send_in := -1.0 # s al prossimo invio, -1 = niente da mandare
var _quiet := 0.0
var _times: Array = LobbyScript.TIMES.duplicate() # [secondi, scritta]; un tempo arrivato dal server che non c'è si aggiunge


func setup(game_data: Dictionary, s: Settings, rules: Dictionary, bot_level: String) -> void:
	game = game_data
	settings = s
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(760)
	_dim = parts[0]
	add_child(_dim)
	var box: VBoxContainer = parts[1]
	box.add_child(UI.header("Regole della partita"))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	var col_a := VBoxContainer.new()
	var col_b := VBoxContainer.new()
	for col in [col_a, col_b]:
		col.add_theme_constant_override("separation", UI.GAP_S)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
	box.add_child(cols)
	for n in range(1, 6):
		_stocks.add_item("%d %s" % [n, "vita" if n == 1 else "vite"])
	col_a.add_child(_row("Vite", _stocks))
	for t in _times:
		_time.add_item(t[1])
	col_a.add_child(_row("Tempo", _time))
	for n in range(2, int(game.get("maxTeams", 2)) + 1):
		_teams.add_item("%d squadre" % n)
	col_a.add_child(_row("Squadre", _teams))
	for b in BOT_LEVELS:
		_bots.add_item(b[1])
	col_a.add_child(_row("Bot", _bots))
	_ff.text = "Fuoco amico"
	_ff.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col_a.add_child(_ff)
	for sp in game.get("supremeSpeeds", []):
		_supreme.add_item(str(sp.label))
	col_b.add_child(_row("Suprema", _supreme))
	for a in game.get("itemAmounts", []):
		_amount.add_item(str(a.label))
	col_b.add_child(_row("Oggetti", _amount))
	var kinds := HFlowContainer.new()
	kinds.add_theme_constant_override("h_separation", UI.GAP_M)
	kinds.add_theme_constant_override("v_separation", 0)
	var spec: Dictionary = game.get("items", {}) if game.get("items") is Dictionary else {}
	for k in game.get("droppableItems", []):
		var c := CheckButton.new()
		c.text = str(spec.get(k, {}).get("name", k))
		c.add_theme_font_size_override("font_size", Access.px(UI.SIZE_SMALL))
		c.toggled.connect(func(_on): _edited())
		_checks[str(k)] = c
		kinds.add_child(c)
	col_b.add_child(kinds)
	for st in [_stocks, _time, _teams, _bots, _supreme, _amount]:
		st.item_selected.connect(func(_i): _edited())
	_ff.toggled.connect(func(_on): _edited())
	_note = UI.note("Le cambia chiunque è nella sala e valgono dalla prossima partita. Modalità e arena si votano sulle pedane.")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_note)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UI.GAP_M)
	_options_button = UI.button("Opzioni del gioco", _open_options)
	actions.add_child(_options_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var done := UI.button("Fatto", close, true)
	actions.add_child(done)
	box.add_child(actions)
	sync(rules, bot_level, true)
	if get_viewport() != null: # nei test fuori dalla scena non c'è viewport (né pad da tenere sul menu)
		UI.keep_focus(self, _stocks.focus_target())


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP_M)
	var label := UI.heading(text)
	label.custom_minimum_size = Vector2(110, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(control)
	return row


# Le regole arrivate dal server (snapshot della sala): si mostrano, se non le sto cambiando proprio adesso
func sync(rules: Dictionary, bot_level: String, force := false) -> void:
	if not force and (_quiet > 0.0 or _send_in >= 0.0):
		return
	_filling = true
	_stocks.select(clampi(int(rules.get("stocks", 3)) - 1, 0, _stocks.item_count() - 1))
	var sec := int(rules.get("timeLimitSec", 0))
	if not _times.any(func(t): return t[0] == sec):
		# un tempo che la lobby non ha (stanze di prima, link a mano): si mostra com'è, così non si perde cambiando altro
		_times.append([sec, "%d:%02d" % [sec / 60, sec % 60]])
		_time.add_item(_times[-1][1])
	_time.select(maxi(0, _times.map(func(t): return t[0]).find(sec)))
	_teams.select(clampi(int(rules.get("teamCount", 2)) - 2, 0, maxi(0, _teams.item_count() - 1)))
	_bots.select(maxi(0, BOT_LEVELS.map(func(b): return b[0]).find(bot_level if bot_level != "" else "semplice")))
	_ff.set_pressed_no_signal(bool(rules.get("friendlyFire", false)))
	var speeds: Array = game.get("supremeSpeeds", [])
	_supreme.select(maxi(0, speeds.map(func(sp): return float(sp.mult)).find(float(rules.get("supremeSpeed", 1)))))
	_amount.select(clampi(int(rules.get("itemAmount", 2)), 0, maxi(0, _amount.item_count() - 1)))
	var kinds: Variant = rules.get("itemKinds")
	for k in _checks:
		_checks[k].set_pressed_no_signal(not (kinds is Array) or (kinds as Array).has(k))
	_sync_enabled()
	_filling = false


# Le regole come le vuole il server (MatchRules senza modalità)
func chosen_rules() -> Dictionary:
	var speeds: Array = game.get("supremeSpeeds", [])
	return {
		"stocks": _stocks.selected + 1,
		"timeLimitSec": _times[clampi(_time.selected, 0, _times.size() - 1)][0],
		"teamCount": _teams.selected + 2,
		"friendlyFire": _ff.button_pressed,
		"supremeSpeed": float(speeds[_supreme.selected].mult) if _supreme.selected >= 0 and _supreme.selected < speeds.size() else 1.0,
		"itemAmount": maxi(0, _amount.selected),
		"itemKinds": _checks.keys().filter(func(k): return _checks[k].button_pressed),
	}


func chosen_bot_level() -> String:
	return str(BOT_LEVELS[clampi(_bots.selected, 0, BOT_LEVELS.size() - 1)][0])


func _edited() -> void:
	_sync_enabled()
	if _filling:
		return
	_send_in = SEND_DELAY
	_quiet = QUIET_AFTER_EDIT


# Con "Nessuno" la scelta dei tipi di oggetto non serve
func _sync_enabled() -> void:
	for c in _checks.values():
		c.disabled = _amount.selected == 0


func _process(delta: float) -> void:
	_quiet = maxf(0.0, _quiet - delta)
	if _send_in >= 0.0:
		_send_in -= delta
		if _send_in < 0.0:
			_send_in = -1.0
			_quiet = QUIET_AFTER_EDIT
			changed.emit(chosen_rules(), chosen_bot_level())


func close() -> void:
	if _send_in >= 0.0: # l'ultima modifica parte anche chiudendo subito
		_send_in = -1.0
		changed.emit(chosen_rules(), chosen_bot_level())
	queue_free()
	closed.emit()


# Volumi, tasti, video: lo stesso menu della lobby e della pausa
func _open_options() -> void:
	_in_options = true
	_dim.hide()
	var options := preload("res://scripts/options.gd").new()
	add_child(options)
	options.setup(settings)
	options.closed.connect(func():
		_in_options = false
		_dim.show()
		_options_button.grab_focus())


# Esc, B o Start chiudono
func _input(event: InputEvent) -> void:
	if _in_options or event.is_echo():
		return
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if start or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
