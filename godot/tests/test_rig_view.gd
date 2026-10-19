# Prova del lottatore a pezzi in tempo reale (rig_view.gd e FighterPose.rig_frame, #403)
extends RefCounted

var runner

const RigView := preload("res://scripts/rig_view.gd")
const FighterPose := preload("res://scripts/fighter_pose.gd")


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func _nonna() -> RefCounted:
	return RigView.open("res://data/" + str(_game().characters.nonnagina.sprite.rig))


func test_nonna_gina_ha_il_rig() -> void:
	var rig := _nonna()
	runner.check(rig != null, "il rig di Nonna Gina si carica")
	if rig == null:
		return
	var sprite: Dictionary = _game().characters.nonnagina.sprite
	for state in ["idle", "walk", "light", "heavy", "specialSide", "supreme"]:
		var a: Dictionary = sprite.animations[state]
		runner.check(rig.has_state(state) and rig.animations[state].size() == int(a.frames), "%s: tante pose quanti fotogrammi della striscia" % state)
	runner.check(rig.layers.size() > 30 and rig.parents[0] == -1, "pezzi e ossa caricati (%d pezzi)" % rig.layers.size())


func test_rig_che_manca() -> void:
	runner.check(RigView.open("res://data/non/esiste.json") == null, "senza file niente rig: si usano le strisce")


func test_pose_mescolate() -> void:
	var rig := _nonna()
	if rig == null:
		return
	var a: PackedFloat32Array = rig.animations.light[1]
	var b: PackedFloat32Array = rig.animations.light[2]
	runner.check(rig.pose("light", 1.0, false) == a, "sul fotogramma intero la posa è quella esportata")
	var mid: PackedFloat32Array = rig.pose("light", 1.5, false)
	var k: int = 2 + rig.parents.size() - 1
	runner.check(is_equal_approx(mid[0], (a[0] + b[0]) / 2.0), "la radice a metà strada (%s)" % mid[0])
	runner.check(absf(wrapf(mid[k] - (a[k] + wrapf(b[k] - a[k], -180, 180) / 2.0), -180, 180)) < 0.01, "gli angoli a metà strada")
	var n: int = rig.animations.idle.size()
	runner.check(rig.pose("idle", n - 0.5, true).size() == a.size(), "nel ciclo dopo l'ultima posa si torna alla prima")


func test_ossa_seguono_il_genitore() -> void:
	var rig := _nonna()
	if rig == null:
		return
	var rest := PackedFloat32Array()
	rest.resize(2 + rig.parents.size())
	for t in rig.bone_transforms(rest):
		runner.check(t.is_equal_approx(Transform2D.IDENTITY), "a riposo ogni pezzo resta dov'è disegnato")
	rest[0] = 10.0
	var moved: Array[Transform2D] = rig.bone_transforms(rest)
	runner.check(moved[rig.parents.size() - 1].origin.is_equal_approx(Vector2(10, 0)), "la radice sposta tutto")


func test_tempi_del_colpo() -> void:
	var a := {"frames": 9, "fps": 24, "loop": false, "hitFrame": 2, "startFrame": 1}
	var attack := {"startupMs": 100.0, "activeMs": 60.0, "cooldownMs": 400.0}
	var early := FighterPose.rig_frame(a, 50.0, attack)
	runner.check(early >= 1.0 and early < 1.2, "a metà carica la posa si tiene vicino alla carica (%s)" % early)
	runner.check(is_equal_approx(FighterPose.rig_frame(a, 100.0, attack), 2.0), "all'accensione della hitbox è sull'impatto")
	runner.check(is_equal_approx(FighterPose.rig_frame(a, 150.0, attack), 2.0), "l'impatto resta fermo finché la hitbox è accesa")
	runner.check(FighterPose.rig_frame(a, 300.0, attack) > 2.0, "poi il recupero")
	runner.check(is_equal_approx(FighterPose.rig_frame(a, 400.0, attack), 8.0), "e finisce con cooldownMs")
	var loop := {"frames": 10, "fps": 20, "loop": true}
	runner.check(is_equal_approx(FighterPose.rig_frame(loop, 525.0), 0.5), "i cicli ricominciano (%s)" % FighterPose.rig_frame(loop, 525.0))
