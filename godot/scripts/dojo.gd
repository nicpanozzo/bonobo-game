# Dojo: il tutorial delle mosse di un personaggio. A sinistra l'elenco (combo e mosse coi loro tasti); scelta una voce
# parte la dimostrazione: il server fa rifare al proprio lottatore i tasti registrati dal laboratorio delle combo
# (src/shared/dojo.ts) e qui si vedono accendersi, tick per tick, insieme ai colpi della combo che entrano.
# Poi tocca a chi gioca, sullo stesso manichino alla stessa percentuale. Il client non decide niente: chiede la prova al
# server (messaggio "training" con dojo) e capisce cosa è entrato dagli eventi della fisica.
extends Control

signal command(data: Dictionary) # da mandare al server così com'è (messaggio "training")
signal demo_changed(playing: bool) # durante la dimostrazione la predizione si spegne: i tasti non sono i propri
signal lesson_done # una prova riuscita: main ci suona sopra

const MoveList := preload("res://scripts/move_list.gd")
# I tasti della dimostrazione, un bit ciascuno: lo stesso ordine di DEMO_KEYS in src/shared/dojo.ts
const DEMO_KEYS := ["left", "right", "up", "down", "jump", "light", "heavy", "special", "shield", "run"]
const PANEL_WIDTH := 400.0 # pixel
const COMBO_DROP_MS := 1500 # ms senza il colpo dopo: la combo è caduta e si riparte dal primo
const SLOW := 0.5 # velocità del rallentatore (una di TRAINING.speeds)
const AFTER_DEMO_MS := 700 # ms dopo la fine della dimostrazione prima che tocchi a chi gioca
# Le mosse comuni a tutti, nell'ordine dei picchiaduro: [nome, mossa del laboratorio, a cosa serve]
const MOVES := [
	["Leggero", "light", "veloce, apre le combo"],
	["Leggero in su", "lightUp", "sopra la testa"],
	["Leggero in giù", "lightDown", "sgambetto basso"],
	["Leggero in aria", "lightAir", "salta e colpisci"],
	["Pesante", "heavy", "più lento e più forte; tenuto si carica"],
	["Pesante in su", "heavyUp", "lancia in verticale"],
	["Pesante in giù", "heavyDown", "spazzata radente"],
	["Pesante in aria", "heavyAir", "il colpo forte in aria"],
	["Attacco in corsa", "dashAttack", "il pesante mentre corri"],
	["Recupero", "recovery", "in aria, per tornare sul palco"],
	["Lancio in avanti", "throwForward", "presa (scudo + leggero), poi avanti"],
	["Lancio in su", "throwUp", "presa, poi su"],
]
const SPECIAL_SLOTS := [["neutral", "specialNeutral"], ["side", "specialSide"], ["down", "specialDown"]]

var game: Dictionary
var settings: Settings
var my_id := ""
var lessons: Array = [] # {name, keys, hint, moves, pick, demo}
var current := -1
var speed := 1.0 # velocità dell'orologio dell'allenamento: la dimostrazione va con lei

var _mode := "" # "demo" mentre il server rifà i tasti, "try" quando tocca a chi gioca
var _progress := 0 # colpi della combo entrati di fila
var _last_hit_ms := 0
var _successes := 0
var _demo_keys: Array = []
var _demo_t0 := 0 # ms in cui è partita la dimostrazione
var _demo_end_ms := -1
var _keys: Dictionary = {} # azione -> nome del tasto
var _panel: PanelContainer
var _list: VBoxContainer
var _buttons: Array[Button] = [] # un pulsante per voce, nello stesso ordine di lessons
var _card: PanelContainer
var _title: Label
var _steps: HBoxContainer
var _status: Label
var _live: HBoxContainer
var _help: Label


# L'elenco delle prove di un personaggio: prima le sue combo, poi le speciali e le mosse di tutti.
# keys: azione -> nome del tasto. Pura: la usano i test
static func lessons_for(game_data: Dictionary, character_id: String, keys: Dictionary) -> Array:
	var c: Dictionary = game_data.characters.get(character_id, {})
	var out := []
	var combos: Array = c.get("combos", []) if c.get("combos") is Array else []
	for i in combos.size():
		var cs: Dictionary = combos[i]
		var steps: Array = cs.get("steps", [])
		out.append({"section": "Combo", "name": str(cs.get("name", "Combo")), "keys": MoveList.combo_keys(steps, keys), "hint": str(cs.get("text", "colpo dopo colpo, appena il primo entra")), "moves": steps.map(func(s): return str(s.move)), "pick": {"combo": i}, "demo": true})
	var sp: Dictionary = c.get("specials", {})
	for slot in SPECIAL_SLOTS:
		var s: Dictionary = sp.get(slot[0], {})
		if s.is_empty():
			continue
		var counter := str(s.get("type", "")) == "counter" # il contrattacco si vede solo quando arriva un colpo
		out.append({"section": "Speciali", "name": str(s.get("name", "Speciale")), "keys": MoveList.move_keys(slot[1], keys), "hint": MoveList.SPECIAL_HINTS.get(str(s.get("type", "")), "mossa speciale"), "moves": [slot[1]], "pick": {"move": slot[1]}, "demo": not counter})
	for m in MOVES:
		out.append({"section": "Mosse", "name": m[0], "keys": MoveList.move_keys(m[1], keys), "hint": m[2], "moves": [m[1]], "pick": {"move": m[1]}, "demo": true})
	return out


# I tasti accesi di un tick della dimostrazione
static func mask_actions(mask: int) -> Array:
	var out := []
	for i in DEMO_KEYS.size():
		if mask & (1 << i):
			out.append(DEMO_KEYS[i])
	return out


func setup(game_data: Dictionary, s: Settings, character_id: String) -> void:
	game = game_data
	settings = s
	var pad := not Input.get_connected_joypads().is_empty()
	_keys = MoveList.touch_keys() if DisplayServer.is_touchscreen_available() and not pad else MoveList.keys_for(s, pad)
	lessons = lessons_for(game, character_id, _keys)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_list(str(game.characters.get(character_id, {}).get("name", "")))
	_build_card()
	open_list()


func _build_list(char_name: String) -> void:
	_panel = PanelContainer.new()
	# Colonna a sinistra, sotto la riga della stanza: il manichino resta in vista a destra
	_panel.offset_left = 16
	_panel.offset_right = 16 + PANEL_WIDTH
	_panel.offset_top = 56
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -150
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.GAP_S)
	_panel.add_child(box)
	box.add_child(UI.header("Dojo"))
	var sub := UI.note("Le mosse di %s: scegline una, guarda come si fa e poi tocca a te." % char_name)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.custom_minimum_size.x = PANEL_WIDTH - 48
	box.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UI.GAP_S)
	scroll.add_child(_list)
	var section := ""
	for i in lessons.size():
		var l: Dictionary = lessons[i]
		if l.section != section:
			section = l.section
			_list.add_child(_section(section))
		var b := UI.button("%s   %s" % [l.name, l.keys], pick.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = l.hint
		_list.add_child(b)
		_buttons.append(b)
	# Al rallentatore la dimostrazione si segue meglio, e anche provare è più facile
	box.add_child(UI.toggle("Al rallentatore", false, func(on: bool): command.emit({"speed": SLOW if on else 1.0})))
	var close := UI.button("Chiudi l'elenco (P)", close_list)
	box.add_child(close)


# Il riquadro in alto: la voce scelta coi suoi colpi, cosa succede e i tasti premuti in questo momento
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.offset_left = -560 - 16
	_card.offset_right = -16
	_card.offset_top = 56
	_card.hide()
	add_child(_card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", UI.GAP_S)
	_card.add_child(box)
	_title = UI.header("")
	box.add_child(_title)
	_steps = HBoxContainer.new()
	_steps.add_theme_constant_override("separation", UI.GAP_S)
	box.add_child(_steps)
	_status = UI.label("", UI.SIZE_BODY, UI.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)
	_live = HBoxContainer.new()
	_live.add_theme_constant_override("separation", 4)
	box.add_child(_live)
	for action in DEMO_KEYS:
		var k := _keycap(str(_keys.get(action, action)), false)
		k.name = action
		k.tooltip_text = Settings.LABELS.get(action, action)
		_live.add_child(k)
	_help = UI.note("R riprova · G guarda di nuovo · P elenco")
	box.add_child(_help)


func is_open() -> bool:
	return _panel.visible


func open_list() -> void:
	_panel.show()
	if not _buttons.is_empty():
		_buttons[maxi(current, 0)].grab_focus()


func close_list() -> void:
	_panel.hide()
	if get_viewport() and get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus() # i tasti tornano al lottatore


func toggle() -> void:
	if is_open():
		close_list()
	else:
		open_list()


# Scelta una voce: si guarda subito la dimostrazione (se c'è), poi tocca a chi gioca
func pick(i: int) -> void:
	current = i
	_successes = 0
	close_list()
	var l: Dictionary = lessons[i]
	_title.text = l.name
	for c in _steps.get_children():
		c.queue_free()
	for m in l.moves:
		_steps.add_child(_keycap(MoveList.move_keys(m, _keys), false))
	_card.show()
	if l.demo:
		watch()
	else:
		try_it()


func watch() -> void:
	if current < 0:
		return
	_set_status("Guarda come si fa…")
	command.emit({"dojo": lessons[current].pick.merged({"play": true})})


func try_it() -> void:
	if current < 0:
		return
	_end_demo()
	_mode = "try"
	_progress = 0
	_paint_steps()
	_set_status("Tocca a te!")
	if lessons[current].demo:
		command.emit({"dojo": lessons[current].pick.merged({"play": false})})


func on_event(e: Dictionary, me: String) -> void:
	my_id = me
	if current < 0:
		return
	match str(e.get("type", "")):
		"dojo":
			if str(e.get("id", "")) != my_id:
				return
			_progress = 0
			_paint_steps()
			if e.has("keys"):
				_mode = "demo"
				_demo_keys = e.keys
				_demo_t0 = Time.get_ticks_msec()
				_demo_end_ms = -1
				_set_status("Guarda come si fa… (manichino al %d%%)" % int(e.get("percent", 0)))
				demo_changed.emit(true)
			else:
				_mode = "try"
				_set_status("Tocca a te! (manichino al %d%%)" % int(e.get("percent", 0)) if lessons[current].moves.size() > 1 else "Tocca a te!")
		"hit":
			if str(e.get("attackerId", "")) == my_id:
				_landed(str(e.get("kind", "")), true)
		"attack":
			# Una mossa sola vale anche a vuoto (il leggero in su sopra un manichino fermo non tocca niente)
			if str(e.get("id", "")) == my_id and lessons[current].moves.size() == 1:
				_landed(str(e.get("kind", "")), false)


# Un colpo entrato (o una mossa fatta): la combo va avanti, ricomincia o è finita
func _landed(kind: String, hit: bool) -> void:
	var moves: Array = lessons[current].moves
	if _progress >= moves.size():
		_progress = 0
	if kind == moves[_progress]:
		_progress += 1
	elif hit:
		_progress = 1 if kind == moves[0] else 0
	_last_hit_ms = Time.get_ticks_msec()
	_paint_steps()
	if _progress < moves.size():
		return
	if _mode == "demo":
		_set_status("Ecco fatto!")
		return
	_successes += 1
	_set_status("Fatto! ×%d   (R per rifarla da capo)" % _successes)
	lesson_done.emit()


func _process(_delta: float) -> void:
	if current < 0:
		return
	var now := Time.get_ticks_msec()
	# Combo caduta: il colpo dopo non è arrivato in tempo
	var moves: Array = lessons[current].moves
	if _mode == "try" and _progress > 0 and _progress < moves.size() and now - _last_hit_ms > COMBO_DROP_MS:
		_progress = 0
		_paint_steps()
		_set_status("Si è liberato: riprova (R)")
	_paint_live(now)


# I tasti accesi: quelli della dimostrazione al tick in corso, altrimenti quelli che si stanno premendo
func _paint_live(now: int) -> void:
	var on := []
	if _mode == "demo":
		var tick_ms := 1000.0 / float(game.get("tickRate", 60))
		var i := int((now - _demo_t0) * speed / tick_ms)
		if i < _demo_keys.size():
			on = mask_actions(int(_demo_keys[i]))
		elif _demo_end_ms < 0:
			_demo_end_ms = now
		elif now - _demo_end_ms > AFTER_DEMO_MS:
			try_it()
	elif settings != null and not is_open():
		for action in DEMO_KEYS:
			if settings.is_pressed(action) or (action == "jump" and settings.jump_pressed()):
				on.append(action)
	for k: Label in _live.get_children():
		_light(k, String(k.name) in on)


func _end_demo() -> void:
	if _mode == "demo":
		_mode = ""
		demo_changed.emit(false)


func is_demo() -> bool:
	return _mode == "demo"


func _paint_steps() -> void:
	var i := 0
	for k: Label in _steps.get_children():
		if not k.is_queued_for_deletion():
			_light(k, i < _progress)
			i += 1


func _set_status(text: String) -> void:
	_status.text = text


func _section(text: String) -> Label:
	var l := UI.label(text.to_upper(), UI.SIZE_SMALL, UI.INK)
	l.add_theme_font_override("font", UI.display())
	var plate := UI.button_box(UI.BANANA, false, 4)
	plate.content_margin_top = 1
	plate.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", plate)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


# Un tasto disegnato, come nella lista delle mosse; acceso diventa giallo pieno
func _keycap(text: String, on: bool) -> Label:
	var l := UI.label(text, UI.SIZE_SMALL, UI.BANANA)
	l.add_theme_font_override("font", UI.font(UI.WEIGHT_BLACK))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(34, 0)
	_light(l, on)
	return l


func _light(l: Label, on: bool) -> void:
	var cap := StyleBoxFlat.new()
	cap.bg_color = UI.BANANA if on else UI.FIELD
	cap.border_color = UI.INK if on else UI.BORDER
	cap.set_border_width_all(2)
	cap.border_width_bottom = 2 if on else 4 # premuto: il tasto si abbassa
	cap.set_corner_radius_all(5)
	cap.content_margin_left = 7
	cap.content_margin_right = 7
	cap.content_margin_top = 2 if on else 1
	cap.content_margin_bottom = 1 if on else 2
	l.add_theme_stylebox_override("normal", cap)
	l.add_theme_color_override("font_color", UI.INK if on else UI.BANANA)


# P (o R3 sul pad) apre e chiude l'elenco; R (L3 sul pad) riprova; G guarda di nuovo; Esc con l'elenco aperto lo chiude
func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var code := key.physical_keycode if key != null and key.pressed else KEY_NONE
	var list := code == KEY_P or (pad != null and pad.pressed and pad.button_index == JOY_BUTTON_RIGHT_STICK)
	if list or (is_open() and current >= 0 and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle()
	elif not is_open() and (code == KEY_R or (pad != null and pad.pressed and pad.button_index == JOY_BUTTON_LEFT_STICK)):
		get_viewport().set_input_as_handled()
		try_it()
	elif not is_open() and code == KEY_G and current >= 0 and lessons[current].demo:
		get_viewport().set_input_as_handled()
		watch()
