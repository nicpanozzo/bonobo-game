# Sfondi a strati delle arene con la parallasse (world_view.gd e stage_preview.gd, E12 passo 3)
extends RefCounted

var runner

const WorldView := preload("res://scripts/world_view.gd")
const StagePreview := preload("res://scripts/stage_preview.gd")


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func test_parallasse() -> void:
	var size := Vector2(1920, 1080)
	var world := Vector2(640, 360)
	var view := Vector2(840, 300) # la telecamera è andata a destra e in alto
	var fermo := WorldView.layer_rect(size, 1.0, world, view)
	runner.check(fermo.get_center() == world, "parallasse 1: fermo con il palco")
	var lontano := WorldView.layer_rect(size, 0.0, world, view)
	runner.check(lontano.get_center() == view, "parallasse 0: segue la telecamera")
	var mezzo := WorldView.layer_rect(size, 0.5, world, view)
	runner.check(mezzo.get_center() == Vector2(740, 330), "a metà strada: %s" % mezzo.get_center())
	runner.check(mezzo.size == size, "la grandezza non cambia")


func test_il_palco_ha_tre_strati_le_altre_arene_no() -> void:
	var game := _game()
	var w: Node2D = WorldView.new()
	w.setup(game)
	w.set_stage_spec(game.stages.palco)
	runner.check(w._layers.size() == 3, "tre strati: %d" % w._layers.size())
	runner.check(w._layers[0][1] < w._layers[2][1], "dal più lontano al più vicino")
	runner.check((w._layers[0][0] as Texture2D).get_size() == Vector2(1920, 1080), "1920×1080")
	w.set_stage_spec(game.stages.isole)
	runner.check(w._layers.is_empty() and w._foreground.is_empty(), "Le Isole restano con i colori")
	# Un file che manca non rompe niente: si vede il colore del cielo
	var spec: Dictionary = game.stages.palco.duplicate(true)
	spec.art.layers.append({"file": "non-esiste.png", "parallax": 0.9})
	spec.art.foreground = {"file": "non-esiste.png", "parallax": 1.0}
	w.set_stage_spec(spec)
	runner.check(w._layers.size() == 3 and w._foreground.is_empty(), "strato mancante saltato")
	w.free()


func test_anteprima_nella_lobby() -> void:
	var game := _game()
	runner.check(StagePreview.preview_texture(game.stages.palco) is Texture2D, "Il Palco ha l'anteprima disegnata")
	runner.check(StagePreview.preview_texture(game.stages.isole) == null, "Le Isole no")


func test_arena_casuale_con_lo_sfondo_condiviso() -> void:
	var game := _game()
	var w: Node2D = WorldView.new()
	w.setup(game)
	# Come arriva dal server nel benvenuto (generateStage): la cartella è quella condivisa, non l'id
	var spec: Dictionary = game.stages.palco.duplicate(true)
	spec.id = "casuale-42"
	spec.art = {"dir": "generica", "layers": [{"file": "sfondo-0.png", "parallax": 0.15}, {"file": "sfondo-1.png", "parallax": 0.5}]}
	w.set_stage_spec(spec)
	runner.check(w._layers.size() == 2, "due strati: %d" % w._layers.size())
	w.free()
