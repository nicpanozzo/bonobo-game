# Bonobo Party (#579): il tabellone. Disegna caselle, Corona e pedine (i ritratti dei lottatori, nessuna animazione
# nuova: le pedine scivolano e saltellano da sole), la classifica a destra e, in basso, quello che si può fare adesso:
# tirare il dado, scegliere la strada, comprare in bottega, votare il minigioco, dare il feedback, tornare in sala.
# Non decide niente: manda comandi (signal command) e mostra il PartySnapshot che arriva dal server.
extends Control

signal command(cmd: Dictionary) # main.gd lo manda al server come messaggio "party"

const UI := preload("res://scripts/ui.gd")
const LobbyScript := preload("res://scripts/lobby.gd")
const PartyHud := preload("res://scripts/party_hud.gd")

# Le caselle (PartySquareKind in src/shared/types.ts): colore e scritta
const SQUARES := {
	"start": [Color("5ef0a0"), "VIA"],
	"banana": [Color("ffc928"), "+"],
	"buccia": [Color("b0662a"), "-"],
	"evento": [Color("b48cff"), "?"],
	"bottega": [Color("4fd1c5"), "€"],
}
const ITEM_NAMES := {"moka": "Moka", "monopattino": "Monopattino", "ciabatta": "Ciabatta", "telefono": "Telefono"} # come PARTY_ITEMS in party.ts
const SQUARE_R := 17.0 # raggio di una casella, pixel
const PAWN := 46.0 # lato di una pedina, pixel
const PAWN_SPEED := 900.0 # pixel al secondo con cui la pedina raggiunge la sua casella
const PANEL_W := 300.0 # la classifica a destra
const DICE_S := 0.7 # secondi in cui il dado "rotola" prima di fermarsi sul numero
const FLOAT_S := 1.4 # secondi di una scritta che sale da una pedina (+3, -3)

var game: Dictionary
var my_id := ""
var snap: Dictionary = {}
var _pawns := {} # id -> Vector2 disegnata
var _faces := {} # characterId -> Texture2D (o null)
var _floats: Array = [] # [{ id, text, color, age }]
var _dice_at := -10.0 # quando è arrivato l'ultimo tiro (secondi di _t)
var _dice_value := 0
var _t := 0.0
var _actions: HBoxContainer
var _actions_key := "" # cosa c'è adesso in basso: si rifanno i pulsanti solo quando cambia
var _stars := 0
var _note: LineEdit
var _star_buttons: Array = []
var _sent_feedback := false
var _display: Font
var _body: Font


func setup(game_data: Dictionary, id: String) -> void:
	game = game_data
	my_id = id
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display = UI.display()
	_body = UI.font(UI.WEIGHT_BOLD)
	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", UI.GAP_L)
	_actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	add_child(_actions)


func on_snapshot(data: Dictionary) -> void:
	var first := snap.is_empty()
	snap = data
	for e in data.get("events", []):
		_on_event(e)
	for p in data.get("players", []):
		if first or not _pawns.has(p.id):
			_pawns[p.id] = _square_pos(int(p.square))
	_sync_actions()
	queue_redraw()


func _on_event(e: Dictionary) -> void:
	match str(e.get("type", "")):
		"roll":
			_dice_at = _t
			_dice_value = int(e.get("value", 0))
		"square":
			var b := int(e.get("bananas", 0))
			if b != 0:
				_floats.append({"id": str(e.id), "text": ("+%d" % b) if b > 0 else str(b), "color": UI.BANANA if b > 0 else UI.PUNCH, "age": 0.0})
		"crown":
			_floats.append({"id": str(e.id), "text": "CORONA!", "color": UI.BANANA, "age": 0.0})
		"item":
			if e.get("targetId") != null:
				_floats.append({"id": str(e.targetId), "text": "CIABATTATA!", "color": UI.PUNCH, "age": 0.0})
		"results":
			_sent_feedback = false
			_stars = 0


func _process(delta: float) -> void:
	_t += delta
	for p in snap.get("players", []):
		var target := _square_pos(int(p.square))
		var at: Vector2 = _pawns.get(p.id, target)
		_pawns[p.id] = at.move_toward(target, PAWN_SPEED * delta)
	for f in _floats:
		f.age += delta
	_floats = _floats.filter(func(f): return f.age < FLOAT_S)
	queue_redraw()


# --- Geometria ---

func board_rect() -> Rect2:
	return Rect2(24, 96, maxf(200.0, size.x - PANEL_W - 64), maxf(200.0, size.y - 96 - 170))


func _square_pos(i: int) -> Vector2:
	var squares: Array = snap.get("squares", [])
	if i < 0 or i >= squares.size():
		return board_rect().get_center()
	return board_point(board_rect(), squares[i])


static func board_point(r: Rect2, sq: Dictionary) -> Vector2:
	return r.position + Vector2(float(sq.get("x", 0.5)) * r.size.x, float(sq.get("y", 0.5)) * r.size.y)


# Più pedine sulla stessa casella si mettono a ventaglio, così si vedono tutte
static func pawn_offset(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var a := -PI / 2 + TAU * index / count
	return Vector2.from_angle(a) * 22.0


func _player(id: Variant) -> Dictionary:
	for p in snap.get("players", []):
		if p.id == id:
			return p
	return {}


func _my_turn() -> bool:
	return snap.get("turnId") == my_id


func _face(character_id: String) -> Texture2D:
	if not _faces.has(character_id):
		var chars: Dictionary = game.get("characters", {})
		_faces[character_id] = LobbyScript.face_texture(chars[character_id]) if chars.has(character_id) else null
	return _faces[character_id]


# --- Pulsanti in basso ---

# La "firma" di quello che va mostrato: se non cambia, i pulsanti restano (e il pad non perde il fuoco)
func actions_key() -> String:
	var phase := str(snap.get("phase", ""))
	var me := _player(my_id)
	match phase:
		"roll", "path", "shop":
			return "%s:%s:%s:%s" % [phase, str(_my_turn()), str(me.get("item")), str(snap.get("shop", []))]
		"vote":
			return "vote:%s:%s" % [str(snap.get("options", []).map(func(o): return o.id)), str(snap.get("votes", {}).get(my_id, ""))]
		"feedback":
			return "feedback:%s" % str(_sent_feedback or snap.get("feedbackDone", []).has(my_id))
		"podium":
			return "podium"
	return phase


func _sync_actions() -> void:
	var key := actions_key()
	if key == _actions_key:
		return
	_actions_key = key
	for c in _actions.get_children():
		c.queue_free()
	_star_buttons = []
	_note = null
	var first: Control = null
	var phase := str(snap.get("phase", ""))
	var me := _player(my_id)
	if phase == "roll" and _my_turn():
		first = UI.button("Tira il dado!", func(): command.emit({"kind": "roll"}), true)
		_actions.add_child(first)
		if me.get("item") != null:
			_actions.add_child(UI.button("Usa %s e tira" % ITEM_NAMES.get(str(me.item), str(me.item)), func(): command.emit({"kind": "roll", "useItem": true})))
	elif phase == "path" and _my_turn():
		first = UI.button("Giro lungo", func(): command.emit({"kind": "path", "next": 0}), true)
		_actions.add_child(first)
		_actions.add_child(UI.button("Scorciatoia", func(): command.emit({"kind": "path", "next": 1})))
	elif phase == "shop" and _my_turn():
		for s in snap.get("shop", []):
			var item := str(s.item)
			var b := UI.button("%s · %d banane" % [str(s.name), int(s.price)], func(): command.emit({"kind": "buy", "item": item}))
			b.disabled = int(me.get("bananas", 0)) < int(s.price)
			_actions.add_child(b)
			if first == null and not b.disabled:
				first = b
		var none := UI.button("Niente, grazie", func(): command.emit({"kind": "buy", "item": null}))
		_actions.add_child(none)
		if first == null:
			first = none
	elif phase == "vote":
		var mine := str(snap.get("votes", {}).get(my_id, ""))
		for o in snap.get("options", []):
			var id := str(o.id)
			var card := UI.choice_card(str(o.title), PartyHud.category_name(str(o.get("category", ""))), func(): command.emit({"kind": "vote", "minigameId": id}), UI.SIZE_BODY + 3)
			card.custom_minimum_size = Vector2(230, 84)
			UI.set_selected(card, id == mine)
			_actions.add_child(card)
			if first == null:
				first = card
	elif phase == "feedback" and not (_sent_feedback or snap.get("feedbackDone", []).has(my_id)):
		first = _build_feedback()
	elif phase == "podium":
		first = UI.button("Torna in sala", func(): command.emit({"kind": "hall"}), true)
		_actions.add_child(first)
	_actions.reset_size()
	_place_actions()
	if first != null and is_inside_tree():
		first.grab_focus.call_deferred()


func _place_actions() -> void:
	_actions.position = Vector2((size.x - PANEL_W - _actions.size.x) / 2.0, size.y - _actions.size.y - 28)


# Le stelle, la riga di testo e Invia/Salta
func _build_feedback() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.GAP_S)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", UI.GAP_S)
	for n in range(1, 6):
		var b := UI.small_button("★", func(): _set_stars(n))
		b.custom_minimum_size = Vector2(44, 40)
		b.tooltip_text = "%d su 5" % n
		stars.add_child(b)
		_star_buttons.append(b)
	box.add_child(stars)
	_note = LineEdit.new()
	_note.placeholder_text = "Cosa cambieresti? (facoltativo)"
	_note.max_length = 500
	_note.custom_minimum_size = Vector2(460, 40)
	_note.text_submitted.connect(func(_t): _send_feedback())
	box.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP_M)
	row.add_child(UI.button("Invia", _send_feedback, true))
	row.add_child(UI.button("Salta", func(): _send_feedback(true)))
	box.add_child(row)
	_actions.add_child(box)
	_set_stars(_stars)
	return _star_buttons[0]


func _set_stars(n: int) -> void:
	_stars = n
	for i in _star_buttons.size():
		var b: Button = _star_buttons[i]
		b.add_theme_color_override("font_color", UI.BANANA if i < n else Color(UI.LILAC, 0.5))
		b.add_theme_color_override("font_focus_color", UI.BANANA if i < n else UI.PAPER)


func _send_feedback(skip := false) -> void:
	if _sent_feedback:
		return
	_sent_feedback = true
	var text := "" if skip or _note == null else _note.text.strip_edges()
	command.emit({"kind": "feedback", "stars": 0 if skip else _stars, "text": text})
	_sync_actions()


# --- Disegno ---

func _draw() -> void:
	if snap.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), UI.NIGHT)
	_place_actions()
	var r := board_rect()
	_draw_paths(r)
	_draw_squares(r)
	_draw_crown(_square_pos(int(snap.get("crownSquare", 0))))
	_draw_pawns()
	_draw_header()
	_draw_standings()
	_draw_middle()


func _draw_paths(r: Rect2) -> void:
	var squares: Array = snap.get("squares", [])
	for i in squares.size():
		var a := board_point(r, squares[i])
		for n in squares[i].get("next", []):
			if int(n) >= 0 and int(n) < squares.size():
				var b := board_point(r, squares[int(n)])
				draw_line(a, b, UI.INK, 12.0)
				draw_line(a, b, UI.GRAPE_HI, 6.0)


func _draw_squares(r: Rect2) -> void:
	var squares: Array = snap.get("squares", [])
	for i in squares.size():
		var sq: Dictionary = squares[i]
		var c := board_point(r, sq)
		var spec: Array = SQUARES.get(str(sq.get("kind", "")), [UI.LILAC, ""])
		var fork: bool = sq.get("next", []).size() > 1
		draw_circle(c + Vector2(0, 4), SQUARE_R, UI.INK)
		draw_circle(c, SQUARE_R, spec[0])
		draw_arc(c, SQUARE_R, 0, TAU, 24, UI.INK, 3.0, true)
		if fork:
			draw_arc(c, SQUARE_R + 6, 0, TAU, 24, UI.PAPER, 2.0, true)
		var label: String = spec[1]
		var px := Access.px(14 if label.length() > 1 else 18)
		var w := _display.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(_display, c + Vector2(-w / 2, px * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UI.INK)


# La Corona: tre punte d'oro sopra la casella, che dondola un po'
func _draw_crown(c: Vector2) -> void:
	var at := c + Vector2(0, -SQUARE_R - 18 + sin(_t * 3.0) * 3.0)
	_crown(at, 1.0)


func _crown(at: Vector2, k: float) -> void:
	var pts := PackedVector2Array([
		at + Vector2(-16, 8) * k, at + Vector2(-18, -8) * k, at + Vector2(-8, 0) * k, at + Vector2(0, -12) * k,
		at + Vector2(8, 0) * k, at + Vector2(18, -8) * k, at + Vector2(16, 8) * k,
	])
	draw_colored_polygon(pts, Color("ffd700"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), UI.INK, 2.5 * k, true)


func _draw_pawns() -> void:
	var players: Array = snap.get("players", [])
	var by_square := {}
	for p in players:
		by_square[int(p.square)] = by_square.get(int(p.square), []) + [p.id]
	var turn = snap.get("turnId")
	# Chi è di turno si disegna per ultimo, sopra gli altri
	var order := players.duplicate()
	order.sort_custom(func(a, b): return a.id != turn and b.id == turn)
	for p in order:
		var group: Array = by_square.get(int(p.square), [p.id])
		var target := _square_pos(int(p.square))
		var at: Vector2 = _pawns.get(p.id, target)
		var moving := at.distance_to(target) > 2.0
		var hop := -absf(sin(_t * 14.0)) * 12.0 if moving else 0.0
		var c := at + pawn_offset(group.find(p.id), group.size()) + Vector2(0, -26 + hop)
		var col := Access.color(p.get("color", 0xffffff))
		var rect := Rect2(c - Vector2(PAWN, PAWN) / 2, Vector2(PAWN, PAWN))
		if p.id == turn:
			draw_circle(c, PAWN * 0.75 + sin(_t * 6.0) * 3.0, Color(UI.BANANA, 0.35))
		draw_circle(c + Vector2(0, 3), PAWN / 2 + 3, UI.INK)
		draw_circle(c, PAWN / 2 + 1, col)
		var face := _face(str(p.get("characterId", "")))
		if face != null:
			draw_texture_rect(face, rect.grow(-5), false)
		if p.get("away", false):
			draw_circle(c, PAWN / 2, Color(0, 0, 0, 0.5))
	for f in _floats:
		var p := _player(f.id)
		if p.is_empty():
			continue
		var at: Vector2 = _pawns.get(f.id, Vector2.ZERO)
		var k: float = f.age / FLOAT_S
		var px := Access.px(24)
		var w := _display.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		UI.draw_sticker(self, _display, at + Vector2(-w / 2, -70 - k * 50), f.text, px, Color(f.color, 1.0 - k * k), 5, Vector2(0, 3))


func _draw_header() -> void:
	var round_text := "GIRO %d DI %d" % [int(snap.get("round", 1)), int(snap.get("rounds", 1))]
	UI.draw_sticker(self, _display, Vector2(28, 52), "BONOBO PARTY", Access.px(34), UI.BANANA, 7, Vector2(2, 4))
	draw_string(_display, Vector2(30, 82), round_text + ("   ·   minigioco a voto" if snap.get("pick") == "vote" else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(18), UI.LILAC)


func _draw_standings() -> void:
	var x := size.x - PANEL_W - 16
	var r := Rect2(x, 24, PANEL_W, 60 + snap.get("players", []).size() * 66)
	draw_style_box(UI.panel_box(Color(UI.GRAPE, 0.95), 14), r)
	draw_string(_display, Vector2(x + 18, 56), "CLASSIFICA", HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(20), UI.BANANA)
	var players: Array = snap.get("players", []).duplicate()
	players.sort_custom(func(a, b): return int(a.place) < int(b.place) or (int(a.place) == int(b.place) and str(a.name) < str(b.name)))
	var y := 76.0
	for p in players:
		var mine: bool = p.id == my_id
		if mine:
			draw_rect(Rect2(x + 8, y - 4, PANEL_W - 16, 62), Color(UI.BANANA, 0.12))
		draw_string(_display, Vector2(x + 16, y + 34), "%d°" % int(p.place), HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(22), UI.BANANA if int(p.place) == 1 else UI.PAPER)
		var face := _face(str(p.get("characterId", "")))
		draw_circle(Vector2(x + 82, y + 26), 25, Access.color(p.get("color", 0xffffff)))
		if face != null:
			draw_texture_rect(face, Rect2(x + 60, y + 4, 44, 44), false)
		var name := str(p.get("name", "?")) + (" (tu)" if mine else "") + (" · bot" if p.get("bot", false) else "")
		draw_string(_body, Vector2(x + 116, y + 18), name, HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 124, Access.px(UI.SIZE_SMALL + 1), UI.PAPER)
		_crown(Vector2(x + 128, y + 40), 0.6)
		draw_string(_display, Vector2(x + 142, y + 46), str(int(p.get("crowns", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(18), UI.PAPER)
		draw_circle(Vector2(x + 184, y + 39), 7, UI.BANANA)
		draw_string(_display, Vector2(x + 196, y + 46), str(int(p.get("bananas", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(18), UI.PAPER)
		if p.get("item") != null:
			draw_string(_body, Vector2(x + 232, y + 46), ITEM_NAMES.get(str(p.item), str(p.item)), HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 236, Access.px(UI.SIZE_NOTE), UI.MINT)
		y += 66


# In mezzo al tabellone: il dado, la scritta del momento, il minigioco scelto, il podio
func _draw_middle() -> void:
	var r := board_rect()
	var c := r.get_center()
	var phase := str(snap.get("phase", ""))
	var since := _t - _dice_at
	if since < DICE_S + 1.2 and phase in ["move", "roll", "path", "shop"]:
		var value := _dice_value if since >= DICE_S else 1 + int(_t * 18.0) % 6
		_draw_die(c + Vector2(0, -40), value, since < DICE_S)
	var text := str(snap.get("text", "")) if snap.get("text") != null else ""
	var turn := _player(snap.get("turnId"))
	if phase == "roll" and not turn.is_empty():
		text = "Tocca a te: tira il dado!" if _my_turn() else "Tocca a %s" % str(turn.get("name", "?"))
	elif phase == "path" and not _my_turn() and not turn.is_empty():
		text = "%s sceglie la strada" % str(turn.get("name", "?"))
	elif phase == "shop" and not _my_turn() and not turn.is_empty():
		text = "%s è in bottega" % str(turn.get("name", "?"))
	elif phase == "vote":
		text = "Votate il minigioco! (%d s)" % ceili(float(snap.get("phaseLeftMs", 0)) / 1000.0)
	elif phase == "feedback":
		text = "Com'era? Lascia un voto e due parole: ci servono per migliorarlo" if not snap.get("feedbackDone", []).has(my_id) else "Grazie! Aspettiamo gli altri..."
	if phase == "minigame" and not snap.get("options", []).is_empty():
		_draw_reveal(c, snap.options[0])
		return
	if phase == "podium":
		_draw_podium(c)
	if text != "":
		var px := Access.px(26)
		var w := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		UI.draw_sticker(self, _display, Vector2(c.x - w / 2, r.end.y + 40), text, px, UI.PAPER, 6, Vector2(2, 4))
	if phase == "vote":
		_draw_votes()


func _draw_die(c: Vector2, value: int, rolling: bool) -> void:
	var s := 84.0
	var rot := sin(_t * 30.0) * 0.3 if rolling else 0.0
	draw_set_transform(c, rot, Vector2.ONE)
	var rect := Rect2(-s / 2, -s / 2, s, s)
	draw_rect(rect.grow(4), UI.INK)
	draw_rect(rect, UI.PAPER)
	var pips := die_pips(value)
	for p in pips:
		draw_circle(p * s * 0.28, 8.0, UI.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not rolling and value > 6:
		var px := Access.px(40)
		var t := str(value)
		var w := _display.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		UI.draw_sticker(self, _display, c + Vector2(-w / 2, 80), t, px, UI.BANANA, 7, Vector2(2, 4))


# I puntini di una faccia del dado, in unità da -1 a 1; oltre il 6 (moka, monopattino) si mostra il 6 e il numero sotto
static func die_pips(value: int) -> Array:
	match clampi(value, 1, 6):
		1:
			return [Vector2.ZERO]
		2:
			return [Vector2(-1, -1), Vector2(1, 1)]
		3:
			return [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)]
		4:
			return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
		5:
			return [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)]
	return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]


# Il minigioco scelto, in grande prima di partire
func _draw_reveal(c: Vector2, o: Dictionary) -> void:
	var r := Rect2(c.x - 300, c.y - 110, 600, 220)
	draw_style_box(UI.panel_box(Color(UI.GRAPE, 0.97)), r)
	var cat := str(o.get("category", ""))
	var tag := PartyHud.category_name(cat).to_upper()
	var tpx := Access.px(16)
	var tw := _display.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
	UI.draw_plate(self, Rect2(c.x - tw / 2 - 12, r.position.y - 14, tw + 24, tpx + 12), PartyHud.category_color(cat), 8.0, UI.INK, 2.5, Vector2(2, 3))
	draw_string(_display, Vector2(c.x - tw / 2, r.position.y + tpx - 4), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, UI.INK)
	var title := str(o.get("title", ""))
	var px := Access.px(44)
	var w := _display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	UI.draw_sticker(self, _display, Vector2(c.x - w / 2, r.position.y + 76), title, px, UI.BANANA, 8, Vector2(2, 5))
	draw_multiline_string(_body, Vector2(r.position.x + 30, r.position.y + 118), str(o.get("howTo", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 60, Access.px(UI.SIZE_BODY), 3, UI.PAPER)


# Chi ha votato cosa, sopra le schede del voto
func _draw_votes() -> void:
	var votes: Dictionary = snap.get("votes", {})
	var count := {}
	for id in votes:
		count[votes[id]] = int(count.get(votes[id], 0)) + 1
	var parts: Array = []
	for o in snap.get("options", []):
		parts.append("%s: %d" % [str(o.title), int(count.get(o.id, 0))])
	var line := "   ·   ".join(parts)
	var px := Access.px(UI.SIZE_SMALL + 1)
	var w := _body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_body, Vector2((size.x - PANEL_W - w) / 2, size.y - 140), line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UI.LILAC)


# Il podio: i primi tre su tre gradini, col ritratto sopra
func _draw_podium(c: Vector2) -> void:
	var players: Array = snap.get("players", []).duplicate()
	players.sort_custom(func(a, b): return int(a.place) < int(b.place))
	var steps := [[0, 150.0], [-1, 105.0], [1, 70.0]] # posto -> [lato, altezza del gradino]
	for i in mini(3, players.size()):
		var p: Dictionary = players[i]
		var side: int = steps[i][0]
		var hgt: float = steps[i][1]
		var base := c + Vector2(side * 150, 120)
		var step_rect := Rect2(base.x - 65, base.y - hgt, 130, hgt)
		draw_rect(step_rect.grow(3), UI.INK)
		draw_rect(step_rect, [Color("ffd700"), Color("d9d9e6"), Color("d08a4a")][i])
		draw_string(_display, Vector2(base.x - 14, base.y - hgt + 44), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(36), UI.INK)
		var face := _face(str(p.get("characterId", "")))
		var head := Vector2(base.x, base.y - hgt - 44)
		draw_circle(head, 40, Access.color(p.get("color", 0xffffff)))
		if face != null:
			draw_texture_rect(face, Rect2(head - Vector2(36, 36), Vector2(72, 72)), false)
		if i == 0:
			_crown(head + Vector2(0, -52), 1.4)
		var name := str(p.get("name", "?"))
		var w := _body.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(UI.SIZE_BODY)).x
		draw_string(_body, Vector2(base.x - w / 2, base.y + 26), name, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(UI.SIZE_BODY), UI.PAPER)
