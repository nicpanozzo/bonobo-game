# Fumo della canna (#196): sbuffi morbidi che escono dalla brace, salgono rallentando, si allargano,
# ondeggiano con un filo d'aria e svaniscono. È un effetto, non un disegno: resta uguale quando cambiano i pezzi.
# Si appende all'osso della canna; gli sbuffi già usciti restano dove sono (nel mondo) e non seguono la testa.
extends Node2D

const SPAWN_EVERY := 0.07 # secondi tra uno sbuffo e l'altro
const LIFE := 2.2 # secondi di vita di uno sbuffo
const RISE := 46.0 # pixel/s verso l'alto all'uscita
const DRAG := 0.9 # quanto rallenta salendo (per secondo)
const GROW := 13.0 # pixel di raggio guadagnati al secondo
const START_RADIUS := 2.5
const SWAY := 9.0 # pixel di ondeggiamento
const WIND := 6.0 # pixel/s di deriva all'indietro
const BLOB := 64 # lato della texture morbida

var tip := Vector2.ZERO # punta della canna nello spazio dell'osso
var direction := 1.0 # 1 se il lottatore guarda a destra, -1 a sinistra: il vento va all'indietro
var manual := false # per la registrazione: step() lo chiama la scena con un passo fisso
var _puffs: Array = [] # [{ pos, vel, age, seed }]
var _clock := 0.0
var _spawn := 0.0
var _tex: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true # gli sbuffi vivono nel mondo, non ruotano con la testa
	z_as_relative = false
	z_index = 200
	_rng.seed = 7
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = BLOB
	t.height = BLOB
	_tex = t


func _process(delta: float) -> void:
	if not manual:
		step(delta)


# Un passo del tempo (secondi). Le misure seguono la scala della figura sullo schermo
func step(dt: float) -> void:
	var emitter := get_parent() as Node2D
	var k := global_scale_hint()
	direction = signf(emitter.global_transform.x.x) if emitter.global_transform.x.x != 0 else 1.0
	_clock += dt
	_spawn -= dt
	var origin := emitter.to_global(tip)
	while _spawn <= 0.0:
		_spawn += SPAWN_EVERY
		_puffs.append({
			"pos": origin,
			"vel": Vector2(_rng.randf_range(-4, 4), -RISE * _rng.randf_range(0.8, 1.2)) * k,
			"age": 0.0,
			"seed": _rng.randf() * TAU,
		})
	for p in _puffs:
		p.age += dt
		p.vel *= exp(-DRAG * dt)
		p.pos += (p.vel + Vector2(-direction * WIND * k, 0)) * dt
	_puffs = _puffs.filter(func(p): return p.age < LIFE)
	queue_redraw()


func _draw() -> void:
	for p in _puffs:
		var k: float = p.age / LIFE
		var r: float = (START_RADIUS + GROW * p.age) * global_scale_hint()
		var sway: float = sin(_clock * 2.3 + p.seed) * SWAY * k * global_scale_hint()
		var alpha: float = (1.0 - k) * (1.0 - k) * minf(1.0, p.age * 8.0) * 0.55
		var c := Color(0.86, 0.85, 0.82, alpha).lerp(Color(0.7, 0.72, 0.74, alpha), k) # da bianco caldo a grigio
		var at: Vector2 = p.pos + Vector2(sway, 0)
		draw_texture_rect(_tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


# Gli sbuffi crescono in pixel dello schermo come il resto della figura
func global_scale_hint() -> float:
	var parent := get_parent() as Node2D
	return absf(parent.global_transform.get_scale().y) if parent != null else 1.0
