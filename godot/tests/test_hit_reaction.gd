# Reazione procedurale ai colpi (hit_reaction.gd, #305)
extends RefCounted

var runner

const HitReaction := preload("res://scripts/hit_reaction.gd")

const FX := {"hitReactMs": 420, "hitReactHz": 5, "hitReactFullKnockback": 1200, "hitReactMinStrength": 0.25,
	"hitReactTilt": 0.35, "hitReactSquash": 0.22, "hitReactRecoil": 10}


func test_testa_si_piega_all_indietro() -> void:
	var r := HitReaction.start(FX, 1.0, 1, 1200, 0)
	var s := HitReaction.sample(r, FX, 1)
	runner.check(s.angle > 0.3 and s.squash < 0.01, "colpo alla testa verso destra: ruota in senso orario (%s)" % s)
	var head := HitReaction.transform(Vector2(100, 500), s) * Vector2(100, 400)
	runner.check(head.x > 100, "la testa va lontano da chi colpisce (%s)" % head)


func test_gambe_portate_via() -> void:
	var s := HitReaction.sample(HitReaction.start(FX, 0.0, 1, 1200, 0), FX, 1)
	runner.check(s.angle < -0.3, "colpo alle gambe: il busto cade verso chi colpisce (%s)" % s)


func test_pancia_si_schiaccia() -> void:
	var s := HitReaction.sample(HitReaction.start(FX, 0.5, -1, 1200, 0), FX, 1)
	runner.check(absf(s.angle) < 0.01 and s.squash > 0.2 and s.offset < 0, "pancia: schiacciato e spinto a sinistra (%s)" % s)
	var feet := HitReaction.transform(Vector2(100, 500), s) * Vector2(100, 500)
	runner.check(is_equal_approx(feet.y, 500.0), "i piedi restano a terra (%s)" % feet)


func test_forza_scala_la_reazione() -> void:
	var weak := HitReaction.sample(HitReaction.start(FX, 1.0, 1, 100, 0), FX, 1)
	var strong := HitReaction.sample(HitReaction.start(FX, 1.0, 1, 900, 0), FX, 1)
	runner.check(weak.angle > 0.0 and strong.angle > weak.angle * 2.0, "più forte, più ampia (%s, %s)" % [weak.angle, strong.angle])


func test_si_spegne_da_sola() -> void:
	var r := HitReaction.start(FX, 1.0, 1, 1200, 1000)
	var mid := HitReaction.sample(r, FX, 1000 + 100)
	runner.check(mid.angle < 0.0, "la molla oscilla oltre dritto (%s)" % mid)
	var late := HitReaction.sample(r, FX, 1000 + 419)
	runner.check(absf(late.angle) < 0.005 and absf(late.offset) < 0.1, "quasi dritto a fine durata (%s)" % late)
	runner.check(HitReaction.sample(r, FX, 1000 + 420).angle == 0.0, "poi dritto")


# Nel fermo del colpo (HITSTOP) chi è colpito trema sul posto, poi il tremolio finisce
func test_trema_nel_fermo() -> void:
	var fx := FX.duplicate()
	fx.hitShakePx = 7.0
	fx.hitShakeHz = 30.0
	var stop := HitReaction.stop_ms({"baseMs": 30, "perDamageMs": 6, "maxMs": 200}, 13)
	runner.check(stop == 108.0, "fermo del pesante come il server: %s" % stop)
	runner.check(HitReaction.stop_ms({}, 13) == 0.0, "senza numeri niente fermo")
	var r := HitReaction.start(fx, 0.5, 1, 1200, 0, stop)
	var plain := HitReaction.start(FX, 0.5, 1, 1200, 0)
	var swing := 0.0
	for t in range(1, 100, 3):
		swing = maxf(swing, absf(HitReaction.sample(r, fx, t).offset - HitReaction.sample(plain, FX, t).offset))
	runner.check(swing > 2.0, "nel fermo trema: %s" % swing)
	runner.check(HitReaction.sample(r, fx, 200).offset == HitReaction.sample(plain, FX, 200).offset, "dopo il fermo solo il rinculo")
