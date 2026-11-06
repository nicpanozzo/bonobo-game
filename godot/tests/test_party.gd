# Bonobo Party (#579): tabellone, scheda del minigioco e oggetti di scena; solo disegno e pulsanti
extends RefCounted

var runner

const PartyView := preload("res://scripts/party_view.gd")
const PartyHud := preload("res://scripts/party_hud.gd")
const PartyProps := preload("res://scripts/party_props.gd")


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func _snap(phase: String, turn: String, extra := {}) -> Dictionary:
	var s := {
		"t": 0, "phase": phase, "phaseLeftMs": 5000, "round": 1, "rounds": 3, "pick": "vote", "turnId": turn, "dice": null, "moveLeft": 0,
		"squares": [{"x": 0.1, "y": 0.1, "kind": "start", "next": [1]}, {"x": 0.9, "y": 0.9, "kind": "banana", "next": [0]}],
		"crownSquare": 1,
		"players": [
			{"id": "a", "name": "A", "characterId": "default", "skinId": "", "color": 0xff0000, "bot": false, "away": false, "square": 0, "bananas": 10, "crowns": 0, "item": "moka", "wins": 0, "place": 1},
			{"id": "b", "name": "B", "characterId": "default", "skinId": "", "color": 0x00ff00, "bot": true, "away": false, "square": 0, "bananas": 4, "crowns": 0, "item": null, "wins": 0, "place": 2},
		],
		"options": [], "votes": {}, "feedbackDone": [], "lastResults": null, "shop": [], "text": "", "events": [], "winnerId": null,
	}
	s.merge(extra, true)
	return s


func test_dado_e_pedine() -> void:
	for v in range(1, 7):
		runner.check(PartyView.die_pips(v).size() == v, "il %d ha %d puntini" % [v, v])
	runner.check(PartyView.die_pips(9).size() == 6, "oltre il 6 si mostra il 6")
	runner.check(PartyView.pawn_offset(0, 1) == Vector2.ZERO, "da sola al centro della casella")
	runner.check(PartyView.pawn_offset(0, 3) != PartyView.pawn_offset(1, 3), "in tre a ventaglio")
	var p := PartyView.board_point(Rect2(10, 20, 100, 200), {"x": 0.5, "y": 1.0})
	runner.check(p == Vector2(60, 220), "le caselle da 0..1 al riquadro: %s" % p)


func test_tocca_a_me_tiro_e_uso_l_oggetto() -> void:
	var v: Control = PartyView.new()
	v.setup(_game(), "a")
	var sent: Array = []
	v.command.connect(func(c): sent.append(c))
	v.on_snapshot(_snap("roll", "a"))
	runner.check(v.actions_key().begins_with("roll:true"), "il mio turno: %s" % v.actions_key())
	var buttons: Array = v._actions.get_children()
	runner.check(buttons.size() == 2, "Tira e Usa la moka: %d" % buttons.size())
	(buttons[1] as Button).pressed.emit()
	runner.check(sent == [{"kind": "roll", "useItem": true}], "il tiro con l'oggetto va al server: %s" % [sent])
	v.on_snapshot(_snap("roll", "b"))
	runner.check(v.actions_key().begins_with("roll:false"), "tocca a un altro: niente pulsanti miei")
	v.free()


func test_feedback_una_volta_sola() -> void:
	var v: Control = PartyView.new()
	v.setup(_game(), "a")
	var sent: Array = []
	v.command.connect(func(c): sent.append(c))
	v.on_snapshot(_snap("feedback", "", {"events": [{"type": "results"}]}))
	v._set_stars(4)
	v._note.text = "  troppo corto "
	v._send_feedback()
	v._send_feedback()
	runner.check(sent == [{"kind": "feedback", "stars": 4, "text": "troppo corto"}], "un parere solo, ripulito: %s" % [sent])
	runner.check(v.actions_key() == "feedback:true", "dopo l'invio spariscono le stelle")
	v.free()


func test_scheda_e_punti_del_minigioco() -> void:
	runner.check(PartyHud.clock_text(42000) == "0:42" and PartyHud.clock_text(61500) == "1:02" and PartyHud.clock_text(null) == "", "il tempo in m:ss")
	var rows := PartyHud.ranking({"a": 2, "b": 5, "c": 2}, {"a": "Zeta", "b": "B", "c": "Alfa"})
	runner.check(rows.map(func(r): return r[0]) == ["b", "c", "a"], "dal più alto, a pari punti per nome: %s" % [rows])
	runner.check(PartyHud.category_name("ritmo") == "Ritmo e riflessi" and PartyHud.category_name("boh") == "boh", "le categorie")
	var h: Control = PartyHud.new()
	runner.check(not h.active(), "fuori dai minigiochi è spento")
	h.start({"id": "pioggia", "title": "Pioggia di Banane", "category": "arraffa"})
	h.on_snapshot({"players": [{"id": "a", "name": "A", "color": 0xffffff}], "party": {"id": "pioggia", "scores": {"a": 3}, "unit": "banane", "text": null, "leftMs": 1000, "out": [], "props": []}})
	runner.check(h.active() and h._names.get("a") == "A", "acceso, con i nomi dallo snapshot")
	h.reset()
	runner.check(not h.active(), "reset lo spegne")
	h.free()


func test_oggetti_di_scena() -> void:
	var pr: Node2D = PartyProps.new()
	pr.set_props([{"kind": "banana", "x": 0, "y": 0}, {"kind": "crack", "x": 10, "y": 0, "w": 100}])
	runner.check(pr.props.size() == 2, "arrivano gli oggetti")
	pr.set_props(null)
	runner.check(pr.props.is_empty(), "niente oggetti se lo snapshot non li ha")
	pr.free()
