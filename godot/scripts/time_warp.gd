# Rallentatore solo grafico (#470 passo 2b): le fasi e quanto ritardo in più si accumula sul disegno.
# Il server non rallenta: il disegno resta indietro (SnapshotBuffer.extra_delay_ms) mentre la scena va piano, poi si
# rimette in pari andando un po' più veloce. Funzioni pure, come particle_fx.gd: world_view.gd tiene lo stato.
#
# Un rallentatore è un Dictionary: { kind: "finish" | "game", phase, t0 (ms reali di inizio fase), until (ms reali di
# fine fase), factor (velocità della scena, 1 = normale), zoom (quanto stringe al massimo), point (Vector2), target }.
# Fasi: "slow" (il colpo che chiude la partita, al 12%), "follow" (si segue chi vola via), "game" (l'ultimo KO),
# "catch" (ci si rimette in pari). Vuoto = niente rallentatore.

const StagePhases := preload("res://scripts/stage_phases.gd")
const PredictMovement := preload("res://scripts/predict/movement.gd")


# Il colpo che chiude la partita (come il Finish Zoom di Smash): fermo quasi del tutto e zoom stretto sul colpo
static func finish(now: float, point: Vector2, target: String, fx: Dictionary) -> Dictionary:
	return {"kind": "finish", "phase": "slow", "t0": now, "until": now + float(fx.finishSlowMs),
		"factor": float(fx.finishSlowFactor), "zoom": float(fx.finishZoom), "point": point, "target": target}


# L'ultimo KO: al rallentatore e con lo zoom sul punto dove esce, mentre arriva GAME!
static func game(now: float, point: Vector2, fx: Dictionary) -> Dictionary:
	return {"kind": "game", "phase": "game", "t0": now, "until": now + float(fx.gameSlowMs),
		"factor": float(fx.gameSlowFactor), "zoom": float(fx.gameZoom), "point": point, "target": ""}


# Un passo di dt_ms reali all'ora now: restituisce { warp, extra } con la fase aggiornata e il nuovo ritardo in più.
# Mentre la scena va a velocità factor il ritardo cresce di dt·(1 - factor); in "catch" scende di dt·(warpCatchUp - 1).
# Non supera warpMaxDelayMs: oltre, il buffer non ha più snapshot vecchi abbastanza
static func step(w: Dictionary, extra: float, dt_ms: float, now: float, fx: Dictionary) -> Dictionary:
	if w.is_empty():
		return {"warp": w, "extra": 0.0}
	if w.phase == "catch":
		extra = maxf(0.0, extra - dt_ms * (float(fx.warpCatchUp) - 1.0))
		var c := w.duplicate()
		c.extra_now = extra
		return {"warp": {} if extra <= 0.0 else c, "extra": extra}
	extra = minf(float(fx.warpMaxDelayMs), extra + dt_ms * (1.0 - float(w.factor)))
	if now >= float(w.until):
		w = next_phase(w, now, extra, fx)
	return {"warp": w, "extra": extra}


# Dopo il colpo decisivo si segue chi vola via; dopo tutto il resto ci si rimette in pari
static func next_phase(w: Dictionary, now: float, extra: float, fx: Dictionary) -> Dictionary:
	if w.kind == "finish" and w.phase == "slow":
		var f := w.duplicate()
		f.phase = "follow"
		f.t0 = now
		f.until = now + float(fx.finishFollowMs)
		f.factor = float(fx.finishFollowFactor)
		f.zoom = float(fx.finishZoom) * 0.55
		return f
	var c := w.duplicate()
	c.phase = "catch"
	c.t0 = now
	c.extra0 = extra # da quanto si parte: lo zoom si apre man mano che il ritardo torna a zero
	c.zoom0 = zoom(w, now)
	return c


# Quanto stringe la telecamera adesso (1 = niente). Entra in fretta, nel colpo decisivo si apre negli ultimi istanti
# prima di seguire chi vola, e in "catch" torna a 1 insieme al ritardo
static func zoom(w: Dictionary, now: float) -> float:
	if w.is_empty():
		return 1.0
	if w.phase == "catch":
		return 1.0 + (float(w.get("zoom0", 1.0)) - 1.0) * clampf(float(w.get("extra_now", w.get("extra0", 0.0))) / maxf(1.0, float(w.get("extra0", 1.0))), 0.0, 1.0)
	var k := clampf((now - float(w.t0)) / 120.0, 0.0, 1.0) # in 120 ms è già stretta
	var a := 1.0 - (1.0 - k) * (1.0 - k)
	return 1.0 + float(w.zoom) * a


# Quanto è invertita la scena nel colpo decisivo (0 niente, 1 tutta): scatta subito, resta, sfuma nell'ultimo quinto
static func negative(w: Dictionary, now: float) -> float:
	if w.is_empty() or w.kind != "finish" or w.phase != "slow":
		return 0.0
	var k := clampf((now - float(w.t0)) / maxf(1.0, float(w.until) - float(w.t0)), 0.0, 1.0)
	return minf(1.0, k / 0.06) * (1.0 if k < 0.8 else (1.0 - k) / 0.2)


# La scritta GAME! all'istante k (da 0 a 1 della sua vita): entra grande e scatta al suo posto, poi resta; sparisce alla fine
static func game_text_scale(k: float) -> float:
	if k < 0.0 or k >= 1.0:
		return 0.0
	if k < 0.08:
		return 2.4 - 1.5 * (k / 0.08)
	if k < 0.13:
		return 0.9 + 0.1 * (k - 0.08) / 0.05
	return 1.0


# Il colpo manderà fuori? (#470, correzione) Come il Finish Zoom di Smash si guarda solo il lancio: la velocità subito
# dopo il colpo, la gravità del personaggio, il freno del volo da storditi e il terreno. In più si suppone che chi vola
# si difenda con tutta la correzione (influenza contro il lancio): lo zoom parte solo quando il KO è quasi sicuro, mai
# per un colpo che lascia in gioco. Dopo lo stordimento si guarda ancora extra_ms di slancio, senza salti (0: chi esce
# dallo stordimento sul bordo di solito salta e si salva). Confrontata con la fisica vera su 880 lanci per arena: sei arene
# su sette senza falsi allarmi; nella fabbrica solo chi viene spinto sugli spuntoni, che lo rilanciano.
# pos: i piedi; zone: stage.blastZone; solids e platforms dell'arena (si atterra sopra e si sbatte contro i solidi).
# phys: gravity (px/s², già per la gravità del personaggio), drag (freno per tick in volo), dt (s di combattimento per
# tick), hitstun_ms, drift (px/s² di correzione), air_friction (px/s²), max_fall (px/s), extra_ms
static func predicts_ko(pos: Vector2, vel: Vector2, zone: Dictionary, solids: Array, platforms: Array, phys: Dictionary) -> bool:
	var dt: float = phys.dt
	var stun_ticks := int(ceil(float(phys.hitstun_ms) / (dt * 1000.0)))
	var total := stun_ticks + int(ceil(float(phys.extra_ms) / (dt * 1000.0)))
	var x := pos.x
	var y := pos.y
	var vx := vel.x
	var vy := vel.y
	for i in total:
		var stunned := i < stun_ticks
		if stunned:
			vx *= float(phys.drag)
			vx -= signf(vx) * float(phys.drift) * dt # chi vola si difende
			vy += float(phys.gravity) * dt
		else:
			vx = move_toward(vx, 0.0, float(phys.air_friction) * dt)
			vy = minf(vy + float(phys.gravity) * dt, float(phys.max_fall))
		var nx := x + vx * dt
		var ny := y + vy * dt
		if _blocked(x, y, nx, ny, solids, platforms):
			return false
		x = nx
		y = ny
		# dal fondo no: con un colpo verso il basso ci si aggrappa ancora al bordo, e lo zoom partirebbe a vuoto
		if x < float(zone.left) or x > float(zone.right) or y < float(zone.top):
			return true
	return false


# Il volo si ferma su qualcosa? Scendendo si atterra sopra un solido o una piattaforma; dentro un solido si sbatte
static func _blocked(x: float, y: float, nx: float, ny: float, solids: Array, platforms: Array) -> bool:
	for s in solids:
		var r := Rect2(float(s.x), float(s.y), float(s.width), float(s.get("height", 40)))
		if r.has_point(Vector2(nx, ny)) or (ny >= r.position.y and y < r.position.y and nx >= r.position.x and nx <= r.end.x):
			return true
	for p in platforms:
		var top := (float(p.y) + float(p.y2)) / 2.0 if p.has("y2") else float(p.y) # Bologna: piattaforme inclinate, l'altezza media
		if ny > y and y < top and ny >= top and nx >= float(p.x) and nx <= float(p.x) + float(p.width):
			return true
	return false


# L'arena com'è al tempo t (ms dell'arena), come la vede il server: la zona di espulsione della fase attiva (Bologna la
# sposta di fase in fase: sotto le Torri il cielo finisce a 1300, sulle torri a 300) e solo i pezzi a tempo che ci sono.
# Con la zona dell'arena di partenza chi stava sulle torri era già "fuori" e ogni colpo faceva partire lo zoom.
# prize: la squadra del premio (pezzi forLeader). { zone, solids, platforms }
static func arena_at(stage: Dictionary, t: float, prize := 0) -> Dictionary:
	var zone: Variant = StagePhases.effective_stage(stage, t).get("blastZone")
	var solids: Array = (stage.get("solids", []) as Array).filter(func(s): return PredictMovement.piece_on(s, t, prize))
	var platforms: Array = (stage.get("platforms", []) as Array).filter(func(p): return PredictMovement.piece_on(p, t, prize))
	return {"zone": zone if zone is Dictionary else {}, "solids": solids, "platforms": platforms}
