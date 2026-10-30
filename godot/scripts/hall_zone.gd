# Una zona della sala d'attesa 3D, disegnata dal suo HallZone (hall_view.gd): pedana di una modalità, portale di
# un'arena, piedistallo di un lottatore, cerchio dei pronti, trampolino, gabbia dei bot, gong, trono.
# Dove sta e quanto è grande lo dice il server; qui si costruisce la scena coi materiali della sala (HallMaterials)
# e la si fa vivere: chi c'è sopra, i voti, la scelta in testa.
extends Node3D

const HallFighter := preload("res://scripts/hall_fighter.gd")

const CM := 0.01
const PORTAL_TILT := 0.42 # radianti: i portali sono inclinati all'indietro, verso la telecamera che sta in alto
const LABEL_NEAR := 3.5 # metri: le scritte dei piedistalli e dei portali sono piene entro questa distanza da me
const LABEL_FAR := 9.0 # e quasi spente oltre

# Il colore di ogni modalità sulle pedane (colori del gioco, COLORS)
# Basket: misure di riserva se game.json non ha ancora "hall" (si allineano a HALL in constants.ts)
const RIM_HEIGHT := 3.05 # metri da terra del ferro
const RIM_RADIUS := 0.23 # metri, raggio del ferro (la zona "hoop" ha r = raggio del ferro)
const RIM_OFFSET := 0.38 # m dal tabellone al centro del ferro (HALL.rimOffset)
const THREE_POINT := 6.0 # m dal punto sotto il ferro: oltre il canestro vale 3 (HALL.threePointRadius)
const FIBA_HOOP := 1.575 # m dal fondo al centro del ferro, nel campo vero largo 15 m (lo shader del campo scala su questa)
const FIBA_THREE := 6.75 # m, raggio della linea da tre nel campo vero
const BOARD_BORDER := 0.06 # quota del lato della scacchiera occupata dalla cornice (chessboard_material)

const MODE_COLORS := {"ffa": Color("f1c40f"), "teams": Color("3498db"), "flag": Color("2ecc71"), "race": Color("b06bff")}
const BOT_ADD := Color("2ecc71")
const BOT_REMOVE := Color("e74c3c")

var kind := ""
var zone_id := ""
var radius := 1.0 # metri
var color := Color.WHITE
var progress := 0.0 # gabbia dei bot: da 0 a 1 mentre qualcuno ci sta fermo sopra
var votable := false # ci si ferma sopra per votare (pedane, portali, piedistalli, gabbie)

var _game: Dictionary
var _t := 0.0
var _flash := 0.0 # 1 = appena votata, suonata, saltata: si accende e torna
var _occupied := 0.0 # 0..1, morbido: c'è qualcuno sopra
var _pad_mat: Material # il materiale che si accende quando c'è qualcuno sopra ("active", "hover")
var _active_param := "active"
var _spin: Node3D # quello che gira piano (icone, statue, corona dei bot)
var _bounce: Node3D # la tela del trampolino, il disco del gong
var _bounce_mat: Material
var _title: Label3D
var _count: Label3D # voti, pronti
var _halo: Node3D # la pedana o il portale in testa: la corona d'oro che gira sopra
var _segments: Array[MeshInstance3D] = [] # gabbia dei bot: la corona di luci che si riempie
var _seg_on: Material
var _seg_off: Material
var _beam: MeshInstance3D # il fascio di luce dall'alto (si accende con qualcuno sopra)
var _beam_power := 0.35
var _fade_labels := false # le scritte si spengono da lontano (piedistalli e portali sono tanti)
# Basket e scacchi
var rim_height := RIM_HEIGHT # m
var rim_radius := RIM_RADIUS # m
var _court: MeshInstance3D # il parquet: si sposta sotto il canestro quando si sa dov'è (link)
var _court_logo: Node3D
var _court_size := Vector2(10.0, 9.33)
var _net: MeshInstance3D
var _led: Array[MeshInstance3D] = [] # la cornice del tabellone che lampeggia al canestro
var _score_title: Label3D
var _score_name: Label3D
var _score_points: Label3D
var _score_pop := 0.0
var _board_frame_mat: Material
var _dim := 0.0 # 0..1: le scritte si fanno da parte quando un nome di giocatore ci passa davanti
var _dim_target := 0.0


func setup(z: Dictionary, game: Dictionary, preview: Texture2D = null) -> void:
	_game = game
	kind = str(z.get("kind", ""))
	zone_id = str(z.get("id", ""))
	radius = maxf(0.3, float(z.get("r", 100.0)) * CM)
	if kind == "hoop":
		rim_radius = clampf(float(z.get("r", RIM_RADIUS / CM)) * CM, 0.1, 1.0)
	position = Vector3(float(z.get("x", 0.0)) * CM, 0.0, float(z.get("z", 0.0)) * CM)
	name = "%s_%s" % [kind, zone_id.validate_node_name()]
	votable = kind in ["mode", "stage", "fighter", "botAdd", "botRemove"]
	var text := str(z.get("label", zone_id))
	match kind:
		"mode": _build_mode(text)
		"stage": _build_portal(text, preview)
		"fighter": _build_pedestal(text)
		"ready": _build_ready(text)
		"trampoline": _build_trampoline(text)
		"botAdd", "botRemove": _build_cage(text)
		"gong": _build_gong(text)
		"throne": _build_throne(text)
		"hoop": _build_hoop(text)
		"court": _build_court(text)
		"chessboard": _build_chessboard(text)
		"rack": _build_rack(text)
		_: _build_generic(text)


# Ogni frame: quanti ci sono sopra, i voti, se è la scelta in testa, quanto dista il mio lottatore (metri)
func tick(delta: float, occupants: int, votes: int, leading: bool, ready_total := 0, my_distance := 0.0) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 1.6)
	_occupied = move_toward(_occupied, 1.0 if occupants > 0 else 0.0, delta * 4.0)
	if _pad_mat != null:
		set_param(_pad_mat, _active_param, maxf(_occupied, _flash))
	if _spin != null:
		_spin.rotation.y += delta * (0.6 + _occupied * 2.0)
	if _halo != null:
		_halo.visible = leading
		_halo.rotation.y = _t * 1.2
		_halo.position.y = float(_halo.get_meta("y", 2.0)) + sin(_t * 2.0) * 0.06
	if _beam != null:
		var on := clampf(_occupied * 0.7 + _flash + (0.35 if leading else 0.0), 0.0, 1.0)
		_beam.visible = on > 0.02
		set_param(_beam.material_override, "intensity", _beam_power * on)
	_dim = move_toward(_dim, _dim_target, delta * 4.0)
	var keep := 1.0 - _dim * 0.8
	if _title != null:
		var k := clampf(1.0 - (my_distance - LABEL_NEAR) / (LABEL_FAR - LABEL_NEAR), 0.18, 1.0) if _fade_labels else 1.0
		_title.modulate.a = k * keep
		_title.outline_modulate.a = k * 0.85 * keep
	if _count != null:
		_count.modulate.a = keep
		_count.outline_modulate.a = 0.8 * keep
	match kind:
		"mode", "stage":
			_count.text = _votes_text(votes)
			_count.modulate = Color(UI.ACCENT if leading else Color(1, 1, 1, 0.9), keep)
			_count.scale = Vector3.ONE * (1.0 + _flash * 0.6)
		"ready":
			var fill := float(occupants) / maxf(1.0, float(ready_total))
			set_param(_pad_mat, "fill", clampf(fill, 0.0, 1.0))
			_count.text = "%d / %d" % [mini(occupants, ready_total), ready_total] if ready_total > 0 else ""
			_count.modulate = Color(UI.OK if ready_total > 0 and occupants >= ready_total else Color.WHITE, keep)
		"trampoline":
			set_param(_bounce_mat, "bounce", _flash)
		"botAdd", "botRemove":
			var lit := int(round(progress * _segments.size()))
			for i in _segments.size():
				var mat := _seg_on if i < lit else _seg_off
				if _segments[i].material_override != mat:
					_segments[i].material_override = mat
			_spin.rotation.y += delta * progress * 8.0
		"gong":
			# il disco oscilla dopo il colpo e piano piano si ferma
			_bounce.rotation.x = sin(_t * 9.0) * 0.22 * _flash
			_bounce.rotation.z = sin(_t * 6.0) * 0.06 * _flash
			set_param(_bounce_mat, "strike", _flash)
		"hoop":
			# la retina sobbalza, il tabellone lampeggia, il nome sul tabellino entra grande e si assesta
			set_param(_net.material_override, "swish", _flash)
			var blink := _flash * (0.5 + 0.5 * sin(_t * 26.0))
			for m in _led:
				set_param(m.material_override, "intensity", 1.6 + blink * 5.0)
			_score_pop = maxf(0.0, _score_pop - delta * 2.5)
			_score_name.scale = Vector3.ONE * (1.0 + sin(_score_pop * PI) * 0.35)
			_score_points.scale = _score_name.scale
		"chessboard":
			set_param(_board_frame_mat, "intensity", 1.4 + _flash * 4.0 * (0.5 + 0.5 * sin(_t * 18.0)))


# Un evento su questa zona: voto, rimbalzo, gong, trono
func bang() -> void:
	_flash = 1.0


# hall_view.gd chiede se una scritta (titolo, voti) sta sotto il nome di un giocatore: allora si spegne un po'
func dim_labels(covered: Callable) -> void:
	var hit := false
	for l in [_title, _count]:
		if l != null and l.text != "" and l.billboard != BaseMaterial3D.BILLBOARD_DISABLED and covered.call(l):
			hit = true
	_dim_target = 1.0 if hit else 0.0


# Canestro: il tabellino sopra il tabellone dice chi ha segnato e quanto, nel suo colore
func score(who: String, points: int, col: Color, swish: bool) -> void:
	bang()
	_score_pop = 1.0
	if _score_name == null:
		return
	_score_title.text = "SWISH!" if swish else "CANESTRO!"
	_score_name.text = who
	_score_name.modulate = col.lightened(0.25)
	_score_points.text = "+%d" % points
	_score_points.modulate = UI.ACCENT if points >= 3 else Color.WHITE


# Il centro del ferro, coordinate della sala (metri)
func rim_point() -> Vector3:
	return position + basis * Vector3(0.0, rim_height, 0.0)


# Il centro del tabellone (per capire se un pallone l'ha preso)
func board_point() -> Vector3:
	return position + basis * Vector3(0.0, rim_height + 0.4, -RIM_OFFSET)


# Canestro e campo si guardano: il canestro gira il tabellone verso il campo, il campo mette il fondo sotto il
# canestro (le righe dello shader sono in proporzione al campo vero, col ferro a FIBA_HOOP dal fondo)
func link(other: Vector3) -> void:
	var d := Vector2(other.x - position.x, other.z - position.z)
	match kind:
		"hoop":
			if d.length() > 0.01:
				rotation.y = atan2(d.x, d.y) # +z locale verso il campo
		"court":
			_place_court(Vector3(other.x, 0.0, other.z))


func _votes_text(n: int) -> String:
	if n <= 0:
		return ""
	return "1 voto" if n == 1 else "%d voti" % n


# --- costruzione ---

func _build_mode(text: String) -> void:
	color = MODE_COLORS.get(zone_id, UI.ACCENT)
	var pad := HallMaterials.pad(color, radius * 2.0)
	pad.position.y = 0.02
	_pad_mat = pad.material_override
	add_child(pad)
	_add_rim(radius * 1.02, 0.05, 0.03)
	_spin = Node3D.new()
	_spin.position.y = 1.3
	add_child(_spin)
	_mode_icon(_spin)
	var glow := HallMaterials.halo(color, 2.2, 0.5)
	glow.position.y = 1.3
	add_child(glow)
	_beam = _light_beam(radius * 0.25, radius * 0.95, 7.0, color)
	add_child(_beam)
	_halo = HallFighter.crown(0.45)
	_halo.set_meta("y", 2.05)
	add_child(_halo)
	_title = label(text, 60, Color.WHITE, color.darkened(0.65))
	_title.position.y = 2.75
	add_child(_title)
	_count = label("", 44, UI.ACCENT, Color(0, 0, 0, 0.8))
	_count.position.y = 2.35
	add_child(_count)


# L'icona che gira sopra la pedana: ognuno per sé (stella), squadre (due sagome), bandiera, corsa (bandiera a scacchi)
func _mode_icon(parent: Node3D) -> void:
	var holo := HallMaterials.hologram(color, 0.0)
	match zone_id:
		"ffa":
			for i in 4:
				var b := _box(Vector3(0.95, 0.14, 0.14), holo)
				b.rotation.z = i * PI / 4.0
				parent.add_child(b)
			parent.add_child(_sphere(0.16, HallMaterials.neon(color, 3.0)))
		"teams":
			var tc: Dictionary = _game.get("teamColors", {})
			for side in [-1, 1]:
				var c := Access.color(tc.get("1" if side < 0 else "2", [0xe74c3c])[0]) if not tc.is_empty() else color
				var mat := HallMaterials.hologram(c, 0.0)
				var body := MeshInstance3D.new()
				var cap := CapsuleMesh.new()
				cap.radius = 0.17
				cap.height = 0.62
				cap.radial_segments = 10
				cap.rings = 3
				body.mesh = cap
				body.material_override = mat
				body.position = Vector3(side * 0.26, -0.1, 0.0)
				parent.add_child(body)
				var head := _sphere(0.13, mat)
				head.position = Vector3(side * 0.26, 0.36, 0.0)
				parent.add_child(head)
		"flag", "race":
			var pole := _box(Vector3(0.05, 1.1, 0.05), HallMaterials.trim_gold())
			pole.position = Vector3(-0.3, 0.0, 0.0)
			parent.add_child(pole)
			if zone_id == "flag":
				var cloth := _box(Vector3(0.55, 0.36, 0.03), holo)
				cloth.position = Vector3(0.0, 0.33, 0.0)
				parent.add_child(cloth)
			else:
				var white := HallMaterials.neon(Color.WHITE, 1.6)
				var dark := HallMaterials.hologram(color, 0.0)
				for i in 4:
					for j in 3:
						var sq := _box(Vector3(0.14, 0.12, 0.03), white if (i + j) % 2 == 0 else dark)
						sq.position = Vector3(-0.2 + i * 0.14, 0.45 - j * 0.12, 0.0)
						parent.add_child(sq)
		_:
			parent.add_child(_sphere(0.3, holo))


func _build_portal(text: String, preview: Texture2D) -> void:
	_fade_labels = true
	color = Color("b06bff") if zone_id == "casuale" else Color("4ad9ff")
	var w := minf(radius * 1.85, 2.3)
	var h := w * 1.3
	# la base: una lastra di metallo scuro e la pedana davanti per entrare
	var pad := HallMaterials.pad(color, radius * 1.7)
	pad.position = Vector3(0.0, 0.02, 0.15)
	add_child(pad)
	var base := _box(Vector3(w + 0.3, 0.16, 0.5), HallMaterials.dark_metal())
	base.position = Vector3(0.0, 0.08, -0.25)
	add_child(base)
	var frame := Node3D.new()
	frame.position = Vector3(0.0, 0.14, -0.25)
	frame.rotation.x = -PORTAL_TILT
	add_child(frame)
	var portal := HallMaterials.portal(preview, w, h, color)
	frame.add_child(portal)
	_pad_mat = portal.material_override
	_active_param = "hover"
	var back := _box(Vector3(w + 0.16, h + 0.1, 0.08), HallMaterials.dark_metal())
	back.position = Vector3(0.0, h / 2.0, -0.06)
	frame.add_child(back)
	for side in [-1.0, 1.0]:
		var post := _box(Vector3(0.1, h * 0.72, 0.14), HallMaterials.trim_gold())
		post.position = Vector3(side * (w / 2.0 + 0.04), h * 0.36, 0.0)
		frame.add_child(post)
	if preview == null:
		var q_mark := label("?", 200, Color.WHITE, color.darkened(0.5))
		q_mark.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		q_mark.position = Vector3(0.0, h * 0.45, 0.04)
		frame.add_child(q_mark)
	var top := h * cos(PORTAL_TILT) + 0.14
	_halo = HallFighter.crown(0.35)
	_halo.set_meta("y", top + 0.35)
	_halo.position.z = -0.25 - h * sin(PORTAL_TILT)
	add_child(_halo)
	_title = label(text, 40, Color.WHITE, Color(0, 0, 0, 0.85))
	_title.position = Vector3(0.0, 0.5, 0.95)
	add_child(_title)
	_count = label("", 38, UI.ACCENT, Color(0, 0, 0, 0.85))
	_count.position = Vector3(0.0, 0.2, 0.95)
	add_child(_count)


func _build_pedestal(text: String) -> void:
	_fade_labels = true
	color = UI.ACCENT
	var r := clampf(radius * 0.9, 0.4, 0.65)
	# la pedana bassa dove ci si ferma (il server tiene tutti a terra) e, dietro, la colonnina col busto
	var plinth := _cylinder(r * 0.96, r, 0.1, HallMaterials.marble(true), 20)
	plinth.position.y = 0.05
	add_child(plinth)
	_add_rim(r * 0.98, 0.03, 0.1)
	var pad := HallMaterials.pad(UI.ACCENT, r * 1.6)
	pad.position.y = 0.105
	_pad_mat = pad.material_override
	add_child(pad)
	var back := -(r + 0.12)
	var column := _cylinder(0.12, 0.15, 0.95, HallMaterials.marble(true), 10)
	column.position = Vector3(0.0, 0.475, back)
	add_child(column)
	var capital := _cylinder(0.22, 0.16, 0.08, HallMaterials.trim_gold(), 10)
	capital.position = Vector3(0.0, 0.99, back)
	add_child(capital)
	_spin = Node3D.new()
	_spin.position = Vector3(0.0, 1.03, back)
	add_child(_spin)
	_statue(_spin)
	_beam = _light_beam(r * 0.3, r * 1.1, 4.5, UI.ACCENT)
	_beam_power = 0.25
	add_child(_beam)
	_title = label(text, 30, Color.WHITE, Color(0, 0, 0, 0.85))
	_title.position = Vector3(0.0, 2.15, back)
	add_child(_title)


# La statuina che gira sul piedistallo: il busto d'oro del lottatore, dal suo ritratto
# (il ritratto è piccolo; le strisce delle animazioni intere peserebbero troppo per tutti i lottatori insieme)
func _statue(parent: Node3D) -> void:
	var c: Dictionary = _game.get("characters", {}).get(zone_id, {})
	var tex: Texture2D = null
	var frame := Vector2.ZERO
	if c.get("portrait") is String:
		tex = HallFighter.texture("res://data/" + str(c.portrait))
		if tex != null:
			frame = tex.get_size()
	elif c.get("sprite") is Dictionary and c.sprite.has("path"):
		# un foglio piccolo (OrsoBlu): il primo fotogramma dell'idle
		tex = HallFighter.texture("res://data/" + str(c.sprite.path))
		frame = Vector2(float(c.sprite.frameWidth), float(c.sprite.frameHeight))
	if tex == null:
		# Bonobo: un cubetto rosso con gli occhi
		var cube := _box(Vector3(0.36, 0.62, 0.28), HallMaterials.neon(HallFighter.BONOBO_RED, 1.3))
		cube.position.y = 0.35
		parent.add_child(cube)
		for side in [-1.0, 1.0]:
			for face in [-1.0, 1.0]:
				var eye := _sphere(0.055, HallMaterials.neon(Color.WHITE, 1.4))
				eye.position = Vector3(side * 0.08, 0.5, face * 0.15)
				parent.add_child(eye)
		return
	var h := 0.8
	var nearest := str(c.get("sprite", {}).get("filter", "")) == "nearest" if c.get("sprite") is Dictionary else false
	var q := HallMaterials.fighter(tex, frame, frame.y, h / frame.y, HallMaterials.GOLD, 0, nearest)
	var m: ShaderMaterial = q.material_override
	m.set_shader_parameter("gild", 0.3) # un velo d'oro: una statuina, ma si riconosce chi è
	parent.add_child(q)


func _build_ready(text: String) -> void:
	color = UI.OK
	var ring := HallMaterials.ready_ring(radius * 2.25)
	ring.position.y = 0.025
	_pad_mat = ring.material_override
	_active_param = ""
	add_child(ring)
	# quattro colonnine d'oro attorno, con la gemma accesa
	_spin = Node3D.new()
	add_child(_spin)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		var post := _cylinder(0.08, 0.12, 1.0, HallMaterials.trim_gold())
		post.position = Vector3(cos(a) * (radius + 0.4), 0.5, sin(a) * (radius + 0.4))
		_spin.add_child(post)
		var gem := _sphere(0.13, HallMaterials.neon(UI.ACCENT, 3.0))
		gem.position = post.position + Vector3(0, 0.62, 0)
		_spin.add_child(gem)
	_beam = _light_beam(radius * 0.4, radius * 1.05, 8.0, UI.ACCENT)
	_beam_power = 0.3
	add_child(_beam)
	_title = label(text, 72, UI.ACCENT, Color(0.2, 0.08, 0.0, 0.9))
	_title.position.y = 2.1
	add_child(_title)
	_count = label("", 52, Color.WHITE, Color(0, 0, 0, 0.85))
	_count.position.y = 1.55
	add_child(_count)


func _build_trampoline(text: String) -> void:
	color = HallMaterials.BANANA
	var top := 0.22 # basso: chi ci sta sopra (a terra per il server) non ci affonda dentro
	_bounce = HallMaterials.trampoline(radius * 2.0)
	_bounce.position.y = top
	_bounce_mat = _bounce.material_override
	add_child(_bounce)
	# sotto il telo un anello e le gambe, non un cilindro pieno: il telo scende fino a 25 cm quando si salta
	var skirt := _ring_mesh(radius, 0.07, HallMaterials.dark_metal())
	skirt.position.y = top - 0.05
	add_child(skirt)
	for i in 6:
		var a := i * TAU / 6.0
		var leg := _cylinder(0.04, 0.05, top - 0.05, HallMaterials.dark_metal(), 6)
		leg.position = Vector3(cos(a) * radius, (top - 0.05) / 2.0, sin(a) * radius)
		add_child(leg)
	var neon := _ring_mesh(radius * 1.02, 0.03, HallMaterials.neon(HallMaterials.BANANA, 2.6, 0.6))
	neon.position.y = top - 0.06
	add_child(neon)
	_title = label(text, 32, Color.WHITE, Color(0, 0, 0, 0.8))
	_title.position.y = 1.2
	add_child(_title)


func _build_cage(text: String) -> void:
	color = BOT_ADD if kind == "botAdd" else BOT_REMOVE
	var pad := HallMaterials.pad(color, radius * 2.0)
	pad.position.y = 0.02
	_pad_mat = pad.material_override
	add_child(pad)
	var r := radius * 1.05
	var bars := 10
	for i in bars:
		var a := i * TAU / bars
		var bar := _cylinder(0.03, 0.03, 2.2, HallMaterials.dark_metal(), 6)
		bar.position = Vector3(cos(a) * r, 1.1, sin(a) * r)
		add_child(bar)
	_add_rim(r, 0.06, 0.05)
	var top := _ring_mesh(r, 0.07, HallMaterials.trim_gold())
	top.position.y = 2.2
	add_child(top)
	# l'ologramma del teletrasporto dentro la gabbia
	var field := _cylinder(r * 0.95, r * 0.95, 2.1, HallMaterials.hologram(color, 1.0), 20)
	(field.mesh as CylinderMesh).cap_top = false
	(field.mesh as CylinderMesh).cap_bottom = false
	field.position.y = 1.08
	add_child(field)
	# la corona di luci che si riempie mentre si sta fermi dentro
	_seg_on = HallMaterials.neon(color, 3.0)
	_seg_off = HallMaterials.neon(color.darkened(0.8), 0.6)
	_spin = Node3D.new()
	_spin.position.y = 2.36
	add_child(_spin)
	for i in 12:
		var a := i * TAU / 12.0
		var seg := _box(Vector3(0.16, 0.08, 0.08), _seg_off)
		seg.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		seg.rotation.y = -a + PI / 2.0
		_spin.add_child(seg)
		_segments.append(seg)
	_title = label(text, 38, color.lightened(0.45), Color(0, 0, 0, 0.85))
	_title.position.y = 2.85
	add_child(_title)


func _build_gong(text: String) -> void:
	color = UI.ACCENT
	var dark := HallMaterials.dark_metal()
	var r := clampf(radius, 0.8, 1.1)
	for side in [-1.0, 1.0]:
		var post := _box(Vector3(0.16, 2.9, 0.16), dark)
		post.position = Vector3(side * (r + 0.25), 1.45, -0.3)
		add_child(post)
		var cap := _sphere(0.14, HallMaterials.trim_gold())
		cap.position = Vector3(side * (r + 0.25), 2.96, -0.3)
		add_child(cap)
	var beam := _box(Vector3(r * 2.0 + 0.8, 0.18, 0.2), dark)
	beam.position = Vector3(0.0, 2.8, -0.3)
	add_child(beam)
	var plate := _cylinder(r + 0.5, r + 0.6, 0.12, HallMaterials.marble(), 20)
	plate.position.y = 0.06
	add_child(plate)
	# il disco appeso alla trave: ruota attorno al punto in alto
	_bounce = Node3D.new()
	_bounce.position = Vector3(0.0, 2.7, -0.3)
	add_child(_bounce)
	var disc := _cylinder(r * 0.85, r * 0.85, 0.07, HallMaterials.gong_material(r * 0.85), 32)
	disc.rotation.x = PI / 2.0
	disc.position.y = -r * 0.98
	_bounce_mat = disc.material_override
	_bounce.add_child(disc)
	var glow := HallMaterials.halo(Color("ff9a1f"), r * 3.0, 0.35)
	glow.position = Vector3(0.0, 1.7, -0.45)
	add_child(glow)
	_title = label(text, 40, UI.ACCENT, Color(0, 0, 0, 0.85))
	_title.position.y = 3.35
	add_child(_title)


func _build_throne(text: String) -> void:
	color = UI.ACCENT
	var gold := HallMaterials.trim_gold()
	var r := maxf(radius, 0.8)
	# la pedana a gradini di marmo chiaro coi bordi d'oro
	var step1 := _cylinder(r * 1.45, r * 1.5, 0.18, HallMaterials.marble(true), 24)
	step1.position.y = 0.09
	add_child(step1)
	_add_rim(r * 1.48, 0.035, 0.18)
	var step2 := _cylinder(r * 1.1, r * 1.15, 0.18, HallMaterials.marble(true), 24)
	step2.position.y = 0.27
	add_child(step2)
	_add_rim(r * 1.13, 0.035, 0.36)
	# il trono, dietro il punto dove ci si siede (verso il fondo della sala)
	var cushion_mat := HallMaterials.cushion_material()
	var seat := _box(Vector3(1.1, 0.25, 0.8), gold)
	seat.position = Vector3(0.0, 0.55, -0.3)
	add_child(seat)
	var cushion := _box(Vector3(0.95, 0.12, 0.7), cushion_mat)
	cushion.position = Vector3(0.0, 0.73, -0.27)
	add_child(cushion)
	var back := _box(Vector3(1.15, 2.1, 0.18), gold)
	back.position = Vector3(0.0, 1.6, -0.68)
	add_child(back)
	var back_velvet := _box(Vector3(0.82, 1.6, 0.05), cushion_mat)
	back_velvet.position = Vector3(0.0, 1.55, -0.57)
	add_child(back_velvet)
	for side in [-1.0, 1.0]:
		var arm := _box(Vector3(0.16, 0.4, 0.8), gold)
		arm.position = Vector3(side * 0.62, 0.82, -0.3)
		add_child(arm)
		var knob := _sphere(0.12, gold)
		knob.position = Vector3(side * 0.62, 1.04, 0.08)
		add_child(knob)
		var spire := _cylinder(0.0, 0.12, 0.5, gold, 6)
		spire.position = Vector3(side * 0.5, 2.9, -0.68)
		add_child(spire)
	_spin = HallFighter.crown(0.7)
	_spin.position = Vector3(0.0, 3.0, -0.68)
	add_child(_spin)
	var glow := HallMaterials.halo(HallMaterials.GOLD, 4.0, 0.45)
	glow.position = Vector3(0.0, 1.8, -0.9)
	add_child(glow)
	_beam = _light_beam(r * 0.4, r * 1.4, 9.0, HallMaterials.GOLD)
	_beam_power = 0.35
	add_child(_beam)
	_title = label(text, 42, UI.ACCENT, Color(0.2, 0.08, 0.0, 0.9))
	_title.position.y = 3.75
	add_child(_title)


func _build_generic(text: String) -> void:
	var pad := HallMaterials.pad(UI.ACCENT, radius * 2.0)
	_pad_mat = pad.material_override
	add_child(pad)
	_title = label(text, 40, Color.WHITE, Color(0, 0, 0, 0.8))
	_title.position.y = 1.2
	add_child(_title)


# --- basket e scacchi ---

# Il canestro: palo imbottito, braccio, tabellone di vetro con la cornice di luci, ferro arancione, retina e il
# tabellino col nome di chi ha segnato. Il ferro è nel punto della zona, alto rim_height; il tabellone sta dietro (-z)
func _build_hoop(text: String) -> void:
	color = Color("ff7a1a")
	var hall: Dictionary = _game.get("hall", {}) if _game.get("hall") is Dictionary else {}
	rim_height = float(hall.get("rimHeight", RIM_HEIGHT / CM)) * CM
	var k := rim_radius / 0.23 # tabellone in proporzione al ferro, come quello vero (1,8 x 1,05 per un ferro da 23 cm)
	var bw := 1.8 * k
	var bh := 1.05 * k
	var board_z := -float(hall.get("rimOffset", RIM_OFFSET / CM)) * CM
	var board_y := rim_height - 0.15 * k + bh / 2.0
	# il palo dietro, col piede imbottito nel colore del basket
	var pole_z := board_z - 1.1 * k
	var base := _box(Vector3(0.7 * k, 0.3, 0.9 * k), HallMaterials.dark_metal(true))
	base.position = Vector3(0.0, 0.15, pole_z - 0.1 * k)
	add_child(base)
	var pad_mat := HallMaterials.velvet(Color("d9541a"))
	var pole_h := board_y + bh * 0.25
	var pole := _cylinder(0.09 * k, 0.11 * k, pole_h, HallMaterials.metal(), 12)
	pole.position = Vector3(0.0, pole_h / 2.0, pole_z)
	add_child(pole)
	var sleeve := _cylinder(0.15 * k, 0.15 * k, 1.9, pad_mat, 12)
	sleeve.position = Vector3(0.0, 1.45, pole_z)
	add_child(sleeve)
	for dy in [-0.22, 0.22]:
		var arm := _box(Vector3(0.08 * k, 0.08 * k, absf(pole_z - board_z)), HallMaterials.metal(true))
		arm.position = Vector3(0.0, board_y + dy * bh, (pole_z + board_z) / 2.0 - 0.03)
		add_child(arm)
	# tabellone: vetro con le righe, cornice di metallo e una striscia di luce che lampeggia al canestro
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(bw, bh)
	glass.mesh = q
	glass.material_override = HallMaterials.glass_material(true)
	glass.position = Vector3(0.0, board_y, board_z)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	var frame_mat := HallMaterials.dark_metal(true)
	var t := 0.05 * k
	for side in [-1.0, 1.0]:
		var hb := _box(Vector3(bw + t * 2.0, t, t * 1.4), frame_mat)
		hb.position = Vector3(0.0, board_y + side * (bh / 2.0 + t / 2.0), board_z)
		add_child(hb)
		var vb := _box(Vector3(t, bh, t * 1.4), frame_mat)
		vb.position = Vector3(side * (bw / 2.0 + t / 2.0), board_y, board_z)
		add_child(vb)
		var led_h := _box(Vector3(bw + t * 2.0, 0.025, 0.025), HallMaterials.neon(color, 1.6))
		led_h.position = Vector3(0.0, board_y + side * (bh / 2.0 + t), board_z + t)
		add_child(led_h)
		_led.append(led_h)
		var led_v := _box(Vector3(0.025, bh + t * 2.0, 0.025), HallMaterials.neon(color, 1.6))
		led_v.position = Vector3(side * (bw / 2.0 + t), board_y, board_z + t)
		add_child(led_v)
		_led.append(led_v)
	var glow := HallMaterials.halo(color, bw * 1.8, 0.35)
	glow.position = Vector3(0.0, board_y, board_z - 0.1)
	add_child(glow)
	# il ferro con la staffa e la retina
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = rim_radius - 0.018
	tm.outer_radius = rim_radius + 0.018
	tm.rings = 32
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = HallMaterials.rim_material()
	ring.position.y = rim_height
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var bracket := _box(Vector3(0.16 * k, 0.04, 0.2), HallMaterials.rim_material())
	bracket.position = Vector3(0.0, rim_height - 0.01, board_z + 0.1)
	add_child(bracket)
	_net = HallMaterials.hoop_net(rim_radius, rim_radius * 1.9)
	_net.position.y = rim_height
	add_child(_net)
	# il tabellino sopra il tabellone: chi ha segnato l'ultimo canestro
	var sb_y := board_y + bh / 2.0 + 0.55 * k
	var panel := _box(Vector3(bw * 0.95, 0.75 * k, 0.12), HallMaterials.dark_metal(true))
	panel.position = Vector3(0.0, sb_y, board_z - 0.02)
	add_child(panel)
	var trim := _box(Vector3(bw * 0.95 + 0.06, 0.04, 0.14), HallMaterials.trim_gold())
	trim.position = Vector3(0.0, sb_y - 0.375 * k, board_z - 0.02)
	add_child(trim)
	var trim_top := trim.duplicate()
	trim_top.position.y = sb_y + 0.375 * k
	add_child(trim_top)
	_score_title = _flat_label(text.to_upper(), 34, UI.ACCENT, Vector3(0.0, sb_y + 0.2 * k, board_z + 0.05))
	_score_name = _flat_label("Fai canestro!", 44, Color.WHITE, Vector3(-0.15 * k, sb_y - 0.1 * k, board_z + 0.05))
	_score_points = _flat_label("", 60, UI.ACCENT, Vector3(bw * 0.36, sb_y - 0.08 * k, board_z + 0.05))
	_score_name.pixel_size = 0.005 * k
	_score_title.pixel_size = 0.004 * k
	_score_points.pixel_size = 0.005 * k
	# una luce dall'alto sul ferro
	_beam = _light_beam(0.2, 1.6, rim_height + 3.2, Color(1.0, 0.75, 0.45))
	_beam_power = 0.22
	add_child(_beam)


# Il mezzo campo: parquet laccato con le righe (HallMaterials.court_material) e il logo BONOBO.
# Senza canestro accanto il fondo è verso il fondo della sala (-z); con link() si mette sotto il canestro
func _build_court(text: String) -> void:
	color = Color("ff7a1a")
	_fade_labels = true
	var hall: Dictionary = _game.get("hall", {}) if _game.get("hall") is Dictionary else {}
	var three := float(hall.get("threePointRadius", THREE_POINT / CM)) * CM
	# il campo vero è 15 x 14 m: qui largo quanto serve perché l'arco da tre sia quello del server
	var w := three / FIBA_THREE * 15.0
	_court_size = Vector2(w, w * 14.0 / 15.0)
	_court = HallMaterials.court(_court_size, true)
	_court.name = "Parquet"
	add_child(_court)
	# bordo d'oro attorno al parquet
	_court_logo = Node3D.new()
	add_child(_court_logo)
	var logo := _flat_floor_label("BONOBO", 150, UI.PRIMARY, Color(1.0, 0.85, 0.4))
	logo.pixel_size = _court_size.x / 15.0 * 0.011
	_court_logo.add_child(logo)
	var sub := _flat_floor_label(text.to_upper(), 40, Color(1, 1, 1, 0.75), Color(0, 0, 0, 0.6))
	sub.pixel_size = _court_size.x / 15.0 * 0.009
	sub.position.z = _court_size.x / 15.0 * 1.1
	_court_logo.add_child(sub)
	for side in [-1.0, 1.0]:
		var ex := _box(Vector3(0.08, 0.04, _court_size.y + 0.16), HallMaterials.trim_gold())
		ex.position = Vector3(side * (_court_size.x / 2.0 + 0.04), 0.02, 0.0)
		ex.name = "EdgeX"
		_court.add_child(ex)
		var ez := _box(Vector3(_court_size.x + 0.16, 0.04, 0.08), HallMaterials.trim_gold())
		ez.position = Vector3(0.0, 0.02, side * (_court_size.y / 2.0 + 0.04))
		_court.add_child(ez)
	_place_court(position + Vector3(0.0, 0.0, -_court_size.y / 2.0 + FIBA_HOOP * _court_size.x / 15.0))


# Il parquet con il ferro (in coordinate della sala) a FIBA_HOOP dal fondo, girato verso il centro della zona
func _place_court(hoop: Vector3) -> void:
	if _court == null:
		return
	var s := _court_size.x / 15.0
	var to_center := Vector2(position.x - hoop.x, position.z - hoop.z)
	var dir := to_center.normalized() if to_center.length() > 0.01 else Vector2(0.0, 1.0)
	var yaw := atan2(dir.x, dir.y) # +z locale del parquet: dal canestro verso metà campo
	var mid := Vector2(hoop.x, hoop.z) + dir * (_court_size.y / 2.0 - FIBA_HOOP * s)
	_court.rotation.y = yaw
	_court.position = Vector3(mid.x - position.x, 0.012, mid.y - position.z).rotated(Vector3.UP, -rotation.y)
	# il logo tra l'arco da tre e la metà campo
	var logo_at := Vector2(hoop.x, hoop.z) + dir * ((FIBA_HOOP + FIBA_THREE) * s + (_court_size.y - (FIBA_HOOP + FIBA_THREE) * s) * 0.5)
	_court_logo.position = Vector3(logo_at.x - position.x, 0.02, logo_at.y - position.z)
	_court_logo.rotation.y = 0.0 # le scritte si leggono dalla telecamera, comunque sia girato il campo


# La scacchiera gigante: 8 x 8 caselle di marmo con la cornice (HallMaterials.chessboard), i bordi d'oro,
# le lettere e i numeri sul bordo, quattro colonnine con la gemma agli angoli. Bianco verso la telecamera (+z)
func _build_chessboard(text: String) -> void:
	color = Color("b06bff")
	_fade_labels = true
	var hall: Dictionary = _game.get("hall", {}) if _game.get("hall") is Dictionary else {}
	var square := float(hall.get("chessSquare", radius * 2.0 / 8.0 / CM)) * CM
	var inner := square * 8.0
	var side := inner / (1.0 - 2.0 * BOARD_BORDER)
	var slab := _box(Vector3(side + 0.1, 0.06, side + 0.1), HallMaterials.dark_metal(true))
	slab.position.y = -0.02 # appena sotto: i pezzi stanno a y = 0 per il server
	add_child(slab)
	var board := HallMaterials.chessboard(side, BOARD_BORDER)
	board.position.y = 0.012
	add_child(board)
	_board_frame_mat = HallMaterials.neon(color, 1.4)
	for s in [-1.0, 1.0]:
		var gx := _box(Vector3(0.07, 0.05, side + 0.14), HallMaterials.trim_gold())
		gx.position = Vector3(s * (side / 2.0 + 0.05), 0.02, 0.0)
		add_child(gx)
		var gz := _box(Vector3(side + 0.14, 0.05, 0.07), HallMaterials.trim_gold())
		gz.position = Vector3(0.0, 0.02, s * (side / 2.0 + 0.05))
		add_child(gz)
		var nx := _box(Vector3(0.03, 0.02, side + 0.2), _board_frame_mat)
		nx.position = Vector3(s * (side / 2.0 + 0.11), 0.01, 0.0)
		add_child(nx)
		var nz := _box(Vector3(side + 0.2, 0.02, 0.03), _board_frame_mat)
		nz.position = Vector3(0.0, 0.01, s * (side / 2.0 + 0.11))
		add_child(nz)
	# lettere delle colonne (a-h, da sinistra) e numeri delle traverse (1 davanti, verso la telecamera)
	var edge := inner / 2.0 + side * BOARD_BORDER / 2.0
	for i in 8:
		var off := -inner / 2.0 + square * (i + 0.5)
		for s in [-1.0, 1.0]:
			var f := _flat_floor_label("abcdefgh"[i], 64, Color(1.0, 0.85, 0.45), Color(0.1, 0.03, 0.0, 0.8))
			f.pixel_size = side * BOARD_BORDER * 0.011
			f.position = Vector3(off, 0.03, s * edge)
			add_child(f)
			var r := _flat_floor_label(str(8 - i), 64, Color(1.0, 0.85, 0.45), Color(0.1, 0.03, 0.0, 0.8))
			r.pixel_size = f.pixel_size
			r.position = Vector3(s * edge, 0.03, off)
			add_child(r)
	# colonnine agli angoli con la gemma viola
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var at := Vector3(cx * (side / 2.0 + 0.3), 0.0, cz * (side / 2.0 + 0.3))
			var post := _cylinder(0.1, 0.14, 1.2, HallMaterials.marble(), 10)
			post.position = at + Vector3(0, 0.6, 0)
			add_child(post)
			var cap := _cylinder(0.2, 0.14, 0.1, HallMaterials.trim_gold(), 10)
			cap.position = at + Vector3(0, 1.25, 0)
			add_child(cap)
			var gem := _sphere(0.14, HallMaterials.neon(color, 3.0))
			gem.position = at + Vector3(0, 1.42, 0)
			add_child(gem)
			var gh := HallMaterials.halo(color, 1.2, 0.5)
			gh.position = gem.position
			add_child(gh)
	_title = label(text, 44, Color(1.0, 0.9, 0.6), Color(0.15, 0.05, 0.25, 0.9))
	_title.position = Vector3(0.0, 1.6, -side / 2.0 - 0.4)
	add_child(_title)
	_beam = _light_beam(side * 0.15, side * 0.62, 9.0, Color(0.85, 0.7, 1.0))
	_beam_power = 0.18
	add_child(_beam)


# La rastrelliera dei palloni (i palloni stanno a terra, per il server): una pedana bassa con due binari,
# il cartello e una striscia arancione accesa
func _build_rack(text: String) -> void:
	color = Color("ff7a1a")
	_fade_labels = true
	var w := radius * 2.2
	var plate := _box(Vector3(w, 0.03, 0.62), HallMaterials.dark_metal(true))
	plate.position.y = 0.0
	add_child(plate)
	for side in [-1.0, 1.0]:
		var rail := _box(Vector3(w, 0.06, 0.04), HallMaterials.metal(true))
		rail.position = Vector3(0.0, 0.05, side * 0.14)
		add_child(rail)
		var post := _box(Vector3(0.06, 0.9, 0.06), HallMaterials.dark_metal(true))
		post.position = Vector3(side * (w / 2.0 - 0.03), 0.45, -0.3)
		add_child(post)
	var sign := _box(Vector3(w, 0.32, 0.05), HallMaterials.dark_metal(true))
	sign.position = Vector3(0.0, 0.95, -0.3)
	add_child(sign)
	var neon := _box(Vector3(w - 0.1, 0.03, 0.03), HallMaterials.neon(color, 2.2, 0.6))
	neon.position = Vector3(0.0, 0.77, -0.27)
	add_child(neon)
	var l := _flat_label(text.to_upper(), 40, UI.ACCENT, Vector3(0.0, 0.95, -0.27))
	l.pixel_size = 0.004
	var pool := HallMaterials.light_pool(color, w * 1.4, 0.35)
	pool.position.y = 0.02
	add_child(pool)


# Una scritta dritta (non girata verso la telecamera) che guarda +z: il tabellino del canestro
func _flat_label(text: String, size: int, col: Color, at: Vector3) -> Label3D:
	var l := label(text, size, col, Color(0, 0, 0, 0.85))
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.position = at
	add_child(l)
	return l


# Una scritta dipinta a terra, si legge dalla telecamera (+z)
static func _flat_floor_label(text: String, size: int, col: Color, outline: Color) -> Label3D:
	var l := label(text, size, col, outline)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.render_priority = 0
	l.outline_render_priority = -1
	l.rotation.x = -PI / 2.0
	return l


# --- pezzi ---

static func label(text: String, size: int, col: Color, outline: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UI.font(UI.WEIGHT_BOLD)
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = maxi(8, size / 5)
	l.modulate = col
	l.outline_modulate = outline
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.outline_render_priority = 4
	return l


static func set_param(mat: Material, param: String, value: Variant) -> void:
	if mat is ShaderMaterial and param != "":
		(mat as ShaderMaterial).set_shader_parameter(param, value)


func _add_rim(r: float, thick: float, y: float) -> void:
	var rim := _ring_mesh(r, thick, HallMaterials.trim_gold())
	rim.position.y = y
	add_child(rim)


static func _cylinder(top: float, bottom: float, h: float, mat: Material, segments := 16) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _ring_mesh(r: float, thick: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r + thick
	t.rings = 40
	t.ring_segments = 6
	m.mesh = t
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _sphere(r: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	m.mesh = s
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# Un fascio di luce dall'alto (HallMaterials.god_ray): la lampada a h metri, il cono scende fino a terra
static func _light_beam(top: float, bottom: float, h: float, col: Color) -> MeshInstance3D:
	var m := HallMaterials.god_ray(h, top, bottom, col)
	m.position.y = h
	m.visible = false
	return m
