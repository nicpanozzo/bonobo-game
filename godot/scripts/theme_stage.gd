# Le arene a tema (La Fabbrica, Le Isole, Il Palco): ognuna ha uno script suo che la disegna viva, nello stile di Sala
# Prove (wonder_stage.gd), tutto col codice e tutto dal tempo dell'arena. Questo script sceglie quello giusto dall'id
# dell'arena e passa le chiamate di world_view.gd e audio.gd. Le funzioni draw_* che tornano bool dicono se il pezzo
# l'ha disegnato il tema (true) o se world_view.gd deve fare il disegno di sempre (false).
# Solo grafica e suoni: le regole delle arene stanno in src/shared/physics/.
extends RefCounted

const SCRIPTS := {
	"fabbrica": preload("res://scripts/factory_stage.gd"),
}

var current: RefCounted = null


func setup(spec: Dictionary, game: Dictionary) -> void:
	var script: Variant = SCRIPTS.get(str(spec.get("id", "")))
	current = (script as GDScript).new() if script != null else null
	if current != null:
		current.setup(spec, game)


func active() -> bool:
	return current != null


func draw_back(c: CanvasItem, t: float, view: Rect2, pressed: Array, now_ms: float) -> void:
	if current != null:
		current.draw_back(c, t, view, pressed, now_ms)


func draw_solid(c: CanvasItem, s: Dictionary, t: float, pressed: Array) -> bool:
	return current != null and current.draw_solid(c, s, t, pressed)


func draw_platform(c: CanvasItem, p: Dictionary, t: float) -> bool:
	return current != null and current.draw_platform(c, p, t)


func draw_mover(c: CanvasItem, m: Dictionary, pos: Vector2, t: float) -> bool:
	return current != null and current.draw_mover(c, m, pos, t)


func draw_hazard(c: CanvasItem, h: Dictionary, r: Rect2, on: bool, t: float) -> bool:
	return current != null and current.draw_hazard(c, h, r, on, t)


func draw_pad(c: CanvasItem, p: Dictionary, pressed_at: Variant, t: float) -> bool:
	return current != null and current.draw_pad(c, p, pressed_at, t)


func draw_over_fighters(c: CanvasItem, players: Dictionary, now_ms: float) -> void:
	if current != null and current.has_method("draw_over_fighters"):
		current.draw_over_fighters(c, players, now_ms)


func draw_front(c: CanvasItem, t: float, view: Rect2, pressed: Array) -> void:
	if current != null:
		current.draw_front(c, t, view, pressed)


func on_event(e: Dictionary, now_ms: float) -> void:
	if current != null:
		current.on_event(e, now_ms)


# I suoni dell'arena che non hanno un evento (la sirena, le presse): [[nome del suono, x], ...] passati tra before e now
func cues(before: float, now: float, pressed: Array) -> Array:
	if current == null or before < 0.0 or now <= before:
		return []
	return current.cues(before, now, pressed)
