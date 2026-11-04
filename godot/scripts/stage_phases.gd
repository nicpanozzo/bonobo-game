# Fasi di un'arena (#433): quale è attiva al tempo dell'arena (stageMs), la telecamera che chiede e il testo
# grande da mostrare quando cambia o sta per cambiare. Solo grafica: tutto dallo stageMs dello snapshot.
# La forma di `phases` è quella di StageSpec: [{ id, name, startMs, announce?, warnMs?, blastZone?, respawn?, camera? }],
# ordinate per startMs.
extends RefCounted


# La fase attiva al tempo t: l'ultima con startMs <= t. Dictionary vuoto se l'arena non ha fasi o non sono ancora cominciate
static func active(stage: Dictionary, t: float) -> Dictionary:
	var phases: Variant = stage.get("phases")
	if not (phases is Array):
		return {}
	var found := {}
	for p in phases:
		if float(p.startMs) <= t:
			found = p
		else:
			break
	return found


# L'arena con i campi della fase attiva al posto dei suoi: camera (campo per campo) e blastZone
static func effective_stage(stage: Dictionary, t: float) -> Dictionary:
	var phase := active(stage, t)
	var rise: Variant = stage.get("rise")
	if phase.is_empty() and not (rise is Dictionary):
		return stage
	var out := stage.duplicate()
	if rise is Dictionary: # Il Diluvio: la zona di espulsione sale col mare, la telecamera non scende sotto la superficie
		var up := rise_offset(rise, floorf(maxf(t, 0.0) / float(rise.stepMs)) * float(rise.stepMs))
		var z: Dictionary = stage.blastZone
		out.blastZone = {"left": z.left, "right": z.right, "top": float(z.top) - up, "bottom": float(z.bottom) - up}
		if phase.is_empty():
			return out
	if phase.get("camera") is Dictionary:
		var cam: Dictionary = stage.get("camera") if stage.get("camera") is Dictionary else {}
		var merged := cam.duplicate()
		merged.merge(phase.camera, true)
		out.camera = merged
	if phase.get("blastZone") is Dictionary:
		out.blastZone = phase.blastZone
	return out


# Avvicina la telecamera "corrente" (minZoom, maxZoom, floorY) a quella chiesta dalla fase: ~95% in blend_ms.
# Un campo che la fase non chiede più (floorY) cade di colpo. Restituisce la nuova telecamera corrente.
static func blend_camera(current: Dictionary, target: Dictionary, delta: float, blend_ms: float) -> Dictionary:
	var k := 1.0 - exp(-delta * 3000.0 / maxf(blend_ms, 1.0))
	var out := {}
	for key in ["minZoom", "maxZoom", "floorY"]:
		if not target.has(key):
			continue
		out[key] = lerpf(float(current[key]), float(target[key]), k) if current.has(key) else float(target[key])
	return out


# Il testo grande al tempo t: { text, alpha, warn } o vuoto. Il nome della fase appena cominciata dura banner_ms
# (sfuma alla fine); warnMs prima della fase dopo si mostra il suo `announce`.
static func banner(stage: Dictionary, t: float, banner_ms: float) -> Dictionary:
	var phases: Variant = stage.get("phases")
	if not (phases is Array):
		return {}
	var phase := active(stage, t)
	if not phase.is_empty():
		var since := t - float(phase.startMs)
		if since < banner_ms:
			return {"text": str(phase.name), "alpha": clampf((banner_ms - since) / 400.0, 0.0, 1.0), "warn": false}
	for p in phases:
		var start := float(p.startMs)
		var warn := float(p.get("warnMs", 0.0))
		if start > t and warn > 0.0 and t >= start - warn and str(p.get("announce", "")) != "":
			return {"text": str(p.announce), "alpha": 1.0, "warn": true}
	return {}


# Il premio (#433): "PONTEGGI PER LA SQUADRA N!" per banner_ms da prizeShowMs (senza, prizeAtMs), solo se il server ha
# congelato una squadra in testa (prize_team > 0). { text, alpha } o vuoto
static func prize_banner(stage: Dictionary, t: float, prize_team: int, banner_ms: float) -> Dictionary:
	if prize_team <= 0 or stage.get("prizeAtMs") == null:
		return {}
	var start := float(stage.get("prizeShowMs", stage.prizeAtMs))
	var since := t - start
	if since < 0.0 or since >= banner_ms:
		return {}
	return {"text": "PONTEGGI PER LA SQUADRA %d!" % prize_team, "alpha": clampf((banner_ms - since) / 400.0, 0.0, 1.0)}


# Il Diluvio: di quanto è salito il mare a t (ms), come riseOffset in physics/timed.ts
static func rise_offset(r: Dictionary, t: float) -> float:
	var s := maxf(0.0, t - float(r.startMs)) / 1000.0
	return minf(float(r.maxPx), float(r.pxPerS) * s + 0.5 * float(r.get("accelPxPerS2", 0.0)) * s * s)


# Dove sta la superficie del mare a t, senza scalini (per il disegno)
static func water_y(r: Dictionary, t: float) -> float:
	return float(r.waterY) - rise_offset(r, t)
