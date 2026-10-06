# Scritte sopra la partita: percentuali e vite di tutti, tempo, stato della connessione, vincitore.
extends Control

var game: Dictionary
var my_id := ""
var rules: Dictionary = {}
var _winner_team := 0 # squadra vincitrice dall'evento matchEnd, 0 se nessuna
var _ended := false
var status := ""
var _snap: Dictionary = {}
var _font: Font = ThemeDB.fallback_font


func on_snapshot(snap: Dictionary) -> void:
	_snap = snap
	for e in snap.events:
		if e.type == "matchStart":
			_ended = false
			_winner_team = 0
		elif e.type == "matchEnd":
			_ended = true
			_winner_team = int(e.winnerTeam)
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

	var y := 40.0
	if _snap.timeLeftMs != null:
		var s := int(ceil(_snap.timeLeftMs / 1000.0))
		_centered("%d:%02d" % [s / 60, s % 60], Vector2(w / 2, y), 28, Color.WHITE)
		y += 34
	# Bandiera: punti delle due squadre
	if _snap.get("teamScores") != null:
		var names: Dictionary = game.teamNames
		_centered("%s %d  –  %d %s" % [names["1"], _snap.teamScores["1"], _snap.teamScores["2"], names["2"]], Vector2(w / 2, y), 26, Color.WHITE)

	# Una scheda per giocatore in basso, come nel gioco web
	var players: Array = _snap.players
	var card_w := minf(170.0, (w - 20) / maxi(1, players.size())) # fino a 8 giocatori in una riga
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
		draw_string(_font, Vector2(x + 20, h - 30), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, _percent_color(p.percent))
		# Vite, tranne in Corsa (infinite) e in Bandiera (lì conta chi porta la bandiera)
		var mode: String = rules.get("mode", "ffa")
		if mode == "flag":
			if p.get("carrier", false):
				draw_colored_polygon(PackedVector2Array([Vector2(x + card_w - 34, h - 44), Vector2(x + card_w - 14, h - 37), Vector2(x + card_w - 34, h - 30)]), col)
		elif mode != "race":
			for k in int(p.stocks):
				draw_circle(Vector2(x + card_w - 24 - k * 14, h - 34), 5, col)

	if _ended or _snap.winnerId != null:
		var winner := "Pareggio!"
		if _winner_team > 0 and rules.get("mode", "ffa") != "ffa":
			winner = "Vince la squadra %s!" % game.teamNames[str(_winner_team)]
		else:
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
