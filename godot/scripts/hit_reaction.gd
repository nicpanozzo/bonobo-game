# Reazione procedurale a un colpo (#305): solo grafica, la fisica resta del server.
# Gli sprite sono fotogrammi disegnati, non ossa: invece di una clip fissa si deforma lo sprite
# attorno ai piedi in base a dove arriva il colpo, da che parte e quanto forte.
# Testa: si piega all'indietro. Gambe: le gambe partono e il busto cade verso chi colpisce.
# Pancia: si schiaccia. Una molla smorzata in forma chiusa riporta dritti, senza stato per frame.
extends RefCounted


# fx = game.effects; height = altezza del punto d'impatto sul corpo (0 piedi, 1 testa);
# dir = +1 se il colpo spinge verso destra, -1 verso sinistra; at_ms = quando arriva il colpo;
# stop_ms = il fermo del colpo (HITSTOP), in cui chi è colpito trema sul posto come in Smash
static func start(fx: Dictionary, height: float, dir: int, knockback: float, at_ms: float, stop_ms := 0.0) -> Dictionary:
	var k := clampf(knockback / float(fx.hitReactFullKnockback), float(fx.hitReactMinStrength), 1.0)
	var h := clampf(height, 0.0, 1.0)
	var lean := 2.0 * h - 1.0 # -1 gambe, 0 pancia, +1 testa
	return {
		"at": at_ms,
		"tilt": dir * float(fx.hitReactTilt) * k * lean,
		"squash": float(fx.hitReactSquash) * k * (1.0 - absf(lean)),
		"recoil": dir * float(fx.hitReactRecoil) * k,
		"stop": stop_ms,
		"shake": float(fx.get("hitShakePx", 0.0)) * k,
	}


# Il fermo di un colpo dal suo danno, come resolveHits() in attacks.ts (hitstop = HITSTOP di constants.ts)
static func stop_ms(hitstop: Dictionary, damage: float) -> float:
	if hitstop.is_empty():
		return 0.0
	return minf(float(hitstop.maxMs), float(hitstop.baseMs) + float(hitstop.perDamageMs) * damage)


# Quanto vale la reazione all'istante now_ms: angolo (radianti, positivo = orario),
# schiacciamento (frazione dell'altezza) e spostamento orizzontale (pixel)
static func sample(r: Dictionary, fx: Dictionary, now_ms: float) -> Dictionary:
	var t := now_ms - float(r.at)
	var length := float(fx.hitReactMs)
	if t < 0.0 or t >= length:
		return {"angle": 0.0, "squash": 0.0, "offset": 0.0}
	var fade := exp(-3.0 * t / length) * (1.0 - t / length) # arriva a zero esatto a fine durata
	var spring := fade * cos(TAU * float(fx.hitReactHz) * t / 1000.0) # oscilla attorno a dritto
	var offset := float(r.recoil) * fade
	var stop := float(r.get("stop", 0.0))
	if t < stop and not Access.calm:
		# Nel fermo si trema avanti e indietro, sempre meno fino alla partenza
		offset += float(r.get("shake", 0.0)) * (1.0 - t / stop) * sin(TAU * float(fx.get("hitShakeHz", 30.0)) * t / 1000.0)
	return {"angle": float(r.tilt) * spring, "squash": float(r.squash) * spring, "offset": offset}


# La deformazione come trasformazione del disegno, con il perno sui piedi:
# chi è schiacciato si allarga un po' per non perdere massa (squash & stretch)
static func transform(feet: Vector2, s: Dictionary) -> Transform2D:
	var sq: float = s.squash
	var local := Transform2D(float(s.angle), Vector2(1.0 + sq * 0.5, 1.0 - sq), 0.0, Vector2.ZERO)
	return Transform2D(0.0, feet + Vector2(float(s.offset), 0.0)) * local * Transform2D(0.0, -feet)
