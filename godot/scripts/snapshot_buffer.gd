# Interpolazione degli snapshot, la stessa di src/client/interpolation.ts:
# si disegna il mondo com'era qualche ms fa, a metà tra i due snapshot attorno a quell'istante,
# così il movimento resta fluido anche se i pacchetti arrivano a scatti.
class_name SnapshotBuffer
extends RefCounted

var delay_ms := 80.0
var teleport_distance := 300.0
var size := 30

var _frames: Array = [] # [{ t: ora del server, players: { id: PlayerState } }]
var _offset := NAN # ora locale - ora del server, stimata


func push(server_time: float, received_at: float, players: Array) -> void:
	# Lo scarto più piccolo visto è il più vicino al vero: i ritardi di rete lo fanno solo crescere.
	# Si lascia salire piano, nel caso gli orologi derivino.
	var sample := received_at - server_time
	_offset = sample if is_nan(_offset) else minf(sample, _offset + 0.5)
	if not _frames.is_empty() and server_time <= _frames[-1].t:
		return # fuori ordine o doppio
	var by_id := {}
	for p in players:
		by_id[p.id] = p
	_frames.append({"t": server_time, "players": by_id})
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
		var p: Variant = _interpolate(id, a, b, render_time)
		if p != null:
			out[id] = p
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
