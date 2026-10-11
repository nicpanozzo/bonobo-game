# Il movimento del proprio lottatore in GDScript, per la predizione (E17 passo 3).
# È una copia della parte di src/shared/physics che muove un lottatore libero: corsa, aria, salti,
# salto corto, coyote, gravità, caduta veloce, piattaforme sottili, scatto, corsa, schivata, attacchi leggeri
# e pesanti, recupero, fermo del colpo e contatto con l'arena (stepFighter in index.ts, applyControls/applyGravity/
# tickCoyote in movement.ts, stepDash in dash.ts, tryStartAttack/updateAttack in attacks.ts, collideWithStage in stage.ts).
# La fisica vera resta quella: se cambia, tests/test_prediction.gd rigioca le tracce generate dal
# TypeScript e diventa rosso finché questo file non fa lo stesso. Fuori da qui (colpi subiti, bordo,
# scudo, presa, speciali, suprema, oggetti, ascensori) la predizione non prova a indovinare: decide il server.
class_name PredictMovement
extends RefCounted

var fighter: Dictionary # FIGHTER di constants.ts (game.json)
var dash: Dictionary # DASH
var dodge: Dictionary # DODGE
var attacks: Dictionary # ATTACKS: durata di ogni attacco
var recovery: Dictionary # RECOVERY: spinta del recupero
var own_recovery: Dictionary # i numeri propri del recupero del personaggio (characters.ts), se ne ha
var buffer_ms: float # INPUT.bufferMs: per quanto una pressione del salto vale ancora
var stats: Dictionary # statistiche del personaggio: speed, airSpeed, jump, gravity
var solids: Array
var platforms: Array


func _init(game: Dictionary, character_stats: Dictionary, stage_solids: Array, stage_platforms: Array, character_recovery := {}) -> void:
	fighter = game.fighter
	dash = game.dash
	dodge = game.dodge
	attacks = game.attacks
	recovery = game.recovery
	own_recovery = character_recovery
	buffer_ms = float(game.input.bufferMs)
	stats = character_stats
	solids = stage_solids
	platforms = stage_platforms


# Lo stato di partenza: quello di uno snapshot (PlayerState con predict) o di una traccia
static func state_from(p: Dictionary, timers: Dictionary, input: Dictionary) -> Dictionary:
	return {
		"x": float(p.x), "y": float(p.y), "vx": float(p.vx), "vy": float(p.vy),
		"onGround": bool(p.onGround), "facing": int(p.facing),
		"jumps": int(timers.jumps), "coyote": float(timers.coyote), "rising": bool(timers.rising),
		"drop": float(timers.drop), "jumpBuffer": float(timers.jumpBuffer),
		"dashing": bool(p.get("dashing", false)), "dash": float(timers.get("dash", 0)),
		"tapDir": int(timers.get("tapDir", 0)), "tapTimer": float(timers.get("tapTimer", 0)), "tapHold": float(timers.get("tapHold", 0)),
		"dodge": float(timers.get("dodge", 0)), "dodgeCooldown": float(timers.get("dodgeCooldown", 0)),
		"airDodge": bool(timers.get("airDodge", false)), "dodgeBuffer": float(timers.get("dodgeBuffer", 0)),
		"attack": str(p.attack) if p.get("attack") != null else "", "attackTimer": float(timers.get("attackTimer", 0)),
		"cooldown": float(timers.get("cooldown", 0)), "hitstop": float(timers.get("hitstop", 0)),
		"recoveryUsed": bool(timers.get("recoveryUsed", false)), "helpless": bool(timers.get("helpless", false)),
		"lightBuffer": float(timers.get("lightBuffer", 0)), "heavyBuffer": float(timers.get("heavyBuffer", 0)),
		"input": input.duplicate(), "prev": input.duplicate(),
	}


# Un tasto nuovo (Match.setInput): salto, schivata e attacchi appena premuti finiscono nel buffer (E6)
func set_input(s: Dictionary, input: Dictionary) -> void:
	for key in ["jump", "dodge", "light", "heavy"]:
		if input.get(key, false) and not s.input.get(key, false):
			s[key + "Buffer"] = buffer_ms
	s.input = input


# Un tick di fisica (stepFighter per un lottatore libero)
func step(s: Dictionary, dt_ms: float) -> void:
	var dt := dt_ms / 1000.0
	# Fermo del colpo (#15): tutto resta fermo, timer compresi, e i tasti nuovi valgono al primo passo dopo
	if s.hitstop > 0:
		s.hitstop = maxf(0.0, s.hitstop - dt_ms)
		return
	s.cooldown = maxf(0.0, s.cooldown - dt_ms)
	s.drop = maxf(0.0, s.drop - dt_ms)
	s.dodge = maxf(0.0, s.dodge - dt_ms)
	s.dodgeCooldown = maxf(0.0, s.dodgeCooldown - dt_ms)
	_tick_coyote(s, dt_ms)
	s.jumpBuffer = maxf(0.0, s.jumpBuffer - dt_ms)
	s.dodgeBuffer = maxf(0.0, s.dodgeBuffer - dt_ms)
	s.lightBuffer = maxf(0.0, s.lightBuffer - dt_ms)
	s.heavyBuffer = maxf(0.0, s.heavyBuffer - dt_ms)
	_update_attack(s, dt_ms)
	_apply_controls(s, dt)
	_try_start_attack(s)
	_apply_gravity(s, dt)
	var prev_y: float = s.y
	s.x += s.vx * dt
	s.y += s.vy * dt
	_collide(s, prev_y)
	s.prev = s.input


func _pressed(s: Dictionary, key: String) -> bool:
	return s.input.get(key, false) and not s.prev.get(key, false)


func _tick_coyote(s: Dictionary, dt_ms: float) -> void:
	if s.coyote == 0.0:
		return
	s.coyote = maxf(0.0, s.coyote - dt_ms)
	if s.onGround:
		s.coyote = 0.0
	elif s.coyote == 0.0 and s.jumps == int(fighter.maxJumps):
		s.jumps = int(fighter.maxJumps) - 1


func _apply_controls(s: Dictionary, dt: float) -> void:
	var dir := (1 if s.input.get("right", false) else 0) - (1 if s.input.get("left", false) else 0)
	# Salto corto: lasciando il tasto mentre si sale si perde parte della spinta
	if s.rising:
		if s.vy >= 0:
			s.rising = false
		elif not s.input.get("jump", false):
			s.vy *= float(fighter.shortHopCut)
			s.rising = false
	# Schivata: mentre dura si scivola alla velocità decisa all'inizio, senza controlli
	if s.dodge > 0:
		_end_dash(s)
		return
	if (_pressed(s, "dodge") or s.dodgeBuffer > 0) and s.attack == "" and s.dodgeCooldown == 0.0 and (s.onGround or not s.airDodge):
		s.dodgeBuffer = 0.0
		s.dodge = float(dodge.durationMs)
		s.dodgeCooldown = float(dodge.cooldownMs)
		s.vx = dir * float(dodge.speed)
		if not s.onGround:
			s.airDodge = true
			s.vy = 0.0
		if dir != 0:
			s.facing = dir
		return
	var dash_speed: Variant = _step_dash(s, dir, dt * 1000.0)
	if s.onGround and dash_speed != null:
		s.vx = float(dash_speed)
	elif s.onGround:
		s.vx = 0.0 if s.attack != "" else dir * float(fighter.groundSpeed) * float(stats.speed)
	elif dir != 0:
		s.vx += dir * float(fighter.airAccel) * dt
		var top := float(fighter.airSpeed) * float(stats.airSpeed)
		s.vx = maxf(-top, minf(top, s.vx))
	else:
		var slow := float(fighter.airFriction) * dt
		s.vx = 0.0 if absf(s.vx) <= slow else s.vx - signf(s.vx) * slow
	if dir != 0 and s.attack == "":
		s.facing = dir
	# Recupero (#11): in aria, pesante tenendo su
	if not s.onGround and s.attack == "" and not s.recoveryUsed and s.input.get("up", false) and (_pressed(s, "heavy") or s.heavyBuffer > 0):
		s.vy = -float(recovery.speed)
		s.vx = dir * float(recovery.drift)
		s.recoveryUsed = true
		s.helpless = true
		s.rising = false
		_start_attack(s, "recovery")
		return
	# Salto e doppio salto
	if (_pressed(s, "jump") or s.jumpBuffer > 0) and s.jumps > 0:
		s.jumpBuffer = 0.0
		var from_ground: bool = s.onGround or s.coyote > 0
		s.vy = -float(fighter.jumpSpeed if from_ground else fighter.doubleJumpSpeed) * float(stats.jump)
		s.jumps -= 1
		s.onGround = false
		s.coyote = 0.0
		s.rising = true
	if _pressed(s, "down"):
		s.drop = float(fighter.dropThroughMs)


# Attacchi leggeri e pesanti (tryStartAttack in attacks.ts). Speciali e suprema non ci sono: con quei tasti
# il predittore lascia decidere il server
func _try_start_attack(s: Dictionary) -> void:
	if s.attack != "" or s.cooldown > 0 or s.helpless or s.dodge > 0:
		return
	if _pressed(s, "heavy") or s.heavyBuffer > 0:
		_start_attack(s, _variant(s, "heavy"))
	elif _pressed(s, "light") or s.lightBuffer > 0:
		_start_attack(s, _variant(s, "light"))


# Su vince su tutto, poi l'aria, poi giù (a terra)
func _variant(s: Dictionary, base: String) -> String:
	if s.input.get("up", false):
		return base + "Up"
	if not s.onGround:
		return base + "Air"
	if s.input.get("down", false):
		return base + "Down"
	return base


func _start_attack(s: Dictionary, kind: String) -> void:
	s.attack = kind
	s.attackTimer = 0.0
	s.cooldown = float(attack_spec(kind).cooldownMs)
	s.lightBuffer = 0.0
	s.heavyBuffer = 0.0


func _update_attack(s: Dictionary, dt_ms: float) -> void:
	if s.attack == "":
		return
	var spec := attack_spec(s.attack)
	s.attackTimer += dt_ms
	if s.attackTimer >= float(spec.startupMs) + float(spec.activeMs):
		s.attack = ""


# La finestra in cui l'attacco colpisce: serve solo al disegno dei rettangoli
func attack_active(s: Dictionary) -> bool:
	if s.attack == "":
		return false
	var spec := attack_spec(s.attack)
	return s.attackTimer >= float(spec.startupMs) and s.attackTimer < float(spec.startupMs) + float(spec.activeMs)


func attack_spec(kind: String) -> Dictionary:
	var spec: Dictionary = attacks[kind]
	if kind == "recovery" and not own_recovery.is_empty():
		spec = spec.merged(own_recovery, true)
	return spec


# Scatto e corsa (stepDash in dash.ts): velocità a terra, o null se si cammina come sempre
func _step_dash(s: Dictionary, dir: int, dt_ms: float) -> Variant:
	s.tapTimer = maxf(0.0, s.tapTimer - dt_ms)
	if dir != 0 and dir == s.tapDir:
		s.tapHold += dt_ms
		if s.tapHold > float(dash.tapMaxMs):
			s.tapTimer = 0.0
	if not s.onGround or s.attack != "":
		_end_dash(s)
		return null
	var prev_dir := (1 if s.prev.get("right", false) else 0) - (1 if s.prev.get("left", false) else 0)
	if dir != 0 and dir != prev_dir:
		if not s.dashing and s.tapTimer > 0 and s.tapDir == dir:
			s.dashing = true
			s.dash = float(dash.durationMs)
			s.facing = dir
		s.tapDir = dir
		s.tapTimer = float(dash.doubleTapMs)
		s.tapHold = 0.0
	if not s.dashing:
		return null
	if dir == -s.facing:
		_end_dash(s)
		return null
	if s.dash > 0:
		s.dash = maxf(0.0, s.dash - dt_ms)
		return s.facing * float(dash.speed) * float(stats.speed)
	if dir == s.facing:
		return s.facing * float(dash.runSpeed) * float(stats.speed)
	_end_dash(s)
	return null


func _end_dash(s: Dictionary) -> void:
	s.dashing = false
	s.dash = 0.0


func _apply_gravity(s: Dictionary, dt: float) -> void:
	var fast_fall: bool = s.input.get("down", false)
	var max_fall := float(fighter.fastFallSpeed if fast_fall else fighter.maxFallSpeed)
	s.vy = minf(s.vy + float(fighter.gravity) * float(stats.gravity) * dt, max_fall)
	if fast_fall and not s.onGround and s.vy > 0:
		s.vy = maxf(s.vy, max_fall * 0.8)


# collideWithStage senza ascensori: blocchi pieni, poi piattaforme sottili
func _collide(s: Dictionary, prev_y: float) -> void:
	var half := float(fighter.width) / 2.0
	var height := float(fighter.height)
	var was_on_ground: bool = s.onGround
	s.onGround = false
	for b in solids:
		var bx := float(b.x)
		var by := float(b.y)
		var bw := float(b.width)
		var bh := float(b.height)
		if not (s.x + half > bx and s.x - half < bx + bw):
			continue
		if s.vy >= 0 and prev_y <= by and s.y >= by:
			_land(s, by)
			break
		if s.y > by and s.y - height < by + bh:
			if prev_y - height >= by + bh - 1:
				s.y = by + bh + height
				s.vy = maxf(0.0, s.vy)
			else:
				s.x = bx - half if s.x < bx + bw / 2.0 else bx + bw + half
				s.vx = 0.0
	if not s.onGround and s.vy >= 0 and s.drop == 0.0:
		for p in platforms:
			var px := float(p.x)
			var py := float(p.y)
			if s.x + half > px and s.x - half < px + float(p.width) and prev_y <= py and s.y >= py:
				_land(s, py)
				break
	if was_on_ground and not s.onGround and s.jumps == int(fighter.maxJumps):
		if s.drop > 0:
			s.jumps = int(fighter.maxJumps) - 1
		else:
			s.coyote = float(fighter.coyoteMs)


func _land(s: Dictionary, y: float) -> void:
	s.y = y
	s.vy = 0.0
	s.onGround = true
	s.jumps = int(fighter.maxJumps)
	s.airDodge = false
	s.recoveryUsed = false
	s.helpless = false
