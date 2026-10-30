# Gli oggetti fisici della sala d'attesa 3D (HallSnapshot.props): palloni da basket e da spiaggia, pezzi giganti
# degli scacchi. Dove sono, come rotolano e quando cadono lo decide il server (src/shared/hall.ts): qui si
# interpolano come i giocatori e si disegnano. Il pallone in mano segue la testa di chi lo tiene, già interpolata.
# Pezzi degli scacchi: mesh "al tornio" (un profilo 2D fatto girare) con qualche scatola, una sola mesh per pezzo.
# Per il server un pezzo è il centro della base (y = 0) e cadendo ruota sullo spigolo della base verso tiltDir;
# yaw 0 = guarda verso -z (il cavallo). Un pallone è il centro della sfera; spin gira in [0, 2 PI).
extends Node3D

const HallBuffer := preload("res://scripts/hall_buffer.gd")

const CM := 0.01
const SEGMENTS := 20 # spicchi del tornio: basso poligono ma tondo
const HELD_LIFT := 0.14 # metri tra la testa e il pallone tenuto in mano
const BLEND_RATE := 12.0 # 1/s: quanto in fretta il pallone passa dalla mano al volo (e viceversa) senza scatti

# Profili dei pezzi: [raggio, altezza] con raggio della base = 1; si scalano su r e h dello snapshot
# (l'altezza del profilo è la più alta delle y). Le sfere sono archi di punti.
const BASE := [[0.0, 0.0], [1.0, 0.0], [1.0, 0.12], [0.9, 0.18], [0.92, 0.26], [0.74, 0.34]]

static var _meshes := {} # "pezzo/r/h" -> ArrayMesh (bianchi e neri hanno la stessa forma)

var buffer := HallBuffer.new()
var _props := {} # id -> Prop
var _latest := {} # id -> ultimo HallPropState dello snapshot
var _t := 0.0


# Un oggetto disegnato: il corpo che ruota, l'ombra a terra, da dove arriva quando passa di mano
class Prop extends Node3D:
	var kind := ""
	var body: MeshInstance3D
	var shadow: MeshInstance3D
	var holder := ""
	var drawn := Vector3.ZERO # dove è stato disegnato l'ultima volta, metri
	var offset := Vector3.ZERO # scarto che si richiude dopo una presa o un tiro
	var spin := 0.0
	var r := 0.12
	var h := 0.6
	var glow: Node3D
	var glow_left := 0.0
	var knight := false
	var knight_face := 0.0 # il cavallo guarda verso il centro della scacchiera: 0 = verso +x
	var home_yaw := 0.0


func _init() -> void:
	buffer.angles = ["yaw", "spin", "tilt", "tiltDir"]
	buffer.teleport_cm = 600.0 # un tiro forte fa anche 40 cm in uno snapshot: solo i rientri veri sono salti


func on_snapshot(snap: Dictionary, received_at: float) -> void:
	var props: Array = snap.get("props", []) if snap.get("props") is Array else []
	buffer.push(float(snap.get("t", 0.0)), received_at, props)
	_latest.clear()
	for p in props:
		if p is Dictionary:
			_latest[str(p.get("id", ""))] = p
	for id in _props.keys():
		if not _latest.has(id):
			_props[id].shadow.queue_free()
			_props[id].queue_free()
			_props.erase(id)


# Ogni frame: lo stato interpolato all'ora now (ms), i lottatori disegnati (id -> HallFighter) per i palloni in mano
func update(now: float, fighters: Dictionary, delta: float) -> void:
	_t += delta
	var sampled := buffer.sample_all(now)
	for id in sampled:
		var p: Dictionary = sampled[id]
		var n: Prop = _props.get(id)
		if n == null:
			n = _make(p)
			n.name = "P_" + str(id).validate_node_name()
			add_child(n)
			add_child(n.shadow)
			_props[id] = n
		_place(n, p, fighters, delta)


func count() -> int:
	return _props.size()


func node_of(id: String) -> Node3D:
	return _props.get(id)


# Dove si vede adesso un oggetto, metri (l'ultimo snapshot se non è ancora disegnato)
func position_of(id: String) -> Vector3:
	if _props.has(id):
		return _props[id].position
	var p: Dictionary = _latest.get(id, {})
	return Vector3(float(p.get("x", 0.0)), float(p.get("y", 0.0)), float(p.get("z", 0.0))) * CM


func state_of(id: String) -> Dictionary:
	return _latest.get(id, {})


func ids() -> Array:
	return _latest.keys()


# Il re caduto dello scacco matto brilla d'oro per un po'
func glow(id: String, seconds := 6.0) -> void:
	var n: Prop = _props.get(id)
	if n == null:
		return
	if n.glow == null:
		n.glow = HallMaterials.halo(HallMaterials.GOLD, maxf(2.0, n.h * 2.2), 0.9)
		n.glow.position.y = n.h * 0.5
		n.body.add_child(n.glow)
	n.glow_left = seconds


# Il re di un colore (per lo scacco matto): id o ""
func king_of(color: String) -> String:
	for id in _latest:
		var p: Dictionary = _latest[id]
		if str(p.get("kind", "")) == "chess" and str(p.get("piece", "")) == "king" and str(p.get("color", "")) == color:
			return id
	return ""


# --- costruzione ---

func _make(p: Dictionary) -> Prop:
	var n := Prop.new()
	n.kind = str(p.get("kind", "basketball"))
	n.r = maxf(0.05, float(p.get("r", 12.0)) * CM)
	n.h = maxf(0.1, float(p.get("h", 60.0)) * CM)
	match n.kind:
		"chess":
			n.body = chess_piece(str(p.get("piece", "pawn")), str(p.get("color", "white")), n.r, n.h)
		"beachball":
			n.body = ball(n.r, HallMaterials.beachball_material())
		_:
			n.body = ball(n.r, HallMaterials.basketball_material())
	n.add_child(n.body)
	if n.kind == "basketball":
		# il pallone vero è piccolo (12 cm) nella sala grande: un alone arancione lo fa vedere da lontano
		var halo := HallMaterials.halo(Color("ff8a2a"), n.r * 7.0, 0.3)
		n.add_child(halo)
	# l'ombra sta a terra mentre il pezzo cade o il pallone vola: è figlia della radice, non dell'oggetto
	n.shadow = HallMaterials.blob_shadow(1.0, 1.0, 0.6)
	n.shadow.name = "Shadow"
	n.spin = float(p.get("spin", 0.0))
	n.holder = str(p.get("holder", "")) if p.get("holder") != null else "" # già in mano: niente volo dalla rastrelliera
	n.knight = str(p.get("piece", "")) == "knight"
	n.knight_face = PI if str(p.get("id", "")).ends_with("-g") else 0.0 # b a sinistra guarda a destra, g il contrario
	n.home_yaw = float(p.get("yaw", 0.0))
	n.drawn = Vector3(float(p.get("x", 0.0)), float(p.get("y", 0.0)), float(p.get("z", 0.0))) * CM
	return n


func _place(n: Prop, p: Dictionary, fighters: Dictionary, delta: float) -> void:
	var target := Vector3(float(p.get("x", 0.0)), float(p.get("y", 0.0)), float(p.get("z", 0.0))) * CM
	var holder := str(p.get("holder", "")) if p.get("holder") != null else ""
	var held := holder != "" and fighters.has(holder)
	if held:
		# sopra la testa di chi lo tiene, come la vede chi gioca (il lottatore ha il suo ritardo di disegno)
		var f: Node3D = fighters[holder]
		target = f.position + Vector3(0.0, f.top_height() + n.r + HELD_LIFT + sin(_t * 5.0) * 0.04, 0.0)
	if holder != n.holder:
		# presa o tiro: si parte da dove era disegnato e si raggiunge il punto nuovo in un attimo
		n.offset = n.drawn - target
		n.holder = holder
	n.offset *= exp(-delta * BLEND_RATE)
	var at := target + n.offset
	n.drawn = at
	n.position = at
	if n.kind == "chess":
		var tilt := clampf(float(p.get("tilt", 0.0)), 0.0, PI * 0.5)
		var dir_a := float(p.get("tiltDir", 0.0))
		var dir := Vector3(cos(dir_a), 0.0, sin(dir_a))
		# il cavallo nella mesh guarda +x: con yaw 0 (verso -z) lo si vedrebbe da dietro, e una testa di cavallo
		# si riconosce di profilo; lo giro di un quarto verso il centro della scacchiera, come nei set veri
		var yaw := Basis(Vector3.UP, -float(p.get("yaw", 0.0)))
		if n.knight:
			yaw = Basis(Vector3.UP, n.home_yaw - float(p.get("yaw", 0.0)) + n.knight_face)
		if tilt > 0.001:
			# cade sullo spigolo della base verso dir: il corpo ruota attorno a quel punto
			var rot := Basis(Vector3.UP.cross(dir).normalized(), tilt)
			var edge := dir * n.r
			n.body.transform = Transform3D(rot * yaw, edge - rot * edge)
		else:
			n.body.transform = Transform3D(yaw, Vector3.ZERO)
		# l'ombra si allunga verso dove cade
		var reach := n.h * sin(tilt)
		var spread := maxf(n.r * 2.4, reach + n.r * 1.8)
		var mid := at + dir * (reach * 0.5)
		n.shadow.transform = Transform3D(Basis(Vector3.UP, -dir_a) * Basis.from_scale(Vector3(spread, 1.0, n.r * 2.6)), Vector3(mid.x, 0.013, mid.z))
		_param(n.shadow.material_override, "strength", 0.7)
	else:
		var spin := float(p.get("spin", 0.0))
		var ds := wrapf(spin - n.spin, -PI, PI) # il server fa ricominciare spin da 0 a ogni giro
		n.spin = spin
		if held:
			n.body.basis = Basis(Vector3.UP, delta * 2.5) * n.body.basis # in mano gira piano su se stesso
		elif absf(ds) > 0.0001:
			var yaw := float(p.get("yaw", 0.0))
			var axis := Vector3.UP.cross(Vector3(cos(yaw), 0.0, sin(yaw))).normalized()
			n.body.basis = (Basis(axis, ds) * n.body.basis).orthonormalized()
		# più in alto, ombra più piccola e chiara
		var lift := maxf(0.0, at.y - n.r)
		var k := clampf(1.0 - lift / 5.0, 0.3, 1.0)
		n.shadow.transform = Transform3D(Basis.from_scale(Vector3(n.r * 2.6 * k, 1.0, n.r * 2.6 * k)), Vector3(at.x, 0.014, at.z))
		_param(n.shadow.material_override, "strength", 0.75 * k)
	if n.glow != null:
		n.glow_left = maxf(0.0, n.glow_left - delta)
		n.glow.visible = n.glow_left > 0.0
		n.glow.scale = Vector3.ONE * (1.0 + sin(_t * 6.0) * 0.12) * clampf(n.glow_left, 0.0, 1.0)
		_param(n.body.get_surface_override_material(0), "highlight", clampf(n.glow_left, 0.0, 1.0))

static func _param(mat: Material, param: String, value: Variant) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(param, value)


# Un pallone: sfera col suo materiale, centro nell'origine
static func ball(r: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 28
	s.rings = 14
	m.mesh = s
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# Un pezzo degli scacchi: r raggio della base, h altezza, metri; origine al centro della base
static func chess_piece(piece: String, color: String, r: float, h: float) -> MeshInstance3D:
	var key := "%s/%.3f/%.3f" % [piece, r, h]
	if not _meshes.has(key):
		_meshes[key] = _piece_mesh(piece, r, h)
	var m := MeshInstance3D.new()
	m.mesh = _meshes[key]
	# il basamento è d'oro (gold_below, quota locale da terra)
	m.set_surface_override_material(0, HallMaterials.chess_material(color, h * 0.035))
	m.set_surface_override_material(1, HallMaterials.trim_gold())
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# Profilo, alto profilo (canonico) e pezzi aggiunti di ogni pezzo: { profile, extras: [[mesh, Transform3D, oro?]] }
static func piece_shape(piece: String) -> Dictionary:
	var prof: Array = BASE.duplicate()
	var extras: Array = []
	var trims: Array = [0.13] # altezze (unità del profilo) degli anelli d'oro
	match piece:
		"pawn":
			prof.append_array([[0.58, 0.5], [0.46, 0.9], [0.42, 1.2], [0.74, 1.28], [0.74, 1.38], [0.4, 1.45], [0.34, 1.52]])
			prof.append_array(_arc(Vector2(0.0, 1.98), 0.5, -55.0, 90.0, 8))
			trims.append(1.33)
		"rook":
			prof.append_array([[0.72, 0.42], [0.64, 1.7], [0.8, 1.9], [0.94, 2.1], [0.94, 2.55], [0.66, 2.55], [0.66, 2.42], [0.0, 2.42]])
			for i in 5:
				var a := i * TAU / 5.0
				extras.append([_box_mesh(Vector3(0.42, 0.36, 0.3)), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.8, 2.72, sin(a) * 0.8)), false])
			trims.append(1.95)
		"bishop":
			prof.append_array([[0.6, 0.5], [0.36, 1.6], [0.7, 1.72], [0.7, 1.82], [0.38, 1.9], [0.4, 2.0]])
			prof.append_array(_ellipse(Vector2(0.0, 2.45), Vector2(0.5, 0.62), -50.0, 70.0, 7))
			prof.append_array([[0.14, 3.05], [0.0, 3.1]])
			extras.append([_sphere_mesh(0.14), Transform3D(Basis(), Vector3(0.0, 3.2, 0.0)), true])
			# il taglio della mitra
			extras.append([_box_mesh(Vector3(0.08, 0.6, 1.06)), Transform3D(Basis(Vector3(0, 0, 1), 0.65), Vector3(0.08, 2.6, 0.0)), true])
			trims.append(1.77)
		"queen":
			prof.append_array([[0.66, 0.5], [0.4, 2.2], [0.76, 2.34], [0.76, 2.44], [0.44, 2.54], [0.5, 2.7], [0.84, 3.2], [0.62, 3.22], [0.5, 3.1], [0.0, 3.1]])
			for i in 9:
				var a := i * TAU / 9.0
				extras.append([_sphere_mesh(0.13), Transform3D(Basis(), Vector3(cos(a) * 0.8, 3.3, sin(a) * 0.8)), true])
			extras.append([_sphere_mesh(0.26), Transform3D(Basis(), Vector3(0.0, 3.35, 0.0)), false])
			extras.append([_sphere_mesh(0.11), Transform3D(Basis(), Vector3(0.0, 3.68, 0.0)), true])
			trims.append(2.39)
		"king":
			prof.append_array([[0.68, 0.5], [0.42, 2.4], [0.8, 2.55], [0.8, 2.65], [0.46, 2.75], [0.5, 2.9], [0.74, 3.35], [0.42, 3.5], [0.2, 3.56], [0.0, 3.56]])
			extras.append([_box_mesh(Vector3(0.18, 0.7, 0.18)), Transform3D(Basis(), Vector3(0.0, 3.9, 0.0)), true])
			extras.append([_box_mesh(Vector3(0.56, 0.18, 0.18)), Transform3D(Basis(), Vector3(0.0, 4.0, 0.0)), true])
			trims.append(2.6)
		"knight":
			prof.append_array([[0.72, 0.5], [0.66, 0.62], [0.0, 0.62]])
			# la testa del cavallo, guarda verso +x: collo, testa, muso, criniera, orecchie
			extras.append([_box_mesh(Vector3(0.82, 1.5, 0.66)), Transform3D(Basis(Vector3(0, 0, 1), 0.22), Vector3(-0.08, 1.3, 0.0)), false])
			extras.append([_box_mesh(Vector3(1.25, 0.62, 0.6)), Transform3D(Basis(Vector3(0, 0, 1), -0.5), Vector3(0.32, 2.05, 0.0)), false])
			extras.append([_box_mesh(Vector3(0.5, 0.5, 0.56)), Transform3D(Basis(Vector3(0, 0, 1), -0.25), Vector3(0.82, 1.72, 0.0)), false])
			extras.append([_box_mesh(Vector3(0.2, 1.55, 0.3)), Transform3D(Basis(Vector3(0, 0, 1), 0.3), Vector3(-0.5, 1.6, 0.0)), true])
			for side in [-1.0, 1.0]:
				var ear := CylinderMesh.new()
				ear.top_radius = 0.0
				ear.bottom_radius = 0.14
				ear.height = 0.38
				ear.radial_segments = 3
				ear.rings = 1
				extras.append([ear, Transform3D(Basis(Vector3(0, 0, 1), 0.2), Vector3(-0.12, 2.55, side * 0.16)), false])
				extras.append([_sphere_mesh(0.07), Transform3D(Basis(), Vector3(0.42, 2.12, side * 0.3)), true])
			trims.append(0.56)
	var top := 0.0
	for pt in prof:
		top = maxf(top, float(pt[1]))
	for e in extras:
		var t: Transform3D = e[1]
		top = maxf(top, t.origin.y + 0.15)
	return {"profile": prof, "extras": extras, "trims": trims, "height": top}


# La mesh di un pezzo: superficie 0 il corpo (avorio o ossidiana), superficie 1 le finiture d'oro
static func _piece_mesh(piece: String, r: float, h: float) -> ArrayMesh:
	var shape := piece_shape(piece)
	var sy: float = h / float(shape.height)
	var scale := Vector3(r, sy, r)
	var shift := Vector3.ZERO # origine al centro della base
	# il tornio va indicizzato prima di aggiungere scatole e sfere (che hanno gli indici): senza, Godot
	# disegnerebbe solo i triangoli con l'indice e il corpo del pezzo sparirebbe
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	_lathe(body, shape.profile, scale, shift)
	body.index()
	var gold := SurfaceTool.new()
	gold.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in shape.extras:
		var t: Transform3D = e[1]
		var xf := Transform3D(Basis.from_scale(scale), shift) * t
		var st: SurfaceTool = gold if e[2] else body
		st.append_from(e[0], 0, xf)
	for y in shape.trims:
		var ring := TorusMesh.new()
		var rr := _profile_radius(shape.profile, float(y)) + 0.04
		ring.inner_radius = rr - 0.06
		ring.outer_radius = rr + 0.06
		ring.rings = SEGMENTS
		ring.ring_segments = 6
		gold.append_from(ring, 0, Transform3D(Basis.from_scale(Vector3(r, r * 0.9, r)), Vector3(0.0, float(y) * sy, 0.0) + shift))
	var mesh := body.commit()
	gold.commit(mesh)
	return mesh


static func _profile_radius(prof: Array, y: float) -> float:
	var best := 0.0
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		if (y - float(a[1])) * (y - float(b[1])) <= 0.0 and float(b[1]) != float(a[1]):
			best = maxf(best, lerpf(float(a[0]), float(b[0]), (y - float(a[1])) / (float(b[1]) - float(a[1]))))
	return best


# Il tornio: ogni tratto del profilo è una fascia con la sua normale (spigoli netti tra le fasce, tondo attorno)
static func _lathe(st: SurfaceTool, prof: Array, scale: Vector3, shift: Vector3) -> void:
	for i in prof.size() - 1:
		var a := Vector2(float(prof[i][0]) * scale.x, float(prof[i][1]) * scale.y)
		var b := Vector2(float(prof[i + 1][0]) * scale.x, float(prof[i + 1][1]) * scale.y)
		if a.x <= 0.0 and b.x <= 0.0:
			continue
		var d := b - a
		if d.length() < 0.00001:
			continue
		var n2 := Vector2(d.y, -d.x).normalized() # in fuori (il profilo sale)
		for s in SEGMENTS:
			var a0 := s * TAU / SEGMENTS
			var a1 := (s + 1) * TAU / SEGMENTS
			var c0 := Vector3(cos(a0), 0.0, sin(a0))
			var c1 := Vector3(cos(a1), 0.0, sin(a1))
			var pa0 := c0 * a.x + Vector3(0.0, a.y, 0.0) + shift
			var pa1 := c1 * a.x + Vector3(0.0, a.y, 0.0) + shift
			var pb0 := c0 * b.x + Vector3(0.0, b.y, 0.0) + shift
			var pb1 := c1 * b.x + Vector3(0.0, b.y, 0.0) + shift
			var n0 := (c0 * n2.x + Vector3(0.0, n2.y, 0.0)).normalized()
			var n1 := (c1 * n2.x + Vector3(0.0, n2.y, 0.0)).normalized()
			for v in [[pa0, n0], [pa1, n1], [pb0, n0], [pa1, n1], [pb1, n1], [pb0, n0]]:
				st.set_normal(v[1])
				st.set_uv(Vector2(float(s) / SEGMENTS, a.y))
				st.add_vertex(v[0])


static func _arc(c: Vector2, rad: float, from_deg: float, to_deg: float, steps: int) -> Array:
	return _ellipse(c, Vector2(rad, rad), from_deg, to_deg, steps)


static func _ellipse(c: Vector2, rad: Vector2, from_deg: float, to_deg: float, steps: int) -> Array:
	var out := []
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		out.append([maxf(0.0, c.x + cos(a) * rad.x), c.y + sin(a) * rad.y])
	return out


static func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _sphere_mesh(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s
