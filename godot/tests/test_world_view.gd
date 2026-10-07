# Pose del lottatore (world_view.gd), dai soli campi dello snapshot
extends RefCounted

var runner

const WorldView := preload("res://scripts/world_view.gd")


func _player(extra := {}) -> Dictionary:
	var p := {"hitstun": false, "attack": null, "onGround": true, "vx": 0.0, "vy": 0.0, "ledge": null}
	p.merge(extra, true)
	return p


func test_pose_del_bordo() -> void:
	runner.check(WorldView._animation_for(_player({"ledge": "hang", "onGround": false})) == "ledge", "appeso")
	runner.check(WorldView._animation_for(_player({"ledge": "climb", "onGround": false})) == "climb", "risalita")
	runner.check(WorldView._animation_for(_player({"ledge": "roll", "onGround": false})) == "walk", "rotolata")
	# La risalita con attacco mostra il colpo
	runner.check(WorldView._animation_for(_player({"ledge": "climb", "attack": "ledgeAttack"})) == "light", "attacco dal bordo")


func test_server_vecchio_senza_campo_ledge() -> void:
	var p := _player({"onGround": false, "vy": 100.0})
	p.erase("ledge")
	runner.check(WorldView._animation_for(p) == "fall", "senza ledge si cade come prima")


func test_animazioni_del_bordo_facoltative() -> void:
	var only_base := {"idle": {}, "jump": {}, "walk": {}}
	runner.check(WorldView.available_animation(only_base, "ledge") == "jump", "ledge -> jump")
	runner.check(WorldView.available_animation(only_base, "climb") == "jump", "climb -> jump")
	runner.check(WorldView.available_animation({"ledge": {}, "jump": {}}, "ledge") == "ledge", "se c'è si usa")
	runner.check(WorldView.available_animation(only_base, "walk") == "walk", "le altre restano")


func test_disconnesso_semitrasparente() -> void:
	runner.check(WorldView.away_alpha(_player({"away": true})) < 1.0, "away: trasparente")
	runner.check(WorldView.away_alpha(_player({"away": false})) == 1.0, "collegato: pieno")
	runner.check(WorldView.away_alpha(_player()) == 1.0, "server vecchio senza away: pieno")


func test_bolla_dello_scudo_rimpicciolisce() -> void:
	var full := WorldView.shield_radius(50, 50, 88)
	var half := WorldView.shield_radius(25, 50, 88)
	var empty := WorldView.shield_radius(0, 50, 88)
	runner.check(full > half and half > empty and empty > 0, "raggi: %s %s %s" % [full, half, empty])
	runner.check(full >= 88 / 2.0, "piena copre il lottatore: %s" % full)


func test_stordito_ha_la_posa_del_colpo() -> void:
	var p := {"hitstun": false, "stunned": true, "attack": null, "onGround": true, "vx": 0, "vy": 0}
	runner.check(WorldView._animation_for(p) == "hit", "posa: %s" % WorldView._animation_for(p))
	p.stunned = false
	runner.check(WorldView._animation_for(p) == "idle", "senza stordimento: %s" % WorldView._animation_for(p))


func test_schegge_a_raggiera() -> void:
	var v := WorldView.shard_velocities(10)
	var sum := Vector2.ZERO
	for s in v:
		sum += s
	runner.check(v.size() == 10 and sum.y < 0, "10 schegge, in media verso l'alto: %s" % sum)
