# Sfondo vivo delle arene (#260): stormi, piccioni, passanti, veicoli e tramonto. Solo grafica: tutto si calcola
# dal tempo dell'arena (stageMs) e dalle posizioni dei lottatori che il client ha già, niente passa in rete.
# world_view.gd lo chiama dentro _draw: gli elementi con parallasse p si disegnano dopo gli strati più lontani di p.
extends RefCounted

const INK := Color("1e1a17")
# Colori spenti, lontani dai colori dei giocatori (style guide, sezione 7)
const CLOTHES := [Color("5b5650"), Color("6a5f52"), Color("4f5560"), Color("6b6058"), Color("585a50"), Color("625a62")]
const UMBRELLAS := [Color("4c4f5a"), Color("6a4f4a"), Color("4f5f58"), Color("5e5a4a"), Color("3f4048")]

var life: Dictionary = {}
var width := 1280.0 # larghezza dell'arena
var center := Vector2(640, 360) # centro dell'arena, dove sono centrati gli strati
var match_start := NAN # stageMs di inizio della partita, per il tramonto
var view := Rect2() # la parte di mondo inquadrata in questo frame (world_view.gd): quello che sta fuori non si disegna
var _sheets := {} # nome -> {tex, frames, fw, fh, scale}: i fogli dipinti dello sfondo vivo (#288)
var _pigeons: Array = [] # per ogni piccione: {x, y, away (ms dell'orologio del client in cui è scappato, -1 se posato)}


func setup(spec: Dictionary, stage_width: float, world_height: float) -> void:
	var art: Dictionary = spec.get("art", {}) if spec.get("art") is Dictionary else {}
	life = art.get("life", {}) if art.get("life") is Dictionary else {}
	width = stage_width
	center = Vector2(stage_width / 2.0, world_height / 2.0)
	match_start = NAN
	_pigeons = []
	for p in life.get("pigeons", []):
		_pigeons.append({"x": float(p.x), "y": float(p.y), "away": -1.0})
	# Fogli di fotogrammi dipinti (#288): nuvole e uccelli al posto delle forme semplici
	_sheets = {}
	var dir: String = str(art.get("dir", spec.get("id", "")))
	var sheets: Dictionary = life.get("sheets", {}) if life.get("sheets") is Dictionary else {}
	for name: String in sheets:
		var sh: Dictionary = sheets[name]
		var path := "res://data/assets/stages/%s/%s" % [dir, sh.file]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			var frames := maxi(1, int(sh.frames))
			_sheets[name] = {"tex": tex, "frames": frames, "fw": tex.get_width() / frames, "fh": tex.get_height(), "scale": float(sh.get("scale", 0.5))}


# Un fotogramma di un foglio dipinto, centrato in pos (o con i piedi in pos se feet), grande k volte la sua misura
# di mondo, specchiato se flip. Restituisce false se il foglio non c'è (allora si disegna la forma semplice)
func draw_frame(ci: CanvasItem, name: String, frame: int, pos: Vector2, k: float, flip := false, mod := Color.WHITE, feet := false) -> bool:
	var sh: Variant = _sheets.get(name)
	if sh == null:
		return false
	var fw: float = sh.fw
	var fh: float = sh.fh
	var size := Vector2(fw, fh) * float(sh.scale) * k
	var dest := Rect2(pos.x - size.x / 2.0, pos.y - (size.y if feet else size.y / 2.0), size.x, size.y)
	if flip:
		dest.size.x = -size.x
	ci.draw_texture_rect_region(sh.tex, dest, Rect2(fw * posmod(frame, int(sh.frames)), 0, fw, fh), mod)
	return true


func has_sheet(name: String) -> bool:
	return _sheets.has(name)


func is_empty() -> bool:
	return life.is_empty()


# Dove appare un punto che sta su uno strato con parallasse p: come gli strati, trascinato verso la vista
func offset(p: float, view_center: Vector2) -> Vector2:
	return (view_center - center) * (1.0 - p)


# Gli elementi con parallasse in [from, to): aerei, stormi, uccelli vicini, traffico, veicoli, passanti e bar,
# dal più lontano al più vicino quando stanno nella stessa fascia
func draw_band(ci: CanvasItem, from: float, to: float, t: float, view_center: Vector2, rain: float, amb := Color.WHITE) -> void:
	var dark := darkness(day_phase(t)) if life.get("daycycle") is Dictionary else 0.0
	var planes: Variant = life.get("planes")
	if planes is Dictionary and PLANE_PARALLAX >= from and PLANE_PARALLAX < to:
		_draw_plane(ci, planes, t, offset(PLANE_PARALLAX, view_center), dark)
	var birds: Variant = life.get("birds")
	if _in_band(birds, from, to):
		_draw_birds(ci, birds, t, offset(float(birds.parallax), view_center), amb)
	var flyers: Variant = life.get("flyers")
	if _in_band(flyers, from, to):
		_draw_flyers(ci, flyers, t, offset(float(flyers.parallax), view_center), amb, dark)
	var traffic: Variant = life.get("traffic")
	if _in_band(traffic, from, to):
		_draw_traffic(ci, traffic, t, offset(float(traffic.parallax), view_center), amb, dark)
	var veh: Variant = life.get("vehicles")
	if _in_band(veh, from, to):
		_draw_vehicle(ci, veh, t, offset(float(veh.parallax), view_center), amb)
	var walk: Variant = life.get("walkers")
	if _in_band(walk, from, to):
		_draw_walkers(ci, walk, t, offset(float(walk.parallax), view_center), rain, amb)
	var bar: Variant = life.get("bar")
	if _in_band(bar, from, to):
		_draw_bar(ci, bar, t, offset(float(bar.parallax), view_center), amb, dark)


static func _in_band(e: Variant, from: float, to: float) -> bool:
	return e is Dictionary and float(e.parallax) >= from and float(e.parallax) < to


# Un elemento largo w pixel a partire da x (già spostato dalla parallasse) si vede? Senza vista sì
func _seen(x: float, w := 0.0) -> bool:
	return view.size.x <= 0.0 or (x + w > view.position.x - 60.0 and x < view.end.x + 60.0)


# --- stormi: ogni everyMs uno stormo a V attraversa il cielo in 10 s, un giro da sinistra e uno da destra ---
static func bird_flock(everyMs: float, t: float) -> Dictionary:
	var cycle := floorf(t / everyMs)
	var k := (t - cycle * everyMs) / 10000.0
	return {"k": k, "dir": 1 if int(cycle) % 2 == 0 else -1, "on": k < 1.0}


func _draw_birds(ci: CanvasItem, b: Dictionary, t: float, off: Vector2, amb: Color) -> void:
	if amb.v < 0.5:
		return # di notte gli uccelli dormono
	# tre stormi lontani con giri, quote e grandezze diverse (#267): il primo è quello dell'arena, gli altri più piccoli
	for j in 3:
		var every := float(b.everyMs) * (1.0 + 0.43 * j)
		var f := bird_flock(every, t + j * 5300.0)
		if not f.on:
			continue
		var size := 1.0 - 0.28 * j
		var span := width + 900.0
		var k: float = f.k
		var lead_x: float = -450.0 + span * k if int(f.dir) > 0 else width + 450.0 - span * k
		var n := 7 - j * 2
		for i in n:
			var row := (i + 1) / 2
			var side := 1 if i % 2 == 0 else -1
			var x: float = lead_x - float(f.dir) * row * 26.0 * size
			var y := float(b.y) + j * 70.0 + row * 12.0 * side * size + sin(t / 400.0 + i + j) * 4.0
			var flap := sin(t / 90.0 + i * 1.3 + j) * 5.0 * size
			var p := Vector2(x, y) + off * (1.0 - 0.3 * j)
			if draw_frame(ci, "gabbiano", int(t / 75.0 + i * 1.7 + j * 3.0), p, 0.36 * size, int(f.dir) < 0, Color(amb.r, amb.g, amb.b, 1.0 - 0.2 * j)):
				continue
			var col := Color(0.18, 0.2, 0.26, 0.85 - 0.2 * j) * Color(amb.r, amb.g, amb.b, 1.0)
			ci.draw_polyline(PackedVector2Array([p + Vector2(-8, -flap) * size, p, p + Vector2(8, -flap) * size]), col, 2.0 * size + 0.5)


# --- veicolo: ogni everyMs passa in 12 s, alternando il verso ---
func _draw_vehicle(ci: CanvasItem, v: Dictionary, t: float, off: Vector2, amb := Color.WHITE) -> void:
	var every := float(v.everyMs)
	var cycle := floorf(t / every)
	var k := (t - cycle * every) / 12000.0
	if k >= 1.0:
		return
	var dir := 1 if int(cycle) % 2 == 0 else -1
	var length := 300.0 if v.kind == "tram" else 150.0
	var span := width + 1400.0 + length
	var x: float = -700.0 - length + span * k if dir > 0 else width + 700.0 - span * k
	var base := float(v.y)
	if not _seen(off.x + x, length):
		return
	var body := (Color("7a6a5c") if v.kind == "tram" else Color("6c7064")) * amb
	var h := 52.0
	var o := off + Vector2(x, base - h - 10)
	ci.draw_rect(Rect2(o, Vector2(length, h)), body)
	ci.draw_rect(Rect2(o + Vector2(0, h - 12), Vector2(length, 12)), body.darkened(0.25))
	ci.draw_rect(Rect2(o, Vector2(length, h)), INK, false, 2.0)
	var n := int(length / 34)
	for i in n:  # finestrini, con qualche passeggero in sagoma
		var wx := o.x + 10 + i * (length - 20) / n
		ci.draw_rect(Rect2(wx, o.y + 8, 22, 18), Color("3c3d40"))
		if (i * 7 + int(cycle)) % 3 != 0:
			ci.draw_circle(Vector2(wx + 11, o.y + 20), 4.0, Color("5a5550"))
	for wx in [o.x + 30, o.x + length - 30]:
		ci.draw_circle(Vector2(wx, o.y + h + 4), 7.0, INK)
	if v.kind == "tram":  # pantografo e filo
		ci.draw_polyline(PackedVector2Array([o + Vector2(length / 2 - 20, 0), o + Vector2(length / 2, -18), o + Vector2(length / 2 + 20, 0)]), INK, 2.0)


# --- passanti: ognuno con passo, verso e partenza suoi, sempre uguali per la stessa arena ---
# Tipi di passante (#278): chi passeggia, chi porta il cane, chi corre, il passeggino, l'anziano col bastone,
# lo studente appena laureato con la corona d'alloro, chi torna dal mercato
const WALKER_KINDS := ["solo", "cane", "corsa", "passeggino", "bastone", "solo", "laurea", "borsa"]
const WALKER_PACE := {"corsa": 2.6, "bastone": 0.55, "passeggino": 0.8}
const SKIN := [Color("b08a72"), Color("8f6a52"), Color("c49c80"), Color("6e5040"), Color("a88068")]
const HAIR := [Color("2e2722"), Color("5a4434"), Color("8a8078"), Color("3a3430"), Color("6e5a40")]


static func walker_kind(i: int) -> String:
	return WALKER_KINDS[(i * 5 + 3) % WALKER_KINDS.size()]


static func walker_x(i: int, t: float, span: float) -> float:
	var speed := (26.0 + float((i * 37) % 30)) * float(WALKER_PACE.get(walker_kind(i), 1.0)) # pixel/s
	var dir := 1.0 if i % 2 == 0 else -1.0
	return fposmod(float(i) * 397.0 + dir * speed * t / 1000.0, span)


func _draw_walkers(ci: CanvasItem, w: Dictionary, t: float, off: Vector2, rain: float, amb := Color.WHITE) -> void:
	var span := width + 600.0
	var base := float(w.y)
	var wet: bool = w.get("umbrellas", false) and rain > 0.25
	for i in int(w.count):
		var kind := walker_kind(i)
		var x := walker_x(i, t, span) - 300.0
		if not _seen(off.x + x - 40.0, 80.0):
			continue
		var dir := 1.0 if i % 2 == 0 else -1.0
		var running := kind == "corsa"
		var cadence := 180.0 / (2.2 if running else float(WALKER_PACE.get(kind, 1.0)))
		var step := sin(t / cadence * (1.0 + 0.1 * (i % 3)) + i)
		var p := off + Vector2(x, base)
		var hgt := 34.0 + float(i % 3) * 3.0
		var clothes: Color = CLOTHES[i % CLOTHES.size()] * amb
		var skin: Color = SKIN[i % SKIN.size()] * amb
		var hair: Color = HAIR[(i * 3) % HAIR.size()] * amb
		var lean := dir * (4.0 if running else (3.0 if kind == "bastone" else 0.0))
		var hip := p + Vector2(0, -hgt * 0.44)
		var neck := hip + Vector2(lean, -hgt * 0.4)
		var head := neck + Vector2(lean * 0.3, -6.0)
		var swing := 7.0 if running else 4.0
		# gambe con le scarpe
		for leg in [-1.0, 1.0]:
			var foot := p + Vector2(leg * step * swing, 0)
			ci.draw_line(hip, foot, Color("3a3836") * amb, 3.0)
			ci.draw_line(foot, foot + Vector2(dir * 3.0, 0), INK, 2.0)
		# busto e testa con i capelli
		ci.draw_line(hip, neck, clothes, 9.0)
		ci.draw_circle(head, 5.0, skin)
		ci.draw_arc(head + Vector2(-dir * 0.5, -0.5), 5.0, PI * 0.9, PI * 2.1, 8, hair, 3.0)
		var hand := hip + Vector2(-step * swing * 0.8, -2.0) # il braccio che dondola
		var umbrella := wet and i % 4 != 3 and not running
		if umbrella:
			hand = neck + Vector2(dir * 6.0, 6.0)
			var top := head + Vector2(dir * 3.0, -12.0)
			ci.draw_line(hand, top, INK, 1.5)
			var arc := PackedVector2Array()
			for a in 9:
				var ang := PI + PI * a / 8.0
				arc.append(top + Vector2(cos(ang) * 16, sin(ang) * 9 + 4))
			ci.draw_colored_polygon(arc, UMBRELLAS[i % UMBRELLAS.size()] * amb)
		elif wet:
			# senza ombrello: il giornale sopra la testa
			ci.draw_line(neck, head + Vector2(-6, -7), clothes.darkened(0.2), 2.5)
			ci.draw_line(neck, head + Vector2(6, -7), clothes.darkened(0.2), 2.5)
			ci.draw_rect(Rect2(head + Vector2(-9, -11), Vector2(18, 4)), Color("cfc8b8") * amb)
			continue
		match kind:
			"cane":
				var dog := p + Vector2(dir * 26.0, 0)
				var trot := sin(t / 90.0 + i) * 3.0
				ci.draw_line(neck + Vector2(dir * 2, 10), dog + Vector2(dir * 6, -10), INK, 1.0) # guinzaglio
				ci.draw_line(dog + Vector2(-8, -8), dog + Vector2(6, -8), Color("6a5444") * amb, 6.0)
				ci.draw_circle(dog + Vector2(dir * 9, -11), 3.5, Color("6a5444") * amb)
				for lx in [-6.0, 4.0]:
					ci.draw_line(dog + Vector2(lx, -7), dog + Vector2(lx + trot, 0), Color("4a3c32") * amb, 2.0)
			"passeggino":
				var pram := p + Vector2(dir * 20.0, 0)
				ci.draw_line(neck + Vector2(0, 8), pram + Vector2(-dir * 8, -20), INK, 2.0)
				ci.draw_rect(Rect2(pram + Vector2(-9, -20), Vector2(18, 11)), Color("5f625e") * amb)
				ci.draw_arc(pram + Vector2(dir * 3, -20), 8.0, PI, TAU, 8, Color("4c4f4c") * amb, 3.0)
				for wx in [-6.0, 6.0]:
					ci.draw_circle(pram + Vector2(wx, -3), 3.0, INK)
			"bastone":
				var tip := p + Vector2(dir * 10.0, 0)
				ci.draw_line(hip + Vector2(dir * 5, -4), tip, Color("5a4030") * amb, 2.0)
				ci.draw_line(neck + Vector2(0, 6), hip + Vector2(dir * 5, -4), clothes, 2.5)
			"laurea":
				# la corona d'alloro di chi si è appena laureato, verde spento
				for k in 7:
					var a := PI + PI * k / 6.0
					ci.draw_circle(head + Vector2(cos(a) * 5.5, sin(a) * 3.0 - 1.5), 1.8, Color("6f8250") * amb)
				ci.draw_line(neck + Vector2(0, 6), hand, clothes, 2.5)
			"borsa":
				ci.draw_line(neck + Vector2(0, 6), hand, clothes, 2.5)
				ci.draw_rect(Rect2(hand + Vector2(-3, 0), Vector2(7, 8)), Color("a49a86") * amb)
			"corsa":
				ci.draw_line(neck + Vector2(0, 5), neck + Vector2(dir * 6 - step * 5, 12), clothes, 2.5)
			_:
				if not umbrella:
					ci.draw_line(neck + Vector2(0, 6), hand, clothes, 2.5)


# --- traffico (#278): ogni everyMs parte un veicolo; tipo, verso e colore vengono dal numero del giro ---
const TRAFFIC := {
	"auto": {"length": 64.0, "speed": 230.0},
	"vespa": {"length": 30.0, "speed": 250.0},
	"furgone": {"length": 82.0, "speed": 190.0},
	"bici": {"length": 30.0, "speed": 95.0},
	"bus": {"length": 170.0, "speed": 140.0},
}
# Carrozzerie spente: grigi, sabbia, verde salvia, blu polvere (niente rosso, blu, verde o giallo dei giocatori)
const CAR_COLORS := [Color("6d6a64"), Color("8a8478"), Color("5d6268"), Color("9a958a"), Color("4d4f52"), Color("6e6258"), Color("6a7468"), Color("5a6474")]
const TRAFFIC_MARGIN := 400.0 # pixel fuori dall'arena da cui partono e dove spariscono


static func _mix(n: int) -> int:
	return posmod(n * 1103515245 + 12345, 2147483648) >> 8


static func traffic_slot(n: int, kinds: Array) -> Dictionary:
	var h := _mix(n)
	return {"kind": kinds[h % kinds.size()], "dir": 1 if (h >> 5) % 2 == 0 else -1, "color": (h >> 9) % CAR_COLORS.size(), "n": n}


# I veicoli in strada al tempo t: [{kind, dir, color, n, x}], x è il lato sinistro del veicolo
static func traffic_at(tr: Dictionary, t: float, width_: float) -> Array:
	var every := float(tr.everyMs)
	var kinds: Array = tr.kinds
	var slowest := INF
	for k in kinds:
		slowest = minf(slowest, float(TRAFFIC[k].speed))
	var span := width_ + TRAFFIC_MARGIN * 2.0
	var now_n := int(floorf(t / every))
	var back := int(ceilf((span + 200.0) / slowest * 1000.0 / every))
	var out: Array = []
	for n in range(now_n - back, now_n + 1):
		var v := traffic_slot(n, kinds)
		var spec: Dictionary = TRAFFIC[v.kind]
		var travelled := (t - n * every) / 1000.0 * float(spec.speed)
		if travelled < 0.0 or travelled > span + float(spec.length):
			continue
		v.x = -TRAFFIC_MARGIN - float(spec.length) + travelled if int(v.dir) > 0 else width_ + TRAFFIC_MARGIN - travelled
		out.append(v)
	return out


func _draw_traffic(ci: CanvasItem, tr: Dictionary, t: float, off: Vector2, amb: Color, dark: float) -> void:
	# la strada sotto le ruote: marciapiede, asfalto e la riga tratteggiata, da un capo all'altro
	var road := off + Vector2(-TRAFFIC_MARGIN, float(tr.y))
	var long := width + TRAFFIC_MARGIN * 2.0
	ci.draw_rect(Rect2(road + Vector2(0, -16), Vector2(long, 5)), Color("8e887c") * amb)
	ci.draw_rect(Rect2(road + Vector2(0, -11), Vector2(long, 30)), Color("57585a") * amb)
	for k in int(long / 60.0):
		if _seen(road.x + k * 60.0, 28.0):
			ci.draw_rect(Rect2(road + Vector2(k * 60.0, -5), Vector2(28, 2)), Color("a8a49a") * amb)
	var all := traffic_at(tr, t, width)
	# prima la corsia lontana (verso sinistra), poi quella vicina
	for lane in [-1, 1]:
		for v in all:
			if int(v.dir) == lane and _seen(off.x + float(v.x) - 80.0, float(TRAFFIC[v.kind].length) + 160.0):
				var y := float(tr.y) - (8.0 if lane < 0 else 0.0)
				_draw_car(ci, v, t, off + Vector2(float(v.x), y), amb, dark)


func _draw_car(ci: CanvasItem, v: Dictionary, t: float, o: Vector2, amb: Color, dark: float) -> void:
	var kind: String = v.kind
	var length: float = TRAFFIC[kind].length
	var dir: int = v.dir
	var body: Color = CAR_COLORS[int(v.color)] * amb
	var glass := Color("3c4048") * amb
	var front := o.x + length if dir > 0 else o.x
	var rear := o.x if dir > 0 else o.x + length
	var spin := t / 60.0
	match kind:
		"auto", "furgone":
			var h := 14.0 if kind == "auto" else 24.0
			ci.draw_rect(Rect2(o.x, o.y - 6 - h, length, h), body)
			if kind == "auto":
				var c0 := o.x + length * (0.18 if dir > 0 else 0.3)
				var cabin := PackedVector2Array([Vector2(c0, o.y - 20), Vector2(c0 + 6, o.y - 31), Vector2(c0 + length * 0.42, o.y - 31), Vector2(c0 + length * 0.52, o.y - 20)])
				ci.draw_colored_polygon(cabin, body)
				ci.draw_rect(Rect2(c0 + 7, o.y - 29, length * 0.18, 8), glass)
				ci.draw_rect(Rect2(c0 + 9 + length * 0.2, o.y - 29, length * 0.18, 8), glass)
			else:
				var cab: float = o.x + (length - 22.0 if dir > 0 else 4.0)
				ci.draw_rect(Rect2(cab, o.y - 27, 18, 9), glass)
			ci.draw_rect(Rect2(o.x, o.y - 6 - h, length, h), INK, false, 1.5)
			for wx in [o.x + 13, o.x + length - 13]:
				_wheel(ci, Vector2(wx, o.y - 5), 5.0, spin)
		"bus":
			ci.draw_rect(Rect2(o.x, o.y - 40, length, 34), Color("8c7a5a") * amb)
			ci.draw_rect(Rect2(o.x, o.y - 14, length, 8), (Color("8c7a5a") * amb).darkened(0.25))
			for k in int(length / 24):
				ci.draw_rect(Rect2(o.x + 8 + k * 24, o.y - 35, 18, 13), glass)
			ci.draw_rect(Rect2(o.x, o.y - 40, length, 34), INK, false, 1.5)
			for wx in [o.x + 24, o.x + length - 26]:
				_wheel(ci, Vector2(wx, o.y - 5), 6.0, spin)
		"vespa":
			var seat := Vector2(o.x + length * 0.5, o.y - 14)
			ci.draw_circle(Vector2(rear + dir * 9, o.y - 10), 7.0, body) # la pancia della Vespa
			ci.draw_line(Vector2(front - dir * 6, o.y - 6), Vector2(front - dir * 4, o.y - 24), body, 4.0) # scudo e manubrio
			_wheel(ci, Vector2(o.x + 5, o.y - 4), 4.0, spin)
			_wheel(ci, Vector2(o.x + length - 5, o.y - 4), 4.0, spin)
			_rider(ci, seat, dir, Color("4f5560") * amb, Color("6a5f52") * amb, true)
		"bici":
			var back := Vector2(o.x + 7, o.y - 6)
			var fore := Vector2(o.x + length - 7, o.y - 6)
			var frame := Color("4a4c50") * amb
			for c in [back, fore]:
				ci.draw_arc(c, 6.0, 0, TAU, 12, INK, 1.5)
			var pedal := Vector2(o.x + length * 0.5, o.y - 7)
			ci.draw_polyline(PackedVector2Array([back, pedal, fore, Vector2(o.x + length * 0.5 + dir * 6, o.y - 16), pedal]), frame, 1.5)
			var crank := Vector2(cos(t / 120.0), sin(t / 120.0)) * 3.5
			var seat := Vector2(o.x + length * 0.5 - dir * 3, o.y - 18)
			ci.draw_line(seat, pedal + crank, Color("3a3836") * amb, 2.5)
			ci.draw_line(seat, pedal - crank, Color("3a3836") * amb, 2.5)
			_rider(ci, seat, dir, CLOTHES[int(v.n) % CLOTHES.size()] * amb, HAIR[int(v.n) % HAIR.size()] * amb, false)
	# di sera fari e luci di dietro, che non si moltiplicano per la luce ambiente
	if dark > 0.3 and kind != "bici":
		var a := clampf((dark - 0.3) / 0.3, 0.0, 1.0)
		var lamp := Vector2(front, o.y - (30.0 if kind == "bus" else 14.0))
		var beam := PackedVector2Array([lamp, lamp + Vector2(dir * 70, -10), lamp + Vector2(dir * 70, 12)])
		ci.draw_colored_polygon(beam, Color(1.0, 0.92, 0.7, 0.22 * a))
		ci.draw_circle(lamp, 2.5, Color(1.0, 0.95, 0.8, a))
		ci.draw_circle(Vector2(rear, lamp.y), 2.0, Color(0.85, 0.3, 0.25, a))


static func _wheel(ci: CanvasItem, c: Vector2, r: float, spin: float) -> void:
	ci.draw_circle(c, r, INK)
	ci.draw_line(c - Vector2(cos(spin), sin(spin)) * (r - 1.5), c + Vector2(cos(spin), sin(spin)) * (r - 1.5), Color("5a5a5a"), 1.0)


# Chi guida la Vespa (col casco) o pedala: busto, testa e braccia verso il manubrio
static func _rider(ci: CanvasItem, seat: Vector2, dir: int, clothes: Color, top: Color, helmet: bool) -> void:
	var neck := seat + Vector2(dir * 3, -13)
	ci.draw_line(seat, neck, clothes, 7.0)
	ci.draw_line(neck + Vector2(0, 3), neck + Vector2(dir * 10, 6), clothes, 2.5)
	var head := neck + Vector2(dir * 1, -5)
	ci.draw_circle(head, 4.5, Color("a88068"))
	if helmet:
		ci.draw_arc(head, 5.0, PI * 0.95, PI * 2.05, 8, top, 4.0)
	else:
		ci.draw_arc(head, 4.5, PI, TAU, 8, top, 2.5)


# --- uccelli vicini (#278): rondini che sfrecciano a zig-zag di giorno, pipistrelli che svolazzano di notte ---
static func flyer_at(i: int, t: float, span: float, top: float) -> Vector2:
	var speed := 150.0 + float((i * 53) % 90) # pixel/s
	var dir := 1.0 if i % 2 == 0 else -1.0
	var x := fposmod(float(i) * 613.0 + dir * speed * t / 1000.0, span)
	var y := top + float((i * 71) % 150) + sin(t / (330.0 + i * 40.0) + i) * 40.0 + sin(t / 900.0 + i * 2.0) * 25.0
	return Vector2(x, y)


func _draw_flyers(ci: CanvasItem, f: Dictionary, t: float, off: Vector2, amb: Color, dark: float) -> void:
	var span := width + 800.0
	var swallows := clampf(1.0 - dark / 0.35, 0.0, 1.0)
	var bats := clampf((dark - 0.55) / 0.25, 0.0, 1.0)
	if swallows <= 0.0 and bats <= 0.0:
		return
	for i in int(f.count):
		var p := flyer_at(i, t, span, float(f.y)) + off - Vector2(400, 0)
		var before := flyer_at(i, t - 40.0, span, float(f.y)) + off - Vector2(400, 0)
		if p.distance_to(before) > 100.0 or not _seen(p.x - 20.0, 40.0):
			continue # ha appena fatto il giro dell'arena, o è fuori dall'inquadratura
		var dir := signf(p.x - before.x)
		if swallows > 0.0 and draw_frame(ci, "rondine", int(t / 45.0 + i), p, 0.45, dir < 0, Color(amb.r, amb.g, amb.b, swallows)):
			pass
		elif swallows > 0.0:
			# rondine: ali a falce indietro e la coda a forbice
			var col := Color(0.16, 0.17, 0.22, swallows) * Color(amb.r, amb.g, amb.b, 1.0)
			var beat := sin(t / 55.0 + i) * 4.0
			ci.draw_polyline(PackedVector2Array([p + Vector2(-dir * 4, -9 - beat), p + Vector2(dir * 3, -1), p + Vector2(-dir * 4, 7 + beat)]), col, 2.5)
			ci.draw_line(p + Vector2(dir * 5, 0), p + Vector2(-dir * 6, 0), col, 3.0)
			ci.draw_polyline(PackedVector2Array([p + Vector2(-dir * 11, -3), p + Vector2(-dir * 6, 0), p + Vector2(-dir * 11, 3)]), col, 1.5)
		if bats > 0.0 and i % 2 == 0:
			# pipistrello: ali a festone che battono veloci, solo metà degli uccelli
			# più in basso delle rondini, davanti alle finestre accese e all'orizzonte più chiaro
			var q := p + Vector2(0, 160.0 + sin(t / 140.0 + i) * 8.0)
			if draw_frame(ci, "pipistrello", int(t / 40.0 + i), q, 0.6, dir < 0, Color(1, 1, 1, bats)):
				continue
			var col := Color(0.03, 0.03, 0.05, 0.95 * bats)
			var beat := sin(t / 35.0 + i) * 7.0
			for side in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([q, q + Vector2(side * 8, -5 - beat), q + Vector2(side * 16, -3 - beat), q + Vector2(side * 12, 3), q + Vector2(side * 5, 1)]), col)
			ci.draw_circle(q, 3.0, col)


# --- aereo lontano (#278): ogni everyMs attraversa il cielo in 40 s, alternando il verso ---
const PLANE_PARALLAX := 0.05
const PLANE_CROSS_MS := 40000.0


static func plane_at(everyMs: float, t: float) -> Dictionary:
	var cycle := floorf(t / everyMs)
	var k := (t - cycle * everyMs) / PLANE_CROSS_MS
	return {"k": k, "dir": 1 if int(cycle) % 2 == 0 else -1, "on": k < 1.0}


func _draw_plane(ci: CanvasItem, pl: Dictionary, t: float, off: Vector2, dark: float) -> void:
	var f := plane_at(float(pl.everyMs), t)
	if not f.on:
		return
	var span := width + 1600.0
	var dir: float = f.dir
	var x: float = -800.0 + span * float(f.k) if dir > 0 else width + 800.0 - span * float(f.k)
	var p := Vector2(x, float(pl.y)) + off
	if dark < 0.5:
		# di giorno la scia bianca che si allarga e svanisce, poi la sagoma
		var a := 1.0 - dark * 2.0
		for k in 12:
			var tail := p - Vector2(dir * (10.0 + k * 30.0), 0)
			ci.draw_line(tail, tail - Vector2(dir * 30.0, 0), Color(1, 1, 1, a * 0.5 * (1.0 - k / 12.0)), 2.0 + k * 0.4)
		var col := Color(0.55, 0.57, 0.62, a)
		ci.draw_line(p - Vector2(dir * 8, 0), p + Vector2(dir * 8, 0), col, 2.5)
		ci.draw_line(p + Vector2(dir * 1, 0), p - Vector2(dir * 3, 5), col, 1.5)
		ci.draw_line(p - Vector2(dir * 7, 0), p - Vector2(dir * 8, -4), col, 1.5)
	else:
		# di notte solo le luci che lampeggiano
		var blink := fmod(t, 1200.0) < 120.0
		ci.draw_circle(p, 1.6, Color(0.85, 0.35, 0.3, 0.9))
		if blink:
			ci.draw_circle(p + Vector2(dir * 6, 0), 2.2, Color(1, 1, 1, 0.95))


# --- il bar (#278): tavolini con l'ombrellone, due persone sedute che bevono lo spritz e ogni tanto brindano,
# il cameriere che va e viene col vassoio, e di sera le lucine accese tra gli ombrelloni ---
const SPRITZ := Color("c47a44") # arancione spento: lontano dal rosso e dal giallo dei giocatori
const TOAST_EVERY_MS := 11000.0
const TOAST_MS := 1300.0


# Quanto è alzato il bicchiere di chi siede al tavolino: 1 alla bocca o nel brindisi, 0 sul tavolo
static func bar_sip(table: int, seat: int, t: float) -> float:
	if bar_toast(table, t):
		return 1.0
	var period := 5200.0 + float((table * 3 + seat) % 4) * 900.0
	var k := fposmod(t + table * 1700.0 + seat * 2600.0, period) / period
	return clampf(sin(k * TAU) * 3.0 - 2.0, 0.0, 1.0) # un sorso breve ogni giro


static func bar_toast(table: int, t: float) -> bool:
	return fposmod(t + table * 3700.0, TOAST_EVERY_MS) < TOAST_MS


# Il cameriere va e viene lungo i tavolini, fermandosi un attimo ai capi
static func waiter_x(t: float, x0: float, x1: float) -> float:
	var k := fposmod(t / 16000.0, 1.0)
	var tri := clampf(absf(k * 2.0 - 1.0) * 1.2 - 0.1, 0.0, 1.0)
	return lerpf(x0, x1, 1.0 - tri)


func _draw_bar(ci: CanvasItem, b: Dictionary, t: float, off: Vector2, amb: Color, dark: float) -> void:
	var n := int(b.tables)
	var sp := float(b.spacing)
	var base := Vector2(float(b.x), float(b.y)) + off
	if not _seen(base.x - 60.0, (n - 1) * sp + 120.0):
		return
	var canopy := Color("d2c8b0") * amb
	var stripe := Color("a89a80") * amb
	var tops: Array = []
	for i in n:
		var c := base + Vector2(i * sp, 0)
		# l'ombrellone: palo e tela a spicchi
		var top := c + Vector2(0, -62)
		tops.append(top)
		ci.draw_line(c + Vector2(0, -16), top, Color("5a5650") * amb, 2.0)
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-30, 10), top + Vector2(0, -4), top + Vector2(30, 10)]), canopy)
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-10, 10), top + Vector2(0, -4), top + Vector2(10, 10)]), stripe)
		ci.draw_line(top + Vector2(-30, 10), top + Vector2(30, 10), INK, 1.5)
		# le due persone sedute, una per lato, girate verso il tavolino
		for seat in 2:
			var side := -1.0 if seat == 0 else 1.0
			var hip := c + Vector2(side * 16, -12)
			var clothes: Color = CLOTHES[(i * 2 + seat) % CLOTHES.size()] * amb
			ci.draw_line(hip + Vector2(side * 3, 0), hip + Vector2(side * 3, -4), Color("4a4642") * amb, 2.0) # schienale
			ci.draw_line(hip, hip + Vector2(-side * 7, 0), Color("3a3836") * amb, 3.0) # cosce
			ci.draw_line(hip + Vector2(-side * 7, 0), c + Vector2(side * 9, 0), Color("3a3836") * amb, 3.0) # gambe
			var neck := hip + Vector2(side * 1, -14)
			ci.draw_line(hip, neck, clothes, 8.0)
			var head := neck + Vector2(0, -5)
			ci.draw_circle(head, 4.5, SKIN[(i + seat * 2) % SKIN.size()] * amb)
			ci.draw_arc(head, 4.5, PI, TAU, 8, HAIR[(i * 2 + seat) % HAIR.size()] * amb, 2.5)
			var up := bar_sip(i, seat, t)
			var toast := bar_toast(i, t)
			var glass := c + Vector2(side * 6, -24) if not toast else c + Vector2(side * 3, -34)
			if not toast:
				glass = glass.lerp(head + Vector2(-side * 4, 2), up)
			ci.draw_line(neck + Vector2(0, 3), glass + Vector2(0, 3), clothes, 2.5)
			ci.draw_rect(Rect2(glass + Vector2(-1.5, -3), Vector2(3.5, 6)), SPRITZ * amb)
		# il tavolino tondo, davanti alle gambe
		ci.draw_line(c + Vector2(0, -18), c, Color("4a4642") * amb, 2.0)
		ci.draw_rect(Rect2(c + Vector2(-11, -20), Vector2(22, 3)), Color("b0a894") * amb)
		ci.draw_rect(Rect2(c + Vector2(-6, -26), Vector2(3, 6)), SPRITZ * amb) # il terzo spritz, ancora pieno
		if bar_toast(i, t) and fposmod(t + i * 3700.0, TOAST_EVERY_MS) < 300.0:
			ci.draw_circle(c + Vector2(0, -36), 5.0, Color(1, 0.95, 0.8, 0.8)) # cin cin
	# il cameriere col vassoio alto
	var wx := waiter_x(t, base.x - 20.0, base.x + (n - 1) * sp + 20.0)
	var wdir := 1.0 if fposmod(t / 16000.0, 1.0) < 0.5 else -1.0
	var wp := Vector2(wx, base.y + 4)
	var step := sin(t / 160.0) * 4.0
	for leg in [-1.0, 1.0]:
		ci.draw_line(wp + Vector2(0, -15), wp + Vector2(leg * step, 0), Color("2e2c2a") * amb, 3.0)
	ci.draw_line(wp + Vector2(0, -15), wp + Vector2(0, -30), Color("e4e0d6") * amb, 9.0) # camicia bianca
	ci.draw_line(wp + Vector2(-2, -15), wp + Vector2(-2, -29), Color("2e2c2a") * amb, 3.0) # gilet
	ci.draw_circle(wp + Vector2(0, -35), 4.5, SKIN[1] * amb)
	ci.draw_arc(wp + Vector2(0, -35), 4.5, PI, TAU, 8, HAIR[0] * amb, 2.5)
	var tray := wp + Vector2(wdir * 9, -44)
	ci.draw_line(wp + Vector2(0, -28), tray + Vector2(0, 2), Color("e4e0d6") * amb, 2.5)
	ci.draw_line(tray - Vector2(8, 0), tray + Vector2(8, 0), Color("9a9a94") * amb, 2.0)
	for gx in [-5.0, 0.0, 5.0]:
		ci.draw_rect(Rect2(tray + Vector2(gx - 1.5, -6), Vector2(3, 6)), SPRITZ * amb)
	# di sera le lucine tra gli ombrelloni
	if dark > 0.25 and tops.size() > 1:
		var a := clampf((dark - 0.25) / 0.25, 0.0, 1.0)
		for k in range(tops.size() - 1):
			var p0: Vector2 = tops[k] + Vector2(0, 2)
			var p1: Vector2 = tops[k + 1] + Vector2(0, 2)
			for j in 7:
				var u := (j + 0.5) / 7.0
				var q := p0.lerp(p1, u) + Vector2(0, sin(u * PI) * 10.0)
				var tw := 0.75 + 0.25 * sin(t / 300.0 + j * 1.9 + k)
				ci.draw_circle(q, 4.0, Color(1.0, 0.82, 0.5, 0.25 * a * tw))
				ci.draw_circle(q, 1.6, Color(1.0, 0.9, 0.65, a * tw))


# --- piccioni: posati finché nessuno arriva vicino; scappano verso l'alto e tornano dopo un po' ---
const PIGEON_NEAR := Vector2(110, 120) # pixel orizzontali e verticali da cui un lottatore li fa scappare
const PIGEON_FLY_MS := 1400.0
const PIGEON_BACK_MS := 7000.0


static func pigeon_scared(p: Dictionary, fighters: Array, threats: Array) -> bool:
	for f in fighters:
		if absf(f.x - p.x) < PIGEON_NEAR.x and absf(f.y - p.y) < PIGEON_NEAR.y:
			return true
	for r in threats:
		if (r as Rect2).grow(60).has_point(Vector2(p.x, p.y)):
			return true
	return false


func draw_pigeons(ci: CanvasItem, t: float, now: float, fighters: Array, threats: Array) -> void:
	for p in _pigeons:
		if p.away < 0 and pigeon_scared(p, fighters, threats):
			p.away = now
		var away: float = p.away
		var dt: float = now - away
		if p.away >= 0 and dt > PIGEON_BACK_MS and not pigeon_scared(p, fighters, threats):
			p.away = -1.0
		var pos := Vector2(p.x, p.y)
		var flying := false
		if p.away >= 0:
			if dt < PIGEON_FLY_MS:
				var k := dt / PIGEON_FLY_MS
				pos += Vector2(160.0 * k * (1 if int(p.x) % 2 == 0 else -1), -260.0 * k * k)
				flying = true
			else:
				continue # lontano, fuori scena
		var frame := 2 + int((t + p.x) / 60.0) % 4 if flying else int(fposmod((t + p.x * 13.0) / 900.0, 4.0) >= 3.0)
		if not draw_frame(ci, "piccione", frame, pos + Vector2(0, 2), 0.7, int(p.x) % 2 == 1, Color.WHITE, true):
			_draw_pigeon(ci, pos, t + p.x, flying)


static func _draw_pigeon(ci: CanvasItem, pos: Vector2, t: float, flying: bool) -> void:
	var grey := Color("8d8f96")
	ci.draw_circle(pos + Vector2(0, -6), 6.0, grey) # corpo
	ci.draw_circle(pos + Vector2(5, -11), 3.5, Color("7c7e86")) # testa
	ci.draw_line(pos + Vector2(8, -11), pos + Vector2(11, -10), Color("c09060"), 1.5) # becco
	if flying:
		var flap := sin(t / 60.0) * 8.0
		ci.draw_polyline(PackedVector2Array([pos + Vector2(-10, -8 - flap), pos + Vector2(0, -7), pos + Vector2(10, -8 - flap)]), grey.darkened(0.2), 3.0)
	else:
		ci.draw_line(pos + Vector2(-2, -1), pos + Vector2(-2, 0), INK, 1.5)
		ci.draw_line(pos + Vector2(2, -1), pos + Vector2(2, 0), INK, 1.5)


# --- giorno e notte: un giro completo in cycleMs dall'inizio della partita, che riparte da startAt (0 = mezzogiorno) ---
# Fase del giorno da 0 a 1: 0 mezzogiorno, 0,25 tramonto, 0,5 mezzanotte, 0,75 alba
func day_phase(t: float) -> float:
	var d: Variant = life.get("daycycle")
	if not d is Dictionary:
		return 0.0
	if is_nan(match_start):
		match_start = t
	return fposmod((t - match_start) / float(d.cycleMs) + float(d.get("startAt", 0.0)), 1.0)


# Quanto è buio (0 giorno pieno, 1 notte piena): sale tra il pomeriggio e il tramonto, scende all'alba
static func darkness(phase: float) -> float:
	var c := 0.5 - 0.5 * cos(phase * TAU) # 0 a mezzogiorno, 1 a mezzanotte
	return clampf((c - 0.25) / 0.5, 0.0, 1.0)


# I momenti del giorno (#267): [fase, cielo in alto, cielo all'orizzonte, luce sulle cose]
const SKY_KEYS := [
	[0.0, Color8(92, 140, 196), Color8(190, 212, 226), Color(1, 1, 1)], # mezzogiorno
	[0.15, Color8(98, 138, 190), Color8(218, 208, 190), Color(1, 0.96, 0.9)], # pomeriggio, luce dorata
	[0.25, Color8(84, 84, 140), Color8(248, 148, 88), Color(1, 0.78, 0.6)], # tramonto
	[0.31, Color8(40, 42, 92), Color8(160, 82, 108), Color(0.66, 0.56, 0.72)], # crepuscolo viola
	[0.4, Color8(12, 16, 40), Color8(34, 42, 76), Color(0.34, 0.38, 0.58)], # notte
	[0.6, Color8(12, 16, 40), Color8(34, 42, 76), Color(0.34, 0.38, 0.58)],
	[0.69, Color8(36, 40, 86), Color8(132, 92, 132), Color(0.52, 0.5, 0.66)], # prima dell'alba
	[0.75, Color8(112, 132, 182), Color8(252, 182, 150), Color(1, 0.84, 0.76)], # alba rosa
	[0.86, Color8(108, 158, 208), Color8(214, 222, 226), Color(1, 0.98, 0.95)], # mattina
	[1.0, Color8(92, 140, 196), Color8(190, 212, 226), Color(1, 1, 1)],
]


# I tre colori del momento (cielo in alto, all'orizzonte, luce), sfumando tra i momenti vicini
static func sky_colors(phase: float) -> Array:
	var p := fposmod(phase, 1.0)
	for i in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if p >= a[0] and p <= b[0]:
			var k: float = (p - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
			k = k * k * (3.0 - 2.0 * k) # sfumatura dolce
			return [(a[1] as Color).lerp(b[1], k), (a[2] as Color).lerp(b[2], k), (a[3] as Color).lerp(b[3], k)]
	return [SKY_KEYS[0][1], SKY_KEYS[0][2], SKY_KEYS[0][3]]


# La luce del momento, che moltiplica strati, decorazioni e sfondo vivo (bianca senza ciclo del giorno)
func ambient(t: float) -> Color:
	if not life.get("daycycle") is Dictionary:
		return Color.WHITE
	return sky_colors(day_phase(t))[2]


# Il sole va dall'alba (0,75) al tramonto (0,25), la luna dal tramonto all'alba: k 0 sorge a sinistra, 0,5 in cima, 1 tramonta.
# Il cielo segue quasi la telecamera: l'arco sta dentro lo schermo e ai lati scende sotto l'orizzonte, dietro i palazzi
static func sky_body(phase: float, width_: float) -> Vector2:
	var k := fposmod(phase + 0.25, 0.5) / 0.5
	# in cima a destra del centro, così il palazzo di Padova non lo copre; la luna fa lo stesso giro
	return Vector2(width_ / 2.0 - 450.0 + 1500.0 * k, 30.0 + 510.0 * pow(absf(k - 0.5) * 2.0, 2.0))


# Le nuvole (#267): ognuna con quota, grandezza, velocità e profondità sue, sempre uguali per la stessa arena
static func cloud_at(i: int, t: float, span: float) -> Dictionary:
	var far := i % 2 == 0 # metà lontane (piccole e lente), metà più vicine
	var speed := (5.0 if far else 11.0) + float((i * 13) % 7) # pixel/s, verso destra
	var x := fposmod(float(i) * 731.0 + speed * t / 1000.0, span)
	var y := -260.0 + float((i * 97) % 300) + (0.0 if far else 60.0)
	return {"x": x, "y": y, "size": (110.0 if far else 190.0) + float((i * 53) % 90), "parallax": 0.06 if far else 0.16}


# Il cielo intero: gradiente, sole o luna, stelle e nuvole. Si disegna prima degli strati, che ci passano davanti
func draw_sky(ci: CanvasItem, t: float, view: Rect2) -> void:
	var d: Variant = life.get("daycycle")
	if not d is Dictionary or not d.get("sky", false):
		return
	var phase := day_phase(t)
	var cols := sky_colors(phase)
	var top: Color = cols[0]
	var horizon: Color = cols[1]
	var vc := view.get_center()
	var hy := 470.0 + offset(0.08, vc).y # l'orizzonte, dietro i palazzi
	var r := view.grow(60)
	var mid := top.lerp(horizon, 0.45)
	var my := lerpf(r.position.y, hy, 0.55)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, my), Vector2(r.position.x, my)]), PackedColorArray([top, top, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(r.position.x, my), Vector2(r.end.x, my), Vector2(r.end.x, hy), Vector2(r.position.x, hy)]), PackedColorArray([mid, mid, horizon, horizon]))
	ci.draw_rect(Rect2(r.position.x, hy, r.size.x, maxf(0.0, r.end.y - hy)), horizon)
	var dark := darkness(phase)
	var off := offset(0.08, vc)
	# stelle, prima del resto
	if dark > 0.45:
		var a := clampf((dark - 0.45) / 0.4, 0.0, 1.0)
		for i in 90:
			var sx := fposmod(i * 0.6180339 * 3000.0, width + 1400.0) - 700.0
			var sy := -420.0 + fposmod(i * 0.4142136 * 1000.0, 700.0)
			var tw := 0.55 + 0.45 * sin(t / 280.0 + i * 1.7)
			ci.draw_circle(Vector2(sx, sy) + off, 1.2 + (i % 3) * 0.6, Color(1, 1, 0.92, a * tw))
	# sole di giorno, luna di notte
	var body := sky_body(phase, width) + off
	if phase < 0.25 or phase >= 0.75:
		var low := clampf(absf(fposmod(phase + 0.25, 0.5) / 0.5 - 0.5) * 2.0, 0.0, 1.0) # 1 vicino all'orizzonte
		var col := Color(1.0, 0.97, 0.82).lerp(Color(1.0, 0.55, 0.28), low * low)
		for j in 4:
			ci.draw_circle(body, 90.0 - j * 18.0, Color(col.r, col.g, col.b, 0.07 + j * 0.05))
		ci.draw_circle(body, 30.0, col)
	else:
		for j in 3:
			ci.draw_circle(body, 54.0 - j * 12.0, Color(0.85, 0.88, 1.0, 0.05 + j * 0.03))
		ci.draw_circle(body, 22.0, Color(0.95, 0.95, 0.9))
		ci.draw_circle(body + Vector2(-6, -4), 6.0, Color(0.82, 0.83, 0.82))
		ci.draw_circle(body + Vector2(7, 6), 4.0, Color(0.82, 0.83, 0.82))
	# nuvole che scorrono, colorate dalla luce: bianche di giorno, rosa e arancio all'alba e al tramonto, scure di notte
	var lit := Color(0.96, 0.97, 0.98).lerp(horizon.lightened(0.25), 0.5 * clampf(dark * 2.0, 0.0, 1.0))
	lit = lit.lerp(Color(0.32, 0.36, 0.5), clampf((dark - 0.5) * 2.0, 0.0, 1.0))
	var shade := lit.darkened(0.16).lerp(top, 0.25)
	var span := width + 1600.0
	for i in 12:
		var c := cloud_at(i, t, span)
		var o := offset(float(c.parallax), vc)
		var cp := Vector2(float(c.x) - 800.0, float(c.y)) + o
		var sh: Variant = _sheets.get("nuvole")
		if sh != null:
			# la nuvola dipinta, larga come quella di prima e colorata dalla luce del momento (#288)
			draw_frame(ci, "nuvole", i, cp + Vector2(0, -float(c.size) * 0.12), float(c.size) * 1.35 / (float(sh.fw) * float(sh.scale)), i % 3 == 1, lit.lerp(Color.WHITE, 0.25))
		else:
			_draw_cloud(ci, cp, float(c.size), lit, shade, i)


static func _draw_cloud(ci: CanvasItem, pos: Vector2, w: float, lit: Color, shade: Color, seed: int) -> void:
	# prima la pancia in ombra (batuffoli bassi e larghi), poi i batuffoli in luce sopra, un po' spostati in alto
	for j in 4:
		var px := pos.x - w * 0.3 + j * w * 0.2
		ci.draw_circle(Vector2(px, pos.y + w * 0.02), w * 0.13, shade)
	for j in 5:
		var px := pos.x - w * 0.36 + j * w * 0.18
		var r := w * (0.12 + 0.06 * sin(seed * 1.3 + j * 2.1) + (0.07 if j == 2 else 0.0))
		ci.draw_circle(Vector2(px, pos.y - r * 0.45 - w * 0.02), r, lit)


# I lampioni accesi (#288) di uno strato, subito dopo di lui: l'alone attorno alla lanterna, il cono di luce che
# scende e la pozza chiara a terra (ground pixel sotto la lanterna). Così stanno dietro alle statue del palco
func draw_lamps(ci: CanvasItem, t: float, view: Rect2, parallax: float, ground := 101.0) -> void:
	var d: Variant = life.get("daycycle")
	if not d is Dictionary:
		return
	var on := night_lights(t)
	if on <= 0.0:
		return
	for l in d.get("lamps", []):
		if absf(float(l.parallax) - parallax) > 0.001:
			continue
		var p := Vector2(l.x, l.y) + offset(float(l.parallax), view.get_center())
		var warm := Color(1.0, 0.84, 0.55)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 8), p + Vector2(7, 8), p + Vector2(34, ground), p + Vector2(-34, ground)]), Color(warm, 0.12 * on))
		var pool := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pool.append(p + Vector2(cos(a) * 40.0, ground + sin(a) * 5.0))
		ci.draw_colored_polygon(pool, Color(warm, 0.22 * on))
		for j in 3:
			ci.draw_circle(p, 5.0 + j * 7.0, Color(warm, (0.32 - j * 0.09) * on))


# Quanto sono accese le luci della notte (#288): da 0 di giorno a 1 di sera, con la stessa soglia dei lampioni
func night_lights(t: float) -> float:
	if not life.get("daycycle") is Dictionary:
		return 0.0
	return clampf((darkness(day_phase(t)) - 0.2) / 0.3, 0.0, 1.0)


# Di notte lampioni e finestre accese (dopo le decorazioni, che intanto la luce ambiente ha scurito)
func draw_daycycle(ci: CanvasItem, t: float, view: Rect2) -> void:
	var d: Variant = life.get("daycycle")
	if not d is Dictionary:
		return
	var dark := darkness(day_phase(t))
	var on := clampf((dark - 0.2) / 0.3, 0.0, 1.0) # i lampioni si accendono al tramonto e si spengono all'alba
	if on <= 0.0:
		return
	var windows: Array = d.get("windows", [])
	for i in windows.size():
		# le finestre si accendono una alla volta, non tutte insieme
		var w: Dictionary = windows[i]
		var lit := clampf((dark - 0.25 - 0.06 * (i % 5)) / 0.15, 0.0, 1.0)
		if lit > 0.0:
			ci.draw_rect(Rect2(w.x, w.y, w.width, w.height), Color(1.0, 0.78, 0.42, 0.8 * lit))


# --- acqua intorno all'arena (#264): davanti a chi cade, con lo splash quando qualcuno ci finisce dentro ---
var _last_y := {} # id del lottatore -> y del frame prima
var _splashes: Array = [] # [x, y, ms dell'orologio del client]
const SPLASH_MS := 700.0


func outer_water_level(up: float) -> float:
	var w: Dictionary = life.get("outerWater", {})
	return lerpf(float(w.y), float(w.get("highY", w.y)), up)


func draw_outer_water(ci: CanvasItem, t: float, now: float, up: float, view: Rect2, fighters: Dictionary) -> void:
	if not life.get("outerWater") is Dictionary:
		return
	var level := outer_water_level(up)
	for id in fighters:
		var y: float = fighters[id].y
		if _last_y.has(id) and _last_y[id] < level and y >= level:
			_splashes.append([fighters[id].x, level, now])
		_last_y[id] = y
	var left := view.position.x - 40.0
	var right := view.end.x + 40.0
	var bottom := maxf(view.end.y, level) + 40.0
	var amb := ambient(t) # l'acqua prende la luce del momento: dorata al tramonto, scura di notte
	ci.draw_rect(Rect2(left, level, right - left, bottom - level), Color(0.27 * amb.r, 0.38 * amb.g, 0.4 * amb.b, 0.9))
	var wave := PackedVector2Array()
	var x := left
	while x <= right:
		wave.append(Vector2(x, level + 3.0 * sin(t / 300.0 + x / 41.0)))
		x += 18.0
	ci.draw_polyline(wave, Color("a9c2bf"), 2.5)
	for i in 4: # riflessi che scorrono
		var ry := level + 18.0 + i * 22.0
		var rx := left + fposmod(t / 30.0 + i * 140.0, 260.0)
		while rx < right:
			ci.draw_line(Vector2(rx, ry), Vector2(rx + 40.0, ry), Color(0.66, 0.76, 0.75, 0.25), 1.5)
			rx += 260.0
	var keep: Array = []
	for sp in _splashes:
		var k: float = (now - sp[2]) / SPLASH_MS
		if k >= 1.0:
			continue
		keep.append(sp)
		for j in 7: # gocce che saltano in alto e ricadono
			var ang := PI + PI * (j + 0.5) / 7.0
			var dist := 60.0 * k
			var p := Vector2(sp[0] + cos(ang) * dist, sp[1] + sin(ang) * dist * 1.4 + 90.0 * k * k)
			ci.draw_circle(p, 4.0 * (1.0 - k) + 1.0, Color(0.85, 0.93, 0.92, 1.0 - k))
		ci.draw_arc(Vector2(sp[0], sp[1]), 20.0 + 50.0 * k, PI, TAU, 16, Color(0.85, 0.93, 0.92, 0.8 * (1.0 - k)), 3.0)
	_splashes = keep
