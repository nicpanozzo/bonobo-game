# Sfondo vivo delle arene (#260): stormi, passanti, piccioni e tramonto, calcolati dal tempo dell'arena
extends RefCounted

var runner

const StageLife := preload("res://scripts/stage_life.gd")
const StageSky := preload("res://scripts/stage_sky.gd")


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
	runner.check(life.sky.day_phase(5000) == 0.0, "la partita comincia a mezzogiorno (startAt 0)")
	runner.check(is_equal_approx(life.sky.day_phase(55000), 0.5), "a metà giro è mezzanotte")
	runner.check(is_equal_approx(life.sky.day_phase(105000), 0.0), "poi il giorno ricomincia")
	runner.check(StageSky.darkness(0.0) == 0.0 and StageSky.darkness(0.5) == 1.0, "buio solo di notte")
	runner.check(StageSky.darkness(0.25) > 0.0 and StageSky.darkness(0.25) < 1.0, "al tramonto a metà")
	var empty := StageLife.new()
	empty.setup({}, 1280, 720)
	runner.check(empty.is_empty() and empty.sky.day_phase(99999) == 0.0, "senza life l'arena resta com'è")
	runner.check(empty.sky.ambient(12345) == Color.WHITE, "e la luce resta bianca")


# I colori del cielo e della luce (#267): alba rosa, giorno azzurro, tramonto arancio, notte blu e luce fredda
func test_colori_del_cielo() -> void:
	var noon: Array = StageSky.sky_colors(0.0)
	var sunset: Array = StageSky.sky_colors(0.25)
	var night: Array = StageSky.sky_colors(0.5)
	var dawn: Array = StageSky.sky_colors(0.75)
	runner.check((noon[0] as Color).b > (noon[0] as Color).r, "a mezzogiorno il cielo è azzurro")
	runner.check((sunset[1] as Color).r > 0.9 and (sunset[1] as Color).b < 0.5, "al tramonto l'orizzonte è arancio")
	runner.check((night[0] as Color).v < 0.2, "di notte il cielo è scuro")
	runner.check((dawn[1] as Color).r > (dawn[1] as Color).b, "all'alba l'orizzonte è caldo")
	runner.check((night[2] as Color).v < 0.65 and (noon[2] as Color) == Color.WHITE, "la luce: piena a mezzogiorno, fredda e bassa di notte")
	var a: Color = StageSky.sky_colors(0.249)[1]
	var b: Color = StageSky.sky_colors(0.251)[1]
	runner.check(a.is_equal_approx(b) or absf(a.r - b.r) < 0.02, "i colori sfumano senza salti")


func test_nuvole_che_scorrono() -> void:
	var c0 := StageSky.cloud_at(3, 0, 3500)
	var c1 := StageSky.cloud_at(3, 10000, 3500)
	runner.check(c1.x != c0.x, "le nuvole si muovono")
	runner.check(StageSky.cloud_at(3, 10000, 3500).x == c1.x, "sempre uguali allo stesso tempo")
	runner.check(c0.x >= 0 and c0.x < 3500, "dentro il tratto")


func test_sole_e_luna_attraversano_il_cielo() -> void:
	var rise := StageSky.sky_body(0.76, 1920)
	var noon := StageSky.sky_body(0.0, 1920)
	var set_ := StageSky.sky_body(0.24, 1920)
	runner.check(rise.x < noon.x and noon.x < set_.x, "il sole va da sinistra a destra")
	runner.check(noon.y < rise.y and noon.y < set_.y, "a mezzogiorno è in alto")
	runner.check(is_equal_approx(StageSky.sky_body(0.5, 1920).x, noon.x), "a mezzanotte la luna è in cima")


func test_acqua_intorno_e_splash() -> void:
	var life := StageLife.new()
	life.setup({"art": {"life": {"outerWater": {"y": 800, "highY": 760, "flood": 0}}}}, 1920, 720)
	runner.check(life.outer_water_level(0.0) == 800.0 and life.outer_water_level(1.0) == 760.0, "sale con l'acqua alta")


# Traffico (#278): stessi veicoli per lo stesso tempo, tutti tra i due margini, nei due versi
func test_traffico_sempre_uguale_e_in_strada() -> void:
	var tr := {"y": 488, "parallax": 0.5, "everyMs": 2600, "kinds": ["auto", "vespa", "furgone", "bici", "bus"]}
	var a := StageLife.traffic_at(tr, 61500.0, 1920.0)
	runner.check(a.size() > 2, "in strada ci sono più veicoli: %d" % a.size())
	runner.check(str(a) == str(StageLife.traffic_at(tr, 61500.0, 1920.0)), "stesso tempo, stessi veicoli")
	var dirs := {}
	for v in a:
		var length: float = StageLife.TRAFFIC[v.kind].length
		runner.check(v.x >= -StageLife.TRAFFIC_MARGIN - length - 1.0 and v.x <= 1920.0 + StageLife.TRAFFIC_MARGIN + 1.0, "%s dentro la strada: %s" % [v.kind, v.x])
		dirs[v.dir] = true
	var later := StageLife.traffic_at(tr, 61600.0, 1920.0)
	var moved := false
	for v in later:
		for w in a:
			if v.n == w.n:
				moved = moved or (v.x - w.x) * v.dir > 0.0
	runner.check(moved, "i veicoli vanno nel loro verso")
	var many := 0
	for k in 40:
		many += StageLife.traffic_at(tr, k * 2600.0 + 1300.0, 1920.0).size()
	runner.check(many > 40, "passa sempre qualcuno")
	runner.check(StageLife.traffic_slot(7, tr.kinds).dir == StageLife.traffic_slot(7, tr.kinds).dir, "il giro decide tipo e verso")


# Passanti (#278): tanti tipi, chi corre va più veloce
func test_passanti_di_tanti_tipi() -> void:
	var kinds := {}
	for i in 14:
		kinds[StageLife.walker_kind(i)] = true
	runner.check(kinds.size() >= 6, "almeno sei tipi in 14 passanti: %s" % [kinds.keys()])
	runner.check(StageLife.walker_kind(3) == StageLife.walker_kind(3), "sempre lo stesso tipo")


# Il bar (#278): ogni tanto si brinda, e intanto si beve a sorsi; il cameriere resta tra i tavolini
func test_bar_dello_spritz() -> void:
	var toasts := 0
	var sips := 0
	for k in 220:
		var t := k * 100.0
		if StageLife.bar_toast(0, t):
			toasts += 1
		var up := StageLife.bar_sip(1, 0, t)
		runner.check(up >= 0.0 and up <= 1.0, "il bicchiere tra il tavolo e la bocca")
		if up > 0.5 and not StageLife.bar_toast(1, t):
			sips += 1
	runner.check(toasts > 0 and toasts < 60, "un brindisi ogni tanto: %d decimi su 220" % toasts)
	runner.check(sips > 0, "si beve anche senza brindare")
	runner.check(StageLife.bar_sip(2, 1, 0.0) == 1.0 or not StageLife.bar_toast(2, 0.0), "nel brindisi il bicchiere è alzato")
	for k in 50:
		var x := StageLife.waiter_x(k * 700.0, 100.0, 300.0)
		runner.check(x >= 100.0 and x <= 300.0, "il cameriere tra i tavolini: %s" % x)


# Aereo e uccelli vicini (#278)
func test_aereo_e_rondini() -> void:
	var p := StageLife.plane_at(75000, 20000)
	runner.check(p.on and p.dir == 1 and is_equal_approx(p.k, 0.5), "a metà del primo passaggio")
	runner.check(not StageLife.plane_at(75000, 50000).on, "poi il cielo è libero")
	runner.check(StageLife.plane_at(75000, 80000).dir == -1, "il giro dopo nell'altro verso")
	var f := StageLife.flyer_at(2, 12345, 2700, 90)
	runner.check(f.x >= 0 and f.x < 2700 and f.y > 0 and f.y < 320, "la rondine resta in cielo: %s" % f)


# Fogli dipinti (#288): Padova li ha, un'arena senza resta con le forme semplici
func test_fogli_dipinti_dello_sfondo_vivo() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var life := StageLife.new()
	life.setup(game.stages.padova, 1920, 720)
	for n in ["nuvole", "gabbiano", "rondine", "pipistrello", "piccione"]:
		runner.check(life.has_sheet(n), "Padova ha il foglio %s" % n)
	var empty := StageLife.new()
	empty.setup({"art": {"life": {"birds": {"y": 40, "parallax": 0.2, "everyMs": 14000}}}}, 1280, 720)
	runner.check(not empty.has_sheet("gabbiano"), "senza fogli, le forme di prima")
