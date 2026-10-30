# Materiali della sala d'attesa (hall_materials.gd): ogni materiale si crea con il suo shader, le mesh
# pronte hanno l'origine dove dice l'intestazione, "meno scossa e lampi" rallenta tutto, la versione leggera
# spegne i dettagli. La resa la guarda la CI negli screenshot; qui si controlla il contratto con hall_view.
extends RefCounted

var runner


func _all() -> Dictionary:
	var tex := ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	return {
		"floor": HallMaterials.floor_material(2.0, 3.0),
		"marble": HallMaterials.marble(),
		"marble_light": HallMaterials.marble(true),
		"wall": HallMaterials.wall_material(),
		"gold": HallMaterials.trim_gold(true),
		"metal": HallMaterials.metal(),
		"dark_metal": HallMaterials.dark_metal(),
		"gong": HallMaterials.gong_material(1.2),
		"neon": HallMaterials.neon(HallMaterials.BANANA, 2.0, 1.0),
		"hologram": HallMaterials.hologram(),
		"rays": HallMaterials.god_rays(),
		"glow": HallMaterials.crowd_glow(),
		"pool": HallMaterials.light_pool_material(),
		"shadow": HallMaterials.shadow_material(),
		"pad": HallMaterials.pad_material(Color.RED),
		"portal": HallMaterials.portal_material(tex),
		"portal_empty": HallMaterials.portal_material(null),
		"ready": HallMaterials.ready_ring_material(),
		"trampoline": HallMaterials.trampoline_material(),
		"screen": HallMaterials.screen_material(tex),
		"screen_idle": HallMaterials.screen_material(null),
		"velvet": HallMaterials.velvet(Color.PURPLE),
		"banner": HallMaterials.banner_material(Color.PURPLE),
		"cushion": HallMaterials.cushion_material(),
		"backdrop": HallMaterials.backdrop_material(),
		"sprite": HallMaterials.sprite_rim_material(tex),
		"sprite_pixel": HallMaterials.sprite_rim_material(tex, Color.RED, true),
		"court": HallMaterials.court_material(Vector2(10, 9)),
		"chessboard": HallMaterials.chessboard_material(),
		"square": HallMaterials.chess_square_material(true),
		"chess_white": HallMaterials.chess_material("white"),
		"chess_black": HallMaterials.chess_material("black", 0.2),
		"basketball": HallMaterials.basketball_material(),
		"beachball": HallMaterials.beachball_material(),
		"net": HallMaterials.net_material(),
		"glass": HallMaterials.glass_material(),
		"rim": HallMaterials.rim_material(),
	}


func test_ogni_materiale_ha_il_suo_shader() -> void:
	var mats := _all()
	for k in mats:
		var m: ShaderMaterial = mats[k]
		runner.check(m != null and m.shader != null, "%s: niente shader" % k)
		if m == null or m.shader == null:
			continue
		runner.check(m.shader.resource_path.begins_with("res://shaders/hall_mat_"), "%s: %s" % [k, m.shader.resource_path])
		runner.check(m.shader.code.contains("shader_type spatial"), "%s: non è uno shader 3D" % k)
	runner.check(mats.sprite_pixel.shader != mats.sprite.shader, "la pixel art usa lo shader col filtro nearest")
	runner.check(mats.portal.get_shader_parameter("preview_aspect") == 2.0, "anteprima 64x32: aspect 2")
	runner.check(mats.portal_empty.get_shader_parameter("has_preview") == 0.0, "portale senza anteprima")
	runner.check(mats.screen_idle.get_shader_parameter("has_tex") == 0.0, "schermo senza immagine: attesa")
	runner.check(mats.chess_black.get_shader_parameter("black") == 1.0 and mats.chess_white.get_shader_parameter("black") == 0.0, "pezzi bianchi e neri")
	runner.check(mats.court.get_shader_parameter("court_size") == Vector2(10, 9), "righe del campo sulla sua misura")


# Ogni shader animato ha l'uniform motion (meno movimento) e include le funzioni comuni senza errori di percorso
func test_shader_della_sala() -> void:
	var dir := DirAccess.open("res://shaders")
	var n := 0
	for f in dir.get_files():
		if not (f.begins_with("hall_mat_") and f.ends_with(".gdshader")):
			continue
		n += 1
		var s: Shader = load("res://shaders/" + f)
		runner.check(s != null and s.code != "", "%s non si carica" % f)
		if s == null:
			continue
		if f != "hall_mat_shadow.gdshader":
			var code := s.code
			if code.contains("hall_mat_sprite.gdshaderinc"):
				code += FileAccess.get_file_as_string("res://shaders/hall_mat_sprite.gdshaderinc")
			runner.check(code.contains("uniform float motion"), "%s: manca motion" % f)
		for line in s.code.split("\n"):
			if line.begins_with("#include"):
				var path := line.get_slice("\"", 1)
				runner.check(FileAccess.file_exists(path), "%s include %s che non c'è" % [f, path])
	runner.check(n >= 15, "shader della sala: %d" % n)


func test_mesh_pronte_con_l_origine_giusta() -> void:
	var pad := HallMaterials.pad(Color.YELLOW, 2.4)
	runner.check(is_equal_approx((pad.mesh as PlaneMesh).size.x, 3.0), "pedana: il quad è il disco più l'alone")
	var portal := HallMaterials.portal(null, 2.0, 3.0)
	var pa := portal.mesh.get_aabb()
	runner.check(is_equal_approx(pa.position.y, 0.0) and is_equal_approx(pa.end.y, 3.0), "portale: base all'origine %s" % pa)
	runner.check(is_equal_approx(portal.material_override.get_shader_parameter("aspect"), 2.0 / 3.0), "portale: aspect")
	var ray := HallMaterials.god_ray(6.0, 0.1, 1.5)
	var ra := ray.mesh.get_aabb()
	runner.check(absf(ra.end.y) < 0.01 and absf(ra.position.y + 6.0) < 0.01, "faro: dalla lampada in giù %s" % ra)
	var refl := HallMaterials.floor_reflection(Color.WHITE, 1.0, 4.0)
	var fa := refl.mesh.get_aabb()
	runner.check(absf(fa.position.z) < 0.01 and absf(fa.end.z - 4.0) < 0.01, "riflesso: parte dall'origine %s" % fa)
	var net := HallMaterials.hoop_net(0.23, 0.45)
	var na := net.mesh.get_aabb()
	runner.check(absf(na.end.y) < 0.01 and absf(na.position.y + 0.45) < 0.01, "retina: dal ferro in giù %s" % na)
	for mi in [net, HallMaterials.court(), HallMaterials.chessboard(), pad, portal, ray, refl, HallMaterials.halo(), HallMaterials.light_pool(), HallMaterials.blob_shadow(), HallMaterials.ready_ring(), HallMaterials.trampoline(), HallMaterials.backdrop()]:
		runner.check(mi is MeshInstance3D and mi.material_override is ShaderMaterial, "mesh pronta col materiale")
		mi.free()


func test_lottatore_coi_piedi_all_origine() -> void:
	var tex := ImageTexture.create_from_image(Image.create(400, 100, false, Image.FORMAT_RGBA8))
	var f := HallMaterials.fighter(tex, Vector2(100, 100), 80.0, 0.01)
	var q := f.mesh as QuadMesh
	# il fotogramma è 1 m; i piedi a 80 px dall'alto: il centro del fotogramma sta 0,3 m sopra i piedi
	runner.check(is_equal_approx(q.center_offset.y, 0.3), "centro: %s" % q.center_offset)
	var frame_h := q.size.y * (1.0 - 2.0 * HallMaterials.SPRITE_PAD)
	runner.check(is_equal_approx(frame_h, 1.0), "il quad lascia spazio al contorno: %s" % q.size)
	var m: ShaderMaterial = f.material_override
	runner.check(m.get_shader_parameter("frame_rect") == Vector4(0, 0, 0.25, 1), "primo fotogramma: %s" % m.get_shader_parameter("frame_rect"))
	HallMaterials.set_sprite_frame(m, 3, 100, 100, 4)
	runner.check(m.get_shader_parameter("frame_rect") == Vector4(0.75, 0, 0.25, 1), "quarto: %s" % m.get_shader_parameter("frame_rect"))
	f.free()


func test_meno_movimento_e_versione_leggera() -> void:
	var was := Access.calm
	Access.calm = false
	var a := HallMaterials.pad_material(Color.RED)
	runner.check(a.get_shader_parameter("motion") == 1.0, "movimento pieno")
	HallMaterials.set_calm(true)
	runner.check(a.get_shader_parameter("motion") == HallMaterials.CALM_MOTION, "set_calm rallenta i materiali già fatti")
	HallMaterials.set_calm(false)
	runner.check(a.get_shader_parameter("motion") == 1.0, "e li riporta")
	Access.calm = true
	runner.check(HallMaterials.wall_material().get_shader_parameter("motion") == HallMaterials.CALM_MOTION, "nuovi materiali già lenti")
	Access.calm = was
	HallMaterials.lite = true
	runner.check(HallMaterials.floor_material().get_shader_parameter("detail") == 0.0, "versione leggera")
	HallMaterials.lite = false
	runner.check(HallMaterials.floor_material().get_shader_parameter("detail") != 0.0, "dettagli pieni")


func test_ambiente() -> void:
	var e := HallMaterials.env()
	runner.check(e.glow_enabled and e.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "bagliore e tonemap")
	runner.check(e.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED, "riflessi finti negli shader")
	runner.check(not HallMaterials.env(false).glow_enabled, "senza bagliore sui telefoni lenti")
