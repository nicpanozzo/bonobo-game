# Squash & stretch del movimento (motion_feel.gd)
extends RefCounted

var runner

const MotionFeel := preload("res://scripts/motion_feel.gd")

const FX := {"jumpStretch": 0.14, "landSquash": 0.16, "bounceMs": 220, "bounceHz": 4, "runLean": 0.12}


func test_salto_allunga_atterraggio_schiaccia() -> void:
	var up := MotionFeel.squash(MotionFeel.start(FX, "jump", 0), FX, 1)
	var down := MotionFeel.squash(MotionFeel.start(FX, "land", 0), FX, 1)
	runner.check(up < -0.1, "chi salta si allunga (%s)" % up)
	runner.check(down > 0.1, "chi atterra si schiaccia (%s)" % down)
	var feet := MotionFeel.transform(Vector2(100, 500), down, 0.0) * Vector2(100, 500)
	runner.check(feet.is_equal_approx(Vector2(100, 500)), "i piedi restano dove sono (%s)" % feet)


func test_rimbalzo_finisce() -> void:
	var r := MotionFeel.start(FX, "land", 1000)
	runner.check(MotionFeel.squash(r, FX, 1220) == 0.0, "a fine bounceMs lo sprite è dritto")
	runner.check(MotionFeel.squash(r, FX, 900) == 0.0, "prima dell'evento niente")


func test_corsa_piega_in_avanti() -> void:
	var run := {"onGround": true, "vx": 560.0, "attack": null}
	var walk := {"onGround": true, "vx": -380.0, "attack": null}
	var air := {"onGround": false, "vx": 560.0, "attack": null}
	runner.check(is_equal_approx(MotionFeel.lean(run, FX, 380, 560), 0.12), "a piena corsa verso destra si piega in senso orario")
	runner.check(MotionFeel.lean(walk, FX, 380, 560) == 0.0, "camminando non si piega")
	runner.check(MotionFeel.lean(air, FX, 380, 560) == 0.0, "in aria non si piega")
	var left := {"onGround": true, "vx": -560.0, "attack": null}
	runner.check(MotionFeel.lean(left, FX, 380, 560) < 0.0, "correndo a sinistra si piega dall'altra parte")
