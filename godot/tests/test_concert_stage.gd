# Il Palco: il genere che suona come genreAt/technoBeat in physics/genre.ts (stessi casi di genre.test.ts), l'avviso
# del DJ prima del cambio e il tema che si accende per l'arena "palco"
extends RefCounted

var runner

const StageMotion := preload("res://scripts/stage_motion.gd")
const Concert := preload("res://scripts/concert_stage.gd")
const ThemeStage := preload("res://scripts/theme_stage.gd")


func _disco(g: String) -> Dictionary:
	return {"x": 0, "y": 0, "width": 60, "sound": g, "cooldownMs": 14000, "effect": {"group": "genere", "durationMs": 12000, "genre": g}}


func _stage() -> Dictionary:
	return {"id": "palco", "genres": {"startMs": 12000, "order": ["metal", "reggae", "techno"], "everyMs": 18000, "beatMs": 500},
		"pads": [_disco("metal"), _disco("reggae"), _disco("techno")], "platforms": [], "hazards": []}


func test_il_genere_come_la_fisica() -> void:
	var s := _stage()
	runner.check(StageMotion.genre_at(s, 11999, [null, null, null]) == "", "prova del suono")
	runner.check(StageMotion.genre_at(s, 12000, [null, null, null]) == "metal", "parte il metal")
	runner.check(StageMotion.genre_at(s, 30000, [null, null, null]) == "reggae", "poi il reggae")
	runner.check(StageMotion.genre_at(s, 48000, [null, null, null]) == "techno", "poi la techno")
	runner.check(StageMotion.genre_at(s, 66000, [null, null, null]) == "metal", "e si ricomincia")
	runner.check(StageMotion.genre_at(s, 2000, [null, 1000, null]) == "reggae", "un disco vince sul DJ")
	runner.check(StageMotion.genre_at(s, 4000, [null, 1000, 3000]) == "techno", "vince l'ultimo disco")
	runner.check(StageMotion.genre_at(s, 15000, [null, null, 3000]) == "metal", "finito il disco torna il DJ")
	runner.check(StageMotion.techno_beat(s, 1999, 4) == 0 and StageMotion.techno_beat(s, 2000, 4) == 1, "il giro della techno")
	runner.check(StageMotion.genre_ok({"genre": "techno", "beat": 1}, "techno", 1), "la piattaforma c'è")
	runner.check(not StageMotion.genre_ok({"genre": "techno", "beat": 1}, "techno", 0), "nell'altro giro no")
	runner.check(not StageMotion.genre_ok({"genre": "techno"}, "metal", 0), "con un altro genere no")


func test_il_dj_annuncia_il_cambio() -> void:
	var c := Concert.new()
	c.setup(_stage(), {"genre": {"technoBlinkBeats": 4, "warnMs": 2000}})
	runner.check(c.auto_change_in(20000, [null, null, null]) < 0.0, "lontano dal cambio: zitto")
	runner.check(is_equal_approx(c.auto_change_in(29000, [null, null, null]), 1000.0), "a un secondo dal reggae")
	runner.check(c.auto_change_in(29000, [null, null, 25000]) < 0.0, "se un disco copre il cambio non annuncia niente")
	var cues: Array = c.cues(27900, 28100, [null, null, null])
	runner.check(cues.size() == 1 and cues[0][0] == "airhorn", "la tromba quando parte l'avviso")
	cues = c.cues(29990, 30010, [null, null, null])
	runner.check(cues.size() == 1 and cues[0][0] == "pad_reggae", "il cambio del DJ suona il genere nuovo")


func test_il_palco_ha_il_suo_tema() -> void:
	var theme := ThemeStage.new()
	theme.setup(_stage(), {})
	runner.check(theme.active(), "tema attivo")
