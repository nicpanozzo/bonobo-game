# Fine partita (results_view.gd): ordine della classifica, premi, durata, quando si accende e si spegne
extends RefCounted

var runner

const View := preload("res://scripts/results_view.gd")
const Hud := preload("res://scripts/hud.gd")


func test_premi_a_chi_e_da_solo_in_testa() -> void:
	var stats := {
		"a": {"kos": 3, "falls": 0, "damage": 120, "best": 18, "flags": 0},
		"b": {"kos": 1, "falls": 2, "damage": 120, "best": 25, "flags": 0},
		"c": {"kos": 0, "falls": 3, "damage": 0, "best": 0, "flags": 0},
	}
	var out := View.awards(stats, ["a", "b", "c"])
	var names := func(id: String) -> Array: return out[id].map(func(p: Array) -> String: return p[0])
	runner.check(names.call("a").has("Sterminatore"), "a ha più KO: %s" % [out.a])
	runner.check(not names.call("a").has("Picchiatore") and not names.call("b").has("Picchiatore"), "a pari danni nessuno è Picchiatore")
	runner.check(names.call("b").has("Martello"), "b ha il colpo più forte: %s" % [out.b])
	runner.check(names.call("c").has("Kamikaze") and names.call("c").has("Pacifista"), "c: %s" % [out.c])
	for id in out:
		runner.check(out[id].size() <= View.AWARDS_MAX, "al massimo %d premi: %s" % [View.AWARDS_MAX, out[id]])


func test_da_soli_niente_premi() -> void:
	var out := View.awards({"a": {"kos": 2}}, ["a"])
	runner.check(out.a.is_empty(), "da soli: %s" % [out.a])


func test_classifica_vincitore_e_squadra_in_cima() -> void:
	var players := [
		{"id": "a", "team": 1}, {"id": "b", "team": 2}, {"id": "c", "team": 2}, {"id": "d", "team": 1},
	]
	var stats := {"a": {"kos": 5}, "b": {"kos": 0}, "c": {"kos": 2}, "d": {"kos": 1}}
	var ids := View.ranking(players, stats, players[1]).map(func(p: Dictionary) -> String: return p.id)
	runner.check(ids == ["b", "c", "a", "d"], "prima chi ha vinto, poi la sua squadra, poi per KO: %s" % [ids])
	var ffa := [{"id": "a", "team": 0}, {"id": "b", "team": 0}]
	ids = View.ranking(ffa, {"a": {"kos": 9}}, ffa[1]).map(func(p: Dictionary) -> String: return p.id)
	runner.check(ids == ["b", "a"], "tutti contro tutti: il vincitore resta primo: %s" % [ids])


func test_durata() -> void:
	runner.check(View.duration_text(133400) == "2:13", View.duration_text(133400))
	runner.check(View.duration_text(5000) == "0:05", View.duration_text(5000))


func test_si_accende_a_fine_partita_e_si_spegne_alla_rivincita() -> void:
	var h: Control = Hud.new()
	var v: Control = View.new()
	v.game = {"world": {"width": 1280, "height": 720}}
	v.hud = h
	runner.root.add_child(v)
	var players := [{"id": "a", "name": "Anna", "team": 0, "color": 0xff0000}]
	v.on_snapshot({"players": players, "events": [], "winnerId": null})
	runner.check(not v.is_on(), "in partita spenta")
	v.on_snapshot({"players": players, "events": [{"type": "matchEnd", "winnerId": "a", "winnerTeam": 0, "durationMs": 90000}], "winnerId": "a"})
	runner.check(v.is_on() and v._duration_ms == 90000.0, "a fine partita accesa, con la durata")
	runner.check(not v._confetti.is_empty(), "coriandoli")
	v._draw()
	runner.check(v._veil.visible, "l'arena dietro si sfoca")
	v.on_snapshot({"players": players, "events": [{"type": "matchStart"}], "winnerId": null})
	runner.check(not v.is_on() and v._confetti.is_empty(), "alla rivincita si spegne")
	runner.check(not v._veil.visible, "e il velo se ne va")
	v.queue_free()
	h.free()


# Punti in classifica (evento ratings): per id, che contano dai vecchi ai nuovi, verdi se si guadagna
func test_punti_in_classifica() -> void:
	var view: Control = View.new()
	view.set_ratings([{"id": "a", "name": "A", "rating": 1018, "delta": 18, "tier": "Babbuino", "rank": 3}, {"id": "b", "name": "B", "rating": 988, "delta": -12, "tier": "Babbuino", "rank": null}, "rotto"])
	runner.check(view._ratings.size() == 2 and view._ratings.a.delta == 18, "tenuti per id: %s" % [view._ratings.keys()])
	runner.check(View.rating_shown(view._ratings.a, 0) == 1000, "si parte dai punti di prima: %d" % View.rating_shown(view._ratings.a, 0))
	runner.check(View.rating_shown(view._ratings.a, View.RATING_COUNT_MS * 2) == 1018, "e si arriva ai nuovi")
	var mid := View.rating_shown(view._ratings.b, View.RATING_COUNT_MS / 2)
	runner.check(mid < 1000 and mid > 988, "a metà sta in mezzo: %d" % mid)
	runner.check(View.delta_color(18) == UI.OK and View.delta_color(-12) == UI.WARN, "verde chi guadagna, rosso chi perde")
	runner.check(View.delta_color(0) == UI.LILAC, "lilla chi resta pari")
	view.reset()
	runner.check(view._ratings.is_empty(), "la partita dopo li toglie")
	view.free()
