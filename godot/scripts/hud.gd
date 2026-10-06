# Scritte sopra la partita: percentuali e vite di tutti, tempo, stato della connessione, vincitore.
extends Control

var game: Dictionary
var my_id := ""
var status := ""
var _snap: Dictionary = {}
var _font: Font = ThemeDB.fallback_font


func on_snapshot(snap: Dictionary) -> void:
	_snap = snap
	queue_redraw()


func set_status(text: String) -> void:
	status = text
	queue_redraw()


func _draw() -> void:
	var w: float = game.world.width
	var h: float = game.world.height
	if status != "":
		_centered(status, Vector2(w / 2, 40), 22, Color.WHITE)
	if _snap.is_empty():
		return

	if _snap.timeLeftMs != null:
		var s := int(ceil(_snap.timeLeftMs / 1000.0))
		_centered("%d:%02d" % [s / 60, s % 60], Vector2(w / 2, 40), 28, Color.WHITE)

	# Una scheda per giocatore in basso, come nel gioco web
	var players: Array = _snap.players
	var card_w := 170.0
	var x0 := w / 2 - card_w * players.size() / 2
	for i in players.size():
		var p: Dictionary = players[i]
		var x := x0 + i * card_w
		var col := Color.hex((int(p.color) << 8) | 0xff)
		draw_rect(Rect2(x + 6, h - 86, card_w - 12, 74), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(x + 6, h - 86, 6, 74), col)
		var name: String = p.name + (" (tu)" if p.id == my_id else "")
		draw_string(_font, Vector2(x + 20, h - 64), name, HORIZONTAL_ALIGNMENT_LEFT, card_w - 30, 15, Color.WHITE)
		var pct := "KO" if p.eliminated else "%d%%" % roundi(p.percent)
		draw_string(_font, Vector2(x + 20, h - 30), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, _percent_color(p.percent))
		for k in int(p.stocks):
			draw_circle(Vector2(x + card_w - 24 - k * 14, h - 34), 5, col)

	if _snap.winnerId != null:
		var winner := "Pareggio!"
		for p in players:
			if p.id == _snap.winnerId:
				winner = "Vince %s!" % p.name
		draw_rect(Rect2(0, h / 2 - 70, w, 120), Color(0, 0, 0, 0.55))
		_centered(winner, Vector2(w / 2, h / 2 - 10), 48, Color(1, 0.85, 0.3))
		_centered("R per la rivincita", Vector2(w / 2, h / 2 + 32), 20, Color.WHITE)


# Dal bianco al rosso man mano che si accumula danno
func _percent_color(percent: float) -> Color:
	return Color.WHITE.lerp(Color(0.9, 0.15, 0.1), clampf(percent / 150.0, 0, 1))


func _centered(text: String, pos: Vector2, size: int, color: Color) -> void:
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(_font, Vector2(pos.x - s.x / 2, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
