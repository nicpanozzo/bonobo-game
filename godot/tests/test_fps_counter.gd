# Contatore FPS (fps_counter.gd, #529): testo e colore dai fotogrammi contati nel mezzo secondo
extends RefCounted

var runner

const Counter := preload("res://scripts/fps_counter.gd")


func test_testo() -> void:
	runner.check(Counter.text_for(30, 0.5) == "60 FPS · 16.7 ms", "60 fps: %s" % Counter.text_for(30, 0.5))
	runner.check(Counter.text_for(15, 0.5) == "30 FPS · 33.3 ms", "30 fps: %s" % Counter.text_for(15, 0.5))
	runner.check(Counter.text_for(0, 0.5) == "-- FPS", "nessun fotogramma: niente numero inventato")
	runner.check(Counter.text_for(10, 0.0) == "-- FPS", "tempo zero: niente divisione per zero")


func test_colore() -> void:
	runner.check(Counter.color_for(144.0) == Counter.GOOD and Counter.color_for(57.0) == Counter.GOOD, "da 55 in su verde")
	runner.check(Counter.color_for(45.0) == Counter.SLOW and Counter.color_for(30.0) == Counter.SLOW, "30-54 giallo")
	runner.check(Counter.color_for(20.0) == Counter.BAD, "sotto 30 rosso")


func test_spento_di_default() -> void:
	runner.check(Settings.VIDEO_DEFAULTS.fps_counter == false, "chi non lo accende non vede niente di nuovo")
