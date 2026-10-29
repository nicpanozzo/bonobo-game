# Interpolazione degli snapshot:
# si disegna il mondo com'era qualche ms fa, a metà tra i due snapshot attorno a quell'istante,
# così il movimento resta fluido anche se i pacchetti arrivano a scatti.
class_name SnapshotBuffer
extends RefCounted

var delay_ms := 80.0
var teleport_distance := 300.0
var size := 30
var own_id := "" # il proprio lottatore (E17): niente ritardo d'interpolazione, segue l'ultimo snapshot
var own_extrapolate_ms := 50.0
# Rallentatore solo grafico (#470 passo 2b): ritardo in più sul disegno. Cresce mentre la scena va piano e torna a zero
# quando si rimette in pari (time_warp.gd); la partita sul server non cambia. A zero tutto resta com'era
var extra_delay_ms := 0.0
# Ritardo che si adatta alla rete: se gli snapshot arrivano più in ritardo del solito (wifi, browser lento) il disegno
# va un po' più indietro, fino a max_delay_ms, invece di restare senza lo snapshot dopo e fermarsi a scatti.
# max_delay_ms <= delay_ms lo spegne (il ritardo resta delay_ms)
var max_delay_ms := 0.0
const LATE_FORGET := 0.02 # ms di ritardo dimenticati per ms che passa: un picco pesa per qualche secondo
const ADAPT_UP := 0.1 # di quanto sale il ritardo per ms che passa: il disegno rallenta al massimo del 10%
const ADAPT_DOWN := 0.02 # e di quanto scende: accelera del 2%, non si nota
const ADAPT_MARGIN_MS := 5.0 # aria in più oltre al ritardo più alto visto

var _frames: Array = [] # [{ t: ora del server, stage_ms: tempo dell'arena, players: { id: PlayerState } }]
var _offset := NAN # ora locale - ora del server, stimata
var _late := 0.0 # ritardo di arrivo più alto visto di recente rispetto al più veloce, ms (scende piano)
var _gap := 0.0 # ora del server tra due snapshot, ms (media)
var _adapt := 0.0 # ritardo in più per la rete di adesso, ms
var _last_received := NAN


func push(server_time: float, received_at: float, players: Array, stage_ms := 0.0) -> void:
	# Lo scarto più piccolo visto è il più vicino al vero: i ritardi di rete lo fanno solo crescere.
	# Si lascia salire piano, nel caso gli orologi derivino.
	var sample := received_at - server_time
	_offset = sample if is_nan(_offset) else minf(sample, _offset + 0.5)
	if not _frames.is_empty() and server_time <= _frames[-1].t:
		return # fuori ordine o doppio
	_adapt_delay(sample - _offset, received_at, server_time - float(_frames[-1].t) if not _frames.is_empty() else 0.0)
	var by_id := {}
	for p in players:
		by_id[p.id] = p
	_frames.append({"t": server_time, "stage_ms": stage_ms, "players": by_id})
	if _frames.size() > size:
		_frames.pop_front()


# Per interpolare tra due snapshot serve già quello dopo: il ritardo deve coprire l'intervallo tra due snapshot
# più il ritardo di arrivo peggiore. Si sposta piano, così il disegno non salta
func _adapt_delay(late: float, received_at: float, gap: float) -> void:
	var dt := 0.0 if is_nan(_last_received) else maxf(0.0, received_at - _last_received)
	_last_received = received_at
	if max_delay_ms <= delay_ms:
		_adapt = 0.0
		return
	if gap > 0.0:
		_gap = gap if _gap <= 0.0 else lerpf(_gap, gap, 0.1)
	_late = maxf(late, _late - dt * LATE_FORGET)
	var target := clampf(_late + _gap + ADAPT_MARGIN_MS - delay_ms, 0.0, max_delay_ms - delay_ms)
	_adapt = move_toward(_adapt, target, dt * (ADAPT_UP if target > _adapt else ADAPT_DOWN))


# Il ritardo con cui si disegnano gli altri adesso, ms (senza il rallentatore)
func current_delay() -> float:
	return delay_ms + _adapt


# Stato da disegnare per un giocatore all'ora locale `now`, con x e y interpolate
func sample(id: String, now: float) -> Variant:
	return sample_all([id], now).get(id)


# Come sample, per tutti gli id insieme: la coppia di snapshot si cerca una volta sola per frame
func sample_all(ids: Array, now: float) -> Dictionary:
	var out := {}
	if is_nan(_offset) or _frames.is_empty():
		return out
	var render_time := now - _offset - delay_ms - _adapt - extra_delay_ms
	var i := _frames.size() - 1
	while i > 0 and _frames[i].t > render_time:
		i -= 1
	var a: Dictionary = _frames[i]
	var b: Dictionary = _frames[i + 1] if i + 1 < _frames.size() and render_time > a.t else {}
	for id in ids:
		# al rallentatore anche il proprio lottatore va piano con gli altri: niente scorciatoia sull'ultimo snapshot
		var p: Variant = latest_now(id, now) if id == own_id and extra_delay_ms <= 0.0 else _interpolate(id, a, b, render_time)
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
	# Atterraggio (#227): il lottatore tocca terra a metà intervallo, e la retta tra i due snapshot
	# lo farebbe rallentare prima del suolo. Si scende alla velocità che aveva in aria, poi si resta a terra.
	if pb.get("onGround", false) and not pa.get("onGround", false) and pb.y > pa.y:
		var fall_speed := maxf(float(pa.get("vy", 0.0)) / 1000.0, (pb.y - pa.y) / (b.t - a.t))
		out.y = minf(pa.y + fall_speed * (render_time - a.t), pb.y)
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
	var render_time := now - _offset - delay_ms - _adapt - extra_delay_ms
	var i := _frames.size() - 1
	while i > 0 and _frames[i].t > render_time:
		i -= 1
	var a: Dictionary = _frames[i]
	if i + 1 >= _frames.size() or render_time <= a.t:
		# Senza un frame dopo si va avanti con l'orologio, così gli ascensori non si fermano a scatti
		return a.stage_ms + maxf(0.0, render_time - a.t)
	var b: Dictionary = _frames[i + 1]
	return lerpf(a.stage_ms, b.stage_ms, (render_time - a.t) / (b.t - a.t))


# Il disegno è arrivato all'istante del server server_t? (#470 passo 2b) Gli eventi di uno snapshot trattenuto durante
# il rallentatore partono quando il disegno lo raggiunge, con lo stesso anticipo di sempre (delay_ms): senza
# rallentatore è sempre vero, e gli eventi partono subito come prima
func reached(server_t: float, now: float) -> bool:
	return is_nan(_offset) or server_t <= now - _offset - extra_delay_ms
