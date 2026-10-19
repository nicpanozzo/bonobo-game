# Squash & stretch del movimento: solo grafica, la fisica resta del server.
# Chi salta si allunga, chi atterra si schiaccia, chi corre si piega in avanti.
# Come hit_reaction.gd: una molla smorzata in forma chiusa, senza stato per frame.
extends RefCounted

const HitReaction := preload("res://scripts/hit_reaction.gd")


# Il rimbalzo che parte all'evento kind ("jump" o "land") all'istante at_ms; fx = game.effects.
# amount positivo schiaccia, negativo allunga (come squash di hit_reaction.gd)
static func start(fx: Dictionary, kind: String, at_ms: float) -> Dictionary:
	var amount := -float(fx.get("jumpStretch", 0.0)) if kind == "jump" else float(fx.get("landSquash", 0.0))
	return {"at": at_ms, "amount": amount}


# Lo schiacciamento all'istante now_ms: pieno all'evento, torna a zero esatto a fine bounceMs
static func squash(r: Dictionary, fx: Dictionary, now_ms: float) -> float:
	var t := now_ms - float(r.at)
	var length := float(fx.get("bounceMs", 0.0))
	if t < 0.0 or t >= length:
		return 0.0
	var fade := exp(-3.0 * t / length) * (1.0 - t / length)
	return float(r.amount) * fade * cos(TAU * float(fx.get("bounceHz", 0.0)) * t / 1000.0)


# Quanto si piega in avanti chi corre a terra (radianti, positivo = orario): niente camminando,
# pieno alla velocità di corsa; walk e run sono FIGHTER.groundSpeed e DASH.runSpeed
static func lean(p: Dictionary, fx: Dictionary, walk: float, run: float) -> float:
	if not p.get("onGround", false) or p.get("attack") != null or p.get("hitstun", false):
		return 0.0
	var vx := float(p.get("vx", 0.0))
	var k := clampf((absf(vx) - walk) / maxf(1.0, run - walk), 0.0, 1.0)
	return signf(vx) * float(fx.get("runLean", 0.0)) * k


# La deformazione con il perno sui piedi (la stessa di hit_reaction.gd)
static func transform(feet: Vector2, squash_amount: float, angle: float) -> Transform2D:
	return HitReaction.transform(feet, {"angle": angle, "squash": squash_amount, "offset": 0.0})
