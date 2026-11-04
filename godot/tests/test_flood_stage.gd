# Il Diluvio: il mare che sale come riseOffset/riseTimeMs in physics/timed.ts, la zona di espulsione che sale a
# scalini come stageAt, e il tema che si accende per l'arena "isole"
extends RefCounted

var runner

const StagePhases := preload("res://scripts/stage_phases.gd")
const Flood := preload("res://scripts/flood_stage.gd")
const ThemeStage := preload("res://scripts/theme_stage.gd")

const RISE := {"startMs": 6000, "pxPerS": 24, "accelPxPerS2": 0.1, "maxPx": 7900, "stepMs": 250, "waterY": 9120}


func test_il_mare_sale_come_la_fisica() -> void:
	runner.check(StagePhases.rise_offset(RISE, 3000) == 0.0, "fermo prima della partenza")
	# 10 s dopo la partenza: 24*10 + 0.5*0.1*100 = 245
	runner.check(is_equal_approx(StagePhases.rise_offset(RISE, 16000), 245.0), "velocità più accelerazione")
	runner.check(StagePhases.rise_offset(RISE, 1e9) == 7900.0, "si ferma all'Arca")
	runner.check(is_equal_approx(StagePhases.water_y(RISE, 16000), 9120.0 - 245.0), "superficie")
	runner.check(is_equal_approx(Flood.time_at(RISE, 245.0), 16000.0), "l'istante inverso")


func test_la_zona_di_espulsione_sale_a_scalini() -> void:
	var stage := {"id": "isole", "rise": RISE, "blastZone": {"left": -400, "right": 1680, "top": 7420, "bottom": 9160}}
	var v: Dictionary = StagePhases.effective_stage(stage, 16100)
	var up := StagePhases.rise_offset(RISE, 16000)
	runner.check(is_equal_approx(float(v.blastZone.bottom), 9160.0 - up), "il fondo sale con lo scalino")
	runner.check(is_equal_approx(float(v.blastZone.top), 7420.0 - up), "anche il cielo")
	runner.check(float(stage.blastZone.bottom) == 9160.0, "l'arena di partenza resta com'è")


func test_il_diluvio_ha_il_suo_tema() -> void:
	var theme := ThemeStage.new()
	theme.setup({"id": "isole", "rise": RISE, "solids": [], "platforms": []}, {})
	runner.check(theme.active(), "tema attivo")
