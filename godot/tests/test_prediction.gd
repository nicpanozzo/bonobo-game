# Predizione del proprio lottatore (E17)
extends RefCounted

var runner
const Main := preload("res://scripts/main.gd")


func test_numero_dell_input_e_il_tick_locale() -> void:
	runner.check(Main.local_tick(1000, 60.0) == 60, "1 s a 60 tick/s: 60, avuto %s" % Main.local_tick(1000, 60.0))
	runner.check(Main.local_tick(1016, 60.0) == 60 and Main.local_tick(1017, 60.0) == 61, "si passa al tick dopo a 1016,7 ms")
