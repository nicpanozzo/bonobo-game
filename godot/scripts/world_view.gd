# Disegna l'arena, i lottatori e qualche effetto sugli eventi. Non decide niente:
# legge solo gli snapshot (interpolati) e gli eventi che arrivano dal server.
extends Node2D

# I numeri degli effetti stanno in EFFECTS (constants.ts), letti da game.effects
var game: Dictionary # godot/data/game.json
var stage: Dictionary
var my_id := ""
var buffer := SnapshotBuffer.new()
var player_ids: Array = []

var positions := {} # id -> Vector2 dei piedi, come disegnati all'ultimo frame (per la telecamera)
var _alive: Array = [] # id dei lottatori disegnati all'ultimo frame
var _sampled := {} # id -> stato interpolato di questo frame, calcolato una volta sola in _draw
var _reached := 0 # checkpoint della Corsa presi da me
var _sparks: Array = [] # [{ x, y, age, size, color }]
var _shake := 0.0
var _flash := 0.0 # ms di lampo bianco rimasti
var _dust: Array = [] # [{ x, y, dx, age }] sbuffi di polvere
var _trails := {} # id -> Array[Vector2] delle ultime posizioni, per la scia di chi vola
var effects := true # scie e polvere (opzioni → Video), main.gd lo legge dalle preferenze
var _beams: Array = [] # [{ x, y, age, color }] raggi dei KO, dal punto di uscita verso il centro
var _shards: Array = [] # [{ x, y, vx, vy, age, color }] schegge di uno scudo rotto (#109)
var _shield_hits := {} # id giocatore -> ms da quando lo scudo ha parato un colpo
var _items: Array = [] # oggetti dell'ultimo snapshot (#17)
var _projectiles: Array = [] # proiettili delle speciali dell'ultimo snapshot (E10)
var _projectiles_ms := 0 # quando è arrivato: tra uno snapshot e l'altro volano con la loro velocità
var _item_pos := {} # id oggetto -> Vector2 disegnata, che insegue quella dello snapshot
var _facings := {} # id giocatore -> verso, per mettere in mano gli oggetti
var _font: Font = ThemeDB.fallback_font
var view_rect := Rect2(0, 0, 1280, 720) # la parte di mondo che si vede, decisa dalla telecamera in main.gd
var _layers: Array = [] # strati dello sfondo dell'arena (E12), dal più lontano: [texture, parallasse]
var _foreground: Array = [] # strato davanti ai lottatori, o []
var _layer_scale := 1.0 # pixel di mondo per pixel delle immagini degli strati
var _textures := {} # id personaggio -> Texture2D dello spritesheet (nel formato cartella, quella di idle)
var _state_textures := {} # id personaggio -> { stato: Texture2D }, solo per il formato cartella (E7 passo 2)
var _anims := {} # id giocatore -> { name, since }: animazione in corso e da quando
var show_hitboxes := false # allenamento (E15): corpo dei lottatori visibile anche sopra gli sprite
var _air_jumps := {} # id giocatore -> quando ha fatto il doppio salto (ms), per l'animazione doubleJump (#103)
var _taunts := {} # id giocatore -> quando ha provocato (ms), per l'animazione taunt (E7)
var _holding := {} # id di chi tiene qualcuno con la presa (#109), dall'ultimo snapshot
var _variants := {} # id giocatore -> variante di colore (0 = originale), ricalcolata a ogni frame (E11)
const VARIANT_HUES := [0.5, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875] # spostamento della tinta per la variante 1, 2, ...
var _supreme_view: Node2D # liana, orsogufo e gnomo della suprema di Bonobot (#102), disegnati sopra i lottatori


func setup(game_data: Dictionary) -> void:
	game = game_data
	_supreme_view = preload("res://scripts/supreme_view.gd").new()
	_supreme_view.game = game
	_supreme_view.impact.connect(func(strength: float): _shake = maxf(_shake, strength)) # l'orsogufo tocca terra
	add_child(_supreme_view)
	reset()
	if material == null:
		var palette := ShaderMaterial.new()
		palette.shader = load("res://shaders/palette.gdshader")
		material = palette
	for id in game.characters:
		var c: Dictionary = game.characters[id]
		if c.get("sprite") == null:
			continue
		var filter: String = c.sprite.get("filter", "linear")
		if c.sprite.has("dir"):
			# Formato cartella: un PNG per stato, <dir>/<stato>.png, con i fotogrammi in fila.
			# Nella tabella ci sono tutti gli stati; quelli senza disegno puntano a quello del ripiego (src)
			var states := {}
			for state in c.sprite.animations:
				var src: String = c.sprite.animations[state].src
				if not states.has(src):
					states[src] = _sprite_texture("res://data/%s/%s.png" % [c.sprite.dir, src], filter)
			_state_textures[id] = states
			_textures[id] = states.idle
		else:
			_textures[id] = _sprite_texture("res://data/" + c.sprite.path, filter)


# La texture di uno sprite con il suo filtro: lineare con mipmap per l'illustrato, così rimpicciolito
# dalla telecamera non sfarfalla; nearest per la pixel art, che resta a quadretti netti (E7 passo 3)
static func _sprite_texture(path: String, filter: String) -> Texture2D:
	var tex: Texture2D = load(path)
	var canvas := CanvasTexture.new()
	if filter == "nearest":
		canvas.diffuse_texture = tex
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return canvas
	var img := tex.get_image()
	if img == null or img.is_compressed(): # una texture compressa per la GPU non si rifà: resta senza mipmap
		return tex
	img.generate_mipmaps()
	canvas.diffuse_texture = ImageTexture.create_from_image(img)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return canvas


# Si torna alla lobby: via i giocatori della stanza di prima
func reset() -> void:
	buffer = SnapshotBuffer.new()
	buffer.delay_ms = game.net.interpolationDelayMs
	buffer.teleport_distance = game.net.teleportDistance
	buffer.size = int(game.net.bufferSize)
	player_ids = []
	positions = {}
	_anims = {}
	_air_jumps = {}
	_taunts = {}
	_sparks = []
	_beams = []
	_shards = []
	_shield_hits = {}
	_items = []
	_projectiles = []
	_item_pos = {}
	_dust = []
	_trails = {}
	_flash = 0.0
	_supreme_view.clear()
	my_id = ""
	set_stage(game.defaultStageId)


func set_stage(stage_id: String) -> void:
	set_stage_spec(game.stages.get(stage_id, game.stages[game.defaultStageId]))


# L'arena intera arriva dal server nel benvenuto: così si vedono anche le arene casuali e i percorsi
func set_stage_spec(spec: Dictionary) -> void:
	stage = spec
	_layers = []
	_foreground = []
	var art: Dictionary = spec.get("art", {})
	for l in art.get("layers", []):
		var layer := _stage_layer(spec.id, l)
		if not layer.is_empty():
			_layers.append(layer)
	if art.has("foreground"):
		_foreground = _stage_layer(spec.id, art.foreground)
	_layer_scale = art.get("scale", 1.0)
	_supreme_view.stage = spec
	_reached = 0
	queue_redraw()


# Uno strato dello sfondo (E12): [texture, parallasse], o [] se il file non c'è (si vede il colore del cielo)
static func _stage_layer(stage_id: String, layer: Dictionary) -> Array:
	var path := "res://data/assets/stages/%s/%s" % [stage_id, layer.file]
	if not ResourceLoader.exists(path):
		push_warning("Sfondo mancante: " + path)
		return []
	return [_sprite_texture(path, "linear"), clampf(layer.parallax, 0.0, 1.0)]


func _draw_layer(layer: Array) -> void:
	var tex: Texture2D = layer[0]
	var center := Vector2(stage_width() / 2.0, game.world.height / 2.0)
	draw_texture_rect(tex, layer_rect(tex.get_size() * _layer_scale, layer[1], center, view_rect.get_center()), false)


# Dove sta uno strato: centrato sull'arena, poi trascinato verso il centro della vista tanto più quanto è lontano.
# parallax 1 = fermo con il palco, 0 = fermo con la telecamera
static func layer_rect(size: Vector2, parallax: float, world_center: Vector2, view_center: Vector2) -> Rect2:
	var center := world_center + (view_center - world_center) * (1.0 - parallax)
	return Rect2(center - size / 2.0, size)


# Piedi dei lottatori in gioco (non eliminati), per la telecamera
func alive_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for id in _alive:
		if positions.has(id):
			out.append(positions[id])
	return out


# Larghezza del mondo: lo schermo, o di più per i percorsi della Corsa (stageWidth in stages.ts)
func stage_width() -> float:
	var w: Variant = stage.get("width")
	return float(w) if w != null else float(game.world.width)


func on_snapshot(snap: Dictionary) -> void:
	buffer.push(snap.t, Time.get_ticks_msec(), snap.players, float(snap.get("stageMs", 0)))
	player_ids = snap.players.map(func(p): return p.id)
	_holding = {}
	for p in snap.players:
		if p.get("grabbedBy") != null:
			_holding[p.grabbedBy] = true
	_items = snap.get("items", [])
	_projectiles = snap.get("projectiles", [])
	_projectiles_ms = Time.get_ticks_msec()


func on_event(e: Dictionary) -> void:
	match e.type:
		"matchStart":
			_reached = 0
		"checkpoint":
			if e.id == my_id:
				_reached = int(e.index)
		"hit":
			var big: bool = str(e.kind).begins_with("heavy")
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 34.0 if big else 20.0, "color": Color(1, 0.85, 0.3) if big else Color.WHITE})
			# Più il colpo lancia lontano, più lo schermo trema; i colpi enormi fanno anche un lampo
			var fx: Dictionary = game.effects
			var kb := float(e.get("knockback", 0))
			if kb > fx.shakeFromKnockback:
				_shake = maxf(_shake, minf(fx.shakeMax, (kb - fx.shakeFromKnockback) * fx.shakePerKnockback))
			if kb >= fx.flashKnockback:
				_flash = fx.flashMs
		"hazard":
			# Trappola (#14): scintilla arancione e scossa come un colpo forte
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 30.0, "color": Color(1, 0.55, 0.15)})
			_shake = maxf(_shake, minf(game.effects.shakeMax, float(e.knockback) * game.effects.shakePerKnockback))
		"land":
			_puff(e.x, e.y)
		"shield":
			# Colpo parato (#109): scintilla piccola del colore di chi para e bolla che si illumina
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			var col: Color = Access.color(p.color).lightened(0.5) if p != null else Color.WHITE
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 16.0 + float(e.damage), "color": col})
			_shield_hits[e.id] = 0.0
		"shieldBreak":
			# Scudo rotto: scossa e schegge della bolla che volano via
			_shake = maxf(_shake, float(game.effects.shieldBreakShake))
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			var col: Color = Access.color(p.color).lightened(0.3) if p != null else Color.WHITE
			var center := Vector2(e.x, e.y - float(game.fighter.height) / 2)
			for s in shard_velocities(int(game.effects.shards)):
				_shards.append({"x": center.x, "y": center.y, "vx": s.x, "vy": s.y, "age": 0.0, "color": col})
		"grab":
			# Presa (#109): un lampo bianco dove la mano afferra
			_sparks.append({"x": e.x, "y": float(e.y) - float(game.fighter.height) * 0.55, "age": 0.0, "size": 24.0, "color": Color.WHITE})
		"projectileEnd":
			# Proiettile che sparisce contro qualcosa (E10): una scintilla piccola; il colpo e lo scudo hanno già la loro
			if e.reason == "wall":
				_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 14.0, "color": Color(1, 0.9, 0.6)})
			elif e.reason == "hit":
				_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 18.0, "color": Color.WHITE}) # anche due proiettili che si annullano
		"counter":
			# Contrattacco (E10): lampo azzurro grande dove para, così si capisce perché l'altro vola via
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 46.0, "color": Color(0.55, 0.85, 1)})
			_flash = maxf(_flash, float(game.effects.flashMs) * 0.5)
		"grabRelease":
			# Liberato: polvere ai piedi di tutti e due
			for id in [e.id, e.targetId]:
				var p: Variant = buffer.sample(id, Time.get_ticks_msec())
				if p != null:
					_puff(p.x, p.y)
		"ledgeGrab":
			# Lampo bianco sullo spigolo se la presa è invulnerabile (#110), così chi difende sa che non serve colpire
			if e.get("invulnerable", false):
				_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 30.0, "color": Color.WHITE})
		"ledgeGetup":
			if e.option == "roll":
				var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
				if p != null:
					_puff(p.x, p.y - float(game.ledge.hangOffsetY)) # polvere sullo spigolo, da dove parte la rotolata
		"taunt":
			_taunts[e.id] = Time.get_ticks_msec()
		"attack":
			# Suprema propria (#102): la scena (liana, orsogufo, gnomo) la disegna supreme_view.gd
			if e.kind == "supreme":
				var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
				if p != null:
					_supreme_view.start(p, game.characters.get(p.characterId, {}))
		"dash":
			# Scatto (#199): uno sbuffo di polvere dove parte e uno un po' indietro
			_puff(e.x, e.y)
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			if p != null:
				_puff(float(e.x) - float(p.facing) * 26.0, float(e.y))
		"jump":
			if not e.get("air", false):
				_puff(e.x, e.y)
			else:
				_air_jumps[e.id] = Time.get_ticks_msec()
		"ko":
			_shake = game.effects.shakeKo
			_sparks.append({"x": clampf(e.x, 0, game.world.width), "y": clampf(e.y, 0, game.world.height), "age": 0.0, "size": 90.0, "color": Color(1, 0.4, 0.3)})
			# Il raggio prende il colore di chi è uscito, come in Smash
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			var col: Color = Access.color(p.color) if p != null else Color(1, 0.4, 0.3)
			_beams.append({"x": e.x, "y": e.y, "age": 0.0, "color": col})


# Sbuffi di polvere ai piedi, a destra e a sinistra
func _puff(x: float, y: float) -> void:
	if not effects:
		return
	var n := int(game.effects.dustPuffs)
	for i in n:
		var dx := (float(i) / maxf(1, n - 1) - 0.5) * 2.0 # da -1 a 1
		_dust.append({"x": x, "y": y, "dx": dx, "age": 0.0})


func _process(delta: float) -> void:
	var fx: Dictionary = game.effects
	for s in _sparks:
		s.age += delta * 1000.0
	_sparks = _sparks.filter(func(s): return s.age < fx.hitSparkMs)
	for d in _dust:
		d.age += delta * 1000.0
	_dust = _dust.filter(func(d): return d.age < fx.dustMs)
	for b in _beams:
		b.age += delta * 1000.0
	_beams = _beams.filter(func(b): return b.age < fx.koBeamMs)
	for s in _shards:
		s.age += delta * 1000.0
		s.x += s.vx * delta
		s.y += s.vy * delta
		s.vy += 900.0 * delta # le schegge ricadono
	_shards = _shards.filter(func(s): return s.age < fx.shardMs)
	for id in _shield_hits.keys():
		_shield_hits[id] += delta * 1000.0
		if _shield_hits[id] >= fx.shieldFlashMs:
			_shield_hits.erase(id)
	if Access.calm: # meno scossa e lampi (opzioni → Accessibilità): niente tremolio né lampo bianco
		_shake = 0.0
		_flash = 0.0
	_flash = maxf(0.0, _flash - delta * 1000.0)
	_shake = maxf(0.0, _shake - fx.shakeDecay * delta)
	position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0 else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if stage.is_empty():
		return
	var w: float = game.world.width
	var h: float = game.world.height
	draw_rect(Rect2(-400, -400, stage_width() + 800, h + 800), _color(stage.colors.sky))
	for l in _layers:
		_draw_layer(l)
	for s in stage.solids:
		draw_rect(Rect2(s.x, s.y, s.width, s.height), _color(stage.colors.solid))
		draw_rect(Rect2(s.x, s.y, s.width, 6), _color(stage.colors.solidEdge))
	for p in stage.platforms:
		draw_rect(Rect2(p.x, p.y, p.width, 8), _color(stage.colors.platform))

	_draw_elements(buffer.sample_stage_ms(Time.get_ticks_msec()))
	_draw_course()

	var now := Time.get_ticks_msec()
	_alive = []
	_sampled = buffer.sample_all(player_ids, now)
	_variants = variant_ranks(_sampled.values())
	for id in player_ids:
		var p: Variant = _sampled.get(id)
		if p != null:
			positions[id] = Vector2(p.x, p.y)
			_facings[id] = p.facing
			if not p.eliminated:
				_alive.append(id)
				_draw_trail(id, p)
				_draw_fighter(p, now)

	_supreme_view.view_rect = view_rect
	_draw_items(now)
	_draw_projectiles()
	if not _foreground.is_empty():
		_draw_layer(_foreground)
	_draw_offscreen_markers()

	for d in _dust:
		var kd: float = d.age / game.effects.dustMs
		var dc := Color(0.9, 0.85, 0.75, 0.8 * (1.0 - kd))
		draw_circle(Vector2(d.x + d.dx * (8 + 34 * kd), d.y - 4 - 10 * kd * absf(d.dx)), 4 + 7 * kd, dc)

	for s in _sparks:
		var k: float = s.age / game.effects.hitSparkMs
		var c: Color = s.color
		c.a = 1.0 - k
		draw_arc(Vector2(s.x, s.y), s.size * (0.4 + k), 0, TAU, 20, c, 4.0)

	for b in _beams:
		_draw_beam(b)

	for s in _shards:
		var c: Color = s.color
		c.a = 1.0 - s.age / game.effects.shardMs
		var tip := Vector2(s.vx, s.vy).normalized() * 12.0
		draw_line(Vector2(s.x, s.y) - tip, Vector2(s.x, s.y) + tip, c, 4.0)

	if _flash > 0:
		draw_rect(view_rect.grow(40), Color(1, 1, 1, 0.45 * _flash / float(game.effects.flashMs)))


# Raggio del KO: parte a punta dal bordo dello schermo dove si è usciti e si allarga verso il centro.
# Si allunga di colpo all'inizio e poi sbiadisce; dentro ha un'anima bianca.
func _draw_beam(b: Dictionary) -> void:
	var fx: Dictionary = game.effects
	var k: float = b.age / fx.koBeamMs
	var inner := view_rect.grow(-8)
	var from := Vector2(clampf(b.x, inner.position.x, inner.end.x), clampf(b.y, inner.position.y, inner.end.y))
	var dir := (view_rect.get_center() - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var side := dir.orthogonal()
	var reach: float = fx.koBeamLength * minf(1.0, k * 5.0)
	var alpha := 1.0 - k * k
	for layer in [[1.0, b.color], [0.35, Color.WHITE]]:
		var half: float = fx.koBeamWidth * 0.5 * layer[0] * (1.0 + k * 0.6)
		var c: Color = layer[1]
		c.a = alpha * (0.75 if layer[0] == 1.0 else 0.9)
		var end := from + dir * reach
		draw_colored_polygon(PackedVector2Array([from - side * half * 0.08, end - side * half, end + side * half, from + side * half * 0.08]), c)


# Oggetti (#17): in mano seguono il lottatore disegnato (che è interpolato), gli altri
# inseguono la posizione dello snapshot; in volo girano su se stessi
# Proiettili delle speciali (E10): un ovale della misura del colpo, del colore della speciale, girato
# nella direzione in cui vola, con una scia che sfuma. Tra uno snapshot e l'altro avanzano da soli
func _draw_projectiles() -> void:
	var dt := (Time.get_ticks_msec() - _projectiles_ms) / 1000.0
	for pr in _projectiles:
		var spec := attack_spec(game, str(pr.characterId), str(pr.kind))
		var size := Vector2(float(spec.get("range", 24)), float(spec.get("height", 16)))
		var vel := Vector2(pr.vx, pr.vy)
		var c := Vector2(pr.x, pr.y) + vel * minf(dt, 0.1)
		var color := projectile_color(game, str(pr.characterId), str(pr.kind))
		var angle := vel.angle() if vel.length() > 1.0 else 0.0
		for i in [3, 2, 1]: # la scia: copie più piccole e trasparenti dietro
			var tc := color
			tc.a = 0.5 - 0.13 * i
			_draw_oval(c - vel * 0.018 * i, angle, size * (1.0 - 0.15 * i), tc)
		_draw_oval(c, angle, size, color)
		_draw_oval(c + Vector2(-2, -2).rotated(angle), angle, size * 0.45, color.lightened(0.6))


func _draw_oval(c: Vector2, angle: float, size: Vector2, color: Color) -> void:
	draw_set_transform(c, angle, Vector2(size.x / size.y, 1.0))
	draw_circle(Vector2.ZERO, size.y / 2, color)
	draw_set_transform(Vector2.ZERO)


const SLOT_OF_KIND := {"specialNeutral": "neutral", "specialSide": "side", "specialDown": "down"}


# Il colore del proiettile: quello della speciale del personaggio, poi quello del personaggio base
static func projectile_color(game_data: Dictionary, character_id: String, kind: String) -> Color:
	var slot: String = SLOT_OF_KIND.get(kind, "neutral")
	for id in [character_id, str(game_data.get("defaultCharacterId", ""))]:
		var c: Dictionary = game_data.characters.get(id, {})
		var sp: Dictionary = c.get("specials", {}).get(slot, {})
		if sp.has("color"):
			return Color.hex((int(sp.color) << 8) | 0xff)
	return Color(1, 0.85, 0.3)


# Alone della carica (E10): cresce con la carica, da giallo ad arancione
static func charge_radius(fighter_height: float, charge: float) -> float:
	return fighter_height * (0.45 + 0.35 * clampf(charge, 0.0, 1.0))


func _draw_charge(center: Vector2, charge: float, now: float) -> void:
	var r := charge_radius(float(game.fighter.height), charge)
	var col := Color(1, 0.85, 0.3).lerp(Color(1, 0.45, 0.1), charge)
	var full := charge >= 0.99
	if full and not Access.calm: # carica piena: l'alone pulsa
		r += 3.0 * sin(now / 70.0)
	col.a = 0.12 + 0.18 * charge
	draw_circle(center, r, col)
	col.a = 0.4 + 0.5 * charge
	draw_arc(center, r, 0, TAU, 32, col, 3.0 if full else 2.0)


func _draw_items(now: int) -> void:
	var seen := {}
	for it in _items:
		var target := Vector2(it.x, it.y)
		var holder: Variant = it.heldBy
		if holder != null and positions.has(holder):
			var rules: Dictionary = game.itemRules
			target = positions[holder] + Vector2(_facings.get(holder, 1) * rules.holdOffsetX, -rules.holdOffsetY)
		var pos: Vector2 = _item_pos.get(it.id, target)
		pos = target if holder != null or pos.distance_to(target) > 200 else pos.lerp(target, 0.5)
		_item_pos[it.id] = pos
		seen[it.id] = true
		var spin := now / 1000.0 * 14.0 if it.thrown else 0.0
		_draw_item(it.kind, pos, spin)
	for id in _item_pos.keys():
		if not seen.has(id):
			_item_pos.erase(id)


# La banana è una mezzaluna gialla con le punte scure; gli altri oggetti, finché non hanno
# un disegno, sono un rettangolo del loro colore
func _draw_item(kind: String, base: Vector2, spin: float) -> void:
	var spec: Dictionary = game.items.get(kind, {"width": 24, "height": 16, "color": 0xffffff})
	var w: float = spec.width
	var h: float = spec.height
	var center := base - Vector2(0, h / 2)
	draw_set_transform(center, spin, Vector2.ONE)
	if kind == "banana":
		draw_arc(Vector2(0, -h * 0.9), h * 1.25, PI * 0.2, PI * 0.8, 12, _color(spec.color), h * 0.55)
		draw_circle(Vector2(-w * 0.42, -h * 0.25), 2.5, Color("5a3a1a"))
		draw_circle(Vector2(w * 0.42, -h * 0.25), 2.5, Color("5a3a1a"))
	else:
		draw_rect(Rect2(-w / 2, -h / 2, w, h), _color(spec.color))
	draw_set_transform(Vector2.ZERO)


# Chi vola veloce (lanciato lontano) lascia dietro di sé delle sagome che sbiadiscono
func _draw_trail(id: String, p: Dictionary) -> void:
	if not effects:
		return
	var fx: Dictionary = game.effects
	var fast: bool = not p.onGround and Vector2(p.vx, p.vy).length() > fx.trailSpeed and not p.respawning
	var trail: Array = _trails.get(id, [])
	if fast:
		trail.push_front(Vector2(p.x, p.y))
		trail.resize(mini(trail.size(), int(fx.trailLength)))
	elif not trail.is_empty():
		trail.pop_back() # la scia si accorcia da sola quando si rallenta
	_trails[id] = trail
	var fw: float = game.fighter.width
	var fh: float = game.fighter.height
	var col := Access.color(p.color)
	for i in range(1, trail.size()):
		var pos: Vector2 = trail[i]
		col.a = 0.35 * (1.0 - float(i) / trail.size())
		var shrink := 1.0 - 0.08 * i
		draw_rect(Rect2(pos.x - fw * shrink / 2, pos.y - fh * shrink, fw * shrink, fh * shrink), col)


# Ascensori e trappole (#14), dove sono all'istante t dell'arena: stessi calcoli di physics/elements.ts
func _draw_elements(t: float) -> void:
	var movers: Array = stage.get("movers") if stage.get("movers") != null else []
	for m in movers:
		var pos := mover_position(m, t)
		draw_rect(Rect2(pos.x, pos.y, m.width, 10), _color(stage.colors.platform))
		# Strisce gialle e nere sotto: si capisce che si muove
		for x in range(0, int(m.width), 20):
			draw_rect(Rect2(pos.x + x, pos.y + 10, minf(10, m.width - x), 5), Color("f1c40f"))
	var hazards: Array = stage.get("hazards") if stage.get("hazards") != null else []
	for h in hazards:
		_draw_hazard(h, hazard_active(h, t), t)


func _draw_hazard(h: Dictionary, on: bool, t: float) -> void:
	var r := Rect2(h.x, h.y, h.width, h.height)
	match h.kind:
		"spuntoni":
			var n := maxi(1, int(h.width / 15.0))
			var w: float = h.width / n
			var col := Color("d9dde3") if on else Color("6b6f75")
			for i in n:
				var x: float = h.x + i * w
				draw_colored_polygon(PackedVector2Array([Vector2(x, h.y + h.height), Vector2(x + w / 2, h.y), Vector2(x + w, h.y + h.height)]), col)
		"fuoco":
			if not on:
				# Spento: solo le bocchette, che si scaldano poco prima di accendersi
				draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), Color("5a2a1a"))
				return
			for i in int(h.width / 20.0):
				var flicker := 0.6 + 0.4 * sin(t / 70.0 + i * 1.7)
				var fh: float = h.height * (1.2 + flicker)
				var x: float = h.x + i * 20.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 10, r.end.y - fh), Vector2(x + 20, r.end.y)]), Color(1, 0.35 + 0.3 * flicker, 0.1, 0.9))
		_:
			# Trappola senza disegno suo: un rettangolo rosso che pulsa quando è accesa
			var a := 0.35 + 0.25 * sin(t / 90.0) if on else 0.15
			draw_rect(r, Color(1, 0.2, 0.2, a))


# Posizione di una piattaforma mobile al tempo t: la stessa formula di moverPosition() in physics/elements.ts
static func mover_position(m: Dictionary, t: float) -> Vector2:
	var pts: Array = m.path
	if pts.size() < 2:
		return Vector2(pts[0].x, pts[0].y)
	var route: Array = pts.duplicate()
	if m.get("loop", false):
		route.append(pts[0])
	else:
		for i in range(pts.size() - 2, -1, -1):
			route.append(pts[i])
	var segments := route.size() - 1
	var pause: float = m.get("pauseMs", 0)
	var lengths: Array[float] = []
	var total := 0.0
	for i in segments:
		var d := Vector2(route[i + 1].x - route[i].x, route[i + 1].y - route[i].y).length()
		lengths.append(d)
		total += d
	var period: float = m.periodMs
	var travel := maxf(1.0, period - pause * segments)
	var left := fposmod(t + float(m.get("offsetMs", 0)), period)
	for i in segments:
		var a := Vector2(route[i].x, route[i].y)
		if left < pause:
			return a
		left -= pause
		var seg_ms: float = travel * lengths[i] / total if total > 0 else travel / segments
		if left < seg_ms:
			return a.lerp(Vector2(route[i + 1].x, route[i + 1].y), left / seg_ms)
		left -= seg_ms
	return Vector2(route[segments].x, route[segments].y)


# Come hazardActive() in physics/elements.ts
static func hazard_active(h: Dictionary, t: float) -> bool:
	var period: float = h.get("periodMs", 0)
	if period <= 0:
		return true
	return fposmod(t + float(h.get("offsetMs", 0)), period) < float(h.get("activeMs", period / 2.0))


# Corsa: checkpoint (asta grigia, bandierina verde quando la si prende) e arrivo a scacchi
func _draw_course() -> void:
	var cps: Array = stage.get("checkpoints") if stage.get("checkpoints") != null else []
	for i in range(1, cps.size()):
		var c: Dictionary = cps[i]
		draw_rect(Rect2(c.x - 2, c.y - 70, 4, 70), Color("dddddd"))
		var flag := Color("2ecc71") if i <= _reached else Color("999999")
		draw_colored_polygon(PackedVector2Array([Vector2(c.x + 2, c.y - 70), Vector2(c.x + 28, c.y - 62), Vector2(c.x + 2, c.y - 54)]), flag)
	var g: Variant = stage.get("goal")
	if g == null:
		return
	var cell := 20.0
	for y in range(0, int(g.height), int(cell)):
		for x in range(0, int(g.width), int(cell)):
			var white := (x + y) / int(cell) % 2 == 0
			draw_rect(Rect2(g.x + x, g.y + y, minf(cell, g.width - x), minf(cell, g.height - y)), Color(1, 1, 1, 0.75) if white else Color(0.07, 0.07, 0.07, 0.75))
	var label := "ARRIVO"
	var size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string_outline(_font, Vector2(g.x + g.width / 2 - size.x / 2, g.y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color.BLACK)
	draw_string(_font, Vector2(g.x + g.width / 2 - size.x / 2, g.y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffcf4a"))


func _draw_fighter(p: Dictionary, now: float) -> void:
	var fw: float = game.fighter.width
	var fh: float = game.fighter.height
	# Chi è appena rientrato lampeggia finché è invulnerabile; chi ha perso la rete no, è solo trasparente (#107)
	var away: bool = p.get("away", false)
	# Chi fa la suprema propria (#102) è invulnerabile ma appeso alla liana: non lampeggia
	var blink: bool = p.invulnerable and not away and not _supreme_view.holds(p.id, now)
	if p.respawning or (blink and int(now / 100) % 2 == 0):
		return
	var character: Dictionary = game.characters.get(p.characterId, game.characters[game.defaultCharacterId])
	var charge := float(p.get("charge", 0.0))
	if charge > 0.0:
		_draw_charge(Vector2(p.x, p.y - fh / 2), charge, now)
	var head := fh # altezza della testa sopra i piedi: lo sprite può essere più alto del corpo
	if _textures.has(character.id):
		head = maxf(fh, character.sprite.frameHeight * character.sprite.get("scale", 1.0))
		_draw_sprite(p, character, now)
	else:
		var color := Access.color(p.color)
		if p.hitstun or p.get("stunned", false) or p.get("grabbedBy") != null:
			color = color.lightened(0.5)
		color.a = away_alpha(p)
		var body := Rect2(p.x - fw / 2, p.y - fh, fw, fh)
		draw_rect(body, color)
		if p.id == my_id:
			draw_rect(body, Color.WHITE, false, 3.0)
		# Occhio dalla parte in cui si guarda
		draw_circle(Vector2(p.x + p.facing * fw * 0.22, p.y - fh * 0.78), 5.0, Color.WHITE)
		draw_circle(Vector2(p.x + p.facing * fw * 0.27, p.y - fh * 0.78), 2.5, Color.BLACK)

	# Appeso al bordo (#110): il braccio arriva fino allo spigolo, sopra la testa.
	# Chi ha l'animazione ledge nello spritesheet (#171) ha già la mano disegnata sullo spigolo.
	var own_hang: bool = _textures.has(character.id) and has_own(character.sprite.animations, "ledge")
	if str(p.get("ledge", "")) == "hang" and not own_hang:
		var hand := Vector2(p.x + p.facing * fw / 2, p.y - float(game.ledge.hangOffsetY))
		var shoulder := Vector2(p.x + p.facing * fw * 0.2, p.y - fh * 0.55)
		var arm := Access.color(p.color).darkened(0.2)
		draw_line(shoulder, hand, arm, 6.0)
		draw_circle(hand, 6.0, arm)

	# Presa (#109): il braccio di chi tiene arriva a chi è tenuto, se lo sprite non ha la sua posa
	var own_grab: bool = _textures.has(character.id) and has_own(character.sprite.animations, "grab")
	if _holding.has(p.id) and not own_grab:
		var reach: float = fw / 2 + float(game.attacks.grab.range) * 0.6
		var hand := Vector2(p.x + p.facing * reach, p.y - fh * 0.55)
		var arm := Access.color(p.color).darkened(0.2)
		arm.a = away_alpha(p)
		draw_line(Vector2(p.x + p.facing * fw * 0.2, p.y - fh * 0.55), hand, arm, 6.0)
		draw_circle(hand, 7.0, arm)

	# Scudo (#109): una bolla del colore del giocatore che rimpicciolisce con i punti rimasti
	if p.get("shielding", false):
		var r := shield_radius(float(p.get("shieldHp", 0)), float(game.shield.maxHp), fh)
		var bubble := Access.color(p.color).lightened(0.3)
		var lit: float = 1.0 - float(_shield_hits[p.id]) / game.effects.shieldFlashMs if _shield_hits.has(p.id) else 0.0
		bubble = bubble.lerp(Color.WHITE, 0.6 * lit) # si illumina quando para un colpo
		bubble.a = (0.35 + 0.3 * lit) * away_alpha(p)
		var center := Vector2(p.x, p.y - fh / 2)
		draw_circle(center, r, bubble)
		bubble.a = 0.9 * away_alpha(p)
		draw_arc(center, r, 0, TAU, 40, bubble, 3.0)

	# Stordito dopo la rottura dello scudo: stelline che girano sopra la testa
	if p.get("stunned", false):
		for i in int(game.effects.stunStars):
			var a := now / 300.0 + TAU * i / float(game.effects.stunStars)
			var star := Vector2(p.x + cos(a) * fw * 0.6, p.y - head - 18 - Access.px(16) + sin(a) * 6) # sopra il nome
			_draw_star(star, 6.0, Color(1, 0.9, 0.3))

	# Allenamento: il corpo che si può colpire, lo stesso rettangolo della fisica
	if show_hitboxes:
		draw_rect(Rect2(p.x - fw / 2, p.y - fh, fw, fh), Color(0.3, 1, 0.5, 0.9), false, 2.0)

	# Colpo in corso: la stessa hitbox di attackBox() in src/shared/physics/attacks.ts,
	# spostata da boxX/boxY per le varianti direzionali (#2)
	var spec := attack_spec(game, p.characterId, str(p.attack)) if p.attack != null else {}
	if not spec.is_empty(): # un attacco che questa versione non conosce non ha rettangolo
		var front: float = spec.get("boxX", fw / 2)
		var o := Vector2(p.x, p.y)
		var vine: Variant = _supreme_view.origin(p.id) if p.attack == "supreme" else null
		if vine != null:
			o = vine # la suprema di Bonobot colpisce sulla liana (#102), come hitOrigin() in supreme.ts
		var x: float = o.x + front if p.facing == 1 else o.x - front - spec.range
		var y: float = o.y + spec.get("boxY", -fh * 0.7)
		var c := Color("ff9f43") if str(p.attack).begins_with("heavy") else Color.WHITE
		c.a = 0.85 if p.attackActive else 0.25
		draw_rect(Rect2(x, y, spec.range, spec.height), c)

	var label := "%s  %d%%" % [p.name, roundi(p.percent)]
	var size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, Access.px(16))
	draw_string(_font, Vector2(p.x - size.x / 2, p.y - head - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), Color.WHITE)
	if away:
		var note := "disconnesso"
		var note_size := _font.get_string_size(note, HORIZONTAL_ALIGNMENT_CENTER, -1, Access.px(13))
		draw_string(_font, Vector2(p.x - note_size.x / 2, p.y - head - 10 - Access.px(18)), note, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(13), Color(1, 0.8, 0.3))
	if p.id == my_id and _textures.has(character.id):
		# Un triangolino sopra il nome dice chi sei, al posto del bordo bianco del rettangolo
		var top: float = p.y - head - 30
		draw_colored_polygon(PackedVector2Array([Vector2(p.x - 7, top - 10), Vector2(p.x + 7, top - 10), Vector2(p.x, top)]), Color.WHITE)

	# Bandiera: chi la porta ha una bandierina del colore della squadra sopra la testa
	if p.get("carrier", false):
		var top: float = p.y - head - 34
		draw_rect(Rect2(p.x - 1, top - 30, 3, 30), Color.WHITE)
		var team_color := Access.team_color(game, int(p.team))
		draw_colored_polygon(PackedVector2Array([Vector2(p.x + 2, top - 30), Vector2(p.x + 26, top - 22), Vector2(p.x + 2, top - 14)]), team_color)


# Un fotogramma dello spritesheet, con i piedi dello sprite su quelli del giocatore
# e girato dalla parte in cui guarda (come FighterViews in src/client/render/fighters.ts)
func _draw_sprite(p: Dictionary, character: Dictionary, now: float) -> void:
	var sheet: Dictionary = character.sprite
	var anims: Dictionary = sheet.animations # tutti gli stati, già risolti con il ripiego (export:godot)
	var name := _animation_for(p, _holding.has(p.id))
	var state: Dictionary = _anims.get(p.id, {})
	var prev_name: String = state.get("name", "")
	var kind: String = str(p.attack) if p.attack != null else ""
	# Sul server il colpo finisce quando la hitbox si spegne, prima del recupero disegnato:
	# se si resta fermi a terra lasciamo finire l'animazione del colpo
	var prev_kind: String = state.get("kind", "")
	if name == "idle" and kind == "" and prev_kind != "" and anims.has(prev_name):
		if now - float(state.since) < animation_ms(anims[prev_name], attack_spec(game, p.characterId, prev_kind)):
			name = prev_name
	# Gli stati di passaggio si mostrano solo a chi li ha disegnati: il ripiego fermerebbe la corsa o il salto
	var flying: bool = p.hitstun and not p.onGround
	if name == "hit" and has_own(anims, "tumble") and flying:
		# Una volta lanciato si continua a rotolare finché dura lo stordimento, anche rallentando
		if prev_name == "tumble" or Vector2(p.vx, p.vy).length() > float(game.effects.tumbleSpeed):
			name = "tumble"
	var air_jump: float = float(_air_jumps.get(p.id, -1.0))
	if (name == "jump" or name == "fall") and has_own(anims, "doubleJump") and air_jump >= 0.0:
		if now - air_jump < animation_ms(anims.doubleJump):
			name = "doubleJump"
	var since := now
	if (name == "idle" or name == "walk") and has_own(anims, "land"):
		# Atterraggio: dal passaggio aria -> terra dello stato disegnato, non dall'evento che arriva prima
		if prev_name in ["jump", "fall", "doubleJump", "recovery", "tumble"]:
			name = "land"
		elif prev_name == "land" and now - float(state.since) < animation_ms(anims.land):
			name = "land"
	var taunted: float = float(_taunts.get(p.id, -1.0))
	if name == "idle" and has_own(anims, "taunt") and taunted >= 0.0 and now - taunted < animation_ms(anims.taunt):
		name = "taunt"
		since = taunted
	elif name == "doubleJump":
		since = air_jump # la capriola parte dal momento del doppio salto, non da quando la si disegna
	var new_attack: bool = p.attack != null and not bool(state.get("attacking", false))
	if prev_name != name or new_attack:
		state = {"name": name, "since": since, "kind": kind}
		_anims[p.id] = state
	state["attacking"] = p.attack != null
	var a: Dictionary = anims[name]
	var attack := attack_spec(game, p.characterId, str(state.get("kind", "")))
	var frame := sprite_frame(a, now - float(state.since), attack)
	var fw: float = sheet.frameWidth
	var fh: float = sheet.frameHeight
	# Nel foglio unico ogni animazione è una riga; nel formato cartella è un PNG a sé, con una riga sola
	var texture: Texture2D = _textures[character.id]
	var row: float = a.get("row", 0)
	if _state_textures.has(character.id):
		texture = _state_textures[character.id][a.src]
	var src := Rect2(frame * fw, row * fh, fw, fh)
	var scale: float = sheet.get("scale", 1.0) # 0.5 per i disegni fatti a 2x
	draw_set_transform(Vector2(p.x, p.y), 0, Vector2(p.facing * scale, scale))
	draw_texture_rect_region(texture, Rect2(-fw / 2, -fh, fw, fh), src, sprite_modulate(int(_variants.get(p.id, 0)), away_alpha(p)))
	draw_set_transform(Vector2.ZERO)


# Chi ha lo stesso personaggio di un altro giocatore prende una variante di colore: il primo in ordine
# di colore resta originale, gli altri 1, 2, ... Il colore lo dà il server, così ogni client vede lo stesso.
# Anche gli eliminati contano: chi resta non cambia colore a metà partita
static func variant_ranks(players: Array) -> Dictionary:
	var by_character := {}
	for p in players:
		if p == null:
			continue
		var id: String = str(p.get("characterId", ""))
		if not by_character.has(id):
			by_character[id] = []
		by_character[id].append(p)
	var ranks := {}
	for id in by_character:
		var same: Array = by_character[id]
		same.sort_custom(func(a, b): return int(a.color) < int(b.color) or (int(a.color) == int(b.color) and str(a.id) < str(b.id)))
		for i in same.size():
			ranks[same[i].id] = i
	return ranks


# Il modulate dello sprite: con una variante il rosso oltre 1 dice allo shader di quanto spostare la tinta
static func sprite_modulate(variant: int, alpha: float) -> Color:
	if variant <= 0:
		return Color(1, 1, 1, alpha)
	return Color(2.0 + VARIANT_HUES[(variant - 1) % VARIANT_HUES.size()], 1, 1, alpha)


# I numeri di un attacco per un personaggio, come attackSpecFor() in src/shared/physics/attacks.ts:
# quelli di ATTACKS con i ritocchi del personaggio (il recupero). {} se l'attacco non esiste
static func attack_spec(game_data: Dictionary, character_id: String, kind: String) -> Dictionary:
	if kind == "supreme": # la suprema (#101, #102): quella del personaggio, o quella di base
		var c: Dictionary = game_data.characters.get(character_id, {})
		var own: Variant = c.get("supremeAttack")
		return own if own is Dictionary else game_data.attacks.get("supreme", {})
	if kind.begins_with("special"): # le speciali (E10) sono del personaggio
		var c: Dictionary = game_data.characters.get(character_id, game_data.characters.get(game_data.get("defaultCharacterId", ""), {}))
		return c.get("specialAttacks", {}).get(kind, {})
	var spec: Dictionary = game_data.attacks.get(kind, {})
	if kind != "recovery" or spec.is_empty():
		return spec
	var character: Dictionary = game_data.characters.get(character_id, {})
	var own: Variant = character.get("recovery")
	return spec.merged(own, true) if own is Dictionary else spec


# Il personaggio ha il disegno di questo stato, non quello del ripiego
static func has_own(animations: Dictionary, name: String) -> bool:
	return animations.has(name) and str(animations[name].get("src", name)) == name


# Il fotogramma da mostrare dopo elapsed_ms. Negli attacchi con hitFrame il fotogramma d'impatto cade quando
# la hitbox si accende (startupMs) e l'animazione finisce con cooldownMs; senza, si va a fps.
static func sprite_frame(a: Dictionary, elapsed_ms: float, attack: Dictionary = {}) -> int:
	var frames := int(a.frames)
	if attack.is_empty() or not a.has("hitFrame"):
		var f := int(elapsed_ms / 1000.0 * float(a.fps))
		return f % frames if a.loop else mini(f, frames - 1)
	var hit := int(a.hitFrame)
	var startup: float = attack.startupMs
	if elapsed_ms < startup:
		return int(elapsed_ms / startup * hit)
	var rest := maxf(1.0, animation_ms(a, attack) - startup)
	return mini(hit + int((elapsed_ms - startup) / rest * (frames - hit)), frames - 1)


# Quanto dura un giro dell'animazione, in ms
static func animation_ms(a: Dictionary, attack: Dictionary = {}) -> float:
	if not attack.is_empty() and a.has("hitFrame"):
		return maxf(float(attack.cooldownMs), float(attack.startupMs) + float(attack.activeMs))
	return float(a.frames) / float(a.fps) * 1000.0


# Chi ha perso la rete (#107) si vede semitrasparente finché rientra o il suo posto scade
static func away_alpha(p: Dictionary) -> float:
	return 0.4 if p.get("away", false) else 1.0


# Stellina a quattro punte
func _draw_star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var rr := r if k % 2 == 0 else r * 0.4
		var a := TAU * k / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, color)


# Velocità delle schegge della bolla rotta: a raggiera, un po' più verso l'alto
static func shard_velocities(n: int) -> Array:
	var out := []
	for i in n:
		var a := TAU * i / float(n)
		out.append(Vector2(cos(a), sin(a) - 0.5) * 320.0)
	return out


# Raggio della bolla: copre il lottatore con lo scudo pieno, a vuoto ne resta un terzo
static func shield_radius(hp: float, max_hp: float, fighter_height: float) -> float:
	var full := fighter_height * 0.62
	return lerpf(full / 3.0, full, clampf(hp / max_hp, 0.0, 1.0))


# Quale animazione mostrare, dai soli campi dello snapshot (animationFor in fighters.ts)
static func _animation_for(p: Dictionary, holding := false) -> String:
	if p.hitstun or p.get("stunned", false): # lo stordito dopo lo scudo rotto (#109) ha la posa di chi è colpito
		return "hit"
	if p.get("grabbedBy") != null:
		return "grabbed" # tenuto con la presa (#109); senza disegno, la posa di chi è colpito
	if holding:
		return "grab" # chi tiene resta nella posa della presa
	if p.attack != null and str(p.attack).begins_with("throw"):
		return "throw" # i quattro lanci; senza disegno, la posa della presa
	if p.attack != null and str(p.attack).begins_with("special"):
		return "special" # le speciali (E10); senza disegno, la posa del pesante
	if p.attack != null:
		# Lo stato del colpo preciso (lightUp, heavyAir, recovery...): chi non l'ha disegnato mostra il ripiego.
		# L'attacco dal bordo (#110) non ha uno stato suo: usa il colpo leggero
		return "light" if p.attack == "ledgeAttack" else str(p.attack)
	var ledge := str(p.get("ledge", ""))
	if ledge == "hang":
		return "ledge" # appeso al bordo (#110)
	if ledge == "climb":
		return "climb"
	if ledge == "roll":
		return "walk"
	if p.get("shielding", false):
		return "shield" # scudo (#109): chi non l'ha disegnato resta fermo, dentro la bolla
	if not p.onGround:
		return "jump" if p.vy < 0 else "fall"
	if p.get("dashing", false):
		return "dash" # scatto e corsa (#199); senza disegno, la camminata
	if absf(p.vx) > 20:
		return "walk"
	return "idle"


# Freccia sul bordo dello schermo per chi è stato lanciato fuori (o resta indietro nella Corsa)
func _draw_offscreen_markers() -> void:
	var w: float = game.world.width
	for id in player_ids:
		var p: Variant = _sampled.get(id)
		if p == null or p.respawning or p.eliminated:
			continue
		var cx: float = p.x
		var cy: float = p.y - game.fighter.height / 2.0
		if view_rect.has_point(Vector2(cx, cy)):
			continue
		# Con la telecamera lontana tutto si rimpicciolisce: la freccia resta della stessa misura sullo schermo
		var s := view_rect.size.x / w
		var inner := view_rect.grow(-16 * s)
		var m := Vector2(clampf(cx, inner.position.x, inner.end.x), clampf(cy, inner.position.y, inner.end.y))
		var dir := (Vector2(cx, cy) - m).normalized()
		var side := dir.orthogonal() * 9 * s
		draw_colored_polygon(PackedVector2Array([m + dir * 14 * s, m - dir * 4 * s + side, m - dir * 4 * s - side]), Access.color(p.color))


static func _color(n: Variant) -> Color:
	return Color.hex((int(n) << 8) | 0xff)
