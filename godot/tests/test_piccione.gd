# Elvedeo: il Piccione vola col suo disegno ritagliato dal video, e nella suprema l'Elefante cresce
extends RefCounted

var runner

const FighterPose := preload("res://scripts/fighter_pose.gd")


func test_il_proiettile_ha_il_suo_disegno() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.open("res://data/game.json", FileAccess.READ).get_as_text())
	var art: Variant = FighterPose.projectile_special(game, "elvedeo", "specialNeutral").get("sprite")
	runner.check(art is Dictionary, "la speciale neutra di Elvedeo ha un disegno")
	if not (art is Dictionary):
		return
	var path := "res://data/%s" % art.path
	runner.check(ResourceLoader.exists(path), "il PNG del piccione è in godot/data")
	var tex: Texture2D = load(path)
	runner.check(tex != null and tex.get_height() == int(art.frameHeight), "alto un fotogramma")
	runner.check(tex != null and tex.get_width() % int(art.frameWidth) == 0, "fotogrammi interi in fila")
	runner.check(FighterPose.projectile_special(game, "bonobot", "specialNeutral").get("sprite") == null, "gli altri restano ovali")


func test_l_elefante_cresce_e_torna_normale() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.open("res://data/game.json", FileAccess.READ).get_as_text())
	var elvedeo: Dictionary = game.characters.elvedeo
	var sp: Dictionary = elvedeo.supreme
	var during := float(sp.windupMs) + float(sp.durationMs) / 2.0
	runner.check(is_equal_approx(FighterPose.supreme_grow(elvedeo, "supreme", 0.0), 1.0), "all'inizio normale")
	runner.check(is_equal_approx(FighterPose.supreme_grow(elvedeo, "supreme", during), float(sp.grow)), "grande mentre pesta")
	runner.check(is_equal_approx(FighterPose.supreme_grow(elvedeo, "supreme", float(sp.windupMs) + float(sp.durationMs) + 300.0), 1.0), "poi torna normale")
	runner.check(is_equal_approx(FighterPose.supreme_grow(elvedeo, "heavy", during), 1.0), "solo nella suprema")
	runner.check(is_equal_approx(FighterPose.supreme_grow(game.characters.bradipo, "supreme", during), 1.0), "gli altri non crescono")


func test_l_aquila_della_suprema_ha_il_suo_disegno() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.open("res://data/game.json", FileAccess.READ).get_as_text())
	var pr := {"characterId": "elvedeo", "kind": "specialNeutral", "supreme": true}
	var eagle := FighterPose.projectile_of(game, pr)
	runner.check(eagle.get("name") == "Aquila", "il proiettile della suprema è l'aquila")
	pr.erase("supreme")
	runner.check(FighterPose.projectile_of(game, pr).get("name") == "Piccione", "quello della speciale resta il piccione")
	var art: Dictionary = eagle.get("sprite", {})
	runner.check(ResourceLoader.exists("res://data/%s" % art.get("path", "")), "il PNG dell'aquila è in godot/data")
	# la suprema senza aquila: gli stessi fotogrammi della suprema, uno per uno
	var after: Texture2D = load("res://data/%s" % eagle.after)
	var sheet: Dictionary = game.characters.elvedeo.sprite
	var supreme: Texture2D = load("res://data/%s/supreme.png" % sheet.dir)
	runner.check(after != null and supreme != null and after.get_size() == supreme.get_size(), "suprema senza aquila grande come la suprema")


func test_il_proiettile_guarda_dove_va() -> void:
	runner.check(is_equal_approx(FighterPose.projectile_tilt(Vector2(300, 0)), 0.0), "dritto")
	runner.check(FighterPose.projectile_tilt(Vector2(300, 200)) > 0.0, "a destra in picchiata: muso giù")
	runner.check(FighterPose.projectile_tilt(Vector2(-300, 200)) < 0.0, "a sinistra in picchiata: specchiato")
	runner.check(absf(FighterPose.projectile_tilt(Vector2(10, 900))) <= 0.6, "mai di più di 35 gradi")
