# Suprema "drop" (#102), quella di Bonobot. Bonobot salta ad afferrare la liana che scende un po' davanti
# a lui e la tira (il salto e la capriola indietro li muove il server). Dall'alto l'orsogufo Omar, legato
# all'altro capo, cade di peso in verticale sulla liana, con la liana che gli sventola dietro; schiaccia,
# resta a terra stordito, fa puff e al suo posto compare lo gnomo Omar che scappa verso il bordo più
# vicino. Col puff sparisce anche la liana.
# Solo disegno: parte dall'evento attack con kind "supreme" e segue i tempi e i disegni del personaggio in
# game.json (characters.<id>.supreme). Il colpo vero lo decide il server.
extends Node2D

signal impact(strength: float) # l'orsogufo tocca terra: world_view fa tremare lo schermo

const PUFF_MS := 380.0 # durata della nuvola del puff
const RUNNER_DELAY_MS := 140.0 # lo gnomo esce dalla nuvola un attimo dopo
const RUNNER_MAX_MS := 3000.0 # oltre, anche se non è uscito dallo schermo, sparisce
const SQUASH_MS := 160.0 # rimbalzo dell'orsogufo quando tocca terra
const ROPE_TAIL := 240.0 # pixel di liana che sventola sopra l'orsogufo mentre cade
const IMPACT_SHAKE := 12.0
const INK := Color("221c1a")
const ROPE := Color("557f2e")
const ROPE_SH := Color("36571c")
const LEAF := Color("6f9a3c")
const CLOUD := Color("eef2ea")
const CLOUD_SH := Color("bccab6")

var game: Dictionary
var stage: Dictionary
var view_rect := Rect2(0, 0, 1280, 720) # lo aggiorna world_view: da qui cade l'orsogufo e lì esce lo gnomo
var fixed_now := -1.0 # per i test e le anteprime: se >= 0 è l'orologio in ms al posto di quello vero
var _runs: Array = [] # [{ id, sp, x, ground, hand, t0, dir, shook }]
var _tex := {} # percorso -> Texture2D
var _font: Font = ThemeDB.fallback_font


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
		"shook": false,
	})


func clear() -> void:
	_runs = []


# Chi sta facendo la suprema non lampeggia per l'invulnerabilità
func holds(id: String, now: float) -> bool:
	for r in _runs:
		var sp: Dictionary = r.sp
		if r.id == id and now - r.t0 < impact_at(sp) + float(sp.impactMs) + float(sp.recoverMs):
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
	for r in _runs:
		if not r.shook and now - r.t0 >= impact_at(r.sp):
			r.shook = true
			impact.emit(IMPACT_SHAKE)
	_runs = _runs.filter(func(r): return now - r.t0 < puff_at(r.sp) + RUNNER_DELAY_MS + RUNNER_MAX_MS)
	queue_redraw()


func _draw() -> void:
	var now := _now()
	for r in _runs:
		_draw_run(r, now - r.t0)


static func impact_at(sp: Dictionary) -> float:
	return float(sp.leapMs) + float(sp.pullMs) + float(sp.warnMs)


# Il puff arriva alla fine dell'attesa: l'orsogufo resta a terra stordito per impactMs + recoverMs
static func puff_at(sp: Dictionary) -> float:
	return impact_at(sp) + float(sp.impactMs) + float(sp.recoverMs) * 0.6


func _draw_run(r: Dictionary, ms: float) -> void:
	var sp: Dictionary = r.sp
	var art: Dictionary = sp.get("art", {})
	var x: float = r.x
	var ground: float = r.ground
	var top := view_rect.position.y - 40.0
	var impact := impact_at(sp)
	var puff := puff_at(sp)
	var fall_from := impact - float(sp.fallMs)
	var pulled := float(sp.leapMs) + float(sp.pullMs)

	# 1. La liana scende mentre Bonobot salta, lui la tira, poi resta a penzolare finché parte l'orsogufo
	if ms < fall_from:
		var k := clampf(ms / float(sp.leapMs), 0.0, 1.0)
		var tip := lerpf(top, r.hand, 1.0 - (1.0 - k) * (1.0 - k))
		var pull := 0.0
		if ms >= float(sp.leapMs) and ms < pulled:
			pull = sin((ms - float(sp.leapMs)) / float(sp.pullMs) * PI) * 18.0 # la tira giù
		var sway := 0.0 if ms < pulled else sin((ms - pulled) / 90.0) * 10.0 # lasciata, oscilla
		_draw_rope([Vector2(x, top), Vector2(x + sway * 0.4, (top + tip) / 2), Vector2(x + sway, tip + pull)], ms, true)

	# 2. Ombra: compare quando la tira, si allarga e scurisce fino all'impatto
	if ms >= pulled and ms < impact + float(sp.impactMs):
		var k := clampf((ms - pulled) / float(sp.warnMs), 0.0, 1.0)
		var w := float(sp.width) * (0.3 + 0.7 * k * k)
		_ellipse(Vector2(x, ground), Vector2(w / 2, 6.0 + 7.0 * k), Color(0, 0, 0, 0.15 + 0.35 * k))
		var pulse := 0.5 + 0.5 * sin(ms / 60.0)
		_ellipse_outline(Vector2(x, ground), Vector2(float(sp.width) / 2, 14.0), Color(1, 0.3, 0.25, (0.3 + 0.45 * pulse) * k), 2.5)

	var scale: float = float(art.get("scale", 0.5))
	var falling := _texture(art, "falling")
	var landed := _texture(art, "landed")

	# 3. Caduta di peso: parte ferma da sopra lo schermo e accelera fino a terra (moto uniformemente accelerato),
	# allungata dalla velocità, con la liana legata che le sventola sopra
	if ms >= fall_from and ms < impact and falling != null:
		var size := falling.get_size() * scale
		var k := (ms - fall_from) / float(sp.fallMs)
		var start_feet := top - 30.0
		var feet := lerpf(start_feet, ground, k * k)
		var stretch := 1.0 + 0.16 * k
		var knot := Vector2(x, feet - size.y * stretch * 0.62)
		var flap := sin(ms / 45.0) * (8.0 + 22.0 * k)
		_draw_rope([knot, knot + Vector2(flap * 0.5, -ROPE_TAIL * 0.5), knot + Vector2(-flap, -ROPE_TAIL)], ms, false)
		_draw_texture_at(falling, Vector2(x, feet), Vector2(scale / stretch, scale * stretch))
		_draw_label(str(sp.label), Vector2(x, feet - size.y * stretch - 6))

	# 4. A terra: schiacciato col rimbalzo, stordito, con la liana afflosciata accanto, fino al puff
	if ms >= impact and ms < puff:
		var since := ms - impact
		var k := clampf(since / SQUASH_MS, 0.0, 1.0)
		var squash := 1.0 - 0.32 * exp(-5.0 * k) * cos(k * PI * 2.5) # schiacciato, poi si assesta
		_draw_slack_rope(x + float(r.dir) * 20.0, ground, int(r.dir), ms)
		if landed != null:
			var size := landed.get_size() * scale
			_draw_texture_at(landed, Vector2(x, ground + 6), Vector2(scale * (2.0 - squash), scale * squash))
			_draw_label(str(sp.label), Vector2(x, ground - size.y * squash - 2))

	# 5. Impatto: anello sul terreno, polvere e sassolini
	if ms >= impact and ms < impact + 420.0:
		var k := (ms - impact) / 420.0
		_ellipse_outline(Vector2(x, ground), Vector2(float(sp.width) * (0.55 + 0.5 * k), 16.0 * (1.0 + k)), Color(1, 0.95, 0.85, 1.0 - k), 5.0 * (1.0 - k) + 1.0)
		for i in 10:
			var a := PI + PI * (i + 0.5) / 10.0
			var d := 30.0 + 120.0 * k
			var p := Vector2(x + cos(a) * d * 1.3, ground + sin(a) * d * 0.55 + 260.0 * k * k)
			draw_circle(p, 4.0 * (1.0 - k) + 1.0, Color(0.55, 0.45, 0.35, 1.0 - k))
		for side in [-1.0, 1.0]:
			for i in 3:
				var c := Vector2(x + side * (40.0 + 60.0 * k + i * 18.0), ground - 8.0 - i * 6.0)
				draw_circle(c, (10.0 + i * 3.0) * (0.6 + k), Color(0.9, 0.85, 0.75, 0.75 * (1.0 - k)))

	# 6. Puff: nuvola a 2 toni con l'inchiostro, che si gonfia e svanisce; si porta via orsogufo e liana
	if ms >= puff and ms < puff + PUFF_MS:
		_draw_puff(Vector2(x, ground - 46.0), (ms - puff) / PUFF_MS)

	# 7. Lo gnomo Omar esce dalla nuvola e scappa verso il bordo più vicino
	var run_ms := ms - puff - RUNNER_DELAY_MS
	var runner := _texture(art, "runner")
	if run_ms >= 0 and runner != null:
		var frames := int(art.get("runnerFrames", 1))
		var fw := runner.get_size().x / frames
		var fh := runner.get_size().y
		var gx: float = x + float(r.dir) * float(sp.runSpeed) * run_ms / 1000.0
		if gx > view_rect.position.x - fw and gx < view_rect.end.x + fw:
			var frame := int(run_ms / 1000.0 * float(art.get("runnerFps", 12))) % frames
			draw_set_transform(Vector2(gx, ground), 0, Vector2(float(r.dir) * scale, scale))
			draw_texture_rect_region(runner, Rect2(-fw / 2, -fh, fw, fh), Rect2(frame * fw, 0, fw, fh))
			draw_set_transform(Vector2.ZERO)
			_draw_label(str(sp.label), Vector2(gx, ground - fh * scale - 6))


# Una texture con i piedi (il centro del bordo basso) in feet
func _draw_texture_at(tex: Texture2D, feet: Vector2, s: Vector2) -> void:
	var size := tex.get_size()
	draw_set_transform(feet, 0, s)
	draw_texture(tex, Vector2(-size.x / 2, -size.y))
	draw_set_transform(Vector2.ZERO)


# La liana: una corda a 2 toni con l'inchiostro lungo una curva che passa per i punti, con le foglie
func _draw_rope(points: Array, ms: float, leaves: bool) -> void:
	var pts := PackedVector2Array()
	var n := 16
	for i in n + 1:
		pts.append(_bezier(points, float(i) / n))
	draw_polyline(pts, INK, 11.0, true)
	draw_polyline(pts, ROPE, 6.0, true)
	var shade := PackedVector2Array()
	for p in pts:
		shade.append(p + Vector2(1.5, 0))
	draw_polyline(shade, ROPE_SH, 2.0, true)
	if not leaves:
		return
	var length := pts[0].distance_to(pts[n])
	var count := int(length / 52.0)
	for i in count:
		var p := _bezier(points, (i + 0.6) / maxf(1.0, count))
		var side := 1.0 if i % 2 == 0 else -1.0
		var sway := sin(ms / 150.0 + i) * 0.25
		_leaf(p, side, sway)


func _leaf(p: Vector2, side: float, sway: float) -> void:
	var a := (-0.6 + sway) * side
	var d := Vector2(cos(a) * side, sin(a)) * 18.0
	var nrm := Vector2(-d.y, d.x).normalized() * 6.0
	var poly := PackedVector2Array([p, p + d * 0.5 + nrm, p + d, p + d * 0.5 - nrm])
	draw_colored_polygon(poly, LEAF)
	poly.append(p)
	draw_polyline(poly, INK, 2.0, true)


# La liana afflosciata a terra accanto all'orsogufo, a riccioli
func _draw_slack_rope(x: float, ground: float, dir: int, ms: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector2(x + dir * (t * 90.0 + sin(t * 9.0) * 10.0), ground - 4.0 - absf(sin(t * 9.0)) * 9.0))
	draw_polyline(pts, INK, 11.0, true)
	draw_polyline(pts, ROPE, 6.0, true)


func _draw_puff(c: Vector2, k: float) -> void:
	var grow := 1.0 - (1.0 - k) * (1.0 - k)
	var alpha := 1.0 if k < 0.6 else (1.0 - k) / 0.4
	var blobs := [Vector2(0, 0), Vector2(-42, 10), Vector2(42, 8), Vector2(-24, -30), Vector2(26, -32), Vector2(0, -50), Vector2(-50, -18), Vector2(52, -16)]
	for pass_i in 3: # inchiostro, tono base, ombra
		for i in blobs.size():
			var b: Vector2 = blobs[i]
			var r := (22.0 + (i % 3) * 5.0) * (0.5 + 0.8 * grow)
			var p := c + b * (0.6 + 0.7 * grow)
			if pass_i == 0:
				draw_circle(p, r + 3.0, Color(INK, alpha))
			elif pass_i == 1:
				draw_circle(p, r, Color(CLOUD, alpha))
			else:
				draw_circle(p + Vector2(r * 0.25, r * 0.3), r * 0.6, Color(CLOUD_SH, alpha * 0.9))
	for i in 5: # scintille
		var a := TAU * i / 5.0 + k * 2.0
		var p := c + Vector2(cos(a), sin(a)) * (40.0 + 70.0 * grow)
		draw_circle(p, 4.0 * (1.0 - k) + 1.0, Color(1, 0.95, 0.6, alpha))


func _draw_label(text: String, at: Vector2) -> void:
	var px := Access.px(16)
	var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, px)
	draw_string_outline(_font, Vector2(at.x - size.x / 2, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, Vector2(at.x - size.x / 2, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)


func _texture(art: Dictionary, key: String) -> Texture2D:
	if not art.has(key) or not art.has("dir"):
		return null
	var path := "res://data/%s/%s" % [art.dir, art[key]]
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(c, r), color)


func _ellipse_outline(c: Vector2, r: Vector2, color: Color, width := 2.0) -> void:
	var pts := _ellipse_points(c, r)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)


static func _ellipse_points(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


# Curva che passa vicino ai punti (Bézier di grado qualsiasi)
static func _bezier(points: Array, t: float) -> Vector2:
	var pts := points.duplicate()
	while pts.size() > 1:
		var next := []
		for i in pts.size() - 1:
			next.append((pts[i] as Vector2).lerp(pts[i + 1], t))
		pts = next
	return pts[0]


# Il terreno sotto x da y in giù: il bordo alto del blocco o della piattaforma più vicina. Senza, y.
# Come groundBelow() in src/shared/physics/supreme.ts
static func ground_y(stage_spec: Dictionary, x: float, y: float) -> float:
	var best := INF
	for list in [stage_spec.get("solids", []), stage_spec.get("platforms", [])]:
		for s in list:
			if x >= float(s.x) and x <= float(s.x) + float(s.width) and float(s.y) >= y - 1.0:
				best = minf(best, float(s.y))
	return y if best == INF else best


# Da che parte scappa lo gnomo: verso il bordo più vicino dei blocchi pieni
static func escape_dir(stage_spec: Dictionary, x: float) -> int:
	var best_d := INF
	var dir := 1
	for s in stage_spec.get("solids", []):
		for edge in [float(s.x), float(s.x) + float(s.width)]:
			var d := absf(edge - x)
			if d < best_d:
				best_d = d
				dir = -1 if edge < x else 1
	return dir
