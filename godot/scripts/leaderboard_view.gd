# La classifica a punti (Elo di src/server/rating.ts): posizione, nome, grado, punti, vittorie su partite e serie.
# La aprono il titolo e il menu di pausa. Legge <server>/classifica/punti.json ({board, updatedAt});
# un server che non ce l'ha ancora dà /classifica.json (Standing[] della settimana, coi punti accanto).
# Solo lettura: i punti li calcola il server a fine partita.
extends Control

signal closed

const PATHS := ["/classifica/punti.json", "/classifica.json"] # in ordine: il secondo se il primo non c'è
const MEDALS := [Color("ffcf4a"), Color("c9d1d9"), Color("cd7f32")] # oro, argento e bronzo dei primi tre
const WAKE_MS := 5000 # dopo tanto senza risposta si dice che il server forse dorme (Render gratuito)
const TIMEOUT_S := 90.0 # Render ci mette circa un minuto a svegliarsi
const WIDTH := 760.0 # larghezza del riquadro, pixel
const LIST_H := 400.0 # altezza della lista che scorre, pixel
# Colonne: titolo e larghezza in pixel (0 = si allarga)
const COLS := [["#", 44.0], ["Nome", 0.0], ["Grado", 150.0], ["Punti", 80.0], ["Vinte", 90.0], ["Serie", 64.0]]

var rows: Array = [] # righe normalizzate, già in ordine
var _server := ""
var _http: HTTPRequest
var _try := 0 # indice in PATHS della richiesta in corso
var _since := 0 # ms in cui è partita la richiesta, -1 a risposta arrivata
var _status: Label
var _list: VBoxContainer
var _retry: Button
var _close: Button


# server: lo stesso di main.gd (params.server). fetch = false nei test: niente rete
func setup(server: String, fetch := true) -> void:
	_server = server.trim_suffix("/")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(minf(WIDTH, get_viewport_rect().size.x - 40.0) if is_inside_tree() else WIDTH)
	add_child(parts[0])
	var box: VBoxContainer = parts[1]
	box.add_child(UI.header("Classifica"))
	box.add_child(UI.note("Punti di sempre: si vince contro chi ha più punti, se ne prendono di più. Contano le partite con almeno due umani."))
	box.add_child(_row(COLS.map(func(c): return c[0]), Color(UI.TEXT, 0.6), UI.SIZE_SMALL))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_H if not Phone.active else 220.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UI.GAP_S)
	scroll.add_child(_list)
	box.add_child(scroll)
	_status = UI.label("", UI.SIZE_BODY, Color(UI.TEXT, 0.8))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UI.GAP_M)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_retry = UI.button("Riprova", func(): _fetch(0))
	_retry.visible = false
	actions.add_child(_retry)
	_close = UI.button("Chiudi", close, true)
	actions.add_child(_close)
	box.add_child(actions)
	if is_inside_tree():
		UI.keep_focus(self, _close)
	if fetch:
		_fetch(0)


func close() -> void:
	queue_free()
	closed.emit()


func _fetch(i: int) -> void:
	_try = i
	_since = Time.get_ticks_msec()
	_retry.visible = false
	_status.visible = true
	_status.remove_theme_color_override("font_color")
	_status.text = "Carico la classifica..."
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = TIMEOUT_S
		add_child(_http)
		_http.request_completed.connect(_on_done)
	var err := _http.request(_server + PATHS[i])
	if err != OK:
		_fail("Non riesco a chiedere la classifica a %s (%s)." % [_server, error_string(err)])


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_since = -1
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if parsed == null:
		if _try + 1 < PATHS.size() and result == HTTPRequest.RESULT_SUCCESS:
			_fetch(_try + 1) # il server risponde ma non ha ancora la classifica a punti
			return
		_fail("Non riesco a leggere la classifica (%s)." % ("errore %d" % code if result == HTTPRequest.RESULT_SUCCESS else "il server non risponde"))
		return
	show_rows(parse_board(parsed))


func _fail(text: String) -> void:
	_since = -1
	_status.text = text + " Riprova tra poco."
	_status.add_theme_color_override("font_color", UI.WARN)
	_retry.visible = true


func _process(_delta: float) -> void:
	if _since >= 0 and _status != null and Time.get_ticks_msec() - _since >= WAKE_MS:
		var waited := int((Time.get_ticks_msec() - _since) / 1000.0)
		_status.text = "Il server si sta svegliando... Se nessuno giocava da un po' può volerci fino a un minuto (%d s)." % waited


# Le righe nella lista: i primi tre con oro, argento e bronzo
func show_rows(list: Array) -> void:
	rows = list
	for c in _list.get_children():
		if c != _status:
			c.queue_free()
	_status.visible = list.is_empty()
	_status.text = "Nessuno in classifica per ora: gioca una partita con gli amici per entrarci!"
	for i in list.size():
		var r: Dictionary = list[i]
		var color: Color = MEDALS[i] if i < MEDALS.size() else UI.TEXT
		var cells := [str(i + 1), str(r.name), str(r.tier), str(r.rating) if int(r.rating) >= 0 else "—", "%d/%d" % [r.wins, r.matches], str(r.streak)]
		var row := _row(cells, color, UI.SIZE_BODY if i >= MEDALS.size() else UI.SIZE_BIG)
		_list.add_child(row)


func _row(cells: Array, color: Color, size_px: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP_M)
	for j in cells.size():
		var l := UI.label(str(cells[j]), size_px, color if j < 2 else UI.TEXT) # la medaglia colora posizione e nome
		var w: float = COLS[j][1]
		if w > 0:
			l.custom_minimum_size = Vector2(w, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if j >= 3 else HORIZONTAL_ALIGNMENT_LEFT
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.clip_text = true
		row.add_child(l)
	return row


# Le due forme che può mandare il server, in righe tutte uguali {name, rating, tier, wins, matches, streak},
# dalla più alta in punti. Standing[] senza punti (server di prima): rating -1, in ordine di vittorie
static func parse_board(body: Variant) -> Array:
	var src: Array = []
	if body is Dictionary and body.get("board") is Array:
		src = body.board
	elif body is Array:
		src = body
	var out: Array = []
	for r in src:
		if not (r is Dictionary) or str(r.get("name", "")) == "":
			continue
		out.append({
			"name": str(r.name),
			"rating": int(round(float(r.get("rating", -1)))) if r.get("rating") != null else -1,
			"tier": str(r.get("tier", "")) if r.get("tier") != null else "",
			"wins": int(r.get("wins", 0)),
			"matches": int(r.get("matches", 0)),
			"streak": int(r.get("streak", 0)) if r.get("streak") != null else 0,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.rating != b.rating:
			return a.rating > b.rating
		return a.wins > b.wins)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
