# Conta combo dell'allenamento (training.gd, E15): colpi di fila finché il bersaglio resta stordito
extends RefCounted

var runner

const Training := preload("res://scripts/training.gd")


func _hit(attacker: String, target: String, damage: float) -> Dictionary:
	return {"type": "hit", "attackerId": attacker, "targetId": target, "damage": damage}


func _snap(target: String, hitstun: bool) -> Dictionary:
	return {"players": [{"id": "me", "hitstun": false}, {"id": target, "hitstun": hitstun}]}


func test_conta_finche_stordito_poi_si_azzera() -> void:
	var c = Training.Combo.new()
	c.on_event(_hit("me", "bot", 5), "me")
	c.on_snapshot(_snap("bot", true))
	runner.check(c.text() == "", "un colpo solo non è una combo: %s" % c.text())
	c.on_event(_hit("me", "bot", 6), "me")
	c.on_snapshot(_snap("bot", true))
	c.on_event(_hit("me", "bot", 13), "me")
	c.on_snapshot(_snap("bot", true))
	runner.check(c.text() == "3 colpi · 24%", "combo in corso: %s" % c.text())
	c.on_snapshot(_snap("bot", false))
	runner.check(c.hits == 0, "finito lo stordimento la combo si azzera")
	runner.check(c.text() == "Ultima combo: 3 colpi · 24%", "resta l'ultima: %s" % c.text())


func test_colpi_degli_altri_e_bersaglio_nuovo() -> void:
	var c = Training.Combo.new()
	c.on_event(_hit("bot", "me", 9), "me")
	runner.check(c.hits == 0, "i colpi presi non contano")
	c.on_event(_hit("me", "a", 5), "me")
	c.on_event(_hit("me", "a", 5), "me")
	c.on_event(_hit("me", "b", 5), "me")
	runner.check(c.hits == 1 and c.target == "b", "un bersaglio nuovo fa ripartire il conto")
	runner.check(c.last_hits == 2, "la combo su a resta come ultima")


func test_nome_della_velocita() -> void:
	runner.check(Training.speed_text(1.0) == "Normale", "1")
	runner.check(Training.speed_text(0.25) == "Rallentata ×0.25", Training.speed_text(0.25))
