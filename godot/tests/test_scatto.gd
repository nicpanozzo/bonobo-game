# Scatto con doppio tocco (#199): la posa e il ripiego
extends RefCounted

var runner

const WorldView := preload("res://scripts/world_view.gd")


func test_chi_scatta_ha_la_posa_dello_scatto() -> void:
	var p := {"hitstun": false, "attack": null, "onGround": true, "vx": 900.0, "vy": 0.0, "ledge": null, "dashing": true}
	runner.check(WorldView._animation_for(p) == "dash", "a terra mentre scatta")
	p.dashing = false
	runner.check(WorldView._animation_for(p) == "walk", "senza scatto si cammina")
	p.erase("dashing")
	runner.check(WorldView._animation_for(p) == "walk", "server di prima, senza il campo")


func test_senza_disegno_ripiega_sulla_camminata() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.open("res://data/game.json", FileAccess.READ).get_as_text())
	var anims: Dictionary = game.characters.bonobot.sprite.animations
	runner.check(anims.has("dash") and str(anims.dash.src) == "walk", "Bonobot: lo scatto usa il galoppo della camminata")
