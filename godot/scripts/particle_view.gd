# Disegna gli effetti a particelle (#470 passo 1): li tiene in vita, li invecchia e li disegna con le texture di
# godot/assets/fx/ (tools/fx/texture_particelle.py). È figlio di world_view.gd, quindi segue telecamera e scossa.
# Un suo figlio con fusione additiva (la luce si somma, come in Smash) disegna scintille, bagliori e le particelle "add".
# Le formule e gli emettitori stanno in particle_fx.gd; qui solo l'orologio, i gruppi e il disegno.
extends Node2D

const ParticleFx := preload("res://scripts/particle_fx.gd")
const TONES := ["dust", "smoke", "dark", "air", "core", "yellow", "orange", "red"]

var max_particles := 600 # oltre, i gruppi più vecchi spariscono (EFFECTS.particleMax)
var _groups: Array = [] # [{ t0, end, list }]: particelle nate insieme, in ms dell'orologio degli effetti
var _marks: Array = [] # stelle d'impatto, anelli e bagliori: [{ kind, t0, life_ms, ... }]
var _count := 0
var _now := 0.0 # ms, l'orologio degli effetti
var _tex := {} # "tono_forma" -> Array[Texture2D] (le varianti); manca se i file non ci sono
var _glow: Texture2D
var _add: Node2D


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
	for m in _marks:
		_draw_mark(m)
	draw_set_transform(Vector2.ZERO)


# Il livello additivo: scintille, particelle "add" e bagliori
func draw_additive(ci: CanvasItem) -> void:
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
	for m in _marks:
		var k := (_now - float(m.t0)) / float(m.life_ms)
		if _glow == null or k >= 1.0:
			continue
		if m.kind == "glow" or m.kind == "star":
			var radius: float = float(m.size) * (2.6 if m.kind == "star" else 1.0) * (1.0 if m.kind == "glow" else ParticleFx.star_scale(k))
			var col: Color = m.get("col", Color(1.0, 0.9, 0.6))
			col.a = (1.0 - k) * float(m.get("alpha", 0.9))
			ci.draw_set_transform(Vector2(m.x, m.y))
			ci.draw_texture_rect(_glow, Rect2(-radius, -radius, radius * 2, radius * 2), false, col)
	ci.draw_set_transform(Vector2.ZERO)


func _texture(tone: String, shape: String, v: int) -> Texture2D:
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
		ci.draw_texture_rect(t0, rect, false, Color(1, 1, 1, float(s.alpha) * (1.0 - f)))
	if f > 0.02:
		var t1 := _texture(s.tone1, shape, v)
		if t1:
			ci.draw_texture_rect(t1, rect, false, Color(1, 1, 1, float(s.alpha) * f))


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
	draw_set_transform(pos, float(p.spin) * a)
	draw_colored_polygon(PackedVector2Array([Vector2(-z, -z * 0.6), Vector2(z * 0.8, -z), Vector2(z, z * 0.5), Vector2(-z * 0.4, z)]), col)


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
			var r: float = lerpf(float(m.r0), float(m.r1), 1.0 - (1.0 - k) * (1.0 - k))
			var col: Color = m.get("col", Color.WHITE)
			col.a = float(m.get("alpha", 0.85)) * (1.0 - k)
			draw_set_transform(c, 0.0, Vector2(1.0, float(m.get("squash", 1.0))))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, col, float(m.get("width", 3.5)) * (1.0 - k) + 0.4, true)
