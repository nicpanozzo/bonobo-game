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
