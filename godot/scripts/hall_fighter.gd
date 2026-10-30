# Un giocatore nella sala d'attesa 3D: il suo lottatore 2D in piedi nel mondo, come una figurina (Paper Mario),
# girato sempre verso la telecamera. Sotto i piedi l'ombra e l'anello del suo colore; sopra il nome, la corona
# di chi ha creato la stanza, la spunta dei pronti. Bonobo, che non ha disegno, è un cubo rosso con gli occhi.
# Disegna e basta: dove sta e cosa fa lo dice lo snapshot (hall_view.gd).
extends Node3D

const FighterPose := preload("res://scripts/fighter_pose.gd")
const HallIcons := preload("res://scripts/hall_icons.gd")

const PX := 0.022 # metri per pixel di mondo del gioco: un lottatore da 96 px è alto circa 2,1 m
const CM := 0.01 # metri per centimetro dello snapshot
const TAG_PX := 0.005 # metri per pixel delle scritte sopra la testa
const BONOBO_RED := Color("e74c3c") # il rettangolo rosso del gioco
const VOICE_GREEN := Color("3ba55d") # il verde di chi parla, come su Discord

# PNG già caricati, per tutta la sala: ogni striscia si legge dal disco una volta sola (sul web il caricamento blocca)
static var _textures := {}

var game: Dictionary
var id := ""
var head := 1.9 # altezza della testa da terra, metri
var me := false

var _look: Dictionary = {}
var _look_key := "-"
var _pivot: Node3D # ai piedi, ruota verso la telecamera
var _quad: MeshInstance3D
var _mats := {} # texture -> materiale: uno per striscia, si cambia solo il riquadro del fotogramma
var _outline := Color.WHITE # il contorno del lottatore, nel colore del giocatore
var _charge_ring: MeshInstance3D # il cerchio che si riempie sotto chi si ferma su una pedana per votare
var charge := 0.0 # da 0 a 1, lo decide hall_view.gd
var charge_color := Color.WHITE
var _box: Node3D # Bonobo senza disegno
var _eyes: Node3D
var _shadow: MeshInstance3D
var _ring: MeshInstance3D
var _ring_color := Color.WHITE
var _tag: Label3D
var _crown: Node3D
var _check: Sprite3D
var _marker: MeshInstance3D # la freccia sopra la propria testa
var _stars: Node3D # stordito dopo una spinta
var _throne_crown: Node3D
var _anim := ""
var _anim_since := 0.0
var _pop := 0.0 # 1 = appena cambiato lottatore: cresce di colpo e torna
var _squash := 0.0 # atterraggio e rimbalzo: si schiaccia e torna
var _t := 0.0
var _host := false
var _ready_shown := false
# Scritte sopra la testa: hall_view.gd le alza quando si accavallano con quelle vicine e spegne quelle lontane
var tag_lift := 0.0 # metri in più sopra la testa, deciso da hall_view (si arriva piano)
var tag_lift_target := 0.0
var tag_fade := 1.0 # 0..1
var _tag_row: Node3D # gira con la telecamera: l'icona della voce a sinistra del nome, i canestri a destra
var _tag_w := 0.0 # metri, larghezza del nome
var _baskets := 0
var _badge: Node3D
var _badge_count: Label3D
# Chat vocale (come Discord): anello verde sotto i piedi mentre parla, icona sopra la testa
var speaking := false
var voice_muted := false
var _voice_ring: MeshInstance3D
var _voice_icon: Sprite3D
var _voice_glow := 0.0


func setup(game_data: Dictionary, p: Dictionary, mine: bool) -> void:
	game = game_data
	id = str(p.get("id", ""))
	me = mine
	_pivot = Node3D.new()
	add_child(_pivot)
	_shadow = HallMaterials.blob_shadow(1.2, 0.55, 0.7)
	_shadow.position.y = 0.012
	add_child(_shadow)
	_charge_ring = HallMaterials.ready_ring(1.5)
	_charge_ring.position.y = 0.03
	_charge_ring.visible = false
	add_child(_charge_ring)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.6
	torus.rings = 24
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.12, 1)
	_ring.position.y = 0.02
	add_child(_ring)
	_tag = Label3D.new()
	_tag.font = UI.font(UI.WEIGHT_BOLD)
	_tag.font_size = 50
	_tag.pixel_size = TAG_PX
	_tag.outline_size = 14
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.render_priority = 10
	_tag.outline_render_priority = 9
	add_child(_tag)
	_tag_row = Node3D.new()
	_tag_row.name = "TagRow"
	add_child(_tag_row)
	_crown = crown(0.3)
	_crown.visible = false
	add_child(_crown)
	_check = Sprite3D.new()
	_check.texture = HallIcons.check()
	_check.pixel_size = 0.0055
	_check.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_check.no_depth_test = true
	_check.render_priority = 11
	_check.visible = false
	add_child(_check)
	if me:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.16
		cone.bottom_radius = 0.0
		cone.height = 0.3
		cone.radial_segments = 4
		cone.rings = 1
		_marker = MeshInstance3D.new()
		_marker.mesh = cone
		_marker.material_override = HallMaterials.neon(UI.ACCENT)
		add_child(_marker)
	_stars = Node3D.new()
	for i in 3:
		var s := Sprite3D.new()
		s.texture = HallIcons.sparkle()
		s.pixel_size = 0.005
		s.modulate = UI.ACCENT
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_stars.add_child(s)
	_stars.visible = false
	add_child(_stars)
	_voice_ring = MeshInstance3D.new()
	var vt := TorusMesh.new()
	vt.inner_radius = 0.6
	vt.outer_radius = 0.7
	vt.rings = 32
	vt.ring_segments = 4
	_voice_ring.mesh = vt
	_voice_ring.material_override = HallMaterials.neon(VOICE_GREEN, 3.0)
	_voice_ring.position.y = 0.03
	_voice_ring.visible = false
	add_child(_voice_ring)
	_voice_icon = Sprite3D.new()
	_voice_icon.pixel_size = 0.0042
	_voice_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_voice_icon.no_depth_test = true
	_voice_icon.render_priority = 11
	_voice_icon.visible = false
	_tag_row.add_child(_voice_icon)
	apply(p, 0.0, 0.0, 0.0)


# Lo stato da disegnare (già interpolato), l'ora in ms, l'angolo della telecamera attorno a y, il tempo passato
func apply(p: Dictionary, now: float, cam_yaw: float, delta: float) -> void:
	_t += delta
	var key := "%s/%s" % [p.get("characterId", ""), FighterPose.skin_of(p)]
	if key != _look_key:
		_set_look(key, p)
	position = Vector3(float(p.get("x", 0.0)), 0.0, float(p.get("z", 0.0))) * CM
	var lift := maxf(0.0, float(p.get("y", 0.0))) * CM
	_pivot.position.y = lift
	# sul trono si sta seduti in alto sul cuscino, un po' indietro (solo disegno: per il server si è a terra)
	if p.get("throne", false):
		_pivot.position.y += 0.55
		_pivot.position.z = -0.2
	else:
		_pivot.position.z = 0.0
	_pivot.rotation.y = cam_yaw
	var facing := -1.0 if int(p.get("facing", 1)) < 0 else 1.0
	var alpha := FighterPose.away_alpha(p)
	_pop = maxf(0.0, _pop - delta * 3.0)
	_squash = maxf(0.0, _squash - delta * 4.0)
	var anim := _anim_of(p)
	if anim != _anim:
		_anim = anim
		_anim_since = now
	# un po' di elasticità: salto allungato, atterraggio schiacciato, cambio di lottatore che "fa pop"
	var stretch := 1.0
	if anim == "jump":
		stretch = 1.06
	var squash := sin(_squash * PI) * 0.18
	var pop := sin(_pop * PI) * 0.35
	var sx := (1.0 + squash + pop) / stretch
	var sy := (1.0 - squash + pop) * stretch
	if p.get("throne", false):
		sy *= 0.93 # seduto
	if _box != null:
		_animate_box(p, anim, facing, sx, sy, alpha)
	elif _quad != null:
		_quad.scale = Vector3(sx, sy, 1.0)
		_show_frame(anim, now, alpha, facing)
	# ombra: più piccola e chiara più si è in alto
	var k := clampf(1.0 - lift / 4.0, 0.25, 1.0)
	_shadow.scale = Vector3(k, 1.0, k)
	_param(_shadow.material_override, "strength", 0.7 * k * alpha)
	var col := Access.color(p.get("color", 0xe74c3c))
	if col != _ring_color:
		_ring_color = col
		_ring.material_override = HallMaterials.neon(col, 2.6)
		_tag.outline_modulate = col.darkened(0.55)
		_outline = col
		for m in _mats.values():
			_param(m, "outline_color", col)
	_charge_ring.visible = charge > 0.01
	if _charge_ring.visible:
		_param(_charge_ring.material_override, "fill", charge)
		_param(_charge_ring.material_override, "color", charge_color)
	var pulse := 1.0 + sin(_t * 4.0) * 0.04 if me else 1.0
	_ring.scale = Vector3(pulse, 0.12, pulse)
	_ring.visible = alpha > 0.5
	# scritte sopra la testa
	var tag: String = str(p.get("name", ""))
	if p.get("bot", false):
		tag += " · BOT"
	if p.get("away", false):
		tag += " · via"
	if tag != _tag.text:
		_tag.text = tag
		_tag_w = _tag.font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _tag.font_size).x * _tag.pixel_size if _tag.font != null else 0.0
	tag_lift = move_toward(tag_lift, tag_lift_target, delta * 6.0)
	var shown := alpha * tag_fade
	_tag.modulate = Color(1, 1, 1, shown)
	_tag.outline_modulate.a = shown
	var top := _pivot.position.y + head + 0.35 + tag_lift
	_tag.position.y = top
	_tag_row.position.y = top
	_tag_row.rotation.y = cam_yaw
	_update_badge(int(p.get("baskets", 0)), shown)
	_update_voice(delta, shown)
	_host = bool(p.get("host", false))
	_crown.visible = _host and not p.get("throne", false)
	_crown.position.y = top + 0.32
	_crown.rotation.y = _t * 1.5
	var is_ready := bool(p.get("ready", false))
	if is_ready and not _ready_shown:
		_check.scale = Vector3.ONE * 1.8 # entra grande e si assesta
	_ready_shown = is_ready
	_check.visible = is_ready
	_check.scale = _check.scale.lerp(Vector3.ONE, minf(1.0, delta * 10.0))
	_check.position = Vector3(0.0, top + (0.62 if _crown.visible else 0.36), 0.0)
	_check.modulate.a = tag_fade
	if _marker != null:
		_marker.position.y = top + (0.95 if _crown.visible or is_ready else 0.6) + sin(_t * 5.0) * 0.08
		_marker.rotation.y = _t * 2.0
	_stars.visible = float(p.get("stunMs", 0.0)) > 0.0 or (p.get("away", false))
	if _stars.visible:
		for i in _stars.get_child_count():
			var a := _t * 5.0 + i * TAU / 3.0
			_stars.get_child(i).position = Vector3(cos(a) * 0.45, _pivot.position.y + head + 0.05 + sin(a * 2.0) * 0.05, sin(a) * 0.45)
	var throne := bool(p.get("throne", false))
	if throne and _throne_crown == null:
		_throne_crown = crown(0.55)
		add_child(_throne_crown)
	if _throne_crown != null:
		_throne_crown.visible = throne
		_throne_crown.position.y = _pivot.position.y + head + 0.15 + sin(_t * 2.5) * 0.06
		_throne_crown.rotation.y = _t * 0.8


# Quanto è alto da terra il punto sopra la testa, metri: per gli effetti
func top_height() -> float:
	return _pivot.position.y + head


# Il nome sopra la testa: dove sta senza spostamenti (metri da terra) e quanto è largo, per non accavallarli
func tag_base_height() -> float:
	return _pivot.position.y + head + 0.35


func tag_size() -> Vector2:
	var extra := (0.5 if _badge != null and _badge.visible else 0.0) + (0.4 if _voice_icon.visible else 0.0)
	return Vector2(_tag_w + extra, _tag.font_size * _tag.pixel_size * 1.1)


# Metri occupati sopra il nome (spunta dei pronti, corona): contano anche loro per non accavallarsi
func tag_above() -> float:
	if _check.visible:
		return 0.62 if _crown.visible else 0.4
	return 0.3 if _crown.visible else 0.0


func tag_node() -> Label3D:
	return _tag


func set_voice(is_speaking: bool, is_muted: bool) -> void:
	speaking = is_speaking and not is_muted
	voice_muted = is_muted


# Canestri fatti in questa sala: il pallino arancione col numero a destra del nome
func _update_badge(n: int, shown: float) -> void:
	if n > 0 and _badge == null:
		_badge = Node3D.new()
		var ball := Sprite3D.new()
		ball.texture = HallIcons.basketball()
		ball.pixel_size = 0.0048
		ball.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ball.no_depth_test = true
		ball.render_priority = 11
		_badge.add_child(ball)
		_badge_count = Label3D.new()
		_badge_count.font = UI.font(UI.WEIGHT_BOLD)
		_badge_count.font_size = 40
		_badge_count.pixel_size = TAG_PX
		_badge_count.outline_size = 12
		_badge_count.outline_modulate = Color(0.25, 0.08, 0.0)
		_badge_count.modulate = Color("ffb04a")
		_badge_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_badge_count.no_depth_test = true
		_badge_count.render_priority = 12
		_badge_count.outline_render_priority = 11
		_badge_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_badge_count.position.x = 0.17
		_badge.add_child(_badge_count)
		_tag_row.add_child(_badge)
	if _badge == null:
		return
	_badge.visible = n > 0
	if n != _baskets and n > _baskets:
		_badge.scale = Vector3.ONE * 1.8 # un canestro in più: il pallino salta
	_baskets = n
	_badge_count.text = str(n)
	_badge.position.x = _tag_w / 2.0 + 0.16
	_badge.scale = _badge.scale.lerp(Vector3.ONE, 0.12)
	_badge_count.modulate.a = shown
	_badge_count.outline_modulate.a = shown
	(_badge.get_child(0) as Sprite3D).modulate.a = shown


func _update_voice(delta: float, shown: float) -> void:
	_voice_glow = move_toward(_voice_glow, 1.0 if speaking else 0.0, delta * (8.0 if speaking else 3.0))
	_voice_ring.visible = _voice_glow > 0.01
	if _voice_ring.visible:
		var pulse := 1.0 + sin(_t * 9.0) * 0.06 * _voice_glow
		_voice_ring.scale = Vector3(pulse, 0.15, pulse)
		_param(_voice_ring.material_override, "intensity", 3.2 * _voice_glow)
	_voice_icon.visible = speaking or voice_muted
	if _voice_icon.visible:
		var tex := HallIcons.muted() if voice_muted else HallIcons.speaker()
		if _voice_icon.texture != tex:
			_voice_icon.texture = tex
		_voice_icon.position.x = -(_tag_w / 2.0 + 0.16)
		_voice_icon.scale = Vector3.ONE * (1.0 + (sin(_t * 10.0) * 0.08 if speaking else 0.0))
		_voice_icon.modulate.a = shown


func pop() -> void:
	_pop = 1.0


func squash() -> void:
	_squash = 1.0


func _anim_of(p: Dictionary) -> String:
	if not p.get("onGround", true):
		return "jump" if float(p.get("vy", 0.0)) > 0.0 else "fall"
	if p.get("emote", false):
		return "taunt"
	if p.get("moving", false) and not p.get("throne", false):
		return "walk"
	return "idle"


func _set_look(key: String, p: Dictionary) -> void:
	_look_key = key
	_look = FighterPose.look(game, str(p.get("characterId", "")), FighterPose.skin_of(p))
	if _quad != null:
		_quad.queue_free()
		_quad = null
	if _box != null:
		_box.queue_free()
		_box = null
	_mats.clear()
	_anim = ""
	var hb: Variant = _look.get("hurtbox")
	head = float(hb.get("height", 96.0) if hb is Dictionary else game.get("fighter", {}).get("height", 88.0)) * PX
	var sp: Variant = _look.get("sprite")
	if not (sp is Dictionary):
		_build_box()
		head = 1.55
		return
	var s := float(sp.get("scale", 1.0))
	var fw := float(sp.frameWidth)
	var fh := float(sp.frameHeight)
	var foot := float(sp.get("footY", fh))
	# si caricano subito le pose che servono in sala; la provocazione alla prima volta
	for state in ["idle", "walk", "jump", "fall"]:
		_texture_for(state)
	var tex := _texture_for("idle")
	_quad = HallMaterials.fighter(tex, Vector2(fw, fh), foot, s * PX, _outline, 0, _nearest())
	_mats[tex] = _quad.material_override
	_pivot.add_child(_quad)


# La striscia (formato cartella) o il foglio intero di una posa, una volta sola per tutta la sala
func _texture_for(state: String) -> Texture2D:
	var sp: Dictionary = _look.sprite
	var anims: Dictionary = sp.animations
	var a: Dictionary = anims.get(state, anims.get("idle", {}))
	var path := ""
	if sp.has("dir"):
		path = "res://data/%s/%s.png" % [sp.dir, a.get("src", state)]
	else:
		path = "res://data/" + str(sp.path)
	return texture(path)


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


func _nearest() -> bool:
	return str(_look.get("sprite", {}).get("filter", "")) == "nearest"


func _show_frame(anim: String, now: float, alpha: float, facing: float) -> void:
	var sp: Dictionary = _look.sprite
	var anims: Dictionary = sp.animations
	var a: Dictionary = anims.get(anim, anims.get("idle", {}))
	var tex := _texture_for(anim)
	if tex == null:
		return
	if not _mats.has(tex):
		var m := HallMaterials.sprite_rim_material(tex, _outline, _nearest())
		m.set_shader_parameter("pad", (_quad.material_override as ShaderMaterial).get_shader_parameter("pad"))
		_mats[tex] = m
	var mat: ShaderMaterial = _mats[tex]
	if _quad.material_override != mat:
		_quad.material_override = mat
	var frames := maxi(1, int(a.get("frames", 1)))
	var elapsed := maxf(0.0, now - _anim_since)
	var f := int(elapsed / 1000.0 * float(a.get("fps", 8))) if a.get("loop", true) else 0
	f = f % frames if a.get("loop", true) else mini(int(elapsed / 1000.0 * float(a.get("fps", 8))), frames - 1)
	var fw := float(sp.frameWidth)
	var fh := float(sp.frameHeight)
	var row := 0 if sp.has("dir") else int(a.get("row", 0))
	var columns := maxi(1, int(tex.get_width() / fw))
	HallMaterials.set_sprite_frame(mat, f, int(fw), int(fh), columns, row)
	mat.set_shader_parameter("flip_h", 1.0 if facing < 0.0 else 0.0)
	mat.set_shader_parameter("flash", sin(_pop * PI) * 0.8)
	mat.set_shader_parameter("brightness", 1.0 if alpha >= 1.0 else 0.45) # chi è caduto dalla rete si spegne


static func _param(mat: Material, param: String, value: Variant) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(param, value)


# Bonobo, il rettangolo rosso del gioco: qui un cubo con due occhioni
func _build_box() -> void:
	_box = Node3D.new()
	_pivot.add_child(_box)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 1.45, 0.62)
	body.mesh = bm
	var red := StandardMaterial3D.new()
	red.albedo_color = BONOBO_RED
	red.roughness = 0.35
	red.metallic_specular = 0.8
	red.rim_enabled = true
	red.rim = 0.6
	red.rim_tint = 0.2
	red.emission_enabled = true
	red.emission = BONOBO_RED.darkened(0.6)
	body.material_override = red
	body.position.y = 0.725
	_box.add_child(body)
	_eyes = Node3D.new()
	_eyes.position = Vector3(0.0, 1.08, 0.32)
	_box.add_child(_eyes)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("111111")
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.13
		em.height = 0.26
		em.radial_segments = 12
		em.rings = 6
		eye.mesh = em
		eye.material_override = white
		eye.position = Vector3(side * 0.17, 0.0, 0.0)
		eye.scale = Vector3(1.0, 1.25, 0.5)
		_eyes.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.065
		pm.height = 0.13
		pm.radial_segments = 10
		pm.rings = 5
		pupil.mesh = pm
		pupil.material_override = black
		pupil.position = Vector3(side * 0.17 + 0.04, -0.02, 0.07)
		pupil.scale = Vector3(1.0, 1.2, 0.5)
		_eyes.add_child(pupil)


func _animate_box(p: Dictionary, anim: String, facing: float, sx: float, sy: float, alpha: float) -> void:
	var bob := 0.0
	var lean := 0.0
	if anim == "walk":
		bob = absf(sin(_t * 12.0)) * 0.12
		lean = -facing * 0.12
	elif anim == "idle":
		sy *= 1.0 + sin(_t * 3.0) * 0.025 # respira
	elif anim == "taunt":
		lean = sin(_t * 8.0) * 0.35 # l'inchino del cubo: dondola
	_box.position.y = bob
	_box.scale = Vector3(sx, sy, sx)
	_box.rotation.z = lean
	# gli occhi guardano dove va
	_eyes.position.x = facing * 0.08
	_box.visible = alpha > 0.1
	for c in _box.get_children():
		if c is MeshInstance3D:
			(c.material_override as StandardMaterial3D).albedo_color.a = alpha
			(c.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED


# Corona d'oro: un anello con cinque punte e una gemma rossa davanti
static func crown(size: float) -> Node3D:
	var n := Node3D.new()
	var gold := HallMaterials.trim_gold()
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = size * 0.5
	bm.bottom_radius = size * 0.45
	bm.height = size * 0.3
	bm.radial_segments = 12
	bm.rings = 1
	band.mesh = bm
	band.material_override = gold
	n.add_child(band)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = size * 0.14
	spike.height = size * 0.38
	spike.radial_segments = 4
	spike.rings = 1
	for i in 5:
		var a := i * TAU / 5.0
		var s := MeshInstance3D.new()
		s.mesh = spike
		s.material_override = gold
		s.position = Vector3(cos(a) * size * 0.44, size * 0.32, sin(a) * size * 0.44)
		n.add_child(s)
	var gem := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = size * 0.09
	gm.height = size * 0.18
	gm.radial_segments = 8
	gm.rings = 4
	gem.mesh = gm
	gem.material_override = HallMaterials.neon(UI.PRIMARY)
	gem.position = Vector3(0.0, 0.0, size * 0.5)
	n.add_child(gem)
	return n
