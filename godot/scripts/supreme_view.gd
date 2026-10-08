# Suprema "drop" (#102), quella di Bonobot: la liana scende un po' davanti a lui, Bonobot salta ad
# afferrarla e la tira, l'ombra avvisa, l'orsogufo Omar cade in verticale sulla liana mentre Bonobot
# fa la capriola indietro, schiaccia, fa puff e diventa uno gnomo che scappa verso il bordo più vicino.
# Il salto e la capriola li muove il server: qui si disegna il resto.
# Solo disegno: parte dall'evento attack con kind "supreme" e segue i tempi del personaggio in game.json
# (characters.<id>.supreme). Il colpo vero lo decide il server. Le forme sono provvisorie: quando ci
# saranno i disegni di Riccardo (liana, orsogufo, puff, gnomo) si sostituiscono qui.
extends Node2D

const PUFF_MS := 320.0 # durata della nuvola del puff
const GNOME_DELAY_MS := 120.0 # lo gnomo esce dalla nuvola un attimo dopo
const GNOME_MAX_MS := 3000.0 # oltre, anche se non è uscito dallo schermo, sparisce
const BEAR_W := 92.0 # sagoma provvisoria dell'orsogufo, pixel
const BEAR_H := 104.0
const GNOME_H := 52.0

var game: Dictionary
var stage: Dictionary
var view_rect := Rect2(0, 0, 1280, 720) # lo aggiorna world_view, per sapere quando lo gnomo è uscito
var _runs: Array = [] # [{ id, sp, x, ground, hand, t0, dir }]
var _font: Font = ThemeDB.fallback_font
var fixed_now := -1.0 # per i test e le anteprime: se >= 0 è l'orologio in ms al posto di quello vero


func _now() -> float:
	return fixed_now if fixed_now >= 0 else float(Time.get_ticks_msec())


# p: lo stato interpolato di chi la lancia, character: il suo blocco in game.json
func start(p: Dictionary, character: Dictionary) -> void:
	var sp: Variant = character.get("supreme")
	if not (sp is Dictionary) or str(sp.get("type", "")) != "drop":
		return
	var x: float = float(p.x) + float(p.get("facing", 1)) * float(sp.leapDx) # la liana, come supremeX sul server
	var y: float = p.y
	_runs.append({
		"id": p.id,
		"sp": sp,
		"x": x,
		"ground": ground_y(stage, x, y),
		"hand": y - float(sp.leapDy) - float(game.fighter.height) * 0.95, # dove la mano prende la liana
		"t0": _now(),
		"dir": escape_dir(stage, x),
	})


func clear() -> void:
	_runs = []


# Chi sta facendo la suprema non lampeggia per l'invulnerabilità: è appeso alla liana
func holds(id: String, now: float) -> bool:
	for r in _runs:
		var sp: Dictionary = r.sp
		if r.id == id and now - r.t0 < _impact_at(sp) + float(sp.impactMs) + float(sp.recoverMs):
			return true
	return false


# Il centro dell'impatto della suprema di id (la liana), per disegnare la hitbox lì. null se non c'è
func origin(id: String) -> Variant:
	for r in _runs:
		if r.id == id:
			return Vector2(r.x, r.ground)
	return null


func _process(_delta: float) -> void:
	if _runs.is_empty():
		return
	var now := _now()
	_runs = _runs.filter(func(r): return now - r.t0 < _impact_at(r.sp) + float(r.sp.impactMs) + GNOME_DELAY_MS + GNOME_MAX_MS)
	queue_redraw()


func _draw() -> void:
	var now := _now()
	for r in _runs:
		_draw_run(r, now - r.t0)


static func _impact_at(sp: Dictionary) -> float:
	return float(sp.leapMs) + float(sp.pullMs) + float(sp.warnMs)


func _draw_run(r: Dictionary, ms: float) -> void:
	var sp: Dictionary = r.sp
	var impact := _impact_at(sp)
	var after := ms - impact - float(sp.impactMs) # ms dalla fine dell'impatto
	var x: float = r.x
	var ground: float = r.ground
	var top := view_rect.position.y - 60.0

	# Liana: scende dall'alto mentre Bonobot salta, resta finché l'orsogufo arriva a terra
	if ms < impact + float(sp.impactMs):
		var k := clampf(ms / float(sp.leapMs), 0.0, 1.0)
		var tip := lerpf(top, r.hand, _ease_out(k))
		_draw_vine(Vector2(x, top), Vector2(x, tip), ms)

	# Ombra a terra: compare quando tira la liana, si allarga e scurisce fino all'impatto
	var pulled := float(sp.leapMs) + float(sp.pullMs)
	if ms >= pulled and ms < impact + float(sp.impactMs):
		var k := clampf((ms - pulled) / float(sp.warnMs), 0.0, 1.0)
		var w := float(sp.width) * (0.35 + 0.65 * k)
		_ellipse(Vector2(x, ground), Vector2(w / 2, 9.0 + 5.0 * k), Color(0, 0, 0, 0.18 + 0.32 * k))
		# Un bordo rosso che pulsa: si capisce che lì sta per cadere qualcosa
		var pulse := 0.5 + 0.5 * sin(ms / 70.0)
		_ellipse_outline(Vector2(x, ground), Vector2(float(sp.width) / 2, 14.0), Color(1, 0.3, 0.25, 0.35 + 0.4 * pulse * k))

	# Orsogufo: cade negli ultimi fallMs dell'ombra, schiacciato durante l'impatto
	var fall_from := impact - float(sp.fallMs)
	if ms >= fall_from and after < 0:
		var k := clampf((ms - fall_from) / float(sp.fallMs), 0.0, 1.0)
		var feet := lerpf(top, ground, k * k) # accelera cadendo
		var squash := 1.0
		if ms >= impact:
			squash = 0.75 # schiacciato a terra
		_draw_bear(Vector2(x, feet), squash)
		_draw_label(str(sp.label), Vector2(x, feet - BEAR_H * squash - 26)) # sopra le orecchie

	# Impatto: un anello che si allarga sul terreno
	if ms >= impact and after < 250.0:
		var k := clampf((ms - impact) / (float(sp.impactMs) + 250.0), 0.0, 1.0)
		var ring := Color(1, 0.95, 0.8, 1.0 - k)
		_ellipse_outline(Vector2(x, ground), Vector2(float(sp.width) / 2 * (0.8 + 0.6 * k), 18.0 * (0.8 + 0.6 * k)), ring, 5.0)

	# Puff: nuvola verde-grigia che si gonfia e svanisce
	if after >= 0 and after < PUFF_MS:
		var k := after / PUFF_MS
		for i in 7:
			var a := TAU * i / 7.0 + 0.4
			var c := Vector2(x, ground - BEAR_H * 0.45) + Vector2(cos(a), sin(a) * 0.7) * (22.0 + 40.0 * k)
			draw_circle(c, 20.0 + 14.0 * k, Color(0.82, 0.9, 0.8, 0.85 * (1.0 - k)))

	# Gnomo: esce dalla nuvola e corre verso il bordo più vicino, con l'etichetta sopra
	var run_ms := after - GNOME_DELAY_MS
	if run_ms >= 0:
		var gx: float = x + float(r.dir) * float(sp.runSpeed) * run_ms / 1000.0
		if gx > view_rect.position.x - 80 and gx < view_rect.end.x + 80:
			var bob := absf(sin(run_ms / 55.0)) * 4.0 # saltella correndo
			_draw_gnome(Vector2(gx, ground - bob), int(r.dir), run_ms)
			_draw_label(str(sp.label), Vector2(gx, ground - bob - GNOME_H - 10))


func _draw_vine(a: Vector2, b: Vector2, ms: float) -> void:
	var green := Color("3f6b2a")
	draw_line(a, b, green, 6.0)
	# Foglie a intervalli, che ondeggiano appena
	var n := int((b.y - a.y) / 46.0)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / maxf(1.0, n))
		var side := 1.0 if i % 2 == 0 else -1.0
		var sway := sin(ms / 160.0 + i) * 3.0
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 16 + sway, -6), p + Vector2(side * 8, 6)]), Color("5b8f3a"))


# Sagoma provvisoria: corpo bianco tondo, orecchie a ciuffo, becco giallo, occhi grandi
func _draw_bear(feet: Vector2, squash: float) -> void:
	var w := BEAR_W / squash * 0.9 + BEAR_W * 0.1
	var h := BEAR_H * squash
	var body := Vector2(feet.x, feet.y - h * 0.45)
	_ellipse(body, Vector2(w / 2, h * 0.45), Color("f2efe8"))
	_ellipse_outline(body, Vector2(w / 2, h * 0.45), Color("2b2622"), 3.0)
	var head := Vector2(feet.x, feet.y - h * 0.8)
	draw_circle(head, w * 0.3, Color("f2efe8"))
	draw_arc(head, w * 0.3, 0, TAU, 24, Color("2b2622"), 3.0)
	for s in [-1.0, 1.0]:
		var ear := head + Vector2(s * w * 0.2, -w * 0.25)
		draw_colored_polygon(PackedVector2Array([ear + Vector2(-8, 6), ear + Vector2(s * 6, -14), ear + Vector2(8, 6)]), Color("d9d3c7"))
		draw_circle(head + Vector2(s * w * 0.11, -2), 7.0, Color("1d1a17"))
		draw_circle(head + Vector2(s * w * 0.11 + 2, -4), 2.0, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-6, 6), head + Vector2(6, 6), head + Vector2(0, 17)]), Color("e0a526"))


# Sagoma provvisoria: gnomo pelato, pelle nero perlato, armatura di cuoio, gambe che corrono
func _draw_gnome(feet: Vector2, dir: int, ms: float) -> void:
	var skin := Color("26232b")
	var leather := Color("7a4a26")
	var step := sin(ms / 55.0) * 7.0
	draw_line(feet + Vector2(-4, -14), feet + Vector2(-4 + step, 0), skin, 5.0)
	draw_line(feet + Vector2(4, -14), feet + Vector2(4 - step, 0), skin, 5.0)
	draw_rect(Rect2(feet.x - 11, feet.y - 36, 22, 24), leather)
	draw_rect(Rect2(feet.x - 11, feet.y - 36, 22, 24), Color("3b2412"), false, 2.0)
	var head := feet + Vector2(dir * 2, -GNOME_H + 9)
	draw_circle(head, 11.0, skin)
	draw_circle(head + Vector2(-dir * 3, -5), 3.0, Color(1, 1, 1, 0.35)) # la pelle perlata luccica
	draw_circle(head + Vector2(dir * 5, -1), 2.0, Color.WHITE)


func _draw_label(text: String, at: Vector2) -> void:
	var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, Access.px(16))
	draw_string(_font, Vector2(at.x - size.x / 2, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), Color.WHITE)


func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(c, r), color)


func _ellipse_outline(c: Vector2, r: Vector2, color: Color, width := 2.0) -> void:
	var pts := _ellipse_points(c, r)
	pts.append(pts[0])
	draw_polyline(pts, color, width)


static func _ellipse_points(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


static func _ease_out(k: float) -> float:
	return 1.0 - (1.0 - k) * (1.0 - k)


# Il terreno sotto x da y in giù: il bordo alto del blocco o della piattaforma più vicina. Senza, y
static func ground_y(stage_spec: Dictionary, x: float, y: float) -> float:
	var best := INF
	for list in [stage_spec.get("solids", []), stage_spec.get("platforms", [])]:
		for s in list:
			if x >= float(s.x) and x <= float(s.x) + float(s.width) and float(s.y) >= y - 1.0:
				best = minf(best, float(s.y))
	return y if best == INF else best


# Da che parte scappa lo gnomo: verso il bordo più vicino del blocco su cui si è (o del più vicino)
static func escape_dir(stage_spec: Dictionary, x: float) -> int:
	var best_d := INF
	var dir := 1
	for s in stage_spec.get("solids", []):
		var left: float = float(s.x)
		var right: float = float(s.x) + float(s.width)
		for edge in [left, right]:
			var d := absf(edge - x)
			if d < best_d:
				best_d = d
				dir = -1 if edge < x else 1
	return dir
