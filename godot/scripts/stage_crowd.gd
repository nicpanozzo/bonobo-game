# Il pubblico dell'arena (#433): i turisti di Bologna che fotografano la zuffa. A ogni KO scattano i flash da tanti punti
# (finestre, portici, la base delle torri), ai colpi che fanno tremare lo schermo un paio, come il pubblico degli stadi di
# Smash che reagisce a quello che succede. Solo grafica, dagli eventi dello snapshot: i punti sono art.life.crowd.
# world_view.gd lo chiama in on_event e dentro _draw.
extends RefCounted

const FLASH_MS := 260.0 # quanto dura un flash
const KO_FLASHES := 7 # flash per un KO...
const HIT_FLASHES := 2 # ...e per un colpo forte
const SPREAD_MS := 700.0 # i flash di un KO arrivano sparsi in tanto, non tutti insieme
const MAX_FLASHES := 24 # oltre, i più vecchi si scartano

var spots: Array = [] # Vector2 nel mondo da cui si scatta
var _flashes: Array = [] # {at: Vector2, start: ms dell'orologio del client}
var _rng := RandomNumberGenerator.new()


func setup(spec: Dictionary) -> void:
	spots = []
	_flashes = []
	var art: Variant = spec.get("art")
	var life: Variant = art.get("life") if art is Dictionary else null
	var crowd: Variant = life.get("crowd") if life is Dictionary else null
	if crowd is Dictionary and crowd.get("flashes") is Array:
		for p in crowd.flashes:
			spots.append(Vector2(float(p.x), float(p.y)))


func is_empty() -> bool:
	return spots.is_empty()


# count flash da punti a caso, sparsi nei prossimi SPREAD_MS (il primo subito)
func flash(count: int, now: float) -> void:
	if spots.is_empty():
		return
	for k in count:
		var delay := 0.0 if k == 0 else _rng.randf() * SPREAD_MS
		_flashes.append({"at": spots[_rng.randi() % spots.size()], "start": now + delay})
	while _flashes.size() > MAX_FLASHES:
		_flashes.pop_front()


# Un flash: il bagliore tondo e la stella a quattro punte che si spegne in FLASH_MS
func draw(ci: CanvasItem, now: float) -> void:
	var keep := []
	for f in _flashes:
		var age := now - float(f.start)
		if age > FLASH_MS:
			continue
		keep.append(f)
		if age < 0.0:
			continue
		var k := 1.0 - age / FLASH_MS
		var at: Vector2 = f.at
		ci.draw_circle(at, 26.0 * k + 6.0, Color(1, 1, 0.92, 0.25 * k))
		for dir: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
			ci.draw_line(at - dir * 22.0 * k, at + dir * 22.0 * k, Color(1, 1, 1, 0.9 * k), 2.0)
		ci.draw_circle(at, 4.0 * k + 1.0, Color(1, 1, 1, k))
	_flashes = keep


# Quanti flash ha un evento: un KO molti, un colpo che fa tremare lo schermo pochi, il resto nessuno
static func flashes_for(e: Dictionary, shake_from_knockback: float) -> int:
	match str(e.get("type", "")):
		"ko":
			return KO_FLASHES
		"hit":
			return HIT_FLASHES if float(e.get("knockback", 0)) > shake_from_knockback else 0
	return 0
