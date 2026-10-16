# Dove sono e cosa fanno gli elementi dell'arena in un certo istante (trappole, piattaforme mobili,
# getti, pioggia, acqua alta): funzioni pure, senza disegno. Le usano world_view.gd, audio.gd e i test.
extends RefCounted

# Posizione di una piattaforma mobile al tempo t: la stessa formula di moverPosition() in physics/elements.ts
static func mover_position(m: Dictionary, t: float) -> Vector2:
	var pts: Array = m.path
	if pts.size() < 2:
		return Vector2(pts[0].x, pts[0].y)
	var route: Array = pts.duplicate()
	if m.get("loop", false):
		route.append(pts[0])
	else:
		for i in range(pts.size() - 2, -1, -1):
			route.append(pts[i])
	var segments := route.size() - 1
	var pause: float = m.get("pauseMs", 0)
	var lengths: Array[float] = []
	var total := 0.0
	for i in segments:
		var d := Vector2(route[i + 1].x - route[i].x, route[i + 1].y - route[i].y).length()
		lengths.append(d)
		total += d
	var period: float = m.periodMs
	var travel := maxf(1.0, period - pause * segments)
	var left := fposmod(t + float(m.get("offsetMs", 0)), period)
	for i in segments:
		var a := Vector2(route[i].x, route[i].y)
		if left < pause:
			return a
		left -= pause
		var seg_ms: float = travel * lengths[i] / total if total > 0 else travel / segments
		if left < seg_ms:
			return a.lerp(Vector2(route[i + 1].x, route[i + 1].y), left / seg_ms)
		left -= seg_ms
	return Vector2(route[segments].x, route[segments].y)


# Piattaforma ad arco (#244): la striscia spessa thick che segue la curva di PredictMovement.surface_y
static func arch_polygon(p: Dictionary, thick: float, k := 1.0, o := Vector2.ZERO) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var steps := maxi(2, int(float(p.width) / 16.0))
	for i in steps + 1:
		var x: float = float(p.x) + float(p.width) * i / steps
		var y := PredictMovement.surface_y(p, x)
		top.append(o + Vector2(x, y) * k)
		bottom.insert(0, o + Vector2(x, y + thick) * k)
	top.append_array(bottom)
	return top


# Come jetPhase() in physics/elements.ts: "calm", "warn" (bolle) o "active" (getto)
static func jet_phase(j: Dictionary, t: float) -> String:
	var period: float = j.periodMs
	var left := fposmod(t + float(j.get("offsetMs", 0)), period) - (period - float(j.warnMs) - float(j.activeMs))
	if left < 0:
		return "calm"
	return "warn" if left < float(j.warnMs) else "active"


# Il verso di una piattaforma mobile: quello in cui va, o da ferma verso il centro dell'arena
static func mover_facing(m: Dictionary, t: float, arena_width: float) -> int:
	var dx := mover_position(m, t + 50.0).x - mover_position(m, t).x
	if absf(dx) > 0.01:
		return 1 if dx > 0 else -1
	var x := mover_position(m, t).x + float(m.width) / 2.0
	return 1 if x < arena_width / 2.0 else -1


# Il fotogramma dell'animazione di una trappola al tempo t dell'arena (#270)
static func hazard_frame(t: float, fps: float, frames: int) -> int:
	return posmod(int(floorf(t / 1000.0 * fps)), frames)


# Dove si disegna un fotogramma: il piede (footX, footY) sul centro del lato basso del rettangolo che fa male.
# Andando a sinistra si specchia sul posto: la larghezza negativa gira l'immagine (canvas_item_add_texture_rect)
static func hazard_sprite_rect(spr: Dictionary, fw: float, fh: float, r: Rect2, dir: int) -> Rect2:
	var k: float = spr.scale
	var foot_x: float = spr.footX
	var left := r.get_center().x - (foot_x if dir > 0 else fw - foot_x) * k
	var top: float = r.end.y - float(spr.footY) * k
	return Rect2(left, top, fw * k, fh * k) if dir > 0 else Rect2(left, top, -fw * k, fh * k)


# Come hazardActive() in physics/elements.ts
static func hazard_active(h: Dictionary, t: float) -> bool:
	var period: float = h.get("periodMs", 0)
	if period <= 0:
		return true
	return fposmod(t + float(h.get("offsetMs", 0)), period) < float(h.get("activeMs", period / 2.0))


# Come floodPhase() in physics/elements.ts: fase dell'acqua alta (#228) e quanto è avanti (k da 0 a 1)
static func flood_phase(h: Dictionary, t: float) -> Dictionary:
	var f: Dictionary = h.get("flood", {})
	if f.is_empty():
		return {"phase": "calm", "k": 0.0}
	var warn: float = f.warnMs
	var rise: float = f.riseMs
	var hold: float = f.holdMs
	var fall: float = f.get("fallMs", rise)
	var period: float = f.periodMs
	var left := fposmod(t + float(f.get("offsetMs", 0)), period) - (period - (warn + rise + hold + fall))
	if left < 0:
		return {"phase": "calm", "k": 0.0}
	if left < warn:
		return {"phase": "warn", "k": left / warn}
	left -= warn
	if left < rise:
		return {"phase": "rise", "k": left / rise}
	left -= rise
	if left < hold:
		return {"phase": "high", "k": left / hold}
	left -= hold
	return {"phase": "fall", "k": minf(1.0, left / fall) if fall > 0 else 1.0}


# Come hazardRect() in physics/elements.ts: con l'acqua alta la superficie sale, il fondo resta fermo
static func hazard_rect(h: Dictionary, t: float) -> Rect2:
	var tr: Variant = h.get("travel")
	if tr is Dictionary and tr.path.size() >= 2:
		# Trappola che viaggia (#229): lungo il percorso, come hazardRect() in physics/elements.ts
		var tp := travel_phase(h, t)
		var k: float = tp.k
		var along: float = (1.0 - k if tp.reverse else k) if tp.phase == "cross" else (1.0 if tp.reverse else 0.0)
		var p := path_point(tr.path, along)
		return Rect2(p.x, p.y, h.width, h.height)
	var y: float = h.y
	var bottom: float = h.y + h.height
	if h.has("flood"):
		var fp := flood_phase(h, t)
		var k: float = fp.k
		var up := 0.0
		match fp.phase:
			"rise":
				up = k
			"high":
				up = 1.0
			"fall":
				up = 1.0 - k
		y = h.y + (float(h.flood.highY) - h.y) * up
	return Rect2(h.x, y, h.width, bottom - y)


# Quanto piove (0-1) per l'acqua alta: cresce durante l'avviso, piena con l'acqua che sale e alta, cala con la discesa
static func rain_strength(h: Dictionary, t: float) -> float:
	if not h.has("flood"):
		return 0.0
	var fp := flood_phase(h, t)
	var k: float = fp.k
	match fp.phase:
		"warn":
			return k
		"rise", "high":
			return 1.0
		"fall":
			return 1.0 - k
	return 0.0


# Come travelPhase() in physics/elements.ts: calma, avviso o passaggio della trappola che viaggia (#229)
static func travel_phase(h: Dictionary, t: float) -> Dictionary:
	var tr: Variant = h.get("travel")
	if not tr is Dictionary:
		return {"phase": "calm", "k": 0.0, "reverse": false}
	var period: float = tr.periodMs
	var warn: float = tr.warnMs
	var cross: float = tr.crossMs
	var tt: float = t + float(tr.get("offsetMs", 0))
	var reverse: bool = bool(tr.get("alternate", false)) and int(fposmod(floorf(tt / period), 2.0)) == 1
	var left := fposmod(tt, period) - (period - warn - cross)
	if left < 0:
		return {"phase": "calm", "k": 0.0, "reverse": reverse}
	if left < warn:
		return {"phase": "warn", "k": left / warn, "reverse": reverse}
	return {"phase": "cross", "k": minf(1.0, (left - warn) / cross), "reverse": reverse}


# Punto del percorso a una frazione k della sua lunghezza (come pathPoint in physics/elements.ts)
static func path_point(path: Array, k: float) -> Vector2:
	var lengths: Array[float] = []
	var total := 0.0
	for i in range(1, path.size()):
		var d := Vector2(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y).length()
		lengths.append(d)
		total += d
	var left := k * total
	for i in lengths.size():
		if left <= lengths[i] or i == lengths.size() - 1:
			var f: float = minf(1.0, left / lengths[i]) if lengths[i] > 0 else 0.0
			return Vector2(path[i].x, path[i].y).lerp(Vector2(path[i + 1].x, path[i + 1].y), f)
		left -= lengths[i]
	return Vector2(path[0].x, path[0].y)


# Da che parte va in questo giro: 1 verso destra, -1 verso sinistra (come travelDirection)
static func travel_direction(h: Dictionary, t: float) -> int:
	var path: Array = h.travel.path
	var forward := -1 if path[path.size() - 1].x < path[0].x else 1
	return -forward if travel_phase(h, t).reverse else forward


# Pioggia solo grafica (#288): 2 s per arrivare e 2 per smettere, dentro i rainMs di ogni giro
static func life_rain(r: Dictionary, t: float) -> float:
	var k := fposmod(t + float(r.get("offsetMs", 0)), float(r.periodMs))
	var dur: float = r.rainMs
	if k >= dur:
		return 0.0
	return clampf(minf(k, dur - k) / 2000.0, 0.0, 1.0)


# Dove sta uno strato: centrato sull'arena, poi trascinato verso il centro della vista tanto più quanto è lontano.
# parallax 1 = fermo con il palco, 0 = fermo con la telecamera
static func layer_rect(size: Vector2, parallax: float, world_center: Vector2, view_center: Vector2) -> Rect2:
	var center := world_center + (view_center - world_center) * (1.0 - parallax)
	return Rect2(center - size / 2.0, size)
