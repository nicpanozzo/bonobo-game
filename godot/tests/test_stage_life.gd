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
	var empty := StageLife.new()
	empty.setup({}, 1280, 720)
	runner.check(empty.is_empty() and empty.day_phase(99999) == 0.0, "senza life l'arena resta com'è")
	runner.check(empty.ambient(12345) == Color.WHITE, "e la luce resta bianca")


# I colori del cielo e della luce (#267): alba rosa, giorno azzurro, tramonto arancio, notte blu e luce fredda
func test_colori_del_cielo() -> void:
	var noon: Array = StageLife.sky_colors(0.0)
	var sunset: Array = StageLife.sky_colors(0.25)
	var night: Array = StageLife.sky_colors(0.5)
	var dawn: Array = StageLife.sky_colors(0.75)
	runner.check((noon[0] as Color).b > (noon[0] as Color).r, "a mezzogiorno il cielo è azzurro")
	runner.check((sunset[1] as Color).r > 0.9 and (sunset[1] as Color).b < 0.5, "al tramonto l'orizzonte è arancio")
	runner.check((night[0] as Color).v < 0.2, "di notte il cielo è scuro")
	runner.check((dawn[1] as Color).r > (dawn[1] as Color).b, "all'alba l'orizzonte è caldo")
	runner.check((night[2] as Color).v < 0.65 and (noon[2] as Color) == Color.WHITE, "la luce: piena a mezzogiorno, fredda e bassa di notte")
	var a: Color = StageLife.sky_colors(0.249)[1]
	var b: Color = StageLife.sky_colors(0.251)[1]
	runner.check(a.is_equal_approx(b) or absf(a.r - b.r) < 0.02, "i colori sfumano senza salti")


func test_nuvole_che_scorrono() -> void:
	var c0 := StageLife.cloud_at(3, 0, 3500)
	var c1 := StageLife.cloud_at(3, 10000, 3500)
	runner.check(c1.x != c0.x, "le nuvole si muovono")
	runner.check(StageLife.cloud_at(3, 10000, 3500).x == c1.x, "sempre uguali allo stesso tempo")
	runner.check(c0.x >= 0 and c0.x < 3500, "dentro il tratto")


func test_sole_e_luna_attraversano_il_cielo() -> void:
	var rise := StageLife.sky_body(0.76, 1920)
	var noon := StageLife.sky_body(0.0, 1920)
	var set_ := StageLife.sky_body(0.24, 1920)
	runner.check(rise.x < noon.x and noon.x < set_.x, "il sole va da sinistra a destra")
	runner.check(noon.y < rise.y and noon.y < set_.y, "a mezzogiorno è in alto")
	runner.check(is_equal_approx(StageLife.sky_body(0.5, 1920).x, noon.x), "a mezzanotte la luna è in cima")


func test_acqua_intorno_e_splash() -> void:
	var life := StageLife.new()
	life.setup({"art": {"life": {"outerWater": {"y": 800, "highY": 760, "flood": 0}}}}, 1920, 720)
	runner.check(life.outer_water_level(0.0) == 800.0 and life.outer_water_level(1.0) == 760.0, "sale con l'acqua alta")
