# Effetti della sala d'attesa 3D (hall_view.gd): polvere, onde, fasci di luce, scintille, coriandoli, scritte che salgono.
# Partono dagli HallEvent e non toccano niente dello stato: ogni effetto si toglie da solo quando ha finito.
# Particelle sulla CPU (CPUParticles3D): con gl_compatibility (WebGL2, telefoni) sono le più sicure, e sono poche.
extends Node3D

const HallIcons := preload("res://scripts/hall_icons.gd")

const MAX_LIVE := 40 # effetti vivi insieme al massimo: oltre si salta (una festa di spinte non affonda i telefoni)
const CONFETTI := [Color("e74c3c"), Color("ffcf4a"), Color("3498db"), Color("2ecc71"), Color("9b59b6"), Color("ff7675"), Color.WHITE]

static var _mats := {} # materiali delle particelle, uno per tipo, condivisi
static var _gradient: Texture2D # la sfumatura dei fasci di luce

var calm := false # accessibilità: meno lampi e meno roba in giro
var _items: Array = [] # effetti vivi: { node, kind, t, life, ... }


func dust(at: Vector3, amount := 10, col := Color(0.85, 0.8, 0.95, 0.6), spread := 0.6) -> void:
	var p := _particles(amount, 0.55, _material("glow", false))
	if p == null:
		return
	p.position = at + Vector3(0, 0.08, 0)
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 90.0
	p.flatness = 0.85
	p.initial_velocity_min = spread * 1.2
	p.initial_velocity_max = spread * 2.6
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 3.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.5
	p.color_ramp = _fade(col)
	_go(p)


# Fumo del cambio di lottatore: una nuvola grossa e lenta che lo nasconde mentre si cambia
func smoke(at: Vector3, col := Color(0.9, 0.9, 1.0, 0.85)) -> void:
	var p := _particles(26, 0.9, _material("glow", false))
	if p == null:
		return
	p.position = at + Vector3(0, 0.9, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.color_ramp = _fade(col)
	_go(p)


# Scintille d'oro che schizzano in alto e ricadono: trono, voto, bot che arriva
func sparkles(at: Vector3, col := Color("ffcf4a"), amount := 40, power := 1.0) -> void:
	var p := _particles(int(amount * (0.5 if calm else 1.0)), 1.3, _material("sparkle", true))
	if p == null:
		return
	p.position = at
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 2.5 * power
	p.initial_velocity_max = 6.0 * power
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.color_ramp = _fade(col, true)
	_go(p)


# Coriandoli sparati da un cannone: verso dir, poi giù piano girando
func confetti(at: Vector3, dir: Vector3, amount := 90) -> void:
	var p := _particles(int(amount * (0.5 if calm else 1.0)), 3.2, _material("confetti", false))
	if p == null:
		return
	p.position = at
	p.direction = dir.normalized()
	p.spread = 22.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3(0, -5.0, 0)
	p.damping_min = 2.2
	p.damping_max = 3.2
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in CONFETTI.size():
		offsets.append(float(i) / CONFETTI.size())
	g.offsets = offsets
	g.colors = PackedColorArray(CONFETTI)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT # colori pieni, niente mezze tinte
	p.color_initial_ramp = g
	_go(p)


# Scia di chi rimbalza sul trampolino: lo segue per un po'
func trail(target: Node3D, col: Color, seconds := 0.9) -> void:
	if target == null or _items.size() >= MAX_LIVE:
		return
	var p := _particles(30, 0.5, _material("glow", true))
	p.one_shot = false
	p.explosiveness = 0.0
	p.position = Vector3(0, 0.9, 0)
	p.local_coords = false
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	p.color_ramp = _fade(col, true)
	target.add_child(p)
	p.emitting = true
	_items.append({"node": p, "kind": "trail", "t": 0.0, "life": seconds + 0.6, "stop": seconds})


# Onda che si allarga a terra (spinta, gong) o in piedi (vertical, il suono del gong)
func ring_wave(at: Vector3, col: Color, to_radius: float, seconds := 0.55, vertical := false, thick := 0.08) -> void:
	if _items.size() >= MAX_LIVE:
		return
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.0 - thick
	t.outer_radius = 1.0 + thick
	t.rings = 48
	t.ring_segments = 4
	m.mesh = t
	m.material_override = _additive(col)
	m.position = at + Vector3(0, 0.06, 0)
	if vertical:
		m.rotation.x = PI / 2.0
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_items.append({"node": m, "kind": "ring", "t": 0.0, "life": seconds, "to": to_radius, "vertical": vertical, "color": col})
	_step(_items[-1], 0.0)


# Colonna di luce che scende dal cielo (bot che arriva, giocatore che entra, voto)
func beam(at: Vector3, col: Color, height := 9.0, seconds := 1.1, radius := 0.7) -> void:
	if _items.size() >= MAX_LIVE:
		return
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 20
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	m.mesh = c
	var mat := _additive(col)
	mat.albedo_texture = _beam_gradient()
	m.material_override = mat
	m.position = at + Vector3(0, height / 2.0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_items.append({"node": m, "kind": "beam", "t": 0.0, "life": seconds, "color": col})
	_step(_items[-1], 0.0)
	ring_wave(at, col, radius * 2.6, seconds * 0.6)


# Scritta che sale e svanisce ("+1", "GONG!")
func floater(at: Vector3, text: String, col: Color, size := 64, rise := 1.2, seconds := 1.1) -> void:
	if _items.size() >= MAX_LIVE:
		return
	var l := Label3D.new()
	l.text = text
	l.font = UI.font(UI.WEIGHT_BOLD)
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = maxi(8, size / 5)
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	add_child(l)
	_items.append({"node": l, "kind": "floater", "t": 0.0, "life": seconds, "at": at, "rise": rise, "color": col})
	_step(_items[-1], 0.0)


func _process(delta: float) -> void:
	var keep: Array = []
	for it in _items:
		if not is_instance_valid(it.node):
			continue
		it.t += delta
		if it.t >= it.life:
			it.node.queue_free()
			continue
		_step(it, delta)
		keep.append(it)
	_items = keep


func effect_count() -> int:
	return _items.size()


# Un passo di un effetto: le animazioni sono a mano (niente Tween né timer: funzionano anche fuori dall'albero)
func _step(it: Dictionary, _delta: float) -> void:
	var k: float = clampf(it.t / it.life, 0.0, 1.0)
	match it.kind:
		"trail":
			if it.t >= it.stop:
				it.node.emitting = false
		"ring":
			var e := 1.0 - pow(1.0 - k, 3.0)
			var r: float = lerpf(0.2, it.to, e)
			it.node.scale = Vector3(r, r if it.vertical else 0.3, r)
			it.node.material_override.albedo_color = Color(it.color, (1.0 - k * k) * it.color.a)
		"beam":
			# si apre di colpo, si stringe e svanisce
			var w := 1.2 * sin(minf(k / 0.18, 1.0) * PI * 0.5) if k < 0.18 else lerpf(1.2, 0.7, (k - 0.18) / 0.82)
			it.node.scale = Vector3(maxf(0.05, w), 1.0, maxf(0.05, w))
			it.node.material_override.albedo_color = Color(it.color, it.color.a * (1.0 - smoothstep(0.1, 1.0, k)))
		"floater":
			var pop := minf(1.0, it.t / 0.18)
			it.node.scale = Vector3.ONE * lerpf(0.4, 1.0, 1.0 - pow(1.0 - pop, 3.0))
			it.node.position = it.at + Vector3(0, it.rise * (1.0 - pow(1.0 - k, 2.0)), 0)
			var a := 1.0 - smoothstep(0.6, 1.0, k)
			it.node.modulate = Color(it.color, a)
			it.node.outline_modulate = Color(0, 0, 0, 0.85 * a)


# --- pezzi ---

func _particles(amount: int, lifetime: float, mat: Material) -> CPUParticles3D:
	if _items.size() >= MAX_LIVE:
		return null
	var p := CPUParticles3D.new()
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.5
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _go(p: CPUParticles3D) -> void:
	add_child(p)
	p.emitting = true
	_items.append({"node": p, "kind": "particles", "t": 0.0, "life": p.lifetime + 0.3})


static func _fade(col: Color, add := false) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(col, 0.0 if not add else col.a), col, Color(col, 0.0)])
	return g


static func _material(kind: String, add: bool) -> Material:
	var key := "%s/%s" % [kind, add]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	match kind:
		"glow": m.albedo_texture = HallIcons.glow()
		"sparkle": m.albedo_texture = HallIcons.sparkle()
		"confetti":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if kind != "confetti" else BaseMaterial3D.BILLBOARD_DISABLED
	_mats[key] = m
	return m


static func _additive(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	return m


# Sfumatura verticale dei fasci: piena in basso, nulla in alto
static func _beam_gradient() -> Texture2D:
	if _gradient == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 1.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 64
		_gradient = t
	return _gradient
