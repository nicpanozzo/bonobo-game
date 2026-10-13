# Luce e ombre del sole e della luna (#288): da dove arriva la luce in un momento del giorno, quanto è alta e quanto
# è forte, e la forma delle ombre che fa. Solo grafica: world_view.gd la usa per le ombre a terra dei lottatori e
# delle decorazioni, e per una luce calda o fredda che arriva dal lato dell'astro. Fasi come stage_life.gd:
# 0 mezzogiorno, 0,25 tramonto, 0,5 mezzanotte, 0,75 alba.
extends RefCounted

const SHADOW_DAY := 0.5 # quanto è scura l'ombra col sole alto
const SHADOW_NIGHT := 0.24 # con la luna
const MIN_LEN := 8.0 # pixel di mondo dell'ombra con l'astro allo zenit
const MAX_LEN := 120.0 # e al tramonto, quando è bassissimo


# side: da che parte arriva la luce, da -1 (sinistra) a 1 (destra); elev: altezza dell'astro, da 0 all'orizzonte a 1
# in cima; strength: quanto si vedono le ombre; sun: true di giorno; tint: il colore della luce sul lato dell'astro
static func light(phase: float) -> Dictionary:
	var p := fposmod(phase, 1.0)
	var sun := p < 0.25 or p >= 0.75
	var k := fposmod(p + 0.25, 0.5) / 0.5 # 0 sorge a sinistra, 0,5 in cima, 1 tramonta a destra
	var elev := sin(k * PI)
	var side := (k - 0.5) * 2.0
	var strength := (SHADOW_DAY if sun else SHADOW_NIGHT) * clampf(elev * 3.0, 0.0, 1.0) # all'orizzonte sfuma
	var low := 1.0 - elev # 1 vicino all'orizzonte: luce calda di alba e tramonto
	var tint := Color(1.0, 0.92 - 0.25 * low, 0.75 - 0.4 * low) if sun else Color(0.72, 0.8, 1.0)
	return {"side": side, "elev": elev, "strength": strength, "sun": sun, "tint": tint}


# Lunghezza dell'ombra a terra: corta a mezzogiorno, lunga quando l'astro è basso
static func shadow_length(l: Dictionary) -> float:
	return clampf(MIN_LEN / maxf(float(l.elev), 0.07), MIN_LEN, MAX_LEN)


# L'ombra a terra come un'ellisse schiacciata sulla superficie: parte dai piedi (feet) e si allunga dalla parte
# opposta alla luce. width è la larghezza di chi la fa; above i pixel tra i piedi e la superficie (salta: l'ombra
# si stringe e schiarisce). Restituisce [poligono, alfa], alfa 0 se non c'è ombra
static func shadow(feet: Vector2, width: float, l: Dictionary, above := 0.0) -> Array:
	var alpha := float(l.strength) * clampf(1.0 - above / 260.0, 0.0, 1.0)
	if alpha <= 0.01:
		return [PackedVector2Array(), 0.0]
	var length := shadow_length(l) * (1.0 + above / 200.0)
	var dir := -signf(float(l.side)) if absf(float(l.side)) > 0.02 else 0.0
	var half := width * 0.5 * (1.0 - clampf(above / 400.0, 0.0, 0.5)) + length * 0.5 * absf(float(l.side))
	var cx := feet.x + dir * length * 0.5 * absf(float(l.side))
	var ry := 6.5
	# Il cerchio unitario allargato e spostato dal motore: in GDScript punto per punto costava molto con tante ombre
	var pts := Transform2D(0.0, Vector2(half, ry), 0.0, Vector2(cx, feet.y + 2.0)) * _unit
	return [pts, alpha]


static var _unit := _unit_circle() # i 20 punti dell'ombra sul cerchio di raggio 1


static func _unit_circle() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		out.append(Vector2(cos(a), sin(a)))
	return out
