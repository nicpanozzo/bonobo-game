# Fine partita: GAME! che sbatte sullo schermo, il vincitore sotto il riflettore tra i coriandoli,
# la classifica che entra riga per riga con i numeri che contano e i premi della partita.
# Solo disegno: chi ha vinto lo dice lo snapshot, i numeri li conta hud.gd dagli eventi.
extends Control

const SLAM_MS := 900.0 # GAME! da solo prima del resto, ms
const SLAM_FADE_MS := 300.0 # GAME! sparisce mentre entra il vincitore, ms
const DIM := 0.6 # quanto si scurisce l'arena dietro, da 0 a 1
const FLASH_MS := 260.0 # il lampo bianco della fine, ms
const POP_MS := 450.0 # il ritratto del vincitore che rimbalza dentro, ms
const ROW_DELAY_MS := 140.0 # una riga della classifica entra dopo l'altra, ms
const ROW_SLIDE_MS := 320.0 # quanto ci mette una riga a scivolare al suo posto, ms
const ROW_SLIDE := 260.0 # da quanto più a destra parte una riga, pixel
const COUNT_MS := 700.0 # i numeri contano fino al totale in questo tempo, dopo l'arrivo della riga, ms
const CONFETTI := 110 # coriandoli della prima ondata
const CONFETTI_RAIN_MS := 4000.0 # per quanto continuano a cadere, ms
const CONFETTI_PER_S := 30.0 # quanti ne cadono al secondo dopo la prima ondata
const GRAVITY := 260.0 # caduta dei coriandoli, pixel/s²
const RAYS := 14 # raggi che girano dietro il vincitore
const RAYS_TURN := 0.25 # giri dei raggi, radianti/s
const SHOWCASE_W := 360.0 # colonna del vincitore, pixel
const TABLE_W := 640.0 # colonna della classifica, pixel
const TOP := 120.0 # dove comincia la schermata, sotto tempo e punteggio, pixel
const BOTTOM := 215.0 # spazio lasciato in fondo a schede e pulsanti, pixel
const BOTTOM_PHONE := 100.0 # sul telefono le schede spariscono: restano i pulsanti
const ROW_H := 50.0 # una riga della classifica (nome sopra, premi sotto), pixel
const AWARDS_MAX := 2 # premi al massimo per giocatore
const GOLD := Color("ffcf4a")

# I premi: statistica -> [nome, perché]. Va a chi è da solo in testa, se il valore non è zero
const TOP_AWARDS := {
	"kos": ["Sterminatore", "più KO"],
	"damage": ["Picchiatore", "più danni"],
	"best": ["Martello", "colpo più forte"],
	"flags": ["Portabandiera", "più bandiere"],
	"falls": ["Kamikaze", "più cadute"],
}
const UNTOUCHED := ["Intoccabile", "mai caduto"]
const PEACEFUL := ["Pacifista", "zero danni"]

const SpeechBubbles := preload("res://scripts/speech_bubbles.gd")

var game: Dictionary
var hud: Control # da qui numeri (_stat) e ritratti (portrait_of)
var _snap: Dictionary = {}
var _on := false # la partita è finita
var _since := 0 # ms in cui è finita
var _duration_ms := 0.0
var _confetti: Array = [] # { pos, vel, rot, spin, size, color }
var _rain := 0.0 # coriandoli da far cadere ancora (frazione)
var _font: Font = UI.font()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset() -> void:
	_on = false
	_snap = {}
	_duration_ms = 0.0
	_confetti.clear()
	queue_redraw()


func is_on() -> bool:
	return _on


func on_snapshot(snap: Dictionary) -> void:
	for e in snap.get("events", []):
		if e.type == "matchEnd":
			_duration_ms = float(e.get("durationMs", 0))
	if snap.get("winnerId") == null:
		if _on:
			reset()
		return
	_snap = snap
	if not _on:
		_on = true
		_since = Time.get_ticks_msec()
		_burst(CONFETTI)


func _process(delta: float) -> void:
	if not _on:
		return
	var t := _elapsed()
	if t > SLAM_MS and t < SLAM_MS + CONFETTI_RAIN_MS:
		_rain += delta * CONFETTI_PER_S
		_burst(int(_rain))
		_rain -= int(_rain)
	var h := _height()
	for c in _confetti:
		c.vel.y += GRAVITY * delta
		c.vel.x *= 1.0 - delta * 0.8 # l'aria li frena di lato
		c.pos += c.vel * delta
		c.rot += c.spin * delta
	_confetti = _confetti.filter(func(c: Dictionary) -> bool: return c.pos.y < h + 20)
	queue_redraw()


func _elapsed() -> float:
	return float(Time.get_ticks_msec() - _since)


func _width() -> float:
	return size.x if size.x > 0 else float(game.world.width)


func _height() -> float:
	return size.y if size.y > 0 else float(game.world.height)


# Coriandoli dall'alto, col colore di chi ha vinto e l'oro
func _burst(n: int) -> void:
	var w := _width()
	var tint := _winner_color()
	for i in n:
		var color: Color = [tint, tint.lightened(0.35), GOLD, Color.WHITE][randi() % 4]
		_confetti.append({
			"pos": Vector2(randf() * w, -10.0 - randf() * 120.0),
			"vel": Vector2(randf_range(-80, 80), randf_range(40, 180)),
			"rot": randf() * TAU,
			"spin": randf_range(-8, 8),
			"size": Vector2(randf_range(5, 10), randf_range(3, 6)),
			"color": color,
		})


func _winner() -> Dictionary:
	for p in _snap.get("players", []):
		if p.id == _snap.get("winnerId"):
			return p
	return {}


func _winner_color() -> Color:
	var w := _winner()
	if w.is_empty():
		return GOLD
	if int(w.team) > 0:
		return Access.team_color(game, int(w.team))
	return Access.color(w.color)


# Chi ha vinto in cima (a squadre tutta la squadra), poi bandiere, KO e danni
static func ranking(players: Array, stats: Dictionary, winner: Dictionary) -> Array:
	var list := players.duplicate()
	var won := func(p: Dictionary) -> bool:
		if winner.is_empty():
			return false
		return p.id == winner.id or (int(winner.team) > 0 and int(p.team) == int(winner.team))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if won.call(a) != won.call(b):
			return won.call(a)
		if (a.id == winner.get("id")) != (b.id == winner.get("id")):
			return a.id == winner.get("id")
		var sa: Dictionary = stats.get(a.id, {})
		var sb: Dictionary = stats.get(b.id, {})
		for k in ["flags", "kos", "damage"]:
			if float(sa.get(k, 0)) != float(sb.get(k, 0)):
				return float(sa.get(k, 0)) > float(sb.get(k, 0))
		return float(sa.get("falls", 0)) < float(sb.get("falls", 0)))
	return list


# I premi della partita, id -> [[nome, perché], ...]: al massimo AWARDS_MAX a testa, nessuno se si gioca da soli
static func awards(stats: Dictionary, ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		out[id] = []
	if ids.size() < 2:
		return out
	for key in TOP_AWARDS:
		var best := 0.0
		var holders: Array = []
		for id in ids:
			var v := float(stats.get(id, {}).get(key, 0))
			if v > best:
				best = v
				holders = [id]
			elif v == best and v > 0:
				holders.append(id)
		if holders.size() == 1:
			out[holders[0]].append(TOP_AWARDS[key])
	for id in ids:
		var s: Dictionary = stats.get(id, {})
		if int(s.get("falls", 0)) == 0:
			out[id].append(UNTOUCHED)
		if int(s.get("damage", 0)) == 0:
			out[id].append(PEACEFUL)
		out[id] = out[id].slice(0, AWARDS_MAX)
	return out


static func duration_text(ms: float) -> String:
	var s := int(round(ms / 1000.0))
	return "%d:%02d" % [s / 60, s % 60]


static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


# Supera un po' l'arrivo e torna indietro: il rimbalzo del ritratto
static func ease_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c := 1.9
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


func _draw() -> void:
	if not _on:
		return
	var w := _width()
	var h := _height()
	var t := _elapsed()
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, DIM * ease_out(t / 400.0)))
	if t < FLASH_MS:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.55 * (1.0 - t / FLASH_MS)))
	var k := t - SLAM_MS
	if k > 0:
		var winner := _winner()
		var players: Array = ranking(_snap.get("players", []), hud._stats, winner)
		var left := w / 2 - (SHOWCASE_W + TABLE_W) / 2
		var bottom := h - (BOTTOM_PHONE if hud.compact else BOTTOM)
		_draw_showcase(winner, players, Rect2(left, TOP, SHOWCASE_W, bottom - TOP), k)
		_draw_table(players, winner, Rect2(left + SHOWCASE_W, TOP, TABLE_W, bottom - TOP), k)
	_draw_confetti()
	if t < SLAM_MS + SLAM_FADE_MS:
		_draw_slam(w, h, t)


# GAME! arriva enorme e sbatte al centro, trema un attimo e poi lascia il posto
func _draw_slam(w: float, h: float, t: float) -> void:
	var text := "GAME!" if not _winner().is_empty() else "PAREGGIO!"
	var zoom := lerpf(3.2, 1.0, ease_out(t / 200.0))
	var alpha := clampf(t / 120.0, 0.0, 1.0) * (1.0 - clampf((t - SLAM_MS) / SLAM_FADE_MS, 0.0, 1.0))
	var shake := Vector2.ZERO
	if t > 200 and t < 420:
		shake = Vector2(randf_range(-6, 6), randf_range(-6, 6)) * (1.0 - (t - 200) / 220.0)
	var fs := Access.px(110)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(Vector2(w / 2, h * 0.45) + shake, -0.06, Vector2(zoom, zoom))
	var pos := Vector2(-tw / 2, fs * 0.35)
	draw_string_outline(_font, pos + Vector2(6, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0, 0, 0, alpha * 0.6))
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(_winner_color().darkened(0.3), alpha))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.97, 0.85, alpha))
	draw_set_transform(Vector2.ZERO)


# Il vincitore (a squadre tutta la squadra) sotto il riflettore, coi raggi che girano, il nome e la sua frase
func _draw_showcase(winner: Dictionary, players: Array, r: Rect2, k: float) -> void:
	var cx := r.position.x + r.size.x / 2
	var appear := ease_out(k / 300.0)
	if winner.is_empty():
		_text("Pareggio!", Vector2(cx, r.position.y + r.size.y * 0.45), 48, Color(GOLD, appear))
		return
	var tint := _winner_color()
	var team := int(winner.team)
	var heroes: Array = [winner] if team <= 0 else players.filter(func(p: Dictionary) -> bool: return int(p.team) == team)
	var portrait := minf(200.0, r.size.y - 150.0) * (1.0 if heroes.size() == 1 else 0.7)
	var center := Vector2(cx, r.position.y + 30 + portrait / 2)
	# Il riflettore dall'alto e i raggi dietro
	var beam := PackedVector2Array([Vector2(cx - 26, 0), Vector2(cx + 26, 0), center + Vector2(portrait * 0.8, portrait * 0.55), center + Vector2(-portrait * 0.8, portrait * 0.55)])
	draw_colored_polygon(beam, Color(1, 0.95, 0.75, 0.10 * appear))
	var turn := k / 1000.0 * RAYS_TURN * TAU
	for i in RAYS:
		var a := turn + TAU * i / RAYS
		var spread := PI / RAYS * 0.5
		var far := portrait * 1.1
		draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a - spread) * far, center + Vector2.from_angle(a + spread) * far]), Color(tint.lightened(0.3), 0.16 * appear))
	for i in 4:
		draw_circle(center, portrait * (0.62 - i * 0.1), Color(tint, 0.10 * appear))
	# Il ritratto rimbalza dentro, poi respira
	var pop := ease_back(k / POP_MS)
	var breathe := 1.0 + 0.025 * sin(k / 260.0)
	var gap := portrait * 0.75
	for i in heroes.size():
		var c := center + Vector2((i - (heroes.size() - 1) / 2.0) * gap, 0)
		_draw_portrait(heroes[i], c, portrait * pop * breathe)
	# La corona sopra il primo
	var crown_y := center.y - portrait * 0.5 * pop - 6
	_draw_crown(Vector2(cx, crown_y), 22.0 * pop, appear)
	var y := center.y + portrait / 2 + 34
	var label: String = ("Squadra %s" % game.teamNames[str(team)]) if team > 0 else str(winner.name)
	var title_in := ease_back((k - 150) / POP_MS)
	_text(label.to_upper(), Vector2(cx, y), roundi(40 * maxf(title_in, 0.01)), Color(tint.lightened(0.35), clampf(title_in, 0, 1)))
	_text("VINCE!", Vector2(cx, y + 34 * Access.text_scale), 26, Color(GOLD, clampf(title_in, 0, 1)))
	# La frase di vittoria del suo personaggio (#13), o la provocazione se la scheda ha solo quella
	if team <= 0:
		var ch: Dictionary = game.characters.get(winner.get("characterId", ""), {})
		var line := SpeechBubbles.quote(ch, "victory")
		if line == "":
			line = SpeechBubbles.quote(ch, "taunt")
		if line != "":
			var a := clampf((k - 500) / 400.0, 0, 1)
			var fs := Access.px(17)
			var top := y + 52 * Access.text_scale
			var box := Rect2(r.position.x + 10, top, r.size.x - 20, fs * 2.6)
			draw_multiline_string_outline(_font, box.position + Vector2(0, fs), "«%s»" % line, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, fs, 2, 4, Color(0, 0, 0, a))
			draw_multiline_string(_font, box.position + Vector2(0, fs), "«%s»" % line, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, fs, 2, Color(1, 1, 1, a))


func _draw_crown(at: Vector2, s: float, alpha: float) -> void:
	if s <= 0:
		return
	var pts := PackedVector2Array([at + Vector2(-s, 0), at + Vector2(-s, -s * 0.7), at + Vector2(-s * 0.5, -s * 0.25), at + Vector2(0, -s * 0.95), at + Vector2(s * 0.5, -s * 0.25), at + Vector2(s, -s * 0.7), at + Vector2(s, 0)])
	draw_colored_polygon(pts, Color(GOLD, alpha))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.35, 0.2, 0, alpha), 2.0)


# Il ritratto centrato in c, con lato s; senza disegni un cerchio col colore e l'iniziale
func _draw_portrait(p: Dictionary, c: Vector2, s: float) -> void:
	var r := Rect2(c - Vector2(s, s) / 2, Vector2(s, s))
	var src: Array = hud.portrait_of(p) if hud != null else []
	if src.is_empty():
		draw_circle(c, s * 0.4, Access.color(p.color))
		_text(str(p.name).left(1).to_upper(), c + Vector2(0, s * 0.15), roundi(s * 0.4 / Access.text_scale), Color.WHITE)
		return
	draw_texture_rect_region(src[0], hud.fit_rect(src[1].size, r), src[1], src[2])


# La classifica: le righe entrano una dopo l'altra da destra, i numeri contano fino al totale, sotto il nome i premi
func _draw_table(players: Array, winner: Dictionary, r: Rect2, k: float) -> void:
	var flag: bool = _snap.get("teamScores") != null
	var stats: Dictionary = hud._stats
	var ids := players.map(func(p: Dictionary) -> String: return p.id)
	var prizes := awards(stats, ids)
	var row_h := minf(ROW_H * Access.text_scale, (r.size.y - 70) / maxi(1, players.size()))
	var cols: Array = [["KO", "kos"], ["Cadute", "falls"], ["Danni", "damage"]]
	if flag:
		cols.push_front(["Bandiere", "flags"])
	var col_w := 86.0 * Access.text_scale
	var x_cols := r.end.x - col_w * cols.size()
	var head_a := ease_out(k / 300.0)
	for j in cols.size():
		_text(cols[j][0], Vector2(x_cols + col_w * (j + 0.5), r.position.y + 14), 14, Color(1, 1, 1, 0.7 * head_a))
	var y0 := r.position.y + 26
	draw_rect(Rect2(r.position.x, y0, r.size.x, row_h * players.size() + 8), Color(0, 0, 0, 0.45 * head_a))
	for i in players.size():
		var p: Dictionary = players[i]
		var since := k - 200 - i * ROW_DELAY_MS
		if since <= 0:
			continue
		var slide := ease_out(since / ROW_SLIDE_MS)
		var a := slide
		var off := (1.0 - slide) * ROW_SLIDE
		var y := y0 + 4 + i * row_h
		var row := Rect2(r.position.x + 4 + off, y, r.size.x - 8, row_h - 4)
		var mine: bool = p.id == winner.get("id") or (not winner.is_empty() and int(winner.team) > 0 and int(p.team) == int(winner.team))
		var col := Access.team_color(game, int(p.team)) if int(p.team) > 0 else Access.color(p.color)
		draw_rect(row, Color(1, 0.85, 0.3, 0.16 * a) if mine else Color(1, 1, 1, 0.05 * a))
		draw_rect(Rect2(row.position, Vector2(5, row.size.y)), Color(col, a))
		if p.id == winner.get("id"):
			draw_rect(row, Color(GOLD, 0.8 * a), false, 2.0)
		var mid := row.position.y + row.size.y / 2
		_text(str(i + 1), Vector2(row.position.x + 24, mid + 8), 22, Color(GOLD if i == 0 else Color.WHITE, a))
		_draw_portrait(p, Vector2(row.position.x + 66, mid), row.size.y - 4)
		var label: String = str(p.name) + (" (tu)" if hud != null and p.id == hud.my_id else "")
		var list: Array = prizes.get(p.id, [])
		var name_y := mid + (-2.0 if not list.is_empty() else 7.0)
		var fs := Access.px(20)
		draw_string_outline(_font, Vector2(row.position.x + 96, name_y), label, HORIZONTAL_ALIGNMENT_LEFT, x_cols - row.position.x - 100, fs, 4, Color(0, 0, 0, a))
		draw_string(_font, Vector2(row.position.x + 96, name_y), label, HORIZONTAL_ALIGNMENT_LEFT, x_cols - row.position.x - 100, fs, Color(1, 1, 1, a))
		# I premi entrano dopo che i numeri hanno finito di contare
		var px := row.position.x + 96
		var prize_a := a * clampf((since - ROW_SLIDE_MS - COUNT_MS) / 250.0, 0, 1)
		for prize in list:
			px += _draw_badge("%s · %s" % prize, Vector2(px, mid + 6), prize_a) + 6
		var count := ease_out((since - ROW_SLIDE_MS * 0.5) / COUNT_MS)
		var s: Dictionary = stats.get(p.id, {})
		for j in cols.size():
			var v := float(s.get(cols[j][1], 0))
			var text := str(roundi(v * count)) + ("%" if cols[j][1] == "damage" else "")
			_text(text, Vector2(x_cols + off + col_w * (j + 0.5), mid + 8), 22, Color(1, 1, 1, a))
	var foot := y0 + row_h * players.size() + 34
	var foot_a := clampf((k - 400 - players.size() * ROW_DELAY_MS) / 400.0, 0, 1)
	var parts: Array[String] = []
	if _duration_ms > 0:
		parts.append("Durata %s" % duration_text(_duration_ms))
	parts.append("%s: rivincita subito" % hud.rematch_key)
	_text(" · ".join(parts), Vector2(r.position.x + r.size.x / 2, foot), 16, Color(1, 1, 1, 0.8 * foot_a))


# Una targhetta dorata col premio; restituisce quanto è larga
func _draw_badge(text: String, at: Vector2, alpha: float) -> float:
	var fs := Access.px(12)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(at, Vector2(tw + 14, fs + 6))
	draw_rect(box, Color(GOLD, 0.9 * alpha))
	draw_string(_font, at + Vector2(7, fs + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.1, 0, alpha))
	return box.size.x


func _draw_confetti() -> void:
	for c in _confetti:
		draw_set_transform(c.pos, c.rot, Vector2(1.0, absf(cos(c.rot * 0.7)) + 0.15)) # girano su se stessi
		draw_rect(Rect2(-c.size / 2, c.size), c.color)
	draw_set_transform(Vector2.ZERO)


# Testo centrato su pos con il contorno; size è al 100%, la scala delle opzioni si applica qui
func _text(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	var fs := Access.px(size_px)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(pos.x - tw / 2, pos.y)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, color.a))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
