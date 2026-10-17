# Il compagno di un lottatore (#369), il beagle di Lampione: disegnato col codice, con la stessa linea scura
# degli altri disegni provvisori. Solo disegno: dove è e dove guarda arrivano dallo snapshot (PlayerState.companion).
extends RefCounted

const INK := Color("221c1a")
const WHITE := Color("f4efe6")
const TAN := Color("c8843c")
const BLACK := Color("2b2522")
const EAR := Color("8a4f22")

var _target := {} # id del padrone -> {x, y, facing, onGround} dell'ultimo snapshot
var _pos := {} # id -> Vector2 disegnato: va verso il bersaglio, così tra due snapshot non scatta
var _moving := {} # id -> pixel/frame dell'ultimo spostamento, per far muovere le zampe
var _biting := {} # id -> true se il compagno sta mordendo (un attacco del padrone in companion.bites, #369 passo 2)
var _hurt_at := {} # id -> ms in cui ha preso l'ultimo colpo (#369 passo 3): lampeggia rosso
var _poofs: Array = [] # [{pos, t}]: nuvolette dove un compagno è andato KO

const HURT_MS := 220.0
const POOF_MS := 600.0


# characters: game.characters, per sapere quali attacchi fa il compagno
# now: l'orologio in ms (i test lo passano, sennò quello vero)
func on_snapshot(players: Array, characters: Dictionary = {}, now := -1) -> void:
	if now < 0:
		now = Time.get_ticks_msec()
	var before := _target
	_target = {}
	_biting = {}
	for p in players:
		var c: Variant = p.get("companion")
		if c is Dictionary:
			_target[p.id] = c
			_biting[p.id] = biting(p, characters)
			if before.has(p.id) and float(c.get("percent", 0)) > float(before[p.id].get("percent", 0)):
				_hurt_at[p.id] = now
		elif before.has(p.id) and _pos.has(p.id) and not p.get("respawning", false) and not p.get("eliminated", false):
			# Il compagno è sparito ma il padrone c'è ancora: è andato KO
			_poofs.append({"pos": _pos[p.id], "t": now})


# Il compagno di p sta facendo il suo attacco in corso? Come biting() in src/shared/physics/companion.ts
static func biting(p: Dictionary, characters: Dictionary) -> bool:
	if p.get("attack") == null:
		return false
	var spec: Variant = characters.get(p.get("characterId", ""), {}).get("companion")
	return spec is Dictionary and str(p.attack) in spec.get("bites", [])


func is_biting(id: String) -> bool:
	return _biting.get(id, false)


func poof_count() -> int:
	return _poofs.size()


func clear() -> void:
	_target = {}
	_pos = {}
	_moving = {}
	_biting = {}
	_hurt_at = {}
	_poofs = []


# Dov'è disegnato il compagno di id (per i test e per gli effetti), o null
func position_of(id: String) -> Variant:
	return _pos.get(id)


func draw(canvas: CanvasItem, now: int) -> void:
	advance()
	for id in _pos:
		var c: Dictionary = _target[id]
		draw_beagle(canvas, _pos[id], int(c.facing), now, float(_moving[id]) > 0.6, bool(c.get("onGround", true)), is_biting(id))
		if now - int(_hurt_at.get(id, -100000)) < HURT_MS:
			canvas.draw_circle(_pos[id] + Vector2(0, -20), 22.0, Color(1, 0.2, 0.15, 0.45))
	# KO: una nuvoletta grigia che si allarga e svanisce, con tre stelline
	_poofs = _poofs.filter(func(q): return now - int(q.t) < POOF_MS)
	for q in _poofs:
		var k := (now - int(q.t)) / POOF_MS
		var center: Vector2 = q.pos + Vector2(0, -18 - 20 * k)
		for i in 5:
			var a := TAU * i / 5.0
			canvas.draw_circle(center + Vector2(cos(a), sin(a)) * (10 + 18 * k), 9.0 * (1.0 - k * 0.5), Color(0.85, 0.85, 0.85, 1.0 - k))
		for i in 3:
			var a := TAU * i / 3.0 + k * 4.0
			canvas.draw_circle(center + Vector2(cos(a), sin(a) * 0.4) * 22.0 + Vector2(0, -16), 3.0, Color(1, 0.9, 0.3, 1.0 - k))


# Un frame: ognuno va verso il posto dell'ultimo snapshot
func advance() -> void:
	for id in _pos.keys():
		if not _target.has(id):
			_pos.erase(id)
			_moving.erase(id)
	for id in _target:
		var c: Dictionary = _target[id]
		var target := Vector2(float(c.x), float(c.y))
		var pos: Vector2 = _pos.get(id, target)
		var next := target if pos.distance_to(target) > 200 else pos.lerp(target, 0.5)
		_moving[id] = absf(next.x - pos.x)
		_pos[id] = next


# Il beagle di profilo, piedi in base: bianco sotto, sella nera e testa marrone con l'orecchio lungo
# bite: a bocca aperta, allungato in avanti
static func draw_beagle(canvas: CanvasItem, base: Vector2, facing: int, now: int, moving: bool, on_ground: bool, bite := false) -> void:
	var s := float(facing)
	var t := now / 90.0
	var step := sin(t) * 5.0 if moving and on_ground else 0.0
	var body := base + Vector2(0, -20)
	# Zampe: due davanti e due dietro, che vanno avanti e indietro quando corre
	for k in 4:
		var x0 := (-14.0 + 9.0 * k) * s
		var swing := step * (1.0 if k % 2 == 0 else -1.0)
		var foot := base + Vector2(x0 + swing * s, 0) if on_ground else base + Vector2(x0 - 4.0 * s, -4)
		canvas.draw_line(body + Vector2(x0, 4), foot, INK, 6.0)
		canvas.draw_line(body + Vector2(x0, 4), foot, WHITE, 3.5)
	# Coda dritta all'insù con la punta bianca, che scodinzola
	var wag := sin(now / 70.0) * 4.0
	var tail_root := body + Vector2(-20 * s, -4)
	var tail_tip := tail_root + Vector2((-6 + wag) * s, -16)
	canvas.draw_line(tail_root, tail_tip, INK, 6.0)
	canvas.draw_line(tail_root, tail_tip, TAN, 3.5)
	canvas.draw_circle(tail_tip, 3.0, WHITE)
	# Corpo, con la sella nera sulla schiena
	var torso := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		torso.append(body + Vector2(cos(a) * 22.0, sin(a) * 11.0))
	canvas.draw_colored_polygon(torso, WHITE)
	var saddle := PackedVector2Array()
	for k in 9:
		var a := PI + PI * k / 8.0
		saddle.append(body + Vector2(cos(a) * 17.0 - 2.0 * s, sin(a) * 9.5 - 1.0))
	canvas.draw_colored_polygon(saddle, BLACK)
	torso.append(torso[0])
	canvas.draw_polyline(torso, INK, 2.0)
	# Testa marrone col muso bianco, l'occhio e l'orecchio lungo che pende
	var head := body + Vector2(20 * s, -12)
	canvas.draw_circle(head, 10.5, INK)
	canvas.draw_circle(head, 9.0, TAN)
	var muzzle := head + Vector2(9 * s, 4)
	if bite:
		# Il morso: mascella giù e denti bianchi
		var jaw := PackedVector2Array([head + Vector2(3 * s, 6), head + Vector2(17 * s, 13), head + Vector2(15 * s, 16), head + Vector2(2 * s, 10)])
		canvas.draw_colored_polygon(jaw, TAN)
		canvas.draw_polyline(PackedVector2Array([jaw[0], jaw[1], jaw[2], jaw[3]]), INK, 1.5)
		for k in 3:
			canvas.draw_line(muzzle + Vector2((1 + 3 * k) * s, 3), muzzle + Vector2((1 + 3 * k) * s, 6), Color.WHITE, 1.5)
	canvas.draw_circle(muzzle, 6.0, INK)
	canvas.draw_circle(muzzle, 4.8, WHITE)
	canvas.draw_circle(muzzle + Vector2(4 * s, -1), 2.2, BLACK)
	canvas.draw_circle(head + Vector2(3 * s, -3), 1.8, BLACK)
	var ear_sway := sin(t * 0.8) * 2.0 if moving else 0.0
	var ear := PackedVector2Array([head + Vector2(-3 * s, -7), head + Vector2(-8 * s, -4), head + Vector2((-7 + ear_sway) * s, 11), head + Vector2((-1 + ear_sway) * s, 10)])
	canvas.draw_colored_polygon(ear, EAR)
	ear.append(ear[0])
	canvas.draw_polyline(ear, INK, 1.5)
