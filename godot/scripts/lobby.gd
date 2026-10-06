# Schermata iniziale (come src/client/LobbyScene.ts): nome, stanza, lottatore, arena, regole
# e link da mandare agli amici. In più c'è l'indirizzo del server, perché il client Godot
# può stare su un sito diverso da quello del server.
extends Control

signal join_requested(choice: Dictionary)
signal options_requested

const MAX_SEED := 999999 # come stageGenerator.ts: "casuale-<seme>" e "corsa-<seme>"
const MODES := [["ffa", "Tutti contro tutti"], ["teams", "Squadre"], ["flag", "Bandiera (a squadre)"], ["race", "Corsa (platformer)"]]
const TIMES := [[0, "Senza tempo"], [120, "2 minuti"], [180, "3 minuti"], [300, "5 minuti"]]

var game: Dictionary
var room_link: Callable # stanza -> link da mandare agli amici

var _name := LineEdit.new()
var _room := LineEdit.new()
var _server := LineEdit.new()
var _msg: Label
var _chars := HBoxContainer.new()
var _stages := HFlowContainer.new()
var _stage_label: Control
var _course_note: Label
var _mode := OptionButton.new()
var _stocks := OptionButton.new()
var _time := OptionButton.new()
var _ff := CheckBox.new()
var _character := ""
var _stage := ""
var _random_stage := ""
var _server_len := 0 # per riconoscere un link incollato nel campo del server


func setup(game_data: Dictionary, params: Dictionary, link: Callable) -> void:
	game = game_data
	room_link = link
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0d1520")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var title := UI.label("BONOBO GAME", 34, UI.ACCENT)
	title.add_theme_color_override("font_shadow_color", Color("7a3b00"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)
	box.add_child(UI.label("Il picchiaduro del nostro Discord", 16, Color(UI.TEXT, 0.7)))

	box.add_child(UI.heading("Nome"))
	_name.max_length = 16
	_name.text = params.get("name", "")
	_name.text_submitted.connect(func(_t): _submit())
	box.add_child(_name)

	box.add_child(UI.heading("Stanza"))
	var row := HBoxContainer.new()
	_room.max_length = 24
	_room.text = params.get("room", _random_room())
	_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room.text_submitted.connect(func(_t): _submit())
	row.add_child(_room)
	row.add_child(UI.button("Nuova", func(): _room.text = _random_room()))
	row.add_child(UI.button("Copia link", func():
		UI.copy(room_link.call(_clean_room()))
		_msg.text = "Link copiato: incollalo sul Discord"
		_msg.show()))
	box.add_child(row)
	_msg = UI.label("", 13, Color("8fd18f"))
	_msg.hide() # compare solo dopo "Copia link"
	box.add_child(_msg)

	box.add_child(UI.heading("Lottatore"))
	_chars.add_theme_constant_override("separation", 10)
	box.add_child(_chars)
	_character = params.get("char", game.defaultCharacterId)
	if not game.characters.has(_character):
		_character = game.defaultCharacterId
	_draw_chars()

	_stage_label = UI.heading("Arena (la sceglie chi crea la stanza)")
	box.add_child(_stage_label)
	_stages.add_theme_constant_override("h_separation", 10)
	box.add_child(_stages)
	_stage = params.get("stage", game.defaultStageId)
	_random_stage = _stage if _stage.begins_with("casuale-") else _new_id("casuale-")
	if not game.stages.has(_stage) and not _stage.begins_with("casuale-"):
		_stage = game.defaultStageId # i percorsi della Corsa non sono arene da scegliere
	_draw_stages()
	_course_note = UI.label("In Corsa si gioca su un percorso lungo, nuovo a ogni stanza: vince chi arriva prima al traguardo.", 14, Color(UI.TEXT, 0.7))
	_course_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_course_note)

	box.add_child(UI.heading("Regole (anche queste le sceglie chi crea la stanza)"))
	var rules := HBoxContainer.new()
	rules.add_theme_constant_override("separation", 8)
	var saved: Dictionary = params.get("rules", {}) if params.get("rules") is Dictionary else {}
	for m in MODES:
		_mode.add_item(m[1])
	_mode.select(maxi(0, MODES.map(func(m): return m[0]).find(saved.get("mode", "ffa"))))
	for n in range(1, 6):
		_stocks.add_item(str(n))
	_stocks.select(clampi(int(saved.get("stocks", 3)) - 1, 0, 4))
	for t in TIMES:
		_time.add_item(t[1])
	_time.select(maxi(0, TIMES.map(func(t): return t[0]).find(int(saved.get("timeLimitSec", 0)))))
	_ff.text = "Fuoco amico"
	_ff.button_pressed = bool(saved.get("friendlyFire", false))
	for c in [_mode, _stocks, _time, _ff]:
		rules.add_child(c)
	box.add_child(rules)
	_mode.item_selected.connect(func(_i): _sync_rules())
	_sync_rules()

	box.add_child(UI.heading("Server"))
	_server.text = params.server
	_server.placeholder_text = "https://... (o incolla qui il link della serata)"
	_server_len = _server.text.length()
	_server.text_changed.connect(_on_server_text)
	box.add_child(_server)

	var play := UI.button("Gioca", _submit, true)
	box.add_child(play)
	var foot := HBoxContainer.new()
	foot.add_child(UI.label("Mandate a tutti lo stesso link per giocare insieme", 13, Color(UI.TEXT, 0.7)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(UI.button("Opzioni", func(): options_requested.emit()))
	box.add_child(foot)
	if _name.text == "":
		_name.call_deferred("grab_focus")


# Il fuoco amico ha senso solo a squadre; in Bandiera le vite diventano i punti per vincere;
# in Corsa le vite non contano e l'arena è un percorso generato
func _sync_rules() -> void:
	var mode: String = MODES[_mode.selected][0]
	_ff.visible = mode == "teams" or mode == "flag"
	var race := mode == "race"
	_stocks.visible = not race
	_stage_label.visible = not race
	_stages.visible = not race
	_course_note.visible = race
	for i in 5:
		var n := i + 1
		var word := ("punto" if n == 1 else "punti") if mode == "flag" else ("vita" if n == 1 else "vite")
		_stocks.set_item_text(i, "%d %s" % [n, word])


func _draw_chars() -> void:
	for c in _chars.get_children():
		c.queue_free()
	for id in game.characters:
		var c: Dictionary = game.characters[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 98)
		UI.set_selected(b, id == _character)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(v)
		if c.get("sprite") != null:
			# Primo fotogramma dello spritesheet, ridotto per stare nel riquadro
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://data/" + c.sprite.path)
			atlas.region = Rect2(0, 0, c.sprite.frameWidth, c.sprite.frameHeight)
			var pic := TextureRect.new()
			pic.texture = atlas
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(56, 62)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(pic)
		else:
			var boxc := CenterContainer.new()
			boxc.custom_minimum_size = Vector2(56, 62)
			boxc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var r := ColorRect.new()
			r.color = UI.PRIMARY
			r.custom_minimum_size = Vector2(26, 52)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boxc.add_child(r)
			v.add_child(boxc)
		var l := UI.label(c.name, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		b.pressed.connect(func():
			_character = id
			_draw_chars())
		_chars.add_child(b)


# Le arene di stages.ts più una generata a caso: cliccandola di nuovo se ne genera un'altra
func _draw_stages() -> void:
	for c in _stages.get_children():
		c.queue_free()
	for id in game.stages:
		_stages.add_child(_stage_card(id, game.stages[id].name, game.stages[id]))
	_stages.add_child(_stage_card(_random_stage, "Casuale", {}))


func _stage_card(id: String, text: String, spec: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(132, 90)
	UI.set_selected(b, id == _stage)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(v)
	var preview := preload("res://scripts/stage_preview.gd").new()
	preview.spec = spec
	preview.custom_minimum_size = Vector2(116, 56)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(preview)
	var l := UI.label(text, 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.pressed.connect(func():
		if id == _random_stage and _stage == _random_stage:
			_random_stage = _new_id("casuale-")
		_stage = _random_stage if id.begins_with("casuale-") else id
		_draw_stages())
	return b


func _submit() -> void:
	_apply_link(_server.text) # anche un link scritto a mano
	var mode: String = MODES[_mode.selected][0]
	get_viewport().gui_release_focus() # così i tasti tornano alla partita
	join_requested.emit({
		"name": _name.text.strip_edges().left(16) if _name.text.strip_edges() != "" else "Bonobo",
		"room": _clean_room() if _clean_room() != "" else _random_room(),
		"char": _character,
		"stage": _new_id("corsa-") if mode == "race" else _stage,
		"rules": {"mode": mode, "stocks": _stocks.selected + 1, "timeLimitSec": TIMES[_time.selected][0], "friendlyFire": _ff.button_pressed},
		"server": _server.text.strip_edges(),
	})


# Nell'app da scaricare si incolla il link mandato sul Discord (".../godot/?room=amici&server=...")
# e si prendono server e stanza da lì. Solo se il testo arriva tutto insieme, cioè incollato
func _on_server_text(text: String) -> void:
	var pasted := text.length() - _server_len > 1
	_server_len = text.length()
	if pasted:
		_apply_link(text)


func _apply_link(text: String) -> void:
	var found := parse_link(text)
	if found.has("room"):
		_room.text = found.room
	if found.has("server"):
		_server.text = found.server
		_server_len = _server.text.length()
		_server.caret_column = _server_len


static func parse_link(text: String) -> Dictionary:
	var found := {}
	var at := text.find("?")
	if at < 0:
		return found
	for pair in text.substr(at + 1).strip_edges().split("&", false):
		var kv := pair.split("=", true, 1)
		if kv.size() == 2 and kv[1] != "" and kv[0] in ["room", "server"]:
			found[kv[0]] = kv[1].uri_decode()
	return found


func _clean_room() -> String:
	var out := ""
	for ch in _room.text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-":
			out += ch
	return out.left(24)


static func _random_room() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var out := ""
	for i in 5:
		out += chars[randi() % chars.length()]
	return out


static func _new_id(prefix: String) -> String:
	return prefix + str(randi() % MAX_SEED)
