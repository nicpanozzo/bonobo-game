# Lobby a pagine (#250): una schermata per ogni scelta, come nei picchiaduro veri.
#   1 Partita: crea una stanza, entra con il link arrivato dal Discord, o gioca contro un bot; regole e bot
#   2 Arena: anteprima grande e griglia (si salta in Corsa e quando si entra in una stanza che c'è già)
#   3 Lottatore: ritratto, statistiche e mosse, la griglia e il tuo nome, poi "Combatti!"
# In alto le briciole dicono a che punto sei; Indietro, Esc o B tornano al passo prima (dal primo, al titolo).
# L'indirizzo del server è in "Avanzate" sotto Entra: il link incollato lo porta già con sé.
extends Control

signal join_requested(choice: Dictionary)
signal options_requested
signal credits_requested
signal back_requested # Indietro, Esc o B dal primo passo: torna al titolo (E14)

const MAX_SEED := 999999 # come stageGenerator.ts: "casuale-<seme>" e "corsa-<seme>"
# Modalità: id, nome, spiegazione sulla scheda
const MODES := [
	["ffa", "Tutti contro tutti", "Vince chi resta con le vite"],
	["teams", "Squadre", "Rossi contro blu"],
	["flag", "Bandiera", "Butta fuori il portabandiera"],
	["race", "Corsa", "Primo al traguardo"],
	["training", "Allenamento", "Col manichino, senza vite"],
]
const TIMES := [[0, "Senza tempo"], [120, "2 minuti"], [180, "3 minuti"], [300, "5 minuti"]]
# Avversari del server per giocare da soli (#20, src/server/bot.ts)
# "Nome a caso" per chi usa il pad e non vuole scrivere
# TODO community: soprannomi e tormentoni del canale
const RANDOM_NAMES := ["Bonobo", "Scimmione", "Banana", "Liana", "Gorilla", "Babbuino", "Orango"]
const BOTS := [["", "Nessun bot"], ["manichino", "Manichino"], ["facile", "Bot facile"], ["semplice", "Bot"], ["difficile", "Bot difficile"]]
const STAT_BARS := [["speed", "Vel.", "Velocità"], ["jump", "Salto", "Salto"], ["weight", "Peso", "Peso"]] # barre sotto il ritratto (E11)
const BAR_W := 44.0 # larghezza delle barre nei riquadri, pixel
const BIG_BAR_W := 200.0 # larghezza delle barre nella scheda del lottatore scelto, pixel
const QUICK_BOT := "semplice" # "Contro un bot" quando nelle regole non ne è scelto nessuno
# I tre modi di cominciare, nella prima pagina: id, titolo, spiegazione
const KINDS := [
	["create", "Crea una stanza", "Giochi con gli amici: mandi loro il link"],
	["join", "Entra con un link", "Un amico ha già creato la stanza"],
	["bot", "Contro un bot", "Da solo, contro il computer"],
]
const PAGE_NAMES := {"match": "Partita", "stage": "Arena", "fighter": "Lottatore"}
const PAGE_W := 940.0 # larghezza del contenuto delle pagine, pixel
const PAGE_TOP := 28 # spazio sopra il titolo della pagina, pixel
const BIG_STAGE := Vector2(560, 315) # anteprima grande dell'arena (16:9), pixel
const BIG_FACE := Vector2(260, 260) # ritratto grande del lottatore, pixel

var game: Dictionary
var room_link: Callable # stanza -> link da mandare agli amici

var _name := LineEdit.new()
var _room := LineEdit.new() # Entra: nome della stanza o link incollato
var _new_room := LineEdit.new() # Crea: la stanza nuova
var _server := LineEdit.new()
var _msg: Label
var _room_hint: Label # "Scrivi la stanza...", se si va avanti col campo vuoto
var _chars := GridContainer.new()
var _stages := GridContainer.new()
var _course_note: Label
var _mode_i := 0 # modalità scelta, indice in MODES
var _mode_cards := HBoxContainer.new()
var _stocks := Stepper.new()
var _time := Stepper.new()
var _ff := CheckButton.new()
var _host: CheckButton # Crea: ospita dal proprio computer (#308), solo nell'app per computer
var _host_status: Label # a che punto è il server mentre si accende
var _bot := Stepper.new()
var _stocks_box: Control # titoletto e selettore delle vite, si nascondono insieme
var _stocks_label: Label
var _time_box: Control
var _character := ""
var _stage := ""
var _random_stage := ""
var _server_len := 0 # per riconoscere un link incollato nel campo del server
var _room_len := 0 # lo stesso per il campo della stanza
var _kind := "create" # create, join o bot: come si comincia
var _creating: bool: # si crea una stanza nuova (anche contro un bot), invece di entrare in una che c'è
	get:
		return _kind != "join"
var _kind_cards := {} # id -> riquadro nella prima pagina
var _kind_boxes := {} # id -> parte della prima pagina che si vede solo con quel modo
var _rules_box: Control
var _bot_label: Label
var _pages := {} # match/stage/fighter -> pagina
var _page := "match"
var _crumbs: HBoxContainer
var _summary: Label
var _next_button: Button
var _back_button: Button
var _advanced: Control
var _advanced_button: Button
var _back_to: Control # dove torna il fuoco quando si chiudono opzioni o crediti
var _big_stage: Control
var _big_stage_name: Label
var _big_face: TextureRect
var _big_name: Label
var _big_stats: VBoxContainer
var _big_moves: Label


# start_kind: da dove si parte nella prima pagina. "join" se si arriva da un link con la stanza,
# "bot" da "Da solo → Contro un bot" nel titolo, altrimenti "create"
func setup(game_data: Dictionary, params: Dictionary, link: Callable, start_kind := "create") -> void:
	game = game_data
	room_link = link
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_top_bar())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true # col pad la pagina scorre fino al controllo scelto
	root.add_child(scroll)
	# Le pagine partono dall'alto e non dal centro: così il titolo non salta quando cambia il contenuto
	var body := MarginContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_top", PAGE_TOP)
	body.add_theme_constant_override("margin_bottom", UI.GAP_L)
	scroll.add_child(body)
	var pages := VBoxContainer.new()
	pages.custom_minimum_size = Vector2(PAGE_W, 0)
	pages.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(pages)
	_pages.match = _match_page(params)
	_pages.stage = _stage_page(params)
	_pages.fighter = _fighter_page(params)
	for p in ["match", "stage", "fighter"]:
		pages.add_child(_pages[p])
	root.add_child(_bottom_bar())
	_set_kind(start_kind if _kind_cards.has(start_kind) else "create", false)
	_show_page("match")


# In alto: Indietro, le briciole dei passi, Opzioni e Crediti
func _top_bar() -> Control:
	var bar := _bar()
	var row: HBoxContainer = bar.get_child(0)
	_back_button = UI.small_button("‹ Indietro", _back)
	row.add_child(_back_button)
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_crumbs = HBoxContainer.new()
	_crumbs.add_theme_constant_override("separation", UI.GAP_M)
	row.add_child(_crumbs)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	row.add_child(UI.small_button("Opzioni", func():
		_back_to = get_viewport().gui_get_focus_owner()
		options_requested.emit()))
	row.add_child(UI.small_button("Crediti", func():
		_back_to = get_viewport().gui_get_focus_owner()
		credits_requested.emit()))
	return bar


# In basso: la versione, il riassunto delle scelte e il pulsante per andare avanti
func _bottom_bar() -> Control:
	var bar := _bar()
	var row: HBoxContainer = bar.get_child(0)
	row.add_child(UI.note(UI.version_text(game), 0.5))
	_summary = UI.label("", UI.SIZE_SMALL, Color(UI.TEXT, 0.8))
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_summary)
	_next_button = UI.button("Avanti ›", _forward, true)
	_next_button.custom_minimum_size = Vector2(220, 0)
	row.add_child(_next_button)
	return bar


# Una striscia scura a tutta larghezza con una riga dentro
func _bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UI.CARD
	style.set_content_margin_all(UI.GAP_L)
	style.content_margin_left = 24
	style.content_margin_right = 24
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP_M)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)
	return bar


# --- Pagina 1: Partita ---

func _match_page(params: Dictionary) -> Control:
	var page := _page_box("Come vuoi giocare?")
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", UI.GAP_L)
	for k in KINDS:
		var id: String = k[0]
		var b := UI.choice_card(k[1], k[2], func(): _set_kind(id))
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_kind_cards[id] = b
		cards.add_child(b)
	page.add_child(cards)

	# Crea: la stanza nuova e il link da mandare
	var create := VBoxContainer.new()
	create.add_theme_constant_override("separation", UI.GAP_S)
	create.add_child(UI.heading("La tua stanza"))
	var row := HBoxContainer.new()
	_new_room.max_length = 24
	# Tornando da una partita si ripropone la stessa stanza: gli amici sono ancora lì
	var rejoin: bool = params.get("rejoin", false) and str(params.get("room", "")) != ""
	_new_room.text = str(params.room) if rejoin and params.get("kind") == "create" else _random_room()
	_new_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_room.text_submitted.connect(func(_t): _forward())
	_new_room.text_changed.connect(func(_t): _update_summary())
	row.add_child(_new_room)
	row.add_child(UI.button("Nuova", func():
		_new_room.text = _random_room()
		_update_summary()))
	row.add_child(UI.button("Copia link", func():
		if _hosting_new():
			_msg.text = "Ospitando dal tuo computer, il link si copia da solo quando entri"
		else:
			UI.copy(room_link.call(_clean_room(_new_room.text)))
			_msg.text = "Link copiato: incollalo sul Discord"
		_msg.show()))
	create.add_child(row)
	_msg = UI.label("Manda il link agli amici: chi lo apre entra nella tua stessa partita.", UI.SIZE_NOTE, Color(UI.TEXT, 0.7))
	create.add_child(_msg)
	# Il server sul proprio computer invece che su Render: chi ospita gioca senza latenza
	if HostServer.available():
		_host = UI.toggle("Ospita dal mio computer: più fluido, niente server lontano", params.get("host", false), func(_on): pass)
		create.add_child(_host)
		# Molti non sanno che si può giocare in casa senza lag: lo si dice qui (#308)
		create.add_child(UI.note("Siete nella stessa casa? Ospita e manda il link di casa (in partita, in alto a sinistra): niente lag, anche senza internet."))
	_kind_boxes.create = create
	page.add_child(create)

	# Entra: basta il nome della stanza o il link mandato sul Discord
	var join := VBoxContainer.new()
	join.add_theme_constant_override("separation", UI.GAP_S)
	join.add_child(UI.heading("Stanza o link"))
	_room.text = params.get("room", "")
	_room.placeholder_text = "amici, oppure incolla il link della serata"
	_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_len = _room.text.length()
	_room.text_changed.connect(_on_room_text)
	_room.text_submitted.connect(func(_t): _forward())
	join.add_child(_room)
	_room_hint = UI.note("Chiedi il link a chi ha creato la stanza: lo stesso link porta tutti nella stessa partita.")
	join.add_child(_room_hint)
	# Avanzate: l'indirizzo del server, chiuso finché non serve
	_advanced_button = UI.small_button("Avanzate ▸", func(): _set_advanced(not _advanced.visible))
	_advanced_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	join.add_child(_advanced_button)
	var advanced := VBoxContainer.new()
	advanced.add_theme_constant_override("separation", UI.GAP_S)
	advanced.add_child(UI.heading("Server"))
	_server.text = params.server
	_server.placeholder_text = "https://... (o incolla qui il link della serata)"
	_server_len = _server.text.length()
	_server.text_changed.connect(_on_server_text)
	advanced.add_child(_server)
	_advanced = advanced
	join.add_child(advanced)
	_set_advanced(false)
	_kind_boxes.join = join
	page.add_child(join)

	# Regole e bot: contano solo per chi crea la stanza (anche contro un bot)
	var rules_box := VBoxContainer.new()
	rules_box.add_theme_constant_override("separation", UI.GAP_S)
	rules_box.add_child(UI.heading("Modalità"))
	var saved: Dictionary = params.get("rules", {}) if params.get("rules") is Dictionary else {}
	_mode_i = maxi(0, MODES.map(func(m): return m[0]).find(saved.get("mode", "ffa")))
	_mode_cards.add_theme_constant_override("separation", UI.GAP_M)
	for m in MODES:
		var id: String = m[0]
		var b := UI.choice_card(m[1], m[2], func(): _set_mode(id), UI.SIZE_BODY)
		b.custom_minimum_size = Vector2(0, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("id", id)
		_mode_cards.add_child(b)
	rules_box.add_child(_mode_cards)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UI.GAP_S)
	rules_box.add_child(gap)
	# Vite, tempo e bot con le frecce, uno per riga: col pad su e giù si passa dall'uno all'altro,
	# sinistra e destra cambiano il valore
	var rules := VBoxContainer.new()
	rules.add_theme_constant_override("separation", UI.GAP_S)
	for n in range(1, 6):
		_stocks.add_item(str(n))
	_stocks.select(clampi(int(saved.get("stocks", 3)) - 1, 0, 4))
	for t in TIMES:
		_time.add_item(t[1])
	_time.select(maxi(0, TIMES.map(func(t): return t[0]).find(int(saved.get("timeLimitSec", 0)))))
	for b in BOTS:
		_bot.add_item(b[1])
	_bot.select(maxi(0, BOTS.map(func(x): return x[0]).find(str(params.get("bot", "")))))
	_stocks_label = UI.heading("Vite")
	_stocks_box = _labeled(_stocks_label, _stocks)
	rules.add_child(_stocks_box)
	_time_box = _labeled(UI.heading("Tempo"), _time)
	rules.add_child(_time_box)
	_bot_label = UI.heading("Bot")
	rules.add_child(_labeled(_bot_label, _bot))
	_ff.text = "Fuoco amico"
	_ff.button_pressed = bool(saved.get("friendlyFire", false))
	_ff.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_ff.custom_minimum_size = Vector2(374, 0) # l'interruttore finisce dove finiscono le frecce
	rules.add_child(_ff)
	rules_box.add_child(rules)
	_course_note = UI.label("In Corsa si gioca su un percorso lungo, nuovo a ogni stanza: vince chi arriva prima al traguardo.", UI.SIZE_SMALL, Color(UI.TEXT, 0.7))
	_course_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	rules_box.add_child(_course_note)
	_bot.item_selected.connect(func(_i): _sync_rules())
	for c in [_stocks, _time]:
		c.item_selected.connect(func(_i): _update_summary())
	_rules_box = rules_box
	page.add_child(rules_box)
	return page


func _labeled(label: Label, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP_M)
	label.custom_minimum_size = Vector2(130, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(control)
	return row


func _mode_id() -> String:
	return MODES[_mode_i][0]


func _set_mode(id: String) -> void:
	_mode_i = maxi(0, MODES.map(func(m): return m[0]).find(id))
	_sync_rules()


func _set_kind(kind: String, focus := true) -> void:
	_kind = kind
	for id in _kind_cards:
		UI.set_selected(_kind_cards[id], id == kind)
		if _kind_boxes.has(id):
			_kind_boxes[id].visible = id == kind
	_rules_box.visible = kind != "join"
	# Contro un bot serve un bot: se nelle regole non ce n'è, quello di riserva
	if kind == "bot" and _bot.selected == 0:
		_bot.select(BOTS.map(func(x): return x[0]).find(QUICK_BOT))
	_sync_rules()
	if focus and is_inside_tree():
		_kind_cards[kind].grab_focus()


func _set_advanced(open: bool) -> void:
	_advanced.visible = open
	_advanced_button.text = "Avanzate ▾" if open else "Avanzate ▸"


# Il fuoco amico ha senso solo a squadre; in Bandiera le vite diventano i punti per vincere;
# in Corsa le vite non contano e l'arena è un percorso generato; in Allenamento non ci sono né vite né tempo
func _sync_rules() -> void:
	var mode := _mode_id()
	_select_cards(_mode_cards, mode)
	_ff.visible = mode == "teams" or mode == "flag"
	var race := mode == "race"
	var training := mode == "training"
	_stocks_box.visible = not race and not training
	_time_box.visible = not training
	_stocks_label.text = "PUNTI" if mode == "flag" else "VITE"
	if training and _bot.selected == 0:
		_bot.select(1) # in palestra serve qualcuno da colpire: il manichino
	_course_note.visible = race
	_bot_label.text = "AVVERSARIO" if _kind == "bot" else "BOT (SE VUOI)"
	for i in 5:
		var n := i + 1
		var word := ("punto" if n == 1 else "punti") if mode == "flag" else ("vita" if n == 1 else "vite")
		_stocks.set_item_text(i, "%d %s" % [n, word])
	_update_crumbs()
	_update_summary()


# --- Pagina 2: Arena ---

func _stage_page(params: Dictionary) -> Control:
	var page := _page_box("Scegli l'arena")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	page.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", UI.GAP_M)
	row.add_child(left)
	_big_stage = preload("res://scripts/stage_preview.gd").new()
	_big_stage.custom_minimum_size = BIG_STAGE
	left.add_child(_big_stage)
	_big_stage_name = UI.header("")
	left.add_child(_big_stage_name)
	_stages.columns = 2
	_stages.add_theme_constant_override("h_separation", UI.GAP_M)
	_stages.add_theme_constant_override("v_separation", UI.GAP_M)
	row.add_child(_stages)
	_stage = params.get("stage", game.defaultStageId)
	_random_stage = _stage if _stage.begins_with("casuale-") else _new_id("casuale-")
	if not game.stages.has(_stage) and not _stage.begins_with("casuale-"):
		_stage = game.defaultStageId # i percorsi della Corsa non sono arene da scegliere
	_draw_stages()
	_show_big_stage()
	return page


# Le arene di stages.ts più una generata a caso: cliccandola di nuovo se ne genera un'altra
func _draw_stages() -> void:
	for c in _stages.get_children():
		c.queue_free()
	for id in game.stages:
		_stages.add_child(_stage_card(id, game.stages[id].name, game.stages[id]))
	_stages.add_child(_stage_card(_random_stage, "Casuale", {}))


func _stage_card(id: String, text: String, spec: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 112)
	UI.set_selected(b, id == _stage)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(v)
	var preview := preload("res://scripts/stage_preview.gd").new()
	preview.spec = spec
	preview.custom_minimum_size = Vector2(154, 76)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(preview)
	var l := UI.label(text, UI.SIZE_SMALL)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.set_meta("id", id)
	b.pressed.connect(func():
		if id.begins_with("casuale-"):
			if _stage == _random_stage:
				_random_stage = _new_id("casuale-")
			b.set_meta("id", _random_stage)
		_stage = _random_stage if id.begins_with("casuale-") else id
		_select_cards(_stages, _stage)
		_show_big_stage())
	return b


func _show_big_stage() -> void:
	var known: bool = game.stages.has(_stage)
	_big_stage.spec = game.stages[_stage] if known else {}
	_big_stage.queue_redraw()
	_big_stage_name.text = stage_name(game, _stage)
	_update_summary()


static func stage_name(game_data: Dictionary, id: String) -> String:
	return str(game_data.stages[id].name) if game_data.stages.has(id) else "Arena casuale"


# --- Pagina 3: Lottatore ---

func _fighter_page(params: Dictionary) -> Control:
	var page := _page_box("Scegli il lottatore")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	page.add_child(row)
	# A sinistra il lottatore scelto, in grande
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(340, 0)
	row.add_child(card)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", UI.GAP_S)
	card.add_child(left)
	_big_face = TextureRect.new()
	_big_face.custom_minimum_size = BIG_FACE
	_big_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	left.add_child(_big_face)
	_big_name = UI.header("")
	_big_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_big_name)
	_big_stats = VBoxContainer.new()
	_big_stats.add_theme_constant_override("separation", UI.GAP_S)
	left.add_child(_big_stats)
	_big_moves = UI.note("")
	_big_moves.autowrap_mode = TextServer.AUTOWRAP_WORD
	_big_moves.custom_minimum_size = Vector2(300, 0)
	left.add_child(_big_moves)
	# A destra la griglia e il tuo nome
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", UI.GAP_S)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_chars.columns = 5
	_chars.add_theme_constant_override("h_separation", UI.GAP_M)
	_chars.add_theme_constant_override("v_separation", UI.GAP_M)
	right.add_child(_chars)
	_character = params.get("char", game.defaultCharacterId)
	if not game.characters.has(_character):
		_character = game.defaultCharacterId
	_draw_chars()
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UI.GAP_L)
	right.add_child(gap)
	right.add_child(UI.heading("Il tuo nome"))
	_name.max_length = 16
	_name.text = params.get("name", "")
	_name.placeholder_text = "Come ti vedono gli altri"
	_name.text_submitted.connect(func(_t): _forward())
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.add_child(_name)
	name_row.add_child(UI.button("Nome a caso", func():
		_name.text = "%s%d" % [RANDOM_NAMES[randi() % RANDOM_NAMES.size()], randi() % 100]))
	right.add_child(name_row)
	_show_big_fighter()
	return page


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
		v.add_child(_face(c, Vector2(56, 62)))
		var l := UI.label(c.name, UI.SIZE_SMALL)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
		v.add_child(_stat_bars(c))
		b.set_meta("id", id)
		b.pressed.connect(func():
			_character = id
			_select_cards(_chars, _character)
			_show_big_fighter())
		_chars.add_child(b)


# Il disegno del lottatore: il ritratto (E11 passo C), o il primo fotogramma dello spritesheet,
# o un rettangolo del colore del gioco per chi non ha ancora un disegno
func _face(c: Dictionary, size: Vector2) -> Control:
	var tex := face_texture(c)
	if tex == null:
		var boxc := CenterContainer.new()
		boxc.custom_minimum_size = size
		boxc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := ColorRect.new()
		r.color = UI.PRIMARY
		r.custom_minimum_size = Vector2(size.x * 0.45, size.y * 0.85)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boxc.add_child(r)
		return boxc
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


static func face_texture(c: Dictionary) -> Texture2D:
	if c.get("portrait") != null:
		return load("res://data/" + str(c.portrait))
	if c.get("sprite") != null:
		# Nel formato cartella il primo fotogramma è in idle.png
		var path: String = "%s/idle.png" % c.sprite.dir if c.sprite.has("dir") else c.sprite.path
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://data/" + path)
		atlas.region = Rect2(0, 0, c.sprite.frameWidth, c.sprite.frameHeight)
		return atlas
	return null


# La scheda grande: ritratto, nome, statistiche con i numeri e le mosse speciali
func _show_big_fighter() -> void:
	var c: Dictionary = game.characters[_character]
	var tex := face_texture(c)
	_big_face.texture = tex
	if tex == null: # senza disegno: un rettangolo, come nei riquadri
		var img := Image.create(9, 16, false, Image.FORMAT_RGBA8)
		img.fill(UI.PRIMARY)
		_big_face.texture = ImageTexture.create_from_image(img)
		_big_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		_big_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_big_name.text = str(c.name)
	for child in _big_stats.get_children():
		child.queue_free()
	var stats: Dictionary = c.get("stats", {})
	for s in STAT_BARS:
		var value: float = float(stats.get(s[0], 1.0))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", UI.GAP_M)
		var l := UI.label(s[2], UI.SIZE_SMALL, Color(UI.TEXT, 0.8))
		l.custom_minimum_size = Vector2(76, 0)
		r.add_child(l)
		r.add_child(_bar_track(value, BIG_BAR_W, 10))
		r.add_child(UI.label("%d%%" % roundi(value * 100), UI.SIZE_SMALL, Color(UI.TEXT, 0.8)))
		_big_stats.add_child(r)
	_big_moves.text = moves_text(c)
	_update_summary()


# "Speciali: Tiro, Scatto, Contrattacco · Suprema: Omar"
static func moves_text(c: Dictionary) -> String:
	var names := []
	var specials: Dictionary = c.get("specials", {})
	for k in ["neutral", "side", "down"]:
		if specials.has(k) and specials[k] is Dictionary and specials[k].has("name"):
			names.append(str(specials[k].name))
	var text := "Speciali: " + ", ".join(names) if not names.is_empty() else ""
	var supreme = c.get("supreme")
	if supreme is Dictionary and supreme.has("name"):
		text += ("\n" if text != "" else "") + "Suprema: " + str(supreme.name)
	return text


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
		row.add_child(_bar_track(float(stats.get(s[0], 1.0)), BAR_W, 6))
		rows.add_child(row)
	return rows


func _bar_track(value: float, width: float, height: float) -> Control:
	var track := ColorRect.new()
	track.color = UI.BORDER
	track.custom_minimum_size = Vector2(width, height)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = UI.ACCENT
	fill.size = Vector2(maxf(2.0, width * stat_fill(value, game.get("characterStats", {}))), height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	return track


# --- Passi, briciole e riassunto ---

# Contenitore di una pagina, con il suo titolo
func _page_box(text: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UI.GAP_M)
	var t := UI.title(text)
	page.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UI.GAP_S)
	page.add_child(gap)
	return page


# I passi di questa partita: l'arena si sceglie solo creando una stanza e mai in Corsa (il percorso è generato)
func flow() -> Array:
	if _kind == "join" or _mode_id() == "race":
		return ["match", "fighter"]
	return ["match", "stage", "fighter"]


func _show_page(page: String, focus := true) -> void:
	_page = page
	for p in _pages:
		_pages[p].visible = p == page
	var last: bool = flow().back() == page
	_next_button.text = ("Entra!" if _kind == "join" else "Combatti!") if last else "Avanti ›"
	_back_button.text = "‹ Menu" if page == "match" else "‹ Indietro"
	_update_crumbs()
	UI.fade_in(_pages[page])
	if focus:
		_focus_page()


# Apre una pagina da fuori (main.gd: "Cambia lottatore" a fine partita apre "fighter")
func open_page(page: String) -> void:
	if page != _page and flow().has(page):
		_show_page(page)


func _focus_page() -> void:
	var target: Control = _next_button
	match _page:
		"match":
			target = _kind_cards[_kind]
		"stage":
			target = _card(_stages, _stage)
		"fighter":
			target = _card(_chars, _character)
	if target != null:
		target.grab_focus.call_deferred()


func _card(cards: Control, id: String) -> Control:
	for b in cards.get_children():
		if not b.is_queued_for_deletion() and b.get_meta("id", "") == id:
			return b
	return null


# Avanti: dalla prima pagina controlla la stanza, dall'ultima si entra
func _forward() -> void:
	var steps := flow()
	var i := steps.find(_page)
	if _page == "match" and _kind == "join":
		_apply_link(_room.text) # link incollato a mano o scritto senza incollarlo
		if _clean_room(_room.text) == "":
			_room_hint.text = "Scrivi il nome della stanza o incolla il link che ti hanno mandato."
			_room_hint.add_theme_color_override("font_color", UI.WARN)
			if is_inside_tree():
				_room.grab_focus()
			return
	if i + 1 >= steps.size():
		_submit()
	else:
		_show_page(steps[i + 1])


# Indietro, Esc o B: il passo prima, o il titolo dal primo
func _back() -> void:
	var steps := flow()
	var i := steps.find(_page)
	if i <= 0:
		back_requested.emit()
	else:
		_show_page(steps[i - 1])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


# Chiusi opzioni o crediti, il fuoco torna al pulsante che li ha aperti
func restore_focus() -> void:
	if is_instance_valid(_back_to):
		_back_to.grab_focus()


# "1 Partita › 2 Arena › 3 Lottatore": quello di adesso in giallo, i passi fatti si cliccano per tornarci
func _update_crumbs() -> void:
	if _crumbs == null:
		return
	for c in _crumbs.get_children():
		c.queue_free()
	var steps := flow()
	var at := steps.find(_page)
	for i in steps.size():
		if i > 0:
			_crumbs.add_child(UI.label("›", UI.SIZE_BODY, Color(UI.TEXT, 0.4)))
		var b := Button.new()
		b.flat = true
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var empty := StyleBoxEmpty.new()
			empty.set_content_margin_all(UI.GAP_S)
			b.add_theme_stylebox_override(state, empty) # stessa altezza, scelto o no
		b.focus_mode = Control.FOCUS_NONE # col pad si va avanti e indietro con A e B
		b.text = "%d  %s" % [i + 1, PAGE_NAMES[steps[i]]]
		var color := UI.ACCENT if i == at else (UI.TEXT if i < at else Color(UI.TEXT, 0.4))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			b.add_theme_color_override(state, color)
		if i == at:
			b.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
		b.disabled = i >= at
		var step: String = steps[i]
		b.pressed.connect(func(): _show_page(step))
		_crumbs.add_child(b)


# In basso, le scelte fatte finora: "Stanza ab12c · Tutti contro tutti, 3 vite · Il Palco · Bonobot"
func _update_summary() -> void:
	if _summary == null or game.is_empty():
		return
	var parts := []
	match _kind:
		"create":
			parts.append("Stanza " + _clean_room(_new_room.text))
		"join":
			parts.append("Entri in " + _clean_room(_room.text) if _clean_room(_room.text) != "" else "Entri in una stanza")
		"bot":
			parts.append("Contro: " + str(BOTS[_bot.selected][1]) if _bot.selected > 0 else "Contro un bot")
	if _kind != "join":
		var mode := _mode_id()
		var rules := str(MODES[_mode_i][1])
		if _stocks_box.visible:
			rules += ", " + _stocks.get_item_text(_stocks.selected)
		parts.append(rules)
		if mode != "race":
			parts.append(stage_name(game, _stage))
	if _character != "":
		parts.append(str(game.characters[_character].name))
	_summary.text = " · ".join(parts)


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


func _submit() -> void:
	_apply_link(_server.text) # anche un link scritto a mano
	if _kind == "join":
		_apply_link(_room.text)
	var bot: String = BOTS[_bot.selected][0]
	match _kind:
		"join":
			bot = ""
		"bot":
			bot = bot if bot != "" else QUICK_BOT
	if _hosting_new() and _kind == "create":
		_host_and_join(_choice(bot))
		return
	join_requested.emit(_choice(bot))


func _hosting_new() -> bool:
	return _host != null and _host.button_pressed


# Accende il server sul computer (o usa quello già acceso), copia il link per gli amici ed entra
func _host_and_join(choice: Dictionary) -> void:
	if _host_status != null:
		return # già in corso
	var host := HostServer.instance(get_tree())
	_host_status = UI.toast(self, "", UI.OK, 600.0)
	host.progress.connect(_on_host_progress)
	host.failed.connect(_on_host_failed, CONNECT_ONE_SHOT)
	host.ready_to_play.connect(func(_info: Dictionary):
		_host_done(host)
		choice.server = host.local_server()
		choice.host = true
		join_requested.emit(choice), CONNECT_ONE_SHOT)
	host.start(choice.room)


func _on_host_progress(text: String) -> void:
	if is_instance_valid(_host_status):
		_host_status.text = text


func _on_host_failed(text: String) -> void:
	_cancel_host()
	UI.toast(self, text + " Togli \"Ospita\" per giocare sul server online.", UI.WARN, 8.0)


# Lobby chiusa mentre il server si accende: il server resta, ma non si entra più da qui
func _exit_tree() -> void:
	if _host_status != null:
		_cancel_host()


func _cancel_host() -> void:
	var host := HostServer.instance(get_tree())
	_host_done(host)
	for c in host.ready_to_play.get_connections():
		host.ready_to_play.disconnect(c.callable)


func _host_done(host: HostServer) -> void:
	if host.progress.is_connected(_on_host_progress):
		host.progress.disconnect(_on_host_progress)
	if host.failed.is_connected(_on_host_failed):
		host.failed.disconnect(_on_host_failed)
	if is_instance_valid(_host_status):
		_host_status.queue_free()
	_host_status = null


func _choice(bot: String) -> Dictionary:
	var mode := _mode_id()
	var room := ""
	match _kind:
		"create":
			room = _clean_room(_new_room.text)
		"join":
			room = _clean_room(_room.text)
	if is_inside_tree():
		get_viewport().gui_release_focus() # così i tasti tornano alla partita
	return {
		"name": _name.text.strip_edges().left(16) if _name.text.strip_edges() != "" else "Bonobo",
		# La palestra è solo tua: chi la crea ne apre una nuova, così i comandi dell'allenamento valgono.
		# Contro un bot la stanza è nuova e tua
		"room": _random_room() if (mode == "training" and _creating) or room == "" else room,
		"char": _character,
		# Chi entra in una stanza che non c'è ancora la crea con le regole di questa pagina
		"stage": _new_id("corsa-") if mode == "race" else _stage,
		"rules": {"mode": mode, "stocks": _stocks.selected + 1, "timeLimitSec": TIMES[_time.selected][0], "friendlyFire": _ff.button_pressed},
		"server": _server.text.strip_edges(),
		"bot": "manichino" if mode == "training" and bot == "" else bot, # conta solo se la stanza è nuova
		"kind": _kind, # per tornare alla stessa scheda dopo la partita
		"host": _hosting_new(), # ricordato per la prossima volta; il server vero lo mette _host_and_join
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
			_set_kind("join", false)
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
