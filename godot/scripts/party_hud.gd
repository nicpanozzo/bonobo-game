# Bonobo Party (#579): sopra l'arena di un minigioco. Nella prova libera (il pre-partita) la scheda "come si gioca"
# in basso; durante il gioco titolo, tempo, punti di tutti e la scritta del momento; alla fine i posti d'arrivo.
# Solo disegno: tutto arriva dallo snapshot (snapshot.party) e dal messaggio stage (minigame).
extends Control

const UI := preload("res://scripts/ui.gd")

# Le categorie dei minigiochi (MinigameCategory in src/shared/types.ts): nome e colore della targhetta
const CATEGORIES := {
	"arraffa": ["Arraffa", Color("ffc928")],
	"unoContro": ["Uno contro tutti", Color("ff4560")],
	"platform": ["Platform", Color("5ec8ff")],
	"ritmo": ["Ritmo e riflessi", Color("ff8ad8")],
	"puzzle": ["Puzzle", Color("5ef0a0")],
	"classici": ["Classici riadattati", Color("ff8a2a")],
	"pazze": ["Idee pazze", Color("b48cff")],
}
const CARD_W := 640.0 # la scheda "come si gioca", pixel
const ROW_H := 30.0

var game: Dictionary
var my_id := ""
var info: Dictionary = {} # MinigameInfo dell'ultimo stage; {} = non è un minigioco
var _hud: Dictionary = {} # snapshot.party
var _pre: Dictionary = {}
var _names := {} # id -> nome
var _colors := {} # id -> colore
var _display: Font
var _body: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display = UI.display()
	_body = UI.font(UI.WEIGHT_BOLD)


func active() -> bool:
	return not info.is_empty()


func start(minigame: Dictionary) -> void:
	info = minigame
	_hud = {}
	_pre = {}
	queue_redraw()


func reset() -> void:
	info = {}
	_hud = {}
	_pre = {}
	queue_redraw()


func on_snapshot(snap: Dictionary) -> void:
	if not active():
		return
	_hud = snap.get("party", {}) if snap.get("party") is Dictionary else {}
	_pre = snap.get("prematch", {}) if snap.get("prematch") is Dictionary else {}
	for p in snap.get("players", []):
		if p.get("ghostOf") == null:
			_names[str(p.id)] = str(p.get("name", "?"))
			_colors[str(p.id)] = Access.color(p.get("color", 0xffffff))
	queue_redraw()


static func category_name(cat: String) -> String:
	return str(CATEGORIES.get(cat, [cat, Color.WHITE])[0])


static func category_color(cat: String) -> Color:
	return CATEGORIES.get(cat, ["", Color.WHITE])[1]


# Il tempo come lo si legge in un colpo d'occhio: "0:42", o "" senza tempo
static func clock_text(left_ms: Variant) -> String:
	if left_ms == null:
		return ""
	var s := ceili(float(left_ms) / 1000.0)
	return "%d:%02d" % [s / 60, s % 60]


# I punti in classifica: [[id, punti], ...] dal più alto (a pari punti per nome, così non saltano)
static func ranking(scores: Dictionary, names: Dictionary) -> Array:
	var rows: Array = []
	for id in scores:
		rows.append([str(id), int(scores[id])])
	rows.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and str(names.get(a[0], a[0])) < str(names.get(b[0], b[0]))))
	return rows


func _draw() -> void:
	if not active():
		return
	var w := size.x
	var h := size.y
	if _hud.get("places") is Dictionary:
		_draw_places(w, h)
	elif not _pre.is_empty():
		_draw_how_to(w, h)
	else:
		_draw_playing(w, h)


# La scheda in basso nella prova libera: categoria, titolo, come si gioca, tasti, e il mio ruolo se ne ho uno
func _draw_how_to(w: float, h: float) -> void:
	var cat := str(info.get("category", ""))
	var r := Rect2(w / 2 - CARD_W / 2, h - 236, CARD_W, 200)
	draw_style_box(UI.panel_box(Color(UI.GRAPE, 0.95)), r)
	var tag := category_name(cat).to_upper()
	var tpx := Access.px(15)
	var tw := _display.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
	UI.draw_plate(self, Rect2(r.position.x + 24, r.position.y - 12, tw + 22, tpx + 10), category_color(cat), 8.0, UI.INK, 2.5, Vector2(2, 3))
	draw_string(_display, Vector2(r.position.x + 35, r.position.y + tpx - 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, UI.INK)
	UI.draw_sticker(self, _display, Vector2(r.position.x + 24, r.position.y + 52), str(info.get("title", "")), Access.px(32), UI.BANANA, 6, Vector2(2, 4))
	var bpx := Access.px(UI.SIZE_BODY)
	draw_multiline_string(_body, Vector2(r.position.x + 24, r.position.y + 84), str(info.get("howTo", "")), HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 48, bpx, 3, UI.PAPER)
	var keys := "Tasti: " + str(info.get("keys", ""))
	draw_string(_body, Vector2(r.position.x + 24, r.end.y - 44), keys, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 48, Access.px(UI.SIZE_SMALL), UI.LILAC)
	var roles: Dictionary = info.get("roles", {}) if info.get("roles") is Dictionary else {}
	if roles.has(my_id):
		draw_string(_display, Vector2(r.position.x + 24, r.end.y - 16), "Tu sei: " + str(roles[my_id]), HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(20), UI.PUNCH)
	else:
		draw_string(_body, Vector2(r.position.x + 24, r.end.y - 16), "Prova pure i tasti: non conta finché non parte.", HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(UI.SIZE_SMALL), Color(UI.LILAC, 0.8))


# In alto: titolo e tempo, a destra i punti; in mezzo la scritta del momento
func _draw_playing(w: float, _h: float) -> void:
	var title := str(info.get("title", ""))
	var clock := clock_text(_hud.get("leftMs"))
	var tpx := Access.px(22)
	UI.draw_sticker(self, _display, Vector2(24, 40), title + ("   " + clock if clock != "" else ""), tpx, UI.BANANA, 5, Vector2(2, 3))
	var rows := ranking(_hud.get("scores", {}) if _hud.get("scores") is Dictionary else {}, _names)
	var out: Array = _hud.get("out", []) if _hud.get("out") is Array else []
	var unit := str(_hud.get("unit", "punti"))
	var y := 74.0
	for row in rows:
		var id: String = row[0]
		var col: Color = _colors.get(id, Color.WHITE)
		var faded := 0.45 if out.has(id) else 1.0
		UI.draw_plate(self, Rect2(24, y - 16, 14, 18), Color(col, faded), 5.0, UI.INK, 2.0)
		var label := str(_names.get(id, id)) + (" (tu)" if id == my_id else "")
		draw_string(_body, Vector2(46, y), label, HORIZONTAL_ALIGNMENT_LEFT, 200, Access.px(UI.SIZE_SMALL + 1), Color(UI.PAPER, faded))
		draw_string(_display, Vector2(250, y), "%d %s" % [row[1], unit], HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(UI.SIZE_SMALL + 2), Color(UI.BANANA, faded))
		y += ROW_H
	var text := str(_hud.get("text", "")) if _hud.get("text") != null else ""
	if text != "":
		var px := Access.px(30)
		var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		UI.draw_sticker(self, _display, Vector2(w / 2 - tw / 2, 120), text, px, UI.PAPER, 6, Vector2(2, 4))


# Fine minigioco: i posti, prima del ritorno al tabellone
func _draw_places(w: float, h: float) -> void:
	var places: Dictionary = _hud.places
	var ids: Array = places.keys()
	ids.sort_custom(func(a, b): return int(places[a]) < int(places[b]) or (int(places[a]) == int(places[b]) and str(a) < str(b)))
	var r := Rect2(w / 2 - 260, h / 2 - 40 - ids.size() * 20, 520, 90 + ids.size() * 40)
	draw_style_box(UI.panel_box(Color(UI.GRAPE, 0.96)), r)
	UI.draw_sticker(self, _display, Vector2(r.position.x + 24, r.position.y + 50), str(info.get("title", "")), Access.px(28), UI.BANANA, 6, Vector2(2, 4))
	var scores: Dictionary = _hud.get("scores", {}) if _hud.get("scores") is Dictionary else {}
	var y := r.position.y + 96
	for id in ids:
		var place := int(places[id])
		var col := UI.BANANA if place == 1 else UI.PAPER
		draw_string(_display, Vector2(r.position.x + 28, y), "%d°" % place, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(24), col)
		UI.draw_plate(self, Rect2(r.position.x + 84, y - 18, 14, 20), _colors.get(str(id), Color.WHITE), 5.0, UI.INK, 2.0)
		draw_string(_body, Vector2(r.position.x + 108, y), str(_names.get(str(id), id)) + (" (tu)" if str(id) == my_id else ""), HORIZONTAL_ALIGNMENT_LEFT, 250, Access.px(UI.SIZE_BODY), UI.PAPER)
		draw_string(_display, Vector2(r.end.x - 120, y), "%d %s" % [int(scores.get(id, 0)), str(_hud.get("unit", ""))], HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(UI.SIZE_BODY), UI.LILAC)
		y += 40
