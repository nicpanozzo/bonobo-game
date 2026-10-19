# Inquadratura della telecamera nelle arene (main.gd, framing), anche più larghe dello schermo (#240)
extends RefCounted

var runner

const Main := preload("res://scripts/main.gd")

const GAME := {"world": {"width": 1280, "height": 720}, "fighter": {"width": 44, "height": 88}}
const CAM := {"margin": 140, "minZoom": 0.7, "maxZoom": 1.3}
const BLAST := {"left": -250, "right": 1530, "top": -350, "bottom": 920}
const WIDE_BLAST := {"left": -300, "right": 2220, "top": -420, "bottom": 1000}


func test_arena_normale_come_prima() -> void:
	var a := Main.framing({"blastZone": BLAST}, CAM, GAME, [])
	runner.check(is_equal_approx(a.zoom, 1.0) and a.center == Vector2(640, 360), "senza lottatori: tutta l'arena, zoom 1")
	var near := Main.framing({"blastZone": BLAST}, CAM, GAME, [Vector2(600, 560), Vector2(680, 560)])
	runner.check(is_equal_approx(near.zoom, 1.3), "lottatori vicini: zoom massimo (%s)" % near.zoom)
	var far := Main.framing({"blastZone": BLAST}, CAM, GAME, [Vector2(250, 560), Vector2(1030, 560)])
	runner.check(far.zoom < 1.3 and far.zoom >= 0.7, "lontani: si allontana senza scendere sotto minZoom (%s)" % far.zoom)


func test_arena_larga_con_il_suo_zoom() -> void:
	var wide := {"width": 1920, "camera": {"minZoom": 0.6}, "blastZone": WIDE_BLAST}
	var spread := [Vector2(150, 520), Vector2(1770, 520)]
	var a := Main.framing(wide, CAM, GAME, spread)
	runner.check(a.zoom < 0.7 and a.zoom >= 0.6, "ai due capi si allontana oltre lo zoom delle arene normali (%s)" % a.zoom)
	runner.check(1280.0 / a.zoom >= 1770.0 - 150.0, "e li vede tutti e due")
	var plain := Main.framing({"width": 1920, "blastZone": WIDE_BLAST}, CAM, GAME, spread)
	runner.check(is_equal_approx(plain.zoom, 0.7), "senza camera vale CAMERA.minZoom (%s)" % plain.zoom)
	var empty := Main.framing(wide, CAM, GAME, [])
	runner.check(empty.center.x == 960.0 and empty.zoom < 0.7, "senza lottatori: il centro dell'arena larga, tutta in vista")
	runner.check(empty.limits == Rect2(-300, -420, 2520, 1420), "la vista resta nelle zone di espulsione")


# Telefono lungo (Phone): si vede più mondo in larghezza, quindi la telecamera può stare più vicina
func test_schermo_piu_largo_sul_telefono() -> void:
	var spread := [Vector2(250, 560), Vector2(1030, 560)]
	var normal := Main.framing({"blastZone": BLAST}, CAM, GAME, spread)
	var wide := Main.framing({"blastZone": BLAST}, CAM, GAME, spread, Vector2(1560, 720))
	runner.check(wide.zoom >= normal.zoom, "zoom %f contro %f" % [wide.zoom, normal.zoom])


# Il pavimento sempre in vista (#400): chi sale in cima da solo non porta la telecamera lontano dalla piazza
func test_pavimento_sempre_in_vista() -> void:
	var stage := {"width": 1920, "camera": {"minZoom": 0.6, "floorY": 600}, "blastZone": WIDE_BLAST}
	var top := [Vector2(960, 125)]
	var a := Main.framing(stage, CAM, GAME, top)
	var bottom: float = a.center.y + 720.0 / a.zoom / 2.0
	runner.check(bottom >= 600.0, "il pavimento a 600 resta inquadrato: fondo a %s" % bottom)
	runner.check(a.center.y - 720.0 / a.zoom / 2.0 <= 125.0 - 88.0, "e chi sta in cima pure")
	var plain := Main.framing({"width": 1920, "camera": {"minZoom": 0.6}, "blastZone": WIDE_BLAST}, CAM, GAME, top)
	runner.check(plain.center.y < a.center.y, "senza floorY la telecamera sale di più")
	var ground := [Vector2(700, 520), Vector2(1100, 520)]
	runner.check(Main.framing(stage, CAM, GAME, ground) == Main.framing({"width": 1920, "camera": {"minZoom": 0.6}, "blastZone": WIDE_BLAST}, CAM, GAME, ground), "chi sta in piazza non cambia niente")

