# Sala d'attesa 3D: la scena si costruisce da uno snapshot finto, il movimento si interpola, gli eventi non rompono niente
extends RefCounted

var runner

const View := preload("res://scripts/hall_view.gd")
const Buffer := preload("res://scripts/hall_buffer.gd")
const Fake := preload("res://tests/hall_fake.gd")


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
