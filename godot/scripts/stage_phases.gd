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
	if phase.is_empty():
		return stage
	var out := stage.duplicate()
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
