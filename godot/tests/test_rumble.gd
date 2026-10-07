# Vibrazione del pad (rumble.gd): solo dagli eventi, più forte per i colpi pesanti e per il KO
extends RefCounted

var runner

const SPEC := {"hitMs": 120, "hitMinStrength": 0.25, "hitMaxKnockback": 1400, "attackerScale": 0.5, "koMs": 450, "koStrength": 1, "weakScale": 0.5}


func _rumble() -> Rumble:
	var r := Rumble.new(SPEC)
	r.my_id = "me"
	return r


func _hit(target: String, attacker: String, knockback: float) -> Dictionary:
	return {"type": "hit", "targetId": target, "attackerId": attacker, "knockback": knockback}


func test_pesante_piu_forte_del_leggero() -> void:
	var r := _rumble()
	var light := r.effect(_hit("me", "x", 300))
	var heavy := r.effect(_hit("me", "x", 1200))
	runner.check(light.x > 0 and heavy.x > light.x, "leggero %s, pesante %s" % [light, heavy])


func test_ko_piu_forte_e_lungo() -> void:
	var r := _rumble()
	var ko := r.effect({"type": "ko", "id": "me"})
	var heavy := r.effect(_hit("me", "x", 1200))
	runner.check(ko.x >= heavy.x and ko.y > heavy.y, "ko %s, colpo %s" % [ko, heavy])


func test_solo_se_mi_riguarda() -> void:
	var r := _rumble()
	runner.check(r.effect(_hit("a", "b", 1200)) == Vector2.ZERO, "colpo tra altri")
	runner.check(r.effect({"type": "ko", "id": "a"}) == Vector2.ZERO, "ko di un altro")
	runner.check(r.effect({"type": "jump", "id": "me"}) == Vector2.ZERO, "salto")
	var mine := r.effect(_hit("x", "me", 800))
	runner.check(mine.x > 0 and mine.x < r.effect(_hit("me", "x", 800)).x, "chi colpisce sente meno: %s" % mine)


func test_opzione_spenta_e_debole() -> void:
	var r := _rumble()
	var strong := r.effect(_hit("me", "x", 800))
	r.level = Rumble.WEAK
	runner.check(is_equal_approx(r.effect(_hit("me", "x", 800)).x, strong.x * 0.5), "debole = metà")
	r.level = Rumble.OFF
	runner.check(r.effect(_hit("me", "x", 800)) == Vector2.ZERO, "spenta")
	runner.check(r.effect({"type": "ko", "id": "me"}) == Vector2.ZERO, "spenta anche al ko")
