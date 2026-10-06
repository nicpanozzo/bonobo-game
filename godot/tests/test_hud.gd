# Classifica di fine partita e colori della percentuale (hud.gd), dagli eventi degli snapshot
extends RefCounted

var runner

const Hud := preload("res://scripts/hud.gd")


func _hud() -> Control:
	var h: Control = Hud.new()
	h.game = {"effects": {"percentShakeMax": 10, "percentShakePerDamage": 0.5, "percentShakeMs": 200}}
	return h


func _snap(events: Array, players := []) -> Dictionary:
	return {"events": events, "players": players}


func test_conta_danni_ko_e_cadute() -> void:
	var h := _hud()
	h.on_snapshot(_snap([{"type": "matchStart"}]))
	h.on_snapshot(_snap([
		{"type": "hit", "attackerId": "a", "targetId": "b", "damage": 12},
		{"type": "hit", "attackerId": "a", "targetId": "b", "damage": 8},
		{"type": "ko", "id": "b", "byId": "a"},
		{"type": "ko", "id": "a", "byId": null},
	]))
	var st: Dictionary = h._stats
	runner.check(st.a.damage == 20 and st.a.kos == 1 and st.a.falls == 1, "a: %s" % [st.a])
	runner.check(st.b.falls == 1 and st.b.kos == 0, "b: %s" % [st.b])
	h.free()


func test_nuova_partita_azzera() -> void:
	var h := _hud()
	h.on_snapshot(_snap([{"type": "hit", "attackerId": "a", "targetId": "b", "damage": 5}]))
	h.on_snapshot(_snap([{"type": "matchStart"}]))
	runner.check(h._stats.is_empty(), "dopo matchStart la classifica riparte: %s" % [h._stats])
	h.free()


func test_percentuale_trema_quando_sale() -> void:
	var h := _hud()
	h.on_snapshot(_snap([], [{"id": "a", "percent": 10}]))
	h.on_snapshot(_snap([], [{"id": "a", "percent": 30}]))
	runner.check(h._jolts.has("a") and h._jolts.a.amp == 10.0, "scossa: %s" % [h._jolts])
	h.free()


func test_colore_della_percentuale() -> void:
	runner.check(Hud._percent_color(0, false) == Color(1, 1, 1), "bianco a 0%")
	var mid: Color = Hud._percent_color(75, false)
	runner.check(mid.r == 1.0 and mid.g < 1.0 and mid.b == 0.0, "giallo-arancio a 75%%: %s" % mid)
	runner.check(Hud._percent_color(500, false) == Hud._percent_color(150, false), "oltre 150% non cambia")
	runner.check(Hud._percent_color(50, true) == Color("777777"), "grigio se eliminato")
