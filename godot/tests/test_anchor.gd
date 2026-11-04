# L'ancora di Capt. OrsoBlu (#547): maglie della catena, pose da appeso e predizione ferma
extends RefCounted

var runner

const AnchorChain := preload("res://scripts/anchor_chain.gd")
const FighterPose := preload("res://scripts/fighter_pose.gd")


func test_maglie_dalle_mani_alla_punta() -> void:
	var links := AnchorChain.links(Vector2(0, 0), Vector2(0, -100), 0.0)
	runner.check(links.size() == 10, "una maglia ogni 10 pixel (%d)" % links.size())
	var last: Dictionary = links[links.size() - 1]
	runner.check(last.at.distance_to(Vector2(0, -95)) < 0.01, "l'ultima maglia arriva alla punta (%s)" % last.at)
	runner.check(last.dir.is_equal_approx(Vector2.UP), "tesa, ogni maglia guarda verso l'ancora")


func test_in_volo_la_catena_pende() -> void:
	var links := AnchorChain.links(Vector2(0, 0), Vector2(200, 0), 20.0)
	var mid: Dictionary = links[int(links.size() / 2.0)]
	runner.check(mid.at.y > 15.0, "nel mezzo pende verso il basso (%s)" % mid.at)


func test_pose_da_appeso() -> void:
	var p := {"hitstun": false, "attack": null, "onGround": false, "vx": 0, "vy": 0}
	p.anchor = {"x": 0, "y": 0, "phase": "hold"}
	runner.check(FighterPose.animation_for(p) == "anchorHang", "piantata: appeso")
	p.anchor.phase = "climb"
	runner.check(FighterPose.animation_for(p) == "anchorClimb", "su: si arrampica")
	p.anchor.phase = "fly"
	runner.check(FighterPose.animation_for(p) == "fall", "in volo: la posa dell'aria")
	p.attack = "lightAir"
	p.anchor.phase = "hold"
	runner.check(FighterPose.animation_for(p) == "lightAir", "il calcio da appeso si vede")


func test_con_l_ancora_non_si_predice() -> void:
	var p := {"x": 100, "y": 100, "predict": {}, "attack": null, "hitstun": false}
	runner.check(Predictor.predictable(p, {}), "senza ancora si predice")
	p.anchor = {"x": 0, "y": 0, "phase": "fly"}
	runner.check(not Predictor.predictable(p, {}), "con l'ancora fuori no")
