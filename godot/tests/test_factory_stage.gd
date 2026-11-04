# La Fabbrica: il verso dei nastri come beltVelocity in physics/belts.ts (stessi casi di belts.test.ts), la sirena,
# le impacchettatrici e la scatola che si disegna sopra chi è impacchettato
extends RefCounted

var runner

const StageMotion := preload("res://scripts/stage_motion.gd")
const Factory := preload("res://scripts/factory_stage.gd")
const ThemeStage := preload("res://scripts/theme_stage.gd")

const BELT := {"x": 100, "y": 650, "width": 600, "speed": 150, "dir": 1, "flipEveryMs": 10000, "group": "nastri"}


func _lever(x: float) -> Dictionary:
	return {"x": x, "y": 650, "width": 50, "sound": "leva", "cooldownMs": 8000, "effect": {"group": "nastri", "durationMs": 3000, "flip": true}}


func test_verso_dei_nastri_come_la_fisica() -> void:
	var pads := [_lever(900), _lever(1000)]
	runner.check(StageMotion.belt_auto_dir(BELT, 9999) == 1 and StageMotion.belt_auto_dir(BELT, 10000) == -1, "si inverte da solo")
	runner.check(StageMotion.belt_velocity(BELT, 2000, pads, [null, null], 2.0) == 150.0, "dritto")
	runner.check(StageMotion.belt_velocity(BELT, 2000, pads, [1000, null], 2.0) == -150.0, "una leva lo inverte")
	runner.check(StageMotion.belt_velocity(BELT, 4500, pads, [1000, null], 2.0) == 150.0, "finita la leva torna")
	runner.check(StageMotion.belt_velocity(BELT, 2000, pads, [1000, 1500], 2.0) == -300.0, "turbo")
	runner.check(StageMotion.belt_velocity(BELT, 12000, pads, [11000, null], 2.0) == 150.0, "la leva nel giro al contrario")


func test_sirena_e_impacchettatrice() -> void:
	runner.check(Factory.siren(BELT, 7000, 2000) < 0.0, "lontano dal cambio: zitta")
	runner.check(is_equal_approx(Factory.siren(BELT, 9000, 2000), 0.5), "a metà dell'avviso")
	var h := {"kind": "pressa", "x": 200, "y": 470, "width": 90, "height": 90, "periodMs": 7000, "activeMs": 350, "warnMs": 1300}
	var r := Rect2(200, 470, 90, 90)
	runner.check(Factory.press_bottom(h, r, 100)[0] == 560.0, "accesa: appoggiata sul nastro")
	runner.check(Factory.press_bottom(h, r, 3000)[0] == 430.0 and Factory.press_bottom(h, r, 3000)[1] == 0.0, "ferma in alto")
	runner.check(Factory.press_bottom(h, r, 6500)[1] > 0.0, "trema prima di scendere")


func test_la_fabbrica_ha_il_suo_tema() -> void:
	var game := {"belt": {"turboMult": 2, "warnMs": 2000}}
	var theme := ThemeStage.new()
	theme.setup({"id": "fabbrica", "belts": [BELT], "pads": [_lever(900)], "hazards": [{"kind": "pressa", "pack": {"baseMs": 1000, "perPercentMs": 10}, "x": 0, "y": 0, "width": 10, "height": 10}]}, game)
	runner.check(theme.active(), "tema attivo")
	theme.setup({"id": "palestra"}, game)
	runner.check(not theme.active(), "la palestra resta com'è")
	var f := Factory.new()
	f.setup({"belts": [BELT], "hazards": [{"kind": "fuoco"}, {"kind": "pressa", "pack": {"baseMs": 1000, "perPercentMs": 10}}]}, game)
	f.on_event({"type": "hazard", "index": 1, "id": "a"}, 1000)
	f.on_event({"type": "hazard", "index": 0, "id": "b"}, 1000)
	runner.check(f._packed.has("a") and not f._packed.has("b"), "solo l'impacchettatrice chiude in scatola")
	var cues: Array = f.cues(7900, 8100, [])
	runner.check(cues.size() == 1 and cues[0][0] == "siren", "la sirena suona quando parte l'avviso")
