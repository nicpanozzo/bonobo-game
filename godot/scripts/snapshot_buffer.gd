# Interpolazione degli snapshot, la stessa di src/client/interpolation.ts:
# si disegna il mondo com'era qualche ms fa, a metà tra i due snapshot attorno a quell'istante,
# così il movimento resta fluido anche se i pacchetti arrivano a scatti.
class_name SnapshotBuffer
extends RefCounted

var delay_ms := 80.0
var teleport_distance := 300.0
var size := 30
var own_id := "" # il proprio lottatore (E17): niente ritardo d'interpolazione, segue l'ultimo snapshot
var own_extrapolate_ms := 50.0

var _frames: Array = [] # [{ t: ora del server, stage_ms: tempo dell'arena, players: { id: PlayerState } }]
var _offset := NAN # ora locale - ora del server, stimata


func push(server_time: float, received_at: float, players: Array, stage_ms := 0.0) -> void:
	# Lo scarto più piccolo visto è il più vicino al vero: i ritardi di rete lo fanno solo crescere.
	# Si lascia salire piano, nel caso gli orologi derivino.
	var sample := received_at - server_time
	_offset = sample if is_nan(_offset) else minf(sample, _offset + 0.5)
	if not _frames.is_empty() and server_time <= _frames[-1].t:
		return # fuori ordine o doppio
	var by_id := {}
	for p in players:
		by_id[p.id] = p
	_frames.append({"t": server_time, "stage_ms": stage_ms, "players": by_id})
	if _frames.size() > size:
		_frames.pop_front()


# Stato da disegnare per un giocatore all'ora locale `now`, con x e y interpolate
func sample(id: String, now: float) -> Variant:
	return sample_all([id], now).get(id)


# Come sample, per tutti gli id insieme: la coppia di snapshot si cerca una volta sola per frame
func sample_all(ids: Array, now: float) -> Dictionary:
	var out := {}
	if is_nan(_offset) or _frames.is_empty():
		return out
	var render_time := now - _offset - delay_ms
	var i := _frames.size() - 1
	while i > 0 and _frames[i].t > render_time:
		i -= 1
	var a: Dictionary = _frames[i]
	var b: Dictionary = _frames[i + 1] if i + 1 < _frames.size() and render_time > a.t else {}
	for id in ids:
		var p: Variant = latest_now(id, now) if id == own_id else _interpolate(id, a, b, render_time)
		if p != null:
			out[id] = p
	return out


# L'ultimo stato arrivato di un giocatore, spinto avanti per il tempo passato da allora (al massimo
# own_extrapolate_ms): il proprio lottatore si vede circa delay_ms prima (E17 passo 1).
# La velocità è lo spostamento tra gli ultimi due snapshot, non vx/vy: nel fermo di un colpo
# (hitstop, che non viaggia in rete) la posizione non cambia e il lottatore non trema avanti e indietro.
# Fermo anche a terra in verticale, e appeso, preso, in rientro o via.
func latest_now(id: String, now: float) -> Variant:
	if is_nan(_offset):
		return null
	var j := _frames.size() - 1
	while j >= 0 and not _frames[j].players.has(id):
		j -= 1
	if j < 0:
		return null
	var p: Dictionary = _frames[j].players[id]
	if j == 0 or not _frames[j - 1].players.has(id) or p.get("respawning", false) or p.get("eliminated", false) \
			or p.get("away", false) or p.get("ledge") != null or p.get("grabbedBy") != null:
		return p
	var prev: Dictionary = _frames[j - 1].players[id]
	var dt: float = float(_frames[j].t) - float(_frames[j - 1].t)
	var dx: float = float(p.x) - float(prev.x)
	var dy: float = float(p.y) - float(prev.y)
	if absf(dx) > teleport_distance or absf(dy) > teleport_distance:
		return p
	var age := clampf(now - _offset - float(_frames[j].t), 0.0, own_extrapolate_ms)
	var out: Dictionary = p.duplicate()
	out.x = float(p.x) + dx / dt * age
	if not p.get("onGround", false):
		out.y = float(p.y) + dy / dt * age
	return out


func _interpolate(id: String, a: Dictionary, b: Dictionary, render_time: float) -> Variant:
	var pa: Variant = a.players.get(id)
	if b.is_empty() or pa == null:
		return pa if pa != null else _latest(id)
	var pb: Variant = b.players.get(id)
	if pb == null:
		return pa
	if absf(pb.x - pa.x) > teleport_distance or absf(pb.y - pa.y) > teleport_distance:
		return pa if render_time - a.t < b.t - render_time else pb
	var k: float = (render_time - a.t) / (b.t - a.t)
	var out: Dictionary = pa.duplicate()
	out.x = lerpf(pa.x, pb.x, k)
	out.y = lerpf(pa.y, pb.y, k)
	return out


func _latest(id: String) -> Variant:
	for j in range(_frames.size() - 1, -1, -1):
		if _frames[j].players.has(id):
			return _frames[j].players[id]
	return null


# Tempo dell'arena all'ora locale `now`, interpolato come i giocatori: muove ascensori e trappole (#14)
func sample_stage_ms(now: float) -> float:
	if is_nan(_offset) or _frames.is_empty():
		return 0.0
	var render_time := now - _offset - delay_ms
	var i := _frames.size() - 1
	while i > 0 and _frames[i].t > render_time:
		i -= 1
	var a: Dictionary = _frames[i]
	if i + 1 >= _frames.size() or render_time <= a.t:
		# Senza un frame dopo si va avanti con l'orologio, così gli ascensori non si fermano a scatti
		return a.stage_ms + maxf(0.0, render_time - a.t)
	var b: Dictionary = _frames[i + 1]
	return lerpf(a.stage_ms, b.stage_ms, (render_time - a.t) / (b.t - a.t))
