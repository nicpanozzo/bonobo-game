# Pre-partita sopra l'arena: l'attesa di chi deve ancora dire Pronto, poi la presentazione e 3, 2, 1, VIA!
# Solo disegno: fasi e tempi li decide il server (snapshot.prematch); qui si chiede soltanto di essere pronti.
extends Control

signal ready_changed(ready: bool)
signal cue(name: String) # un momento da sottolineare con un suono o una voce: intro, card, vs, 3, 2, 1, go

const FighterPose := preload("res://scripts/fighter_pose.gd")
const Hud := preload("res://scripts/hud.gd")
const GO_MS := 900.0 # quanto resta il VIA! dopo matchStart, ms
const PANEL_W := 560.0 # larghezza del pannello dell'attesa, pixel
const PANEL_Y := 96.0 # dove comincia il pannello, pixel dall'alto
const ROW_H := 34.0 # una riga per lottatore, pixel
const COUNT_COLORS := ["ffcf4a", "ff9a3c", "ff5a4a"] # 1, 2, 3: più si avvicina il VIA più è caldo
const GO_COLOR := Color("7dff6a")
const SYNC_MS := 1000 # dopo quanto, se il server non è d'accordo sul Pronto, vince lui, ms
const CARD_FIRST := 0.08 # presentazione (da 0 a 1): quando arriva la prima scheda
const CARD_GAP := 0.12 # tra una scheda e la successiva
const CARD_SLIDE := 0.16 # quanto ci mette una scheda ad arrivare
const CARD_MAX_W := 250.0 # larghezza massima di una scheda della presentazione, pixel
const FLASH_MS := 260.0 # lampo bianco al VIA!, ms
const POSTER_H := 0.8 # in due, quanto è alto il lottatore sulla locandina, parte dell'altezza dello schermo

var game: Dictionary
var my_id := ""
var _pre: Dictionary = {} # snapshot.prematch: {} = partita in corso (o server di prima, senza pre-partita)
var _players: Array = []
var _left_ms := 0.0 # ms al VIA: scende anche tra uno snapshot e l'altro, così i numeri non scattano
var _go_ms := 0.0 # ms rimasti del VIA!
var _asked := false # Pronto chiesto da qui: si vede subito, senza aspettare lo snapshot dopo
var _asked_at := 0 # ms dell'ultimo Pronto chiesto
var _font: Font = UI.font()
var _button: Button
var portrait_of: Callable # personaggio (look) -> [Texture2D, Rect2] o []: lo stesso dell'HUD, con la sua cache
var _cued := {} # i momenti già suonati in questa presentazione o conto alla rovescia
var _bodies := {} # personaggio (look.id) -> [Texture2D, Rect2]: il corpo intero per la locandina, o []


# Tutto in _init: i test lo usano anche senza che entri nell'albero
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lo shader dei lottatori: il ritratto ha i colori alternativi di chi ha lo stesso personaggio
	var palette := ShaderMaterial.new()
	palette.shader = load("res://shaders/palette.gdshader")
	material = palette
	_button = UI.button("Sono pronto!", func(): set_ready(not is_ready()), true)
	_button.focus_mode = Control.FOCUS_NONE # niente fuoco: i tasti restano al lottatore
	_button.custom_minimum_size = Vector2(240, 0)
	_button.theme = UI.theme()
	_button.visible = false
	add_child(_button)


func reset() -> void:
	_pre = {}
	_players = []
	_left_ms = 0.0
	_go_ms = 0.0
	_asked = false
	_cued = {}
	_button.visible = false
	queue_redraw()


func on_snapshot(snap: Dictionary) -> void:
	var was_on := not _pre.is_empty()
	var pre: Variant = snap.get("prematch")
	_pre = pre if pre is Dictionary else {}
	_players = snap.get("players", [])
	for e in snap.get("events", []):
		if e.type == "matchStart" and was_on:
			_go_ms = GO_MS
			_cue("go")
			_cued = {}
	if not _pre.is_empty():
		_left_ms = float(_pre.get("leftMs", 0))
		# Il server ha l'ultima parola, ma il Pronto appena chiesto ha il tempo di arrivargli
		var server_ready: bool = _pre.get("ready", []).has(my_id)
		if server_ready == _asked or Time.get_ticks_msec() - _asked_at > SYNC_MS:
			_asked = server_ready
	else:
		_asked = false
	queue_redraw()


func waiting() -> bool:
	return _pre.get("phase", "") == "waiting"


# Al 3, 2, 1 il server tiene fermi i lottatori: la predizione si spegne, se no si vedrebbe partire e tornare indietro
func frozen() -> bool:
	return _pre.get("phase", "") == "starting"


func is_ready() -> bool:
	return _asked


func set_ready(value: bool) -> void:
	if not waiting() or value == _asked:
		return
	_asked = value
	_asked_at = Time.get_ticks_msec()
	ready_changed.emit(value)
	queue_redraw()


func _process(delta: float) -> void:
	_button.visible = waiting()
	if waiting():
		_button.text = "Non sono più pronto" if _asked else "Sono pronto!"
		_button.position = Vector2((size.x - _button.size.x) / 2, PANEL_Y + _panel_h() + 12)
	if frozen():
		_left_ms = maxf(0.0, _left_ms - delta * 1000.0)
		_cue_timeline()
	if _go_ms > 0:
		_go_ms -= delta * 1000.0
	if not _pre.is_empty() or _go_ms > 0:
		queue_redraw()


func _draw() -> void:
	var w: float = size.x if size.x > 0 else game.world.width
	var h: float = size.y if size.y > 0 else game.world.height
	if waiting():
		_draw_waiting(w)
	elif frozen():
		_draw_countdown(w, h)
	elif _go_ms > 0:
		_draw_go(w, h, 1.0 - _go_ms / GO_MS)


func _panel_h() -> float:
	return 120.0 + _players.size() * ROW_H


func _draw_waiting(w: float) -> void:
	var r := Rect2(w / 2 - PANEL_W / 2, PANEL_Y, PANEL_W, _panel_h())
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.04, 0.1, 0.82)
	box.border_color = Color("ffcf4a")
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	draw_style_box(box, r)
	var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 400.0) % 3)
	_centered("IN ATTESA DEI LOTTATORI" + dots, Vector2(w / 2, r.position.y + 42), 30, Color("ffcf4a"))
	var y := r.position.y + 82
	for p in _players:
		var on: bool = _asked if p.id == my_id else _pre.ready.has(p.id)
		draw_circle(Vector2(r.position.x + 34, y - 7), 9, Color.hex((int(p.get("color", 0xffffff)) << 8) | 0xff))
		var label: String = str(p.get("name", "?")) + (" (tu)" if p.id == my_id else "")
		_outlined(label, Vector2(r.position.x + 54, y), 22, Color.WHITE)
		var tag := "PRONTO!" if on else "si sta scaldando"
		var size_px := Access.px(20)
		var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		_outlined(tag, Vector2(r.end.x - 24 - tw, y), 20, GO_COLOR if on else Color("9a9aa8"))
		y += ROW_H
	_centered(hint(_players.size(), _asked, _pre.get("autoStartMs")), Vector2(w / 2, r.end.y - 18), 18, Color("d8d8e8"))


# La riga in fondo al pannello: cosa fare adesso
static func hint(players: int, me_ready: bool, auto_start_ms: Variant) -> String:
	if players < 2:
		return "Manda il link agli amici: si comincia appena arriva qualcuno"
	var text := "Aspettiamo gli altri" if me_ready else "Provoca (T) o premi Invio quando sei pronto"
	if auto_start_ms != null:
		text += " · si parte comunque tra %d s" % ceili(float(auto_start_ms) / 1000.0)
	return text


# Il numero del conto alla rovescia: "" durante la presentazione, poi "3", "2", "1"
static func count_label(left_ms: float, countdown_ms: float) -> String:
	if left_ms > countdown_ms:
		return ""
	return str(clampi(ceili(left_ms / 1000.0), 1, 9))


func _draw_countdown(w: float, h: float) -> void:
	var countdown: float = float(game.get("prematch", {}).get("countdownMs", 3000))
	var label := count_label(_left_ms, countdown)
	if label == "":
		_draw_intro(w, h, intro_t(_left_ms, countdown, _intro_ms()))
		return
	var n := int(label)
	var into := 1.0 - fmod(_left_ms, 1000.0) / 1000.0 # da 0 a 1 dentro il secondo di questo numero
	_draw_big(label, Vector2(w / 2, h * 0.42), 220, Color(COUNT_COLORS[clampi(n - 1, 0, 2)]), into)


# Testo enorme che arriva grande e si assesta, poi sfuma: t da 0 (appena comparso) a 1
func _draw_big(text: String, center: Vector2, px: int, color: Color, t: float, alpha := 1.0) -> void:
	var pop := 1.0 + 0.7 * pow(1.0 - clampf(t * 3.0, 0.0, 1.0), 3.0)
	color.a = (1.0 - smoothstep(0.75, 1.0, t)) * alpha
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	draw_set_transform(center, 0.0, Vector2(pop, pop))
	var at := Vector2(-s.x / 2, s.y * 0.3)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 14, Color(0, 0, 0, color.a))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
	draw_set_transform(Vector2.ZERO)


func _centered(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(size_px))
	_outlined(text, Vector2(pos.x - s.x / 2, pos.y), size_px, color)


func _outlined(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	size_px = Access.px(size_px)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, Color.BLACK)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _intro_ms() -> float:
	return float(game.get("prematch", {}).get("introMs", 2500))


# Quanto è andata avanti la presentazione, da 0 a 1 (1 = comincia il 3, 2, 1)
static func intro_t(left_ms: float, countdown_ms: float, intro_ms: float) -> float:
	return clampf(1.0 - (left_ms - countdown_ms) / maxf(intro_ms, 1.0), 0.0, 1.0)


# Dove sta la scheda i di n alla fine della presentazione: in fila al centro dello schermo
static func card_rect(i: int, n: int, w: float, h: float) -> Rect2:
	var gap := 28.0
	var cw := minf(CARD_MAX_W, (w - 80.0 - gap * (n - 1)) / maxf(n, 1))
	var ch := cw * 1.3
	var total := cw * n + gap * (n - 1)
	return Rect2(w / 2 - total / 2 + i * (cw + gap), h * 0.44 - ch / 2, cw, ch)


# Da 0 (fuori schermo) a 1 (al suo posto) per la scheda i, con un piccolo rimbalzo all'arrivo
static func card_in(t: float, i: int) -> float:
	var k := clampf((t - CARD_FIRST - i * CARD_GAP) / CARD_SLIDE, 0.0, 1.0)
	if k <= 0.0:
		return 0.0
	var c := 1.70158 # ease-out back
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3) + c * pow(k - 1.0, 2)


# Le schede dei lottatori arrivano una dopo l'altra, alternando dall'alto e dal basso, poi il VS sbatte in mezzo
func _draw_intro(w: float, h: float, t: float) -> void:
	if _players.size() == 2:
		_draw_poster(w, h, t)
		return
	var fade := 1.0 - smoothstep(0.9, 1.0, t)
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.05, 0.6 * minf(t * 6.0, 1.0) * fade))
	# Due fasce diagonali che attraversano lo schermo
	var band := Color(1.0, 0.81, 0.29, 0.18 * fade)
	var slide := (1.0 - minf(t * 4.0, 1.0)) * w
	draw_colored_polygon(PackedVector2Array([Vector2(-slide, h * 0.2), Vector2(w - slide, h * 0.08), Vector2(w - slide, h * 0.16), Vector2(-slide, h * 0.28)]), band)
	draw_colored_polygon(PackedVector2Array([Vector2(slide, h * 0.78), Vector2(w + slide, h * 0.66), Vector2(w + slide, h * 0.74), Vector2(slide, h * 0.86)]), band)
	var variants: Dictionary = FighterPose.variant_ranks(_players)
	var n := _players.size()
	for i in n:
		var k := card_in(t, i)
		if k <= 0.0:
			continue
		var r := card_rect(i, n, w, h)
		var from_y := -r.size.y - 40.0 if i % 2 == 0 else h + 40.0
		r.position.y = lerpf(from_y, r.position.y, k)
		_draw_card(_players[i], r, int(variants.get(_players[i].id, 0)), fade)
	var vs_t := CARD_FIRST + n * CARD_GAP + 0.04
	if n >= 2 and t >= vs_t:
		var label := "VS" if n == 2 else "RISSA!"
		_draw_big(label, Vector2(w / 2, h * 0.44 + (0.0 if n == 2 else card_rect(0, n, w, h).size.y * 0.5 + 60.0)), 120 if n == 2 else 90, Color("ff5a4a"), (t - vs_t) * 0.5, fade)
	_centered("PREPARATEVI!", Vector2(w / 2, h * 0.14), 40, Color(1.0, 0.81, 0.29, fade))


func _draw_card(p: Dictionary, r: Rect2, variant: int, alpha: float) -> void:
	var color := Color.hex((int(p.get("color", 0xffffff)) << 8) | 0xff)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.darkened(0.7), 0.92 * alpha)
	box.border_color = Color(color, alpha)
	box.set_border_width_all(5)
	box.set_corner_radius_all(16)
	box.skew = Vector2(-0.12, 0)
	draw_style_box(box, r)
	var look: Dictionary = FighterPose.look(game, str(p.get("characterId", "")), FighterPose.skin_of(p))
	var src: Array = portrait_of.call(look) if portrait_of.is_valid() else []
	if not src.is_empty():
		var area := Rect2(r.position + Vector2(14, 14), Vector2(r.size.x - 28, r.size.y - 92))
		var fit: Rect2 = Hud.fit_rect(src[1].size, area)
		draw_texture_rect_region(src[0], fit, src[1], FighterPose.sprite_modulate(variant, alpha))
	else:
		# Personaggio senza immagine (es. il bonobo disegnato col codice): l'iniziale gigante, così la scheda non resta vuota
		var who: Dictionary = game.get("characters", {}).get(str(p.get("characterId", "")), {})
		var initial := str(who.get("name", p.get("name", "?"))).left(1).to_upper()
		_centered(initial, Vector2(r.get_center().x, r.position.y + (r.size.y - 78) * 0.62), int(r.size.y * 0.45), Color(color.lightened(0.2), 0.85 * alpha))
	var name_px := 26 if r.size.x > 180 else 20
	_centered(str(p.get("name", "?")), Vector2(r.get_center().x, r.end.y - 46), name_px, Color(1, 1, 1, alpha))
	var character: Dictionary = game.get("characters", {}).get(str(p.get("characterId", "")), {})
	_centered(str(character.get("name", "")).to_upper(), Vector2(r.get_center().x, r.end.y - 18), 16, Color(color.lightened(0.3), alpha))


# In due: una locandina da incontro di boxe. Sfondo nei due colori, i lottatori enormi che entrano dai lati
# guardandosi, contorno al neon, nomi in basso e il VS acceso in mezzo
func _draw_poster(w: float, h: float, t: float) -> void:
	var fade := 1.0 - smoothstep(0.9, 1.0, t)
	var cols: Array[Color] = []
	for p in _players:
		cols.append(Color.hex((int(p.get("color", 0xffffff)) << 8) | 0xff))
	var bg := minf(t * 6.0, 1.0) * fade
	var a := cols[0].darkened(0.75)
	var b := cols[1].darkened(0.75)
	var dark := Color(0.02, 0.01, 0.05)
	# Metà sinistra e metà destra, ognuna nel colore del suo lottatore che sfuma verso il centro
	var tilt := h * 0.09
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w / 2 + tilt, 0), Vector2(w / 2 - tilt, h), Vector2(0, h)]),
		PackedColorArray([Color(a, 0.97 * bg), Color(dark, 0.97 * bg), Color(dark, 0.97 * bg), Color(a, 0.97 * bg)]))
	draw_polygon(PackedVector2Array([Vector2(w / 2 + tilt, 0), Vector2(w, 0), Vector2(w, h), Vector2(w / 2 - tilt, h)]),
		PackedColorArray([Color(dark, 0.97 * bg), Color(b, 0.97 * bg), Color(b, 0.97 * bg), Color(dark, 0.97 * bg)]))
	# Righe orizzontali sottili, come un'insegna vista da vicino
	for y in range(0, int(h), 6):
		draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.18 * bg), 2.0)
	var variants: Dictionary = FighterPose.variant_ranks(_players)
	for i in 2:
		var k := card_in(t, i)
		if k <= 0.0:
			continue
		_draw_poster_fighter(_players[i], i, w, h, (1.0 - k) * w * 0.6, int(variants.get(_players[i].id, 0)), cols[i], fade)
	# La riga di luce che divide le due metà
	var split := minf(t * 5.0, 1.0)
	var top := Vector2(w / 2 + tilt, 0)
	var bottom := top.lerp(Vector2(w / 2 - tilt, h), split)
	for glow in [[22.0, 0.12], [10.0, 0.3], [3.0, 1.0]]:
		draw_line(top, bottom, Color(1, 1, 1, glow[1] * fade), glow[0])
	var vs_t := CARD_FIRST + 2 * CARD_GAP + 0.04
	if t >= vs_t:
		_draw_neon("VS", Vector2(w / 2, h * 0.5), 190, cols[0].lerp(cols[1], 0.5).lightened(0.3), (t - vs_t) * 0.5, fade)
	_centered("PREPARATEVI!", Vector2(w / 2, h * 0.1), 36, Color(1.0, 0.81, 0.29, fade))


# Un lottatore della locandina: alone del suo colore, sagoma bianca al neon, il corpo intero, il nome in basso
func _draw_poster_fighter(p: Dictionary, i: int, w: float, h: float, slide: float, variant: int, color: Color, alpha: float) -> void:
	var side := -1.0 if i == 0 else 1.0
	var area := Rect2(w * (0.03 if i == 0 else 0.55), h * (0.97 - POSTER_H) - 30.0, w * 0.42, h * POSTER_H)
	area.position.x += side * slide
	var center := area.get_center()
	for step in 8:
		draw_circle(center, area.size.y * (0.56 - step * 0.05), Color(color, 0.06 * alpha))
	var look: Dictionary = FighterPose.look(game, str(p.get("characterId", "")), FighterPose.skin_of(p))
	var src := body_of(look)
	if src.is_empty():
		var initial := str(look.get("name", p.get("name", "?"))).left(1).to_upper()
		_draw_neon(initial, center, int(area.size.y * 0.6), color, 1.0, alpha)
	else:
		var region: Rect2 = src[1]
		var k := minf(area.size.x / region.size.x, area.size.y / region.size.y)
		var size := region.size * k
		# In basso al suo riquadro, e chi sta a destra si gira verso il centro
		var at := Vector2(center.x - size.x / 2, area.end.y - size.y)
		var flip := 1.0 if i == 0 else -1.0
		draw_set_transform(Vector2(at.x + (size.x if flip < 0 else 0.0), at.y), 0.0, Vector2(flip, 1))
		var white := FighterPose.sprite_modulate(0, alpha, 1.0)
		for d in [Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5), Vector2(4, 4), Vector2(-4, 4), Vector2(4, -4), Vector2(-4, -4)]:
			draw_texture_rect_region(src[0], Rect2(d, size), region, white)
		draw_texture_rect_region(src[0], Rect2(Vector2.ZERO, size), region, FighterPose.sprite_modulate(variant, alpha))
		draw_set_transform(Vector2.ZERO)
	# Nome del giocatore grande, personaggio sotto nel suo colore
	var x := area.position.x + 20.0 if i == 0 else area.end.x - 20.0
	var name_px := Access.px(54)
	var player := str(p.get("name", "?")).to_upper()
	var character: Dictionary = game.get("characters", {}).get(str(p.get("characterId", "")), {})
	var role := str(character.get("name", "")).to_upper()
	var nw := _font.get_string_size(player, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
	var rw := _font.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(24)).x
	_outlined(player, Vector2(x if i == 0 else x - nw, h - 58), 54, Color(1, 1, 1, alpha))
	_outlined(role, Vector2(x if i == 0 else x - rw, h - 24), 24, Color(color.lightened(0.35), alpha))


# Scritta al neon: alone colorato a strati e cuore quasi bianco, che arriva grande e si assesta
func _draw_neon(text: String, center: Vector2, px: int, color: Color, t: float, alpha: float) -> void:
	var pop := 1.0 + 0.6 * pow(1.0 - clampf(t * 3.0, 0.0, 1.0), 3.0)
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	draw_set_transform(center, 0.0, Vector2(pop, pop))
	var at := Vector2(-s.x / 2, s.y * 0.3)
	for glow in [[48, 0.1], [30, 0.18], [16, 0.45]]:
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, glow[0], Color(color, glow[1] * alpha))
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color(color, alpha))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(color.lightened(0.75), alpha))
	draw_set_transform(Vector2.ZERO)


# Il corpo intero del personaggio (il primo fotogramma di idle, senza bordi vuoti); senza sprite il ritratto
func body_of(look: Dictionary) -> Array:
	var id := str(look.get("id", ""))
	if _bodies.has(id):
		return _bodies[id]
	var out := []
	var sprite: Variant = look.get("sprite")
	if sprite is Dictionary:
		var path: String = "%s/idle.png" % sprite.dir if sprite.has("dir") else sprite.path
		var tex: Texture2D = load("res://data/" + path)
		if tex != null:
			var image := tex.get_image()
			var frame := Rect2i(0, 0, int(sprite.frameWidth), int(sprite.frameHeight))
			if image != null:
				if image.is_compressed():
					image.decompress()
				var used := image.get_region(frame).get_used_rect()
				if used.size.x > 0:
					frame = Rect2i(used.position, used.size)
			out = [tex, Rect2(frame)]
	if out.is_empty() and portrait_of.is_valid():
		out = portrait_of.call(look)
	_bodies[id] = out
	return out


# VIA!: lampo bianco, raggi che partono dal centro e la scritta che esplode
func _draw_go(w: float, h: float, t: float) -> void:
	var flash := 1.0 - minf(t * GO_MS / FLASH_MS, 1.0)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.45 * flash))
	var center := Vector2(w / 2, h * 0.42)
	var rays := 18
	for i in rays:
		var a := TAU * i / rays + 0.15
		var inner := 120.0 + t * 500.0
		var outer := inner + 80.0 + 200.0 * (1.0 - t)
		var dir := Vector2.from_angle(a)
		draw_line(center + dir * inner, center + dir * outer, Color(1.0, 0.95, 0.6, 0.8 * (1.0 - t)), 6.0 * (1.0 - t) + 1.0)
	_draw_big("VIA!", center, 200, GO_COLOR, t)


# Suoni e voci nei momenti giusti: ognuno una volta sola, anche se lo snapshot arriva in ritardo
func _cue_timeline() -> void:
	var countdown: float = float(game.get("prematch", {}).get("countdownMs", 3000))
	var label := count_label(_left_ms, countdown)
	if label != "":
		_cue(label)
		return
	var t := intro_t(_left_ms, countdown, _intro_ms())
	_cue("intro")
	for i in _players.size():
		if card_in(t, i) > 0.0:
			_cue("card%d" % i)
	if _players.size() >= 2 and t >= CARD_FIRST + _players.size() * CARD_GAP + 0.04:
		_cue("vs")


func _cue(key: String) -> void:
	if _cued.has(key):
		return
	_cued[key] = true
	cue.emit("card" if key.begins_with("card") else key)
