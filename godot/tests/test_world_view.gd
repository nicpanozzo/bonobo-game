# Pose del lottatore (world_view.gd), dai soli campi dello snapshot
extends RefCounted

var runner

const WorldView := preload("res://scripts/world_view.gd")
const StageMotion := preload("res://scripts/stage_motion.gd")

const FighterPose := preload("res://scripts/fighter_pose.gd")


func _player(extra := {}) -> Dictionary:
	var p := {"hitstun": false, "attack": null, "onGround": true, "vx": 0.0, "vy": 0.0, "ledge": null}
	p.merge(extra, true)
	return p


func test_pose_del_bordo() -> void:
	runner.check(FighterPose.animation_for(_player({"ledge": "hang", "onGround": false})) == "ledge", "appeso")
	runner.check(FighterPose.animation_for(_player({"ledge": "climb", "onGround": false})) == "climb", "risalita")
	runner.check(FighterPose.animation_for(_player({"ledge": "roll", "onGround": false})) == "walk", "rotolata")
	# La risalita con attacco mostra il colpo
	runner.check(FighterPose.animation_for(_player({"ledge": "climb", "attack": "ledgeAttack"})) == "light", "attacco dal bordo")


func test_server_vecchio_senza_campo_ledge() -> void:
	var p := _player({"onGround": false, "vy": 100.0})
	p.erase("ledge")
	runner.check(FighterPose.animation_for(p) == "fall", "senza ledge si cade come prima")


# Preparazione al salto e pausa all'atterraggio (#384 A3): campi facoltativi, chi non li manda resta com'era
func test_preparazione_al_salto_e_atterraggio() -> void:
	runner.check(FighterPose.animation_for(_player({"jumpSquat": 33})) == "jumpSquat", "preparazione al salto")
	runner.check(FighterPose.animation_for(_player({"landing": 100})) == "land", "pausa all'atterraggio")
	runner.check(FighterPose.animation_for(_player({"landing": 100, "hitstun": true})) == "hit", "colpiti vince sull'atterraggio")
	runner.check(FighterPose.animation_for(_player({})) == "idle", "senza i campi, fermi")
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	for id in game.characters:
		var anims: Dictionary = game.characters[id].get("sprite", {}).get("animations", {})
		if not anims.is_empty():
			runner.check(anims.has("jumpSquat") and anims.has("land"), "%s: jumpSquat e land ripiegano su uno stato disegnato" % id)


# Col gioco rallentato le animazioni contano il tempo del combattimento, come la fisica (#384 A4)
func test_animazioni_al_passo_del_gioco() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var speed := float(game.gameSpeed)
	runner.check(speed > 0.0 and speed <= 1.0, "gameSpeed tra 0 e 1 (%s)" % speed)
	runner.check(is_equal_approx(FighterPose.fight_elapsed(game, 1500.0, 500.0), 1000.0 * speed), "1 s d'orologio = %s ms di combattimento" % (1000.0 * speed))
	runner.check(is_equal_approx(FighterPose.fight_elapsed({}, 1500.0, 500.0), 1000.0), "senza il campo, tempo vero")


func test_stato_preciso_dei_colpi() -> void:
	runner.check(FighterPose.animation_for(_player({"attack": "lightUp"})) == "lightUp", "variante leggera")
	runner.check(FighterPose.animation_for(_player({"attack": "heavyAir", "onGround": false})) == "heavyAir", "variante pesante in aria")
	runner.check(FighterPose.animation_for(_player({"attack": "recovery", "onGround": false})) == "recovery", "recupero")
	runner.check(FighterPose.animation_for(_player({"shielding": true})) == "shield", "scudo")
	runner.check(FighterPose.animation_for(_player({"grabbedBy": "b"})) == "grabbed", "tenuto con la presa")
	runner.check(FighterPose.animation_for(_player({}), true) == "grab", "chi tiene")
	runner.check(FighterPose.animation_for(_player({"attack": "throwBack"})) == "throw", "lancio")
	runner.check(FighterPose.animation_for(_player({"attack": "specialSide"})) == "specialSide", "speciale: lo stato della singola speciale (#257), che ripiega su special")


func test_disegno_proprio_o_ripiego() -> void:
	# In game.json ogni stato c'è già risolto: src dice di chi è il disegno (E7 passo 3)
	var anims := {"jump": {"src": "jump"}, "ledge": {"src": "jump"}, "taunt": {"src": "taunt"}}
	runner.check(not FighterPose.has_own(anims, "ledge"), "ledge col disegno del salto non è suo")
	runner.check(FighterPose.has_own(anims, "taunt"), "taunt disegnato è suo")
	runner.check(not FighterPose.has_own(anims, "land"), "uno stato assente non è suo")
	runner.check(FighterPose.has_own({"ledge": {}}, "ledge"), "senza src (dati vecchi) conta come suo")


func test_fotogrammi_a_fps() -> void:
	var walk := {"frames": 10, "fps": 20, "loop": true}
	runner.check(FighterPose.sprite_frame(walk, 0) == 0, "si parte dal primo")
	runner.check(FighterPose.sprite_frame(walk, 260) == 5, "a 20 fps, 260 ms = fotogramma 5")
	runner.check(FighterPose.sprite_frame(walk, 560) == 1, "in ciclo ricomincia")
	var jump := {"frames": 4, "fps": 20, "loop": false}
	runner.check(FighterPose.sprite_frame(jump, 5000) == 3, "senza ciclo resta sull'ultimo")
	runner.check(is_equal_approx(FighterPose.animation_ms(walk), 500.0), "10 fotogrammi a 20 fps = 500 ms")


func test_fotogramma_d_impatto_con_la_hitbox() -> void:
	# Martello di 18 fotogrammi con l'impatto nel 6: cade a startupMs e l'animazione finisce con cooldownMs
	var heavy := {"frames": 18, "fps": 24, "loop": false, "hitFrame": 6}
	var spec := {"startupMs": 260, "activeMs": 120, "cooldownMs": 750}
	runner.check(FighterPose.sprite_frame(heavy, 0, spec) == 0, "si parte dal primo")
	runner.check(FighterPose.sprite_frame(heavy, 259, spec) == 5, "un attimo prima della hitbox: %d" % FighterPose.sprite_frame(heavy, 259, spec))
	runner.check(FighterPose.sprite_frame(heavy, 260, spec) == 6, "con la hitbox accesa: impatto")
	runner.check(FighterPose.sprite_frame(heavy, 749, spec) == 17, "alla fine: ultimo")
	runner.check(FighterPose.sprite_frame(heavy, 2000, spec) == 17, "dopo resta sull'ultimo")
	runner.check(is_equal_approx(FighterPose.animation_ms(heavy, spec), 750.0), "dura cooldownMs")
	# La variante con un avvio più lungo stira lo stesso disegno
	var slow := {"startupMs": 400, "activeMs": 120, "cooldownMs": 900}
	runner.check(FighterPose.sprite_frame(heavy, 399, slow) == 5 and FighterPose.sprite_frame(heavy, 400, slow) == 6, "impatto a 400 ms")
	# Avvio zero (recupero): si parte dall'impatto
	runner.check(FighterPose.sprite_frame(heavy, 0, {"startupMs": 0, "activeMs": 250, "cooldownMs": 0}) == 6, "avvio zero")
	# Senza hitFrame si va a fps anche negli attacchi
	runner.check(FighterPose.sprite_frame({"frames": 3, "fps": 20, "loop": false}, 100, spec) == 2, "senza hitFrame: fps")
	var rest := heavy.duplicate()
	rest.startFrame = 1
	runner.check(FighterPose.sprite_frame(rest, 0, spec) == 1, "startFrame: si salta la posa di riposo")
	runner.check(FighterPose.sprite_frame(rest, 260, spec) == 6, "e l'impatto resta all'accendersi della hitbox")


func test_disconnesso_semitrasparente() -> void:
	runner.check(FighterPose.away_alpha(_player({"away": true})) < 1.0, "away: trasparente")
	runner.check(FighterPose.away_alpha(_player({"away": false})) == 1.0, "collegato: pieno")
	runner.check(FighterPose.away_alpha(_player()) == 1.0, "server vecchio senza away: pieno")


func test_bolla_dello_scudo_rimpicciolisce() -> void:
	var full := FighterPose.shield_radius(50, 50, 88)
	var half := FighterPose.shield_radius(25, 50, 88)
	var empty := FighterPose.shield_radius(0, 50, 88)
	runner.check(full > half and half > empty and empty > 0, "raggi: %s %s %s" % [full, half, empty])
	runner.check(full >= 88 / 2.0, "piena copre il lottatore: %s" % full)


func test_stordito_ha_la_posa_del_colpo() -> void:
	var p := {"hitstun": false, "stunned": true, "attack": null, "onGround": true, "vx": 0, "vy": 0}
	runner.check(FighterPose.animation_for(p) == "hit", "posa: %s" % FighterPose.animation_for(p))
	p.stunned = false
	runner.check(FighterPose.animation_for(p) == "idle", "senza stordimento: %s" % FighterPose.animation_for(p))


func test_schegge_a_raggiera() -> void:
	var v := FighterPose.shard_velocities(10)
	var sum := Vector2.ZERO
	for s in v:
		sum += s
	runner.check(v.size() == 10 and sum.y < 0, "10 schegge, in media verso l'alto: %s" % sum)


func test_numeri_degli_attacchi_per_personaggio() -> void:
	var game := {"attacks": {"light": {"range": 52}, "recovery": {"range": 40, "height": 70}}, "characters": {"a": {"recovery": {"range": 60}}, "b": {}}}
	runner.check(FighterPose.attack_spec(game, "a", "light").range == 52, "leggero uguale per tutti")
	runner.check(FighterPose.attack_spec(game, "a", "recovery").range == 60, "recupero ritoccato")
	runner.check(FighterPose.attack_spec(game, "a", "recovery").height == 70, "il resto resta")
	runner.check(FighterPose.attack_spec(game, "b", "recovery").range == 40, "senza ritocchi")
	runner.check(FighterPose.attack_spec(game, "b", "nuovo").is_empty(), "attacco sconosciuto")


func test_numeri_delle_speciali_dal_personaggio() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	for id in game.characters:
		for kind in ["specialNeutral", "specialSide", "specialDown"]:
			var spec := FighterPose.attack_spec(game, id, kind)
			runner.check(spec.get("range", 0) > 0 and spec.get("cooldownMs", 0) > 0, "%s: %s senza numeri" % [id, kind])
	runner.check(not FighterPose.attack_spec(game, "sconosciuto", "specialSide").is_empty(), "personaggio sconosciuto: quello base")


func test_colore_dei_proiettili_e_alone_della_carica() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var tiro := FighterPose.projectile_color(game, "egiainuso", "specialNeutral")
	runner.check(tiro.is_equal_approx(Color.hex(0xffd84aff)), "il Tiro è giallo: %s" % tiro)
	var fumo := FighterPose.projectile_color(game, "bonobot", "specialNeutral")
	runner.check(fumo.is_equal_approx(Color.hex(0xd9d3c7ff)), "l'Anello di fumo di Bonobot è grigio: %s" % fumo)
	runner.check(FighterPose.projectile_color(game, "sconosciuto", "specialNeutral").is_equal_approx(FighterPose.projectile_color(game, "default", "specialNeutral")), "personaggio sconosciuto: quello di Bonobo")
	var schizzo := FighterPose.projectile_color(game, "orsoblu", "specialNeutral")
	runner.check(schizzo.is_equal_approx(Color.hex(0x6ec8ffff)), "lo Schizzo di Capt. OrsoBlu è azzurro: %s" % schizzo)
	runner.check(FighterPose.charge_radius(88, 1.0) > FighterPose.charge_radius(88, 0.2), "l'alone cresce con la carica")
	runner.check(FighterPose.charge_radius(88, 5.0) == FighterPose.charge_radius(88, 1.0), "oltre la carica piena non cresce")


func test_stesso_personaggio_colori_diversi() -> void:
	var players := [
		{"id": "a", "characterId": "bonobot", "color": 0x3498db},
		{"id": "b", "characterId": "bonobot", "color": 0xe74c3c},
		{"id": "c", "characterId": "orsoblu", "color": 0x2ecc71},
		{"id": "d", "characterId": "bonobot", "color": 0x2ecc71, "eliminated": true},
	]
	var ranks := FighterPose.variant_ranks(players)
	runner.check(ranks.d == 0 and ranks.a == 1 and ranks.b == 2, "in ordine di colore, eliminati compresi: %s" % ranks)
	runner.check(ranks.c == 0, "da solo col suo personaggio resta originale")
	runner.check(FighterPose.sprite_modulate(0, 0.5) == Color(1, 1, 1, 0.5), "originale: modulate normale")
	var m := FighterPose.sprite_modulate(1, 1.0)
	runner.check(m.r > 1.5 and m.a == 1.0, "variante: rosso oltre 1 per lo shader")
	runner.check(FighterPose.sprite_modulate(2, 1.0) != m, "varianti diverse, tinte diverse")
	runner.check(FighterPose.sprite_modulate(1 + FighterPose.VARIANT_HUES.size(), 1.0) == m, "oltre l'ultima si ricomincia")


# Colpo caricato (SMASH_CHARGE): solo con un attacco in corso e la carica sopra zero, lampo che cresce
func test_colpo_caricato_lampeggia() -> void:
	var charging := {"attack": "heavy", "charge": 0.9}
	runner.check(FighterPose.smash_charging(charging), "pesante tenuto: carica")
	runner.check(not FighterPose.smash_charging({"attack": null, "charge": 0.5}), "la carica della speciale non è un colpo caricato")
	runner.check(not FighterPose.smash_charging({"attack": "heavy", "charge": 0.0}), "pesante lasciato: niente lampo")
	var peak := 0.0
	for t in 200:
		peak = maxf(peak, FighterPose.charge_flash(charging, t * 5.0, false))
	runner.check(peak > 0.6 and peak <= 1.0, "a carica quasi piena il lampo è forte: %s" % peak)
	runner.check(FighterPose.charge_flash(charging, 0.0, true) > 0.0, "con meno lampi resta un bagliore")
	var m := FighterPose.sprite_modulate(1, 1.0, 0.5)
	runner.check(m.r > 1.5 and is_equal_approx(m.g, 2.5), "variante e lampo insieme: rosso e verde oltre 1")
	runner.check(FighterPose.sprite_modulate(0, 1.0, 0.0).g == 1.0, "senza lampo il verde resta 1")


# Suprema pronta (#101): solo con la barra piena e in gioco; le fiammelle restano attorno al corpo
func test_suprema_pronta_si_vede() -> void:
	runner.check(FighterPose.supreme_ready({"supreme": 100}, 100.0), "barra piena: pronta")
	runner.check(not FighterPose.supreme_ready({"supreme": 99.5}, 100.0), "quasi piena: non ancora")
	runner.check(not FighterPose.supreme_ready({"supreme": 100, "respawning": true}, 100.0), "chi rientra non si accende")
	var flames := FighterPose.supreme_flames("a", 1234.0, 88.0)
	runner.check(flames.size() == 7, "sette fiammelle")
	for f in flames:
		runner.check(absf(f.pos.x) < 40.0 and f.pos.y <= 0.0 and f.pos.y > -110.0, "fiammella fuori dal corpo: %s" % f.pos)
	runner.check(FighterPose.supreme_flames("a", 1234.0, 88.0) == flames, "stesso istante, stesse fiammelle")


# Acqua alta (#228): stessi numeri di hazardRect() e floodPhase() in physics/elements.test.ts
func test_acqua_alta_come_il_server() -> void:
	var water := {"kind": "acqua", "x": 300, "y": 620, "width": 400, "height": 30,
		"flood": {"highY": 540, "periodMs": 10000, "warnMs": 1000, "riseMs": 1000, "holdMs": 2000, "fallMs": 1000}}
	runner.check(StageMotion.hazard_rect(water, 0).position.y == 620.0, "bassa all'inizio del giro")
	runner.check(StageMotion.flood_phase(water, 5500).phase == "warn", "pioggia prima della salita")
	runner.check(StageMotion.hazard_rect(water, 5500).position.y == 620.0, "con la pioggia è ancora bassa")
	runner.check(StageMotion.hazard_rect(water, 6500).position.y == 580.0, "a metà della salita")
	runner.check(StageMotion.hazard_rect(water, 7500).position.y == 540.0, "alta")
	runner.check(StageMotion.hazard_rect(water, 9500).position.y == 580.0, "a metà della discesa")
	runner.check(StageMotion.hazard_rect(water, 10000).position.y == 620.0, "il giro ricomincia")
	runner.check(StageMotion.hazard_rect(water, 7500).end.y == 650.0, "il fondo resta fermo")
	runner.check(StageMotion.rain_strength(water, 5500) == 0.5 and StageMotion.rain_strength(water, 2000) == 0.0, "pioggia solo dall'avviso in poi")
	var spikes := {"kind": "spuntoni", "x": 10, "y": 20, "width": 30, "height": 5}
	runner.check(StageMotion.hazard_rect(spikes, 1234) == Rect2(10, 20, 30, 5), "le altre trappole restano ferme")


# Trappola che viaggia (#229): stessi numeri di travelPhase(), hazardRect() e travelDirection() in elements.test.ts
func test_ciclista_come_il_server() -> void:
	var bike := {"kind": "ciclista", "x": 0, "y": 0, "width": 70, "height": 60,
		"travel": {"path": [{"x": 0, "y": 590}, {"x": 1000, "y": 590}], "periodMs": 10000, "warnMs": 1000, "crossMs": 2000, "alternate": true}}
	runner.check(StageMotion.travel_phase(bike, 6000).phase == "calm", "calma")
	var warn := StageMotion.travel_phase(bike, 7500)
	runner.check(warn.phase == "warn" and warn.k == 0.5 and not warn.reverse, "campanello")
	runner.check(StageMotion.hazard_rect(bike, 9000).position.x == 500.0, "a metà del passaggio è a metà strada")
	runner.check(StageMotion.travel_direction(bike, 9000) == 1, "all'andata verso destra")
	runner.check(StageMotion.travel_phase(bike, 19000).reverse, "il giro dopo al contrario")
	runner.check(StageMotion.hazard_rect(bike, 18500).position.x == 750.0, "al ritorno da destra a sinistra")
	runner.check(StageMotion.travel_direction(bike, 19000) == -1, "al ritorno verso sinistra")
	var arc := bike.duplicate(true)
	arc.travel.path = [{"x": 0, "y": 500}, {"x": 100, "y": 400}, {"x": 200, "y": 500}]
	arc.travel.alternate = false
	var top := StageMotion.hazard_rect(arc, 9000).position
	runner.check(is_equal_approx(top.x, 100.0) and is_equal_approx(top.y, 400.0), "segue il percorso a più punti: %s" % top)


# Getto d'acqua (#253): stesse fasi di jetPhase() in elements.test.ts
func test_getto_come_il_server() -> void:
	var jet := {"x": 450, "y": 650, "width": 100, "height": 300, "speed": 1300, "periodMs": 6000, "warnMs": 1000, "activeMs": 1000}
	runner.check(StageMotion.jet_phase(jet, 1000) == "calm", "calma")
	runner.check(StageMotion.jet_phase(jet, 4500) == "warn", "bolle")
	runner.check(StageMotion.jet_phase(jet, 5500) == "active", "getto")


# Animazione di una trappola (#270): fotogramma dal tempo dell'arena, piede sul fondo del rettangolo, specchiata a sinistra
func test_animazione_della_trappola() -> void:
	runner.check(StageMotion.hazard_frame(0, 16, 8) == 0 and StageMotion.hazard_frame(130, 16, 8) == 2, "16 fps: 130 ms = fotogramma 2")
	runner.check(StageMotion.hazard_frame(1000, 16, 8) == 0, "in ciclo: dopo 16 fotogrammi si ricomincia")
	var spr := {"scale": 0.5, "footX": 150.0, "footY": 312.0}
	var r := Rect2(100, 425, 80, 95)
	var right := StageMotion.hazard_sprite_rect(spr, 300, 320, r, 1)
	runner.check(right.position.x == 140.0 - 75.0 and right.position.y == 520.0 - 156.0 and right.size.x == 150.0, "verso destra: il piede sul centro in basso: %s" % right)
	var left := StageMotion.hazard_sprite_rect(spr, 300, 320, r, -1)
	runner.check(left.size.x == -150.0 and left.position.x == 140.0 - 75.0, "verso sinistra: specchiata sul posto: %s" % left)


# La barca disegnata (#273): guarda dove va, e da ferma verso il centro dell'arena
func test_verso_della_barca() -> void:
	var boat := {"width": 160, "path": [{"x": -560, "y": 780}, {"x": -150, "y": 780}], "periodMs": 40000, "pauseMs": 14000}
	runner.check(StageMotion.mover_facing(boat, 15000, 1920) == 1, "arriva verso destra")
	runner.check(StageMotion.mover_facing(boat, 20000, 1920) == 1, "ferma accanto alla riva sinistra: guarda il centro")
	runner.check(StageMotion.mover_facing(boat, 35000, 1920) == -1, "se ne va verso sinistra")
	var right := {"width": 160, "path": [{"x": 2380, "y": 780}, {"x": 1910, "y": 780}], "periodMs": 40000, "pauseMs": 14000}
	runner.check(StageMotion.mover_facing(right, 20000, 1920) == -1, "quella di destra, ferma, guarda a sinistra")


# Il fiore (#231): la foglia ha sette foglioline chiuse, l'alone respira e lampeggia solo alla fine
func test_foglia_e_alone_del_fiore() -> void:
	var leaflets: Array = WorldView.leaf_leaflets(30.0)
	runner.check(leaflets.size() == 7, "sette foglioline: %d" % leaflets.size())
	var middle: PackedVector2Array = leaflets[3]
	runner.check(middle[middle.size() / 2].y < -20.0, "quella centrale punta in alto: %s" % middle[middle.size() / 2])
	runner.check(Geometry2D.triangulate_polygon(middle).size() > 0, "si può riempire")
	runner.check(FighterPose.aura_alpha(0.0, 1000.0, 1500.0) == 0.0, "finito, niente alone")
	var full := [0.0, 50.0, 120.0, 240.0].map(func(now: float) -> float: return FighterPose.aura_alpha(6000.0, now, 1500.0))
	runner.check(full.all(func(a: float) -> bool: return a > 0.25), "a metà effetto sempre visibile: %s" % [full])
	runner.check(FighterPose.aura_alpha(1000.0, 0.0, 1500.0) < 0.2 and FighterPose.aura_alpha(1000.0, 130.0, 1500.0) > 0.25, "alla fine lampeggia")


# Il bong (#302): lo schermo si distorce solo per chi è fatto, e sempre di più col tempo
func test_quanto_si_e_fatti_col_bong() -> void:
	runner.check(FighterPose.high_level(null, 7000.0) == 0.0, "senza lottatore niente")
	runner.check(FighterPose.high_level({"powerup": null, "powerupMs": 0}, 7000.0) == 0.0, "senza potenziamento niente")
	runner.check(FighterPose.high_level({"powerup": "fiore", "powerupMs": 5000}, 7000.0) == 0.0, "il fiore non distorce")
	var soon := FighterPose.high_level({"powerup": "bong", "powerupMs": 7000}, 7000.0)
	var late := FighterPose.high_level({"powerup": "bong", "powerupMs": 500}, 7000.0)
	runner.check(FighterPose.high_level({"powerup": "trip", "powerupMs": 2000}, 7000.0) > 0.0, "i funghetti distorcono un po'")
	runner.check(soon > 0.0 and soon < late and late <= 1.0, "cresce col tempo: %s → %s" % [soon, late])
