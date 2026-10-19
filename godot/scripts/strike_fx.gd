# Effetti dei colpi guidati dalla fisica (#384 B2): solo disegno, i numeri arrivano dallo snapshot.
# - la scia del colpo: una mezzaluna che spazza la zona d'attacco mentre il colpo è attivo, come in Smash;
# - le linee di velocità dietro a chi vola via forte.
# Funzioni pure (niente stato), così i test le provano senza la scena.
extends RefCounted


# L'arco della scia per un colpo con la zona box, tirato da origin (il centro del petto) verso facing.
# L'arco passa dal bordo vicino in alto al bordo lontano in basso della zona, girando attorno a origin.
# Restituisce centro, raggio e angoli di partenza e di arrivo (radianti)
static func arc_for(origin: Vector2, facing: int, box: Rect2) -> Dictionary:
	var far_x := box.end.x if facing == 1 else box.position.x
	var near_x := box.position.x if facing == 1 else box.end.x
	var top := Vector2(lerpf(near_x, far_x, 0.35), box.position.y)
	var bottom := Vector2(far_x, box.end.y)
	var radius := maxf(origin.distance_to(top), origin.distance_to(bottom))
	var a0 := (top - origin).angle()
	var a1 := (bottom - origin).angle()
	# La scia gira sempre dal davanti: a destra in senso orario, a sinistra al contrario
	if facing == 1 and a1 < a0:
		a1 += TAU
	elif facing == -1 and a1 > a0:
		a1 -= TAU
	return {"center": origin, "radius": radius, "a0": a0, "a1": a1}


# Il poligono della mezzaluna: progress da 0 a 1 dice quanto dell'arco è già stato spazzato.
# La punta è sottile, il fondo spesso width. Vuoto se non c'è niente da disegnare
static func crescent(arc: Dictionary, progress: float, width: float, steps := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := clampf(progress, 0.0, 1.0)
	if p <= 0.0 or float(arc.radius) <= 0.0:
		return out
	var a0: float = arc.a0
	var a_end := lerpf(a0, float(arc.a1), p)
	var c: Vector2 = arc.center
	var r: float = arc.radius
	for i in steps + 1:
		var a := lerpf(a0, a_end, float(i) / steps)
		out.append(c + Vector2.from_angle(a) * r)
	for i in range(steps, -1, -1):
		var k := float(i) / steps
		var a := lerpf(a0, a_end, k)
		out.append(c + Vector2.from_angle(a) * (r - width * k)) # più spessa verso la fine del colpo
	return out


# Linee di velocità dietro a chi vola via: n segmenti paralleli alla velocità, sparsi di traverso.
# salt cambia la disposizione a ogni lottatore; i segmenti partono dal corpo e vanno all'indietro
static func speed_lines(pos: Vector2, vel: Vector2, n: int, length: float, spread: float, salt: int) -> Array:
	var out := []
	var speed := vel.length()
	if speed <= 0.0 or n <= 0:
		return out
	var back := -vel / speed
	var side := Vector2(-back.y, back.x)
	for i in n:
		var h := float(absi(hash(salt * 31 + i)) % 1000) / 1000.0 # da 0 a 1, sempre lo stesso per lo stesso segmento
		var across := (float(i) / maxf(1, n - 1) - 0.5) * 2.0 * spread
		var start := pos + side * across + back * (12.0 + 20.0 * h)
		out.append([start, start + back * length * (0.6 + 0.4 * h)])
	return out
