# Scia dei colpi e linee di velocità (strike_fx.gd, #384 B2)
extends RefCounted

var runner

const StrikeFx := preload("res://scripts/strike_fx.gd")


# La scia passa sulla zona del colpo e gira dal davanti, da tutte e due le parti
func test_scia_sulla_zona_del_colpo() -> void:
	var chest := Vector2(500, 460)
	for facing in [1, -1]:
		var box := Rect2(522, 440, 52, 30) if facing == 1 else Rect2(426, 440, 52, 30)
		var arc := StrikeFx.arc_for(chest, facing, box)
		var poly := StrikeFx.crescent(arc, 1.0, 14.0)
		runner.check(poly.size() > 6, "una mezzaluna (%d punti)" % poly.size())
		var inside := 0
		for pt in poly:
			if box.grow(4).has_point(pt):
				inside += 1
		runner.check(inside > 0, "la scia passa sulla zona del colpo (facing %d)" % facing)
		var ahead := 0
		for pt in poly:
			if signf(pt.x - chest.x) == facing:
				ahead += 1
		runner.check(ahead >= poly.size() * 0.8, "la scia sta davanti (facing %d, %d su %d)" % [facing, ahead, poly.size()])
		runner.check(absf(float(arc.a1) - float(arc.a0)) < PI, "arco corto, non il giro lungo")


func test_la_scia_cresce_col_colpo() -> void:
	var arc := StrikeFx.arc_for(Vector2(500, 460), 1, Rect2(522, 440, 52, 30))
	runner.check(StrikeFx.crescent(arc, 0.0, 14.0).is_empty(), "all'inizio niente")
	var half := StrikeFx.crescent(arc, 0.5, 14.0)
	var full := StrikeFx.crescent(arc, 1.0, 14.0)
	runner.check(half[half.size() / 2 - 1].distance_to(full[full.size() / 2 - 1]) > 1.0, "a metà la punta non è ancora in fondo")


func test_linee_di_velocita_dietro() -> void:
	var lines := StrikeFx.speed_lines(Vector2(500, 400), Vector2(1200, -300), 5, 70, 30, 7)
	runner.check(lines.size() == 5, "5 linee")
	for l in lines:
		runner.check(l[1].x < l[0].x and l[0].x < 500, "dietro a chi vola verso destra: %s" % [l])
	runner.check(StrikeFx.speed_lines(Vector2.ZERO, Vector2.ZERO, 5, 70, 30, 7).is_empty(), "fermo: niente linee")
