# Disegno delle trappole di Bologna (#433) che prima erano solo un rettangolo rosso: l'auto della piazza,
# l'ingorgo di via Rizzoli, i mattoni della Garisenda e la polvere della zuffa. Solo grafica, tutta da stageMs:
# la fisica è quella di hazardRect/hazardActive. Le macchine usano i fogli dipinti dello sfondo vivo (auto, furgone,
# bus di bologna.py) se l'arena li ha, altrimenti un disegno semplice col codice.
extends RefCounted

const JAM_KINDS := ["auto", "furgone", "auto", "bus", "auto", "furgone"] # la fila dell'ingorgo, ripetuta
const JAM_LENGTH := {"auto": 150.0, "furgone": 170.0, "bus": 300.0} # pixel di mondo: lunghi come l'auto della piazza
const JAM_GAP_PX := 14.0 # paraurti contro paraurti
const JAM_BUMP_PX := 4.0 # quanto sobbalzano quando l'ingorgo spinge
const BRICK := Color("9a4f38")
const MORTAR := Color("d9c4a0")
const INK := Color("2a2622")
const DUST := Color(0.62, 0.55, 0.45)
const AWNING_RED := Color("c0392b")
const AWNING_WHITE := Color("f3e6cc")
const FRUIT := [Color("e67e22"), Color("c0392b"), Color("27ae60"), Color("f1c40f")]
const AWNING_SQUASH_PX := 18.0 # quanto si abbassa sotto chi ci arriva
const AWNING_REACH_PX := 160.0 # sopra il tendone fin dove si sente il peso di chi è appena stato lanciato
const BUS_OVERHANG := 1.06 # il bus disegnato è un po' più lungo del suo tetto, che è la piattaforma
const BUS_ROOF := 0.96 # bus.png: il tetto è a tanto della sua altezza dal basso
const EMBER := Color("ff9a3c")
const UPDRAFT_BITS := 14 # tra braci, foglie e pezzi di carta che salgono nella corrente
const BRONZE := Color("a8792f")
const BELL_CABLE_PX := 190.0 # il cavo della campana, da una parte e dall'altra del perno: arriva alle due torri
# La sagoma della campana, col giogo in (0, 0) sotto il ceppo e la bocca in basso
const BELL_SHAPE := [Vector2(-10, 0), Vector2(10, 0), Vector2(16, 8), Vector2(18, 30), Vector2(30, 46), Vector2(30, 52), Vector2(-30, 52), Vector2(-30, 46), Vector2(-18, 30), Vector2(-16, 8)]


# L'auto che attraversa la piazza (travel): il modello cambia a ogni giro, girata nel verso in cui va
static func draw_car(ci: CanvasItem, life: RefCounted, r: Rect2, dir: int, lap: int, mod: Color) -> void:
	_car(ci, life, "auto", lap, Vector2(r.get_center().x, r.end.y), r.size.x, dir, mod)


# L'ingorgo: una fila di macchine ferme sulla corsia. Quando spinge (on) sobbalzano, avanzano di poco e suonano
static func draw_jam(ci: CanvasItem, life: RefCounted, h: Dictionary, r: Rect2, on: bool, t: float, mod: Color) -> void:
	var dir := 1 if r.get_center().x < 1100.0 else -1 # metà a sinistra verso destra, l'altra verso sinistra
	var x := r.position.x + 10.0
	var i := int(r.position.x / 100.0) # la fila non è uguale nelle due metà
	var dim := mod if on else mod.darkened(0.15)
	while x < r.end.x - 60.0:
		var kind: String = JAM_KINDS[posmod(i, JAM_KINDS.size())]
		var length: float = minf(JAM_LENGTH[kind], r.end.x - 10.0 - x)
		if length < 120.0:
			kind = "auto"
		var nudge := 0.0
		var bump := 0.0
		if on:
			nudge = dir * 6.0 * (0.5 + 0.5 * sin(t / 180.0 + i * 1.3))
			bump = -absf(sin(t / 90.0 + i * 2.1)) * JAM_BUMP_PX
		_car(ci, life, kind, i, Vector2(x + length / 2.0 + nudge, r.end.y + bump), length, dir, dim)
		if on and posmod(i, 3) == 0 and fposmod(t / 250.0 + i, 2.0) < 1.0:
			_honk(ci, Vector2(x + length / 2.0, r.end.y - _car_height(kind) - 14.0))
		x += length + JAM_GAP_PX
		i += 1


# Un mattone che cade dalla Garisenda: un blocco di mattoni che gira. Nell'avviso, l'ombra dove cadrà
static func draw_brick(ci: CanvasItem, h: Dictionary, r: Rect2, phase: String, k: float, t: float, mod: Color) -> void:
	if phase == "warn":
		var path: Array = h.travel.path
		var land := Vector2(float(path[path.size() - 1].x) + h.width / 2.0, float(path[path.size() - 1].y) + h.height)
		var w: float = h.width * (0.4 + 0.6 * k)
		_ellipse(ci, land, w / 2.0, w / 7.0, Color(0, 0, 0, 0.15 + 0.25 * k))
		for g in 3: # calcinacci che cadono prima del blocco
			var gy: float = r.position.y + fposmod(t / 2.0 + g * 37.0, 120.0)
			ci.draw_rect(Rect2(r.get_center().x - 12.0 + g * 11.0, gy, 4, 4), MORTAR * mod)
		return
	if phase != "cross":
		return
	var c := r.get_center()
	var a := t / 260.0 + float(h.travel.path[0].x) # gira mentre cade, ognuno da un angolo suo
	var xf := Transform2D(a, c)
	var half := r.size * 0.5
	var body := PackedVector2Array([xf * Vector2(-half.x, -half.y), xf * Vector2(half.x, -half.y), xf * Vector2(half.x, half.y), xf * Vector2(-half.x, half.y)])
	ci.draw_colored_polygon(body, BRICK * mod)
	# tre corsi di mattoni sfalsati
	for row in 3:
		var y := -half.y + (row + 1) * r.size.y / 3.0
		if row < 2:
			ci.draw_line(xf * Vector2(-half.x, y), xf * Vector2(half.x, y), MORTAR * mod, 2.0)
		var y0 := -half.y + row * r.size.y / 3.0
		var off := 0.0 if row % 2 == 0 else r.size.x / 4.0
		var bx := -half.x + off + r.size.x / 2.0
		while bx < half.x:
			ci.draw_line(xf * Vector2(bx, y0), xf * Vector2(bx, y0 + r.size.y / 3.0), MORTAR * mod, 2.0)
			bx += r.size.x / 2.0
	body.append(body[0])
	ci.draw_polyline(body, INK, 2.0)


# La polvere che sale: una nube color sabbia con il bordo che ribolle. Bassa e ferma non fa male e non si vede;
# nell'avviso compare una foschia sul fondo
static func draw_dust(ci: CanvasItem, r: Rect2, phase: String, k: float, t: float, mod: Color) -> void:
	if phase == "calm":
		return
	var alpha := 0.55
	var top := r.position.y
	if phase == "warn":
		alpha = 0.35 * k
		top = r.end.y - r.size.y * 0.3
	var col := Color(DUST.r * mod.r, DUST.g * mod.g, DUST.b * mod.b, alpha)
	ci.draw_rect(Rect2(r.position.x, top + 20.0, r.size.x, r.end.y - top - 20.0), col)
	var x := r.position.x
	var n := 0
	while x < r.end.x: # il bordo: sbuffi che salgono e scendono piano
		var rad := 34.0 + 12.0 * sin(n * 1.7)
		var y := top + 24.0 + 10.0 * sin(t / 400.0 + n * 0.9)
		ci.draw_circle(Vector2(x + fposmod(t / 60.0, 50.0), y), rad, col)
		x += 50.0
		n += 1
	# granelli più chiari che vorticano dentro
	for g in int(r.size.x / 90.0):
		var gx: float = r.position.x + fposmod(g * 97.0 + t / 25.0, r.size.x)
		var gy: float = top + 30.0 + fposmod(g * 53.0 - t / 40.0, maxf(1.0, r.end.y - top - 30.0))
		ci.draw_circle(Vector2(gx, gy), 3.0, Color(0.85, 0.78, 0.64, alpha * 0.8))


# La bancarella col tendone a strisce che fa da molla (jet "tenda"): il banco sul selciato, i pali e il tendone, che si
# schiaccia sotto chi ci arriva (squash da 0 a 1) e rimbalza. La molla vera è il getto della fisica, sempre acceso
static func draw_awning(ci: CanvasItem, j: Dictionary, squash: float, t: float, mod: Color) -> void:
	var x0 := float(j.x)
	var w := float(j.width)
	var ground := float(j.y)
	var top := ground - float(j.height) + AWNING_SQUASH_PX * squash # il tendone è in cima alla fascia che lancia
	var paint := func(c: Color) -> Color: return Color(c.r * mod.r, c.g * mod.g, c.b * mod.b, c.a)
	# il banco con la frutta e i pali
	ci.draw_rect(Rect2(x0 + 6.0, ground - 34.0, w - 12.0, 34.0), paint.call(Color("6b4a2e")))
	for k in 4:
		ci.draw_circle(Vector2(x0 + 16.0 + k * (w - 32.0) / 3.0, ground - 38.0), 7.0, paint.call(FRUIT[k % FRUIT.size()]))
	for side in [x0 + 4.0, x0 + w - 4.0]:
		ci.draw_line(Vector2(side, ground - 34.0), Vector2(side, top + 6.0), paint.call(INK), 3.0)
	# il tendone: un trapezio a strisce, più largo del banco, con la frangia a onde
	var spread := 14.0 + 6.0 * squash
	var stripes := 6
	for k in stripes:
		var a := float(k) / stripes
		var b := float(k + 1) / stripes
		var poly := PackedVector2Array([
			Vector2(x0 + w * a, top - 12.0 + 6.0 * squash), Vector2(x0 + w * b, top - 12.0 + 6.0 * squash),
			Vector2(x0 - spread + (w + 2.0 * spread) * b, top + 10.0), Vector2(x0 - spread + (w + 2.0 * spread) * a, top + 10.0)])
		ci.draw_colored_polygon(poly, paint.call(AWNING_RED if k % 2 == 0 else AWNING_WHITE))
	for k in stripes:
		var cx := x0 - spread + (w + 2.0 * spread) * (k + 0.5) / stripes
		ci.draw_circle(Vector2(cx, top + 10.0), (w + 2.0 * spread) / stripes / 2.0, paint.call(AWNING_RED if k % 2 == 0 else AWNING_WHITE))
	ci.draw_line(Vector2(x0 - spread, top + 10.0), Vector2(x0 + w + spread, top + 10.0), paint.call(INK), 2.0)
	# a riposo il tendone ondeggia appena col vento della piazza
	if squash <= 0.0:
		ci.draw_line(Vector2(x0, top - 12.0 + sin(t / 400.0)), Vector2(x0 + w, top - 12.0 - sin(t / 400.0)), paint.call(INK), 2.0)


# Quanto è schiacciato il tendone: 1 con qualcuno sopra, poi torna su mentre chi è stato lanciato sale
static func awning_squash(j: Dictionary, feet: Array) -> float:
	var best := 0.0
	for p: Vector2 in feet:
		if p.x < float(j.x) - 20.0 or p.x > float(j.x) + float(j.width) + 20.0:
			continue
		var above := float(j.y) - p.y
		if above >= -4.0 and above < AWNING_REACH_PX:
			best = maxf(best, 1.0 - clampf(above / AWNING_REACH_PX, 0.0, 1.0))
	return best


# Il bus su cui si sale (#433): una piattaforma mobile col tetto alla superficie pos.y. Il foglio dipinto del bus ha il
# tetto a BUS_ROOF della sua altezza dal basso; alla fermata accende le quattro frecce
static func draw_bus(ci: CanvasItem, life: RefCounted, pos: Vector2, w: float, dir: int, stopped: bool, t: float, mod: Color) -> void:
	var length := w * BUS_OVERHANG
	var sh: Dictionary = life.sheet("bus") if life != null else {}
	var height := _car_height("bus") + 8.0 if sh.is_empty() else length * float(sh.fh) / float(sh.fw)
	var feet := Vector2(pos.x + w / 2.0, pos.y + height * (1.0 if sh.is_empty() else BUS_ROOF)) # senza foglio, il tetto del disegno col codice
	_car(ci, life, "bus", 0, feet, length, dir, Color(mod.r, mod.g, mod.b, 1.0))
	# Le quattro frecce alla fermata: si capisce che è il momento di salire
	if stopped and fposmod(t / 350.0, 2.0) < 1.0:
		for side in [-1, 1]:
			ci.draw_circle(Vector2(feet.x + side * length * 0.48, feet.y - height * 0.3), 5.0, Color("ffb347"))
	# Il tetto dove si sta in piedi: una riga chiara, si capisce che ci si sale
	ci.draw_rect(Rect2(pos.x, pos.y, w, 3.0), Color("f0d9b5") * Color(mod.r, mod.g, mod.b, 0.9))


# La campana appesa al cavo tra le torri (mover "campana" con swing): il cavo teso da una torre all'altra, la carrucola,
# le due funi fino al ceppo di legno su cui si sta (la superficie della fisica) e sotto la campana di bronzo, che
# dondola un po' più del ceppo e col batacchio in ritardo. angle: l'angolo dell'altalena (StageMotion.swing_angle)
static func draw_bell(ci: CanvasItem, m: Dictionary, pos: Vector2, angle: float, t: float, mod: Color) -> void:
	var paint := func(c: Color) -> Color: return Color(c.r * mod.r, c.g * mod.g, c.b * mod.b, c.a)
	var pivot := Vector2(float(m.swing.pivot.x), float(m.swing.pivot.y))
	var w := float(m.width)
	# il cavo teso tra le torri, che cede appena sotto il peso
	ci.draw_polyline(PackedVector2Array([pivot + Vector2(-BELL_CABLE_PX, -12.0), pivot, pivot + Vector2(BELL_CABLE_PX, -16.0)]), paint.call(INK), 3.0)
	ci.draw_circle(pivot, 9.0, paint.call(Color("5a4a3a")))
	ci.draw_circle(pivot, 4.0, paint.call(BRONZE.lightened(0.2)))
	# le funi fino agli spigoli del ceppo
	for x in [pos.x + 10.0, pos.x + w - 10.0]:
		ci.draw_line(pivot, Vector2(x, pos.y), paint.call(Color("b49a6a")), 3.0)
	# la campana sotto il ceppo, appesa al giogo: oscilla un po' più del ceppo
	var hang := Vector2(pos.x + w / 2.0, pos.y + 12.0)
	var tilt := angle * 0.5
	var xf := Transform2D(tilt, hang)
	var body := PackedVector2Array()
	for p: Vector2 in BELL_SHAPE:
		body.append(xf * p)
	ci.draw_colored_polygon(body, paint.call(BRONZE))
	body.append(body[0])
	ci.draw_polyline(body, paint.call(INK), 2.0)
	ci.draw_line(xf * Vector2(-22.0, 34.0), xf * Vector2(22.0, 34.0), paint.call(BRONZE.lightened(0.35)), 3.0)
	ci.draw_circle(xf * Vector2(sin(angle * 2.0 + t / 300.0) * 8.0, 52.0), 6.0, paint.call(INK)) # il batacchio
	# il ceppo di legno su cui si sta
	ci.draw_rect(Rect2(pos.x, pos.y, w, 12.0), paint.call(Color("8a5a32")))
	ci.draw_rect(Rect2(pos.x, pos.y, w, 3.0), paint.call(Color("f0d9b5")))
	ci.draw_rect(Rect2(pos.x, pos.y, w, 12.0), paint.call(INK), false, 2.0)


static func _car(ci: CanvasItem, life: RefCounted, kind: String, model: int, feet: Vector2, length: float, dir: int, mod: Color) -> void:
	var sh: Dictionary = life.sheet(kind) if life != null else {}
	if not sh.is_empty():
		var k := length / (float(sh.fw) * float(sh.scale))
		life.draw_frame(ci, kind, posmod(model, int(sh.frames)), feet, k, dir < 0, Color(mod.r, mod.g, mod.b, 1.0), true)
		return
	# senza foglio dipinto: carrozzeria grigia, abitacolo, ruote
	var h := _car_height(kind)
	var o := Vector2(feet.x - length / 2.0, feet.y)
	var body := Color("6d6a64") * mod
	ci.draw_rect(Rect2(o.x, o.y - 8.0 - h * 0.55, length, h * 0.55), body)
	ci.draw_rect(Rect2(o.x + length * (0.2 if dir > 0 else 0.3), o.y - 8.0 - h, length * 0.5, h * 0.45), body)
	ci.draw_rect(Rect2(o.x, o.y - 8.0 - h * 0.55, length, h * 0.55), INK, false, 2.0)
	for wx in [o.x + length * 0.18, o.x + length * 0.82]:
		ci.draw_circle(Vector2(wx, o.y - 8.0), 8.0, INK)


static func _car_height(kind: String) -> float:
	return 70.0 if kind == "bus" else (56.0 if kind == "furgone" else 44.0)


# Il clacson: tre trattini a ventaglio sopra la macchina
static func _honk(ci: CanvasItem, p: Vector2) -> void:
	for a in [-0.5, 0.0, 0.5]:
		var d := Vector2(sin(a), -cos(a))
		ci.draw_line(p + d * 6.0, p + d * 16.0, Color("f0d9b5"), 3.0)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


# La corrente calda delle macerie (jet "corrente"): sotto le braci della torre caduta che fumano, sopra l'aria che trema
# (linee chiare ondulate) e su per la colonna braci, foglie e pezzi di carta che salgono, così si vede dove porta.
# La spinta vera è il getto della fisica, sempre acceso
static func draw_updraft(ci: CanvasItem, j: Dictionary, t: float, mod: Color) -> void:
	var x0 := float(j.x)
	var w := float(j.width)
	var base := float(j.y)
	var h := float(j.height)
	var paint := func(c: Color) -> Color: return Color(c.r * mod.r, c.g * mod.g, c.b * mod.b, c.a)
	# il bagliore e le braci in fondo
	var glow := 0.5 + 0.2 * sin(t / 180.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 10.0, base + 14.0), Vector2(x0 + w + 10.0, base + 14.0),
		Vector2(x0 + w, base - 60.0), Vector2(x0, base - 60.0)]), Color(EMBER.r, EMBER.g * 0.8, EMBER.b, 0.16 * glow))
	for k in 5:
		ci.draw_circle(Vector2(x0 + 10.0 + k * (w - 20.0) / 4.0, base + 8.0), 9.0 - (k % 2) * 3.0, paint.call(BRICK.darkened(0.3)))
		ci.draw_circle(Vector2(x0 + 10.0 + k * (w - 20.0) / 4.0, base + 4.0), 3.0, Color(EMBER.r, EMBER.g, EMBER.b, glow))
	# l'aria che trema: tre linee ondulate che salgono, più chiare in basso
	for k in 3:
		var pts := PackedVector2Array()
		var lx := x0 + w * (k + 0.5) / 3.0
		for s in 13:
			var y := base - h * s / 12.0
			pts.append(Vector2(lx + 7.0 * sin(y / 38.0 + t / 160.0 + k * 2.1), y))
		ci.draw_polyline(pts, Color(1.0, 0.95, 0.85, 0.16), 2.0)
	# braci, foglie e carta: salgono alla velocità della corrente e ricominciano dal fondo
	var speed := float(j.speed) / 1000.0
	for k in UPDRAFT_BITS:
		var rise := fposmod(t * speed * (0.7 + 0.05 * (k % 6)) + k * 97.0, h)
		var p := Vector2(x0 + fposmod(k * 37.0, w) + 10.0 * sin(t / 230.0 + k), base - rise)
		var fade := 1.0 - rise / h
		match k % 3:
			0:
				ci.draw_circle(p, 2.5, Color(EMBER.r, EMBER.g, EMBER.b, 0.9 * fade))
			1:
				ci.draw_set_transform(p, t / 300.0 + k, Vector2.ONE)
				ci.draw_rect(Rect2(-5.0, -3.5, 10.0, 7.0), paint.call(Color(0.95, 0.92, 0.84, 0.85 * fade)))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				ci.draw_set_transform(p, sin(t / 200.0 + k), Vector2.ONE)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(0, -3), Vector2(6, 0), Vector2(0, 3)]),
					paint.call(Color(0.78, 0.55, 0.2, 0.85 * fade)))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
