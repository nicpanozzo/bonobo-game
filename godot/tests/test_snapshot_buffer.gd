# Interpolazione degli snapshot (snapshot_buffer.gd)
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


# E17 passo 1: il proprio lottatore segue l'ultimo snapshot, senza il ritardo d'interpolazione
func _me(x: float, y := 0.0, on_ground := false) -> Array:
	return [{"id": "me", "x": x, "y": y, "onGround": on_ground}, {"id": "a", "x": x, "y": y}]


func test_il_mio_lottatore_va_avanti() -> void:
	var b := SnapshotBuffer.new()
	b.own_id = "me"
	b.own_extrapolate_ms = 50.0
	b.push(1000, 1020, _me(0, 0))
	b.push(1100, 1120, _me(100, -50)) # 1 px/ms in x, -0,5 px/ms in y
	var s: Dictionary = b.sample_all(["me", "a"], 1140)
	runner.check(absf(s.me.x - 120.0) < 0.01 and absf(s.me.y + 60.0) < 0.01, "20 ms dopo l'ultimo: 120, -60, avuto %s, %s" % [s.me.x, s.me.y])
	runner.check(s.a.x < 100.0, "gli altri restano interpolati nel passato: %s" % [s.a.x])
	var far: Variant = b.sample("me", 5000)
	runner.check(absf(far.x - 150.0) < 0.01, "non oltre own_extrapolate_ms: %s" % [far.x])


func test_il_mio_lottatore_a_terra_non_scende() -> void:
	var b := SnapshotBuffer.new()
	b.own_id = "me"
	b.push(1000, 1020, _me(0, 300, true))
	b.push(1100, 1120, _me(100, 310, true))
	var s: Variant = b.sample("me", 1140)
	runner.check(s.y == 310.0 and s.x > 100.0, "a terra si corre ma non si scende: %s, %s" % [s.x, s.y])


func test_il_mio_lottatore_fermo_nel_colpo_non_trema() -> void:
	var b := SnapshotBuffer.new()
	b.own_id = "me"
	var frozen: Array = [{"id": "me", "x": 50.0, "y": 0.0, "vx": 900.0, "vy": -400.0}]
	b.push(1000, 1020, frozen)
	b.push(1033, 1053, frozen) # hitstop: vx grande ma la posizione non cambia
	var s: Variant = b.sample("me", 1080)
	runner.check(s.x == 50.0 and s.y == 0.0, "senza spostamento tra due snapshot si resta lì: %s, %s" % [s.x, s.y])


func test_il_mio_lottatore_dopo_il_rientro_non_scivola() -> void:
	var b := SnapshotBuffer.new()
	b.own_id = "me"
	b.push(1000, 1020, _me(0))
	b.push(1100, 1120, _me(1000)) # rientro dopo un KO: oltre teleport_distance
	var s: Variant = b.sample("me", 1140)
	runner.check(s.x == 1000.0, "un salto lungo non diventa una velocità: %s" % [s.x])


# #227: nell'intervallo in cui atterra, il lottatore scende alla velocità che aveva in aria, non più piano
func test_atterraggio_senza_rallentare() -> void:
	var b := SnapshotBuffer.new()
	b.push(1000, 1020, [{"id": "a", "x": 0, "y": 580, "vy": 950, "onGround": false}])
	b.push(1033, 1053, [{"id": "a", "x": 0, "y": 600, "vy": 0, "onGround": true}])
	var s: Variant = b.sample("a", 1030 + b.delay_ms) # ora del server 1010
	runner.check(absf(s.y - 589.5) < 0.01, "a 10 ms si cade a 950 px/s, y attesa 589,5: %s" % [s.y])
	s = b.sample("a", 1050 + b.delay_ms) # ora del server 1030
	runner.check(s.y == 600.0, "toccato il suolo si resta lì: %s" % [s.y])


# Rallentatore solo grafico (#470 passo 2b): il ritardo in più disegna il passato, anche per il proprio lottatore
func test_ritardo_in_piu() -> void:
	var b := SnapshotBuffer.new()
	b.own_id = "a"
	b.push(1000, 1020, _players(0))
	b.push(1100, 1120, _players(100))
	b.push(1200, 1220, _players(200))
	var now := 1170.0 + b.delay_ms
	runner.check(float(b.sample("a", now).x) >= 200.0, "senza ritardo il mio lottatore segue l'ultimo snapshot (o va avanti)")
	b.extra_delay_ms = 100.0
	runner.check(absf(float(b.sample("a", now).x) - 50.0) < 0.01, "con 100 ms in più si vede a metà tra i primi due: %s" % [b.sample("a", now).x])
	runner.check(b.reached(1100, now) and not b.reached(1200, now), "gli eventi aspettano che il disegno arrivi al loro istante")
	b.extra_delay_ms = 0.0
	runner.check(b.reached(1200, 1220), "senza ritardo un evento appena arrivato parte subito")


# Ritardo che si adatta alla rete: con gli snapshot puntuali resta delay_ms, con quelli a scatti sale (fino al tetto)
# e poi torna giù piano
func test_ritardo_si_adatta_alla_rete() -> void:
	var b := SnapshotBuffer.new()
	b.delay_ms = 50.0
	b.max_delay_ms = 120.0
	var t := 1000.0
	for i in 120: # 2 s puntuali a 60 snapshot al secondo
		t += 16.0
		b.push(t, t + 20.0, _players(i))
	runner.check(b.current_delay() == 50.0, "rete puntuale: resta delay_ms, avuto %s" % b.current_delay())
	for i in 120: # 2 s con uno snapshot su due in ritardo di 60 ms
		t += 16.0
		b.push(t, t + 20.0 + (60.0 if i % 2 == 0 else 0.0), _players(i))
	var high := b.current_delay()
	runner.check(high > 70.0 and high <= 120.0, "rete a scatti: il ritardo sale, avuto %s" % high)
	for i in 600: # 10 s di nuovo puntuali
		t += 16.0
		b.push(t, t + 20.0, _players(i))
	runner.check(b.current_delay() < high, "rete di nuovo puntuale: il ritardo torna giù, avuto %s" % b.current_delay())
	var s: Variant = b.sample("a", t + 20.0)
	runner.check(s != null, "si disegna sempre qualcosa")


func test_ritardo_fisso_senza_tetto() -> void:
	var b := SnapshotBuffer.new()
	var t := 1000.0
	for i in 60:
		t += 16.0
		b.push(t, t + 20.0 + (80.0 if i % 2 == 0 else 0.0), _players(i))
	runner.check(b.current_delay() == b.delay_ms, "con max_delay_ms a 0 il ritardo resta delay_ms")
