# Le battute dei lottatori (#13): un fumetto sopra la testa con la frase scritta nella scheda del personaggio
# (characters.<id>.quotes in game.json). La provocazione quando provoca, l'urlo quando va KO (lì il fumetto sta
# dov'è uscito, dentro l'inquadratura). Solo disegno: parte dagli eventi taunt e ko dello snapshot.
extends Node2D

const SHOW_MS := 1800.0 # quanto resta il fumetto
const FADE_MS := 220.0 # comparsa e sparizione
const PAD := Vector2(12, 8) # margine del testo nel fumetto, pixel
const TAIL := 12.0 # la punta verso chi parla, pixel
const MAX_W := 260.0 # oltre, il testo va a capo
const INK := Color("221c1a")
const PAPER := Color("fbf7ee")

var where: Callable # id giocatore -> Vector2 della testa, o null se non c'è; lo imposta world_view
var view_rect := Rect2(0, 0, 1280, 720) # lo aggiorna world_view: i fumetti fermi restano dentro
var fixed_now := -1.0 # per i test: se >= 0 è l'orologio in ms al posto di quello vero
var _bubbles: Array = [] # [{ id, text, t0, at }]: at è null per chi segue il lottatore
var _font: Font = ThemeDB.fallback_font


func _now() -> float:
	return fixed_now if fixed_now >= 0 else float(Time.get_ticks_msec())


# La frase di un personaggio per una battuta ("taunt", "ko", "victory"), o "" se la scheda non la dice
static func quote(character: Dictionary, line: String) -> String:
	var q: Variant = character.get("quotes")
	return str(q.get(line, "")) if q is Dictionary else ""


# Un fumetto che segue il lottatore; at fisso (Vector2) per chi è già uscito dallo schermo. Uno per lottatore
func say(id: String, text: String, at: Variant = null) -> void:
	if text == "":
		return
	_bubbles = _bubbles.filter(func(b): return b.id != id)
	_bubbles.append({"id": id, "text": text, "t0": _now(), "at": at})


func clear() -> void:
	_bubbles = []


func showing(id: String) -> String:
	for b in _bubbles:
		if b.id == id and _now() - float(b.t0) < SHOW_MS:
			return b.text
	return ""


func _process(_delta: float) -> void:
	var now := _now()
	_bubbles = _bubbles.filter(func(b): return now - float(b.t0) < SHOW_MS)
	if not _bubbles.is_empty() or visible:
		queue_redraw()


func _draw() -> void:
	var now := _now()
	for b in _bubbles:
		var head: Variant = b.at if b.at != null else (where.call(b.id) if where.is_valid() else null)
		if head == null:
			continue
		var age := now - float(b.t0)
		var alpha := clampf(minf(age, SHOW_MS - age) / FADE_MS, 0.0, 1.0)
		_draw_bubble(str(b.text), head, alpha)


func _draw_bubble(text: String, head: Vector2, alpha: float) -> void:
	var px := Access.px(15)
	var lines := _wrap(text, px)
	var line_h := _font.get_height(px)
	var w := 0.0
	for l in lines:
		w = maxf(w, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var size := Vector2(w, line_h * lines.size()) + PAD * 2
	var box := Rect2(Vector2(head.x - size.x / 2, head.y - TAIL - size.y), size)
	# dentro l'inquadratura, la punta resta verso chi parla
	box.position.x = clampf(box.position.x, view_rect.position.x + 4, maxf(view_rect.position.x + 4, view_rect.end.x - size.x - 4))
	box.position.y = clampf(box.position.y, view_rect.position.y + 4, maxf(view_rect.position.y + 4, view_rect.end.y - size.y - TAIL - 4))
	var tip := Vector2(clampf(head.x, box.position.x + 14, box.end.x - 14), box.end.y + TAIL)
	var tail := PackedVector2Array([Vector2(tip.x - 8, box.end.y - 1), Vector2(tip.x + 8, box.end.y - 1), tip])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER, alpha)
	sb.border_color = Color(INK, alpha)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	draw_colored_polygon(tail, Color(INK, alpha))
	draw_style_box(sb, box)
	draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(3, -2), tail[1] + Vector2(-3, -2), tip + Vector2(0, -5)]), Color(PAPER, alpha))
	for i in lines.size():
		var at := box.position + PAD + Vector2(0, _font.get_ascent(px) + i * line_h)
		draw_string(_font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(INK, alpha))


# A capo sulle parole, entro MAX_W
func _wrap(text: String, px: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > MAX_W:
			out.append(line)
			line = word
		else:
			line = next
	out.append(line)
	return out
