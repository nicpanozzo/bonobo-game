# Il riquadro della voce (voice_panel.gd): sta in alto a destra senza coprire l'HUD della partita
# (schede in basso, tempo in alto al centro), le scritte della sala né il tasto di pausa del telefono
extends RefCounted

var runner

const PATH := "user://test_voice_panel.cfg"
const DESKTOP := Vector2(1280, 720)
const PHONE := Vector2(853, 480) # Phone.PHONE_HEIGHT con lo schermo 16:9
const PHONE_LONG := Vector2(1040, 480) # telefono lungo (20:9)


func _no_overlap(a: Rect2, b: Rect2, what: String) -> void:
	runner.check(not a.intersects(b), "%s: %s tocca %s" % [what, a, b])


func _inside(r: Rect2, screen: Vector2, what: String) -> void:
	runner.check(Rect2(Vector2.ZERO, screen).encloses(r), "%s: %s esce dallo schermo %s" % [what, r, screen])


func test_partita_al_computer() -> void:
	# 8 giocatori in voce, compatto, sotto il contatore FPS
	var r := VoicePanel.layout_rect(DESKTOP, 8, 44.0, true, false, false)
	_inside(r, DESKTOP, "partita")
	# Le schede dei giocatori stanno nei 130 pixel in basso (hud.gd), il tempo al centro in alto
	_no_overlap(r, Rect2(0, DESKTOP.y - 140, DESKTOP.x, 140), "schede HUD")
	_no_overlap(r, Rect2(DESKTOP.x / 2 - 120, 0, 240, 90), "tempo")
	# Il contatore FPS in alto a destra (fps_counter.gd), alto meno di 40
	_no_overlap(r, Rect2(DESKTOP.x - 200, 0, 200, 40), "FPS")


func test_sala_al_computer() -> void:
	# Sotto la scheda "Si gioca" (hall_hud.gd: 300 di larghezza, in alto a destra) e lontano dalla stanza a sinistra
	var lead := Rect2(DESKTOP.x - 300 - 16, 16, 300, 120)
	var r := VoicePanel.layout_rect(DESKTOP, 8, lead.end.y + 12.0, false, true, false)
	_inside(r, DESKTOP, "sala")
	_no_overlap(r, lead, "Si gioca")
	_no_overlap(r, Rect2(16, 16, 290, 400), "stanza e giocatori")
	# La richiesta in basso al centro e la riga dei tasti
	_no_overlap(r, Rect2((DESKTOP.x - 640) / 2, DESKTOP.y - 100, 640, 100), "richiesta in basso")


func test_telefono() -> void:
	for screen: Vector2 in [PHONE, PHONE_LONG]:
		# Partita: sotto il tasto di pausa (touch_controls.gd: tondo in alto a destra, scalato 480/720)
		var k: float = screen.y / 720.0
		var pause_c: Vector2 = Vector2(1236 + (screen.x / k - 1280), 42) * k
		var pause := Rect2(pause_c - Vector2(30, 30) * k * 1.3, Vector2(60, 60) * k * 1.3)
		var r := VoicePanel.layout_rect(screen, 4, 64.0, true, false, true)
		_inside(r, screen, "telefono partita")
		_no_overlap(r, pause, "pausa")
		_no_overlap(r, Rect2(0, screen.y - 100, screen.x, 100), "schede e tasti a schermo")
		# Sala con 4 giocatori: sotto la scheda "Si gioca" del telefono (240 di larghezza)
		var lead := Rect2(screen.x - 240 - 12, 12, 240, 96)
		var h := VoicePanel.layout_rect(screen, 4, lead.end.y + 12.0, false, true, true)
		_inside(h, screen, "telefono sala")
		_no_overlap(h, lead, "Si gioca")
		_no_overlap(h, Rect2(12, 12, minf(240, screen.x * 0.36), 300), "stanza")


func test_otto_in_voce_non_coprono_niente() -> void:
	# Partita al computer: le schede in basso
	var r := VoicePanel.layout_rect(DESKTOP, 8, 44.0, true, false, false)
	runner.check(VoicePanel.fit_rows(8, DESKTOP.y, 44.0, true, false, false) == 8, "al computer ci stanno tutti")
	_no_overlap(r, Rect2(0, DESKTOP.y - 140, DESKTOP.x, 140), "schede HUD")
	for screen: Vector2 in [PHONE, PHONE_LONG]:
		# Telefono in partita: i tasti a schermo a destra (Speciale è il più alto, tondo a 1180,465 di 1280x720)
		var k: float = screen.y / 720.0
		var special := Rect2((Vector2(1180 + (screen.x / k - 1280), 465) - Vector2(48, 48)) * k, Vector2(96, 96) * k)
		var m := VoicePanel.layout_rect(screen, 8, 64.0, true, false, true)
		_inside(m, screen, "telefono partita, 8")
		_no_overlap(m, special, "tasto Speciale")
		runner.check(VoicePanel.fit_rows(8, screen.y, 64.0, true, false, true) >= 3, "almeno tre righe")
		# Telefono in sala: la richiesta in basso al centro (440 di larghezza)
		var h := VoicePanel.layout_rect(screen, 8, 120.0, false, true, true)
		_inside(h, screen, "telefono sala, 8")
		_no_overlap(h, Rect2((screen.x - 440) / 2, screen.y - 12 - 60, 440, 60), "richiesta")


func test_righe_che_non_ci_stanno() -> void:
	var rows := [
		{"id": "a", "me": false, "speaking": false}, {"id": "b", "me": false, "speaking": true},
		{"id": "m", "me": true, "speaking": false}, {"id": "c", "me": false, "speaking": false},
	]
	var shown := VoicePanel.pick_rows(rows, 2)
	runner.check(shown.size() == 2 and shown[0].id == "m" and shown[1].id == "b", "io e chi parla: %s" % [shown])
	runner.check(VoicePanel.pick_rows(rows, 4) == rows, "se ci stanno, nell'ordine di sempre")


func test_righe_alte_sul_telefono() -> void:
	runner.check(VoicePanel.row_height(false, true) >= 32.0, "si toccano col dito")
	var desk := VoicePanel.panel_size(3, false, true, false)
	var compact := VoicePanel.panel_size(3, true, false, false)
	runner.check(compact.y < desk.y, "in partita più basso: %s %s" % [compact, desk])
	runner.check(VoicePanel.panel_size(20, true, false, false) == VoicePanel.panel_size(VoicePanel.MAX_ROWS, true, false, false), "al massimo 8 righe")


func _panel(supported: bool) -> Array:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var s := Settings.new({"master": 0.8, "sfx": 0.7, "music": 0.35}, PATH)
	var v := VoiceChat.new()
	var fake: Object = load("res://tests/test_voice.gd").FakeBridge.new() if supported else null
	v.setup(s, fake)
	v.on_welcome("m")
	var p := VoicePanel.new()
	p.setup(v)
	return [v, p]


func test_righe_e_pulsanti() -> void:
	var vp := _panel(true)
	var v: VoiceChat = vp[0]
	var p: VoicePanel = vp[1]
	p.area = "match"
	runner.check(not p.wanted(), "in partita, nessuno in voce: nascosto")
	p.area = "hall"
	runner.check(p.wanted() and p._join.visible and not p._mic.visible, "in sala: Entra in voce")
	v.on_config({"iceServers": [], "states": [{"id": "a", "on": true, "muted": true, "deafened": false}]})
	v.join()
	v.on_bridge_event("joined", {"ok": true})
	runner.check(not p._join.visible and p._mic.visible and p._deaf.visible and p._leave.visible, "dentro: microfono, audio, esci")
	runner.check(p._rows.size() == 2 and p._rows[0].me and p._rows[1].muted, "io e A silenziato: %s" % [p._rows])
	p.area = "match"
	runner.check(p.wanted() and not p.has_bar(), "in partita: compatto, senza pulsanti")
	# Clic sulla riga di A: la sua riga è la seconda
	runner.check(p.row_at(VoicePanel.PAD + VoicePanel.HEADER_H + VoicePanel.ROW_H_COMPACT * 1.5) == 1, "riga di A")
	runner.check(p.row_at(2.0) == -1, "l'intestazione non è una riga")
	p.free()
	v.free()


func test_fuori_dal_browser() -> void:
	var vp := _panel(false)
	var v: VoiceChat = vp[0]
	var p: VoicePanel = vp[1]
	p.area = "hall"
	runner.check(p.wanted() and p._join.disabled, "in sala si vede, spento")
	p.area = "match"
	runner.check(not p.wanted(), "in partita non ingombra")
	p.free()
	v.free()


func test_nomi_lunghi() -> void:
	var f := UI.font(UI.WEIGHT_BOLD)
	var t := VoicePanel.fit_text(f, "Un nome lunghissimo davvero tanto", 14, 80.0)
	runner.check(t.ends_with("...") and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 80.0, t)
	runner.check(VoicePanel.fit_text(f, "Nico", 14, 80.0) == "Nico", "corto resta")
