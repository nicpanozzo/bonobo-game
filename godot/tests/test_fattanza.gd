# La Fattanza di Marcomunista (FATTANZA): da fatto o col cappello aperto la predizione si ferma
extends RefCounted

var runner


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
