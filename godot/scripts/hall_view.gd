# La sala d'attesa 3D (E?): prima delle partite ci si ritrova in una sala vera e si sceglie camminando.
# Qui si disegna e basta: dove sono tutti, chi vota cosa, il conto alla rovescia li decide il server
# (src/shared/hall.ts) e arrivano negli HallSnapshot. I lottatori sono figurine 2D in un mondo 3D (Paper Mario).
# Coordinate dello snapshot in centimetri (x a destra, z verso la telecamera, y in alto); qui 1 unità = 1 metro.
# Leggera per WebGL2 e telefoni (gl_compatibility): niente ombre vere, poche luci, emissivi e trucchi additivi.
extends Node3D

const HallBuffer := preload("res://scripts/hall_buffer.gd")
const HallFighter := preload("res://scripts/hall_fighter.gd")
const HallZone := preload("res://scripts/hall_zone.gd")
const HallFx := preload("res://scripts/hall_fx.gd")
const HallIcons := preload("res://scripts/hall_icons.gd")
const StagePreview := preload("res://scripts/stage_preview.gd")

const CM := 0.01 # metri per centimetro dello snapshot
const DEFAULT_WIDTH := 3000.0 # HALL.width, cm: se lo snapshot non lo dice
const DEFAULT_DEPTH := 1800.0
const BOT_HOLD_MS := 1200.0 # HALL.botHoldMs: quanto si sta fermi nella gabbia per chiamare un bot
# Telecamera: dall'alto di tre quarti, dietro al proprio lottatore
const CAM_HEIGHT := 7.8 # metri sopra il punto seguito
const CAM_BACK := 11.2 # metri verso lo schermo
const CAM_AHEAD := 3.0 # guarda un po' oltre il lottatore, verso il fondo: si vede il maxischermo
const CAM_FOV := 46.0
const CAM_FOLLOW := 3.5 # quanto in fretta insegue (1/s)
const WALL_HEIGHT := 9.0
const SPOTS := 5 # fari che girano sopra la sala
const FRAME_RADIUS := 10.0 # metri: la telecamera si allarga per tenere dentro chi è entro questa distanza da me
const MODE_NAMES := {"ffa": "Tutti contro tutti", "teams": "A squadre", "flag": "Ruba bandiera", "race": "Corsa"}

var my_id := ""
var game: Dictionary
var buffer := HallBuffer.new()
var camera: Camera3D
var fx: Node3D

var _snap: Dictionary = {}
var _width := DEFAULT_WIDTH * CM # metri
var _depth := DEFAULT_DEPTH * CM
var _room: Node3D # pavimento, pareti, maxischermo: si rifà solo se cambiano le misure
var _room_size := Vector2.ZERO
var _floor_mat: Material
var _medallion := Vector2.ZERO # il rosone del pavimento sta sotto il cerchio dei pronti
var _zones_root: Node3D
var _zones := {} # "kind/id" -> HallZone
var _zones_sig := ""
var _labels := {} # "mode/ffa" -> "Tutti contro tutti", dalle zone
var _fighters := {} # id -> HallFighter
var _fighters_root: Node3D
var _sampled := {} # id -> stato interpolato di questo frame
var _previews := {} # id dell'arena -> Texture2D dell'anteprima
var _pending: Array = [] # eventi di giocatori non ancora arrivati nello snapshot (entra, bot)
var _bot_hold := {} # chiave della zona -> ms fermi dentro
var _t := 0.0
var _now := 0.0
# Telecamera
var _focus := Vector3.ZERO
var _zoom := 1.0
var _shake := 0.0
var _swoop := -1.0 # >= 0: la ripresa del via, da 0 a 1
var _cam_ready := false
# Luci
var _spots: Array = [] # [{ pivot, cone, pool, phase, color }]
var _key_light: DirectionalLight3D
var _pulse := 0.0 # lampo di tutte le luci (conto alla rovescia, gong)
var _countdown_left := -1.0 # ms al via, -1 = niente conto
var _countdown_at := 0.0
var _go_at := -1.0
# Maxischermo e tabellone
var _screen_vp: SubViewport
var _screen_title: Label
var _screen_main: Label
var _screen_sub: Label
var _screen_big: Label
var _screen_sig := ""
var _board_vp: SubViewport
var _board_rows: VBoxContainer
var _board_sig := "-"
var _flash_text := "" # una scritta sul maxischermo per un attimo (GONG!, ANNULLATO)
var _flash_until := 0.0


func setup(game_data: Dictionary, my_id_: String) -> void:
	game = game_data
	my_id = my_id_
	buffer.own_id = my_id
	if Phone.active:
		HallMaterials.lite = true # telefoni: shader senza le ottave di rumore più fini
	_build_environment()
	_fighters_root = Node3D.new()
	_fighters_root.name = "Fighters"
	_zones_root = Node3D.new()
	_zones_root.name = "Zones"
	add_child(_zones_root)
	add_child(_fighters_root)
	fx = HallFx.new()
	fx.name = "Fx"
	fx.calm = Access.calm
	add_child(fx)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.near = 0.2
	camera.far = 260.0 # il fondale stellato è una sfera di 120 m di raggio
	camera.current = true # la sala ha la sua telecamera: main.gd la aggiunge e poi chiama setup
	add_child(camera)
	_build_room(Vector2(_width, _depth))
	_place_camera(0.0)


func _ready() -> void:
	if camera != null:
		camera.make_current()
	visibility_changed.connect(func():
		if camera != null and is_visible_in_tree():
			camera.make_current())


func on_snapshot(snap: Dictionary) -> void:
	if game.is_empty():
		return
	_snap = snap
	var players: Array = snap.get("players", []) if snap.get("players") is Array else []
	buffer.own_id = my_id
	buffer.push(float(snap.get("t", 0.0)), float(Time.get_ticks_msec()), players)
	var size := Vector2(float(snap.get("width", DEFAULT_WIDTH)), float(snap.get("depth", DEFAULT_DEPTH))) * CM
	if size != _room_size:
		_width = size.x
		_depth = size.y
		_build_room(size)
	_sync_zones(snap.get("zones", []) if snap.get("zones") is Array else [])
	# chi non c'è più se ne va
	var ids := {}
	for p in players:
		ids[str(p.get("id", ""))] = true
	for id in _fighters.keys():
		if not ids.has(id):
			_fighters[id].queue_free()
			_fighters.erase(id)
	var cd: Variant = snap.get("countdownMs")
	if cd != null:
		_countdown_left = float(cd)
		_countdown_at = float(Time.get_ticks_msec())
	elif _countdown_left >= 0.0:
		_countdown_left = -1.0
	_update_screen()
	_update_board(snap.get("board", []) if snap.get("board") is Array else [])
	# gli eventi rimasti in attesa del giocatore (entrato o bot appena chiamato)
	if not _pending.is_empty():
		var again := _pending
		_pending = []
		for e in again:
			if ids.has(str(e.get("id", ""))) or int(e.get("_tries", 0)) >= 3:
				_fx_for(e)
			else:
				e["_tries"] = int(e.get("_tries", 0)) + 1
				_pending.append(e)


func on_event(e: Dictionary) -> void:
	if game.is_empty():
		return
	var id := str(e.get("id", ""))
	var type := str(e.get("type", ""))
	if type in ["join", "bot"] and id != "" and not _fighters.has(id) and _player(id).is_empty():
		_pending.append(e.duplicate()) # il nuovo arriva nello snapshot che segue
		return
	_fx_for(e)


# --- effetti degli eventi ---

func _fx_for(e: Dictionary) -> void:
	var id := str(e.get("id", ""))
	var at := _feet(id)
	var mine := id == my_id
	match str(e.get("type", "")):
		"hop":
			fx.dust(at, 8)
		"land":
			fx.dust(at, 12, Color(0.85, 0.8, 0.95, 0.5), 0.9)
			if _fighters.has(id):
				_fighters[id].squash()
		"bounce":
			var z: Node3D = _nearest_zone("trampoline", at)
			if z != null:
				z.bang()
			if _fighters.has(id):
				_fighters[id].squash()
				fx.trail(_fighters[id], _color_of(id).lightened(0.3), 1.0)
			fx.ring_wave(at, Color("4ad9ff"), 1.6, 0.45)
		"shove":
			fx.ring_wave(at + Vector3(0, 0.6, 0), Color(1, 1, 1, 0.9), float(game.get("hall", {}).get("shoveRadius", 170.0)) * CM * 1.3, 0.35)
			fx.dust(at, 14, Color(1, 1, 1, 0.5), 1.4)
			var targets: Array = e.get("targets", []) if e.get("targets") is Array else []
			for t in targets:
				var tp := _feet(str(t))
				fx.sparkles(tp + Vector3(0, 1.2, 0), Color.WHITE, 10, 0.5)
				if str(t) == my_id:
					_kick(0.35)
			if mine and not targets.is_empty():
				_kick(0.15)
		"vote":
			var what := str(e.get("what", ""))
			var key := "%s/%s" % [what, str(e.get("value", ""))]
			var z: Node3D = _zones.get(key)
			if z != null:
				z.bang()
				var zp: Vector3 = z.position
				fx.beam(zp, z.color, 8.0, 0.9, z.radius * 0.6)
				fx.sparkles(zp + Vector3(0, 0.3, 0), z.color.lightened(0.3), 24, 0.8)
				fx.floater(zp + Vector3(0, 2.9, 0), "+1", z.color.lightened(0.4), 80)
			_pulse = maxf(_pulse, 0.3)
		"pick":
			fx.smoke(at)
			fx.sparkles(at + Vector3(0, 0.5, 0), UI.ACCENT, 16, 0.6)
			if _fighters.has(id):
				_fighters[id].pop()
			var z: Node3D = _zones.get("fighter/%s" % str(e.get("characterId", "")))
			if z != null:
				z.bang()
		"gong":
			var z: Node3D = _zones.get(_first_key("gong"))
			var gp: Vector3 = z.position + Vector3(0, 1.7, 0.1) if z != null else at
			if z != null:
				z.bang()
			fx.ring_wave(gp, Color("ffcf4a"), 7.0, 0.9, true, 0.04)
			fx.ring_wave(gp, Color("ff9a1f"), 4.5, 0.7, true, 0.06)
			fx.ring_wave(Vector3(gp.x, 0.0, gp.z), Color("ffcf4a"), 9.0, 1.1)
			fx.floater(gp + Vector3(0, 1.4, 0), "GONG!", UI.ACCENT, 120, 1.5, 1.4)
			_kick(0.7)
			_pulse = 1.0
			_flash("GONG!")
		"throne":
			var z: Node3D = _zones.get(_first_key("throne"))
			var tp: Vector3 = z.position if z != null else at
			if z != null:
				z.bang()
			fx.beam(tp, UI.ACCENT, 10.0, 1.6, 1.4)
			fx.sparkles(tp + Vector3(-0.8, 0.4, 0), UI.ACCENT, 50, 1.2)
			fx.sparkles(tp + Vector3(0.8, 0.4, 0), UI.ACCENT, 50, 1.2)
			fx.floater(tp + Vector3(0, 4.2, 0), "%s è sul trono!" % _name_of(id), UI.ACCENT, 64, 0.8, 1.8)
			_pulse = maxf(_pulse, 0.6)
		"bot":
			if bool(e.get("added", false)):
				fx.beam(at, Color("2ecc71"), 12.0, 1.3, 0.8)
				fx.sparkles(at + Vector3(0, 0.4, 0), Color("8fffb0"), 30, 0.9)
			else:
				fx.beam(at, Color("e74c3c"), 12.0, 1.0, 0.8)
				fx.smoke(at, Color(1.0, 0.6, 0.6, 0.8))
		"join":
			fx.beam(at, _color_of(id), 12.0, 1.2, 0.8)
			fx.floater(at + Vector3(0, 2.8, 0), "Ciao %s!" % _name_of(id), Color.WHITE, 56)
		"leave":
			fx.smoke(at)
		"countdown":
			_countdown_left = float(e.get("ms", 5000.0))
			_countdown_at = float(Time.get_ticks_msec())
			_pulse = 1.0
			var z: Node3D = _zones.get(_first_key("ready"))
			if z != null:
				z.bang()
				fx.ring_wave(z.position, UI.OK, z.radius * 2.0, 0.8)
		"cancel":
			_countdown_left = -1.0
			_flash("ANNULLATO")
			_pulse = 0.5
		"go":
			_go_at = _t
			_swoop = 0.0
			_flash("SI PARTE!")
			_flash_until += 3000.0 # resta fino a quando la sala si chiude
			_pulse = 1.0
			# quattro cannoni attorno a dove guarda la telecamera, così i coriandoli si vedono tutti
			for side in [-1.0, 1.0]:
				fx.confetti(_focus + Vector3(side * 7.0, 0.3, -4.0), Vector3(-side * 0.45, 1.0, 0.25))
				fx.confetti(_focus + Vector3(side * 6.0, 0.3, 3.0), Vector3(-side * 0.45, 1.0, -0.3))
			_countdown_left = -1.0
			fx.sparkles(_focus + Vector3(0, 0.5, 0), UI.ACCENT, 60, 1.6)


func _kick(amount: float) -> void:
	_shake = maxf(_shake, amount * (0.2 if Access.calm else 1.0))


func _flash(text: String) -> void:
	_flash_text = text
	_flash_until = float(Time.get_ticks_msec()) + 1400.0
	_screen_sig = "" # si ridisegna subito


# Dove sono i piedi di un giocatore, metri (l'ultimo stato disegnato, o l'ultimo snapshot)
func _feet(id: String) -> Vector3:
	if _fighters.has(id):
		var f: Node3D = _fighters[id]
		return f.position
	var p := _player(id)
	if p.is_empty():
		return _focus
	return Vector3(float(p.get("x", 0.0)), 0.0, float(p.get("z", 0.0))) * CM


func _player(id: String) -> Dictionary:
	for p in _snap.get("players", []):
		if p is Dictionary and str(p.get("id", "")) == id:
			return p
	return {}


func _name_of(id: String) -> String:
	return str(_player(id).get("name", ""))


func _color_of(id: String) -> Color:
	var p := _player(id)
	return Access.color(p.get("color", 0xffcf4a)) if not p.is_empty() else UI.ACCENT


func _first_key(kind: String) -> String:
	for k in _zones:
		if _zones[k].kind == kind:
			return k
	return ""


func _nearest_zone(kind: String, at: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for k in _zones:
		var z: Node3D = _zones[k]
		if z.kind != kind:
			continue
		var d := Vector2(z.position.x - at.x, z.position.z - at.z).length()
		if d < bd:
			bd = d
			best = z
	return best


# --- ogni frame ---

func _process(delta: float) -> void:
	if game.is_empty():
		return
	_t += delta
	_now = float(Time.get_ticks_msec())
	_sampled = buffer.sample_all(_now)
	var yaw := camera.rotation.y if camera != null else 0.0
	for id in _sampled:
		var p: Dictionary = _sampled[id]
		if not _fighters.has(id):
			var f: Node3D = HallFighter.new()
			f.name = "F_" + str(id).validate_node_name()
			_fighters_root.add_child(f)
			f.setup(game, p, id == my_id)
			_fighters[id] = f
		_fighters[id].apply(p, _now, yaw, delta)
	_tick_zones(delta)
	_tick_lights(delta)
	_place_camera(delta)
	if _countdown_left >= 0.0 or _now < _flash_until or _screen_sig == "":
		_update_screen()


func _tick_zones(delta: float) -> void:
	var votes: Dictionary = _snap.get("votes", {}) if _snap.get("votes") is Dictionary else {}
	var mode_votes: Dictionary = votes.get("mode", {}) if votes.get("mode") is Dictionary else {}
	var stage_votes: Dictionary = votes.get("stage", {}) if votes.get("stage") is Dictionary else {}
	var leading: Dictionary = _snap.get("leading", {}) if _snap.get("leading") is Dictionary else {}
	var humans := 0
	for id in _sampled:
		if not _sampled[id].get("bot", false) and not _sampled[id].get("away", false):
			humans += 1
	var hold_ms := float(game.get("hall", {}).get("botHoldMs", BOT_HOLD_MS))
	var me: Variant = _sampled.get(my_id)
	var my_pos := Vector2(float(me.x), float(me.z)) * CM if me != null else Vector2(INF, INF)
	var charges := {} # id -> [carica, colore]: chi è fermo su una zona da votare
	for key in _zones:
		var z: Node3D = _zones[key]
		var inside := 0
		var still := false
		for id in _sampled:
			var p: Dictionary = _sampled[id]
			var d := Vector2(float(p.x) * CM - z.position.x, float(p.z) * CM - z.position.z).length()
			if d <= z.radius and float(p.get("y", 0.0)) < 60.0:
				inside += 1
				if not p.get("bot", false) and not p.get("moving", false):
					still = true
				if z.votable and not p.get("bot", false):
					charges[id] = [_vote_charge(p, z), z.color]
		var n := 0
		var lead := false
		match z.kind:
			"mode":
				n = int(mode_votes.get(z.zone_id, 0))
				lead = str(leading.get("mode", "")) == z.zone_id
			"stage":
				n = int(stage_votes.get(z.zone_id, 0))
				lead = str(leading.get("stageId", "")) == z.zone_id
			"botAdd", "botRemove":
				# la corona di luci si riempie mentre qualcuno ci sta fermo (il server conta lo stesso tempo)
				var held: float = _bot_hold.get(key, 0.0)
				held = held + delta * 1000.0 if still else 0.0
				_bot_hold[key] = held
				z.progress = clampf(held / hold_ms, 0.0, 1.0)
		z.tick(delta, inside, n, lead, humans, my_pos.distance_to(Vector2(z.position.x, z.position.z)))
	for id in _fighters:
		var f: Node3D = _fighters[id]
		var c: Array = charges.get(id, [0.0, Color.WHITE])
		# il cerchio sale piano mentre ci si ferma, e scende subito quando si esce
		f.charge = move_toward(f.charge, c[0], delta * (4.0 if c[0] > f.charge else 8.0))
		f.charge_color = c[1]


# Quanto è carico il voto di un giocatore fermo su una zona: pieno se il voto è già suo, se no sale fermandosi
# (il server conta il voto solo sotto HALL.voteMaxSpeed); la gabbia dei bot segue il suo tempo
func _vote_charge(p: Dictionary, z: Node3D) -> float:
	var done := false
	match z.kind:
		"mode": done = str(p.get("modeVote", "")) == z.zone_id
		"stage": done = str(p.get("stageVote", "")) == z.zone_id
		"fighter": done = str(p.get("characterId", "")) == z.zone_id
		"botAdd", "botRemove": return z.progress
	if done:
		return 1.0
	return 0.0 if p.get("moving", false) else 0.85


func _tick_lights(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta * 1.5)
	var counting := _countdown_left >= 0.0
	var beat := 0.0
	if counting:
		var left := _countdown_left - (_now - _countdown_at)
		beat = pow(1.0 - fposmod(left, 1000.0) / 1000.0, 3.0) # un colpo di luce a ogni secondo
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		var pivot: Node3D = s.pivot
		var ph: float = s.phase
		var speed := 0.35 if not counting else 0.9
		# ogni faro disegna un otto lento sul pavimento
		pivot.rotation = Vector3(sin(_t * speed + ph) * 0.42, 0.0, cos(_t * speed * 0.7 + ph * 1.3) * 0.48)
		var col: Color = s.color
		if counting:
			col = col.lerp(UI.ACCENT if i % 2 == 0 else UI.PRIMARY, 0.7)
		var k := 0.55 + _pulse * 0.6 + beat * 0.5
		HallZone.set_param(s.cone.material_override, "color", col)
		HallZone.set_param(s.cone.material_override, "intensity", 0.16 * k)
		# la pozza di luce dove il cono tocca terra
		# (coordinate della sala: pivot e pozza stanno entrambi in _room, senza usare global_*, che fuori dall'albero non va)
		var top: Vector3 = pivot.position
		var dir: Vector3 = -pivot.transform.basis.y
		if dir.y < -0.1:
			var hit := top + dir * (top.y / -dir.y)
			s.pool.position = Vector3(hit.x, 0.03, hit.z)
		HallZone.set_param(s.pool.material_override, "color", col)
		HallZone.set_param(s.pool.material_override, "intensity", 0.35 * k)
	if _key_light != null:
		_key_light.light_energy = 0.9 + _pulse * 0.5 + beat * 0.3


# La telecamera segue il proprio lottatore da dietro e dall'alto; se gli altri sono lontani si allarga per tenerli
func _place_camera(delta: float) -> void:
	if camera == null:
		return
	var target := Vector3(0.0, 0.0, _depth * 0.15)
	var me: Variant = _sampled.get(my_id)
	if me != null:
		target = Vector3(float(me.x), 0.0, float(me.z)) * CM
	# tutti dentro l'inquadratura: quanto è lontano il più lontano dal punto seguito
	var spread := 0.0
	var center := target
	var n := 1
	for id in _sampled:
		if id == my_id or _sampled[id].get("away", false):
			continue
		var p := Vector3(float(_sampled[id].x), 0.0, float(_sampled[id].z)) * CM
		if p.distance_to(target) > FRAME_RADIUS:
			continue # chi è dall'altra parte della sala non rimpicciolisce tutto
		center += p
		n += 1
		spread = maxf(spread, maxf(absf(p.x - target.x) * 0.75, absf(p.z - target.z)))
	center /= float(n)
	var far := clampf((spread - 6.0) / 12.0, 0.0, 1.0)
	target = target.lerp(center, far * 0.3)
	var half := Vector2(_width / 2.0, _depth / 2.0)
	target.x = clampf(target.x, -half.x + 2.0, half.x - 2.0)
	target.z = clampf(target.z, -half.y + 3.0, half.y - 1.0)
	var zoom := 1.0 + far * 0.35
	var k := 1.0 - exp(-delta * CAM_FOLLOW) if _cam_ready else 1.0
	_cam_ready = true
	_focus = _focus.lerp(target, k)
	_zoom = lerpf(_zoom, zoom, k)
	# leggero dondolio da gru, e la ripresa del via: si alza e gira attorno
	var sway := Vector3(sin(_t * 0.31) * 0.5, sin(_t * 0.23) * 0.2, 0.0)
	var orbit := 0.0
	var lift := 0.0
	if _swoop >= 0.0:
		_swoop = minf(1.0, _swoop + delta / 1.8)
		var e := _swoop * _swoop * (3.0 - 2.0 * _swoop)
		orbit = e * 0.5
		lift = e * 3.0
	var back := Vector3(sin(orbit) * CAM_BACK, CAM_HEIGHT + lift, cos(orbit) * CAM_BACK) * _zoom
	var look := _focus + Vector3(0.0, 1.0, -CAM_AHEAD)
	var pos := _focus + back + sway
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.2)
		var s := _shake * _shake * 0.6
		pos += Vector3(randf_range(-s, s), randf_range(-s, s), 0.0)
		look += Vector3(randf_range(-s, s), randf_range(-s, s), 0.0) * 0.5
	camera.transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos) # anche fuori dall'albero


# --- zone ---

func _sync_zones(zones: Array) -> void:
	var sig := ""
	for z in zones:
		if z is Dictionary:
			sig += "%s/%s/%d/%d/%d/%s;" % [z.get("kind", ""), z.get("id", ""), int(z.get("x", 0)), int(z.get("z", 0)), int(z.get("r", 0)), z.get("label", "")]
	if sig == _zones_sig:
		return
	_zones_sig = sig
	for c in _zones_root.get_children():
		c.queue_free()
	_zones.clear()
	_labels.clear()
	for z in zones:
		if not (z is Dictionary):
			continue
		var kind := str(z.get("kind", ""))
		var id := str(z.get("id", ""))
		var node: Node3D = HallZone.new()
		node.setup(z, game, _preview_for(id) if kind == "stage" else null)
		_zones_root.add_child(node)
		_zones["%s/%s" % [kind, id]] = node
		_labels["%s/%s" % [kind, id]] = str(z.get("label", id))
		if kind == "ready":
			_medallion = Vector2(node.position.x, node.position.z)
			HallZone.set_param(_floor_mat, "medallion_center", _medallion)


# L'anteprima di un'arena per il suo portale: l'immagine disegnata se c'è, se no la piantina in un SubViewport
func _preview_for(stage_id: String) -> Texture2D:
	if _previews.has(stage_id):
		return _previews[stage_id]
	var spec: Dictionary = game.get("stages", {}).get(stage_id, {}) if game.get("stages") is Dictionary else {}
	var tex: Texture2D = null
	if not spec.is_empty():
		tex = StagePreview.preview_texture(spec)
		if tex == null:
			var vp := SubViewport.new()
			vp.size = Vector2i(320, 180)
			vp.transparent_bg = false
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			var pv: Control = StagePreview.new()
			pv.spec = spec
			pv.size = Vector2(320, 180)
			vp.add_child(pv)
			add_child(vp)
			tex = vp.get_texture()
	_previews[stage_id] = tex
	return tex


# --- ambiente, sala, maxischermo, tabellone ---

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := HallMaterials.env()
	we.environment = env
	add_child(we)
	_key_light = DirectionalLight3D.new()
	_key_light.rotation_degrees = Vector3(-52.0, 18.0, 0.0)
	_key_light.light_color = Color(1.0, 0.93, 0.85)
	_key_light.light_energy = 0.9
	_key_light.shadow_enabled = false
	add_child(_key_light)
	# controluce viola e azzurra ai lati: i bordi dei pezzi d'oro e di metallo brillano
	for side in [-1.0, 1.0]:
		var o := OmniLight3D.new()
		o.light_color = Color("b06bff") if side < 0 else Color("4ad9ff")
		o.light_energy = 2.2
		o.omni_range = 22.0
		o.omni_attenuation = 1.2
		o.position = Vector3(side * 11.0, 6.5, -6.0)
		add_child(o)


func _build_room(size: Vector2) -> void:
	_room_size = size
	if _room != null:
		_room.queue_free()
	_spots.clear()
	_room = Node3D.new()
	_room.name = "Room"
	add_child(_room)
	move_child(_room, 0)
	var w := size.x
	var d := size.y
	# fondale stellato oltre le pareti, e marmo scuro attorno al pavimento: il bordo della sala non dà sul vuoto
	_room.add_child(HallMaterials.backdrop())
	var apron := MeshInstance3D.new()
	var am := PlaneMesh.new()
	am.size = Vector2(w + 40.0, d + 40.0)
	apron.mesh = am
	apron.material_override = HallMaterials.marble()
	apron.position.y = -0.03
	_room.add_child(apron)
	# il pavimento lucido della sala
	var ground := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(w + 2.0, d + 2.0)
	ground.mesh = fm
	_floor_mat = HallMaterials.floor_material(2.0, 3.2, _medallion)
	ground.material_override = _floor_mat
	_room.add_child(ground)
	# bordo d'oro e neon attorno al pavimento
	var gold := HallMaterials.trim_gold()
	var edge_neon := HallMaterials.neon(UI.ACCENT)
	for side in [-1.0, 1.0]:
		_room.add_child(_bar(Vector3(w + 2.4, 0.1, 0.2), Vector3(0, 0.05, side * (d / 2.0 + 1.1)), gold))
		_room.add_child(_bar(Vector3(0.2, 0.1, d + 2.4), Vector3(side * (w / 2.0 + 1.1), 0.05, 0), gold))
		_room.add_child(_bar(Vector3(w + 2.0, 0.03, 0.06), Vector3(0, 0.1, side * (d / 2.0 + 0.95)), edge_neon))
		_room.add_child(_bar(Vector3(0.06, 0.03, d + 2.0), Vector3(side * (w / 2.0 + 0.95), 0.1, 0), edge_neon))
	_build_back_wall(w, d)
	_build_side_walls(w, d)
	_build_spots(w, d)
	_build_motes(w, d)


func _build_back_wall(w: float, d: float) -> void:
	var z := -d / 2.0 - 1.6
	var wall := _bar(Vector3(w + 12.0, WALL_HEIGHT, 0.6), Vector3(0, WALL_HEIGHT / 2.0, z - 0.3), HallMaterials.wall_material())
	_room.add_child(wall)
	# zoccolo e cornicione con il neon
	_room.add_child(_bar(Vector3(w + 12.0, 0.5, 0.3), Vector3(0, 0.25, z + 0.1), HallMaterials.metal()))
	_room.add_child(_bar(Vector3(w + 12.0, 0.06, 0.08), Vector3(0, 0.55, z + 0.2), HallMaterials.neon(Color("b06bff"))))
	_room.add_child(_bar(Vector3(w + 12.0, 0.35, 0.4), Vector3(0, WALL_HEIGHT - 0.2, z + 0.1), HallMaterials.trim_gold()))
	# il maxischermo al centro, con la cornice d'oro
	var sw := minf(14.0, w * 0.45)
	var sh := sw * 0.4
	var sy := 1.6 + sh / 2.0
	_screen_vp = SubViewport.new()
	_screen_vp.size = Vector2i(1280, 512)
	_screen_vp.transparent_bg = false
	_screen_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_room.add_child(_screen_vp)
	_build_screen_ui(_screen_vp)
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(sw, sh)
	screen.mesh = q
	screen.material_override = HallMaterials.screen_material(_screen_vp.get_texture())
	screen.position = Vector3(0, sy, z + 0.12)
	_room.add_child(screen)
	var frame := 0.22
	for side in [-1.0, 1.0]:
		_room.add_child(_bar(Vector3(sw + frame * 2.0, frame, 0.3), Vector3(0, sy + side * (sh / 2.0 + frame / 2.0), z + 0.12), HallMaterials.trim_gold()))
		_room.add_child(_bar(Vector3(frame, sh, 0.3), Vector3(side * (sw / 2.0 + frame / 2.0), sy, z + 0.12), HallMaterials.trim_gold()))
	# colonne e stendardi ai due lati dello schermo
	var banner_colors := [UI.PRIMARY, UI.ACCENT]
	var x := sw / 2.0 + 2.2
	var i := 0
	while x < w / 2.0 + 5.0:
		for side in [-1.0, 1.0]:
			_column(Vector3(side * x, 0, z + 0.6))
			var b := _bar(Vector3(1.5, 4.6, 0.06), Vector3(side * (x + 1.6), 5.2, z + 0.32), HallMaterials.banner_material(banner_colors[i % 2]))
			_room.add_child(b)
			_room.add_child(_bar(Vector3(1.6, 0.12, 0.1), Vector3(side * (x + 1.6), 7.5, z + 0.35), HallMaterials.trim_gold()))
			_room.add_child(_bar(Vector3(1.5, 0.08, 0.08), Vector3(side * (x + 1.6), 2.9, z + 0.36), HallMaterials.trim_gold()))
			var emblem := MeshInstance3D.new()
			var em := CylinderMesh.new()
			em.top_radius = 0.42
			em.bottom_radius = 0.42
			em.height = 0.05
			em.radial_segments = 6
			em.rings = 1
			emblem.mesh = em
			emblem.material_override = HallMaterials.trim_gold()
			emblem.rotation.x = PI / 2.0
			emblem.position = Vector3(side * (x + 1.6), 5.6, z + 0.38)
			_room.add_child(emblem)
		x += 4.2
		i += 1


func _column(at: Vector3) -> void:
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.38
	cm.bottom_radius = 0.42
	cm.height = WALL_HEIGHT
	cm.radial_segments = 12
	cm.rings = 1
	col.mesh = cm
	col.material_override = HallMaterials.metal()
	col.position = at + Vector3(0, WALL_HEIGHT / 2.0, 0)
	_room.add_child(col)
	for y in [0.35, WALL_HEIGHT - 0.6]:
		var ring := _bar(Vector3(1.0, 0.3, 1.0), at + Vector3(0, y, 0), HallMaterials.trim_gold())
		_room.add_child(ring)
	# striscia di neon in verticale sul davanti
	_room.add_child(_bar(Vector3(0.07, WALL_HEIGHT - 1.4, 0.07), at + Vector3(0, WALL_HEIGHT / 2.0, 0.41), HallMaterials.neon(Color("4ad9ff"))))


func _build_side_walls(w: float, d: float) -> void:
	for side in [-1.0, 1.0]:
		# la parete si apre verso la telecamera, come una platea: dal fondo ruota sul suo spigolo
		var hinge := Node3D.new()
		hinge.position = Vector3(side * (w / 2.0 + 2.2), 0, -d / 2.0 - 1.6)
		hinge.rotation.y = side * deg_to_rad(16.0)
		_room.add_child(hinge)
		var length := d + 6.0
		var wall := _bar(Vector3(0.6, WALL_HEIGHT, length), Vector3(side * 0.3, WALL_HEIGHT / 2.0, length / 2.0), HallMaterials.wall_material())
		hinge.add_child(wall)
		hinge.add_child(_bar(Vector3(0.3, 0.5, length), Vector3(-side * 0.05, 0.25, length / 2.0), HallMaterials.metal()))
		hinge.add_child(_bar(Vector3(0.08, 0.06, length), Vector3(-side * 0.2, 0.55, length / 2.0), HallMaterials.neon(Color("4ad9ff") if side > 0 else Color("b06bff"))))
		hinge.add_child(_bar(Vector3(0.4, 0.35, length), Vector3(-side * 0.05, WALL_HEIGHT - 0.2, length / 2.0), HallMaterials.trim_gold()))
		if side > 0:
			_build_board(hinge, side, d)
		else:
			# sulla parete di sinistra stendardi lunghi
			for k in 3:
				var bz := 3.0 + k * 5.0
				hinge.add_child(_bar(Vector3(0.06, 5.0, 1.8), Vector3(-side * 0.05 + 0.0, 5.0, bz), HallMaterials.banner_material(UI.PRIMARY if k % 2 == 0 else UI.ACCENT)))
				hinge.add_child(_bar(Vector3(0.1, 0.12, 1.9), Vector3(-side * 0.08, 7.5, bz), HallMaterials.trim_gold()))


# Il tabellone della classifica sulla parete di destra
func _build_board(hinge: Node3D, side: float, d: float) -> void:
	_board_vp = SubViewport.new()
	_board_vp.size = Vector2i(720, 900)
	_board_vp.transparent_bg = false
	_board_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_room.add_child(_board_vp)
	_build_board_ui(_board_vp)
	var bw := 5.6
	var bh := bw * 900.0 / 720.0
	var board := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(bw, bh)
	board.mesh = q
	board.material_override = HallMaterials.screen_material(_board_vp.get_texture())
	var bz := minf(6.5, d * 0.36)
	board.position = Vector3(-side * 0.1, 1.1 + bh / 2.0, bz)
	board.rotation.y = -side * PI / 2.0
	hinge.add_child(board)
	var frame := 0.2
	for s in [-1.0, 1.0]:
		hinge.add_child(_bar(Vector3(0.3, frame, bw + frame * 2.0), Vector3(-side * 0.1, 1.1 + bh / 2.0 + s * (bh / 2.0 + frame / 2.0), bz), HallMaterials.trim_gold()))
		hinge.add_child(_bar(Vector3(0.3, bh, frame), Vector3(-side * 0.1, 1.1 + bh / 2.0, bz + s * (bw / 2.0 + frame / 2.0)), HallMaterials.trim_gold()))


func _build_spots(w: float, d: float) -> void:
	var colors := [Color("ffcf4a"), Color("b06bff"), Color("4ad9ff"), Color("ff6bd5"), Color("ffcf4a")]
	for i in SPOTS:
		var pivot := Node3D.new()
		var x := lerpf(-w * 0.38, w * 0.38, float(i) / float(SPOTS - 1))
		pivot.position = Vector3(x, 11.0, -d * 0.15 + (i % 2) * 2.5)
		_room.add_child(pivot)
		var col: Color = colors[i % colors.size()]
		var cone := HallMaterials.god_ray(11.5, 0.15, 2.2, col)
		pivot.add_child(cone)
		# la lampada in cima
		var lamp := _bar(Vector3(0.5, 0.5, 0.5), Vector3.ZERO, HallMaterials.dark_metal())
		pivot.add_child(lamp)
		var bulb := HallMaterials.halo(col, 1.6, 0.9)
		bulb.position.y = -0.35
		pivot.add_child(bulb)
		var pool := HallMaterials.light_pool(col, 4.6, 0.5)
		_room.add_child(pool)
		_spots.append({"pivot": pivot, "cone": cone, "pool": pool, "phase": i * 1.7, "color": col})


# Pulviscolo che brilla nell'aria, in tutta la sala
func _build_motes(w: float, d: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# solo nella metà di fondo: vicino alla telecamera diventerebbero macchie grosse
	p.emission_box_extents = Vector3(w / 2.0, 2.8, d * 0.3)
	p.position = Vector3(0, 4.2, -d * 0.2)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.gravity = Vector3(0, 0.03, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 0.9, 0.6, 0.0), Color(1, 0.9, 0.6, 0.45), Color(0.8, 0.7, 1.0, 0.45), Color(0.8, 0.7, 1.0, 0.0)])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.material = HallFx._material("glow", true)
	p.mesh = q
	p.visibility_aabb = AABB(Vector3(-w, -5, -d), Vector3(w * 2.0, 12, d * 2.0))
	p.emitting = true
	_room.add_child(p)


func _bar(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _build_screen_ui(vp: SubViewport) -> void:
	var root := Control.new()
	root.size = Vector2(vp.size)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("0b0618")
	bg.size = root.size
	root.add_child(bg)
	var glow := TextureRect.new()
	glow.texture = HallIcons.glow()
	glow.modulate = Color(0.55, 0.3, 1.0, 0.35)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.size = Vector2(root.size.x * 1.2, root.size.y * 1.6)
	glow.position = Vector2(-root.size.x * 0.1, -root.size.y * 0.3)
	root.add_child(glow)
	_screen_title = _screen_label(root, 64, UI.ACCENT, 36)
	_screen_title.text = "SALA D'ATTESA"
	_screen_main = _screen_label(root, 92, Color.WHITE, 140)
	_screen_sub = _screen_label(root, 46, Color(0.85, 0.85, 1.0), 300)
	_screen_big = _screen_label(root, 330, UI.ACCENT, 40)
	_screen_big.visible = false


func _screen_label(root: Control, size: int, col: Color, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", maxi(6, size / 10))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(20, y)
	l.size = Vector2(root.size.x - 40, size * 1.4)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	root.add_child(l)
	return l


# Cosa dice il maxischermo: la modalità e l'arena in testa, il conto alla rovescia, cosa manca per partire
func screen_lines() -> Dictionary:
	var leading: Dictionary = _snap.get("leading", {}) if _snap.get("leading") is Dictionary else {}
	var mode := str(leading.get("mode", "ffa"))
	var stage := str(leading.get("stageId", ""))
	var mode_name: String = _labels.get("mode/" + mode, MODE_NAMES.get(mode, mode))
	var stage_name: String = _labels.get("stage/" + stage, str(game.get("stages", {}).get(stage, {}).get("name", stage)) if game.get("stages") is Dictionary else stage)
	var main := "%s  ·  %s" % [mode_name, stage_name] if stage != "" else mode_name
	var need: Variant = _snap.get("need")
	var sub := str(need) if need != null and str(need) != "" else "Entrate tutti nel cerchio dei pronti!"
	var big := ""
	var title := "SALA D'ATTESA"
	if _countdown_left >= 0.0:
		# il numero grande lo mostra l'HUD al centro: qui va nel titolo, sopra cosa si gioca
		var left := _countdown_left - (float(Time.get_ticks_msec()) - _countdown_at)
		title = "SI PARTE TRA %d" % maxi(1, ceili(left / 1000.0))
		sub = "Restate nel cerchio!"
	if float(Time.get_ticks_msec()) < _flash_until:
		big = _flash_text
	return {"title": title, "main": main, "sub": sub, "big": big}


func _update_screen() -> void:
	if _screen_vp == null:
		return
	var lines := screen_lines()
	var sig := "%s|%s|%s|%s" % [lines.title, lines.main, lines.sub, lines.big]
	if sig == _screen_sig:
		return
	_screen_sig = sig
	_screen_main.text = lines.main
	_screen_sub.text = lines.sub
	var big: String = lines.big
	_screen_big.visible = big != ""
	_screen_big.text = big
	_screen_big.add_theme_font_size_override("font_size", 330 if big.length() <= 2 else 150)
	_screen_main.visible = big == ""
	_screen_sub.visible = big == ""
	_screen_title.text = lines.title
	_screen_title.add_theme_font_size_override("font_size", 64 if lines.title == "SALA D'ATTESA" else 84)
	_screen_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_board_ui(vp: SubViewport) -> void:
	var root := Control.new()
	root.size = Vector2(vp.size)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("0b0618")
	bg.size = root.size
	root.add_child(bg)
	var title := Label.new()
	title.text = "CLASSIFICA"
	title.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", UI.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 18)
	title.size = Vector2(root.size.x, 100)
	root.add_child(title)
	var line := ColorRect.new()
	line.color = UI.ACCENT
	line.position = Vector2(60, 118)
	line.size = Vector2(root.size.x - 120, 4)
	root.add_child(line)
	_board_rows = VBoxContainer.new()
	_board_rows.position = Vector2(28, 140)
	_board_rows.size = Vector2(root.size.x - 56, root.size.y - 160)
	_board_rows.add_theme_constant_override("separation", 6)
	root.add_child(_board_rows)


# Le righe del tabellone, già pronte da mostrare: posizione, nome, grado, punti, serie (fiammella da 3 in su)
static func board_lines(board: Array) -> Array:
	var out := []
	for i in board.size():
		var r: Variant = board[i]
		if not (r is Dictionary):
			continue
		out.append({
			"rank": i + 1,
			"name": str(r.get("name", "")),
			"tier": str(r.get("tier", "")),
			"points": int(r.get("rating", 0)),
			"streak": int(r.get("streak", 0)),
			"hot": int(r.get("streak", 0)) >= 3,
		})
	return out


func _update_board(board: Array) -> void:
	if _board_vp == null:
		return
	var sig := JSON.stringify(board)
	if sig == _board_sig:
		return
	_board_sig = sig
	for c in _board_rows.get_children():
		c.queue_free()
	var lines := board_lines(board)
	if lines.is_empty():
		var l := Label.new()
		l.text = "Ancora nessuna partita.\nLa prima vittoria\nfinisce qui!"
		l.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
		l.add_theme_font_size_override("font_size", 46)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(0, 400)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_board_rows.add_child(l)
	for r in lines:
		_board_rows.add_child(_board_row(r))
	_board_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _board_row(r: Dictionary) -> Control:
	var first: bool = r.rank == 1
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UI.ACCENT, 0.9) if first else Color(1, 1, 1, 0.06 if r.rank % 2 == 0 else 0.11)
	box.set_corner_radius_all(10)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var ink := Color("1a1000") if first else Color.WHITE
	var size := 40 if first else 34
	row.add_child(_cell(str(r.rank), size, ink, 50, HORIZONTAL_ALIGNMENT_RIGHT))
	var who := _cell(str(r.name), size, ink, 0, HORIZONTAL_ALIGNMENT_LEFT)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	row.add_child(who)
	if r.hot:
		var fire := TextureRect.new()
		fire.texture = HallIcons.flame()
		fire.custom_minimum_size = Vector2(36, 36)
		fire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fire.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(fire)
		row.add_child(_cell("%d" % r.streak, 30, Color("ff9a1f") if not first else ink, 0, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_cell(str(r.tier), 24, Color(ink, 0.75), 0, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(_cell(str(r.points), size, ink if first else UI.ACCENT, 96, HORIZONTAL_ALIGNMENT_RIGHT))
	return panel


static func _cell(text: String, size: int, col: Color, width: float, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
	return l


# Per i test: quanti lottatori e zone ci sono, e lo stato interpolato di un giocatore
func fighter_count() -> int:
	return _fighters.size()


func zone_count() -> int:
	return _zones.size()


func sampled(id: String) -> Variant:
	return _sampled.get(id)
