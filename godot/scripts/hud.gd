# Scritte sopra la partita, come src/client/render/hud.ts e results.ts: riga della stanza,
# schede con percentuale e vite, tempo, punti della Bandiera, vincitore e classifica di fine partita.
extends Control

const MODE_NAMES := {"ffa": "Tutti contro tutti", "teams": "Squadre", "flag": "Bandiera", "race": "Corsa", "training": "Allenamento"}
const LAST_SECONDS := 10 # il tempo diventa rosso negli ultimi secondi

var game: Dictionary
var my_id := ""
var rules: Dictionary = {}
var status := ""
var rematch_key := "R" # o il pulsante del pad, se si gioca col pad (main.gd)
var _info := "" # riga in alto a sinistra: stanza, arena, modalità
var _stage: Dictionary = {}
var _snap: Dictionary = {}
var _stats := {} # id -> { kos, falls, damage, flags }: la classifica di fine partita, dagli eventi
var _font: Font = UI.font()
var _last_percent := {} # id -> percentuale dell'ultimo snapshot, per accorgersi dei colpi presi
var _jolts := {} # id -> { ms, amp }: la percentuale trema per un attimo dopo un colpo
var _supreme_full := false # qualcuno ha la barra della suprema piena (#101): la barra pulsa, si ridisegna sempre


func reset() -> void:
	my_id = ""
	status = ""
	_info = ""
	_snap = {}
	_stats = {}
	_last_percent = {}
	_jolts = {}
	_supreme_full = false
	queue_redraw()


func on_welcome(data: Dictionary, stage: Dictionary) -> void:
	my_id = data.id
	rules = data.rules
	_stage = stage
	var mode: String = MODE_NAMES.get(rules.mode, rules.mode)
	if rules.mode == "flag":
		mode += " a %d %s" % [rules.stocks, "punto" if int(rules.stocks) == 1 else "punti"]
	_info = "Stanza: %s · %s · %s · manda il link agli amici" % [data.room, stage.get("name", data.stageId), mode]
	queue_redraw()


func on_snapshot(snap: Dictionary) -> void:
	_snap = snap
	for e in snap.events:
		match e.type:
			"matchStart":
				_stats = {}
			"hit":
				_stat(e.attackerId).damage += e.damage
			"flag":
				if e.byId != null:
					_stat(e.byId).flags += 1
			"ko":
				_stat(e.id).falls += 1
				if e.byId != null:
					_stat(e.byId).kos += 1
	# Più danno in un colpo, più la percentuale trema
	var fx: Dictionary = game.effects
	for p in snap.players:
		var before: float = _last_percent.get(p.id, p.percent)
		if p.percent > before:
			var amp: float = minf(fx.percentShakeMax, (p.percent - before) * fx.percentShakePerDamage)
			_jolts[p.id] = {"ms": float(fx.percentShakeMs), "amp": maxf(amp, _jolts.get(p.id, {}).get("amp", 0.0))}
		_last_percent[p.id] = p.percent
	_supreme_full = false
	for p in snap.players:
		if not p.eliminated and float(p.get("supreme", 0)) >= _supreme_max():
			_supreme_full = true
	queue_redraw()


func _process(delta: float) -> void:
	if _supreme_full:
		queue_redraw() # la barra piena pulsa
	if _jolts.is_empty():
		return
	for id in _jolts.keys():
		_jolts[id].ms -= delta * 1000.0
		if _jolts[id].ms <= 0:
			_jolts.erase(id)
	queue_redraw()


func set_status(text: String) -> void:
	status = text
	queue_redraw()


func _stat(id: String) -> Dictionary:
	if not _stats.has(id):
		_stats[id] = {"kos": 0, "falls": 0, "damage": 0, "flags": 0}
	return _stats[id]


func _draw() -> void:
	var w: float = game.world.width
	var h: float = game.world.height
	var top_line := status if status != "" else _info
	if top_line != "":
		_outlined(top_line, Vector2(12, 26), 16, Color.WHITE)
	if _snap.is_empty():
		return

	var y := 70.0
	var scores: Variant = _snap.get("teamScores")
	if _snap.timeLeftMs != null:
		var s := int(ceil(_snap.timeLeftMs / 1000.0))
		# Bandiera a pari punti allo scadere: si gioca finché qualcuno segna
		var golden: bool = s == 0 and scores != null and scores["1"] == scores["2"] and _snap.winnerId == null
		var text := "Punto d'oro!" if golden else "%d:%02d" % [s / 60, s % 60]
		_centered(text, Vector2(w / 2, y), 28, Color("ff5a4a") if s <= LAST_SECONDS else Color.WHITE)
		y += 34 * Access.text_scale
	if scores != null:
		var names: Dictionary = game.teamNames
		_centered("%s %d  –  %d %s" % [names["1"], scores["1"], scores["2"], names["2"]], Vector2(w / 2, y), 24, Color.WHITE)

	# Con il testo più grande le schede crescono tutte insieme, a partire dal fondo dello schermo
	var k := Access.text_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	_draw_cards(w / k, h / k, scores != null)
	draw_set_transform(Vector2.ZERO)
	if _snap.winnerId != null:
		_draw_results(w, h)


# Una scheda per giocatore in basso
func _draw_cards(w: float, h: float, flag: bool) -> void:
	var players: Array = _snap.players
	var card_w := minf(170.0, (w - 20) / maxi(1, players.size())) # fino a 8 giocatori in una riga
	var x0 := w / 2 - card_w * players.size() / 2
	for i in players.size():
		var p: Dictionary = players[i]
		var x := x0 + i * card_w
		var col := Access.color(p.color)
		draw_rect(Rect2(x + 6, h - 86, card_w - 12, 74), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(x + 6, h - 86, 6, 74), col)
		var name: String = p.name + (" (tu)" if p.id == my_id else "")
		# Barra della suprema piena: "SUPREMA!" sta sulla riga del nome, a destra (sotto c'erano le vite)
		var supreme_full: bool = not p.eliminated and float(p.get("supreme", 0)) >= _supreme_max()
		var name_w := card_w - 30 - (62.0 if supreme_full else 0.0)
		draw_string(_font, Vector2(x + 20, h - 64), name, HORIZONTAL_ALIGNMENT_LEFT, name_w, 15, Color.WHITE)
		if supreme_full:
			draw_string(_font, Vector2(x + card_w - 72, h - 65), "SUPREMA!", HORIZONTAL_ALIGNMENT_RIGHT, 58, 11, UI.ACCENT)
		var pct := "OUT" if p.eliminated else "%d%%" % roundi(p.percent)
		var pos := Vector2(x + 20, h - 30)
		var size := 28
		if _jolts.has(p.id) and not p.eliminated and not Access.calm:
			var j: Dictionary = _jolts[p.id]
			var left: float = j.ms / game.effects.percentShakeMs
			pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * j.amp * left
			size = roundi(28 * (1.0 + 0.3 * left * j.amp / game.effects.percentShakeMax))
		draw_string(_font, pos, pct, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _percent_color(p.percent, p.eliminated))
		if not p.eliminated:
			_draw_supreme(Rect2(x + 20, h - 23, card_w - 40, 5), float(p.get("supreme", 0)))
		if _stage.get("goal") != null:
			# Corsa: quanta strada si è fatta
			draw_string(_font, Vector2(x + card_w - 62, h - 30), "%d%%" % _progress(p.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.ACCENT)
		elif flag:
			# Bandiera: le vite sono infinite, si segna chi porta la bandiera
			if p.get("carrier", false):
				draw_colored_polygon(PackedVector2Array([Vector2(x + card_w - 34, h - 44), Vector2(x + card_w - 14, h - 37), Vector2(x + card_w - 34, h - 30)]), col)
		elif rules.get("mode", "ffa") != "training": # in allenamento le vite sono infinite
			for k in int(rules.get("stocks", 3)):
				var c := Vector2(x + card_w - 24 - k * 13, h - 34)
				if k < int(p.stocks):
					draw_circle(c, 5, col)
				else:
					draw_arc(c, 5, 0, TAU, 12, col, 1.5)


# Barra della suprema (#101) sotto la percentuale. Piena diventa dorata, più spessa e pulsa
# (ferma con l'opzione "calma"); la scritta "SUPREMA!" la mette la scheda, sulla riga del nome
func _draw_supreme(r: Rect2, value: float) -> void:
	var t := clampf(value / _supreme_max(), 0.0, 1.0)
	draw_rect(r, Color(1, 1, 1, 0.18))
	if t < 1.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * t, r.size.y)), Color("8fd3ff"))
		return
	var pulse := 1.0 if Access.calm else 0.65 + 0.35 * sin(Time.get_ticks_msec() / 110.0)
	draw_rect(r.grow(2), Color(UI.ACCENT, 0.45 * pulse))
	draw_rect(r, Color(UI.ACCENT, pulse).lerp(Color.WHITE, 0.25 * pulse))


func _supreme_max() -> float:
	return float(game.get("supreme", {}).get("max", 100))


# Vincitore e classifica: chi ha vinto in cima, poi bandiere, KO e danni (come results.ts)
func _draw_results(w: float, _h: float) -> void:
	var players: Array = _snap.players.duplicate()
	var winner: Dictionary = {}
	for p in players:
		if p.id == _snap.winnerId:
			winner = p
	var title := "Pareggio!"
	if not winner.is_empty():
		var team: bool = rules.get("mode", "ffa") != "ffa"
		title = ("Squadra %s vince!" % game.teamNames[str(int(winner.team))]) if team else "%s vince!" % winner.name
	_centered(title, Vector2(w / 2, 200), 48, UI.ACCENT)

	players.sort_custom(func(a, b):
		var sa := _stat(a.id)
		var sb := _stat(b.id)
		if (a.id == _snap.winnerId) != (b.id == _snap.winnerId):
			return a.id == _snap.winnerId
		if sa.flags != sb.flags:
			return sa.flags > sb.flags
		if sa.kos != sb.kos:
			return sa.kos > sb.kos
		return sa.damage > sb.damage)
	var flag: bool = _snap.get("teamScores") != null
	var rows: Array[String] = []
	for p in players:
		var s := _stat(p.id)
		var crown := "* " if p.id == _snap.winnerId else ""
		var flags := "bandiere %d · " % s.flags if flag else ""
		rows.append("%s%s   %sKO %d · cadute %d · danni %d%%" % [crown, p.name, flags, s.kos, s.falls, s.damage])
	rows.append("")
	rows.append("%s: rivincita subito" % rematch_key)
	var line_h := 30.0 * Access.text_scale
	var panel_w := 620.0 * Access.text_scale
	var top := 250.0
	draw_rect(Rect2(w / 2 - panel_w / 2, top, panel_w, rows.size() * line_h + 28), Color(0, 0, 0, 0.67))
	for i in rows.size():
		_centered(rows[i], Vector2(w / 2, top + 36 + i * line_h), 20, Color.WHITE)


# Strada fatta in un percorso della Corsa, da 0 (partenza) a 100 (traguardo)
func _progress(x: float) -> int:
	var start: float = _stage.spawns[0].x
	var end: float = _stage.goal.x
	return roundi(clampf((x - start) / (end - start), 0, 1) * 100)


# Bianco a 0%, poi giallo, arancione e rosso man mano che si accumula danno (percentColor in hud.ts)
static func _percent_color(percent: float, eliminated: bool) -> Color:
	if eliminated:
		return Color("777777")
	var t := minf(percent / 150.0, 1.0)
	return Color(1.0, 1.0 - t * 0.85, maxf(0.0, 1.0 - t * 2.0))


func _centered(text: String, pos: Vector2, size: int, color: Color) -> void:
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(size))
	_outlined(text, Vector2(pos.x - s.x / 2, pos.y), size, color)


# size è quella al 100%: la scala del testo scelta nelle opzioni si applica qui
func _outlined(text: String, pos: Vector2, size: int, color: Color) -> void:
	size = Access.px(size)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
