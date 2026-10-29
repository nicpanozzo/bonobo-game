# Scritte della sala d'attesa: conto alla rovescia, cosa manca per partire, lista dei giocatori, tasti
extends RefCounted

var runner

const Hud := preload("res://scripts/hall_hud.gd")
const Fake := preload("res://tests/hall_fake.gd")


func test_numeri_del_conto() -> void:
	runner.check(Hud.count_text(-1.0) == "", "senza conto niente numero")
	runner.check(Hud.count_text(5000.0) == "5", "si parte da 5")
	runner.check(Hud.count_text(4001.0) == "5", "fino a 4 secondi pieni resta 5")
	runner.check(Hud.count_text(1200.0) == "2", "poi 2")
	runner.check(Hud.count_text(0.0) == "1", "mai 0")


func test_cosa_manca() -> void:
	runner.check(Hud.need_text("Serve un altro lottatore", false) == "Serve un altro lottatore", "il testo del server")
	runner.check(Hud.need_text(null, false).contains("cerchio"), "senza richieste: l'invito al cerchio")
	runner.check(Hud.need_text("x", true) == "", "durante il conto niente richieste")


func test_regole_della_stanza() -> void:
	runner.check(Hud.rules_text({"stocks": 3, "timeLimitSec": 240, "itemAmount": 2, "itemKinds": ["banana"]}, "ffa") == "3 vite · 4 min · oggetti", "vite, tempo, oggetti")
	runner.check(Hud.rules_text({"stocks": 1, "timeLimitSec": 0, "itemAmount": 0}, "teams") == "1 vita · senza tempo · senza oggetti", "una vita senza niente")
	runner.check(Hud.rules_text({"stocks": 3, "timeLimitSec": 90, "itemAmount": 0}, "race") == "1:30 · senza oggetti", "nella corsa le vite non contano")
	runner.check(Hud.rules_text({"stocks": 5, "timeLimitSec": 0, "itemAmount": 0}, "flag").begins_with("5 punti"), "in bandiera sono punti")
	runner.check(Hud.rules_text({}, "ffa") == "", "senza regole niente riga")


func test_tasti_di_base() -> void:
	var hint := Hud.controls_hint(null)
	runner.check(hint.contains("J spingi") and hint.contains("K cambia colore") and hint.contains("T inchino"), hint)
	runner.check(hint.contains("Spazio"), "il salto: %s" % hint)


func test_lista_e_conto_sullo_schermo() -> void:
	var h: Control = Hud.new()
	runner.root.add_child(h)
	h.size = Vector2(1280, 720)
	h.setup(JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json")))
	h.my_id = "p0"
	h.room_code = "abc"
	var snap := Fake.party(0.0)
	h.on_snapshot(snap)
	runner.check(h._list.get_child_count() == snap.players.size(), "una riga per giocatore")
	runner.check(h._need.text.contains("mancano"), "la richiesta del server: %s" % h._need.text)
	runner.check(h._code.text == "ABC", "il codice della stanza")
	runner.check(h._lead_mode.text == "Tutti contro tutti" and h._lead_stage.text == "Il Palco", "cosa si gioca")
	var copied := []
	h.copy_link_requested.connect(func(): copied.append(true))
	h._copy.pressed.emit()
	runner.check(copied.size() == 1, "Copia link chiede a main.gd di copiare")
	h.on_snapshot(Fake.party(33.0, "conto"))
	h._process(0.016)
	runner.check(h._count.visible and h._count.text == "4", "il numero al centro: %s" % h._count.text)
	runner.check(not h._need_card.visible, "durante il conto niente richiesta")
	# niente sovrapposizioni a 1280x720: la lista, il riquadro della modalità e la richiesta in basso
	h.on_snapshot(snap)
	var list_r := Rect2(h._room_card.position, h._room_card.size)
	var lead_r := Rect2(h._lead_card.position, h._lead_card.size)
	var need_r := Rect2(h._need_card.position, h._need_card.size)
	runner.check(not list_r.intersects(lead_r) and not list_r.intersects(need_r) and not lead_r.intersects(need_r), "riquadri separati")
	h.free()
