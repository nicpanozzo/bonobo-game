# Disegna gli effetti a particelle (#470 passo 1): li tiene in vita, li invecchia e li disegna con le texture di
# godot/assets/fx/ (tools/fx/texture_particelle.py). È figlio di world_view.gd, quindi segue telecamera e scossa.
# Un suo figlio con fusione additiva (la luce si somma, come in Smash) disegna scintille, bagliori e le particelle "add".
# Le formule e gli emettitori stanno in particle_fx.gd; qui solo l'orologio, i gruppi e il disegno.
extends Node2D

const ParticleFx := preload("res://scripts/particle_fx.gd")
const FighterFx := preload("res://scripts/fighter_fx.gd")
const TONES := ["dust", "smoke", "dark", "air", "core", "yellow", "orange", "red"]

var max_particles := 600 # oltre, i gruppi più vecchi spariscono (EFFECTS.particleMax)
var _groups: Array = [] # [{ t0, end, list }]: particelle nate insieme, in ms dell'orologio degli effetti
var _marks: Array = [] # stelle d'impatto, anelli e bagliori: [{ kind, t0, life_ms, ... }]
var _count := 0
var _now := 0.0 # ms, l'orologio degli effetti
var _tex := {} # "tono_forma" -> Array[Texture2D] (le varianti); manca se i file non ci sono
var _glow: Texture2D
var _add: Node2D
var _clouds := {} # id -> { pos, col }: le nuvolette della rinascita (#470 passo 2a), le muove world_view.gd
var _live := {} # chiave -> { list: [[particella, età]], at }: fuochi calcolati a ogni frame dal tempo dell'arena (#470 fase 4)


# Il livello additivo: chiede a chi lo possiede di disegnarci sopra
class AddLayer extends Node2D:
	var view # chi lo possiede (particle_view.gd), senza tipo: la chiamata a draw_additive si risolve a runtime

	func _draw() -> void:
		view.draw_additive(self)


func _ready() -> void:
	for tone in TONES:
		for shape in ["puff", "flame"]:
			var list: Array = []
			for v in ParticleFx.VARIANTS:
				var path := "res://assets/fx/%s_%s_%d.png" % [tone, shape, v]
				if ResourceLoader.exists(path):
					list.append(load(path))
			if not list.is_empty():
				_tex["%s_%s" % [tone, shape]] = list
	if ResourceLoader.exists("res://assets/fx/glow.png"):
		_glow = load("res://assets/fx/glow.png")
	_add = AddLayer.new()
	_add.view = self
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = additive
	add_child(_add)


# Un gruppo di particelle che nasce adesso (da particle_fx.gd)
func add(list: Array) -> void:
	if list.is_empty():
		return
	_groups.append({"t0": _now, "end": _now + ParticleFx.span(list) * 1000.0, "list": list})
	_count += list.size()
	while _count > max_particles and _groups.size() > 1:
		_count -= (_groups[0].list as Array).size()
		_groups.pop_front()


# Un segno disegnato qui e non con le particelle: "star" (stella d'impatto), "ring" (anello o onda), "glow" (bagliore)
func mark(m: Dictionary) -> void:
	m.t0 = _now
	_marks.append(m)


func clear() -> void:
	_clouds = {}
	_live = {}
	_groups = []
	_marks = []
	_count = 0


func particle_count() -> int:
	return _count


func _process(delta: float) -> void:
	_now += delta * 1000.0
	if not _groups.is_empty():
		var kept: Array = []
		for g in _groups:
			if float(g.end) > _now:
				kept.append(g)
			else:
				_count -= (g.list as Array).size()
		_groups = kept
	if not _marks.is_empty():
		_marks = _marks.filter(func(m): return _now - float(m.t0) < float(m.life_ms))
	for key in _live.keys(): # un fuoco che non si ridisegna più (fuori inquadratura, arena cambiata) si spegne
		if _now - float(_live[key].at) > 100.0:
			_live.erase(key)
	queue_redraw()
	if _add:
		_add.queue_redraw()


func _draw() -> void:
	for g in _groups:
		var a := (_now - float(g.t0)) / 1000.0
		for p in g.list:
			var ap: float = a - float(p.get("delay", 0.0))
			if ap < 0.0:
				continue
			var kind: String = p.get("kind", "tex")
			if kind == "tex" and not p.get("add", false):
				_draw_tex(self, p, ap)
			elif kind == "grit":
				_draw_grit(p, ap)
			elif kind == "pixel":
				_draw_pixel(p, ap)
			elif kind == "star5":
				_draw_star5(p, ap)
			elif kind == "slice":
				_draw_slice(p, ap)
	for key in _live:
		for pa in _live[key].list:
			var lp: Dictionary = pa[0]
			if lp.get("kind", "tex") == "tex" and not lp.get("add", false):
				_draw_tex(self, lp, float(pa[1]))
	for id in _clouds:
		_draw_cloud(_clouds[id])
	for m in _marks:
		_draw_mark(m)
	draw_set_transform(Vector2.ZERO)


# Il livello additivo: scintille, particelle "add" e bagliori
func draw_additive(ci: CanvasItem) -> void:
	if _glow: # il bagliore delle nuvolette della rinascita
		for id in _clouds:
			var c: Dictionary = _clouds[id]
			var gc: Color = (c.col as Color).lightened(0.5)
			gc.a = 0.45
			ci.draw_set_transform(c.pos)
			ci.draw_texture_rect(_glow, Rect2(-80, -60, 160, 120), false, gc)
	for g in _groups:
		var a := (_now - float(g.t0)) / 1000.0
		for p in g.list:
			var ap: float = a - float(p.get("delay", 0.0))
			if ap < 0.0:
				continue
			var kind: String = p.get("kind", "tex")
			if kind == "spark":
				_draw_spark(ci, p, ap)
			elif kind == "tex" and p.get("add", false):
				_draw_tex(ci, p, ap)
	for key in _live:
		for pa in _live[key].list:
			var lp: Dictionary = pa[0]
			var lk: String = lp.get("kind", "tex")
			if lk == "spark":
				_draw_spark(ci, lp, float(pa[1]))
			elif lk == "tex" and lp.get("add", false):
				_draw_tex(ci, lp, float(pa[1]))
	for m in _marks:
		var k := (_now - float(m.t0)) / float(m.life_ms)
		if m.kind == "sparkle" and k < 1.0:
			_draw_sparkle(ci, m, k)
			continue
		if _glow == null or k >= 1.0:
			continue
		if m.kind == "glow" or m.kind == "star":
			var radius: float = float(m.size) * (2.6 if m.kind == "star" else 1.0) * (1.0 if m.kind == "glow" else ParticleFx.star_scale(k))
			var col: Color = m.get("col", Color(1.0, 0.9, 0.6))
			col.a = (1.0 - k) * float(m.get("alpha", 0.9))
			ci.draw_set_transform(Vector2(m.x, m.y))
			ci.draw_texture_rect(_glow, Rect2(-radius, -radius, radius * 2, radius * 2), false, col)
	ci.draw_set_transform(Vector2.ZERO)


# La nuvoletta della rinascita di un giocatore: dove sta (i piedi ci poggiano sopra) e di che colore è
func set_cloud(id: String, pos: Vector2, col: Color) -> void:
	_clouds[id] = {"pos": pos, "col": col}


func drop_cloud(id: String) -> void:
	_clouds.erase(id)


func has_cloud(id: String) -> bool:
	return _clouds.has(id)


# Particelle vive calcolate da chi le possiede per l'istante di adesso (ParticleFx.fire_wall): si disegnano finché
# vengono rinnovate a ogni frame
func set_live(key: String, list: Array) -> void:
	_live[key] = {"list": list, "at": _now}


# Tre sbuffi del fumo colorati col colore del giocatore, schiariti: una nuvoletta morbida, con un bagliore additivo
func _draw_cloud(c: Dictionary) -> void:
	var tex := _texture("smoke", "puff", 0)
	if tex == null:
		return
	var pos: Vector2 = c.pos
	var col: Color = (c.col as Color).lightened(0.45)
	draw_set_transform(Vector2.ZERO)
	for b in [[-22.0, 6.0, 20.0, 1], [0.0, 0.0, 26.0, 2], [24.0, 5.0, 22.0, 3]]:
		var r: float = b[2]
		var t2 := _texture("smoke", "puff", int(b[3]))
		draw_texture_rect(t2 if t2 else tex, Rect2(pos.x + float(b[0]) - r, pos.y + float(b[1]) - r, r * 2.0, r * 2.0), false, col)


# Luccichio (#470 passo 3): una stella a quattro punte che brilla e sparisce. "converge" = si stringe verso x1, y1
# rimpicciolendo (raccolta); altrimenti cresce e cala sul posto (comparsa, caduta veloce)
func _draw_sparkle(ci: CanvasItem, m: Dictionary, k: float) -> void:
	var converge: bool = m.has("x1")
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var pos := Vector2(m.x, m.y).lerp(Vector2(m.get("x1", m.x), m.get("y1", m.y)), e) if converge else Vector2(m.x, m.y)
	var size: float = float(m.size) * ((1.0 - k) + 0.15 if converge else sin(k * PI))
	if size <= 0.3:
		return
	var col: Color = m.get("col", Color.WHITE)
	col.a = 1.0 - k * 0.3
	ci.draw_set_transform(pos, float(m.get("spin", 0.0)) * k)
	ci.draw_colored_polygon(ParticleFx.star_points(Vector2.ZERO, size, 4, 0.18, 0, 0.0), col)
	if _glow:
		var gc := Color(1, 1, 1, 0.55 * (1.0 - k))
		ci.draw_texture_rect(_glow, Rect2(-size * 2.2, -size * 2.2, size * 4.4, size * 4.4), false, gc)


func _texture(tone: String, shape: String, v: int) -> Texture2D:
	if tone == "tint": # il tono del giocatore: la texture del fumo, colorata da modulate in _draw_tex
		tone = "smoke"
	var list: Array = _tex.get("%s_%s" % [tone, shape], _tex.get("%s_puff" % tone, []))
	return list[v % list.size()] if not list.is_empty() else null


func _draw_tex(ci: CanvasItem, p: Dictionary, a: float) -> void:
	var s := ParticleFx.sample(p, a)
	if s.is_empty() or float(s.alpha) <= 0.01:
		return
	var size: float = s.size
	var stretch: float = p.get("stretch", 1.0)
	var shape: String = p.get("shape", "puff")
	var v: int = p.get("v", 0)
	var f: float = s.f
	var rect := Rect2(-size, -size, size * 2.0, size * 2.0)
	ci.draw_set_transform(s.pos, s.rot, Vector2(1.0 / sqrt(stretch), stretch))
	var t0 := _texture(s.tone0, shape, v)
	if t0:
		ci.draw_texture_rect(t0, rect, false, _modulate(s.tone0, p, float(s.alpha) * (1.0 - f)))
	if f > 0.02:
		var t1 := _texture(s.tone1, shape, v)
		if t1:
			ci.draw_texture_rect(t1, rect, false, _modulate(s.tone1, p, float(s.alpha) * f))


# Il colore con cui si disegna un tono: bianco (la texture com'è), o il colore del giocatore per "tint"
static func _modulate(tone: String, p: Dictionary, alpha: float) -> Color:
	var c: Color = p.get("tint", Color.WHITE) if tone == "tint" else Color.WHITE
	c.a = alpha
	return c


# Granello: un quadrilatero storto che gira, ricade e saltella sul terreno
func _draw_grit(p: Dictionary, a: float) -> void:
	var k := a / float(p.life)
	if k >= 1.0:
		return
	var pos := ParticleFx.at(p, a)
	var floor_y: float = p.get("floor", INF)
	if pos.y > floor_y:
		pos.y = floor_y - absf(sin(a * 14.0)) * 2.0 * (1.0 - k)
	var col: Color = p.col
	col.a = 1.0 if k < 0.7 else (1.0 - k) / 0.3
	var z: float = float(p.s) * ParticleFx.SCALE
	draw_set_transform(pos, float(p.spin) * a, Vector2(float(p.get("stretch", 1.0)), 1.0)) # stretch: filo d'erba, scheggia
	draw_colored_polygon(PackedVector2Array([Vector2(-z, -z * 0.6), Vector2(z * 0.8, -z), Vector2(z, z * 0.5), Vector2(-z * 0.4, z)]), col)


# Quadratino di pixel (Egiainuso, fighter_fx.gd): fermo sulla griglia, si muove a scatti e sfarfalla
func _draw_pixel(p: Dictionary, a: float) -> void:
	if not FighterFx.pixel_visible(p, a):
		return
	var z: float = float(p.s) * ParticleFx.SCALE
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(FighterFx.pixel_at(p, a) - Vector2(z, z) * 0.5, Vector2(z, z)), p.col)


# Stellina a cinque punte che salta e ricade (Marcomunista, fighter_fx.gd)
func _draw_star5(p: Dictionary, a: float) -> void:
	var k := a / float(p.life)
	if k >= 1.0:
		return
	var pos := ParticleFx.at(p, a)
	var floor_y: float = p.get("floor", INF)
	pos.y = minf(pos.y, floor_y)
	var col: Color = p.col
	col.a = 1.0 if k < 0.7 else (1.0 - k) / 0.3
	draw_set_transform(pos, float(p.spin) * a)
	draw_colored_polygon(ParticleFx.star_points(Vector2.ZERO, float(p.s) * ParticleFx.SCALE, 5, 0.45, 0, 0.0), col)


# Scintilla: un tratto dalla posizione di un attimo prima a quella di adesso, che si assottiglia e si spegne
func _draw_spark(ci: CanvasItem, p: Dictionary, a: float) -> void:
	var k := a / float(p.life)
	if k >= 1.0:
		return
	var col: Color = p.col
	col.a = 1.0 - k
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_line(ParticleFx.at(p, maxf(0.0, a - 0.022)), ParticleFx.at(p, a), col, float(p.w) * ParticleFx.SCALE * 0.75 * (1.0 - k * 0.6), true)


func _draw_mark(m: Dictionary) -> void:
	var k := (_now - float(m.t0)) / float(m.life_ms)
	if k >= 1.0:
		return
	var c := Vector2(m.x, m.y)
	match str(m.kind):
		"star": # stella a tre toni, allungata nella direzione del colpo, con un'onda bianca che si allarga
			var sc := ParticleFx.star_scale(k)
			var radius: float = float(m.size) * sc
			var key: int = m.seed
			var spikes := 12 if m.ko else 9
			var outer := Color("ff6a3a") if m.ko else (Color("ffc23a") if m.heavy else Color("fff0b0"))
			var middle := Color("ffb347") if m.ko else Color("ffe27a")
			var alpha := minf(1.0, (1.0 - k) * 1.6)
			outer.a = alpha
			middle.a = alpha
			draw_set_transform(c, 0.0, Vector2(1.25, 0.85))
			if radius > 0.5:
				draw_colored_polygon(ParticleFx.star_points(Vector2.ZERO, radius, spikes, 0.42, key, 0.55), outer)
				draw_colored_polygon(ParticleFx.star_points(Vector2.ZERO, radius * 0.72, spikes, 0.46, key + 3, 0.45), middle)
				draw_colored_polygon(ParticleFx.star_points(Vector2.ZERO, radius * 0.42, 7, 0.55, key + 5, 0.3), Color(1, 1, 1, alpha))
			var rk := minf(1.0, k * 1.4)
			draw_set_transform(c)
			var rr: float = float(m.size) * (0.9 + rk * 1.8)
			if rk < 1.0:
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(1, 1, 1, 0.9 * (1.0 - rk)), 2.2 * (1.0 - rk), true)
		"ring": # anello d'aria del salto o onda d'urto: un'ellisse che si allarga e si assottiglia
			var e := 1.0 - (1.0 - k) * (1.0 - k)
			var r: float = lerpf(float(m.r0), float(m.r1), e)
			var col: Color = m.get("col", Color.WHITE)
			col.a = float(m.get("alpha", 0.85)) * (1.0 - k)
			if m.has("x1"): # l'anello di fumo della bombarda: va avanti mentre si allarga
				c = c.lerp(Vector2(m.x1, m.y1), e)
			draw_set_transform(c, float(m.get("angle", 0.0)), Vector2(1.0, float(m.get("squash", 1.0))))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, col, float(m.get("width", 3.5)) * (1.0 - k) + 0.4, true)


# Fetta di mortadella (#470 fase 4): rosa coi quadretti di grasso e un pistacchio, gira su se stessa in volo e a
# terra resta piatta
const SLICE_DOTS := [Vector2(0.3, -0.2), Vector2(-0.35, 0.1), Vector2(0.05, 0.4), Vector2(-0.1, -0.45), Vector2(0.45, 0.25)]
func _draw_slice(p: Dictionary, a: float) -> void:
	var k := a / float(p.life)
	if k >= 1.0:
		return
	var pos := ParticleFx.at(p, a)
	var flip := absf(cos(float(p.flip) * a))
	var rot := float(p.spin) * a
	if pos.y > float(p.get("floor", INF)):
		pos.y = float(p.floor)
		flip = 0.3
		rot = 0.0
	var alpha := 1.0 if k < 0.75 else (1.0 - k) / 0.25
	var z: float = float(p.s) * ParticleFx.SCALE
	draw_set_transform(pos, rot, Vector2(1.0, maxf(0.25, flip)))
	draw_circle(Vector2.ZERO, z + 2.0, Color(0.13, 0.11, 0.15, alpha))
	draw_circle(Vector2.ZERO, z, Color(Color("d77f8e"), alpha))
	draw_circle(Vector2(-z * 0.12, -z * 0.14), z * 0.8, Color(Color("f2a7b2"), alpha))
	for i in SLICE_DOTS.size():
		draw_circle(SLICE_DOTS[i] * z, z * 0.12, Color(Color("7fae4a") if i == 2 else Color("fff4f2"), alpha))
