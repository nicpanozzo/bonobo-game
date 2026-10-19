# Sfondi a strati delle arene con la parallasse (world_view.gd e stage_preview.gd, E12 passo 3)
extends RefCounted

var runner

const WorldView := preload("res://scripts/world_view.gd")
const StageMotion := preload("res://scripts/stage_motion.gd")
const StagePreview := preload("res://scripts/stage_preview.gd")


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func test_parallasse() -> void:
	var size := Vector2(1920, 1080)
	var world := Vector2(640, 360)
	var view := Vector2(840, 300) # la telecamera è andata a destra e in alto
	var fermo := StageMotion.layer_rect(size, 1.0, world, view)
	runner.check(fermo.get_center() == world, "parallasse 1: fermo con il palco")
	var lontano := StageMotion.layer_rect(size, 0.0, world, view)
	runner.check(lontano.get_center() == view, "parallasse 0: segue la telecamera")
	var mezzo := StageMotion.layer_rect(size, 0.5, world, view)
	runner.check(mezzo.get_center() == Vector2(740, 330), "a metà strada: %s" % mezzo.get_center())
	runner.check(mezzo.size == size, "la grandezza non cambia")
	# #400: con la parallasse verticale a 0 in verticale lo strato resta attaccato al palco, in orizzontale no
	var piatto := StageMotion.layer_rect(size, 0.5, world, view, 0.0)
	runner.check(piatto.get_center() == Vector2(740, 360), "in verticale fermo col palco: %s" % piatto.get_center())


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


# I vetri accesi di Padova si tengono solo dove ce ne sono: interi costavano tre strati in più a ogni frame di notte
func test_luci_della_notte_ritagliate() -> void:
	var game := _game()
	var w: Node2D = WorldView.new()
	w.setup(game)
	w.set_stage_spec(game.stages.padova)
	runner.check(w._light_layers.size() == 3, "tre strati di luci: %d" % w._light_layers.size())
	for k in w._light_layers:
		var part: Rect2 = w._light_layers[k][1]
		runner.check(part.size.x * part.size.y < 0.5, "strato %s ritagliato: %s" % [k, part])
		runner.check(Rect2(0, 0, 1, 1).encloses(part), "dentro allo strato: %s" % part)
	w.free()


# Sugli schermi piccoli gli strati si rimpiccioliscono al caricamento (#320), ma coprono sempre lo stesso pezzo di
# mondo: prima ai lati restava il cielo vuoto e la strada sembrava sospesa (segnalato da Riccardo su Padova)
func test_strati_rimpiccioliti_restano_grandi_uguali() -> void:
	var before: float = WorldView._screen_px_per_world
	WorldView._screen_px_per_world = 0.6 # uno schermo da portatile
	var layer: Array = WorldView._stage_layer("padova", {"file": "sfondo-1.png", "parallax": 0.45}, 0.5)
	WorldView._screen_px_per_world = before
	runner.check(layer.size() == 3, "con la grandezza vera")
	var tex: Texture2D = layer[0]
	runner.check(tex.get_size().x < (layer[2] as Vector2).x, "l'immagine è stata rimpicciolita: %s" % tex.get_size())
	runner.check(layer[2] == Vector2(4880, 2960), "ma lo strato resta 4880×2960: %s" % layer[2])


# La ruota d'acqua di Padova (#378): lo spruzzo va dalla vasca al fondo della tazza, sempre largo uguale
func test_spruzzo_sotto_le_tazze() -> void:
	var r := StageMotion.stem_rect(960.0, 300.0, 506.0, 70.0)
	runner.check(r == Rect2(925, 300, 70, 206), "dalla tazza alla vasca: %s" % r)
	runner.check(StageMotion.stem_rect(960.0, 510.0, 506.0, 70.0).size == Vector2.ZERO, "sotto la vasca niente spruzzo")
	var game := _game()
	var w: Node2D = WorldView.new()
	w.setup(game)
	w.set_stage_spec(game.stages.padova)
	runner.check(w._mover_sprites.size() == 3, "tre tazze disegnate: %d" % w._mover_sprites.size())
	runner.check(str(w._mover_sprites[0].stem.sheet) == "getto", "ognuna con il suo spruzzo")
	runner.check(w._mover_sprites[0].stem.hub is Dictionary, "i getti partono dall'ugello al centro")
	var order: Array = StageMotion.movers_back_to_front(game.stages.padova.movers, 0.0)
	runner.check(order.size() == 3, "tutte e tre le tazze si disegnano: %s" % [order])
	var dietro: Dictionary = {"width": 10, "periodMs": 1000, "loop": true, "path": [{"x": 0, "y": 100}, {"x": 0, "y": 90}]}
	var davanti: Dictionary = {"width": 10, "periodMs": 1000, "loop": true, "path": [{"x": 0, "y": 100}, {"x": 0, "y": 110}]}
	runner.check(StageMotion.movers_back_to_front([davanti, dietro], 500.0) == [1, 0], "prima quella che passa dietro")
	var jet := StageMotion.jet_curve(Vector2(960, 506), Vector2(1100, 300), 14)
	runner.check(jet.size() == 15 and jet[0] == Vector2(960, 506) and jet[14].is_equal_approx(Vector2(1100, 300)), "il getto va dall'ugello alla tazza")
	runner.check(absf(jet[1].x - 960.0) < absf(jet[1].y - 506.0), "esce dritto in su e poi si piega")
	var up: Array = StageMotion.spoke(Vector2(960, 330), Vector2(960, 200))
	runner.check(is_zero_approx(up[0]) and is_equal_approx(up[1], 130.0), "il raggio verso l'alto non si gira: %s" % [up])
	var down: Array = StageMotion.spoke(Vector2(960, 330), Vector2(960, 460))
	runner.check(is_equal_approx(down[0], PI), "quello verso il basso si capovolge: %s" % [down])
	w.free()


# Chi galleggia nel canale di Padova (#378) gira attorno all'anello: davanti grande, dietro piccolo e coperto
func test_galleggianti_girano_attorno_al_canale() -> void:
	var game := _game()
	var life: RefCounted = load("res://scripts/stage_life.gd").new()
	life.setup(game.stages.padova, 1920.0, 720.0)
	var f: Dictionary = game.stages.padova.art.life.outerWater.floaters
	var a: Array = life.floaters_at(f, 0.0)
	runner.check(a.size() == 2, "la bici e l'ubriaco: %d" % a.size())
	runner.check(a[0].under, "in punta all'isola passa sotto il ponte di profilo")
	var mid: Array = life.floaters_at(f, float(f.lapMs) * 0.75)
	runner.check(mid[0].front and not mid[0].under, "davanti al centro si vede: %s" % [mid[0]])
	var seen_front := false
	var seen_back := false
	for i in 40:
		for p in life.floaters_at(f, i * float(f.lapMs) / 40.0):
			var dx := (float(p.x) - float(f.cx)) / float(f.rx)
			var dy := (float(p.y) - float(f.cy)) / float(f.ry)
			runner.check(absf(dx * dx + dy * dy - 1.0) < 0.01, "sempre sull'anello")
			if p.front:
				seen_front = true
				runner.check(is_equal_approx(float(p.k), 1.0) or float(p.k) > 0.7, "davanti è grande")
			else:
				seen_back = true
				runner.check(float(p.k) < 0.75, "dietro è più piccolo")
	runner.check(seen_front and seen_back, "passa davanti e dietro l'isola")


# Il piano dell'isola di Padova e la vasca non fanno ombra a terra (#378): era una striscia grigia sul bordo
func test_pavimento_senza_ombra() -> void:
	var game := _game()
	var seen := 0
	for pr in game.stages.padova.art.props:
		if str(pr.file) in ["piano.png", "fontana.png"]:
			seen += 1
			runner.check(not WorldView.prop_casts_shadow(pr), "%s senza ombra" % pr.file)
		elif str(pr.file) == "platano.png":
			runner.check(WorldView.prop_casts_shadow(pr), "i platani l'ombra la fanno")
	runner.check(seen == 2, "il piano e la vasca: %d" % seen)


# Sugli schermi piccoli anche i fogli dei lottatori si rimpiccioliscono al caricamento (#320): il fotogramma va preso
# in proporzione, se no si vedeva un pezzo di quello accanto, come un secondo lottatore tagliato di fianco
func test_fotogrammi_dei_fogli_rimpiccioliti() -> void:
	runner.check(WorldView.frame_region(2.0, 1.0, 100.0, 50.0, 0.5) == Rect2(100, 25, 50, 25), "il riquadro in proporzione")
	runner.check(WorldView.frame_region(3.0, 0.0, 336.0, 368.0, 1.0) == Rect2(1008, 0, 336, 368), "intero com'era")
	# una texture grande la metà del PNG (in CI senza schermo il gioco non rimpicciolisce: la si fa a mano)
	var path := "res://data/assets/stages/padova/auto.png"
	var raw: Texture2D = load(path)
	var half := ImageTexture.create_from_image(Image.create(raw.get_width() / 2, raw.get_height() / 2, false, Image.FORMAT_RGBA8))
	runner.check(is_equal_approx(WorldView._kept(half, path), 0.5), "rimpicciolito a metà: %s" % WorldView._kept(half, path))
	runner.check(is_equal_approx(WorldView._kept(raw, path), 1.0), "intero resta 1")


# Lo sfondo vivo segue la stessa parallasse verticale degli strati (#400): se no passanti e traffico si staccherebbero
func test_sfondo_vivo_con_la_parallasse_verticale() -> void:
	var life: RefCounted = load("res://scripts/stage_life.gd").new()
	life.setup({"art": {"verticalParallax": 0.0}}, 1920.0, 720.0)
	runner.check(life.offset(0.5, Vector2(1160, 160)) == Vector2(100, 0), "in verticale niente: %s" % life.offset(0.5, Vector2(1160, 160)))
	life.setup({"art": {}}, 1920.0, 720.0)
	runner.check(life.offset(0.5, Vector2(1160, 160)) == Vector2(100, -100), "senza il campo come prima")

