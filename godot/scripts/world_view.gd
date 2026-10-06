# Disegna l'arena, i lottatori e qualche effetto sugli eventi. Non decide niente:
# legge solo gli snapshot (interpolati) e gli eventi che arrivano dal server.
extends Node2D

const HIT_SPARK_MS := 220.0 # durata della scintilla di un colpo
const SHAKE_KO := 14.0 # pixel di scossa della telecamera a un KO
const SHAKE_DECAY := 40.0 # pixel/s di scossa che si spengono

var game: Dictionary # godot/data/game.json
var stage: Dictionary
var my_id := ""
var buffer := SnapshotBuffer.new()
var player_ids: Array = []

var _sparks: Array = [] # [{ x, y, age, size, color }]
var _shake := 0.0
var _font: Font = ThemeDB.fallback_font


func setup(game_data: Dictionary) -> void:
	game = game_data
	buffer.delay_ms = game.net.interpolationDelayMs
	buffer.teleport_distance = game.net.teleportDistance
	buffer.size = int(game.net.bufferSize)
	set_stage(game.defaultStageId)


func set_stage(stage_id: String) -> void:
	# Le arene casuali ("casuale-<seme>") si generano sul server: qui per ora si mostra quella base
	stage = game.stages.get(stage_id, game.stages[game.defaultStageId])
	queue_redraw()


func on_snapshot(snap: Dictionary) -> void:
	buffer.push(snap.t, Time.get_ticks_msec(), snap.players)
	player_ids = snap.players.map(func(p): return p.id)


func on_event(e: Dictionary) -> void:
	match e.type:
		"hit":
			var big: bool = e.kind == "heavy"
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 34.0 if big else 20.0, "color": Color(1, 0.85, 0.3) if big else Color.WHITE})
		"ko":
			_shake = SHAKE_KO
			_sparks.append({"x": clampf(e.x, 0, game.world.width), "y": clampf(e.y, 0, game.world.height), "age": 0.0, "size": 90.0, "color": Color(1, 0.4, 0.3)})


func _process(delta: float) -> void:
	for s in _sparks:
		s.age += delta * 1000.0
	_sparks = _sparks.filter(func(s): return s.age < HIT_SPARK_MS)
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta * 10.0)
	position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0 else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if stage.is_empty():
		return
	var w: float = game.world.width
	var h: float = game.world.height
	draw_rect(Rect2(-400, -400, w + 800, h + 800), _color(stage.colors.sky))
	for s in stage.solids:
		draw_rect(Rect2(s.x, s.y, s.width, s.height), _color(stage.colors.solid))
		draw_rect(Rect2(s.x, s.y, s.width, 6), _color(stage.colors.solidEdge))
	for p in stage.platforms:
		draw_rect(Rect2(p.x, p.y, p.width, 8), _color(stage.colors.platform))

	var now := Time.get_ticks_msec()
	for id in player_ids:
		var p: Variant = buffer.sample(id, now)
		if p != null and not p.eliminated:
			_draw_fighter(p, now)

	for s in _sparks:
		var k: float = s.age / HIT_SPARK_MS
		var c: Color = s.color
		c.a = 1.0 - k
		draw_arc(Vector2(s.x, s.y), s.size * (0.4 + k), 0, TAU, 20, c, 4.0)


func _draw_fighter(p: Dictionary, now: float) -> void:
	var fw: float = game.fighter.width
	var fh: float = game.fighter.height
	# Chi è appena rientrato lampeggia finché è invulnerabile
	if p.respawning or (p.invulnerable and int(now / 100) % 2 == 0):
		return
	var color := _color(p.color)
	if p.hitstun:
		color = color.lightened(0.5)
	var body := Rect2(p.x - fw / 2, p.y - fh, fw, fh)
	draw_rect(body, color)
	if p.id == my_id:
		draw_rect(body, Color.WHITE, false, 3.0)
	# Occhio dalla parte in cui si guarda
	draw_circle(Vector2(p.x + p.facing * fw * 0.22, p.y - fh * 0.78), 5.0, Color.WHITE)
	draw_circle(Vector2(p.x + p.facing * fw * 0.27, p.y - fh * 0.78), 2.5, Color.BLACK)

	# Colpo in corso: la stessa hitbox di attackBox() in src/shared/physics/attacks.ts
	if p.attack != null:
		var spec: Dictionary = game.attacks[p.attack]
		var x: float = p.x + fw / 2 if p.facing == 1 else p.x - fw / 2 - spec.range
		var c := Color(1, 1, 1, 0.85) if p.attackActive else Color(1, 1, 1, 0.25)
		draw_rect(Rect2(x, p.y - fh * 0.7, spec.range, spec.height), c)

	var label := "%s  %d%%" % [p.name, roundi(p.percent)]
	var size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(_font, Vector2(p.x - size.x / 2, p.y - fh - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


static func _color(n: Variant) -> Color:
	return Color.hex((int(n) << 8) | 0xff)
