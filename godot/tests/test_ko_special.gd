# KO stella e KO sullo schermo (ko_special.gd, #470 fase 4)
extends RefCounted

var runner

const KoSpecial := preload("res://scripts/ko_special.gd")
const FX := {"koStarChance": 0.3, "koScreenChance": 0.1, "koStarDelayMs": 150, "koStarTravelMs": 900, "koStarTwinkleMs": 520,
	"koScreenDelayMs": 300, "koScreenApproachMs": 220, "koScreenStickMs": 650, "koScreenSlideMs": 900}
const ZONE := {"left": -250, "right": 1530, "top": -350, "bottom": 920}
const VIEW := Rect2(0, 0, 1280, 720)


# Solo chi esce dall'alto, mai all'ultimo KO; lo stesso KO dà sempre lo stesso risultato
func test_quando_succede() -> void:
	var kinds := {"star": 0, "screen": 0, "": 0}
	var calm_screen := 0
	var calm_star := 0
	for i in 2000:
		var x := 100.0 + i % 900
		var k := KoSpecial.pick("p%d" % (i % 8), x, -351.0 - i % 40, i % 3, ZONE, false, false, FX)
		kinds[k] += 1
		var kc := KoSpecial.pick("p%d" % (i % 8), x, -351.0 - i % 40, i % 3, ZONE, false, true, FX)
		calm_screen += 1 if kc == "screen" else 0
		calm_star += 1 if kc == "star" else 0
	runner.check(kinds.star > 450 and kinds.star < 750, "circa 1 su 3 stella (%d su 2000)" % kinds.star)
	runner.check(kinds.screen > 120 and kinds.screen < 280, "circa 1 su 10 schermo (%d su 2000)" % kinds.screen)
	runner.check(calm_screen == 0 and calm_star == kinds.star, "con la modalità calma niente schermo, la stella resta")
	var a := KoSpecial.pick("p1", 640, -360, 2, ZONE, false, false, FX)
	runner.check(a == KoSpecial.pick("p1", 640, -360, 2, ZONE, false, false, FX), "lo stesso KO, lo stesso effetto per tutti")
	var top_any := false
	for i in 200:
		top_any = top_any or KoSpecial.pick("p%d" % i, 640, -360, 1, ZONE, true, false, FX) != ""
	runner.check(not top_any, "all'ultimo KO mai")
	var side_any := false
	for i in 200:
		side_any = side_any or KoSpecial.pick("p%d" % i, 1540, 300, 1, ZONE, false, false, FX) != "" or KoSpecial.pick("p%d" % i, 640, 930, 1, ZONE, false, false, FX) != ""
	runner.check(not side_any, "di lato e dal fondo mai")


# La stella: aspetta un attimo, vola nello sfondo rimpicciolendo dentro l'inquadratura, brilla, finisce
func test_stella() -> void:
	runner.check(KoSpecial.star_at(100, VIEW, 640, FX).is_empty(), "subito dopo il KO non c'è ancora")
	var a := KoSpecial.star_at(200, VIEW, 640, FX)
	var b := KoSpecial.star_at(900, VIEW, 640, FX)
	runner.check(float(b.scale) < float(a.scale) and VIEW.has_point(a.pos) and VIEW.has_point(b.pos), "si allontana rimpicciolendo, sempre in vista")
	runner.check(float(b.pos.y) > float(a.pos.y), "scende verso il fondo del cielo")
	var t := KoSpecial.star_at(150 + 900 + 130, VIEW, 640, FX)
	runner.check(t.has("twinkle") and float(t.twinkle) > 1.0, "poi brilla (%.2f)" % float(t.get("twinkle", 0)))
	runner.check(KoSpecial.star_at(KoSpecial.duration("star", FX), VIEW, 640, FX).is_empty(), "e finisce")
	var edge := KoSpecial.star_at(200, VIEW, 5000, FX)
	runner.check(VIEW.has_point(edge.pos), "uscito lontano di lato, la stella resta nell'inquadratura")


# Lo schermo: arriva enorme, sbatte (lampo e mani sul vetro), resta, scivola giù fuori dallo schermo
func test_schermo() -> void:
	runner.check(KoSpecial.screen_at(200, VIEW, FX).is_empty(), "prima aspetta")
	var near := KoSpecial.screen_at(300 + 100, VIEW, FX)
	var hit := KoSpecial.screen_at(300 + 230, VIEW, FX)
	runner.check(float(near.scale) < float(hit.scale) and not near.hands, "arriva crescendo")
	runner.check(hit.hands and float(hit.flash) > 0.5 and float(hit.sx) > 1.0, "sbatte: lampo, mani sul vetro, schiacciato")
	var stuck := KoSpecial.screen_at(300 + 220 + 500, VIEW, FX)
	runner.check(stuck.pos == hit.pos and float(stuck.flash) == 0.0, "resta lì")
	var late := KoSpecial.screen_at(KoSpecial.duration("screen", FX) - 10, VIEW, FX)
	runner.check(float(late.pos.y) - float(late.scale) * VIEW.size.y / 2.0 > VIEW.end.y * 0.9, "alla fine è scivolato fuori")
	runner.check(KoSpecial.screen_at(KoSpecial.duration("screen", FX), VIEW, FX).is_empty(), "e finisce")


func test_stellina_a_quattro_punte() -> void:
	var pts := KoSpecial.sparkle_points(Vector2(10, 10), 20.0, 0.0)
	runner.check(pts.size() == 8 and pts[0].is_equal_approx(Vector2(10, -10)), "otto punti, la prima punta in alto")
