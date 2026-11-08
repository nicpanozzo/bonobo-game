# Le maglie della catena dell'ancora di Capt. OrsoBlu (#547): solo geometria, la disegna world_view.gd.
# sag: di quanti pixel pende nel mezzo (0 = tesa, quando l'ancora è piantata)
extends RefCounted

const LINK_PX := 10.0 # distanza tra una maglia e l'altra


# Le maglie dalle mani alla punta: centro (at) e verso (dir, lungo la catena) di ognuna
static func links(hand: Vector2, tip: Vector2, sag: float) -> Array:
	var out := []
	var length := hand.distance_to(tip)
	var n := maxi(1, int(length / LINK_PX))
	var prev := hand
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var at := hand.lerp(tip, t) + Vector2(0, sag * 4.0 * t * (1.0 - t))
		var d := (at - prev).normalized() if at.distance_to(prev) > 0.01 else Vector2.RIGHT
		out.append({"at": (at + prev) / 2.0, "dir": d})
		prev = at
	return out
