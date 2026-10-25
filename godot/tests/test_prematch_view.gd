# Pre-partita: righe dell'attesa, numeri del conto alla rovescia, Pronto che si vede subito
extends RefCounted

var runner

const View := preload("res://scripts/prematch_view.gd")


func test_numeri_del_conto_alla_rovescia() -> void:
	runner.check(View.count_label(5000, 3000) == "", "durante la presentazione nessun numero")
	runner.check(View.count_label(3000, 3000) == "3", "si parte da 3")
	runner.check(View.count_label(1500, 3000) == "2", "a metà del secondo dopo è 2")
	runner.check(View.count_label(10, 3000) == "1", "fino al VIA resta 1")
	runner.check(View.count_label(0, 3000) == "1", "mai 0")


func test_riga_in_fondo_all_attesa() -> void:
	runner.check(View.hint(1, false, null).contains("link"), "da soli: manda il link")
	runner.check(View.hint(2, false, null).contains("Invio"), "da dire come si è pronti")
	runner.check(View.hint(2, true, 41200).contains("42 s"), "il tempo prima della partenza comunque")


func test_pronto_si_vede_subito_e_poi_decide_il_server() -> void:
	var v: Control = View.new()
	v.game = {"world": {"width": 1280, "height": 720}, "prematch": {"countdownMs": 3000}}
	v.my_id = "a"
	runner.root.add_child(v)
	var players := [{"id": "a", "name": "Anna"}, {"id": "b", "name": "Bruno"}]
	v.on_snapshot({"players": players, "events": [], "prematch": {"phase": "waiting", "leftMs": 0, "ready": [], "autoStartMs": 60000}})
	runner.check(v.waiting() and not v.is_ready(), "in attesa, non pronto")
	var sent := []
	v.ready_changed.connect(func(r: bool): sent.append(r))
	v.set_ready(true)
	runner.check(v.is_ready() and sent == [true], "pronto subito, e detto al server")
	v.on_snapshot({"players": players, "events": [], "prematch": {"phase": "waiting", "leftMs": 0, "ready": [], "autoStartMs": 59000}})
	runner.check(v.is_ready(), "lo snapshot in viaggio non lo cancella")
	v.on_snapshot({"players": players, "events": [], "prematch": {"phase": "starting", "leftMs": 5500, "ready": ["a", "b"], "autoStartMs": null}})
	runner.check(v.frozen() and not v.waiting(), "al 3, 2, 1 si sta fermi")
	v.set_ready(false)
	runner.check(sent == [true], "al conto alla rovescia non si ritira il Pronto")
	v.on_snapshot({"players": players, "events": [{"type": "matchStart"}]})
	runner.check(not v.frozen() and not v.waiting(), "VIA: partita in corso")
	v.free()


func test_presentazione_schede_in_fila_e_in_arrivo() -> void:
	runner.check(is_equal_approx(View.intro_t(5500, 3000, 2500), 0.0), "comincia a 0")
	runner.check(is_equal_approx(View.intro_t(3000, 3000, 2500), 1.0), "finisce al 3")
	var a: Rect2 = View.card_rect(0, 2, 1280, 720)
	var b: Rect2 = View.card_rect(1, 2, 1280, 720)
	runner.check(a.end.x < b.position.x, "una accanto all'altra")
	runner.check(absf((a.position.x + b.end.x) / 2.0 - 640.0) < 1.0, "centrate")
	var many: Rect2 = View.card_rect(7, 8, 1280, 720)
	runner.check(many.end.x <= 1280.0 - 39.0, "in otto stanno nello schermo")
	runner.check(View.card_in(0.0, 0) <= 0.0, "all'inizio fuori")
	runner.check(is_equal_approx(View.card_in(1.0, 3), 1.0), "alla fine al suo posto")


func test_suoni_della_presentazione_una_volta_sola() -> void:
	var v: Control = View.new()
	v.game = {"world": {"width": 1280, "height": 720}, "prematch": {"countdownMs": 3000, "introMs": 2500}}
	runner.root.add_child(v)
	var heard := []
	v.cue.connect(func(c: String): heard.append(c))
	var players := [{"id": "a", "name": "Anna"}, {"id": "b", "name": "Bruno"}]
	for left in [5500, 5000, 4000, 3500, 3000, 2500, 1500, 500]:
		v.on_snapshot({"players": players, "events": [], "prematch": {"phase": "starting", "leftMs": left, "ready": [], "autoStartMs": null}})
		v._process(0.0)
		v._process(0.0)
	v.on_snapshot({"players": players, "events": [{"type": "matchStart"}]})
	runner.check(heard == ["intro", "card", "card", "vs", "3", "2", "1", "go"], "in ordine e senza doppioni: %s" % [heard])
	v.free()


func test_locandina_senza_immagine_non_si_rompe() -> void:
	var v: Control = View.new()
	runner.check(v.body_of({"id": "default", "name": "Bonobo"}).is_empty(), "il bonobo disegnato col codice non ha corpo: si usa l'iniziale")
	v.free()
