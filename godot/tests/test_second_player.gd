# Il secondo giocatore sullo stesso schermo (second_player.gd): il suo pad non muove più il primo
extends RefCounted

var runner


func test_il_pad_del_secondo_esce_dai_tasti_del_primo() -> void:
	var s := Settings.new({"master": 0.8, "sfx": 0.7, "music": 0.35}, "user://test_second_player.cfg")
	var p2 := SecondPlayer.new(1, s, {})
	runner.check(s.p2_pad == 1, "il primo non legge il pad 1: %d" % s.p2_pad)
	var reasons := []
	p2.left.connect(func(r: String): reasons.append(r))
	p2.stop("uscito")
	runner.check(s.p2_pad == -1, "dopo l'uscita il pad torna al primo")
	p2.stop("di nuovo")
	runner.check(reasons == ["uscito"], "si esce una volta sola: %s" % [reasons])
