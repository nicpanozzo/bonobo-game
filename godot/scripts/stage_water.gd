# L'acqua e il vento delle arene, solo disegno: getti e fontane (#253, #288), raffiche (#433) e gli spruzzi che reggono
# le piattaforme di Padova (#378). Dove sono e in che fase li dice stage_motion.gd; world_view.gd lo chiama dentro _draw
# passando sé stesso (ci) e la luce dell'arena.
extends RefCounted

const StageMotion := preload("res://scripts/stage_motion.gd")

var life: RefCounted # lo sfondo vivo di world_view (stage_life.gd): i fogli dipinti dell'acqua


# Getto d'acqua (#253): bolle durante l'avviso, poi una colonna d'acqua spumosa che sale. Stessa fase di jetPhase().
# Con idle (#288) è una fontana: a riposo lo zampillo resta basso, con l'avviso cresce, poi sale tutto
func draw_jet(ci: CanvasItem, light: Color, j: Dictionary, t: float) -> void:
	var phase := StageMotion.jet_phase(j, t)
	if j.has("dir"): # raffica di vento (#433): si disegna di lato, non come colonna d'acqua
		_draw_gust(ci, light, j, t, phase)
		return
	var idle := float(j.get("idle", 0))
	if phase == "calm" and idle <= 0.0:
		return
	var x0: float = j.x
	var w: float = j.width
	var base: float = j.y
	if phase == "warn":
		for i in 6:
			var bx := x0 + w * (0.15 + 0.7 * fposmod(i * 0.37, 1.0))
			var rise := fposmod(t / 6.0 + i * 23.0, 40.0)
			ci.draw_arc(Vector2(bx, base - 4 - rise), 3.0 + (i % 3), 0, TAU, 10, Color(0.85, 0.92, 0.9, 0.8 - rise / 50.0), 1.5)
		if idle <= 0.0:
			return
	var h: float = j.height
	if phase == "calm":
		h = idle
	elif phase == "warn":
		h = idle * (1.3 + 0.25 * sin(t / 60.0)) # gorgoglia e cresce: sta per partire
	if idle > 0.0:
		_draw_fountain_plume(ci, light, x0 + w / 2.0, base, w, h, t, phase == "active")
		return
	var col := Color(0.55, 0.7, 0.72, 0.55)
	# Il bordo destro dal basso in alto, poi il sinistro dall'alto in basso: un poligono semplice che ondeggia
	var pts := PackedVector2Array()
	for i in 10:
		var k := i / 9.0
		pts.append(Vector2(x0 + w * (0.5 + 0.4 * (1.0 - k * 0.6)) + sin(t / 70.0 + k * 9.0) * w * 0.08, base - h * k))
	for i in range(9, -1, -1):
		var k := i / 9.0
		pts.append(Vector2(x0 + w * (0.5 - 0.4 * (1.0 - k * 0.6)) + sin(t / 70.0 + k * 9.0 + 1.3) * w * 0.08, base - h * k))
	ci.draw_colored_polygon(pts, col)
	for i in 5: # schizzi in cima
		var a := t / 120.0 + i * 1.3
		ci.draw_circle(Vector2(x0 + w / 2 + cos(a) * w * 0.5, base - h + sin(a * 1.7) * 10), 4.0, Color(0.85, 0.93, 0.92, 0.8))


# Raffica di vento (#433, jets con dir): con l'avviso qualche foglia/pulviscolo comincia a scivolare nel verso,
# poi righe di vento semitrasparenti attraversano la zona. Pochi segmenti, nessun nodo: costa poco
func _draw_gust(ci: CanvasItem, light: Color, j: Dictionary, t: float, phase: String) -> void:
	if phase == "calm":
		return
	var sign_x: float = -1.0 if str(j.dir) == "left" else 1.0
	var x0: float = j.x
	var w: float = j.width
	var h: float = j.height
	var top: float = float(j.y) - h
	if phase == "warn":
		for i in 6:
			var k := fposmod(t / 1400.0 + i * 0.173, 1.0) # avanzamento nella zona, da 0 a 1
			var px := x0 + w * (k if sign_x > 0.0 else 1.0 - k)
			var py := top + h * fposmod(i * 0.41, 1.0) + sin(t / 260.0 + i) * 6.0
			ci.draw_circle(Vector2(px, py), 2.0 + (i % 2), Color(0.78, 0.74, 0.55, 0.7 * sin(k * PI)))
		return
	for i in 8:
		var k := fposmod(t / 380.0 + i * 0.131, 1.0)
		var streak := minf(w * 0.5, 110.0) * (0.6 + 0.4 * fposmod(i * 0.57, 1.0))
		var head := x0 + (w + streak) * (k if sign_x > 0.0 else 1.0 - k) - (streak if sign_x > 0.0 else 0.0)
		var py := top + h * (0.08 + 0.84 * fposmod(i * 0.37, 1.0))
		var a := Vector2(clampf(head, x0, x0 + w), py)
		var b := Vector2(clampf(head + streak * sign_x * -1.0, x0, x0 + w), py + sin(k * TAU + i) * 4.0)
		ci.draw_line(a, b, Color(0.9, 0.96, 0.97, 0.45 * sin(k * PI)), 2.0)


# Lo zampillo di una fontana (#288): una colonna bianca che si assottiglia, il pennacchio che si apre in cima
# e ricade a ventaglio in gocce, e la schiuma dove l'acqua torna nella vasca. Acceso è alto e pieno
func _draw_fountain_plume(ci: CanvasItem, light: Color, cx: float, base: float, w: float, h: float, t: float, strong: bool) -> void:
	# l'acqua dipinta (#288): il getto alto quando è acceso, lo zampillo (anche gonfio, con l'avviso) a riposo
	if strong and life.draw_frame(ci, "getto", int(t / 90.0), Vector2(cx, base + 3.0), h / 318.0, false, Color.WHITE, true):
		return
	if not strong and life.draw_frame(ci, "zampillo", int(t / 90.0), Vector2(cx, base + 3.0), h / 66.0, false, Color.WHITE, true):
		return
	var foam := Color(0.93, 0.97, 0.96, 0.85)
	var body := Color(0.78, 0.9, 0.9, 0.7)
	var half := w * (0.28 if strong else 0.16)
	# la colonna: due bordi che ondeggiano, stretti in cima
	var pts := PackedVector2Array()
	for i in 12:
		var k := i / 11.0
		pts.append(Vector2(cx + half * (1.0 - k * 0.7) + sin(t / 55.0 + k * 8.0) * 2.5, base - h * k))
	for i in range(11, -1, -1):
		var k := i / 11.0
		pts.append(Vector2(cx - half * (1.0 - k * 0.7) + sin(t / 55.0 + k * 8.0 + 1.7) * 2.5, base - h * k))
	ci.draw_colored_polygon(pts, body)
	ci.draw_line(Vector2(cx - half * 0.3, base), Vector2(cx - half * 0.1, base - h), foam, 2.0) # il filo di luce
	# il pennacchio: ricade a ventaglio, ogni goccia lungo la sua parabola
	var drops := 26 if strong else 14
	for i in drops:
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := fposmod(t / (520.0 if strong else 420.0) + i * 0.137, 1.0) # vita della goccia, da 0 a 1
		var spread := (0.35 + 0.65 * fposmod(i * 0.61, 1.0)) * (w * (1.1 if strong else 0.8))
		var px := cx + side * spread * k
		var py := base - h + h * 0.95 * k * k - 18.0 * k * (1.0 - k) * 4.0 * (0.4 if strong else 0.25)
		ci.draw_circle(Vector2(px, py), (3.2 if strong else 2.4) * (1.0 - 0.4 * k), Color(foam.r, foam.g, foam.b, 0.9 - 0.5 * k))
	# la cima spumosa e la schiuma alla base
	for i in 4:
		var a := t / 140.0 + i * 1.6
		ci.draw_circle(Vector2(cx + cos(a) * half * 0.9, base - h + sin(a * 1.3) * 5.0), 5.0 if strong else 3.5, foam)
	for i in 7:
		var a := t / 200.0 + i * 0.9
		ci.draw_circle(Vector2(cx + (i - 3) * w * 0.22 + sin(a) * 3.0, base - 4.0 + cos(a * 1.4) * 1.5), 4.5 if strong else 3.0, Color(0.95, 0.98, 0.97, 0.7))


# Lo spruzzo d'acqua che regge una piattaforma (#378): il foglio dipinto (il getto della fontana) stirato dalla vasca
# fino al fondo della piattaforma, largo sempre uguale; ogni spruzzo è sfasato per non pulsare insieme agli altri
func draw_mover_stem(ci: CanvasItem, light: Color, stem: Dictionary, cx: float, top: float, t: float, phase: float, plat_w := 0.0) -> void:
	var sh: Dictionary = life.sheet(str(stem.sheet))
	if sh.is_empty():
		return
	var fw: float = sh.fw
	var fh: float = sh.fh
	var frame := int(t / 90.0 + phase) % int(sh.frames)
	if stem.get("hub") is Dictionary: # un getto curvo dall'ugello alla piattaforma (#378, dallo schizzo di Riccardo)
		var hub := Vector2(float(stem.hub.x), float(stem.hub.y))
		var curve := StageMotion.jet_curve(hub, Vector2(cx, top), 14)
		_draw_curved_jet(ci, light, sh, frame, curve, float(stem.width))
		# il cuore del getto, pieno e bianco, e il nodo di schiuma dove spinge contro la tazza
		var white := Color(0.96, 0.99, 1.0, 1.0) * Color(light, 1.0)
		ci.draw_polyline(curve, Color(white, 0.55), float(stem.width) * 0.32, true)
		ci.draw_polyline(curve, Color(white, 0.85), float(stem.width) * 0.12, true)
		for i in 6:
			var a := t / 160.0 + i * TAU / 6.0 + phase
			ci.draw_circle(Vector2(cx, top + 2.0) + Vector2(cos(a) * 7.0, sin(a) * 3.0), 4.5, Color(white, 0.85))
		if stem.get("crown") != null: # dove batte sotto la tazza si apre a ombrello e ricade a rami
			_draw_jet_crown(ci, light, str(stem.crown), Vector2(cx, top), plat_w, t, phase)
		# le gocce che cadono dal bordo della tazza giù nella vasca, ognuna lungo la sua parabola
		var drop := Color(0.93, 0.97, 0.98, 1.0) * Color(light, 1.0)
		var fall := float(stem.baseY) - top
		for i in 12:
			var k := fposmod(t / 1100.0 + i * 0.283 + phase * 0.31, 1.0)
			var side := -1.0 if i % 2 == 0 else 1.0
			var edge := plat_w / 2.0 * (0.55 + 0.45 * fposmod(i * 0.61, 1.0))
			var p := Vector2(cx + side * (edge + 10.0 * k), top + 2.0 + fall * k * k)
			ci.draw_circle(p, 2.4 * (1.0 - 0.45 * k), Color(drop, 0.85 - 0.6 * k))
		return
	var r := StageMotion.stem_rect(cx, top, float(stem.baseY), float(stem.width))
	if r.size.y < 2.0:
		return
	ci.draw_texture_rect_region(sh.tex, r, Rect2(frame * fw, 0, fw, fh), light)


# Il getto curvo (#378): la colonna d'acqua dipinta (la parte sotto la corona del foglio "getto") piegata lungo la
# curva, a pezzi di quattro punti con le coordinate della texture, un po' più sottile in cima
func _draw_curved_jet(ci: CanvasItem, light: Color, sh: Dictionary, frame: int, pts: PackedVector2Array, width: float) -> void:
	var tex: Texture2D = sh.tex
	var tw := float(tex.get_width())
	var fw: float = sh.fw
	var u0 := (frame * fw + fw * 0.2) / tw # la colonna sta nel mezzo del fotogramma
	var u1 := (frame * fw + fw * 0.8) / tw
	var col := light
	var n := pts.size() - 1
	var sides: Array = []
	for i in pts.size():
		var d := (pts[mini(i + 1, n)] - pts[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-d.y, d.x)
		var half := width * (1.0 - 0.25 * i / float(n)) / 2.0
		sides.append([pts[i] - normal * half, pts[i] + normal * half, lerpf(1.0, 0.27, i / float(n))])
	for i in n:
		var a: Array = sides[i]
		var b: Array = sides[i + 1]
		ci.draw_primitive(PackedVector2Array([a[0], b[0], b[1], a[1]]), PackedColorArray([col, col, col, col]),
			PackedVector2Array([Vector2(u0, a[2]), Vector2(u0, b[2]), Vector2(u1, b[2]), Vector2(u1, a[2])]), tex)


# La corona sotto la tazza (#378): il foglio dipinto, con il punto dove arriva il getto in (fw/2, 28) del fotogramma,
# largo poco più della tazza
func _draw_jet_crown(ci: CanvasItem, light: Color, name: String, at: Vector2, plat_w: float, t: float, phase: float) -> void:
	var sh: Dictionary = life.sheet(name)
	if sh.is_empty():
		return
	var fw: float = sh.fw
	var fh: float = sh.fh
	var k := plat_w * 1.15 / (fw * float(sh.scale))
	var size := Vector2(fw, fh) * float(sh.scale) * k
	var anchor := Vector2(fw / 2.0, 28.0) * float(sh.scale) * k
	var frame := posmod(int(t / 110.0 + phase * 2.0), int(sh.frames))
	ci.draw_texture_rect_region(sh.tex, Rect2(at - anchor, size), Rect2(frame * fw, 0, fw, fh), light)


# Il getto unico che sale dal centro della vasca fino al mozzo della ruota (#378), dove si apre in tre raggi:
# lì l'acqua fa una corona di schiuma che pulsa appena
func draw_wheel_trunk(ci: CanvasItem, light: Color, stem: Dictionary, t: float) -> void:
	var sh: Dictionary = life.sheet(str(stem.sheet))
	if sh.is_empty():
		return
	var hub := Vector2(float(stem.hub.x), float(stem.hub.y))
	if float(stem.baseY) - hub.y < 10.0:
		return # i getti partono già dalla vasca: niente tronco
	var w: float = float(stem.width) * 1.5
	var r := StageMotion.stem_rect(hub.x, hub.y - 6.0, float(stem.baseY), w)
	var fw: float = sh.fw
	var frame := int(t / 90.0) % int(sh.frames)
	ci.draw_texture_rect_region(sh.tex, r, Rect2(frame * fw, 0, fw, sh.fh), light)


# La schiuma dove partono i getti (#378): all'ugello nella vasca un ribollire largo e basso, come nelle foto della
# fontana vera; su un mozzo in alto una corona più piccola
func draw_hub_foam(ci: CanvasItem, light: Color, stem: Dictionary, t: float) -> void:
	var hub := Vector2(float(stem.hub.x), float(stem.hub.y))
	var low := float(stem.baseY) - hub.y < 10.0
	var foam := Color(0.95, 0.98, 0.97, 1.0) * Color(light, 1.0)
	var n := 16 if low else 7
	for i in n:
		var a := t / 900.0 + i * TAU / n
		var rr := (26.0 if low else 7.0) * (0.6 + 0.4 * fposmod(i * 0.37, 1.0)) + 2.0 * sin(t / 180.0 + i)
		var p := hub + Vector2(cos(a) * rr, sin(a) * rr * (0.3 if low else 1.0) - (4.0 if low else 0.0))
		ci.draw_circle(p, (5.5 if low else 4.5) - 0.3 * (i % 3), Color(foam, 0.8))
	if low: # gli schizzi che saltano su attorno ai piedi dei getti
		for i in 10:
			var k := fposmod(t / 700.0 + i * 0.173, 1.0)
			var side := -1.0 if i % 2 == 0 else 1.0
			var p := hub + Vector2(side * (8.0 + 30.0 * k), -22.0 * sin(k * PI) - 3.0)
			ci.draw_circle(p, 2.6 * (1.0 - 0.5 * k), Color(foam, 0.9 - 0.6 * k))
	else:
		ci.draw_circle(hub, 7.0, Color(foam, 0.95))
