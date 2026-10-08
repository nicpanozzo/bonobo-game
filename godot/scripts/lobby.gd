# Lobby (come src/client/LobbyScene.ts), in due parti (E14 passo 2): "Entra in una stanza" con il
# nome o il link che arriva dal Discord, e "Crea stanza" con arena, regole e bot. Nome e lottatore
# stanno sopra, perché servono a tutti e due. L'indirizzo del server è in "Avanzate": il link
# incollato lo porta già con sé.
extends Control

signal join_requested(choice: Dictionary)
signal options_requested
signal credits_requested
signal back_requested # Indietro, Esc o B: torna al titolo (E14)

const MAX_SEED := 999999 # come stageGenerator.ts: "casuale-<seme>" e "corsa-<seme>"
const MODES := [["ffa", "Tutti contro tutti"], ["teams", "Squadre"], ["flag", "Bandiera (a squadre)"], ["race", "Corsa (platformer)"], ["training", "Allenamento (col manichino)"]]
const TIMES := [[0, "Senza tempo"], [120, "2 minuti"], [180, "3 minuti"], [300, "5 minuti"]]
# Avversari del server per giocare da soli (#20, src/server/bot.ts)
# "Nome a caso" per chi usa il pad e non vuole scrivere
# TODO community: soprannomi e tormentoni del canale
const RANDOM_NAMES := ["Bonobo", "Scimmione", "Banana", "Liana", "Gorilla", "Babbuino", "Orango"]
const BOTS := [["", "Nessun bot"], ["manichino", "Manichino"], ["facile", "Bot facile"], ["semplice", "Bot"], ["difficile", "Bot difficile"]]
const STAT_BARS := [["speed", "Vel.", "Velocità"], ["jump", "Salto", "Salto"], ["weight", "Peso", "Peso"]] # barre sotto il ritratto (E11)
const BAR_W := 44.0 # larghezza delle barre, pixel
const QUICK_BOT := "semplice" # "Contro un bot" quando nelle regole non ne è scelto nessuno

var game: Dictionary
var room_link: Callable # stanza -> link da mandare agli amici

var _name := LineEdit.new()
var _room := LineEdit.new() # Entra: nome della stanza o link incollato
var _new_room := LineEdit.new() # Crea: la stanza nuova
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
var _bot := OptionButton.new()
var _character := ""
var _stage := ""
var _random_stage := ""
var _server_len := 0 # per riconoscere un link incollato nel campo del server
var _room_len := 0 # lo stesso per il campo della stanza
var _creating := false # quale delle due parti si vede
var _tabs := {} # false/true -> pulsante della scheda
var _pages := {} # false/true -> contenuto della scheda
var _enter: Button
var _create: Button
var _advanced: Control
var _advanced_button: Button
var _back_to: Control # dove torna il fuoco quando si chiudono opzioni o crediti


# start_join: si arriva da un link con la stanza, quindi si parte da "Entra in una stanza"
func setup(game_data: Dictionary, params: Dictionary, link: Callable, start_join := false) -> void:
	game = game_data
	room_link = link
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true # col pad la pagina scorre fino al controllo scelto
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", UI.GAP_S)
	panel.add_child(box)

	box.add_child(UI.title("BONOBO GAME"))

	box.add_child(UI.heading("Nome"))
	_name.max_length = 16
	_name.text = params.get("name", "")
	_name.text_submitted.connect(func(_t): _submit())
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.add_child(_name)
	name_row.add_child(UI.button("Nome a caso", func():
		_name.text = "%s%d" % [RANDOM_NAMES[randi() % RANDOM_NAMES.size()], randi() % 100]))
	box.add_child(name_row)

	box.add_child(UI.heading("Lottatore"))
	_chars.add_theme_constant_override("separation", UI.GAP_M)
	box.add_child(_chars)
	_character = params.get("char", game.defaultCharacterId)
	if not game.characters.has(_character):
		_character = game.defaultCharacterId
	_draw_chars()

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", UI.GAP_S)
	for creating in [false, true]:
		var b := UI.button("Crea stanza" if creating else "Entra in una stanza", func(): _show_tab(creating))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[creating] = b
		tabs.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UI.GAP_S)
	box.add_child(gap)
	box.add_child(tabs)

	# Entra in una stanza: basta il nome della stanza o il link mandato sul Discord
	var join := VBoxContainer.new()
	join.add_theme_constant_override("separation", UI.GAP_S)
	join.add_child(UI.heading("Stanza o link"))
	_room.text = params.get("room", "")
	_room.placeholder_text = "amici, oppure incolla il link della serata"
	_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_len = _room.text.length()
	_room.text_changed.connect(_on_room_text)
	_room.text_submitted.connect(func(_t): _submit())
	join.add_child(_room)
	join.add_child(UI.note("Chiedi il link a chi ha creato la stanza: lo stesso link porta tutti nella stessa partita."))
	_enter = UI.button("Entra", _submit, true)
	join.add_child(_enter)
	_pages[false] = join
	box.add_child(join)

	# Crea stanza: la stanza nuova, l'arena, le regole e i bot (contano solo per chi la crea)
	var create := VBoxContainer.new()
	create.add_theme_constant_override("separation", UI.GAP_S)
	create.add_child(UI.heading("Stanza nuova"))
	var row := HBoxContainer.new()
	_new_room.max_length = 24
	_new_room.text = _random_room()
	_new_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_room.text_submitted.connect(func(_t): _submit())
	row.add_child(_new_room)
	row.add_child(UI.button("Nuova", func(): _new_room.text = _random_room()))
	row.add_child(UI.button("Copia link", func():
		UI.copy(room_link.call(_clean_room(_new_room.text)))
		_msg.text = "Link copiato: incollalo sul Discord"
		_msg.show()))
	create.add_child(row)
	_msg = UI.label("", UI.SIZE_NOTE, UI.OK)
	_msg.hide() # compare solo dopo "Copia link"
	create.add_child(_msg)

	_stage_label = UI.heading("Arena")
	create.add_child(_stage_label)
	_stages.add_theme_constant_override("h_separation", UI.GAP_M)
	create.add_child(_stages)
	_stage = params.get("stage", game.defaultStageId)
	_random_stage = _stage if _stage.begins_with("casuale-") else _new_id("casuale-")
	if not game.stages.has(_stage) and not _stage.begins_with("casuale-"):
		_stage = game.defaultStageId # i percorsi della Corsa non sono arene da scegliere
	_draw_stages()
	_course_note = UI.label("In Corsa si gioca su un percorso lungo, nuovo a ogni stanza: vince chi arriva prima al traguardo.", UI.SIZE_SMALL, Color(UI.TEXT, 0.7))
	_course_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	create.add_child(_course_note)

	create.add_child(UI.heading("Regole"))
	var rules := HBoxContainer.new()
	rules.add_theme_constant_override("separation", UI.GAP_M)
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
	for b in BOTS:
		_bot.add_item(b[1])
	_bot.select(maxi(0, BOTS.map(func(x): return x[0]).find(str(params.get("bot", "")))))
	for c in [_mode, _stocks, _time, _ff, _bot]:
		rules.add_child(c)
	create.add_child(rules)
	_mode.item_selected.connect(func(_i): _sync_rules())
	_sync_rules()

	# Due modi di partire: con le regole scelte, o subito contro un bot (da soli, col pad in pochi tasti)
	var go := HBoxContainer.new()
	go.add_theme_constant_override("separation", UI.GAP_M)
	_create = UI.button("Crea e gioca", _submit, true)
	_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.add_child(_create)
	var quick := UI.button("Contro un bot", _quick_bot)
	quick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.add_theme_font_size_override("font_size", Access.px(UI.SIZE_BIG))
	go.add_child(quick)
	# A destra Godot sceglierebbe le regole qui sopra: col pad si passa dritto da un pulsante all'altro
	_create.focus_neighbor_right = _create.get_path_to(quick)
	quick.focus_neighbor_left = quick.get_path_to(_create)
	create.add_child(go)
	_pages[true] = create
	box.add_child(create)

	# Avanzate: l'indirizzo del server, chiuso finché non serve
	_advanced_button = UI.button("Avanzate ▸", func(): _set_advanced(not _advanced.visible))
	_advanced_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_advanced_button)
	var advanced := VBoxContainer.new()
	advanced.add_theme_constant_override("separation", UI.GAP_S)
	advanced.add_child(UI.heading("Server"))
	_server.text = params.server
	_server.placeholder_text = "https://... (o incolla qui il link della serata)"
	_server_len = _server.text.length()
	_server.text_changed.connect(_on_server_text)
	advanced.add_child(_server)
	_advanced = advanced
	box.add_child(advanced)
	_set_advanced(false)

	var foot := HBoxContainer.new()
	foot.add_child(UI.note(UI.version_text(game_data), 0.5))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(UI.button("Indietro", back_requested.emit))
	foot.add_child(UI.button("Crediti", func():
		_back_to = get_viewport().gui_get_focus_owner()
		credits_requested.emit()))
	foot.add_child(UI.button("Opzioni", func():
		_back_to = get_viewport().gui_get_focus_owner()
		options_requested.emit()))
	box.add_child(foot)
	_show_tab(not start_join, false)
	# Chi ha già un nome salvato (o usa il pad) parte dal pulsante per giocare; gli altri scrivono il nome
	(_name if _name.text == "" else _primary()).call_deferred("grab_focus")


func _show_tab(creating: bool, focus := true) -> void:
	_creating = creating
	for k in [false, true]:
		_pages[k].visible = k == creating
		UI.set_selected(_tabs[k], k == creating)
	if focus:
		_tabs[creating].grab_focus()


func _primary() -> Button:
	return _create if _creating else _enter


func _set_advanced(open: bool) -> void:
	_advanced.visible = open
	_advanced_button.text = "Avanzate ▾" if open else "Avanzate ▸"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


# Chiusi opzioni o crediti, il fuoco torna al pulsante che li ha aperti
func restore_focus() -> void:
	if is_instance_valid(_back_to):
		_back_to.grab_focus()


# Il fuoco amico ha senso solo a squadre; in Bandiera le vite diventano i punti per vincere;
# in Corsa le vite non contano e l'arena è un percorso generato; in Allenamento non ci sono né vite né tempo
func _sync_rules() -> void:
	var mode: String = MODES[_mode.selected][0]
	_ff.visible = mode == "teams" or mode == "flag"
	var race := mode == "race"
	var training := mode == "training"
	_stocks.visible = not race and not training
	_time.visible = not training
	if training and _bot.selected == 0:
		_bot.select(1) # in palestra serve qualcuno da colpire: il manichino
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
		b.custom_minimum_size = Vector2(104, 148)
		b.tooltip_text = stats_text(c)
		UI.set_selected(b, id == _character)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(v)
		if c.get("portrait") != null:
			# Il ritratto disegnato (E11 passo C): public/assets/characters/<id>/portrait.png
			var face := TextureRect.new()
			face.texture = load("res://data/" + str(c.portrait))
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			face.custom_minimum_size = Vector2(56, 62)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(face)
		elif c.get("sprite") != null:
			# Primo fotogramma dello spritesheet (nel formato cartella, di idle.png), ridotto per stare nel riquadro
			var path: String = "%s/idle.png" % c.sprite.dir if c.sprite.has("dir") else c.sprite.path
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://data/" + path)
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
		var l := UI.label(c.name, UI.SIZE_SMALL)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		v.add_child(_stat_bars(c))
		b.set_meta("id", id)
		b.pressed.connect(func():
			_character = id
			_select_cards(_chars, _character))
		_chars.add_child(b)


# Le tre barre sotto il nome: a metà è Bonobot, il metro (statistiche a 1)
func _stat_bars(c: Dictionary) -> Control:
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 1)
	var stats: Dictionary = c.get("stats", {})
	for s in STAT_BARS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var l := UI.label(s[1], 11, Color(UI.TEXT, 0.7))
		l.custom_minimum_size = Vector2(38, 0)
		row.add_child(l)
		var track := ColorRect.new()
		track.color = UI.BORDER
		track.custom_minimum_size = Vector2(BAR_W, 6)
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = UI.ACCENT
		fill.size = Vector2(maxf(2.0, BAR_W * stat_fill(float(stats.get(s[0], 1.0)), game.get("characterStats", {}))), 6)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)
		row.add_child(track)
		rows.add_child(row)
	return rows


# Da statistica a riempimento della barra, tra i limiti di CHARACTER_STATS (0,8 - 1,2): 1 sta a metà
static func stat_fill(value: float, limits: Dictionary) -> float:
	var lo: float = limits.get("min", 0.8)
	var hi: float = limits.get("max", 1.2)
	if hi <= lo:
		return 0.5
	return clampf((value - lo) / (hi - lo), 0.0, 1.0)


# Il suggerimento sul riquadro: i numeri esatti, in percentuale rispetto a Bonobot
static func stats_text(c: Dictionary) -> String:
	var stats: Dictionary = c.get("stats", {})
	var parts := []
	for s in STAT_BARS:
		parts.append("%s %d%%" % [s[2], roundi(float(stats.get(s[0], 1.0)) * 100)])
	return " · ".join(parts)


# Cambia solo il bordo dei riquadri, senza rifarli: così il fuoco del pad resta dov'è
func _select_cards(cards: Control, selected: String) -> void:
	for b in cards.get_children():
		UI.set_selected(b, b.get_meta("id") == selected)


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
	var l := UI.label(text, UI.SIZE_NOTE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.set_meta("id", id)
	b.pressed.connect(func():
		if id.begins_with("casuale-"):
			if _stage == _random_stage:
				_random_stage = _new_id("casuale-")
			b.set_meta("id", _random_stage)
		_stage = _random_stage if id.begins_with("casuale-") else id
		_select_cards(_stages, _stage))
	return b


func _submit() -> void:
	_apply_link(_server.text) # anche un link scritto a mano
	if not _creating:
		_apply_link(_room.text) # link incollato a mano o scritto senza incollarlo
	join_requested.emit(_choice(BOTS[_bot.selected][0] if _creating else ""))


# Crea una stanza con le regole scelte e un bot, quello delle regole o QUICK_BOT
func _quick_bot() -> void:
	_creating = true
	var bot: String = BOTS[_bot.selected][0]
	join_requested.emit(_choice(bot if bot != "" else QUICK_BOT))


func _choice(bot: String) -> Dictionary:
	var mode: String = MODES[_mode.selected][0]
	var room := _clean_room(_new_room.text if _creating else _room.text)
	if is_inside_tree():
		get_viewport().gui_release_focus() # così i tasti tornano alla partita
	return {
		"name": _name.text.strip_edges().left(16) if _name.text.strip_edges() != "" else "Bonobo",
		# La palestra è solo tua: chi la crea ne apre una nuova, così i comandi dell'allenamento valgono
		"room": _random_room() if mode == "training" and _creating else (room if room != "" else _random_room()),
		"char": _character,
		# Chi entra in una stanza che non c'è ancora la crea con le regole di questa pagina
		"stage": _new_id("corsa-") if mode == "race" else _stage,
		"rules": {"mode": mode, "stocks": _stocks.selected + 1, "timeLimitSec": TIMES[_time.selected][0], "friendlyFire": _ff.button_pressed},
		"server": _server.text.strip_edges(),
		"bot": "manichino" if mode == "training" and bot == "" else bot, # conta solo se la stanza è nuova
	}


# Nell'app da scaricare si incolla il link mandato sul Discord (".../godot/?room=amici&server=...")
# e si prendono server e stanza da lì. Solo se il testo arriva tutto insieme, cioè incollato
func _on_server_text(text: String) -> void:
	var pasted := text.length() - _server_len > 1
	_server_len = text.length()
	if pasted:
		_apply_link(text)


# Nel campo della stanza si incolla anche il link intero: restano la stanza e il server
func _on_room_text(text: String) -> void:
	var pasted := text.length() - _room_len > 1
	_room_len = text.length()
	if pasted and text.contains("?"):
		_apply_link(text)


func _apply_link(text: String) -> void:
	var found := parse_link(text)
	if found.has("room"):
		_room.text = found.room
		_room_len = _room.text.length()
		_room.caret_column = _room_len
		if _creating: # il link porta in una stanza che c'è già
			_show_tab(false, false)
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


static func _clean_room(text: String) -> String:
	var out := ""
	for ch in text.strip_edges().to_lower():
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
