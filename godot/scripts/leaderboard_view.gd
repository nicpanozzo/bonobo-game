# La classifica a punti (Elo di src/server/rating.ts): posizione, nome, grado, punti, vittorie su partite e serie.
# La aprono il titolo e il menu di pausa. Legge <server>/classifica/punti.json ({board, updatedAt});
# un server che non ce l'ha ancora dà /classifica.json (Standing[] della settimana, coi punti accanto).
# Solo lettura: i punti li calcola il server a fine partita.
extends Control

signal closed

const Lobby := preload("res://scripts/lobby.gd") # face_texture: il ritratto di un lottatore

const PATHS := ["/classifica/punti.json", "/classifica.json"] # in ordine: il secondo se il primo non c'è
const MEDALS := [Color("ffc928"), Color("d5dbe6"), Color("e0894a")] # oro, argento e bronzo dei primi tre
const WAKE_MS := 5000 # dopo tanto senza risposta si dice che il server forse dorme (Render gratuito)
const TIMEOUT_S := 90.0 # Render ci mette circa un minuto a svegliarsi
const WIDTH := 780.0 # larghezza del riquadro, pixel
const PODIUM_H := 238.0 # il podio dei primi tre, pixel
const PHONE_PODIUM_H := 200.0
const LIST_H := 226.0 # la lista che scorre sotto il podio, pixel
const PHONE_LIST_H := 70.0
const ROW_H := 40.0 # una riga della lista, pixel
# I colori dei gradi (RATING.tiers in constants.ts), dal più basso; un grado nuovo prende il lilla
const TIER_COLORS := {
	"Scimmietta": Color("c49a6c"),
	"Babbuino": Color("7fd4ff"),
	"Orango": Color("ff9a4a"),
	"Gorilla": Color("b89cff"),
	"Silverback": Color("d5dbe6"),
	"Re della giungla": Color("ffc928"),
}

var rows: Array = [] # righe normalizzate, già in ordine
var _server := ""
var _http: HTTPRequest
var _try := 0 # indice in PATHS della richiesta in corso
var _since := 0 # ms in cui è partita la richiesta, -1 a risposta arrivata
var _status: Label
var _list: VBoxContainer
var _retry: Button
var _close: Button
var _game: Dictionary = {} # game.json, letto solo se il server manda i lottatori (characterId) per i ritratti


# server: lo stesso di main.gd (params.server). fetch = false nei test: niente rete
func setup(server: String, fetch := true) -> void:
	_server = server.trim_suffix("/")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(minf(WIDTH, get_viewport_rect().size.x - 60.0) if is_inside_tree() else WIDTH)
	add_child(parts[0])
	var box: VBoxContainer = parts[1]
	box.add_theme_constant_override("separation", UI.GAP_S)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UI.GAP_L)
	box.add_child(head)
	head.add_child(UI.header("Classifica"))
	var why := UI.note("Punti di sempre: battere chi ne ha di più ne vale di più. Contano le partite con almeno due umani.")
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(why)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, (PHONE_PODIUM_H + PHONE_LIST_H) if Phone.active else (PODIUM_H + LIST_H))
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


# Il podio coi primi tre (il primo in mezzo, più in alto) e sotto le altre righe, ognuna su una lastra
func show_rows(list: Array) -> void:
	rows = list
	for c in _list.get_children():
		if c != _status:
			c.queue_free()
	_status.visible = list.is_empty()
	_status.text = "Nessuno in classifica per ora: gioca una partita con gli amici per entrarci!"
	if list.is_empty():
		return
	if _game.is_empty() and list.any(func(r: Dictionary) -> bool: return str(r.get("characterId", "")) != ""):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
		_game = parsed if parsed is Dictionary else {}
	var podium := Podium.new()
	podium.rows = list.slice(0, 3)
	podium.view = self
	podium.custom_minimum_size = Vector2(0, PHONE_PODIUM_H if Phone.active else PODIUM_H)
	_list.add_child(podium)
	for i in range(3, list.size()):
		var row := Row.new()
		row.rank = i + 1
		row.data = list[i]
		row.view = self
		row.custom_minimum_size = Vector2(0, ROW_H)
		_list.add_child(row)


# Il ritratto del lottatore preferito, se il server lo manda e c'è il disegno: [texture, regione] o []
func portrait(r: Dictionary) -> Array:
	var id := str(r.get("characterId", ""))
	if id == "" or not _game.get("characters", {}).has(id):
		return []
	var tex := Lobby.face_texture(_game.characters[id])
	return [tex, Rect2(Vector2.ZERO, tex.get_size())] if tex != null else []


# Le iniziali di un nome: "Nicola" → "N", "Giovanni fRa" → "GF"
static func initials(name: String) -> String:
	var out := ""
	for w in name.strip_edges().split(" ", false):
		out += w.left(1).to_upper()
		if out.length() >= 2:
			break
	return out if out != "" else "?"


static func tier_color(tier: String) -> Color:
	return TIER_COLORS.get(tier, UI.LILAC)


static func tier_width(tier: String, size_px: int) -> float:
	return UI.display().get_string_size(tier.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(size_px)).x + 22.0


# Il distintivo del grado: una targhetta storta del suo colore con la scritta a inchiostro.
# at: bordo sinistro e centro in altezza. Restituisce quanto è largo (la usa anche results_view.gd)
static func draw_tier(ci: CanvasItem, at: Vector2, tier: String, size_px: int, alpha := 1.0) -> float:
	var fs := Access.px(size_px)
	var w := tier_width(tier, size_px)
	var box := Rect2(at - Vector2(0, (fs + 8) / 2.0), Vector2(w, fs + 8))
	UI.draw_plate(ci, box, Color(tier_color(tier), alpha), 8.0, Color(UI.INK, alpha), 2.5, Vector2(2, 3))
	ci.draw_string(UI.display(), Vector2(box.position.x + 11, box.end.y - fs * 0.32 - 2), tier.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.INK, alpha))
	return w


# La fiamma della serie di vittorie, disegnata (i font non hanno le emoji): rossa fuori, gialla dentro.
# c: il centro della base, h: l'altezza
static func draw_flame(ci: CanvasItem, c: Vector2, h: float, alpha := 1.0) -> void:
	var shape := [Vector2(0, -1), Vector2(0.2, -0.64), Vector2(0.4, -0.42), Vector2(0.46, -0.12), Vector2(0.4, 0.1), Vector2(0.22, 0.24), Vector2(0, 0.28), Vector2(-0.22, 0.24), Vector2(-0.4, 0.1), Vector2(-0.46, -0.12), Vector2(-0.38, -0.38), Vector2(-0.22, -0.3), Vector2(-0.14, -0.62)]
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for p: Vector2 in shape:
		outer.append(c + Vector2(p.x, p.y - 0.28) * h)
		inner.append(c + Vector2(p.x * 0.52, p.y * 0.55 - 0.18) * h)
	ci.draw_colored_polygon(outer, Color(UI.PUNCH, alpha))
	ci.draw_colored_polygon(inner, Color(UI.BANANA, alpha))
	ci.draw_polyline(outer + PackedVector2Array([outer[0]]), Color(UI.INK, alpha), 2.0, true)


# Un tondo con le iniziali (o il ritratto), con l'anello del colore della medaglia
func draw_avatar(ci: CanvasItem, r: Dictionary, c: Vector2, radius: float, ring: Color) -> void:
	ci.draw_circle(c, radius + 3, UI.INK)
	ci.draw_circle(c, radius, ring)
	ci.draw_circle(c, radius - maxf(3.0, radius * 0.12), UI.GRAPE_HI)
	var pic := portrait(r)
	if not pic.is_empty():
		var s := radius * 1.6
		ci.draw_texture_rect_region(pic[0], Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), pic[1])
		return
	var text := initials(str(r.name))
	var fs := roundi(radius * (0.95 if text.length() == 1 else 0.75))
	var tw := UI.display().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	UI.draw_sticker(ci, UI.display(), Vector2(c.x - tw / 2, c.y + fs * 0.36), text, fs, UI.PAPER, maxi(3, fs / 6), Vector2(0, 2))


# Il podio: tre gradini a lastra storta (oro in mezzo, più alto), sopra il tondo, il nome, il grado e i punti
class Podium extends Control:
	var rows: Array = []
	var view: Control

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var slot := w / 3.0
		var order := [1, 0, 2] # argento a sinistra, oro in mezzo, bronzo a destra
		for j in 3:
			var i: int = order[j]
			if i >= rows.size():
				continue
			var r: Dictionary = rows[i]
			var medal: Color = MEDALS[i]
			var step_h: float = h * ([0.2, 0.14, 0.1] if Phone.active else [0.3, 0.22, 0.17])[i]
			var cx := slot * (j + 0.5)
			var step := Rect2(Vector2(cx - slot * 0.4, h - step_h - 6), Vector2(slot * 0.8, step_h))
			UI.draw_plate(self, step, medal.darkened(0.35), 14.0, UI.INK, 3.0, Vector2(5, 6))
			UI.draw_plate(self, Rect2(step.position, Vector2(step.size.x, 8)), medal, 14.0 * 8.0 / step.size.y, UI.INK, 0.0)
			var place := str(i + 1)
			var pf := roundi(step_h * 0.62)
			var pw := UI.display().get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, pf).x
			UI.draw_sticker(self, UI.display(), Vector2(cx - pw / 2, step.end.y - step_h * 0.2), place, pf, medal, 6, Vector2(0, 3))
			# Sopra il gradino: punti, grado, nome e il tondo, dal basso in su
			var y := step.position.y - 10
			var pts := "%d punti" % int(r.rating) if int(r.rating) >= 0 else "%d vinte" % int(r.wins)
			var nf := Access.px(17)
			var nw := UI.numbers().get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, nf).x
			draw_string_outline(UI.numbers(), Vector2(cx - nw / 2, y), pts, HORIZONTAL_ALIGNMENT_LEFT, -1, nf, 5, UI.INK)
			draw_string(UI.numbers(), Vector2(cx - nw / 2, y), pts, HORIZONTAL_ALIGNMENT_LEFT, -1, nf, UI.BANANA if i == 0 else UI.PAPER)
			y -= nf + 8
			if str(r.tier) != "":
				var tw: float = view.tier_width(str(r.tier), 12)
				view.draw_tier(self, Vector2(cx - tw / 2, y - 4), str(r.tier), 12)
				y -= Access.px(12) + 14
			var name := str(r.name)
			var sf := Access.px(22 if i == 0 else 19)
			var sw := minf(UI.display().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, sf).x, slot - 16)
			UI.draw_sticker(self, UI.display(), Vector2(cx - sw / 2, y), name, sf, UI.PAPER, 6, Vector2(0, 3))
			# Il tondo più grande che ci sta sopra il nome (col primo c'è anche la corona)
			var radius := clampf((y - sf - 6) / (2.6 if i == 0 else 2.1), 12.0, 34.0 if i == 0 else 28.0)
			var ac := Vector2(cx, y - sf - radius - 2)
			view.draw_avatar(self, r, ac, radius, medal)
			if i == 0: # la corona sopra l'oro
				var s := radius * 0.55
				var at := ac - Vector2(0, radius + 2)
				var crown := PackedVector2Array([at + Vector2(-s, 0), at + Vector2(-s, -s * 0.8), at + Vector2(-s * 0.5, -s * 0.35), at + Vector2(0, -s), at + Vector2(s * 0.5, -s * 0.35), at + Vector2(s, -s * 0.8), at + Vector2(s, 0)])
				draw_colored_polygon(crown, UI.BANANA)
				draw_polyline(crown + PackedVector2Array([crown[0]]), UI.INK, 2.5, true)
			if int(r.streak) >= 2: # la fiamma accanto al tondo di chi è in serie
				view.draw_flame(self, ac + Vector2(radius + 12, radius * 0.6), 26.0)
				var st := str(r.streak)
				draw_string_outline(UI.display(), ac + Vector2(radius + 22, radius * 0.6 + 4), st, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), 5, UI.INK)
				draw_string(UI.display(), ac + Vector2(radius + 22, radius * 0.6 + 4), st, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), UI.BANANA)


# Una riga dal quarto in giù: posizione, tondo, nome, grado, punti, vinte su giocate e la serie con la fiamma
class Row extends Control:
	var rank := 4
	var data: Dictionary = {}
	var view: Control

	func _draw() -> void:
		var r := Rect2(Vector2(8, 1), size - Vector2(20, 6))
		UI.draw_plate(self, r, UI.GRAPE.lightened(0.04), 10.0, UI.INK, 2.5, Vector2(3, 4))
		var mid := r.position.y + r.size.y / 2
		var bf := UI.font(UI.WEIGHT_BOLD)
		var fs := Access.px(UI.SIZE_BODY)
		var rk := str(rank)
		UI.draw_sticker(self, UI.display(), Vector2(r.position.x + 12, mid + fs * 0.4), rk, Access.px(20), UI.LILAC, 4, Vector2(0, 2))
		view.draw_avatar(self, data, Vector2(r.position.x + 58, mid), r.size.y * 0.36, UI.BORDER)
		var x_end := r.end.x - 10
		var streak := int(data.get("streak", 0))
		# Da destra: serie, vinte su giocate, punti, grado
		var sx := x_end - 40
		if streak > 0:
			view.draw_flame(self, Vector2(sx + 6, mid + 9), 22.0)
			draw_string(UI.display(), Vector2(sx + 18, mid + fs * 0.36), str(streak), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.BANANA)
		# Colonne fisse da destra, numeri allineati a destra: si leggono in colonna
		var nf := UI.numbers()
		var wins := "%d/%d" % [int(data.wins), int(data.matches)]
		var ww := nf.get_string_size(wins, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(nf, Vector2(sx - 14 - ww, mid + fs * 0.36), wins, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.PAPER, 0.75))
		var pts := str(int(data.rating)) if int(data.rating) >= 0 else "—"
		var pw := nf.get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(20)).x
		var px := sx - 90 - pw
		draw_string(nf, Vector2(px, mid + fs * 0.4), pts, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(20), UI.PAPER)
		var tier := str(data.tier)
		var tx := sx - 90 - 60 - 150
		if tier != "":
			view.draw_tier(self, Vector2(tx, mid), tier, 12)
		var name_x := r.position.x + 84
		draw_string(bf, Vector2(name_x, mid + fs * 0.36), str(data.name), HORIZONTAL_ALIGNMENT_LEFT, maxf(20.0, tx - name_x - 10), fs, UI.PAPER)


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
			"characterId": str(r.get("characterId", "")) if r.get("characterId") != null else "",
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
