# Luce e ombre del sole e della luna (#288)
extends RefCounted

var runner

const SunLight := preload("res://scripts/sun_light.gd")


func test_il_sole_gira_e_le_ombre_si_allungano() -> void:
	var noon := SunLight.light(0.0)
	runner.check(noon.sun and is_equal_approx(noon.elev, 1.0) and absf(noon.side) < 0.01, "a mezzogiorno il sole è in cima")
	var dawn := SunLight.light(0.8)
	runner.check(dawn.sun and dawn.side < 0.0, "al mattino la luce arriva da sinistra")
	var dusk := SunLight.light(0.2)
	runner.check(dusk.side > 0.0, "al pomeriggio da destra")
	runner.check(SunLight.shadow_length(dusk) > SunLight.shadow_length(noon) * 3.0, "al tramonto le ombre sono lunghe")
	var night := SunLight.light(0.5)
	runner.check(not night.sun and night.strength < noon.strength, "di notte la luna fa ombre più deboli")


func test_l_ombra_va_dalla_parte_opposta_alla_luce() -> void:
	var dawn := SunLight.light(0.8)
	var s: Array = SunLight.shadow(Vector2(500, 520), 44, dawn)
	var pts: PackedVector2Array = s[0]
	var cx := 0.0
	for p in pts:
		cx += p.x
	cx /= pts.size()
	runner.check(cx > 500.0 and float(s[1]) > 0.0, "luce da sinistra, ombra a destra: %s" % cx)
	var high: Array = SunLight.shadow(Vector2(500, 520), 44, dawn, 300.0)
	runner.check(float(high[1]) == 0.0, "chi è molto in alto non fa ombra a terra")
