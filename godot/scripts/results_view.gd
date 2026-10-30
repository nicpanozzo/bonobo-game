# Fine partita: GAME! che sbatte sullo schermo, il vincitore sotto il riflettore tra i coriandoli,
# la classifica che entra riga per riga con i numeri che contano e i premi della partita.
# Solo disegno: chi ha vinto lo dice lo snapshot, i numeri li conta hud.gd dagli eventi.
extends Control

const SLAM_MS := 900.0 # GAME! da solo prima del resto, ms
const SLAM_FADE_MS := 300.0 # GAME! sparisce mentre entra il vincitore, ms
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
const TOP := 112.0 # dove comincia la schermata, sotto tempo e punteggio, pixel
const TOP_PHONE := 86.0 # sul telefono sopra ci sono il tempo e la stanza, più grandi
const BOTTOM := 215.0 # spazio lasciato in fondo a schede e pulsanti, pixel
const BOTTOM_PHONE := 100.0 # sul telefono le schede spariscono: restano i pulsanti
const ROW_H := 50.0 # una riga della classifica (nome sopra, premi sotto), pixel
const AWARDS_MAX := 2 # premi al massimo per giocatore
const GOLD := UI.BANANA
const ROW_LEAN := 12.0 # quanto pendono le lastre della classifica, pixel
const RATING_COUNT_MS := 900.0 # i punti in classifica contano fino al nuovo totale in questo tempo, ms
const DELTA_W := 64.0 # colonna dei punti guadagnati o persi, accanto ai numeri, pixel

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
const HallFlow := preload("res://scripts/hall_flow.gd")
const Board := preload("res://scripts/leaderboard_view.gd") # i distintivi dei gradi, uguali nella classifica

var game: Dictionary
var hud: Control # da qui numeri (_stat) e ritratti (portrait_of)
var _snap: Dictionary = {}
var _on := false # la partita è finita
var _since := 0 # ms in cui è finita
var _duration_ms := 0.0
var _confetti: Array = [] # { pos, vel, rot, spin, size, color }
var _rain := 0.0 # coriandoli da far cadere ancora (frazione)
var _bold: Font = UI.font(UI.WEIGHT_BOLD)
var _italic: Font = UI.numbers(UI.WEIGHT_BOLD)
var _display: Font = UI.display()
var _numbers: Font = UI.numbers()
var _veil := ColorRect.new() # l'arena dietro sfocata e scurita (results_veil.gdshader), sotto ai disegni
var _ratings := {} # id -> RatingChange (evento ratings del server): i punti in classifica di questa partita
var _ratings_at := 0 # ms in cui sono arrivati, per il conto che sale


func _init() -> void:
	_veil.show_behind_parent = true # sotto a quello che disegna _draw
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/results_veil.gdshader")
	m.set_shader_parameter("ink", UI.INK)
	_veil.material = m
	_veil.visible = false
	add_child(_veil)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset() -> void:
	_on = false
	_veil.visible = false
	_snap = {}
	_duration_ms = 0.0
	_confetti.clear()
	_ratings = {}
	queue_redraw()


# I punti in classifica a fine partita (evento ratings): accanto a ogni riga e, per me, sotto la classifica
func set_ratings(changes: Array) -> void:
	_ratings = {}
	for c in changes:
		if c is Dictionary and c.has("id"):
			_ratings[str(c.id)] = c
	_ratings_at = Time.get_ticks_msec()
	queue_redraw()


# Il valore mostrato mentre conta: dai punti di prima ai nuovi, rallentando alla fine
static func rating_shown(c: Dictionary, since_ms: float) -> int:
	var to := float(c.get("rating", 0))
	var from := to - float(c.get("delta", 0))
	return roundi(lerpf(from, to, ease_out(since_ms / RATING_COUNT_MS)))


static func delta_color(delta: int) -> Color:
	return UI.OK if delta > 0 else (UI.WARN if delta < 0 else UI.LILAC)


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
		_veil.visible = false
		return
	var w := _width()
	var h := _height()
	var t := _elapsed()
	# Il velo: l'arena dietro sfocata e scurita (results_veil.gdshader), così sotto la classifica non si legge niente
	_veil.visible = true
	(_veil.material as ShaderMaterial).set_shader_parameter("amount", ease_out(t / 400.0))
	(_veil.material as ShaderMaterial).set_shader_parameter("rect_size", Vector2(w, h))
	if t < FLASH_MS:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.55 * (1.0 - t / FLASH_MS)))
	var k := t - SLAM_MS
	if k > 0:
		var winner := _winner()
		var players: Array = ranking(_snap.get("players", []), hud._stats, winner)
		# Vetrina e classifica si disegnano in uno spazio largo BOARD_W e si rimpiccioliscono sugli schermi stretti
		var top := TOP_PHONE if _compact() else TOP
		var bottom := h - (BOTTOM_PHONE if _compact() else BOTTOM)
		var table_w := TABLE_W * (1.0 + (Access.text_scale - 1.0) * 0.8) # col testo grande la tabella si allarga e tutto si rimpicciolisce
		var board_w := SHOWCASE_W + table_w
		var s := minf(1.0, (w - 24.0) / board_w)
		var left := w / 2 - board_w * s / 2
		draw_set_transform(Vector2(left, top), 0.0, Vector2(s, s))
		var board_h := (bottom - top) / s
		_draw_showcase(winner, players, Rect2(0, 0, SHOWCASE_W, board_h), k)
		_draw_table(players, winner, Rect2(SHOWCASE_W, 0, table_w, board_h), k)
		draw_set_transform(Vector2.ZERO)
	_draw_confetti()
	if t < SLAM_MS + SLAM_FADE_MS:
		_draw_slam(w, h, t)


func _compact() -> bool:
	return hud != null and hud.compact


# GAME! arriva enorme e sbatte al centro, trema un attimo e poi lascia il posto: giallo, inchiostro e ombra rossa
func _draw_slam(w: float, h: float, t: float) -> void:
	var text := "GAME!" if not _winner().is_empty() else "PAREGGIO!"
	var zoom := lerpf(3.2, 1.0, ease_out(t / 200.0))
	var alpha := clampf(t / 120.0, 0.0, 1.0) * (1.0 - clampf((t - SLAM_MS) / SLAM_FADE_MS, 0.0, 1.0))
	var shake := Vector2.ZERO
	if t > 200 and t < 420:
		shake = Vector2(randf_range(-6, 6), randf_range(-6, 6)) * (1.0 - (t - 200) / 220.0)
	var fs := Access.px(120)
	var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(Vector2(w / 2, h * 0.45) + shake, -0.06, Vector2(zoom, zoom))
	var pos := Vector2(-tw / 2, fs * 0.35)
	UI.draw_sticker(self, _display, pos + Vector2(7, 9), text, fs, Color(UI.PUNCH, alpha), 18, Vector2(6, 8), UI.INK)
	UI.draw_sticker(self, _display, pos, text, fs, Color(UI.BANANA, alpha), 18, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)


# Il vincitore (a squadre tutta la squadra) sotto il riflettore, coi raggi che girano, il nome sulla targa e la sua frase
func _draw_showcase(winner: Dictionary, players: Array, r: Rect2, k: float) -> void:
	var cx := r.position.x + r.size.x / 2
	var appear := ease_out(k / 300.0)
	if winner.is_empty():
		_sticker("PAREGGIO!", Vector2(cx, r.position.y + r.size.y * 0.45), 52, Color(UI.BANANA, appear))
		return
	var tint := _winner_color()
	var team := int(winner.team)
	var heroes: Array = [winner] if team <= 0 else players.filter(func(p: Dictionary) -> bool: return int(p.team) == team)
	var portrait := clampf(r.size.y - 170.0, 90.0, 200.0) * (1.0 if heroes.size() == 1 else 0.7)
	var center := Vector2(cx, r.position.y + 34 + portrait / 2)
	# I raggi dietro, nel colore di chi ha vinto, e i cerchi del riflettore
	var turn := k / 1000.0 * RAYS_TURN * TAU
	for i in RAYS:
		var a := turn + TAU * i / RAYS
		var spread := PI / RAYS * 0.5
		var far := portrait * 1.15
		draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a - spread) * far, center + Vector2.from_angle(a + spread) * far]), Color(tint.lightened(0.3), 0.2 * appear))
	for i in 4:
		draw_circle(center, portrait * (0.62 - i * 0.1), Color(tint, 0.12 * appear))
	# Il ritratto rimbalza dentro, poi respira
	var pop := ease_back(k / POP_MS)
	var breathe := 1.0 + 0.025 * sin(k / 260.0)
	var gap := portrait * 0.75
	for i in heroes.size():
		var c := center + Vector2((i - (heroes.size() - 1) / 2.0) * gap, 0)
		_draw_portrait(heroes[i], c, portrait * pop * breathe)
	# La corona sopra il primo
	_draw_crown(Vector2(cx, center.y - portrait * 0.5 * pop - 4), 24.0 * pop, appear)
	# Il nome su una targa del suo colore, storta, e sotto VINCE! giallo
	var y := center.y + portrait / 2 + 18
	var label: String = ("Squadra %s" % game.teamNames[str(team)]) if team > 0 else str(winner.name)
	var title_in := clampf(ease_back((k - 150) / POP_MS), 0.0, 1.3)
	var fs := Access.px(34)
	var word := label.to_upper()
	var tw := minf(_display.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, r.size.x - 50)
	var plate := Rect2(Vector2(cx - tw / 2 - 22, y), Vector2(tw + 44, fs + 14))
	var a := clampf(title_in, 0, 1)
	UI.draw_plate(self, plate, Color(tint.darkened(0.15), a), 16.0, Color(UI.INK, a), 3.0, Vector2(5, 6))
	UI.draw_sticker(self, _display, Vector2(cx - tw / 2, plate.end.y - 12), word, fs, Color(UI.PAPER, a), 8, Vector2(0, 3))
	var vy := plate.end.y + 8 + Access.px(30)
	_sticker("VINCE!", Vector2(cx, vy), 30, Color(UI.BANANA, a), Color(UI.PUNCH, a))
	# La frase di vittoria del suo personaggio (#13), o la provocazione se la scheda ha solo quella
	if team <= 0:
		var ch: Dictionary = game.characters.get(winner.get("characterId", ""), {})
		var line := SpeechBubbles.quote(ch, "victory")
		if line == "":
			line = SpeechBubbles.quote(ch, "taunt")
		if line != "":
			var qa := clampf((k - 500) / 400.0, 0, 1)
			var qs := Access.px(16)
			var box := Rect2(r.position.x + 10, vy + 10, r.size.x - 20, qs * 2.6)
			draw_multiline_string_outline(_italic, box.position + Vector2(0, qs), "«%s»" % line, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, qs, 2, 5, Color(UI.INK, qa))
			draw_multiline_string(_italic, box.position + Vector2(0, qs), "«%s»" % line, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, qs, 2, Color(UI.PAPER, qa))


func _draw_crown(at: Vector2, s: float, alpha: float) -> void:
	if s <= 0:
		return
	var pts := PackedVector2Array([at + Vector2(-s, 0), at + Vector2(-s, -s * 0.7), at + Vector2(-s * 0.5, -s * 0.25), at + Vector2(0, -s * 0.95), at + Vector2(s * 0.5, -s * 0.25), at + Vector2(s, -s * 0.7), at + Vector2(s, 0)])
	draw_colored_polygon(pts, Color(UI.BANANA, alpha))
	pts.append(pts[0])
	draw_polyline(pts, Color(UI.INK, alpha), 3.0, true)


# Il ritratto centrato in c, con lato s; senza disegni un cerchio col colore e l'iniziale
func _draw_portrait(p: Dictionary, c: Vector2, s: float) -> void:
	var r := Rect2(c - Vector2(s, s) / 2, Vector2(s, s))
	var src: Array = hud.portrait_of(p) if hud != null else []
	if src.is_empty():
		draw_circle(c, s * 0.42, UI.INK)
		draw_circle(c, s * 0.38, Access.color(p.color))
		_sticker(str(p.name).left(1).to_upper(), c + Vector2(0, s * 0.16), maxi(8, roundi(s * 0.42 / Access.text_scale)), UI.PAPER)
		return
	draw_texture_rect_region(src[0], hud.fit_rect(src[1].size, r), src[1], src[2])


# La classifica: ogni giocatore una lastra storta che entra da destra, i numeri contano fino al totale,
# sotto il nome i premi; accanto i punti in classifica guadagnati o persi
func _draw_table(players: Array, winner: Dictionary, r: Rect2, k: float) -> void:
	var flag: bool = _snap.get("teamScores") != null
	var stats: Dictionary = hud._stats
	var ids := players.map(func(p: Dictionary) -> String: return p.id)
	var prizes := awards(stats, ids)
	var foot_h := 80.0 if not _ratings.is_empty() else 46.0
	var row_h := minf(ROW_H * Access.text_scale, (r.size.y - 30 - foot_h) / maxi(1, players.size()))
	var cols: Array = [["KO", "kos"], ["CADUTE", "falls"], ["DANNI", "damage"]]
	if flag:
		cols.push_front(["BANDIERE", "flags"])
	var col_w := 84.0 * Access.text_scale
	var x_cols := r.end.x - 14 - col_w * cols.size()
	var x_delta := x_cols # i punti in classifica, se sono arrivati, a sinistra dei numeri
	if not _ratings.is_empty():
		x_delta = x_cols - DELTA_W * Access.text_scale
	var head_a := ease_out(k / 300.0)
	var caps := UI.caps()
	for j in cols.size():
		_text(cols[j][0], Vector2(x_cols + col_w * (j + 0.5), r.position.y + 16), 13, Color(UI.LILAC, head_a), caps)
	if not _ratings.is_empty():
		_text("PUNTI", Vector2(x_delta + DELTA_W * Access.text_scale / 2, r.position.y + 16), 13, Color(UI.LILAC, head_a), caps)
	var y0 := r.position.y + 26
	for i in players.size():
		var p: Dictionary = players[i]
		var since := k - 200 - i * ROW_DELAY_MS
		if since <= 0:
			continue
		var slide := ease_out(since / ROW_SLIDE_MS)
		var a := slide
		var off := (1.0 - slide) * ROW_SLIDE
		var y := y0 + i * row_h
		var row := Rect2(r.position.x + 12 + off, y, r.size.x - 24, row_h - 7)
		var won: bool = p.id == winner.get("id") or (not winner.is_empty() and int(winner.team) > 0 and int(p.team) == int(winner.team))
		var col := Access.team_color(game, int(p.team)) if int(p.team) > 0 else Access.color(p.color)
		var fill := UI.SELECTED if won else UI.GRAPE
		UI.draw_plate(self, row, Color(fill, a), ROW_LEAN, Color(UI.BANANA if p.id == winner.get("id") else UI.INK, a), 3.0, Vector2(4, 5))
		# La fascia del colore del giocatore lungo il lato sinistro
		UI.draw_plate(self, Rect2(row.position + Vector2(3, 3), Vector2(9, row.size.y - 6)), Color(col, a), ROW_LEAN * (row.size.y - 6) / row.size.y, UI.INK, 0.0)
		var mid := row.position.y + row.size.y / 2
		_sticker(str(i + 1), Vector2(row.position.x + 32, mid + 10), 26, Color(UI.BANANA if i == 0 else UI.PAPER, a))
		_draw_portrait(p, Vector2(row.position.x + 72, mid), row.size.y - 6)
		var label: String = str(p.name) + (" (tu)" if hud != null and p.id == hud.my_id else "")
		var list: Array = prizes.get(p.id, [])
		var name_y := mid + (-2.0 if not list.is_empty() else 7.0)
		var fs := Access.px(19)
		var name_x := row.position.x + 100
		var name_w := x_delta - name_x - 6
		draw_string_outline(_bold, Vector2(name_x, name_y), label, HORIZONTAL_ALIGNMENT_LEFT, name_w, fs, 5, Color(UI.INK, a))
		draw_string(_bold, Vector2(name_x, name_y), label, HORIZONTAL_ALIGNMENT_LEFT, name_w, fs, Color(UI.PAPER, a))
		if _ratings.has(p.id):
			# "+18" su una targhetta verde, "-12" rossa, che entra con un piccolo salto
			var delta := int(_ratings[p.id].get("delta", 0))
			var pop := ease_back(float(Time.get_ticks_msec() - _ratings_at) / POP_MS)
			_pill(HallFlow.delta_text(delta), Vector2(x_delta + off + DELTA_W * Access.text_scale / 2, mid), delta_color(delta), a * clampf(pop, 0, 1), maxf(0.2, pop))
		# I premi entrano dopo che i numeri hanno finito di contare
		var px := name_x
		var prize_a := a * clampf((since - ROW_SLIDE_MS - COUNT_MS) / 250.0, 0, 1)
		for prize in list:
			var text := "%s · %s" % prize
			if px + _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(12)).x + 16 > x_delta - 4:
				break # non c'è posto prima dei punti: meglio un premio in meno che uno sotto i numeri
			px += _draw_badge(text, Vector2(px, mid + 5), prize_a) + 8
		var count := ease_out((since - ROW_SLIDE_MS * 0.5) / COUNT_MS)
		var s: Dictionary = stats.get(p.id, {})
		for j in cols.size():
			var v := float(s.get(cols[j][1], 0))
			var text := str(roundi(v * count)) + ("%" if cols[j][1] == "damage" else "")
			_text(text, Vector2(x_cols + off + col_w * (j + 0.5), mid + 9), 24, Color(UI.PAPER, a), _numbers)
	var foot := y0 + row_h * players.size() + 22
	var foot_a := clampf((k - 400 - players.size() * ROW_DELAY_MS) / 400.0, 0, 1)
	var parts: Array[String] = []
	if _duration_ms > 0:
		parts.append("Durata %s" % duration_text(_duration_ms))
	parts.append("%s: rivincita subito" % hud.rematch_key)
	_text(" · ".join(parts), Vector2(r.position.x + r.size.x / 2, foot), 15, Color(UI.LILAC, 0.95 * foot_a), _bold)
	# I miei punti in classifica: il grado sul suo distintivo, il totale che conta fino al nuovo e quanto ho preso
	var mine: Dictionary = _ratings.get(hud.my_id, {}) if hud != null else {}
	if not mine.is_empty():
		var since := float(Time.get_ticks_msec() - _ratings_at)
		var delta := int(mine.get("delta", 0))
		var ma := clampf(since / 300.0, 0, 1)
		var tier := str(mine.get("tier", ""))
		var total := "%d punti" % rating_shown(mine, since)
		if mine.get("rank") != null and int(mine.rank) > 0: # il posto in classifica
			total += " · %d°" % int(mine.rank)
		var ts := Access.px(22)
		var total_w := _numbers.get_string_size(total, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var tier_w := Board.tier_width(tier, 15) if tier != "" else 0.0
		var line_w := tier_w + 14 + total_w + 14 + 64
		var x := r.position.x + r.size.x / 2 - line_w / 2
		var cy := foot + 34 * Access.text_scale
		if tier != "":
			x += Board.draw_tier(self, Vector2(x, cy), tier, 15, ma) + 14
		draw_string_outline(_numbers, Vector2(x, cy + ts * 0.36), total, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, 5, Color(UI.INK, ma))
		draw_string(_numbers, Vector2(x, cy + ts * 0.36), total, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(UI.BANANA, ma))
		x += total_w + 14
		_pill(HallFlow.delta_text(delta), Vector2(x + 30, cy), delta_color(delta), ma, 1.0)


# Una targhetta gialla storta col premio, scritta a inchiostro; restituisce quanto è larga
func _draw_badge(text: String, at: Vector2, alpha: float) -> float:
	if alpha <= 0.0:
		return 0.0
	var fs := Access.px(12)
	var tw := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(at, Vector2(tw + 16, fs + 6))
	UI.draw_plate(self, box, Color(UI.BANANA, alpha), 6.0, Color(UI.INK, alpha), 2.0, Vector2(2, 2))
	draw_string(_bold, at + Vector2(8, fs + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.INK, alpha))
	return box.size.x


# Una targhetta col numero centrata in c: verde chi guadagna, rossa chi perde, lilla chi resta pari
func _pill(text: String, c: Vector2, color: Color, alpha: float, grow: float) -> void:
	if alpha <= 0.0:
		return
	var fs := Access.px(17)
	var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var size := Vector2(tw + 18, fs + 8) * grow
	var box := Rect2(c - size / 2, size)
	UI.draw_plate(self, box, Color(color, alpha), 8.0, Color(UI.INK, alpha), 2.5, Vector2(2, 3))
	draw_string(_display, Vector2(c.x - tw * grow / 2, c.y + fs * grow * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(fs * grow), Color(UI.INK, alpha))


func _draw_confetti() -> void:
	for c in _confetti:
		draw_set_transform(c.pos, c.rot, Vector2(1.0, absf(cos(c.rot * 0.7)) + 0.15)) # girano su se stessi
		draw_rect(Rect2(-c.size / 2, c.size), c.color)
	draw_set_transform(Vector2.ZERO)


# Testo centrato su pos con il contorno; size è al 100%, la scala delle opzioni si applica qui
func _text(text: String, pos: Vector2, size_px: int, color: Color, f: Font = null) -> void:
	if f == null:
		f = _bold
	var fs := Access.px(size_px)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(pos.x - tw / 2, pos.y)
	draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(UI.INK, color.a))
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


# Scritta "adesivo" nel font dei titoli, centrata su pos (linea di base): contorno a inchiostro e ombra dura
func _sticker(text: String, pos: Vector2, size_px: int, color: Color, shadow := UI.INK) -> void:
	var fs := Access.px(size_px)
	var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	UI.draw_sticker(self, _display, Vector2(pos.x - tw / 2, pos.y), text, fs, color, maxi(4, fs / 5), Vector2(0, maxf(2.0, fs / 9.0)), Color(shadow, color.a))
