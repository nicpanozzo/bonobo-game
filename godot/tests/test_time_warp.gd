# Rallentatore solo grafico (time_warp.gd, #470 passo 2b)
extends RefCounted

var runner

const TimeWarp := preload("res://scripts/time_warp.gd")
const FX := {"finishSlowFactor": 0.12, "finishSlowMs": 750, "finishFollowFactor": 0.3, "finishFollowMs": 1200, "finishZoom": 0.45,
	"gameSlowFactor": 0.25, "gameSlowMs": 1400, "gameZoom": 0.35, "warpCatchUp": 1.6, "warpMaxDelayMs": 2400}


# Avanza a passi da 16 ms fino a until (ms reali dall'inizio), restituisce lo stato finale
func _run(w: Dictionary, from: float, until: float) -> Dictionary:
	var extra := 0.0
	var now := from
	while now < until and not w.is_empty():
		now += 16.0
		var r := TimeWarp.step(w, extra, 16.0, now, FX)
		w = r.warp
		extra = r.extra
	return {"warp": w, "extra": extra, "now": now}


# Al 12% per 750 ms il disegno resta indietro di circa 660 ms, poi si segue chi vola via
func test_colpo_decisivo() -> void:
	var w := TimeWarp.finish(1000.0, Vector2(400, 500), "b", FX)
	var r := _run(w, 1000.0, 1750.0)
	runner.check(absf(float(r.extra) - 750.0 * 0.88) < 20.0, "indietro di circa 660 ms (%.0f)" % r.extra)
	runner.check(r.warp.phase == "follow" and r.warp.target == "b", "poi si segue chi vola via")


# Dopo tutto la scena si rimette in pari: il ritardo torna a zero e il rallentatore finisce
func test_si_rimette_in_pari() -> void:
	var w := TimeWarp.finish(0.0, Vector2.ZERO, "b", FX)
	var r := _run(w, 0.0, 20000.0)
	runner.check(r.warp.is_empty() and float(r.extra) == 0.0, "finito, ritardo a zero")
	runner.check(float(r.now) < 8000.0, "in pochi secondi (%.0f ms)" % r.now)


# Il ritardo non supera il massimo: il buffer non ha snapshot più vecchi
func test_tetto_del_ritardo() -> void:
	var w := TimeWarp.game(0.0, Vector2.ZERO, FX)
	w.until = 100000.0
	var r := _run(w, 0.0, 10000.0)
	runner.check(float(r.extra) <= 2400.0, "al massimo 2400 ms (%.0f)" % r.extra)


# Lo zoom entra in fretta, nel catch torna a 1 col ritardo; il negativo c'è solo nel colpo decisivo
func test_zoom_e_negativo() -> void:
	var w := TimeWarp.finish(0.0, Vector2.ZERO, "b", FX)
	runner.check(TimeWarp.zoom(w, 200.0) > 1.4, "zoom stretto subito (%.2f)" % TimeWarp.zoom(w, 200.0))
	runner.check(TimeWarp.negative(w, 300.0) == 1.0, "a metà tutta in negativo")
	runner.check(TimeWarp.negative(w, 740.0) < 0.2, "sfuma alla fine")
	runner.check(TimeWarp.negative(TimeWarp.game(0.0, Vector2.ZERO, FX), 300.0) == 0.0, "a GAME! niente negativo")
	runner.check(TimeWarp.zoom({}, 0.0) == 1.0, "senza rallentatore niente zoom")
	var c := TimeWarp.next_phase(TimeWarp.game(0.0, Vector2.ZERO, FX), 2000.0, 800.0, FX)
	runner.check(c.phase == "catch", "dopo GAME! ci si rimette in pari")
	var half := TimeWarp.step(c, 800.0, 400.0, 2400.0, FX)
	runner.check(TimeWarp.zoom(half.warp, 2400.0) < TimeWarp.zoom(c, 2000.0) and TimeWarp.zoom(half.warp, 2400.0) > 1.0, "lo zoom si apre mentre il ritardo cala")


# La scritta GAME!: entra grande, scatta al suo posto, resta, sparisce
func test_scritta_game() -> void:
	runner.check(TimeWarp.game_text_scale(0.0) > 2.0, "entra grande")
	runner.check(TimeWarp.game_text_scale(0.1) < 1.0, "scatta un po' sotto")
	runner.check(TimeWarp.game_text_scale(0.5) == 1.0, "poi resta")
	runner.check(TimeWarp.game_text_scale(1.0) == 0.0 and TimeWarp.game_text_scale(-0.1) == 0.0, "fuori dalla vita non c'è")


# La previsione del colpo decisivo (#470, correzione): casi controllati con la fisica vera del server sul Palco,
# con chi vola che si difende (tests: scratch di confronto, 880 lanci per arena)
func _phys() -> Dictionary:
	return {"gravity": 2300.0, "drag": 0.985, "dt": 0.9 / 60.0, "hitstun_ms": 0.0, "drift": 700.0, "air_friction": 1200.0,
		"max_fall": 950.0, "extra_ms": 0.0}


func _ko(x: float, angle_deg: float, kb: float) -> bool:
	var a := deg_to_rad(angle_deg)
	var phys := _phys()
	phys.hitstun_ms = kb * 0.35
	var zone := {"left": -250, "right": 1530, "top": -350, "bottom": 920}
	var solids := [{"x": 240, "y": 560, "width": 800, "height": 80}]
	var platforms := [{"x": 340, "width": 200, "y": 420}, {"x": 740, "width": 200, "y": 420}, {"x": 540, "width": 200, "y": 290}]
	return TimeWarp.predicts_ko(Vector2(x, 558), Vector2(cos(a) * kb, -sin(a) * kb), zone, solids, platforms, phys)


func test_previsione_del_colpo_decisivo() -> void:
	runner.check(_ko(1040, 30, 2600), "forte verso fuori dal bordo destro: esce")
	runner.check(_ko(240, 160, 2200), "forte verso fuori dal bordo sinistro: esce")
	runner.check(_ko(640, 90, 3000), "fortissimo verso l'alto: esce dal cielo")
	runner.check(not _ko(640, 30, 900), "colpo medio al centro: resta in gioco")
	runner.check(not _ko(640, 60, 1500), "forte ma al centro e in alto: resta in gioco")
	runner.check(not _ko(320, 10, 1200), "radente sul palco: resta in gioco")
	runner.check(not _ko(640, -80, 2600), "verso il basso al centro: sbatte sul palco")
