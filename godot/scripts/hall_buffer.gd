# Interpolazione degli snapshot della sala d'attesa (come snapshot_buffer.gd per la partita, ma in 3D: x, y, z).
# Si disegna la sala com'era delay_ms fa, a metà tra i due snapshot attorno a quell'istante:
# a 30 snapshot al secondo il movimento resta fluido anche se i pacchetti arrivano a scatti.
extends RefCounted

var delay_ms := 100.0
var own_id := "" # il proprio lottatore: ritardo più corto, si sente più pronto
var own_delay_ms := 50.0
var teleport_cm := 400.0 # oltre questo salto tra due snapshot non si interpola (rientro, spinta enorme)
var size := 20

var _frames: Array = [] # [{ t: ora del server, players: { id: HallPlayerState } }]
var _offset := NAN # ora locale - ora del server, stimata


func push(server_time: float, received_at: float, players: Array) -> void:
	# Lo scarto più piccolo visto è il più vicino al vero: i ritardi di rete lo fanno solo crescere
	var sample := received_at - server_time
	_offset = sample if is_nan(_offset) else minf(sample, _offset + 0.5)
	if not _frames.is_empty() and server_time <= float(_frames[-1].t):
		return # fuori ordine o doppio
	var by_id := {}
	for p in players:
		if p is Dictionary:
			by_id[str(p.get("id", ""))] = p
	_frames.append({"t": server_time, "players": by_id})
	if _frames.size() > size:
		_frames.pop_front()


func clear() -> void:
	_frames.clear()
	_offset = NAN


func ids() -> Array:
	return [] if _frames.is_empty() else _frames[-1].players.keys()


# Lo stato da disegnare di tutti i giocatori dell'ultimo snapshot all'ora locale now, con x, y, z interpolate
func sample_all(now: float) -> Dictionary:
	var out := {}
	if is_nan(_offset) or _frames.is_empty():
		return out
	var latest: Dictionary = _frames[-1].players
	for id in latest:
		var delay := own_delay_ms if id == own_id else delay_ms
		out[id] = _at(id, now - _offset - delay)
	return out


func _at(id: String, render_time: float) -> Dictionary:
	var i := _frames.size() - 1
	while i > 0 and float(_frames[i].t) > render_time:
		i -= 1
	var a: Dictionary = _frames[i]
	var pa: Variant = a.players.get(id)
	if pa == null:
		return _frames[-1].players[id] # appena entrato: non c'è un prima
	if i + 1 >= _frames.size() or render_time <= float(a.t):
		return pa
	var b: Dictionary = _frames[i + 1]
	var pb: Variant = b.players.get(id)
	if pb == null:
		return pa
	if Vector3(float(pb.x) - float(pa.x), float(pb.y) - float(pa.y), float(pb.z) - float(pa.z)).length() > teleport_cm:
		return pa if render_time - float(a.t) < float(b.t) - render_time else pb
	var k := (render_time - float(a.t)) / maxf(1.0, float(b.t) - float(a.t))
	var out: Dictionary = pb.duplicate() if k > 0.5 else pa.duplicate()
	out.x = lerpf(float(pa.x), float(pb.x), k)
	out.y = lerpf(float(pa.y), float(pb.y), k)
	out.z = lerpf(float(pa.z), float(pb.z), k)
	out.vy = (float(pb.y) - float(pa.y)) / maxf(1.0, float(b.t) - float(a.t)) * 1000.0 # cm/s: sale o scende
	return out
