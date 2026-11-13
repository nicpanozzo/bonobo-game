# La Fattanza di Marcomunista (FATTANZA): da fatto o col cappello aperto la predizione si ferma
extends RefCounted

var runner

const FighterPose := preload("res://scripts/fighter_pose.gd")


func test_da_fatto_non_si_predice() -> void:
	var p := {"x": 100, "y": 100, "predict": {}, "attack": null, "hitstun": false, "fattanza": 0.4}
	runner.check(Predictor.predictable(p, {}), "da Lucido si predice")
	p.fattanza = 1.2
	runner.check(not Predictor.predictable(p, {}), "da Rilassato in su no: gravità e passo cambiano")
	p.fattanza = 0.0
	p.floating = true
	runner.check(not Predictor.predictable(p, {}), "fluttuando col cappello no")
	p.floating = false
	p.sballato = true
	runner.check(not Predictor.predictable(p, {}), "sballato dalla Nuvola no: gravità e passo cambiano")


func test_fluttuando_usa_la_posa_float() -> void:
	var p := {"hitstun": false, "attack": null, "onGround": false, "vy": 80.0, "floating": true}
	runner.check(FighterPose.animation_for(p) == "float", "col cappello aperto la posa è float (senza disegno ripiega sulla caduta)")
	p.floating = false
	runner.check(FighterPose.animation_for(p) == "fall", "senza fluttuare cade e basta")
