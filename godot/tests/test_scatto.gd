# Scatto con doppio tocco (#199): la posa e il ripiego
extends RefCounted

var runner

const FighterPose := preload("res://scripts/fighter_pose.gd")


func test_chi_scatta_ha_la_posa_dello_scatto() -> void:
	var p := {"hitstun": false, "attack": null, "onGround": true, "vx": 900.0, "vy": 0.0, "ledge": null, "dashing": true}
	runner.check(FighterPose.animation_for(p) == "dash", "a terra mentre scatta")
	p.dashing = false
	runner.check(FighterPose.animation_for(p) == "walk", "senza scatto si cammina")
	p.erase("dashing")
	runner.check(FighterPose.animation_for(p) == "walk", "server di prima, senza il campo")


func test_ogni_personaggio_ha_lo_scatto_o_il_ripiego() -> void:
	# Chi non ha il disegno dello scatto usa la camminata (ANIMATION_FALLBACK in characters.ts); dal 2026-11-08
	# tutti hanno il proprio, quindi qui si controlla che ogni striscia sia una delle due.
	var game: Dictionary = JSON.parse_string(FileAccess.open("res://data/game.json", FileAccess.READ).get_as_text())
	for id in game.characters:
		var c: Dictionary = game.characters[id]
		if not c.has("sprite"):
			continue
		var anims: Dictionary = c.sprite.animations
		runner.check(anims.has("dash") and str(anims.dash.src) in ["dash", "walk"], "%s: lo scatto ha il suo disegno o la camminata" % id)
	runner.check(str(game.characters.orsoblu.sprite.animations.dash.src) == "dash", "Capt. OrsoBlu ha il suo scatto (clip Flow OB-B5)")
	runner.check(str(game.characters.bonobot.sprite.animations.dash.src) == "dash", "Bonobot ha il suo scatto (#257)")
