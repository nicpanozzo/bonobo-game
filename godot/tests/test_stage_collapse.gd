# La torre che crolla e l'avviso delle trappole a ciclo (#433): solo calcoli sul tempo dell'arena
extends RefCounted

var runner

const Collapse := preload("res://scripts/stage_collapse.gd")
const HazardFx := preload("res://scripts/hazard_fx.gd")

const C := {"atMs": 150000, "durationMs": 4000, "pivot": {"x": 830, "y": 1940}, "height": 780, "width": 260, "toDeg": 62, "warnMs": 6000}
const BOLT := {"kind": "fulmine", "x": 1450, "y": 820, "width": 120, "height": 160, "periodMs": 20000, "activeMs": 500, "offsetMs": 10000, "warnMs": 1200}


func test_fasi_del_crollo() -> void:
	runner.check(Collapse.phase(C, 100000.0) == "idle", "lontano: niente")
	runner.check(Collapse.phase(C, 144500.0) == "warn", "negli ultimi 6 s: avviso")
	runner.check(Collapse.phase(C, 150000.0) == "fall", "a 2:30 cade")
	runner.check(Collapse.phase(C, 154000.0) == "after", "a 2:34 è a terra")
	runner.check(Collapse.phase(C, 170000.0) == "idle", "poi la polvere è finita")
	runner.check(Collapse.config({}).is_empty() and Collapse.config({"art": {"collapse": C}}) == C, "la descrizione viene da art.collapse")


func test_torre_in_piedi_da_standfromms() -> void:
	var s := C.duplicate()
	s["standFromMs"] = 30000
	runner.check(Collapse.phase(s, 29999.0) == "idle", "prima di standFromMs: niente")
	runner.check(Collapse.phase(s, 30000.0) == "stand", "da standFromMs è in piedi")
	runner.check(Collapse.phase(s, 143999.0) == "stand", "fino all'avviso resta in piedi")
	runner.check(Collapse.phase(s, 144000.0) == "warn", "poi l'avviso")
	runner.check(is_equal_approx(Collapse.angle_deg(s, 100000.0), 0.0) and Collapse.shake(s, 100000.0) == 0.0, "in piedi: dritta e senza scossa")
	runner.check(Collapse.phase(C, 100000.0) == "idle", "senza standFromMs resta com'era")


func test_angolo_con_partenza_lenta_e_arrivo_veloce() -> void:
	runner.check(is_equal_approx(Collapse.angle_deg(C, 140000.0), 0.0), "prima dell'avviso è dritta")
	runner.check(absf(Collapse.angle_deg(C, 147000.0)) <= Collapse.WOBBLE_DEG, "nell'avviso trema poco")
	runner.check(is_equal_approx(Collapse.angle_deg(C, 150000.0), 0.0), "alla partenza è dritta")
	var a1 := Collapse.angle_deg(C, 151000.0)
	var a2 := Collapse.angle_deg(C, 152000.0)
	var a3 := Collapse.angle_deg(C, 153000.0)
	var a4 := Collapse.angle_deg(C, 154000.0)
	runner.check(a1 < a2 and a2 < a3 and a3 < a4, "l'angolo cresce")
	runner.check((a2 - a1) < (a4 - a3), "ease-in: l'ultimo secondo gira più del primo (%s contro %s)" % [a4 - a3, a2 - a1])
	runner.check(is_equal_approx(a4, 62.0), "arriva a toDeg")
	runner.check(is_equal_approx(Collapse.angle_deg(C, 200000.0), 62.0), "e ci resta")


func test_cima_e_scossa() -> void:
	var p := Vector2(830, 1940)
	runner.check(Collapse.tip(C, 100000.0).distance_to(p + Vector2(-130, -780)) < 0.01, "in piedi la cima è sopra il piede")
	var end_tip := Collapse.tip(C, 154000.0)
	runner.check(end_tip.x > 1300 and end_tip.x < 1700, "a fine caduta la cima è sull'Asinelli (x %s)" % end_tip.x)
	runner.check(Collapse.shake(C, 100000.0) == 0.0, "da lontano niente scossa")
	runner.check(Collapse.shake(C, 154100.0) > Collapse.shake(C, 152000.0), "l'impatto scuote più della caduta")
	runner.check(Collapse.shake(C, 158000.0) == 0.0, "poi si ferma")


func test_avviso_delle_trappole_a_ciclo() -> void:
	# la finestra accesa comincia a 10000 + 20000 n
	runner.check(HazardFx.warn_progress(BOLT, 5000.0) < 0.0, "lontano: nessun avviso")
	runner.check(HazardFx.warn_progress(BOLT, 8700.0) < 0.0, "appena prima della finestra d'avviso")
	runner.check(is_equal_approx(HazardFx.warn_progress(BOLT, 8800.0), 0.0), "l'avviso comincia 1200 ms prima")
	runner.check(is_equal_approx(HazardFx.warn_progress(BOLT, 9400.0), 0.5), "a metà")
	runner.check(HazardFx.warn_progress(BOLT, 9999.0) > 0.99, "un attimo prima di accendersi")
	runner.check(HazardFx.warn_progress(BOLT, 10000.0) < 0.0, "acceso: niente avviso")
	runner.check(HazardFx.warn_progress(BOLT, 10499.0) < 0.0, "ancora acceso")
	runner.check(HazardFx.warn_progress(BOLT, 28900.0) >= 0.0, "il giro dopo")
	var plain := BOLT.duplicate()
	plain.erase("warnMs")
	runner.check(HazardFx.warn_progress(plain, 9400.0) < 0.0, "senza warnMs niente avviso")
	runner.check(HazardFx.warn_progress({"periodMs": 0, "warnMs": 500}, 100.0) < 0.0, "senza ciclo niente avviso")
