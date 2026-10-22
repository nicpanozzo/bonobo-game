# Avviso e disegno delle trappole a ciclo (#433), solo grafica. `warnMs` di una trappola con periodMs/activeMs: negli
# ultimi warnMs prima di ogni finestra accesa non fa male (la fisica è quella di hazardActive, invariata) ma si vede
# un avviso. Il fulmine ("fulmine") ha l'avviso suo: una linea tratteggiata dal cielo e il bersaglio che si accende.
extends RefCounted

const SKY_PX := 1400.0 # da quanto in alto sopra il bersaglio parte il fulmine
const DASH_PX := 16.0 # un tratto della linea tratteggiata
const DASH_STEP_PX := 30.0 # da un tratto al successivo
const BOLT_STEP_PX := 70.0 # lunghezza di un pezzo del fulmine a zig-zag
const BOLT_JITTER_PX := 34.0 # quanto sbanda un pezzo
const FLASH_MS := 90.0 # il lampo sullo schermo all'inizio del colpo
const BOLT_FRAME_MS := 50.0 # il fulmine cambia forma ogni tanto: sfarfalla


# Quanto è avanti l'avviso prima della prossima finestra accesa (0 a inizio, 1 un attimo prima di accendersi);
# -1 se la trappola non ha avviso, è accesa o la finestra è ancora lontana
static func warn_progress(h: Dictionary, t: float) -> float:
	var period: float = h.get("periodMs", 0)
	var warn: float = h.get("warnMs", 0)
	if period <= 0.0 or warn <= 0.0:
		return -1.0
	var phase := fposmod(t + float(h.get("offsetMs", 0)), period)
	if phase < float(h.get("activeMs", period / 2.0)):
		return -1.0
	var until := period - phase
	return 1.0 - until / warn if until <= warn else -1.0


# L'avviso: per il fulmine la linea dal cielo e il bersaglio che brilla, per le altre il rettangolo che lampeggia
static func draw_warning(ci: CanvasItem, h: Dictionary, r: Rect2, k: float, t: float, view: Rect2) -> void:
	if h.get("kind", "") == "fulmine":
		var flick := 1.0 if fposmod(t, 140.0 - 70.0 * k) < 80.0 else 0.25
		var cx := r.get_center().x
		var top := maxf(r.position.y - SKY_PX, view.position.y)
		var y := r.position.y
		while y > top:
			ci.draw_line(Vector2(cx, y), Vector2(cx, maxf(top, y - DASH_PX)), Color(0.85, 0.92, 1.0, (0.2 + 0.5 * k) * flick), 2.0 + 2.0 * k)
			y -= DASH_STEP_PX
		ci.draw_rect(r, Color(1.0, 0.95, 0.6, (0.08 + 0.3 * k) * flick))
		ci.draw_circle(r.get_center(), 40.0 + 70.0 * k, Color(0.85, 0.92, 1.0, 0.18 * k * flick))
	else:
		var blink := fposmod(t, 260.0 - 140.0 * k) < 130.0
		ci.draw_rect(r, Color(1.0, 0.2, 0.2, (0.15 + 0.3 * k) if blink else 0.05))


# Il colpo del fulmine: una saetta a zig-zag dal cielo al bersaglio, con un lampo sullo schermo all'inizio.
# age è da quanto è acceso (ms); calm = opzione "meno lampi"
static func draw_lightning(ci: CanvasItem, r: Rect2, t: float, age: float, view: Rect2, calm: bool) -> void:
	var cx := r.get_center().x
	var top := maxf(r.position.y - SKY_PX, view.position.y - 40.0)
	var bottom := r.end.y
	var frame := int(t / BOLT_FRAME_MS)
	var pts := PackedVector2Array()
	var y := top
	var i := 0
	while y < bottom:
		var left := (bottom - y) / (bottom - top) # sbanda meno man mano che arriva al bersaglio
		pts.append(Vector2(cx + (fposmod(sin(float(frame * 31 + i * 17)) * 9301.0, 1.0) - 0.5) * 2.0 * BOLT_JITTER_PX * left, y))
		y += BOLT_STEP_PX
		i += 1
	pts.append(Vector2(cx, bottom))
	ci.draw_circle(r.get_center(), 90.0, Color(0.85, 0.92, 1.0, 0.25))
	ci.draw_polyline(pts, Color(0.7, 0.8, 1.0, 0.3), 16.0)
	ci.draw_polyline(pts, Color(1.0, 1.0, 0.9), 5.0)
	if age < FLASH_MS and not calm:
		ci.draw_rect(view.grow(40.0), Color(1, 1, 1, 0.35 * (1.0 - age / FLASH_MS)))
