# Interpolazione degli snapshot (snapshot_buffer.gd), gli stessi casi di src/client/interpolation.test.ts
extends RefCounted

var runner


func _players(x: float, y := 0.0) -> Array:
	return [{"id": "a", "x": x, "y": y, "percent": 0}]


func test_interpola_a_meta() -> void:
	var b := SnapshotBuffer.new()
	b.push(1000, 1020, _players(0))
	b.push(1100, 1120, _players(100))
	var s: Variant = b.sample("a", 1070 + b.delay_ms)
	runner.check(s != null and absf(s.x - 50.0) < 0.01, "x atteso 50, avuto %s" % [s])


func test_teletrasporto_non_interpola() -> void:
	var b := SnapshotBuffer.new()
	b.push(1000, 1020, _players(0))
	b.push(1100, 1120, _players(1000))
	var s: Variant = b.sample("a", 1060 + b.delay_ms)
	runner.check(s.x == 0.0 or s.x == 1000.0, "con un salto oltre teleport_distance non si interpola: %s" % [s.x])


func test_fuori_ordine_scartato() -> void:
	var b := SnapshotBuffer.new()
	b.push(1000, 1020, _players(0))
	b.push(1100, 1120, _players(100))
	b.push(1050, 1130, _players(999)) # arriva dopo ma è più vecchio
	var s: Variant = b.sample("a", 1070 + b.delay_ms)
	# L'orologio stimato si sposta di poco (0,5 ms), ma la x vecchia non entra
	runner.check(absf(s.x - 50.0) < 1.0, "lo snapshot fuori ordine va ignorato: %s" % [s.x])


func test_senza_dati_niente() -> void:
	var b := SnapshotBuffer.new()
	runner.check(b.sample("a", 5000) == null, "buffer vuoto: null")
	runner.check(b.sample_stage_ms(5000) == 0.0, "buffer vuoto: tempo dell'arena 0")


func test_dopo_l_ultimo_resta_l_ultimo() -> void:
	var b := SnapshotBuffer.new()
	b.push(1000, 1020, _players(0))
	b.push(1100, 1120, _players(100))
	var s: Variant = b.sample("a", 5000)
	runner.check(s.x == 100.0, "oltre l'ultimo snapshot si resta lì: %s" % [s.x])


func test_giocatore_sparito_usa_l_ultimo_noto() -> void:
	var b := SnapshotBuffer.new()
	b.push(1000, 1020, _players(40))
	b.push(1100, 1120, [])
	var s: Variant = b.sample("a", 1150 + b.delay_ms)
	runner.check(s != null and s.x == 40.0, "si usa l'ultima posizione nota: %s" % [s])


func test_tempo_arena_interpolato() -> void:
	var b := SnapshotBuffer.new()
	b.push(1000, 1020, [], 0.0)
	b.push(1100, 1120, [], 100.0)
	runner.check(absf(b.sample_stage_ms(1070 + b.delay_ms) - 50.0) < 0.01, "tempo dell'arena a metà")
	runner.check(absf(b.sample_stage_ms(1220 + b.delay_ms) - 200.0) < 0.01, "oltre l'ultimo va avanti con l'orologio")


func test_tiene_al_massimo_size_snapshot() -> void:
	var b := SnapshotBuffer.new()
	for i in 50:
		b.push(1000 + i * 33, 1020 + i * 33, _players(i))
	runner.check(b._frames.size() == b.size, "frame tenuti: %d" % b._frames.size())
