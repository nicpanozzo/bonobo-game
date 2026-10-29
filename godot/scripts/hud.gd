# Scritte sopra la partita: riga della stanza,
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
var _stats := {} # id -> { kos, falls, damage, flags, best }: la classifica di fine partita (results_view.gd), dagli eventi
var _font: Font = UI.font(UI.WEIGHT_BOLD) # righe e nomi: Rubik pieno, si legge sopra qualunque arena
var _num: Font = UI.numbers() # percentuali e tempo: corsivo nero a cifre larghe uguali
var _display: Font = UI.display() # scritte grandi (fasi, squadre)
var _last_percent := {} # id -> percentuale dell'ultimo snapshot, per accorgersi dei colpi presi
var _jolts := {} # id -> { ms, amp }: la percentuale trema per un attimo dopo un colpo
var _supreme_full := false # qualcuno ha la barra della suprema piena (#101): la barra pulsa, si ridisegna sempre
var _portraits := {} # id personaggio (con la skin, #339) -> [Texture2D, Rect2] del ritratto, o [] se non ha disegni (E11)
var _variants := {} # id giocatore -> variante di colore, come in world_view.gd
var compact := false # modalità telefono (Phone): la classifica sta più in alto e lascia il fondo ai pulsanti
var cards_band := Vector2.ZERO # da x a x dove stanno le schede (tra levetta e tasti touch); zero = tutta la larghezza

const WorldView := preload("res://scripts/world_view.gd")
const FighterPose := preload("res://scripts/fighter_pose.gd")
const StagePhases := preload("res://scripts/stage_phases.gd")
const TeamPicker := preload("res://scripts/team_picker.gd")
const PORTRAIT := 46.0 # lato del ritratto che spunta sopra la scheda, pixel
const LEAN := 10.0 # quanto pendono le schede e le targhette dell'HUD, pixel
const TEAM_GAP := 18.0 # a squadre, spazio tra un gruppo di schede e l'altro, pixel (#409)


func _ready() -> void:
	# Lo stesso shader dei lottatori: il ritratto ha i colori alternativi di chi ha lo stesso personaggio
	var palette := ShaderMaterial.new()
	palette.shader = load("res://shaders/palette.gdshader")
	material = palette


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
				var st := _stat(e.attackerId)
				st.damage += e.damage
				st.best = maxf(st.best, e.damage) # il colpo più forte, per il premio di fine partita
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
	_variants = FighterPose.variant_ranks(snap.players)
	_supreme_full = false
	for p in snap.players:
		if not p.get("eliminated", false) and float(p.get("supreme", 0)) >= _supreme_max():
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
		_stats[id] = {"kos": 0, "falls": 0, "damage": 0, "flags": 0, "best": 0}
	return _stats[id]


func _draw() -> void:
	var w: float = size.x if size.x > 0 else game.world.width
	var h: float = size.y if size.y > 0 else game.world.height
	var top_line := status if status != "" else _info
	if top_line != "":
		# La riga della stanza su una targhetta scura, così si legge anche sopra un'arena chiara
		var tw := _font.get_string_size(top_line, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(15)).x
		UI.draw_plate(self, Rect2(-LEAN, 8, tw + 34 + LEAN, Access.px(15) + 12), Color(UI.INK, 0.62), LEAN, UI.INK, 0.0)
		_outlined(top_line, Vector2(14, 13 + Access.px(15)), 15, UI.PAPER)
	if _snap.is_empty():
		return

	_draw_phase_banner(w, h)
	var y := 70.0
	var scores: Variant = _snap.get("teamScores")
	if _snap.timeLeftMs != null:
		var s := int(ceil(_snap.timeLeftMs / 1000.0))
		# Bandiera a pari punti allo scadere: si gioca finché qualcuno segna
		var golden: bool = s == 0 and scores != null and scores["1"] == scores["2"] and _snap.winnerId == null
		var text := "Punto d'oro!" if golden else "%d:%02d" % [s / 60, s % 60]
		_draw_timer(text, w / 2, y, s <= LAST_SECONDS and not golden, golden)
		y += 40 * Access.text_scale
	if scores != null:
		var names: Dictionary = game.teamNames
		_centered("%s %d  –  %d %s" % [names["1"], scores["1"], scores["2"], names["2"]], Vector2(w / 2, y), 24, Color.WHITE)
		y += 26 * Access.text_scale
	elif rules.get("mode", "ffa") == "teams":
		_draw_team_lives(w / 2, y)
		y += 26 * Access.text_scale
	if _snap.get("towerPoints") is Dictionary:
		_draw_tower_points(w / 2, y) # postazioni (#433)

	# Con il testo più grande le schede crescono tutte insieme, a partire dal fondo dello schermo
	var k := Access.text_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	if not (compact and _snap.winnerId != null): # sul telefono a fine partita il fondo è dei pulsanti
		var band := cards_band if cards_band != Vector2.ZERO else Vector2(0, w)
		_draw_cards(band / k, h / k, scores != null)
	draw_set_transform(Vector2.ZERO)


# Il tempo in alto al centro, su una lastra storta: rossa e che pulsa negli ultimi secondi
func _draw_timer(text: String, cx: float, y: float, hurry: bool, golden: bool) -> void:
	var f := _display if golden else _num
	var px := Access.px(30)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pulse := 1.0
	if hurry and not Access.calm:
		pulse = 1.0 + 0.08 * maxf(0.0, sin(Time.get_ticks_msec() / 1000.0 * TAU))
		queue_redraw()
	draw_set_transform(Vector2(cx, y - px * 0.35), 0.0, Vector2(pulse, pulse))
	var plate := Rect2(-tw / 2 - 22, -px * 0.62 - 4, tw + 44, px * 1.24 + 6)
	var fill := UI.PUNCH if hurry else (UI.BANANA if golden else Color(UI.INK, 0.8))
	UI.draw_plate(self, plate, fill, LEAN + 2, UI.INK, 3.0, Vector2(3, 4))
	var color := UI.INK if golden else UI.PAPER
	UI.draw_sticker(self, f, Vector2(-tw / 2, px * 0.35), text, px, color, 0 if golden else 5, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)


# Il nome della fase appena cominciata (#433), o l'avviso della prossima, grande sopra la partita
func _draw_phase_banner(w: float, h: float) -> void:
	if not _stage.has("phases") or _snap.winnerId != null:
		return
	var b := StagePhases.banner(_stage, float(_snap.get("stageMs", 0.0)), float(game.effects.phaseBannerMs))
	var prize := StagePhases.prize_banner(_stage, float(_snap.get("stageMs", 0.0)), int(_snap.get("prizeTeam", 0)), float(game.effects.phaseBannerMs))
	if not prize.is_empty():
		_draw_banner_line(prize.text, prize.alpha, w, h * 0.28 + Access.px(70), Access.px(36), Color("ffcf4a")) # sotto il nome della fase
	if b.is_empty():
		return
	var color := Color("e67e22") if b.warn else Color("ffcf4a") # arancio come l'avviso del campanello
	_draw_banner_line(b.text, b.alpha, w, h * 0.28, Access.px(34 if b.warn else 54), color)


# Una riga di testo grande centrata: adesivo col contorno a inchiostro e l'ombra dura
func _draw_banner_line(text: String, alpha: float, w: float, y: float, size: int, color: Color) -> void:
	var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	color.a = alpha
	UI.draw_sticker(self, _display, Vector2(w / 2 - tw / 2, y), text, size, color, maxi(6, size / 6), Vector2(3, maxf(4.0, size / 10.0)))


# Una scheda per giocatore in basso, tra band.x e band.y: lastra storta a inchiostro con la fascia del colore
# del giocatore, il ritratto che spunta in alto a destra in una cornice storta, la percentuale grande in corsivo
func _draw_cards(band: Vector2, h: float, flag: bool) -> void:
	var players: Array = team_order(_snap.players)
	var groups := team_breaks(players)
	var gaps := TEAM_GAP * maxi(0, groups.size() - 1)
	var card_w := minf(170.0, (band.y - band.x - 20 - gaps) / maxi(1, players.size())) # fino a 8 giocatori in una riga
	var x0 := (band.x + band.y) / 2 - (card_w * players.size() + gaps) / 2
	# A squadre (#409) le schede stanno a gruppi, con sopra una linguetta col nome e il colore della squadra
	for g in groups.size():
		var first: int = groups[g][0]
		var count: int = groups[g][1]
		var team := int(players[first].team)
		if team <= 0:
			continue
		var gx := x0 + first * card_w + g * TEAM_GAP
		var tc := Access.team_color(game, team)
		UI.draw_plate(self, Rect2(gx + 8, h - 11, count * card_w - 16, 5), tc, 4.0, UI.INK, 0.0) # sotto le schede della squadra
		var tname := str(game.teamNames[str(team)]).to_upper()
		var tw := _display.get_string_size(tname, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		UI.draw_plate(self, Rect2(gx + 12, h - 110, tw + 18, 19), tc, 7.0, UI.INK, 2.0)
		draw_string(_display, Vector2(gx + 21, h - 95), tname, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TeamPicker.text_on(tc))
	var group := 0
	for i in players.size():
		var p: Dictionary = players[i]
		while group + 1 < groups.size() and i >= int(groups[group + 1][0]):
			group += 1
		var x := x0 + i * card_w + group * TEAM_GAP
		var col := Access.color(p.color)
		var out: bool = p.eliminated
		var plate := Rect2(x + 10, h - 80, card_w - 20, 66)
		UI.draw_plate(self, plate, Color(UI.INK, 0.6 if out else 0.84), LEAN, UI.INK, 3.0, Vector2(3, 4))
		# La fascia del colore del giocatore sul lato sinistro, storta come la lastra
		var strip := UI.plate_points(Rect2(plate.position.x + 3, plate.position.y + 3, 7, plate.size.y - 6), LEAN * (plate.size.y - 6) / plate.size.y)
		draw_colored_polygon(strip, Color(col, 0.45 if out else 1.0))
		# Il ritratto spunta sopra l'angolo destro della scheda, come nei picchiaduro (E11 passo C)
		var frame := Rect2(x + card_w - 18 - PORTRAIT, h - 80 - PORTRAIT * 0.62, PORTRAIT, PORTRAIT)
		UI.draw_plate(self, frame, col.darkened(0.55) if not out else Color(0.15, 0.15, 0.18), 8.0, UI.INK, 3.0, Vector2(2, 3))
		if not _draw_portrait(p, frame.grow(-4)):
			# Senza disegni (il bonobo fatto col codice): l'iniziale del personaggio nella cornice
			var who: Dictionary = game.get("characters", {}).get(str(p.get("characterId", "")), {})
			var initial := str(who.get("name", p.name)).left(1).to_upper()
			var iw := _display.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			UI.draw_sticker(self, _display, Vector2(frame.get_center().x - iw / 2, frame.end.y - 10), initial, 30, col.lightened(0.25) if not out else Color(UI.LILAC, 0.5), 5, Vector2(1, 2))
		var name: String = p.name + (" (tu)" if p.id == my_id else "")
		var fit := fit_text(_font, name, 14, frame.position.x - x - 26)
		draw_string(_font, Vector2(x + 22, h - 62), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], UI.PAPER if not out else Color(UI.LILAC, 0.6))
		# Barra della suprema piena: "SUPREMA!" è un bollino giallo sotto il ritratto
		if not out and float(p.get("supreme", 0)) >= _supreme_max():
			_draw_badge("SUPREMA!", Vector2(frame.get_center().x, frame.end.y), UI.ACCENT)
		elif p.get("nextTeam") != null:
			# Ha chiesto di cambiare squadra a partita in corso: ci passa dalla prossima (#409)
			_draw_badge("→ " + str(game.teamNames[str(int(p.nextTeam))]), Vector2(frame.get_center().x, frame.end.y), Access.team_color(game, int(p.nextTeam)))
		var roomy := card_w >= 165.0 # con sette o otto giocatori le schede sono strette: numeri e vite più piccoli
		_draw_percent(p, Vector2(x + 20, h - 25), 31 if roomy else 26)
		if not out:
			_draw_supreme(Rect2(x + 20, h - 22, card_w - 52, 5), float(p.get("supreme", 0)))
		if p.get("powerup") != null and not out:
			_draw_powerup(Rect2(x + 14, h - 80, card_w - 28, 66), float(p.get("powerupMs", 0)), str(p.powerup))
		var right := x + card_w - 20 # bordo destro della lastra, dove stanno vite e bandiera
		if _stage.get("goal") != null:
			# Corsa: quanta strada si è fatta
			draw_string(_num, Vector2(right - 46, h - 30), "%d%%" % _progress(p.x), HORIZONTAL_ALIGNMENT_RIGHT, 40, 16, UI.ACCENT)
		elif flag:
			# Bandiera: le vite sono infinite, si segna chi porta la bandiera
			if p.get("carrier", false):
				var flag_pts := PackedVector2Array([Vector2(right - 26, h - 46), Vector2(right - 6, h - 39), Vector2(right - 26, h - 32)])
				draw_colored_polygon(flag_pts, col)
				draw_polyline(flag_pts + PackedVector2Array([flag_pts[0]]), UI.INK, 2.0)
		elif rules.get("mode", "ffa") != "training": # in allenamento le vite sono infinite
			_draw_stocks(p, col, right, h - 36, roomy)


# Un bollino storto col contorno a inchiostro, centrato in at (sotto il ritratto)
func _draw_badge(text: String, at: Vector2, color: Color) -> void:
	var px := 11
	var tw := _display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(at.x - tw / 2 - 7, at.y - 8, tw + 14, 15)
	UI.draw_plate(self, r, color, 5.0, UI.INK, 2.0)
	draw_string(_display, Vector2(r.position.x + 7, r.end.y - 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, TeamPicker.text_on(color))


# La percentuale: corsivo nero con il contorno a inchiostro e il segno % più piccolo; trema quando si prende un colpo
func _draw_percent(p: Dictionary, pos: Vector2, base := 31) -> void:
	var out: bool = p.eliminated
	var size := base
	if _jolts.has(p.id) and not out and not Access.calm:
		var j: Dictionary = _jolts[p.id]
		var left: float = j.ms / game.effects.percentShakeMs
		pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * j.amp * left
		size = roundi(base * (1.0 + 0.3 * left * j.amp / game.effects.percentShakeMax))
	var color := _percent_color(p.percent, out)
	if out:
		UI.draw_sticker(self, _display, pos, "OUT", base - 5, color, 5, Vector2(2, 3))
		return
	var digits := str(roundi(p.percent))
	UI.draw_sticker(self, _num, pos, digits, size, color, 6, Vector2(2, 3))
	var dw := _num.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	UI.draw_sticker(self, _num, pos + Vector2(dw + 1, 0), "%", roundi(size * 0.58), color, 5, Vector2(2, 3))


# Le vite: piccoli rombi del colore del giocatore col contorno a inchiostro, da destra; quelle perse vuote
func _draw_stocks(p: Dictionary, col: Color, right: float, y: float, roomy := true) -> void:
	var total := int(rules.get("stocks", 3))
	var big := total <= 5 and roomy
	var step := 13.0 if big else 9.0
	for k in total:
		var c := Vector2(right - 8 - k * step, y)
		var r := 5.5 if big else 4.0
		var gem := PackedVector2Array([c + Vector2(0, -r - 1), c + Vector2(r, 0), c + Vector2(0, r + 1), c + Vector2(-r, 0)])
		var alive := k < int(p.stocks)
		draw_colored_polygon(gem, col if alive else Color(UI.INK, 0.9))
		draw_polyline(gem + PackedVector2Array([gem[0]]), UI.INK if alive else Color(col, 0.6), 2.0, true)


# A squadre (#409), in alto al centro: le vite rimaste di ogni squadra, ognuna col suo colore
func _draw_team_lives(cx: float, y: float) -> void:
	var lives := {}
	for p in _snap.players:
		var t := int(p.team)
		if t > 0:
			lives[t] = int(lives.get(t, 0)) + maxi(0, int(p.stocks))
	var teams := lives.keys()
	teams.sort()
	var parts := []
	for t in teams:
		var n: int = lives[t]
		parts.append(["%s %d %s" % [game.teamNames[str(t)], n, "vita" if n == 1 else "vite"], Access.team_color(game, t).lightened(0.3)])
	var size := Access.px(20)
	var sep := "   "
	var total := 0.0
	for part in parts:
		total += _font.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	total += _font.get_string_size(sep, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * maxi(0, parts.size() - 1)
	var x := cx - total / 2
	for part in parts:
		draw_string_outline(_font, Vector2(x, y), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(x, y), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, part[1])
		x += _font.get_string_size(part[0] + sep, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# Punti torre (#433): un contatore per squadra col suo colore, piccoli in alto al centro
func _draw_tower_points(cx: float, y: float) -> void:
	var parts := tower_parts(_snap.towerPoints, _snap.players)
	var size := Access.px(16)
	var x := cx - 36.0 * parts.size()
	for part: Array in parts:
		var text := "Torre %d" % part[1]
		draw_string_outline(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, 72, size, 4, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, 72, size, Access.team_color(game, part[0]).lightened(0.3))
		x += 72.0


# [squadra, punti] per ogni squadra in campo, in ordine; chi non ha ancora segnato ha 0
static func tower_parts(points: Dictionary, players: Array) -> Array:
	var teams := []
	for p in players:
		if int(p.team) > 0 and int(p.team) not in teams:
			teams.append(int(p.team))
	teams.sort()
	return teams.map(func(t: int) -> Array: return [t, int(points.get(str(t), 0))])


# A squadre (#409) i giocatori in ordine di squadra, ognuno nell'ordine dello snapshot; altrimenti come sono
static func team_order(players: Array) -> Array:
	var list := players.duplicate()
	var index := {}
	for i in list.size():
		index[list[i].id] = i
	list.sort_custom(func(a, b):
		if int(a.team) != int(b.team):
			return int(a.team) < int(b.team)
		return index[a.id] < index[b.id])
	return list


# I gruppi di una lista già in ordine di squadra: [primo indice, quanti] per ogni squadra
static func team_breaks(players: Array) -> Array:
	var groups := []
	for i in players.size():
		if groups.is_empty() or int(players[i].team) != int(players[groups[-1][0]].team):
			groups.append([i, 0])
		groups[-1][1] += 1
	return groups


# Barra della suprema (#101) sotto la percentuale. Piena diventa dorata, più spessa e pulsa
# (ferma con l'opzione "calma"); la scritta "SUPREMA!" la mette la scheda, sulla riga del nome
func _draw_supreme(r: Rect2, value: float) -> void:
	var t := clampf(value / _supreme_max(), 0.0, 1.0)
	UI.draw_plate(self, r.grow(1), Color(1, 1, 1, 0.12), 3.0, UI.INK, 0.0)
	if t < 1.0:
		if t > 0.0:
			UI.draw_plate(self, Rect2(r.position, Vector2(r.size.x * t, r.size.y)), Color("8fd3ff"), 3.0, UI.INK, 0.0)
		return
	var pulse := 1.0 if Access.calm else 0.65 + 0.35 * sin(Time.get_ticks_msec() / 110.0)
	UI.draw_plate(self, r.grow(2), Color(UI.ACCENT, 0.45 * pulse), 3.0, UI.INK, 0.0)
	UI.draw_plate(self, r, Color(UI.ACCENT, pulse).lerp(Color.WHITE, 0.25 * pulse), 3.0, UI.INK, 0.0)


# Potenziati dal fiore (#231): la foglia sopra la scheda e, sul suo bordo alto,
# una barra verde che si accorcia col tempo che resta
# Col bong (#302) la barra invece si riempie, dal giallo al rosso: piena si crolla
func _draw_powerup(card: Rect2, ms_left: float, kind: String = "fiore") -> void:
	if kind in ["spore", "micelio"]:
		# Il filo di Kirschner (#358): barra verde muschio che si accorcia
		draw_rect(Rect2(card.position, Vector2(card.size.x * clampf(ms_left / float(game.get(kind, {}).get("ms", 4000)), 0.0, 1.0), 4)), Color(0.66, 0.77, 0.42))
		return
	if kind == "pacman":
		# Pac-Man (#427): una fila di palline che si mangia da destra
		var dots := int(ceil(12.0 * clampf(ms_left / float(game.get("pacman", {}).get("ms", 8000)), 0.0, 1.0)))
		for i in dots:
			draw_circle(card.position + Vector2(card.size.x * (i + 0.5) / 12.0, 2), 2.5, Color("ffe11a"))
		return
	if kind == "tetris":
		# Il Tetris (#427): barra a quadretti colorati che si accorcia
		var cells := int(ceil(10.0 * clampf(ms_left / float(game.get("tetris", {}).get("ms", 9000)), 0.0, 1.0)))
		var colors := [Color("29d3ea"), Color("ffd23f"), Color("b04df0"), Color("ff9a1f"), Color("3d6df2"), Color("4ee05a"), Color("f2424a")]
		for i in cells:
			draw_rect(Rect2(card.position + Vector2(card.size.x * i / 10.0, 0), Vector2(card.size.x / 10.0 - 1, 5)), colors[i % colors.size()])
		return
	if kind == "veleno":
		# Il veleno del fungo di Teemo (#419): barra che si accorcia e passa dal verde al viola
		var left := clampf(ms_left / float(game.get("fungo", {}).get("poisonMs", 6000)), 0.0, 1.0)
		draw_rect(Rect2(card.position, Vector2(card.size.x * left, 4)), Color(0.45, 0.85, 0.25).lerp(Color(0.6, 0.35, 0.85), 1.0 - left))
		return
	if kind == "trip":
		# I funghetti (#302): barra viola che si accorcia
		draw_rect(Rect2(card.position, Vector2(card.size.x * clampf(ms_left / float(game.get("funghi", {}).get("tripMs", 3000)), 0.0, 1.0), 4)), Color(0.75, 0.4, 0.95))
		return
	if kind == "bong":
		var high := 1.0 - clampf(ms_left / float(game.get("bong", {}).get("highMs", 7000)), 0.0, 1.0)
		var col := Color(1, 0.85, 0.3).lerp(Color(1, 0.25, 0.2), high)
		if high > 0.8 and Time.get_ticks_msec() / 120 % 2 == 0:
			col = col.lightened(0.5)
		draw_rect(Rect2(card.position, Vector2(card.size.x * high, 4)), col)
		WorldView.draw_leaf(self, card.position + Vector2(20, 4), 30.0, WorldView.SMOKE_GREY)
		return
	var total := float(game.get("powerup", {}).get("flowerMs", 8000))
	var t := clampf(ms_left / total, 0.0, 1.0)
	draw_rect(Rect2(card.position, Vector2(card.size.x * t, 3)), WorldView.FLOWER_GREEN.lightened(0.25))
	# La foglia spunta sopra l'angolo sinistro, come il ritratto a destra
	WorldView.draw_leaf(self, card.position + Vector2(20, 4), 30.0, WorldView.FLOWER_GREEN.lightened(0.1))


func _supreme_max() -> float:
	return float(game.get("supreme", {}).get("max", 100))


# Il ritratto di un giocatore dentro r, con i suoi colori; niente per i personaggi senza disegni
func _draw_portrait(p: Dictionary, r: Rect2) -> bool:
	var src := portrait_of(p, 0.35 if p.get("eliminated", false) else 1.0)
	if src.is_empty():
		return false
	draw_texture_rect_region(src[0], fit_rect(src[1].size, r), src[1], src[2])
	return true


# Il ritratto di un giocatore: [Texture2D, regione, colori] o [] se il personaggio non ha disegni
func portrait_of(p: Dictionary, alpha := 1.0) -> Array:
	var src := _portrait(FighterPose.look(game, str(p.get("characterId", "")), FighterPose.skin_of(p)))
	if src.is_empty():
		return []
	return [src[0], src[1], FighterPose.sprite_modulate(int(_variants.get(p.id, 0)), alpha)]


# Da dove prendere il ritratto: portrait.png se c'è, altrimenti il primo fotogramma di idle,
# ritagliato sulla parte disegnata (i fotogrammi hanno molto vuoto intorno)
func _portrait(c: Dictionary) -> Array:
	var character_id: String = c.get("id", "")
	if _portraits.has(character_id):
		return _portraits[character_id]
	var out := []
	if c.get("portrait") != null:
		var tex: Texture2D = load("res://data/" + str(c.portrait))
		if tex != null:
			out = [tex, Rect2(Vector2.ZERO, tex.get_size())]
	elif c.get("sprite") != null:
		var path: String = "%s/idle.png" % c.sprite.dir if c.sprite.has("dir") else c.sprite.path
		var tex: Texture2D = load("res://data/" + path)
		if tex != null:
			var frame := Rect2(0, 0, c.sprite.frameWidth, c.sprite.frameHeight)
			out = [tex, used_region(tex.get_image(), frame)]
	_portraits[character_id] = out
	return out


# La parte disegnata (non trasparente) di frame, tagliata in basso a un quadrato: testa e spalle
static func used_region(image: Image, frame: Rect2) -> Rect2:
	if image == null:
		return frame
	if image.is_compressed():
		image.decompress()
	var used := image.get_region(Rect2i(frame)).get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return frame
	return Rect2(frame.position + Vector2(used.position), Vector2(used.size.x, mini(used.size.y, used.size.x)))


# Il rettangolo più grande con le proporzioni di size che sta dentro r, centrato
static func fit_rect(size: Vector2, r: Rect2) -> Rect2:
	if size.x <= 0 or size.y <= 0:
		return r
	var k := minf(r.size.x / size.x, r.size.y / size.y)
	var s := size * k
	return Rect2(r.position + (r.size - s) / 2, s)


# Il nome che sta in width pixel: prima si rimpicciolisce (fino a 11), poi si taglia coi puntini. [testo, misura]
static func fit_text(f: Font, text: String, size: int, width: float) -> Array:
	var s := size
	while s > 11 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= width:
		return [text, s]
	var cut := text
	while cut.length() > 1 and f.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		cut = cut.left(cut.length() - 1)
	return [cut.strip_edges() + "…", s]


# Strada fatta in un percorso della Corsa, da 0 (partenza) a 100 (traguardo)
func _progress(x: float) -> int:
	var start: float = _stage.spawns[0].x
	var end: float = _stage.goal.x
	return roundi(clampf((x - start) / (end - start), 0, 1) * 100)


# Bianco a 0%, poi giallo, arancione e rosso man mano che si accumula danno
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
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, UI.INK)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
