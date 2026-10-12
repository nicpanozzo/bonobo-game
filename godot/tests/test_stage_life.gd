# Sfondo vivo delle arene (#260): stormi, passanti, piccioni e tramonto, calcolati dal tempo dell'arena
extends RefCounted

var runner

const StageLife := preload("res://scripts/stage_life.gd")


func test_stormo_a_giri_alterni() -> void:
	var a := StageLife.bird_flock(14000, 5000)
	runner.check(a.on and a.dir == 1 and is_equal_approx(a.k, 0.5), "a metà del primo passaggio, verso destra")
	runner.check(not StageLife.bird_flock(14000, 12000).on, "dopo 10 s il cielo è vuoto fino al prossimo")
	runner.check(StageLife.bird_flock(14000, 15000).dir == -1, "il giro dopo va verso sinistra")


func test_passanti_sempre_uguali_e_nel_tratto() -> void:
	for i in 6:
		var x := StageLife.walker_x(i, 123456, 2500)
		runner.check(x >= 0 and x < 2500, "passante %d dentro il tratto" % i)
		runner.check(x == StageLife.walker_x(i, 123456, 2500), "stesso tempo, stessa posizione")


func test_piccioni_scappano_da_chi_arriva_vicino() -> void:
	var p := {"x": 500.0, "y": 330.0}
	runner.check(StageLife.pigeon_scared(p, [Vector2(560, 330)], []), "un lottatore vicino li fa scappare")
	runner.check(not StageLife.pigeon_scared(p, [Vector2(900, 520)], []), "lontano no")
	runner.check(StageLife.pigeon_scared(p, [], [Rect2(450, 250, 80, 95)]), "anche il ciclista che passa")


func test_giorno_e_notte() -> void:
	var life := StageLife.new()
	life.setup({"art": {"life": {"daycycle": {"cycleMs": 100000, "startAt": 0.0, "lamps": [{"x": 0, "y": 0, "parallax": 0.75}]}}}}, 1920, 720)
	runner.check(life.day_phase(5000) == 0.0, "la partita comincia a mezzogiorno (startAt 0)")
	runner.check(is_equal_approx(life.day_phase(55000), 0.5), "a metà giro è mezzanotte")
	runner.check(is_equal_approx(life.day_phase(105000), 0.0), "poi il giorno ricomincia")
	runner.check(StageLife.darkness(0.0) == 0.0 and StageLife.darkness(0.5) == 1.0, "buio solo di notte")
	runner.check(StageLife.darkness(0.25) > 0.0 and StageLife.darkness(0.25) < 1.0, "al tramonto a metà")
	runner.check(StageLife.sky_tint(0.0).a == 0.0 and StageLife.sky_tint(0.5).a > 0.4, "di giorno niente velo, di notte blu")
	var empty := StageLife.new()
	empty.setup({}, 1280, 720)
	runner.check(empty.is_empty() and empty.day_phase(99999) == 0.0, "senza life l'arena resta com'è")
