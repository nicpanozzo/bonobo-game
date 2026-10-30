# Sala d'attesa 3D: la scena si costruisce da uno snapshot finto, il movimento si interpola, gli eventi non rompono niente
extends RefCounted

var runner

const View := preload("res://scripts/hall_view.gd")
const Buffer := preload("res://scripts/hall_buffer.gd")
const Fake := preload("res://tests/hall_fake.gd")
const Audio := preload("res://scripts/audio.gd")


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func test_interpolazione_tra_due_snapshot() -> void:
	var b := Buffer.new()
	b.delay_ms = 100.0
	var a := Fake.player("a", "Anna", "default", 0xe74c3c, 0.0, 0.0)
	var a2 := Fake.player("a", "Anna", "default", 0xe74c3c, 100.0, 50.0, {"y": 40.0})
	b.push(1000.0, 5000.0, [a])
	b.push(1033.0, 5033.0, [a2])
	# ora locale 5116.5 = server 1016.5 dopo i 100 ms di ritardo: a metà
	var p: Dictionary = b.sample_all(5116.5).a
	runner.check(absf(float(p.x) - 50.0) < 1.0, "x a metà strada: %s" % p.x)
	runner.check(absf(float(p.z) - 25.0) < 1.0, "z a metà strada: %s" % p.z)
	runner.check(float(p.vy) > 0.0, "sta salendo")
	var late: Dictionary = b.sample_all(9000.0).a
	runner.check(is_equal_approx(float(late.x), 100.0), "senza snapshot nuovi resta all'ultimo")
	# un salto enorme (rientro) non si attraversa a metà
	b.push(1066.0, 5066.0, [Fake.player("a", "Anna", "default", 0xe74c3c, 2000.0, 50.0)])
	var jump: Dictionary = b.sample_all(5150.0).a
	runner.check(float(jump.x) == 100.0 or float(jump.x) == 2000.0, "teletrasporto senza strisciata: %s" % jump.x)


func test_la_sala_si_costruisce_con_tutte_le_zone_e_i_lottatori() -> void:
	var v: Node3D = View.new()
	runner.root.add_child(v)
	v.setup(_game(), "p0")
	var snap := Fake.party(0.0)
	var kinds := {}
	for z in snap.zones:
		kinds[z.kind] = true
	for k in ["mode", "stage", "fighter", "ready", "trampoline", "botAdd", "botRemove", "gong", "throne"]:
		runner.check(kinds.has(k), "lo snapshot finto ha la zona %s" % k)
	var chars := {}
	for p in snap.players:
		chars[p.characterId] = true
	runner.check(chars.has("default") and chars.has("nonnagina") and chars.has("orsoblu"), "Bonobo senza disegno, Nonna Gina a pezzi e la pixel art")
	v.on_snapshot(snap)
	runner.check(v.zone_count() == snap.zones.size(), "una zona disegnata per ogni zona: %d" % v.zone_count())
	v.on_snapshot(Fake.party(33.0))
	v._process(0.016)
	runner.check(v.fighter_count() == snap.players.size(), "un lottatore per giocatore: %d" % v.fighter_count())
	runner.check(v.sampled("p0") != null, "il mio lottatore ha una posizione")
	# le zone uguali non si rifanno a ogni snapshot
	var zone: Node = v.get_node("Zones").get_child(0)
	v.on_snapshot(Fake.party(66.0))
	runner.check(is_instance_valid(zone) and not zone.is_queued_for_deletion(), "zone tenute tra uno snapshot e l'altro")
	# chi esce sparisce
	var fewer := Fake.party(99.0)
	fewer.players = fewer.players.slice(0, 3)
	v.on_snapshot(fewer)
	runner.check(v.fighter_count() == 3, "chi esce non resta nella sala")
	v.free()


func test_eventi_e_maxischermo() -> void:
	var v: Node3D = View.new()
	runner.root.add_child(v)
	v.setup(_game(), "p0")
	v.on_snapshot(Fake.party(0.0))
	v.on_snapshot(Fake.party(33.0))
	v._process(0.016)
	var events := [
		{"type": "hop", "id": "p0"}, {"type": "land", "id": "p0"}, {"type": "bounce", "id": "p5"},
		{"type": "shove", "id": "p0", "targets": ["p1", "p2"]}, {"type": "vote", "id": "p1", "what": "mode", "value": "teams"},
		{"type": "vote", "id": "p1", "what": "stage", "value": "casuale"}, {"type": "pick", "id": "p2", "characterId": "bonobot", "skinId": ""},
		{"type": "gong", "id": "p0"}, {"type": "throne", "id": "p3"}, {"type": "bot", "id": "p6", "added": true},
		{"type": "bot", "id": "nuovo-bot", "added": true}, {"type": "join", "id": "p4"}, {"type": "leave", "id": "p7"},
		{"type": "countdown", "ms": 5000}, {"type": "cancel"}, {"type": "go", "mode": "ffa", "stageId": "palco"},
		{"type": "sconosciuto"},
	]
	for e in events:
		v.on_event(e)
	v._process(0.016)
	runner.check(true, "nessun evento rompe la sala")
	v.on_snapshot(Fake.party(66.0, "conto"))
	var lines: Dictionary = v.screen_lines()
	runner.check(str(lines.title).begins_with("SI PARTE TRA"), "il maxischermo conta: %s" % lines.title)
	runner.check(str(lines.main).contains("Tutti contro tutti") and str(lines.main).contains("Il Palco"), "modalità e arena in testa: %s" % lines.main)
	v.free()


func test_tabellone() -> void:
	var lines: Array = View.board_lines(Fake.BOARD)
	runner.check(lines.size() == Fake.BOARD.size(), "una riga per giocatore")
	runner.check(lines[0].rank == 1 and lines[0].name == "Nicola", "primo in cima")
	runner.check(lines[0].hot and not lines[1].hot and lines[2].hot, "la fiammella dalla terza vittoria di fila")
	runner.check(View.board_lines([]).is_empty() and View.board_lines([null, 3]).is_empty(), "righe strane ignorate")


func _view(scene := "basket") -> Node3D:
	var v: Node3D = View.new()
	runner.root.add_child(v)
	v.setup(_game(), "p0")
	v.on_snapshot(Fake.party(0.0, scene))
	v.on_snapshot(Fake.party(33.0, scene))
	v._process(0.016)
	v._process(0.016)
	return v


func test_angoli_interpolati_senza_giro_lungo() -> void:
	var b := Buffer.new()
	b.angles = ["yaw", "spin"]
	b.push(1000.0, 5000.0, [{"id": "a", "x": 0, "y": 0, "z": 0, "yaw": 3.1, "spin": 6.2}])
	b.push(1033.0, 5033.0, [{"id": "a", "x": 0, "y": 0, "z": 0, "yaw": -3.1, "spin": 0.1}])
	var p: Dictionary = b.sample_all(5116.5).a
	runner.check(absf(absf(float(p.yaw)) - PI) < 0.1, "yaw passa da PI e non fa il giro: %s" % p.yaw)
	runner.check(float(p.spin) > 6.0 or float(p.spin) < 0.3, "spin ricomincia da 0 senza tornare indietro: %s" % p.spin)


func test_oggetti_della_zona_giochi() -> void:
	var v := _view("basket")
	runner.check(v.props.count() == Fake.props().size(), "un oggetto disegnato per ogni oggetto: %d" % v.props.count())
	# il pallone in mano sta sopra la testa di chi lo tiene, non dove dice lo snapshot
	var f: Node3D = v._fighters["p0"]
	var held: Vector3 = v.props.position_of("ball-2")
	runner.check(Vector2(held.x - f.position.x, held.z - f.position.z).length() < 0.6, "il pallone segue chi lo tiene")
	runner.check(held.y > f.top_height(), "sopra la testa: %.2f > %.2f" % [held.y, f.top_height()])
	# ogni pezzo ha la sua mesh al tornio con le finiture d'oro
	var king: Node3D = v.props.node_of("chess-w-king")
	runner.check(king != null and king.body.mesh.get_surface_count() == 2, "il re ha corpo e oro")
	v.free()


func test_pezzo_caduto_ruota_sullo_spigolo() -> void:
	var v := _view("scacchi")
	var pawn: Node3D = v.props.node_of("chess-w-pawn-e") # caduto verso -z (tiltDir -PI/2)
	var up: Vector3 = pawn.body.transform.basis.y
	runner.check(absf(up.y) < 0.05 and up.z < -0.9, "il pedone è disteso verso -z: %s" % up)
	runner.check(pawn.body.transform.origin.y > 0.1, "ruotando sullo spigolo la base si alza: %s" % pawn.body.transform.origin)
	var standing: Node3D = v.props.node_of("chess-w-queen")
	runner.check(standing.body.transform.basis.y.is_equal_approx(Vector3.UP), "la regina è in piedi")
	for id in ["chess-w-pawn-a", "chess-b-rook-h", "chess-w-knight-b", "chess-b-bishop-c", "chess-w-queen"]:
		var shape: Dictionary = v.props.piece_shape(id.split("-")[2])
		runner.check(float(shape.height) > 1.0 and (shape.profile as Array).size() > 6, "profilo di %s" % id)
	v.free()


func test_canestro_campo_e_scacchiera() -> void:
	var v := _view("basket")
	var hoop: Node3D = v._zones["hoop/canestro"]
	var court: Node3D = v._zones["court/campo"]
	# il tabellone è tra il ferro e il muro di destra: il canestro guarda il campo (-x)
	var facing := hoop.basis.z
	runner.check(facing.x < -0.9, "il canestro guarda il campo: %s" % facing)
	var rim: Vector3 = hoop.rim_point()
	runner.check(absf(rim.y - 3.05) < 0.01 and absf(rim.x - 25.42) < 0.01, "ferro all'altezza del server: %s" % rim)
	runner.check(hoop.board_point().x > rim.x, "il tabellone sta dietro al ferro")
	# il fondo del parquet passa dietro al ferro, a FIBA_HOOP (scalato) dal centro del ferro
	var s: float = court._court_size.x / 15.0
	var baseline: float = court.position.x + court._court.position.x + court._court_size.y / 2.0
	runner.check(absf(baseline - (rim.x + 1.575 * s)) < 0.05, "il parquet finisce sotto il canestro: %.2f" % baseline)
	runner.check(v.zone_count() == Fake.ZONES.size(), "tutte le zone, anche rastrelliera e scacchiera")
	runner.check(v.hit_surface(rim + Vector3(0.23, 0.0, 0.0), 0.12, "basketball") == "rim", "colpo sul ferro")
	runner.check(v.hit_surface(Vector3(25.7, 3.7, 0.6), 0.12, "basketball") == "board", "colpo sul tabellone")
	runner.check(v.hit_surface(Vector3(20.0, 0.12, 2.0), 0.12, "basketball") == "floor", "rimbalzo a terra")
	runner.check(v.hit_surface(Vector3(-21.0, 0.5, 0.0), 0.2, "chess") == "piece", "pezzo degli scacchi")
	v.free()


func test_eventi_di_palloni_e_scacchi() -> void:
	var v := _view("basket")
	var events := [
		{"type": "pickup", "id": "p0", "prop": "ball-2"}, {"type": "throw", "id": "p0", "prop": "ball-2"},
		{"type": "propHit", "prop": "ball-1", "speed": 900}, {"type": "propHit", "prop": "beach-2", "speed": 300},
		{"type": "propHit", "prop": "nessuno", "speed": 10}, {"type": "pickup", "id": "chi?", "prop": "nessuno"},
		{"type": "topple", "prop": "chess-b-pawn-a", "by": "p0"}, {"type": "topple", "prop": "nessuno", "by": null},
		{"type": "basket", "id": "p2", "prop": "ball-1", "points": 3, "swish": true},
	]
	for e in events:
		v.on_event(e)
	v._process(0.016)
	runner.check(str(events[2].get("surface", "")) != "", "propHit dice dove ha sbattuto (per audio.gd)")
	var hoop: Node3D = v._zones["hoop/canestro"]
	runner.check(hoop._score_name.text == "Riccardo" and hoop._score_points.text == "+3", "il tabellino del canestro: %s %s" % [hoop._score_name.text, hoop._score_points.text])
	runner.check(str(v.screen_lines().big) == "TRIPLA!", "il maxischermo: %s" % v.screen_lines().big)
	runner.check(str(v.screen_lines().sub).contains("Riccardo"), "l'ultimo canestro sul maxischermo: %s" % v.screen_lines().sub)
	v.on_event({"type": "checkmate", "id": "", "color": "black"})
	v.on_event({"type": "checkmate", "id": "p0", "color": "white"})
	v._process(0.016)
	runner.check(str(v.screen_lines().big) == "SCACCO MATTO!", "scacco matto sul maxischermo")
	runner.check(v.props.node_of("chess-w-king").glow != null, "il re caduto brilla")
	for e in events + [{"type": "checkmate", "color": "white"}]:
		runner.check(e.type == "propHit" and str(e.prop) == "nessuno" or not Audio.hall_cue(e).is_empty(), "%s suona" % e.type)
	for name in ["hallBounce", "hallBeachBounce", "hallRim", "hallBoard", "hallNet", "hallCheer", "hallCheer3", "hallChessThud", "hallTopple", "hallCheckmate"]:
		var used := false
		for c in [Audio.prop_hit_cue("rim", "", 500), Audio.prop_hit_cue("board", "", 500), Audio.prop_hit_cue("floor", "beachball", 500),
				Audio.prop_hit_cue("floor", "basketball", 500), Audio.prop_hit_cue("piece", "chess", 500), Audio.hall_cue({"type": "topple"}),
				Audio.hall_cue({"type": "checkmate"}), Audio.hall_cue({"type": "basket", "points": 2}), Audio.hall_cue({"type": "basket", "points": 3})]:
			used = used or c.sound == name or c.get("then", "") == name
		runner.check(used, "il suono %s si usa" % name)
	runner.check(Audio.prop_hit_cue("floor", "basketball", 1500).volume > Audio.prop_hit_cue("floor", "basketball", 200).volume, "più forte, più alto")
	v.free()


func test_voce_e_nomi_che_non_si_accavallano() -> void:
	var v := _view("basket")
	v.set_speaking("p1", true)
	v.set_voice_muted("p3", true)
	v.set_speaking("p3", true) # col microfono spento non parla
	for i in 4:
		v._process(0.05)
	var nicola: Node3D = v._fighters["p1"]
	var marta: Node3D = v._fighters["p3"]
	runner.check(nicola.speaking and nicola._voice_ring.visible and nicola._voice_icon.visible, "chi parla ha l'anello verde e l'altoparlante")
	runner.check(not marta.speaking and marta.voice_muted and marta._voice_icon.visible and not marta._voice_ring.visible, "microfono spento")
	v.set_speaking("p1", false)
	for i in 20:
		v._process(0.05)
	runner.check(not nicola._voice_icon.visible and not nicola._voice_ring.visible, "finito di parlare si spegne")
	runner.check(marta._badge != null and marta._badge.visible and marta._badge_count.text == "7", "i canestri accanto al nome")
	# due giocatori uno sull'altro: il nome di quello più lontano dalla telecamera sale sopra l'altro
	var snap := Fake.party(2000.0, "basket")
	snap.players[4].x = snap.players[5].x
	snap.players[4].z = snap.players[5].z - 30
	v.on_snapshot(snap)
	snap = snap.duplicate(true)
	snap.t = 2033.0
	v.on_snapshot(snap)
	for i in 6:
		v._process(0.05)
	v._declutter()
	var a: float = v._fighters["p4"].tag_lift_target
	var b: float = v._fighters["p5"].tag_lift_target
	runner.check(maxf(a, b) > 0.2 and minf(a, b) < 0.05, "un nome sale, l'altro resta: %.2f %.2f" % [a, b])
	v.free()
