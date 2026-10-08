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


func test_ritratto_ritagliato_e_proporzionato() -> void:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(20, 10, 24, 80), Color.RED) # una figura alta e stretta
	var r := Hud.used_region(img, Rect2(0, 0, 64, 96))
	runner.check(r == Rect2(20, 10, 24, 24), "testa e spalle: %s" % r)
	var empty := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	runner.check(Hud.used_region(empty, Rect2(0, 0, 64, 96)) == Rect2(0, 0, 64, 96), "fotogramma vuoto: tutto")
	var fit := Hud.fit_rect(Vector2(20, 40), Rect2(0, 0, 40, 40))
	runner.check(fit == Rect2(10, 0, 20, 40), "proporzioni tenute, centrato: %s" % fit)
