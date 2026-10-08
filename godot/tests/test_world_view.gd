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


func test_stato_preciso_dei_colpi() -> void:
	runner.check(WorldView._animation_for(_player({"attack": "lightUp"})) == "lightUp", "variante leggera")
	runner.check(WorldView._animation_for(_player({"attack": "heavyAir", "onGround": false})) == "heavyAir", "variante pesante in aria")
	runner.check(WorldView._animation_for(_player({"attack": "recovery", "onGround": false})) == "recovery", "recupero")
	runner.check(WorldView._animation_for(_player({"shielding": true})) == "shield", "scudo")
	runner.check(WorldView._animation_for(_player({"grabbedBy": "b"})) == "grabbed", "tenuto con la presa")
	runner.check(WorldView._animation_for(_player({}), true) == "grab", "chi tiene")
	runner.check(WorldView._animation_for(_player({"attack": "throwBack"})) == "throw", "lancio")
	runner.check(WorldView._animation_for(_player({"attack": "specialSide"})) == "special", "speciale")


func test_disegno_proprio_o_ripiego() -> void:
	# In game.json ogni stato c'è già risolto: src dice di chi è il disegno (E7 passo 3)
	var anims := {"jump": {"src": "jump"}, "ledge": {"src": "jump"}, "taunt": {"src": "taunt"}}
	runner.check(not WorldView.has_own(anims, "ledge"), "ledge col disegno del salto non è suo")
	runner.check(WorldView.has_own(anims, "taunt"), "taunt disegnato è suo")
	runner.check(not WorldView.has_own(anims, "land"), "uno stato assente non è suo")
	runner.check(WorldView.has_own({"ledge": {}}, "ledge"), "senza src (dati vecchi) conta come suo")


func test_fotogrammi_a_fps() -> void:
	var walk := {"frames": 10, "fps": 20, "loop": true}
	runner.check(WorldView.sprite_frame(walk, 0) == 0, "si parte dal primo")
	runner.check(WorldView.sprite_frame(walk, 260) == 5, "a 20 fps, 260 ms = fotogramma 5")
	runner.check(WorldView.sprite_frame(walk, 560) == 1, "in ciclo ricomincia")
	var jump := {"frames": 4, "fps": 20, "loop": false}
	runner.check(WorldView.sprite_frame(jump, 5000) == 3, "senza ciclo resta sull'ultimo")
	runner.check(is_equal_approx(WorldView.animation_ms(walk), 500.0), "10 fotogrammi a 20 fps = 500 ms")


func test_fotogramma_d_impatto_con_la_hitbox() -> void:
	# Martello di 18 fotogrammi con l'impatto nel 6: cade a startupMs e l'animazione finisce con cooldownMs
	var heavy := {"frames": 18, "fps": 24, "loop": false, "hitFrame": 6}
	var spec := {"startupMs": 260, "activeMs": 120, "cooldownMs": 750}
	runner.check(WorldView.sprite_frame(heavy, 0, spec) == 0, "si parte dal primo")
	runner.check(WorldView.sprite_frame(heavy, 259, spec) == 5, "un attimo prima della hitbox: %d" % WorldView.sprite_frame(heavy, 259, spec))
	runner.check(WorldView.sprite_frame(heavy, 260, spec) == 6, "con la hitbox accesa: impatto")
	runner.check(WorldView.sprite_frame(heavy, 749, spec) == 17, "alla fine: ultimo")
	runner.check(WorldView.sprite_frame(heavy, 2000, spec) == 17, "dopo resta sull'ultimo")
	runner.check(is_equal_approx(WorldView.animation_ms(heavy, spec), 750.0), "dura cooldownMs")
	# La variante con un avvio più lungo stira lo stesso disegno
	var slow := {"startupMs": 400, "activeMs": 120, "cooldownMs": 900}
	runner.check(WorldView.sprite_frame(heavy, 399, slow) == 5 and WorldView.sprite_frame(heavy, 400, slow) == 6, "impatto a 400 ms")
	# Avvio zero (recupero): si parte dall'impatto
	runner.check(WorldView.sprite_frame(heavy, 0, {"startupMs": 0, "activeMs": 250, "cooldownMs": 0}) == 6, "avvio zero")
	# Senza hitFrame si va a fps anche negli attacchi
	runner.check(WorldView.sprite_frame({"frames": 3, "fps": 20, "loop": false}, 100, spec) == 2, "senza hitFrame: fps")


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


func test_numeri_degli_attacchi_per_personaggio() -> void:
	var game := {"attacks": {"light": {"range": 52}, "recovery": {"range": 40, "height": 70}}, "characters": {"a": {"recovery": {"range": 60}}, "b": {}}}
	runner.check(WorldView.attack_spec(game, "a", "light").range == 52, "leggero uguale per tutti")
	runner.check(WorldView.attack_spec(game, "a", "recovery").range == 60, "recupero ritoccato")
	runner.check(WorldView.attack_spec(game, "a", "recovery").height == 70, "il resto resta")
	runner.check(WorldView.attack_spec(game, "b", "recovery").range == 40, "senza ritocchi")
	runner.check(WorldView.attack_spec(game, "b", "nuovo").is_empty(), "attacco sconosciuto")


func test_numeri_delle_speciali_dal_personaggio() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	for id in game.characters:
		for kind in ["specialNeutral", "specialSide", "specialDown"]:
			var spec := WorldView.attack_spec(game, id, kind)
			runner.check(spec.get("range", 0) > 0 and spec.get("cooldownMs", 0) > 0, "%s: %s senza numeri" % [id, kind])
	runner.check(not WorldView.attack_spec(game, "sconosciuto", "specialSide").is_empty(), "personaggio sconosciuto: quello base")


func test_colore_dei_proiettili_e_alone_della_carica() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var tiro := WorldView.projectile_color(game, "bonobot", "specialNeutral")
	runner.check(tiro.is_equal_approx(Color.hex(0xffd84aff)), "il Tiro è giallo: %s" % tiro)
	runner.check(WorldView.projectile_color(game, "sconosciuto", "specialNeutral").is_equal_approx(WorldView.projectile_color(game, "default", "specialNeutral")), "personaggio sconosciuto: quello di Bonobo")
	var schizzo := WorldView.projectile_color(game, "egiainuso", "specialNeutral")
	runner.check(schizzo.is_equal_approx(Color.hex(0x6ec8ffff)), "lo Schizzo di Egiainuso è azzurro: %s" % schizzo)
	runner.check(WorldView.charge_radius(88, 1.0) > WorldView.charge_radius(88, 0.2), "l'alone cresce con la carica")
	runner.check(WorldView.charge_radius(88, 5.0) == WorldView.charge_radius(88, 1.0), "oltre la carica piena non cresce")
