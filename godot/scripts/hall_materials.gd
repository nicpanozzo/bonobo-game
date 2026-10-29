# Materiali della sala d'attesa 3D (hall_view.gd): marmo, pareti, oro, neon, pedane, portali, schermi,
# velluti, fasci di luce e lottatori 2D col contorno. Tutto procedurale negli shader hall_mat_*.gdshader:
# niente texture da scaricare, e tutto compila in Compatibility (WebGL2, telefoni).
#
# COME SI USA (hall_view.gd):
#   var floor := MeshInstance3D.new()
#   floor.mesh = PlaneMesh.new(); floor.mesh.size = Vector2(40, 30)
#   floor.material_override = HallMaterials.floor_material(2.0, 3.0)  # lastre da 2 m, rosone di 3 m al centro
#   world_env.environment = HallMaterials.env()
#   add_child(HallMaterials.backdrop())                                # fondale stellato oltre le pareti
#
#   I pezzi "a disco" e i fasci hanno già la mesh giusta, materiale compreso:
#   add_child(HallMaterials.pad(Color.YELLOW, 2.4))        # pedana di 2,4 m di diametro, distesa a terra
#   add_child(HallMaterials.ready_ring(3.0))                # cerchio "pronti"
#   add_child(HallMaterials.trampoline(2.0))                # tappeto elastico
#   add_child(HallMaterials.portal(preview_tex, 2.2, 3.4))  # portale 2,2 x 3,4 m, base all'origine, guarda +z
#   add_child(HallMaterials.god_ray(6.0, 0.15, 1.6))        # faro: origine sulla lampada, il cono scende lungo -y
#   add_child(HallMaterials.halo(Color.GOLD, 1.5))          # bagliore finto (bloom) sempre rivolto alla telecamera
#   add_child(HallMaterials.light_pool(Color.GOLD, 3.0))    # pozza di luce a terra sotto un faro
#   add_child(HallMaterials.blob_shadow(0.9, 0.35))         # ombra sotto lottatori e statue
#   Sono MeshInstance3D: spostali e ruotali come vuoi. Il materiale è in .material_override.
#
#   Lottatori 2D: var f := HallMaterials.fighter(tex, Vector2(336, 368), 286, 0.006, Color.RED)
#   (fotogramma 336x368 px, piedi a 286 px dall'alto, 0,006 m per pixel: l'origine è ai piedi.)
#   Cambiare fotogramma: HallMaterials.set_sprite_frame(f.material_override, frame, 336, 368, columns)
#   Statuette d'oro sui piedistalli: f.material_override.set_shader_parameter("gild", 1.0)
#
# PARAMETRI DA ANIMARE (con un Tween: tween_property(mat, "shader_parameter/active", 1.0, 0.25)):
#   pad: active 0..1 (qualcuno sopra)    ready_ring: fill 0..1 (pronti / totale; a 1 pulsa)
#   portal: hover 0..1 (il velo si apre) trampoline: bounce 0..1 (salto, poi torna a 0)
#   gong_material: strike 0..1 (colpo)   sprite: flash 0..1, gild 0..1, flip_h 0/1
#   Tutti: motion (velocità delle animazioni; set_calm() la abbassa per "meno scossa e lampi").
#
# PRESTAZIONI: ogni materiale costa solo ALU (niente texture, salvo anteprime e schermi). Sui telefoni
# lenti metti HallMaterials.lite = true PRIMA di creare i materiali: tolgono le ottave di rumore e le trame
# fini. I materiali additivi (fasci, aloni, ologrammi) costano per area: meglio pochi e non a tutto schermo.
class_name HallMaterials
extends RefCounted

const BANANA := Color(1.0, 0.84, 0.18)
const GOLD := Color(1.0, 0.68, 0.24)
const PURPLE := Color(0.45, 0.22, 0.95)
const NAVY := Color(0.03, 0.025, 0.08)
const CYAN := Color(0.3, 0.85, 1.0)
const SPRITE_PAD := 0.08 # quota del quad del lottatore per lato fuori dal fotogramma: posto per contorno e alone
const CALM_MOTION := 0.3 # con "meno scossa e lampi" le animazioni vanno a un terzo della velocità

static var lite := false # versione leggera degli shader: da mettere prima di creare i materiali
static var _made: Array[WeakRef] = [] # i materiali creati, per cambiare motion a tutti con set_calm()


# load() tiene già in cache lo shader: cento materiali dello stesso tipo ne compilano uno solo
static func _shader(name: String) -> Shader:
	return load("res://shaders/hall_mat_%s.gdshader" % name)


static func _mat(name: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	m.set_shader_parameter("motion", motion_scale())
	if lite:
		m.set_shader_parameter("detail", 0.0)
	_made.append(weakref(m))
	return m


static func _vec3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


# Velocità delle animazioni: piena, o ridotta con "meno scossa e lampi" (Access.calm)
static func motion_scale() -> float:
	return CALM_MOTION if Access.calm else 1.0


# Da chiamare quando cambia Access.calm: aggiorna tutti i materiali vivi
static func set_calm(on: bool) -> void:
	var k := CALM_MOTION if on else 1.0
	var alive: Array[WeakRef] = []
	for w in _made:
		var m: ShaderMaterial = w.get_ref()
		if m != null:
			m.set_shader_parameter("motion", k)
			alive.append(w)
	_made = alive


# ---------------------------------------------------------------- superfici della sala

# Pavimento: marmo nero-viola lucido con intarsi d'oro che si accendono a onde dal centro.
# tile_size in m; medallion_radius > 0 disegna il rosone a stella in medallion_center (xz del mondo).
static func floor_material(tile_size := 2.0, medallion_radius := 0.0, medallion_center := Vector2.ZERO) -> ShaderMaterial:
	return _mat("floor", {"tile_size": tile_size, "medallion_radius": medallion_radius, "medallion_center": medallion_center})


# Marmo senza intarsi per piedistalli, gradini e la pedana del trono. light = marmo chiaro con vene d'oro.
static func marble(light := false) -> ShaderMaterial:
	if light:
		return _mat("floor", {"inlay": 0.0, "base_a": Color(0.78, 0.74, 0.7), "base_b": Color(0.86, 0.83, 0.8),
			"vein_color": Color(0.85, 0.62, 0.25), "vein_strength": 0.9, "vein_scale": 1.0, "polish": 0.6})
	return _mat("floor", {"inlay": 0.0, "vein_scale": 1.2, "vein_strength": 1.3})


# Pareti: pannelli esagonali in carbonio indaco, qualche cella col filo acceso, una lama di luce che scorre.
static func wall_material(accent := PURPLE, hex_size := 0.55) -> ShaderMaterial:
	return _mat("wall", {"accent": accent, "hex_size": hex_size})


# ---------------------------------------------------------------- metalli

# box_edges = true se va su una BoxMesh: gli spigoli brillano come smussi lucidati
static func trim_gold(box_edges := false) -> ShaderMaterial:
	return _mat("metal", {"tint": GOLD, "roughness": 0.28, "brush": 0.45, "reflect_strength": 0.9, "edge_grid": _box_grid(box_edges)})


static func _box_grid(on: bool) -> Vector2:
	return Vector2(3, 2) if on else Vector2.ZERO # BoxMesh mette le sei facce in una griglia di UV 3 x 2


static func metal(box_edges := false) -> ShaderMaterial:
	return _mat("metal", {"tint": Color(0.62, 0.64, 0.72), "roughness": 0.32, "edge_grid": _box_grid(box_edges)})


# Metallo scuro per cornici di schermi, sbarre e basi: acciaio brunito quasi nero
static func dark_metal(box_edges := false) -> ShaderMaterial:
	return _mat("metal", {"tint": Color(0.2, 0.19, 0.26), "roughness": 0.35, "shine": 0.6, "edge_grid": _box_grid(box_edges)})


# Gong: bronzo martellato coi cerchi del tornio sulle UV; strike 0..1 lo accende quando lo colpiscono
# radius: raggio del disco in m. I cerchi girano attorno all'asse Y della mesh (un CylinderMesh basso, ruotato).
static func gong_material(radius := 1.0) -> ShaderMaterial:
	return _mat("metal", {"tint": Color(0.85, 0.48, 0.18), "roughness": 0.25, "hammered": 0.5, "rings": 1.0, "ring_radius": radius,
		"brush": 0.0, "reflect_strength": 0.8, "bands": 0.25})


# ---------------------------------------------------------------- luci

# Neon: tubo acceso. chase > 0 fa correre le luci lungo UV.x (insegne, bordi delle pedane).
static func neon(color: Color, intensity := 2.2, chase := 0.0) -> ShaderMaterial:
	return _mat("neon", {"color": color, "intensity": intensity, "chase": chase})


# Ologramma additivo (gabbia dei bot, teletrasporto, scritte sospese). fade_top: sfuma verso UV.y = 0.
static func hologram(color := CYAN, fade_top := 1.0) -> ShaderMaterial:
	return _mat("hologram", {"color": color, "fade_top": fade_top})


static func god_rays(color := Color(1.0, 0.88, 0.6), intensity := 0.16) -> ShaderMaterial:
	return _mat("rays", {"color": color, "intensity": intensity})


# Alone additivo sempre rivolto alla telecamera: il bloom finto dietro neon, statue e trono
static func crowd_glow(color := GOLD, intensity := 0.8) -> ShaderMaterial:
	return _mat("glow", {"color": color, "intensity": intensity})


static func light_pool_material(color := GOLD, intensity := 0.5) -> ShaderMaterial:
	return _mat("glow", {"color": color, "intensity": intensity, "billboard": 0.0, "on_floor": 1.0, "falloff": 1.2, "shimmer": 0.1})


static func shadow_material(strength := 0.65) -> ShaderMaterial:
	return _shadow_mat(strength)


static func _shadow_mat(strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("shadow")
	m.set_shader_parameter("strength", strength)
	return m


# ---------------------------------------------------------------- oggetti della sala

static func pad_material(color: Color) -> ShaderMaterial:
	return _mat("pad", {"color": color, "phase": randf() * 10.0})


static func portal_material(preview: Texture2D, color := PURPLE, aspect := 0.62) -> ShaderMaterial:
	var m := _mat("portal", {"color": color, "aspect": aspect, "has_preview": 1.0 if preview != null else 0.0})
	if preview != null:
		m.set_shader_parameter("preview", preview)
		m.set_shader_parameter("preview_aspect", float(preview.get_width()) / maxf(1.0, float(preview.get_height())))
	return m


static func ready_ring_material() -> ShaderMaterial:
	return _mat("ready")


static func trampoline_material(color := BANANA) -> ShaderMaterial:
	return _mat("trampoline", {"color": color})


# Schermo a LED: tex può essere la ViewportTexture di un SubViewport (classifica, tabellone).
# led_count: quanti led per lato (più alto = più nitido); null = animazione d'attesa.
static func screen_material(tex: Texture2D, led_count := Vector2(192, 108)) -> ShaderMaterial:
	var m := _mat("screen", {"led_count": led_count, "has_tex": 1.0 if tex != null else 0.0})
	if tex != null:
		m.set_shader_parameter("screen_tex", tex)
	return m


# Velluto per tende e drappi; banner_material per gli stendardi con lo stemma; cushion per il trono
static func velvet(color: Color) -> ShaderMaterial:
	return _mat("velvet", {"color": color, "trim": 0.0, "sway": 0.3})


# aspect = altezza / larghezza dello stendardo, perché lo stemma non esca schiacciato
static func banner_material(color: Color, crest := true, aspect := 2.6) -> ShaderMaterial:
	return _mat("velvet", {"color": color, "crest": 1.0 if crest else 0.0, "swallowtail": 1.0, "fold_count": 3.0, "aspect": aspect})


static func cushion_material(color := Color(0.55, 0.06, 0.12)) -> ShaderMaterial:
	return _mat("velvet", {"color": color, "tufted": 1.0, "trim": 0.0, "sway": 0.0, "folds": 0.0})


static func backdrop_material() -> ShaderMaterial:
	return _mat("backdrop")


# Lottatore 2D: billboard dritto con contorno e alone nel colore del giocatore. nearest per la pixel art.
static func sprite_rim_material(tex: Texture2D, outline_color := BANANA, nearest := false) -> ShaderMaterial:
	return _mat("sprite_nearest" if nearest else "sprite", {"sprite_tex": tex, "outline_color": outline_color, "pad": SPRITE_PAD})


# Sceglie il fotogramma: frame in una griglia di columns colonne (row si somma in righe intere)
static func set_sprite_frame(m: ShaderMaterial, frame: int, frame_w: int, frame_h: int, columns: int, row := 0) -> void:
	var tex: Texture2D = m.get_shader_parameter("sprite_tex")
	if tex == null or columns <= 0:
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var col := frame % columns
	var r := row + frame / columns
	m.set_shader_parameter("frame_rect", Vector4(col * frame_w / w, r * frame_h / h, frame_w / w, frame_h / h))


static func env(glow := true) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.015, 0.012, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.34, 0.62)
	e.ambient_light_energy = 0.45
	# niente cielo da riflettere: i riflessi li fingono gli shader (hall_env), così costa zero
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = glow
	e.glow_intensity = 0.7
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.07, 0.22)
	e.fog_light_energy = 1.0
	e.fog_density = 0.012
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.1
	e.adjustment_contrast = 1.05
	return e


# ---------------------------------------------------------------- mesh pronte (materiale compreso)

static func _inst(mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _plane(size: float, subdiv := 0) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(size, size)
	p.subdivide_width = subdiv
	p.subdivide_depth = subdiv
	return p


# Pedana a terra: diametro del disco in m (il quad è più largo per l'alone). Alzala di 1-2 cm sul pavimento.
static func pad(color: Color, diameter := 2.4) -> MeshInstance3D:
	return _inst(_plane(diameter / 0.8), pad_material(color))


static func ready_ring(diameter := 3.0) -> MeshInstance3D:
	return _inst(_plane(diameter), ready_ring_material())


# Il telo si abbassa con bounce: per questo il piano è suddiviso. Il bordo imbottito è nel 20% esterno.
static func trampoline(diameter := 2.0, color := BANANA) -> MeshInstance3D:
	var mi := _inst(_plane(diameter, 16), trampoline_material(color))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# Portale: quad verticale che guarda +z con la base all'origine; l'arco riempie il quad meno il 6% di bordo
static func portal(preview: Texture2D, width := 2.2, height := 3.4, color := PURPLE) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(width, height)
	q.center_offset = Vector3(0, height / 2.0, 0)
	return _inst(q, portal_material(preview, color, width / height))


# Fascio di luce: origine sulla lampada, il cono scende lungo -y (ruotalo per inclinarlo)
static func god_ray(length := 6.0, top_radius := 0.15, bottom_radius := 1.6, color := Color(1.0, 0.88, 0.6)) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top_radius
	c.bottom_radius = bottom_radius
	c.height = length
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 24
	c.rings = 1
	# il cilindro di Godot ha l'origine a metà: lo abbasso così l'origine è sulla lampada
	var arrays := c.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].y -= length / 2.0
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _inst(mesh, god_rays(color))


static func halo(color := GOLD, size := 1.5, intensity := 0.8) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return _inst(q, crowd_glow(color, intensity))


static func light_pool(color := GOLD, diameter := 3.0, intensity := 0.5) -> MeshInstance3D:
	return _inst(_plane(diameter), light_pool_material(color, intensity))


# Riflesso di una luce sul pavimento lucido: una scia che parte dall'origine (mettila alla base di portali,
# schermi, neon, 1-2 cm sopra il pavimento) e si gira da sola verso la telecamera. width e length in m.
static func floor_reflection(color: Color, width := 2.0, length := 4.0, intensity := 0.6) -> MeshInstance3D:
	var p := PlaneMesh.new()
	p.size = Vector2(width, length)
	p.center_offset = Vector3(0, 0, length / 2.0)
	var m := _mat("glow", {"color": color, "intensity": intensity, "billboard": 0.0, "streak": 1.0, "falloff": 1.0, "shimmer": 0.2})
	return _inst(p, m)


static func blob_shadow(width := 0.9, depth := 0.35, strength := 0.65) -> MeshInstance3D:
	var p := PlaneMesh.new()
	p.size = Vector2(width, depth)
	return _inst(p, _shadow_mat(strength))


static func backdrop(radius := 120.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 32
	s.rings = 16
	var mi := _inst(s, backdrop_material())
	mi.extra_cull_margin = radius
	return mi


# Lottatore 2D. frame_size in px, foot_y in px dall'alto del fotogramma (data: sprite.footY, o l'altezza),
# pixel_size in m per pixel. L'origine del nodo è ai piedi; il quad è più grande del pad per il contorno.
static func fighter(tex: Texture2D, frame_size: Vector2, foot_y: float, pixel_size := 0.006, outline_color := BANANA, columns := 0, nearest := false) -> MeshInstance3D:
	var m := sprite_rim_material(tex, outline_color, nearest)
	var q := QuadMesh.new()
	var size := frame_size * pixel_size
	q.size = size / (1.0 - 2.0 * SPRITE_PAD)
	# i piedi (foot_y px dall'alto) all'origine: il centro del quad sale di quanto il fotogramma sta sopra i piedi
	q.center_offset = Vector3(0, foot_y * pixel_size - size.y / 2.0, 0)
	if tex != null:
		var cols := columns if columns > 0 else maxi(1, int(tex.get_width() / frame_size.x))
		set_sprite_frame(m, 0, int(frame_size.x), int(frame_size.y), cols)
	return _inst(q, m)
