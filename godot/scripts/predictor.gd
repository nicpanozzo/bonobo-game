# Predizione del proprio lottatore (E17 passo 4): il server resta l'arbitro, questo è solo un disegno.
# A ogni snapshot si riparte dallo stato del server (PlayerState con predict) e si rigiocano, con
# predict/movement.gd, i tick che il server non ha ancora visto con i tasti premuti nel frattempo.
# La differenza con quello che si vedeva si spalma su smooth_ms, così una correzione non dà scatti.
# Fuori da quello che il port sa fare (colpo subito, bordo, scudo, presa, speciale, suprema, rientro, bandiera,
# ascensori) o con uno di quei tasti premuto dopo l'ultimo input visto dal server si disegna lo stato del server
# come nel passo 1; anche il passaggio dall'uno all'altro si spalma, così il lottatore non salta indietro.
class_name Predictor
extends RefCounted

const ACTION_KEYS := ["shield", "special", "supreme"] # mosse che il port non fa
const ITEM_KEYS := ["light", "heavy"] # con un oggetto vicino raccolgono o lanciano invece di attaccare (#17)
# Gli attacchi che il port sa fare (E17 passo 5): leggeri, pesanti e recupero
const PREDICTED_ATTACKS := ["light", "heavy", "lightUp", "lightDown", "lightAir", "heavyUp", "heavyDown", "heavyAir", "recovery"]

var enabled := true # opzione "Predizione" (video.predict) e velocità normale nell'allenamento
var smooth_ms := 100.0
var max_replay_ticks := 30
var teleport_distance := 300.0
var items_present := false # oggetti nell'arena: leggero e pesante li lascia decidere al server

var _game: Dictionary
var _tick_rate := 60.0
var _dt_ms := 1000.0 / 60.0
var _stage: Dictionary = {}
var _movement: PredictMovement
var _movement_key := ""
var _inputs: Array = [] # [[tick, input]] in ordine: l'input in uso da quel tick locale
var _server: Dictionary = {} # l'ultimo PlayerState del proprio lottatore
var _state: Dictionary = {} # stato previsto dopo il tick _tick
var _prev_xy := Vector2.ZERO # posizione dopo il tick prima: tra due tick si disegna una via di mezzo
var _tick := 0
var _error := Vector2.ZERO # quello che si vedeva meno il nuovo stato previsto: torna a zero piano
var _error_at := 0.0
var _active := false
var _last_out := Vector2(NAN, NAN) # dove si è disegnato il lottatore l'ultima volta
var _was_active := false


func setup(game: Dictionary) -> void:
	_game = game
	_tick_rate = float(game.get("tickRate", 60))
	_dt_ms = 1000.0 / _tick_rate
	smooth_ms = float(game.net.get("predictionSmoothMs", smooth_ms))
	max_replay_ticks = int(ceil(float(game.net.get("predictionMaxReplayMs", 500)) / _dt_ms))
	teleport_distance = float(game.net.teleportDistance)


func reset() -> void:
	_inputs = []
	_server = {}
	_active = false
	_was_active = false
	_error = Vector2.ZERO
	_last_out = Vector2(NAN, NAN)


func set_stage(stage: Dictionary) -> void:
	_stage = stage
	_movement_key = ""
	_active = false


func local_tick(now_ms: float) -> int:
	return int(floor(now_ms * _tick_rate / 1000.0))


# L'input mandato al server con seq = tick (main.gd): da quel tick vale questo
func record_input(input: Dictionary, tick: int) -> void:
	if not _inputs.is_empty() and _inputs[-1][0] == tick:
		_inputs[-1][1] = input
	else:
		_inputs.append([tick, input])
	# Basta tenere quello che serve a rigiocare dall'ultimo snapshot, più un po' di margine
	var keep_from := tick - max_replay_ticks * 4
	while _inputs.size() > 2 and _inputs[1][0] <= keep_from:
		_inputs.pop_front()


func input_at(tick: int) -> Dictionary:
	for i in range(_inputs.size() - 1, -1, -1):
		if _inputs[i][0] <= tick:
			return _inputs[i][1]
	return {}


# Il proprio lottatore in uno snapshot. shown: dove era disegnato finora (NAN se da nessuna parte)
func on_server(p: Dictionary, now_ms: float, shown := Vector2(NAN, NAN)) -> void:
	_server = p
	_active = enabled and predictable(p, _stage) and not _pressed_action_since(int(p.predict.seq) if p.get("predict") is Dictionary else 0)
	if not _active:
		return
	var key := "%s/%s" % [_stage.get("id", ""), p.characterId]
	if key != _movement_key:
		var character: Dictionary = _game.characters.get(p.characterId, _game.characters[_game.defaultCharacterId])
		_movement = PredictMovement.new(_game, character.stats, _stage.get("solids", []), _stage.get("platforms", []), character.get("recovery", {}))
		_movement_key = key
	var pr: Dictionary = p.predict
	# Lo stato del server è quello dopo il tick locale seq + ticks - 1
	_tick = int(pr.seq) + int(pr.ticks) - 1
	_state = PredictMovement.state_from(p, pr, input_at(int(pr.seq)))
	_prev_xy = Vector2(_state.x, _state.y)
	if local_tick(now_ms) - _tick > max_replay_ticks:
		_active = false # troppo indietro: meglio lo stato del server che indovinare mezzo secondo
		return
	_advance(now_ms)
	var now_xy := _position(now_ms)
	_error = shown - now_xy if not is_nan(shown.x) else Vector2.ZERO
	if _error.length() > teleport_distance:
		_error = Vector2.ZERO
	_error_at = now_ms


# Lo stato da disegnare ora. server: quello del passo 1 (l'ultimo snapshot spinto avanti), usato quando
# non si predice. Passando da uno all'altro la differenza si spalma come una correzione.
func sample(now_ms: float, server: Variant = null) -> Variant:
	var out: Variant
	if _active:
		_advance(now_ms)
		var xy := _position(now_ms)
		out = _server.duplicate()
		out.x = xy.x
		out.y = xy.y
		out.vx = _state.vx
		out.vy = _state.vy
		out.onGround = _state.onGround
		out.facing = _state.facing
		out.attack = _state.attack if _state.attack != "" else null
		out.attackActive = _movement.attack_active(_state)
	elif server == null:
		_last_out = Vector2(NAN, NAN)
		_was_active = false
		return null
	else:
		out = server.duplicate()
		if _was_active and not is_nan(_last_out.x):
			# Si è appena smesso di predire: si parte da dove si era, non da dove dice il server
			_error = _last_out - Vector2(out.x, out.y)
			if _error.length() > teleport_distance:
				_error = Vector2.ZERO
			_error_at = now_ms
	_was_active = _active
	if smooth_ms > 0:
		_error *= exp(-(now_ms - _error_at) / smooth_ms)
	_error_at = now_ms
	out.x += _error.x
	out.y += _error.y
	_last_out = Vector2(out.x, out.y)
	return out


func is_active() -> bool:
	return _active


# Dove il port sa fare quello che fa il server
static func predictable(p: Dictionary, stage: Dictionary) -> bool:
	if not (p.get("predict") is Dictionary) or not stage.get("movers", []).is_empty():
		return false
	if p.get("attack") != null and not str(p.attack) in PREDICTED_ATTACKS:
		return false
	if p.get("ledge") != null or p.get("grabbedBy") != null:
		return false
	for flag in ["hitstun", "respawning", "eliminated", "away", "shielding", "stunned", "carrier"]:
		if p.get(flag, false):
			return false
	return float(p.get("charge", 0)) == 0.0


func _pressed_action_since(seq: int) -> bool:
	for entry in _inputs:
		if entry[0] >= seq:
			for k in ACTION_KEYS + (ITEM_KEYS if items_present else []):
				if entry[1].get(k, false):
					return true
	return false


func _advance(now_ms: float) -> void:
	var target := local_tick(now_ms)
	while _tick < target:
		_tick += 1
		_prev_xy = Vector2(_state.x, _state.y)
		_movement.set_input(_state, input_at(_tick))
		_movement.step(_state, _dt_ms)


# Tra un tick e l'altro: la via di mezzo, così a più di 60 fps il lottatore non va a scatti
func _position(now_ms: float) -> Vector2:
	var frac := clampf(now_ms * _tick_rate / 1000.0 - float(_tick), 0.0, 1.0)
	return _prev_xy.lerp(Vector2(_state.x, _state.y), frac)
