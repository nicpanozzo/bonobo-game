# KO stella e KO sullo schermo (#470 fase 4), solo disegno. Come in Smash, ogni tanto chi esce dall'alto non esplode
# nella colonna: vola piccolo nello sfondo e si spegne in una stellina ("star"), o più di rado torna enorme verso lo
# schermo, ci resta spiaccicato e scivola giù ("screen"). Mai all'ultimo KO della partita (ha già il suo GAME!) e lo
# schermo mai con la modalità calma (ha un lampo).
# Il caso viene da chi esce, dal punto d'uscita e dalle vite rimaste, che sono uguali per tutti: tutti vedono la stessa
# stella. Funzioni pure come time_warp.gd: world_view.gd tiene lo stato e disegna.
# Le posizioni sono relative all'inquadratura (view): la stella resta ferma sullo schermo anche se la telecamera si muove.


# Quale KO speciale, "" se nessuno. zone: stage.blastZone; final: l'ultimo KO della partita
static func pick(id: String, x: float, y: float, stocks_left: int, zone: Dictionary, final: bool, calm: bool, fx: Dictionary) -> String:
	if final or y >= float(zone.get("top", -INF)) or x < float(zone.get("left", -INF)) or x > float(zone.get("right", INF)):
		return ""
	var roll := roll_of(id, x, y, stocks_left)
	var screen: float = fx.get("koScreenChance", 0.0)
	if roll < screen:
		return "" if calm else "screen"
	return "star" if roll < screen + float(fx.get("koStarChance", 0.0)) else ""


# Un numero da 0 a 1 uguale su tutti i client per lo stesso KO
static func roll_of(id: String, x: float, y: float, stocks_left: int) -> float:
	return float(hash("%s|%d|%d|%d" % [id, roundi(x), roundi(y), stocks_left]) & 0xFFFF) / 65536.0


# Quanto dura tutto, ms dal KO
static func duration(kind: String, fx: Dictionary) -> float:
	if kind == "star":
		return float(fx.koStarDelayMs) + float(fx.koStarTravelMs) + float(fx.koStarTwinkleMs)
	return float(fx.koScreenDelayMs) + float(fx.koScreenApproachMs) + float(fx.koScreenStickMs) + float(fx.koScreenSlideMs)


# KO stella a ms dal KO: { pos, scale (rispetto all'altezza dell'inquadratura), rot } mentre vola nello sfondo,
# { twinkle (scala da 0 a 1.25), pos } quando brilla, vuoto prima e dopo. from_x: dove è uscito
static func star_at(ms: float, view: Rect2, from_x: float, fx: Dictionary) -> Dictionary:
	var travel: float = fx.koStarTravelMs
	var a := ms - float(fx.koStarDelayMs)
	if a < 0.0:
		return {}
	var start := Vector2(clampf(from_x, view.position.x + view.size.x * 0.15, view.end.x - view.size.x * 0.15), view.position.y + view.size.y * 0.09)
	var end := Vector2(lerpf(start.x, view.get_center().x, 0.6), view.position.y + view.size.y * 0.26)
	if a < travel:
		var k := a / travel
		return {"pos": start.lerp(end, 1.0 - (1.0 - k) * (1.0 - k)), "scale": 0.21 * (0.95 * pow(1.0 - k, 1.5) + 0.04), "rot": a / 60.0}
	var k2 := (a - travel) / float(fx.koStarTwinkleMs)
	if k2 >= 1.0:
		return {}
	var tw := (1.0 - (1.0 - k2 / 0.25) * (1.0 - k2 / 0.25)) * 1.25 if k2 < 0.25 else 1.25 * (1.0 - (k2 - 0.25) / 0.75)
	return {"pos": end, "twinkle": tw, "spin": k2 * 1.2}


# KO sullo schermo a ms dal KO: { pos, scale (rispetto all'altezza dell'inquadratura), sx, sy (schiacciato), rot,
# alpha, hands (mani sul vetro), flash (lampo dell'urto da 0 a 1), smear (la striscia che lascia scivolando) }
static func screen_at(ms: float, view: Rect2, fx: Dictionary) -> Dictionary:
	var a := ms - float(fx.koScreenDelayMs)
	var approach: float = fx.koScreenApproachMs
	var stick: float = fx.koScreenStickMs
	var slide: float = fx.koScreenSlideMs
	var c := view.get_center()
	var hit := Vector2(c.x + view.size.x * 0.02, view.position.y + view.size.y * 0.55)
	var full := 0.74 # alto quasi tre quarti dello schermo
	if a < 0.0 or a >= approach + stick + slide:
		return {}
	if a < approach: # arriva da lontano girando, sempre più grande
		var k := a / approach
		var e := k * k
		return {"pos": Vector2(c.x, view.position.y + view.size.y * 0.2).lerp(hit, e), "scale": lerpf(0.05, full, e), "sx": 1.0, "sy": 1.0,
			"rot": (1.0 - k) * 4.0, "alpha": 1.0, "hands": false, "flash": 0.0, "smear": 0.0}
	var b := a - approach
	var sq := 1.0 + 0.18 * sin(b / 120.0 * PI) if b < 120.0 else 1.0 # lo schiaffo contro il vetro
	var s := maxf(0.0, b - stick) / slide
	var dy := view.size.y * 1.15 * s * s
	return {"pos": hit + Vector2(0, dy), "scale": full, "sx": 1.16 * sq, "sy": 0.86 / sq, "rot": s * 0.15,
		"alpha": 1.0 if s < 0.7 else (1.0 - s) / 0.3, "hands": true, "flash": maxf(0.0, 1.0 - b / 110.0),
		"smear": (1.0 - s) * minf(1.0, dy / (view.size.y * 0.7)) if s > 0.0 else 0.0}


# I punti di una stella a quattro punte attorno a c, ruotata di rot
static func sparkle_points(c: Vector2, radius: float, rot: float, inner := 0.2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot - PI / 2.0 + i * PI / 4.0
		pts.append(c + Vector2(cos(a), sin(a)) * (radius if i % 2 == 0 else radius * inner))
	return pts
