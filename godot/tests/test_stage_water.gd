# Il disegno dell'acqua e del vento staccato da world_view.gd (#325): lo script si carica e world_view gli passa lo
# sfondo vivo, da cui prende i fogli dipinti dei getti
extends RefCounted

var runner

const StageWater := preload("res://scripts/stage_water.gd")


func test_world_view_usa_il_disegno_dell_acqua() -> void:
	var water: RefCounted = StageWater.new()
	for m in ["draw_jet", "draw_mover_stem", "draw_wheel_trunk", "draw_hub_foam"]:
		runner.check(water.has_method(m), "stage_water ha " + m)
	var view: Node2D = load("res://scripts/world_view.gd").new()
	runner.check(view.get("_water") != null, "world_view ha il disegno dell'acqua")
	view.free()
