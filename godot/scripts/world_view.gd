# Disegna l'arena, i lottatori e qualche effetto sugli eventi. Non decide niente:
# legge solo gli snapshot (interpolati) e gli eventi che arrivano dal server.
extends Node2D

# I numeri degli effetti stanno in EFFECTS (constants.ts), letti da game.effects
var game: Dictionary # godot/data/game.json
var stage: Dictionary
var my_id := ""
var buffer := SnapshotBuffer.new()
var predictor := Predictor.new() # il proprio lottatore previsto (E17 passo 4)
var player_ids: Array = []

var positions := {} # id -> Vector2 dei piedi, come disegnati all'ultimo frame (per la telecamera)
var _alive: Array = [] # id dei lottatori disegnati all'ultimo frame
var _sampled := {} # id -> stato interpolato di questo frame, calcolato una volta sola in _draw
var _reached := 0 # checkpoint della Corsa presi da me
var _sparks: Array = [] # [{ x, y, age, size, color }]
var _shake := 0.0
var _flash := 0.0 # ms di lampo bianco rimasti
var _dust: Array = [] # [{ x, y, dx, age }] sbuffi di polvere
var _trails := {} # id -> Array[Vector2] delle ultime posizioni, per la scia di chi vola
var _clouds: Array = [] # [{ x, y, dir, age, damage }] nuvole soffiate col bong (#302)
var _high_overlay: ColorRect # lo schermo distorto di chi è fatto col bong (#302)
var effects := true # scie e polvere (opzioni → Video), main.gd lo legge dalle preferenze
var _beams: Array = [] # [{ x, y, age, color }] raggi dei KO, dal punto di uscita verso il centro
var _shards: Array = [] # [{ x, y, vx, vy, age, color }] schegge di uno scudo rotto (#109)
var _shield_hits := {} # id giocatore -> ms da quando lo scudo ha parato un colpo
var _reactions := {} # id giocatore -> reazione procedurale all'ultimo colpo preso (#305)
var _items: Array = [] # oggetti dell'ultimo snapshot (#17)
var _projectiles: Array = [] # proiettili delle speciali dell'ultimo snapshot (E10)
var _projectiles_ms := 0 # quando è arrivato: tra uno snapshot e l'altro volano con la loro velocità
var _puddles: Array = [] # pozze di merda dell'IRA di Lendmar a terra (#13)
var _companions: RefCounted = preload("res://scripts/companion_view.gd").new() # il beagle di Lampione (#369)
var _item_pos := {} # id oggetto -> Vector2 disegnata, che insegue quella dello snapshot
var _facings := {} # id giocatore -> verso, per mettere in mano gli oggetti
var _font: Font = ThemeDB.fallback_font
var view_rect := Rect2(0, 0, 1280, 720) # la parte di mondo che si vede, decisa dalla telecamera in main.gd
var _layers: Array = [] # strati dello sfondo dell'arena (E12), dal più lontano: [texture, parallasse]
var _foreground: Array = [] # strato davanti ai lottatori, o []
var _layer_scale := 1.0 # pixel di mondo per pixel delle immagini degli strati
var _skins := {} # materiali del palco (#237): nome -> {tex, edge, depth, rails}
var _fan := PackedInt32Array() # indici dei triangoli a ventaglio delle ombre, per _draw_convex
var _props_back: Array = [] # decorazioni dietro ai lottatori (#237): [texture, decorazione, y della superficie sotto]
var _props_front: Array = [] # e davanti
var _hazard_sprites := {} # indice della trappola -> {tex, frames, fps, scale, footX, footY}: animazioni disegnate (#270)
var _mover_sprites := {} # indice della piattaforma mobile -> come sopra (#273)
var _light_layers := {} # parallasse -> [Texture2D, Rect2]: i vetri accesi di quello strato (#288), ritagliati; Rect2 in frazioni dello strato
var _light_props: Array = [] # [texture, decorazione] con i vetri accesi, sopra le decorazioni (#288)
var _life: RefCounted = preload("res://scripts/stage_life.gd").new() # sfondo vivo (#260)
var _ambient := Color.WHITE # luce del momento del giorno (#267): moltiplica strati e decorazioni, un po' il palco
var _textures := {} # id personaggio -> Texture2D dello spritesheet (nel formato cartella, quella di idle)
var _state_textures := {} # id personaggio -> { stato: Texture2D }, solo per il formato cartella (E7 passo 2)
var _anims := {} # id giocatore -> { name, since }: animazione in corso e da quando
var show_hitboxes := false # allenamento (E15): corpo dei lottatori visibile anche sopra gli sprite
var attack_boxes := true # rettangolo del colpo in corso (opzioni → Video), main.gd lo legge dalle preferenze
var _air_jumps := {} # id giocatore -> quando ha fatto il doppio salto (ms), per l'animazione doubleJump (#103)
var _taunts := {} # id giocatore -> quando ha provocato (ms), per l'animazione taunt (E7)
var _supreme_ready := {} # id giocatore -> true se aveva la suprema pronta all'ultimo disegno: al passaggio un'onda dorata
var _holding := {} # id di chi tiene qualcuno con la presa (#109), dall'ultimo snapshot
var _palette := {} # colori dell'arena già convertiti (stage.colors), per non rifarlo a ogni frame
var _variants := {} # id giocatore -> variante di colore (0 = originale), ricalcolata a ogni snapshot (E11)
const StageMotion := preload("res://scripts/stage_motion.gd")
const FighterPose := preload("res://scripts/fighter_pose.gd")
const HitReaction := preload("res://scripts/hit_reaction.gd") # il corpo si piega dove è colpito (#305)
const SunLight := preload("res://scripts/sun_light.gd") # luce e ombre del sole e della luna (#288)
static var _screen_px_per_world := 0.0 # pixel dello schermo per pixel di mondo alla telecamera più vicina; 0 = non si sa (headless)
var _character_sprites := {} # id personaggio -> true quando i suoi sprite sono caricati
var _looks := {} # "<personaggio>/<skin>" -> il suo disegno (FighterPose.look), #339
var _supreme_view: Node2D # liana, orsogufo e gnomo della suprema di Bonobot (#102), disegnati sopra i lottatori
var _speech: Node2D # i fumetti con le battute dei lottatori (speech_bubbles.gd), sopra a tutto
const SpeechBubbles := preload("res://scripts/speech_bubbles.gd")
var _spin_view: Node2D # i vortici della suprema che gira (DEMACIAAA di Bradipo Giallo, #358)
var _grab_view: Node2D # il braccio della suprema che afferra (snaack di Lampione, #358)
var _burst_view: Node2D # la vampata della suprema a raffiche (IRA di Lendmar, #358)
var _rewind_view: Node2D # l'orologio della suprema che torna indietro (…COSA? di Marcomunista, #358)


func setup(game_data: Dictionary) -> void:
	game = game_data
	_supreme_view = preload("res://scripts/supreme_view.gd").new()
	_supreme_view.game = game
	_supreme_view.impact.connect(func(strength: float): _shake = maxf(_shake, strength)) # l'orsogufo tocca terra
	add_child(_supreme_view)
	_speech = SpeechBubbles.new()
	_speech.where = func(id: String) -> Variant:
		var p: Variant = buffer.sample(id, Time.get_ticks_msec())
		return Vector2(p.x, float(p.y) - float(game.fighter.height) * 1.15) if p != null and not p.eliminated else null
	add_child(_speech)
	_spin_view = preload("res://scripts/supreme_spin_view.gd").new()
	_spin_view.where = func(id: String) -> Variant:
		var p: Variant = buffer.sample(id, Time.get_ticks_msec())
		return Vector2(p.x, p.y) if p != null and not p.eliminated else null
	add_child(_spin_view)
	_grab_view = preload("res://scripts/supreme_grab_view.gd").new()
	_grab_view.fighter_width = float(game.fighter.width)
	_grab_view.fighter_height = float(game.fighter.height)
	_grab_view.where = func(id: String) -> Variant:
		var p: Variant = buffer.sample(id, Time.get_ticks_msec())
		return p if p != null and not p.eliminated else null
	add_child(_grab_view)
	_burst_view = preload("res://scripts/supreme_burst_view.gd").new()
	_burst_view.fighter_height = float(game.fighter.height)
	_burst_view.where = _spin_view.where
	add_child(_burst_view)
	_rewind_view = preload("res://scripts/supreme_rewind_view.gd").new()
	_rewind_view.fighter_height = float(game.fighter.height)
	_rewind_view.where = _spin_view.where
	add_child(_rewind_view)
	_high_overlay = ColorRect.new()
	var fatto := ShaderMaterial.new()
	fatto.shader = load("res://shaders/fatto.gdshader")
	_high_overlay.material = fatto
	_high_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_high_overlay.visible = false
	add_child(_high_overlay)
	predictor.setup(game)
	reset()
	if material == null:
		var palette := ShaderMaterial.new()
		palette.shader = load("res://shaders/palette.gdshader")
		material = palette
	# Al massimo quanti pixel dello schermo copre un pixel di mondo (#320): lo schermo intero
	# alla telecamera più vicina. Le immagini più fini di così si rimpiccioliscono al caricamento
	var screen := float(DisplayServer.screen_get_size().x) * DisplayServer.screen_get_scale()
	_screen_px_per_world = screen / float(game.world.width) * float(game.get("camera", {}).get("maxZoom", 1.0)) if screen > 0.0 else 0.0
	_character_sprites = {}


# Gli sprite di un personaggio si caricano quando entra in partita, non tutti all'avvio (#320):
# i fogli di Bonobot da soli occupano centinaia di MB di memoria video
func _load_character(c: Dictionary) -> void:
	var id: String = c.get("id", "")
	if id == "" or _character_sprites.has(id):
		return
	_character_sprites[id] = true
	if c.get("sprite") == null:
		return
	var filter: String = c.sprite.get("filter", "linear")
	var k := float(c.sprite.get("scale", 1.0))
	if c.sprite.has("dir"):
		# Formato cartella: un PNG per stato, <dir>/<stato>.png, con i fotogrammi in fila.
		# Nella tabella ci sono tutti gli stati; quelli senza disegno puntano a quello del ripiego (src)
		var states := {}
		for state in c.sprite.animations:
			var src: String = c.sprite.animations[state].src
			if not states.has(src):
				states[src] = _sprite_texture("res://data/%s/%s.png" % [c.sprite.dir, src], filter, k)
		_state_textures[id] = states
		_textures[id] = states.idle
	else:
		_textures[id] = _sprite_texture("res://data/" + c.sprite.path, filter, k)


# Il disegno di un giocatore, con la sua skin (#339): si tiene da parte, perché si chiede a ogni frame
func _look(p: Dictionary) -> Dictionary:
	var key := "%s/%s" % [p.get("characterId", ""), FighterPose.skin_of(p)]
	if not _looks.has(key):
		_looks[key] = FighterPose.look(game, str(p.get("characterId", "")), FighterPose.skin_of(p))
	return _looks[key]


# La texture di uno sprite con il suo filtro: lineare con mipmap per l'illustrato, così rimpicciolito
# dalla telecamera non sfarfalla; nearest per la pixel art, che resta a quadretti netti (E7 passo 3)
# world_scale = pixel di mondo per pixel dell'immagine: con lo schermo piccolo l'immagine si rimpicciolisce (#320),
# così non occupa memoria video e banda per dettagli che non si vedono (gli sfondi di Padova sono 4880x2960)
static func _sprite_texture(path: String, filter: String, world_scale := 0.0) -> Texture2D:
	var tex: Texture2D = load(path)
	var canvas := CanvasTexture.new()
	if filter == "nearest":
		canvas.diffuse_texture = tex
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return canvas
	var img := tex.get_image()
	if img == null or img.is_compressed(): # una texture compressa per la GPU non si rifà: resta senza mipmap
		return tex
	var keep := minf(1.0, _screen_px_per_world * world_scale)
	if keep > 0.0 and keep < 0.9:
		img.resize(maxi(1, roundi(img.get_width() * keep)), maxi(1, roundi(img.get_height() * keep)), Image.INTERPOLATE_CUBIC)
	img.generate_mipmaps()
	canvas.diffuse_texture = ImageTexture.create_from_image(img)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return canvas


# Si torna alla lobby: via i giocatori della stanza di prima
func reset() -> void:
	buffer = SnapshotBuffer.new()
	buffer.delay_ms = game.net.interpolationDelayMs
	buffer.teleport_distance = game.net.teleportDistance
	buffer.size = int(game.net.bufferSize)
	buffer.own_extrapolate_ms = float(game.net.get("ownExtrapolateMaxMs", 0.0))
	player_ids = []
	positions = {}
	_anims = {}
	_air_jumps = {}
	_taunts = {}
	_sparks = []
	_clouds = []
	_beams = []
	_shards = []
	_shield_hits = {}
	_reactions = {}
	_items = []
	_projectiles = []
	_puddles = []
	_companions.clear()
	_item_pos = {}
	_dust = []
	_trails = {}
	_flash = 0.0
	_supreme_view.clear()
	_speech.clear()
	_spin_view.clear()
	_grab_view.clear()
	_burst_view.clear()
	_rewind_view.clear()
	my_id = ""
	predictor.reset()
	set_stage(game.defaultStageId)


func set_stage(stage_id: String) -> void:
	set_stage_spec(game.stages.get(stage_id, game.stages[game.defaultStageId]))


# L'arena intera arriva dal server nel benvenuto: così si vedono anche le arene casuali e i percorsi
func set_stage_spec(spec: Dictionary) -> void:
	stage = spec
	predictor.set_stage(spec)
	_palette = {}
	for k in spec.get("colors", {}):
		_palette[k] = _color(spec.colors[k])
	_layers = []
	_foreground = []
	var art: Dictionary = spec.get("art", {})
	for l in art.get("layers", []):
		var layer := _stage_layer(art.get("dir", spec.id), l, float(art.get("scale", 1.0)))
		if not layer.is_empty():
			_layers.append(layer)
	if art.has("foreground"):
		_foreground = _stage_layer(art.get("dir", spec.id), art.foreground, float(art.get("scale", 1.0)))
	_layer_scale = art.get("scale", 1.0)
	_load_stage_dressing(art.get("dir", spec.id), art)
	_life.setup(spec, stage_width(), game.world.height)
	_supreme_view.stage = spec
	_reached = 0
	queue_redraw()


# Quanto è salita l'acqua alta che l'acqua intorno all'arena segue (0 bassa, 1 alta), #264
func _flood_up(t: float) -> float:
	var art: Dictionary = stage.get("art", {}) if stage.get("art") is Dictionary else {}
	var w: Variant = art.get("life", {}).get("outerWater") if art.get("life") is Dictionary else null
	var hazards: Array = stage.get("hazards", []) if stage.get("hazards") is Array else []
	if not w is Dictionary or w.get("flood") == null or int(w.flood) >= hazards.size():
		return 0.0
	var h: Dictionary = hazards[int(w.flood)]
	var r := StageMotion.hazard_rect(h, t)
	var low: float = h.y
	var high: float = h.get("flood", {}).get("highY", low)
	return clampf((low - r.position.y) / (low - high), 0.0, 1.0) if high != low else 0.0


# Quanto piove adesso (0-1), per gli ombrelli dello sfondo vivo (#260)
func _rain_now(t: float) -> float:
	var rain := 0.0
	for h in stage.get("hazards", []) if stage.get("hazards") is Array else []:
		rain = maxf(rain, StageMotion.rain_strength(h, t))
	var art: Dictionary = stage.get("art", {}) if stage.get("art") is Dictionary else {}
	var life: Dictionary = art.get("life", {}) if art.get("life") is Dictionary else {}
	if life.get("rain") is Dictionary:
		rain = maxf(rain, StageMotion.life_rain(life.rain, t))
	return rain


# Dove passa adesso una trappola che viaggia: i piccioni scappano anche dal ciclista (#260)
func _threats(t: float) -> Array:
	var out := []
	for h in stage.get("hazards", []) if stage.get("hazards") is Array else []:
		if h.get("travel") is Dictionary and StageMotion.travel_phase(h, t).phase == "cross":
			out.append(StageMotion.hazard_rect(h, t))
	return out


# Materiali e decorazioni del palco (#237): si caricano una volta, quando si sceglie l'arena
func _load_stage_dressing(dir: String, art: Dictionary) -> void:
	_skins = {}
	_props_back = []
	_props_front = []
	var skins: Dictionary = art.get("skins", {}) if art.get("skins") is Dictionary else {}
	for name in skins:
		var k: Dictionary = skins[name]
		var tex := _stage_texture(dir, k.file)
		if tex == null:
			continue
		var rails: Array = []
		for r in k.get("rails", []):
			var rt := _stage_texture(dir, r.file)
			if rt != null:
				rails.append({"tex": rt, "height": float(r.height), "offsetY": float(r.get("offsetY", 0)), "front": bool(r.get("front", false)), "opacity": float(r.get("opacity", 1.0))})
		_skins[name] = {"tex": tex, "edge": _stage_texture(dir, k.edge) if k.get("edge") != null else null, "depth": float(k.get("depth", 12)), "rails": rails}
	for pr in art.get("props", []):
		var tex := _stage_texture(dir, pr.file)
		if tex != null:
			# Il palco non si sposta: la superficie sotto la decorazione (per la sua ombra) si cerca una volta sola
			(_props_front if pr.get("front", false) else _props_back).append([tex, pr, _surface_below(float(pr.x), float(pr.y) - 6.0)])
	_hazard_sprites = {}
	for hs in art.get("hazardSprites", []):
		var tex := _stage_texture(dir, hs.file)
		if tex != null:
			_hazard_sprites[int(hs.hazard)] = {"tex": tex, "frames": int(hs.frames), "fps": float(hs.fps), "scale": float(hs.get("scale", 1.0)),
				"footX": float(hs.get("footX", tex.get_width() / float(hs.frames) / 2.0)), "footY": float(hs.get("footY", tex.get_height())),
				"shout": hs.get("shout") if hs.get("shout") is Dictionary else {}}
	_mover_sprites = {}
	for ms in art.get("moverSprites", []):
		var tex := _stage_texture(dir, ms.file)
		if tex != null:
			_mover_sprites[int(ms.mover)] = {"tex": tex, "frames": int(ms.frames), "fps": float(ms.fps), "scale": float(ms.get("scale", 1.0)),
				"footX": float(ms.get("footX", tex.get_width() / float(ms.frames) / 2.0)), "footY": float(ms.get("footY", tex.get_height()))}
	# Luci della notte precise (#288): strati e decorazioni con solo i vetri accesi
	_light_layers = {}
	_light_props = []
	var life: Dictionary = art.get("life", {}) if art.get("life") is Dictionary else {}
	var day: Dictionary = life.get("daycycle", {}) if life.get("daycycle") is Dictionary else {}
	for ll in day.get("lightLayers", []):
		var lit := _lit_texture(dir, ll.file, _layer_scale)
		if not lit.is_empty():
			_light_layers[snappedf(float(ll.parallax), 0.001)] = lit
	for lp in day.get("lightProps", []):
		var tex := _stage_texture(dir, lp.file)
		if tex != null:
			_light_props.append([tex, lp])


static func _stage_texture(dir: String, file: String, world_scale := 0.0) -> Texture2D:
	var path := "res://data/assets/stages/%s/%s" % [dir, file]
	if not ResourceLoader.exists(path):
		push_warning("Immagine dell'arena mancante: " + path)
		return null
	return _sprite_texture(path, "linear", world_scale)


# I vetri accesi di uno strato sono grandi quanto lo strato ma quasi tutti trasparenti: disegnarli interi di notte
# costava tre strati in più da fondere a ogni frame (gli fps calavano al tramonto). Si tiene solo la parte con qualcosa,
# con la sua posizione in frazioni dello strato. [] se manca il file
static func _lit_texture(dir: String, file: String, world_scale := 0.0) -> Array:
	var path := "res://data/assets/stages/%s/%s" % [dir, file]
	if not ResourceLoader.exists(path):
		push_warning("Immagine dell'arena mancante: " + path)
		return []
	var img: Image = (load(path) as Texture2D).get_image()
	if img == null or img.is_compressed():
		return [_sprite_texture(path, "linear", world_scale), Rect2(0, 0, 1, 1)]
	var full := Vector2(img.get_size())
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return [] # niente da accendere
	var part := img.get_region(used)
	var keep := minf(1.0, _screen_px_per_world * world_scale)
	if keep > 0.0 and keep < 0.9:
		part.resize(maxi(1, roundi(part.get_width() * keep)), maxi(1, roundi(part.get_height() * keep)), Image.INTERPOLATE_CUBIC)
	part.generate_mipmaps()
	var canvas := CanvasTexture.new()
	canvas.diffuse_texture = ImageTexture.create_from_image(part)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return [canvas, Rect2(Vector2(used.position) / full, Vector2(used.size) / full)]


# Il materiale di un pezzo: l'eccezione in art.pieces (null = tinta unita), o quello di base; {} se non c'è
func _skin_for(kind: String, i: int) -> Dictionary:
	var art: Dictionary = stage.get("art", {}) if stage.get("art") is Dictionary else {}
	var name: Variant = art.get("solidSkin" if kind == "solids" else "platformSkin")
	var pieces: Variant = art.get("pieces")
	if pieces is Dictionary and pieces.get(kind) is Array and i < pieces[kind].size():
		name = pieces[kind][i]
	if name == null or not _skins.has(name):
		return {}
	return _skins[name]


# Il palco prende solo un po' della luce del momento (#267): di notte resta ben leggibile
func _stage_light() -> Color:
	return Color.WHITE.lerp(_ambient, 0.4)


# Un PNG ripetuto dentro un rettangolo, a _layer_scale pixel di mondo per pixel; l'ultima fila e colonna si tagliano
func _draw_tiled(tex: Texture2D, rect: Rect2, mod := Color.WHITE) -> void:
	mod *= _stage_light()
	var tw := tex.get_width() * _layer_scale
	var th := tex.get_height() * _layer_scale
	if tw <= 0 or th <= 0:
		return
	var y := rect.position.y
	while y < rect.end.y - 0.01:
		var h := minf(th, rect.end.y - y)
		var x := rect.position.x
		while x < rect.end.x - 0.01:
			var w := minf(tw, rect.end.x - x)
			draw_texture_rect_region(tex, Rect2(x, y, w, h), Rect2(0, 0, w / _layer_scale, h / _layer_scale), mod)
			x += tw
		y += th


# Un PNG ripetuto lungo la superficie di una piattaforma (dritta, ad arco o inclinata), a colonne strette:
# ogni colonna sta all'altezza della superficie in quel punto più top, ed è alta height
func _draw_strip(tex: Texture2D, p: Dictionary, top: float, height: float, mod := Color.WHITE) -> void:
	mod *= _stage_light()
	var src_w := float(tex.get_width())
	var cw := 6.0 if PredictMovement.curved(p) else float(p.width)
	var x: float = p.x
	var end: float = float(p.x) + float(p.width)
	while x < end - 0.01:
		var w := minf(cw, end - x)
		var y := PredictMovement.surface_y(p, x + w / 2.0) + top
		# La texture si ripete in orizzontale ogni src_w × _layer_scale pixel di mondo
		var u := fposmod((x - float(p.x)) / _layer_scale, src_w)
		var left := w
		var dx := x
		while left > 0.01:
			var piece := minf(left, (src_w - u) * _layer_scale)
			draw_texture_rect_region(tex, Rect2(dx, y, piece, height), Rect2(u, 0, piece / _layer_scale, tex.get_height()), mod)
			dx += piece
			left -= piece
			u = 0.0
		x += w


func _draw_skinned_solid(s: Dictionary, skin: Dictionary) -> void:
	_draw_tiled(skin.tex, Rect2(s.x, s.y, s.width, s.height))
	if skin.edge != null:
		_draw_tiled(skin.edge, Rect2(s.x, s.y, s.width, minf(skin.edge.get_height() * _layer_scale, s.height)))


func _draw_skinned_platform(p: Dictionary, skin: Dictionary) -> void:
	var edge: Variant = skin.edge
	if p.get("y2") != null:
		# Scala (#246): ogni gradino è un blocco del materiale, con il bordo sulla pedata
		var rise := absf(float(p.y2) - float(p.y))
		var n := maxi(2, int(rise / 14.0))
		var step := float(p.width) / n
		var bottom := maxf(float(p.y), float(p.y2))
		for i in n:
			var x0: float = float(p.x) + step * i
			var top := maxf(PredictMovement.surface_y(p, x0), PredictMovement.surface_y(p, x0 + step))
			var h := minf(rise / n + 6.0, bottom - top)
			if h > 0:
				_draw_tiled(skin.tex, Rect2(x0, top, step + 0.5, h))
				if edge != null:
					_draw_tiled(edge, Rect2(x0, top, step + 0.5, minf(edge.get_height() * _layer_scale, h)))
		return
	_draw_strip(skin.tex, p, 0.0, skin.depth)
	if edge != null:
		_draw_strip(edge, p, 0.0, minf(edge.get_height() * _layer_scale, skin.depth))


# Ringhiere (#237) di tutte le piattaforme col materiale che le ha: dietro (front = false) o davanti ai lottatori
func _draw_rails(front: bool) -> void:
	for i in stage.platforms.size():
		var skin := _skin_for("platforms", i)
		if skin.is_empty():
			continue
		for r in skin.rails:
			if r.front == front:
				_draw_strip(r.tex, stage.platforms[i], r.offsetY - r.height, r.height, Color(1, 1, 1, r.opacity))


# Decorazioni ferme (#237): i piedi (centro del lato basso) in x, y
func _draw_props(list: Array) -> void:
	for entry in list:
		var tex: Texture2D = entry[0]
		var pr: Dictionary = entry[1]
		var k: float = float(pr.get("scale", _layer_scale))
		var size := tex.get_size() * k
		var rect := Rect2(float(pr.x) - size.x / 2.0, float(pr.y) - size.y, size.x, size.y)
		if pr.get("flip", false):
			rect.size.x = -size.x # con la larghezza negativa Godot la specchia restando nello stesso posto
		draw_texture_rect(tex, rect, false, Color(_ambient.r, _ambient.g, _ambient.b, float(pr.get("opacity", 1.0))))


# Uno strato dello sfondo (E12): [texture, parallasse], o [] se il file non c'è (si vede il colore del cielo)
static func _stage_layer(dir: String, layer: Dictionary, world_scale := 0.0) -> Array:
	var path := "res://data/assets/stages/%s/%s" % [dir, layer.file]
	if not ResourceLoader.exists(path):
		push_warning("Sfondo mancante: " + path)
		return []
	# La grandezza vera del PNG: sugli schermi piccoli _sprite_texture lo rimpicciolisce (#320), ma lo strato
	# deve coprire lo stesso pezzo di mondo, se no ai lati resta il cielo vuoto
	var full := (load(path) as Texture2D).get_size()
	return [_sprite_texture(path, "linear", world_scale), clampf(layer.parallax, 0.0, 1.0), full]


func _draw_layer(layer: Array, mod := Color(-1, 0, 0)) -> void:
	var tex: Texture2D = layer[0]
	var size: Vector2 = layer[2] if layer.size() > 2 else tex.get_size()
	var center := Vector2(stage_width() / 2.0, game.world.height / 2.0)
	draw_texture_rect(tex, StageMotion.layer_rect(size * _layer_scale, layer[1], center, view_rect.get_center()), false, _ambient if mod.r < 0.0 else mod)


# Piedi dei lottatori in gioco (non eliminati), per la telecamera
func alive_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for id in _alive:
		if positions.has(id):
			out.append(positions[id])
	return out


# Larghezza del mondo: lo schermo, o di più per i percorsi della Corsa (stageWidth in stages.ts)
func stage_width() -> float:
	var w: Variant = stage.get("width")
	return float(w) if w != null else float(game.world.width)


func on_snapshot(snap: Dictionary) -> void:
	buffer.own_id = my_id # il proprio lottatore senza ritardo d'interpolazione (E17)
	buffer.push(snap.t, Time.get_ticks_msec(), snap.players, float(snap.get("stageMs", 0)))
	predictor.items_present = not snap.get("items", []).is_empty()
	_puddles = snap.get("puddles", [])
	_companions.on_snapshot(snap.players, game.characters)
	predictor.puddles = _puddles
	for p in snap.players:
		_load_character(_look(p))
		if p.id == my_id:
			predictor.on_server(p, Time.get_ticks_msec(), positions.get(my_id, Vector2(NAN, NAN)))
	player_ids = snap.players.map(func(p): return p.id)
	# Colore, personaggio e id arrivano solo con lo snapshot: le varianti non cambiano tra un frame e l'altro
	_variants = FighterPose.variant_ranks(snap.players)
	_holding = {}
	for p in snap.players:
		if p.get("grabbedBy") != null:
			_holding[p.grabbedBy] = true
	_items = snap.get("items", [])
	_projectiles = snap.get("projectiles", [])
	_projectiles_ms = Time.get_ticks_msec()


func on_event(e: Dictionary) -> void:
	match e.type:
		"matchStart":
			_reached = 0
			_life.match_start = NAN # il giorno riparte da dove dice l'arena (#260)
		"checkpoint":
			if e.id == my_id:
				_reached = int(e.index)
		"hit":
			var big: bool = str(e.kind).begins_with("heavy")
			var fx: Dictionary = game.effects
			var kb := float(e.get("knockback", 0))
			# I colpi forti hanno anche le linee a raggiera, come i fumetti e Smash
			var lines: int = int(fx.get("impactLines", 0)) if kb >= float(fx.get("impactLinesKnockback", INF)) else 0
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": (34.0 if big else 20.0) + float(e.get("damage", 0)), "color": Color(1, 0.85, 0.3) if big else Color.WHITE, "lines": lines})
			# Più il colpo lancia lontano, più lo schermo trema; i colpi enormi fanno anche un lampo
			if kb > fx.shakeFromKnockback:
				_shake = maxf(_shake, minf(fx.shakeMax, (kb - fx.shakeFromKnockback) * fx.shakePerKnockback))
			if kb >= fx.flashKnockback:
				_flash = fx.flashMs
			_react(e)
		"hazard":
			# Trappola (#14): scintilla arancione e scossa come un colpo forte
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 30.0, "color": Color(1, 0.55, 0.15)})
			_shake = maxf(_shake, minf(game.effects.shakeMax, float(e.knockback) * game.effects.shakePerKnockback))
		"land":
			_puff(e.x, e.y)
		"shield":
			# Colpo parato (#109): scintilla piccola del colore di chi para e bolla che si illumina
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			var col: Color = Access.color(p.color).lightened(0.5) if p != null else Color.WHITE
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 16.0 + float(e.damage), "color": col})
			_shield_hits[e.id] = 0.0
		"shieldBreak":
			# Scudo rotto: scossa e schegge della bolla che volano via
			_shake = maxf(_shake, float(game.effects.shieldBreakShake))
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			var col: Color = Access.color(p.color).lightened(0.3) if p != null else Color.WHITE
			var center := Vector2(e.x, e.y - float(game.fighter.height) / 2)
			for s in FighterPose.shard_velocities(int(game.effects.shards)):
				_shards.append({"x": center.x, "y": center.y, "vx": s.x, "vy": s.y, "age": 0.0, "color": col})
		"grab":
			# Presa (#109): un lampo bianco dove la mano afferra
			_sparks.append({"x": e.x, "y": float(e.y) - float(game.fighter.height) * 0.55, "age": 0.0, "size": 24.0, "color": Color.WHITE})
		"projectileEnd":
			# Proiettile che sparisce contro qualcosa (E10): una scintilla piccola; il colpo e lo scudo hanno già la loro
			if e.reason == "wall":
				_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 14.0, "color": Color(1, 0.9, 0.6)})
			elif e.reason == "hit":
				_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 18.0, "color": Color.WHITE}) # anche due proiettili che si annullano
		"powerUp":
			# Il fiore (#231): uno sbuffo verde dove lo si prende, più grande di una scintilla. Il bong (#302): una boccata grigia
			var col: Color = Color(0.66, 0.77, 0.42) if e.kind in ["spore", "micelio"] else SMOKE_GREY if e.kind == "bong" else (Color(0.75, 0.4, 0.95) if e.kind == "trip" else (Color(1, 0.75, 0.2) if e.kind == "birra" else FLOWER_GREEN.lightened(0.3)))
			_sparks.append({"x": e.x, "y": float(e.y) - float(game.fighter.height) * 0.5, "age": 0.0, "size": 50.0, "color": col})
			_puff(e.x, e.y)
		"bong":
			if e.phase == "smoke":
				# La nuvola (#302): si allarga davanti a chi soffia e trema un po' lo schermo
				_clouds.append({"x": float(e.x), "y": float(e.y), "dir": float(e.get("dir", 1)), "age": 0.0, "damage": float(e.get("damage", 12))})
				_shake = maxf(_shake, 6.0)
			elif e.phase == "stun":
				# Troppo fatto: stelline gialle sopra la testa, come uno stordito
				_sparks.append({"x": e.x, "y": float(e.y) - float(game.fighter.height) * 1.1, "age": 0.0, "size": 30.0, "color": Color(1, 0.9, 0.4)})
		"counter":
			# Contrattacco (E10): lampo azzurro grande dove para, così si capisce perché l'altro vola via
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 46.0, "color": Color(0.55, 0.85, 1)})
			_flash = maxf(_flash, float(game.effects.flashMs) * 0.5)
		"grabRelease":
			# Liberato: polvere ai piedi di tutti e due
			for id in [e.id, e.targetId]:
				var p: Variant = buffer.sample(id, Time.get_ticks_msec())
				if p != null:
					_puff(p.x, p.y)
		"ledgeGrab":
			# Lampo bianco sullo spigolo se la presa è invulnerabile (#110), così chi difende sa che non serve colpire
			if e.get("invulnerable", false):
				_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 30.0, "color": Color.WHITE})
		"ledgeGetup":
			if e.option == "roll":
				var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
				if p != null:
					_puff(p.x, p.y - float(game.ledge.hangOffsetY)) # polvere sullo spigolo, da dove parte la rotolata
		"taunt":
			_taunts[e.id] = Time.get_ticks_msec()
			_speech.say(e.id, SpeechBubbles.quote(_character_of(e.id), "taunt"))
		"attack":
			# Suprema propria (#102): la scena (liana, orsogufo, gnomo) la disegna supreme_view.gd
			if e.kind == "supreme":
				var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
				if p != null:
					_supreme_view.start(p, game.characters.get(p.characterId, {}))
					_spin_view.start(e.id, game.characters.get(p.characterId, {}))
					_grab_view.start(e.id, game.characters.get(p.characterId, {}))
					_burst_view.start(e.id, game.characters.get(p.characterId, {}))
					_rewind_view.start(e.id, game.characters.get(p.characterId, {}))
		"dash":
			# Scatto (#199): uno sbuffo di polvere dove parte e uno un po' indietro
			_puff(e.x, e.y)
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			if p != null:
				_puff(float(e.x) - float(p.facing) * 26.0, float(e.y))
		"jump":
			if not e.get("air", false):
				_puff(e.x, e.y)
			else:
				_air_jumps[e.id] = Time.get_ticks_msec()
		"ko":
			_shake = game.effects.shakeKo
			_sparks.append({"x": clampf(e.x, 0, stage_width()), "y": clampf(e.y, 0, game.world.height), "age": 0.0, "size": 90.0, "color": Color(1, 0.4, 0.3)})
			# Il raggio prende il colore di chi è uscito, come in Smash
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			var col: Color = Access.color(p.color) if p != null else Color(1, 0.4, 0.3)
			_beams.append({"x": e.x, "y": e.y, "age": 0.0, "color": col})
			# L'urlo di chi va KO, dove è uscito ma dentro l'inquadratura
			var at := Vector2(clampf(e.x, view_rect.position.x + 60, view_rect.end.x - 60), clampf(e.y, view_rect.position.y + 90, view_rect.end.y - 40))
			_speech.say(e.id, SpeechBubbles.quote(_character_of(e.id), "ko"), at)


# Il blocco del personaggio di un giocatore in game.json, vuoto se non si sa
func _character_of(id: String) -> Dictionary:
	var p: Variant = buffer.sample(id, Time.get_ticks_msec())
	return game.characters.get(p.characterId, {}) if p != null else {}


# Sbuffi di polvere ai piedi, a destra e a sinistra
# Reazione al colpo (#305): altezza del punto d'impatto sul corpo, direzione da chi colpisce, forza dal knockback.
# Le posizioni sono quelle disegnate all'ultimo frame, così la reazione segue quello che si vede
func _react(e: Dictionary) -> void:
	if not positions.has(e.targetId):
		return
	var target: Vector2 = positions[e.targetId]
	var from: Vector2 = positions.get(e.attackerId, Vector2(e.x, e.y)) if e.attackerId != e.targetId else Vector2(e.x, e.y)
	var dir := 1 if target.x >= from.x else -1
	var height := (target.y - float(e.y)) / float(game.fighter.height)
	var stop := HitReaction.stop_ms(game.get("hitstop", {}), float(e.get("damage", 0)))
	_reactions[e.targetId] = HitReaction.start(game.effects, height, dir, float(e.get("knockback", 0)), Time.get_ticks_msec(), stop)


# La deformazione di chi sta reagendo a un colpo, con il perno sui piedi; identità quando è finita
func _reaction_transform(p: Dictionary, now: float) -> Transform2D:
	if not _reactions.has(p.id):
		return Transform2D.IDENTITY
	var s := HitReaction.sample(_reactions[p.id], game.effects, now)
	if s.angle == 0.0 and s.squash == 0.0 and s.offset == 0.0:
		_reactions.erase(p.id)
		return Transform2D.IDENTITY
	return HitReaction.transform(Vector2(p.x, p.y), s)


func _puff(x: float, y: float) -> void:
	if not effects:
		return
	var n := int(game.effects.dustPuffs)
	for i in n:
		var dx := (float(i) / maxf(1, n - 1) - 0.5) * 2.0 # da -1 a 1
		_dust.append({"x": x, "y": y, "dx": dx, "age": 0.0})


func _process(delta: float) -> void:
	var fx: Dictionary = game.effects
	var dt_ms := delta * 1000.0
	_sparks = _aged(_sparks, dt_ms, fx.hitSparkMs)
	_dust = _aged(_dust, dt_ms, fx.dustMs)
	_beams = _aged(_beams, dt_ms, fx.koBeamMs)
	for s in _shards:
		s.x += s.vx * delta
		s.y += s.vy * delta
		s.vy += 900.0 * delta # le schegge ricadono
	_shards = _aged(_shards, dt_ms, fx.shardMs)
	_clouds = _aged(_clouds, dt_ms, CLOUD_MS)
	_update_high_overlay()
	for id in _shield_hits.keys():
		_shield_hits[id] += delta * 1000.0
		if _shield_hits[id] >= fx.shieldFlashMs:
			_shield_hits.erase(id)
	if Access.calm: # meno scossa e lampi (opzioni → Accessibilità): niente tremolio né lampo bianco
		_shake = 0.0
		_flash = 0.0
	_flash = maxf(0.0, _flash - delta * 1000.0)
	_shake = maxf(0.0, _shake - fx.shakeDecay * delta)
	position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0 else Vector2.ZERO
	queue_redraw()


# Invecchia gli effetti e toglie quelli finiti. Gira a ogni frame: senza effetti in corso non crea array nuovi
static func _aged(list: Array, dt_ms: float, life_ms: float) -> Array:
	if list.is_empty():
		return list
	for e in list:
		e.age += dt_ms
	return list.filter(func(e): return e.age < life_ms)


func _draw() -> void:
	if stage.is_empty():
		return
	var w: float = game.world.width
	var h: float = game.world.height
	draw_rect(Rect2(-400, -400, stage_width() + 800, h + 800), _palette.sky)
	# Nelle arene grandi (#240) la telecamera si allontana fino alle zone di espulsione: il cielo arriva fin lì
	var bz: Variant = stage.get("blastZone")
	if bz is Dictionary:
		draw_rect(Rect2(bz.left - 200, bz.top - 200, bz.right - bz.left + 400, bz.bottom - bz.top + 400), _palette.sky)
	var t_stage := buffer.sample_stage_ms(Time.get_ticks_msec())
	var view_center := view_rect.get_center()
	var rain := _rain_now(t_stage)
	_ambient = _life.sky.ambient(t_stage) # la luce del momento del giorno (#267), bianca senza ciclo
	if not _life.is_empty():
		_life.view = view_rect # lo sfondo vivo non disegna quello che sta fuori dall'inquadratura (#278)
		_life.sky.draw_sky(self, t_stage, view_rect) # cielo vivo, sole, luna, stelle e nuvole, dietro agli strati
	# Sfondo vivo (#260): ogni elemento si disegna dopo gli strati più lontani di lui
	var far := -1.0
	var night: float = _life.sky.night_lights(t_stage) if not _life.is_empty() else 0.0
	for l in _layers:
		if not _life.is_empty():
			_life.draw_band(self, far, l[1], t_stage, view_center, rain, _ambient)
		_draw_layer(l)
		var lights: Variant = _light_layers.get(snappedf(float(l[1]), 0.001))
		if lights != null and night > 0.0: # i vetri accesi, senza la luce ambiente, solo dove ce ne sono
			var whole := StageMotion.layer_rect((l[0] as Texture2D).get_size() * _layer_scale, l[1], Vector2(stage_width() / 2.0, h / 2.0), view_center)
			var part: Rect2 = lights[1]
			draw_texture_rect(lights[0], Rect2(whole.position + part.position * whole.size, part.size * whole.size), false, Color(1, 1, 1, night))
		if night > 0.0:
			_life.sky.draw_lamps(self, t_stage, view_rect, float(l[1]))
		far = l[1]
	if not _life.is_empty():
		_life.draw_band(self, far, 1.01, t_stage, view_center, rain, _ambient)
	_draw_props(_props_back) # statue e decorazioni dietro al palco (#237): le lastre che reggono ci stanno sopra
	if night > 0.0:
		for entry in _light_props: # i vetri accesi delle decorazioni (#288)
			var tex: Texture2D = entry[0]
			var pr: Dictionary = entry[1]
			var size := tex.get_size() * float(pr.get("scale", _layer_scale))
			draw_texture_rect(tex, Rect2(float(pr.x) - size.x / 2.0, float(pr.y) - size.y, size.x, size.y), false, Color(1, 1, 1, night))
	if not _life.is_empty():
		_life.sky.draw_daycycle(self, t_stage, view_rect) # di notte lampioni e finestre accese
	for i in stage.solids.size():
		var s: Dictionary = stage.solids[i]
		var skin := _skin_for("solids", i)
		if skin.is_empty():
			draw_rect(Rect2(s.x, s.y, s.width, s.height), _palette.solid)
			draw_rect(Rect2(s.x, s.y, s.width, 6), _palette.solidEdge)
		else:
			_draw_skinned_solid(s, skin)
	for i in stage.platforms.size():
		var p: Dictionary = stage.platforms[i]
		var skin := _skin_for("platforms", i)
		if not skin.is_empty():
			_draw_skinned_platform(p, skin)
		elif p.get("y2") != null:
			_draw_stairs(p, _palette.platform)
		elif float(p.get("arch", 0)) != 0.0:
			draw_colored_polygon(StageMotion.arch_polygon(p, 8.0), _palette.platform)
		else:
			draw_rect(Rect2(p.x, p.y, p.width, 8), _palette.platform)
	_draw_rails(false) # ringhiere dietro ai lottatori
	if not _life.is_empty():
		_life.draw_pigeons(self, t_stage, Time.get_ticks_msec(), positions.values(), _threats(t_stage))

	_draw_elements(t_stage) # lo stesso istante di tutto il resto del frame
	_draw_course()

	var now := Time.get_ticks_msec()
	_alive = []
	_sampled = buffer.sample_all(player_ids, now)
	var mine: Variant = predictor.sample(now, _sampled.get(my_id))
	if mine != null:
		_sampled[my_id] = mine
	_draw_sun_light(t_stage) # ombre a terra e luce dal lato del sole o della luna (#288), sotto i lottatori
	_companions.draw(self, now) # dietro ai lottatori: il beagle di Lampione (#369)
	for id in player_ids:
		var p: Variant = _sampled.get(id)
		if p != null:
			positions[id] = Vector2(p.x, p.y)
			_facings[id] = p.facing
			if not p.eliminated:
				_alive.append(id)
				_draw_trail(id, p)
				_draw_fighter(p, now)

	_supreme_view.view_rect = view_rect
	_speech.view_rect = view_rect
	_draw_puddles(now)
	_draw_items(now)
	_draw_projectiles()
	if not _life.is_empty():
		_life.draw_outer_water(self, t_stage, now, _flood_up(t_stage), view_rect, positions) # davanti a chi cade (#264)
	_draw_props(_props_front)
	_draw_rails(true) # ringhiere davanti, di solito trasparenti
	if not _foreground.is_empty():
		_draw_layer(_foreground)
	_draw_offscreen_markers()

	for d in _dust:
		var kd: float = d.age / game.effects.dustMs
		var dc := Color(0.9, 0.85, 0.75, 0.8 * (1.0 - kd))
		draw_circle(Vector2(d.x + d.dx * (8 + 34 * kd), d.y - 4 - 10 * kd * absf(d.dx)), 4 + 7 * kd, dc)

	for s in _sparks:
		var k: float = s.age / game.effects.hitSparkMs
		var c: Color = s.color
		c.a = 1.0 - k
		draw_arc(Vector2(s.x, s.y), s.size * (0.4 + k), 0, TAU, 20, c, 4.0)
		for i in int(s.get("lines", 0)):
			var dir := Vector2.from_angle(TAU * i / float(s.lines) + float(s.size)) # sempre le stesse per lo stesso colpo
			draw_line(Vector2(s.x, s.y) + dir * s.size * (0.6 + k), Vector2(s.x, s.y) + dir * s.size * (1.1 + 1.4 * k), c, 3.0)

	for c in _clouds:
		_draw_cloud(c)

	for b in _beams:
		_draw_beam(b)

	for s in _shards:
		var c: Color = s.color
		c.a = 1.0 - s.age / game.effects.shardMs
		var tip := Vector2(s.vx, s.vy).normalized() * 12.0
		draw_line(Vector2(s.x, s.y) - tip, Vector2(s.x, s.y) + tip, c, 4.0)

	if _flash > 0:
		draw_rect(view_rect.grow(40), Color(1, 1, 1, 0.45 * _flash / float(game.effects.flashMs)))


# Raggio del KO: parte a punta dal bordo dello schermo dove si è usciti e si allarga verso il centro.
# Si allunga di colpo all'inizio e poi sbiadisce; dentro ha un'anima bianca.
func _draw_beam(b: Dictionary) -> void:
	var fx: Dictionary = game.effects
	var k: float = b.age / fx.koBeamMs
	var inner := view_rect.grow(-8)
	var from := Vector2(clampf(b.x, inner.position.x, inner.end.x), clampf(b.y, inner.position.y, inner.end.y))
	var dir := (view_rect.get_center() - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var side := dir.orthogonal()
	var reach: float = fx.koBeamLength * minf(1.0, k * 5.0)
	var alpha := 1.0 - k * k
	for layer in [[1.0, b.color], [0.35, Color.WHITE]]:
		var half: float = fx.koBeamWidth * 0.5 * layer[0] * (1.0 + k * 0.6)
		var c: Color = layer[1]
		c.a = alpha * (0.75 if layer[0] == 1.0 else 0.9)
		var end := from + dir * reach
		draw_colored_polygon(PackedVector2Array([from - side * half * 0.08, end - side * half, end + side * half, from + side * half * 0.08]), c)


# Oggetti (#17): in mano seguono il lottatore disegnato (che è interpolato), gli altri
# inseguono la posizione dello snapshot; in volo girano su se stessi
# Proiettili delle speciali (E10): un ovale della misura del colpo, del colore della speciale, girato
# nella direzione in cui vola, con una scia che sfuma. Tra uno snapshot e l'altro avanzano da soli
func _draw_projectiles() -> void:
	var dt := (Time.get_ticks_msec() - _projectiles_ms) / 1000.0
	for pr in _projectiles:
		var spec := FighterPose.attack_spec(game, str(pr.characterId), str(pr.kind))
		var size := Vector2(float(spec.get("range", 24)), float(spec.get("height", 16)))
		var vel := Vector2(pr.vx, pr.vy)
		var c := Vector2(pr.x, pr.y) + vel * minf(dt, 0.1)
		var color := FighterPose.projectile_color(game, str(pr.characterId), str(pr.kind))
		var angle := vel.angle() if vel.length() > 1.0 else 0.0
		for i in [3, 2, 1]: # la scia: copie più piccole e trasparenti dietro
			var tc := color
			tc.a = 0.5 - 0.13 * i
			_draw_oval(c - vel * 0.018 * i, angle, size * (1.0 - 0.15 * i), tc)
		_draw_oval(c, angle, size, color)
		_draw_oval(c + Vector2(-2, -2).rotated(angle), angle, size * 0.45, color.lightened(0.6))


func _draw_oval(c: Vector2, angle: float, size: Vector2, color: Color) -> void:
	draw_set_transform(c, angle, Vector2(size.x / size.y, 1.0))
	draw_circle(Vector2.ZERO, size.y / 2, color)
	draw_set_transform(Vector2.ZERO)


func _draw_charge(center: Vector2, charge: float, now: float) -> void:
	var r := FighterPose.charge_radius(float(game.fighter.height), charge)
	var col := Color(1, 0.85, 0.3).lerp(Color(1, 0.45, 0.1), charge)
	var full := charge >= 0.99
	if full and not Access.calm: # carica piena: l'alone pulsa
		r += 3.0 * sin(now / 70.0)
	col.a = 0.12 + 0.18 * charge
	draw_circle(center, r, col)
	col.a = 0.4 + 0.5 * charge
	draw_arc(center, r, 0, TAU, 32, col, 3.0 if full else 2.0)


func _draw_items(now: int) -> void:
	var seen := {}
	for it in _items:
		var target := Vector2(it.x, it.y)
		var holder: Variant = it.heldBy
		if holder != null and positions.has(holder):
			var rules: Dictionary = game.itemRules
			target = positions[holder] + Vector2(_facings.get(holder, 1) * rules.holdOffsetX, -rules.holdOffsetY)
		var pos: Vector2 = _item_pos.get(it.id, target)
		pos = target if holder != null or pos.distance_to(target) > 200 else pos.lerp(target, 0.5)
		_item_pos[it.id] = pos
		seen[it.id] = true
		var spin := now / 1000.0 * 14.0 if it.thrown else 0.0
		# Il funghetto piantato (#302): chi l'ha piantato lo vede, gli altri appena appena
		var owner: Variant = it.get("owner")
		var alpha := 1.0 if owner == null or owner == my_id else 0.13
		_draw_item(it.kind, pos, spin, float(it.get("load", -1.0)), alpha)
	for id in _item_pos.keys():
		if not seen.has(id):
			_item_pos.erase(id)


# Le pozze dell'IRA (#13): una macchia marrone schiacciata a terra, lucida, con due grumi
func _draw_puddles(now: int) -> void:
	for q in _puddles:
		var w: float = q.width
		var c := Vector2(float(q.x), float(q.y) - 2.0)
		var pts := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			pts.append(c + Vector2(cos(a) * w / 2.0 * (1.0 + 0.08 * sin(a * 3.0)), sin(a) * 5.0))
		draw_colored_polygon(pts, Color("5a3a1e"))
		draw_circle(c + Vector2(-w * 0.18, -4), 6.0, Color("6b4a2b"))
		draw_circle(c + Vector2(w * 0.12, -3), 4.5, Color("6b4a2b"))
		var shine := 0.25 + 0.15 * sin(now / 300.0 + float(q.id))
		draw_line(c + Vector2(-w * 0.3, -1), c + Vector2(w * 0.05, -1), Color(1, 0.9, 0.7, shine), 2.0)


# La banana è una mezzaluna gialla con le punte scure; gli altri oggetti, finché non hanno
# un disegno, sono un rettangolo del loro colore
func _draw_item(kind: String, base: Vector2, spin: float, load: float = -1.0, alpha: float = 1.0) -> void:
	var spec: Dictionary = game.items.get(kind, {"width": 24, "height": 16, "color": 0xffffff})
	var w: float = spec.width
	var h: float = spec.height
	var center := base - Vector2(0, h / 2)
	draw_set_transform(center, spin, Vector2.ONE)
	if kind == "banana":
		draw_arc(Vector2(0, -h * 0.9), h * 1.25, PI * 0.2, PI * 0.8, 12, _color(spec.color), h * 0.55)
		draw_circle(Vector2(-w * 0.42, -h * 0.25), 2.5, Color("5a3a1a"))
		draw_circle(Vector2(w * 0.42, -h * 0.25), 2.5, Color("5a3a1a"))
	elif kind == "birra":
		# Il boccale (#302): vetro dorato, schiuma in cima e il manico di lato
		draw_rect(Rect2(-w / 2, -h / 2 + 5, w * 0.8, h - 5), Color(0.95, 0.68, 0.18))
		draw_rect(Rect2(-w / 2, -h / 2 + 5, w * 0.8, h - 5), Color(1, 0.95, 0.8), false, 1.5)
		draw_arc(Vector2(w * 0.32, 0), h * 0.22, -PI / 2, PI / 2, 10, Color(1, 0.95, 0.8), 3.0)
		for k in 3:
			draw_circle(Vector2(-w / 2 + w * (0.15 + 0.25 * k), -h / 2 + 5), w * 0.17, Color.WHITE)
	elif kind == "fiore":
		# Un alone che respira, così a terra si nota anche da lontano
		var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		draw_circle(Vector2(0, -h * 0.05), h * (0.8 + 0.12 * glow), Color(FLOWER_GREEN.lightened(0.4), 0.25 + 0.15 * glow))
		draw_leaf(self, Vector2(0, h / 2), h * 1.3, FLOWER_GREEN.lightened(0.1))
	elif kind == "bong":
		_draw_bong(spec, h, load)
	elif kind == "fungo":
		_draw_mushroom(w, h, alpha)
	elif kind == "funghetti":
		# Il sacchetto: viola chiuso col laccio, e tre cappelli che spuntano
		draw_circle(Vector2(0, h * 0.1), w * 0.45, Color(0.45, 0.25, 0.55))
		draw_line(Vector2(-w * 0.25, -h * 0.25), Vector2(w * 0.25, -h * 0.25), Color(0.9, 0.8, 0.5), 2.0)
		for k in 3:
			_draw_mushroom(w * 0.45, h * 0.45, 1.0, Vector2((k - 1) * w * 0.28, -h * 0.3))
	else:
		draw_rect(Rect2(-w / 2, -h / 2, w, h), _color(spec.color))
	draw_set_transform(Vector2.ZERO)


# Il bong (#302): tubo di vetro con l'acqua, il fornelletto di lato e il boccaglio in alto.
# In carica l'acqua gorgoglia e sopra c'è la barra
func _draw_bong(spec: Dictionary, h: float, load: float) -> void:
	var w: float = spec.width
	var glass := Color(0.75, 0.95, 0.9, 0.55)
	var rim := Color(0.85, 1, 0.95, 0.9)
	var base := Rect2(-w / 2, h * 0.12, w, h * 0.38)
	draw_rect(base, glass)
	var water := Color(0.35, 0.75, 0.6, 0.85)
	draw_rect(Rect2(base.position.x + 2, base.position.y + base.size.y * 0.35, base.size.x - 4, base.size.y * 0.6), water)
	draw_rect(Rect2(-w * 0.22, -h / 2, w * 0.44, h * 0.64), glass)
	draw_rect(Rect2(-w / 2, -h / 2, w, h), rim, false, 1.5)
	draw_line(Vector2(-w * 0.22, -h / 2), Vector2(w * 0.22, -h / 2), rim, 3.0)
	# Il fornelletto, inclinato verso l'esterno
	draw_line(Vector2(w * 0.4, h * 0.3), Vector2(w * 0.85, h * 0.02), rim, 3.0)
	draw_circle(Vector2(w * 0.88, 0), 4.0, Color("6b4a2a"))
	if load >= 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		for k in 4:
			var life := fmod(now * (2.0 + load * 3.0) + k / 4.0, 1.0)
			draw_circle(Vector2(sin(k * 2.3) * w * 0.25, base.end.y - 4 - life * base.size.y * 0.6), 2.0 + 1.5 * life, Color(1, 1, 1, 0.8 * (1.0 - life)))
		# La barra: verde mentre si carica, gialla e pulsante quando è pronta da lasciare
		var bar := Rect2(-w, -h / 2 - 16, w * 2, 6)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		var full := load >= 1.0
		var col := Color(1, 0.85, 0.3) if full else FLOWER_GREEN.lightened(0.3)
		if full and int(now * 8.0) % 2 == 0:
			col = col.lightened(0.4)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(load, 0.0, 1.0), bar.size.y)), col)


# Un funghetto di Teemo (#302): cappello rosso a pallini su un gambo chiaro, base in basso al centro
func _draw_mushroom(w: float, h: float, alpha: float, offset := Vector2.ZERO) -> void:
	var base := offset + Vector2(0, h / 2)
	draw_rect(Rect2(base + Vector2(-w * 0.15, -h * 0.55), Vector2(w * 0.3, h * 0.55)), Color(0.95, 0.9, 0.8, alpha))
	var cap := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		cap.append(base + Vector2(0, -h * 0.5) + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.55))
	draw_colored_polygon(cap, Color(0.8, 0.15, 0.2, alpha))
	for d in [Vector2(-0.22, -0.72), Vector2(0.15, -0.85), Vector2(0.3, -0.62)]:
		draw_circle(base + Vector2(d.x * w, d.y * h), maxf(1.5, w * 0.08), Color(1, 1, 1, alpha))


# La nuvola soffiata (#302): sbuffi che si allargano davanti, grigio-verdi, più grandi se fa più danno
func _draw_cloud(c: Dictionary) -> void:
	var k: float = c.age / CLOUD_MS
	var radius := float(game.get("bong", {}).get("cloudRadius", 95)) * (0.55 + 0.6 * sqrt(k)) * (0.85 + float(c.damage) / 80.0)
	for i in 7:
		var a := float(i) / 7.0 * TAU + float(c.x) * 0.01
		var off := Vector2(cos(a), sin(a)) * radius * 0.45 + Vector2(c.dir * radius * 0.25 * k, -20.0 * k)
		draw_circle(Vector2(c.x, c.y) + off, radius * (0.42 + 0.1 * sin(i * 1.9)), Color(SMOKE_GREY, 0.5 * (1.0 - k)))
	draw_circle(Vector2(c.x, c.y), radius * 0.5, Color(SMOKE_GREY.lightened(0.2), 0.55 * (1.0 - k)))


# Lo schermo distorto copre la parte di mondo che si vede; con "meno scossa e lampi" è più leggero
func _update_high_overlay() -> void:
	if _high_overlay == null:
		return
	var level := FighterPose.high_level(_sampled.get(my_id), float(game.get("bong", {}).get("highMs", 7000)))
	if Access.calm:
		level *= 0.35
	_high_overlay.visible = level > 0.0
	if level <= 0.0:
		return
	_high_overlay.position = view_rect.position - position
	_high_overlay.size = view_rect.size
	var mat: ShaderMaterial = _high_overlay.material
	mat.set_shader_parameter("level", level)
	mat.set_shader_parameter("t", Time.get_ticks_msec() / 1000.0)


const CLOUD_MS := 700.0 # ms di vita della nuvola nel client
const SMOKE_GREY := Color(0.82, 0.86, 0.8)


# Il fiore (#231): verde salvia scuro, non quello acceso del giocatore 3
const FLOWER_GREEN := Color("5f9e4a")
const SUPREME_GOLD := Color("ffc83d") # suprema pronta (#101)


# La foglia del fiore: sette foglioline dentellate a ventaglio sul gambo, dal punto stem verso l'alto.
# Statica perché la usa anche l'HUD per il segno nella scheda
static func draw_leaf(canvas: CanvasItem, stem: Vector2, size: float, col: Color) -> void:
	var dark := col.darkened(0.35)
	canvas.draw_line(stem, stem + Vector2(0, -size * 0.32), dark, maxf(1.5, size * 0.07))
	var hub := stem + Vector2(0, -size * 0.3)
	for leaflet in leaf_leaflets(size):
		var pts: PackedVector2Array = leaflet
		var moved := PackedVector2Array()
		for q in pts:
			moved.append(hub + q)
		canvas.draw_colored_polygon(moved, col)
		canvas.draw_polyline(moved, dark, maxf(1.0, size * 0.03), true)
		canvas.draw_line(hub, hub + pts[pts.size() / 2], dark, maxf(1.0, size * 0.025))


# Le foglioline in coordinate rispetto al centro: lunghe al centro, corte ai lati, con i dentini sui bordi
static func leaf_leaflets(size: float) -> Array:
	var out: Array = []
	var angles := [-80.0, -52.0, -26.0, 0.0, 26.0, 52.0, 80.0]
	var lengths := [0.34, 0.55, 0.68, 0.72, 0.68, 0.55, 0.34]
	for i in angles.size():
		var a := deg_to_rad(angles[i])
		var dir := Vector2(sin(a), -cos(a))
		var side := Vector2(-dir.y, dir.x)
		var length: float = lengths[i] * size
		var half := length * 0.14
		var pts := PackedVector2Array([Vector2.ZERO])
		# Un bordo dalla base alla punta, poi l'altro a ritroso: a zig-zag per i dentini
		for k in range(1, 6):
			var t := k / 6.0
			var wide := half * sin(t * PI) * (1.25 if k % 2 == 0 else 1.0)
			pts.append(dir * length * t + side * wide)
		pts.append(dir * length)
		for k in range(5, 0, -1):
			var t := k / 6.0
			var wide := half * sin(t * PI) * (1.25 if k % 2 == 0 else 1.0)
			pts.append(dir * length * t - side * wide)
		out.append(pts)
	return out


# Alone verde dietro al lottatore potenziato
func _draw_power_aura(p: Dictionary, now: float, height: float) -> void:
	var a := FighterPose.aura_alpha(float(p.get("powerupMs", 0)), now, float(game.get("powerup", {}).get("endingMs", 1500)))
	var center := Vector2(p.x, p.y - height * 0.55)
	var glow := FLOWER_GREEN.lightened(0.35)
	for k in 3:
		draw_circle(center, height * (0.5 + 0.12 * k), Color(glow, a * (0.7 - 0.2 * k)))
	draw_arc(center, height * 0.76, 0, TAU, 40, Color(glow.lightened(0.3), a * 1.4), 3.0)


# Suprema pronta (#101): alone dorato che respira e fiammelle che salgono, sotto lo sprite
func _draw_supreme_ready(p: Dictionary, now: float, height: float) -> void:
	var center := Vector2(p.x, p.y - height * 0.55)
	var pulse := 1.0 if Access.calm else 0.75 + 0.25 * sin(now / 180.0)
	for k in 3:
		draw_circle(center, height * (0.48 + 0.1 * k) * (0.95 + 0.05 * pulse), Color(SUPREME_GOLD, 0.13 * pulse * (1.0 - 0.3 * k)))
	draw_arc(center, height * 0.7, 0, TAU, 40, Color(SUPREME_GOLD.lightened(0.4), 0.55 * pulse), 2.5)
	if Access.calm:
		return
	for f in FighterPose.supreme_flames(str(p.id), now, height):
		draw_circle(Vector2(p.x, p.y) + f.pos, f.r, Color(SUPREME_GOLD.lightened(0.3), 0.8 * float(f.a)))


# La birra (#302): cappello da tirolese verde con la piuma, che dondola col barcollamento
func _draw_tyrolean_hat(top: Vector2, facing: float, now: float) -> void:
	var tilt := sin(now / 143.0) * 0.18 # come BIRRA.swayPeriodMs, a occhio
	draw_set_transform(top + Vector2(0, -2), tilt, Vector2.ONE)
	var green := Color(0.2, 0.42, 0.22)
	draw_rect(Rect2(-24, -4, 48, 6), green.darkened(0.2)) # tesa
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -4), Vector2(-11, -22), Vector2(11, -22), Vector2(15, -4)]), green)
	draw_rect(Rect2(-15, -9, 30, 4), Color(0.75, 0.15, 0.15)) # nastro
	draw_line(Vector2(facing * 8, -10), Vector2(facing * 22, -32), Color(0.95, 0.95, 0.9), 3.0) # piuma
	draw_set_transform(Vector2.ZERO)


# Il fumo: sbuffi grigio-verdi che salgono lenti dalla testa e si allargano, sempre gli stessi per lo stesso istante
func _draw_power_smoke(p: Dictionary, now: float, height: float) -> void:
	if Access.calm:
		return
	var offset := float(hash(p.id) % 1000) / 1000.0
	for k in 5:
		var life := fmod(now / 1800.0 + k / 5.0 + offset, 1.0)
		var drift := sin(now / 700.0 + k * 1.7 + offset * TAU) * 10.0 * life
		var pos := Vector2(p.x + p.facing * 14.0 + drift, p.y - height * 0.85 - life * 80.0)
		draw_circle(pos, 5.0 + life * 13.0, Color(0.86, 0.9, 0.84, 0.55 * (1.0 - life)))


# Chi vola veloce (lanciato lontano) lascia dietro di sé delle sagome che sbiadiscono
func _draw_trail(id: String, p: Dictionary) -> void:
	if not effects:
		return
	var fx: Dictionary = game.effects
	var fast: bool = not p.onGround and Vector2(p.vx, p.vy).length() > fx.trailSpeed and not p.respawning
	var trail: Array = _trails.get(id, [])
	if fast:
		trail.push_front(Vector2(p.x, p.y))
		trail.resize(mini(trail.size(), int(fx.trailLength)))
	elif not trail.is_empty():
		trail.pop_back() # la scia si accorcia da sola quando si rallenta
	_trails[id] = trail
	var fw: float = game.fighter.width
	var fh: float = game.fighter.height
	var col := Access.color(p.color)
	for i in range(1, trail.size()):
		var pos: Vector2 = trail[i]
		col.a = 0.35 * (1.0 - float(i) / trail.size())
		var shrink := 1.0 - 0.08 * i
		draw_rect(Rect2(pos.x - fw * shrink / 2, pos.y - fh * shrink, fw * shrink, fh * shrink), col)


# Ascensori e trappole (#14), dove sono all'istante t dell'arena: stessi calcoli di physics/elements.ts
func _draw_elements(t: float) -> void:
	var movers: Array = stage.get("movers") if stage.get("movers") != null else []
	for mi in movers.size():
		var m: Dictionary = movers[mi]
		var pos := StageMotion.mover_position(m, t)
		if _mover_sprites.has(mi):
			_draw_mover_sprite(_mover_sprites[mi], m, pos, t)
			continue
		if m.get("kind", "") == "barca":
			_draw_boat(pos, float(m.width), t)
			continue
		draw_rect(Rect2(pos.x, pos.y, m.width, 10), _palette.platform)
		# Strisce gialle e nere sotto: si capisce che si muove
		for x in range(0, int(m.width), 20):
			draw_rect(Rect2(pos.x + x, pos.y + 10, minf(10, m.width - x), 5), Color("f1c40f"))
	var hazards: Array = stage.get("hazards") if stage.get("hazards") != null else []
	for i in hazards.size():
		var h: Dictionary = hazards[i]
		_draw_hazard(h, StageMotion.hazard_active(h, t), t, i)
	var rain := _rain_now(t) # dall'acqua alta o dalla pioggia dello sfondo vivo (#288)
	if rain > 0.0:
		_draw_rain(rain, t)
	var jets: Array = stage.get("jets") if stage.get("jets") is Array else []
	for j in jets:
		_draw_jet(j, t)


func _draw_hazard(h: Dictionary, on: bool, t: float, index := -1) -> void:
	var r := StageMotion.hazard_rect(h, t)
	match h.kind:
		"ciclista":
			_draw_cyclist(h, r, t, index)
		"acqua":
			# Acqua alta (#228): verde-grigia, non blu saturo (è il colore di P2), con la superficie che ondeggia
			draw_rect(r, Color(0.29, 0.39, 0.4, 0.82))
			var wave := PackedVector2Array()
			var x: float = r.position.x
			while x <= r.end.x:
				wave.append(Vector2(x, r.position.y + 2.5 * sin(t / 280.0 + x / 37.0)))
				x += 16.0
			wave.append(Vector2(r.end.x, r.position.y + 2.5 * sin(t / 280.0 + r.end.x / 37.0)))
			draw_polyline(wave, Color("a9c2bf"), 2.0)
			# Riflessi: due righe chiare che scorrono piano sotto la superficie
			for i in 2:
				var ry: float = r.position.y + 12.0 + i * 14.0
				if ry < r.end.y - 4.0:
					var off := fposmod(t / 40.0 + i * 90.0, 120.0)
					var rx: float = r.position.x + off
					while rx < r.end.x - 30.0:
						draw_line(Vector2(rx, ry), Vector2(rx + 26.0, ry), Color(0.66, 0.76, 0.75, 0.25), 1.0)
						rx += 120.0
		"spuntoni":
			var n := maxi(1, int(h.width / 15.0))
			var w: float = h.width / n
			var col := Color("d9dde3") if on else Color("6b6f75")
			for i in n:
				var x: float = h.x + i * w
				draw_colored_polygon(PackedVector2Array([Vector2(x, h.y + h.height), Vector2(x + w / 2, h.y), Vector2(x + w, h.y + h.height)]), col)
		"fuoco":
			if not on:
				# Spento: solo le bocchette, che si scaldano poco prima di accendersi
				draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), Color("5a2a1a"))
				return
			for i in int(h.width / 20.0):
				var flicker := 0.6 + 0.4 * sin(t / 70.0 + i * 1.7)
				var fh: float = h.height * (1.2 + flicker)
				var x: float = h.x + i * 20.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 10, r.end.y - fh), Vector2(x + 20, r.end.y)]), Color(1, 0.35 + 0.3 * flicker, 0.1, 0.9))
		_:
			# Trappola senza disegno suo: un rettangolo rosso che pulsa quando è accesa
			var a := 0.35 + 0.25 * sin(t / 90.0) if on else 0.15
			draw_rect(r, Color(1, 0.2, 0.2, a))


# Piattaforma inclinata (#246), disegno provvisorio: gradini di pietra lungo la rampa. La fisica vede la rampa;
# i piedi stanno sulla rampa, che tocca lo spigolo di ogni gradino (al massimo un gradino sopra la pedata).
func _draw_stairs(p: Dictionary, col: Color) -> void:
	var w: float = p.width
	var rise := absf(float(p.y2) - float(p.y))
	var n := maxi(2, int(rise / 14.0)) # un gradino ogni 14 px di dislivello circa
	var step := w / n
	var dark := col.darkened(0.35)
	for i in n:
		var x0: float = float(p.x) + step * i
		var top := maxf(PredictMovement.surface_y(p, x0), PredictMovement.surface_y(p, x0 + step)) # la rampa tocca lo spigolo di ogni gradino
		var bottom := maxf(float(p.y), float(p.y2)) # i gradini non scendono sotto il fondo della scala
		draw_rect(Rect2(x0, top, step + 0.5, minf(6.0, bottom - top)), col)
		if top + 6.0 < bottom:
			draw_rect(Rect2(x0, top + 6, step + 0.5, minf(rise / n, bottom - top - 6.0)), dark)


# Luce del sole e della luna (#288), solo nelle arene col giorno che passa: una luce calda (o fredda di notte)
# che arriva dal lato dell'astro e sfuma dall'altra parte, poi le ombre a terra delle decorazioni (statue, alberi,
# fontana) e dei lottatori, allungate dalla parte opposta all'astro. I lottatori restano dei loro colori
func _draw_sun_light(t: float) -> void:
	if _life.is_empty() or not _life.life.get("daycycle") is Dictionary:
		return
	var l := SunLight.light(_life.sky.day_phase(t))
	var r := view_rect
	var side: float = l.side
	if absf(side) > 0.05 and not Access.calm:
		var tint: Color = l.tint
		var lit := Color(tint.r, tint.g, tint.b, 0.07 * absf(side) + 0.03 * (1.0 - float(l.elev)))
		var dark := Color(0.08, 0.1, 0.2, 0.06 + 0.08 * (1.0 - float(l.elev)))
		var from := lit if side < 0.0 else dark
		var to := dark if side < 0.0 else lit
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([from, to, to, from]))
	for entry in _props_back:
		var pr: Dictionary = entry[1]
		var tex: Texture2D = entry[0]
		var ground: float = entry[2]
		if absf(ground - float(pr.y)) > 8.0:
			continue # non poggia sul palco (il palazzo, le fondamenta)
		var w := tex.get_width() * float(pr.get("scale", _layer_scale)) * 0.55
		_draw_shadow(SunLight.shadow(Vector2(pr.x, ground), w, l))
	for id in player_ids:
		var p: Variant = _sampled.get(id)
		if p == null or p.eliminated or p.respawning:
			continue
		var ground := _surface_below(float(p.x), float(p.y) - 2.0)
		if ground == INF:
			continue
		_draw_shadow(SunLight.shadow(Vector2(p.x, ground), float(game.fighter.width), l, ground - float(p.y)))


func _draw_shadow(s: Array) -> void:
	if float(s[1]) <= 0.0:
		return
	var pts: PackedVector2Array = s[0]
	_draw_convex(pts, Color(0.05, 0.05, 0.1, float(s[1]) * 0.6))
	# il nucleo più scuro, vicino a chi la fa: un'ombra morbida ai bordi
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	# q -> c + (q - c) * 0.6, fatto dal motore su tutto il poligono invece che punto per punto in GDScript
	var core := Transform2D(0.0, Vector2(0.6, 0.6), 0.0, c * 0.4) * pts
	_draw_convex(core, Color(0.05, 0.05, 0.1, float(s[1]) * 0.5))


# Un poligono convesso a ventaglio dal primo punto, senza la triangolazione generica di draw_colored_polygon:
# con tante ombre per frame (Padova, #288) era la parte più cara
func _draw_convex(pts: PackedVector2Array, color: Color) -> void:
	if _fan.size() != (pts.size() - 2) * 3:
		_fan = PackedInt32Array()
		for i in range(1, pts.size() - 1):
			_fan.append_array([0, i, i + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _fan, pts, PackedColorArray([color]))


# La superficie più vicina sotto un punto: blocchi pieni e piattaforme (anche ad arco), INF se sotto c'è il vuoto
func _surface_below(x: float, y: float) -> float:
	var best := INF
	for s in stage.solids:
		if x >= float(s.x) and x <= float(s.x) + float(s.width) and float(s.y) >= y:
			best = minf(best, float(s.y))
	for p in stage.platforms:
		if x >= float(p.x) and x <= float(p.x) + float(p.width):
			var sy := PredictMovement.surface_y(p, x)
			if sy >= y:
				best = minf(best, sy)
	return best


# Getto d'acqua (#253): bolle durante l'avviso, poi una colonna d'acqua spumosa che sale. Stessa fase di jetPhase().
# Con idle (#288) è una fontana: a riposo lo zampillo resta basso, con l'avviso cresce, poi sale tutto
func _draw_jet(j: Dictionary, t: float) -> void:
	var phase := StageMotion.jet_phase(j, t)
	var idle := float(j.get("idle", 0))
	if phase == "calm" and idle <= 0.0:
		return
	var x0: float = j.x
	var w: float = j.width
	var base: float = j.y
	if phase == "warn":
		for i in 6:
			var bx := x0 + w * (0.15 + 0.7 * fposmod(i * 0.37, 1.0))
			var rise := fposmod(t / 6.0 + i * 23.0, 40.0)
			draw_arc(Vector2(bx, base - 4 - rise), 3.0 + (i % 3), 0, TAU, 10, Color(0.85, 0.92, 0.9, 0.8 - rise / 50.0), 1.5)
		if idle <= 0.0:
			return
	var h: float = j.height
	if phase == "calm":
		h = idle
	elif phase == "warn":
		h = idle * (1.3 + 0.25 * sin(t / 60.0)) # gorgoglia e cresce: sta per partire
	if idle > 0.0:
		_draw_fountain_plume(x0 + w / 2.0, base, w, h, t, phase == "active")
		return
	var col := Color(0.55, 0.7, 0.72, 0.55)
	# Il bordo destro dal basso in alto, poi il sinistro dall'alto in basso: un poligono semplice che ondeggia
	var pts := PackedVector2Array()
	for i in 10:
		var k := i / 9.0
		pts.append(Vector2(x0 + w * (0.5 + 0.4 * (1.0 - k * 0.6)) + sin(t / 70.0 + k * 9.0) * w * 0.08, base - h * k))
	for i in range(9, -1, -1):
		var k := i / 9.0
		pts.append(Vector2(x0 + w * (0.5 - 0.4 * (1.0 - k * 0.6)) + sin(t / 70.0 + k * 9.0 + 1.3) * w * 0.08, base - h * k))
	draw_colored_polygon(pts, col)
	for i in 5: # schizzi in cima
		var a := t / 120.0 + i * 1.3
		draw_circle(Vector2(x0 + w / 2 + cos(a) * w * 0.5, base - h + sin(a * 1.7) * 10), 4.0, Color(0.85, 0.93, 0.92, 0.8))


# Lo zampillo di una fontana (#288): una colonna bianca che si assottiglia, il pennacchio che si apre in cima
# e ricade a ventaglio in gocce, e la schiuma dove l'acqua torna nella vasca. Acceso è alto e pieno
func _draw_fountain_plume(cx: float, base: float, w: float, h: float, t: float, strong: bool) -> void:
	# l'acqua dipinta (#288): il getto alto quando è acceso, lo zampillo (anche gonfio, con l'avviso) a riposo
	if strong and _life.draw_frame(self, "getto", int(t / 90.0), Vector2(cx, base + 3.0), h / 318.0, false, Color.WHITE, true):
		return
	if not strong and _life.draw_frame(self, "zampillo", int(t / 90.0), Vector2(cx, base + 3.0), h / 66.0, false, Color.WHITE, true):
		return
	var foam := Color(0.93, 0.97, 0.96, 0.85)
	var body := Color(0.78, 0.9, 0.9, 0.7)
	var half := w * (0.28 if strong else 0.16)
	# la colonna: due bordi che ondeggiano, stretti in cima
	var pts := PackedVector2Array()
	for i in 12:
		var k := i / 11.0
		pts.append(Vector2(cx + half * (1.0 - k * 0.7) + sin(t / 55.0 + k * 8.0) * 2.5, base - h * k))
	for i in range(11, -1, -1):
		var k := i / 11.0
		pts.append(Vector2(cx - half * (1.0 - k * 0.7) + sin(t / 55.0 + k * 8.0 + 1.7) * 2.5, base - h * k))
	draw_colored_polygon(pts, body)
	draw_line(Vector2(cx - half * 0.3, base), Vector2(cx - half * 0.1, base - h), foam, 2.0) # il filo di luce
	# il pennacchio: ricade a ventaglio, ogni goccia lungo la sua parabola
	var drops := 26 if strong else 14
	for i in drops:
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := fposmod(t / (520.0 if strong else 420.0) + i * 0.137, 1.0) # vita della goccia, da 0 a 1
		var spread := (0.35 + 0.65 * fposmod(i * 0.61, 1.0)) * (w * (1.1 if strong else 0.8))
		var px := cx + side * spread * k
		var py := base - h + h * 0.95 * k * k - 18.0 * k * (1.0 - k) * 4.0 * (0.4 if strong else 0.25)
		draw_circle(Vector2(px, py), (3.2 if strong else 2.4) * (1.0 - 0.4 * k), Color(foam.r, foam.g, foam.b, 0.9 - 0.5 * k))
	# la cima spumosa e la schiuma alla base
	for i in 4:
		var a := t / 140.0 + i * 1.6
		draw_circle(Vector2(cx + cos(a) * half * 0.9, base - h + sin(a * 1.3) * 5.0), 5.0 if strong else 3.5, foam)
	for i in 7:
		var a := t / 200.0 + i * 0.9
		draw_circle(Vector2(cx + (i - 3) * w * 0.22 + sin(a) * 3.0, base - 4.0 + cos(a * 1.4) * 1.5), 4.5 if strong else 3.0, Color(0.95, 0.98, 0.97, 0.7))


# La barca del canale (#264): ponte di legno dove si sta in piedi (y), scafo scuro sotto, prua e poppa rialzate
func _draw_boat(pos: Vector2, w: float, t: float) -> void:
	var ink := Color("1e1a17")
	var bob := sin(t / 500.0) * 1.5 # dondola appena: la superficie vera resta pos.y
	var hull := PackedVector2Array([Vector2(pos.x - 18, pos.y - 8 + bob), Vector2(pos.x + w + 18, pos.y - 8 + bob), Vector2(pos.x + w - 10, pos.y + 26 + bob), Vector2(pos.x + 10, pos.y + 26 + bob)])
	draw_colored_polygon(hull, Color("4a3a2e"))
	draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[0]]), ink, 2.0)
	draw_rect(Rect2(pos.x - 14, pos.y - 2 + bob, w + 28, 6), Color("8a6a4c")) # il bordo di legno chiaro
	draw_rect(Rect2(pos.x, pos.y + bob, w, 4), _palette.solidEdge) # dove si sta in piedi: chiaro
	draw_line(Vector2(pos.x + w * 0.7, pos.y + bob), Vector2(pos.x + w * 0.7, pos.y - 46 + bob), ink, 2.0) # asta della bandierina
	draw_colored_polygon(PackedVector2Array([Vector2(pos.x + w * 0.7, pos.y - 46 + bob), Vector2(pos.x + w * 0.7 + 22, pos.y - 40 + bob), Vector2(pos.x + w * 0.7, pos.y - 34 + bob)]), Color("b8a88a"))


# Una piattaforma mobile disegnata (#273): il piede sul centro della superficie, girata nel verso in cui va;
# da ferma guarda verso il centro dell'arena. Dondola appena, ma la superficie vera resta quella della fisica
func _draw_mover_sprite(spr: Dictionary, m: Dictionary, pos: Vector2, t: float) -> void:
	var tex: Texture2D = spr.tex
	var fw := tex.get_width() / float(spr.frames)
	var w: float = m.width
	var dir := StageMotion.mover_facing(m, t, stage_width())
	var bob := sin(t / 500.0) * 1.2 if m.get("kind", "") == "barca" else 0.0
	var surface := Rect2(pos.x, pos.y - 1.0 + bob, w, 1.0)
	var frame := StageMotion.hazard_frame(t, spr.fps, spr.frames)
	draw_texture_rect_region(tex, StageMotion.hazard_sprite_rect(spr, fw, tex.get_height(), surface, dir), Rect2(frame * fw, 0, fw, tex.get_height()), _stage_light())


# Il fumetto di una trappola che urla, come il "CANCAROOOO!" di Cancaro Man (#270): una nuvola a punte che compare
# con un colpo e trema, con la punta verso la bocca.
# TODO community: quando qualcuno registra la voce, il fumetto resta e si sente anche il grido
func _draw_shout(text: String, mouth: Vector2, dir: int, k: float, t: float) -> void:
	var font := UI.font(UI.WEIGHT_BOLD)
	var size := 26
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pop := minf(1.0, k / 0.06) # all'ingresso il fumetto si gonfia in un attimo
	var shake := Vector2(sin(t / 23.0), cos(t / 31.0)) * 1.5
	var c := mouth + Vector2(dir * 55.0, -66.0) + shake # sopra e davanti alla bocca
	var rx := (tw / 2.0 + 22.0) * pop
	var ry := 30.0 * pop
	if rx < 2.0:
		return
	var pts := PackedVector2Array()
	var spikes := 18
	for i in spikes * 2:
		var a := TAU * i / (spikes * 2)
		var out := 1.0 if i % 2 == 0 else 0.8
		pts.append(c + Vector2(cos(a) * rx * out, sin(a) * ry * out))
	# la punta che scende verso la bocca
	draw_colored_polygon(PackedVector2Array([c + Vector2(-dir * rx * 0.25, ry * 0.5), mouth, c + Vector2(-dir * rx * 0.02, ry * 0.7)]), Color.WHITE)
	draw_polyline(PackedVector2Array([c + Vector2(-dir * rx * 0.25, ry * 0.6), mouth, c + Vector2(-dir * rx * 0.02, ry * 0.75)]), Color("1e1a17"), 3.0)
	draw_colored_polygon(pts, Color.WHITE)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color("1e1a17"), 3.0)
	if pop >= 1.0:
		draw_string_outline(font, c + Vector2(-tw / 2.0, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color("1e1a17"))
		draw_string(font, c + Vector2(-tw / 2.0, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("e04a2a"))


# Il ciclista arrabbiato (#229), disegno provvisorio dentro il rettangolo che fa male: bici scassata,
# signore pelato e rosso dalla rabbia, maglietta bianca, pettorina catarifrangente (lime spento, non il
# giallo di P4) e la catena che gira sopra la testa. Durante l'avviso, "DRIN DRIN!" dal lato dove entra.
func _draw_cyclist(h: Dictionary, r: Rect2, t: float, index := -1) -> void:
	var tp := StageMotion.travel_phase(h, t)
	if tp.phase == "calm":
		return
	var dir := StageMotion.travel_direction(h, t)
	if tp.phase == "warn":
		_draw_bell_warning(r, dir, t)
		return
	if _hazard_sprites.has(index):
		# Cancaro Man (#270): l'animazione disegnata, poi il fumetto che urla
		var spr: Dictionary = _hazard_sprites[index]
		var tex: Texture2D = spr.tex
		var fw := tex.get_width() / float(spr.frames)
		var frame := StageMotion.hazard_frame(t, spr.fps, spr.frames)
		draw_texture_rect_region(tex, StageMotion.hazard_sprite_rect(spr, fw, tex.get_height(), r, dir), Rect2(frame * fw, 0, fw, tex.get_height()), _stage_light())
		var shout: Dictionary = spr.shout
		if not shout.is_empty():
			var k: float = spr.scale
			var mouth := Vector2(r.get_center().x + dir * (float(shout.x) - float(spr.footX)) * k, r.end.y - (float(spr.footY) - float(shout.y)) * k)
			_draw_shout(str(shout.text), mouth, dir, tp.k, t)
		return
	var w := r.size.x
	var hh := r.size.y
	var fx := func(x: float) -> float: return r.position.x + (x if dir > 0 else w - x) # disegnato verso destra, girato se va a sinistra
	var bottom := r.end.y
	var wr := hh * 0.16 # raggio delle ruote
	var back := Vector2(fx.call(w * 0.2), bottom - wr)
	var front := Vector2(fx.call(w * 0.82), bottom - wr)
	var ink := Color("2a2622")
	for c in [back, front]:
		draw_arc(c, wr, 0, TAU, 18, ink, 3.0)
		var a := t / 45.0 * dir
		draw_line(c + Vector2(cos(a), sin(a)) * wr, c - Vector2(cos(a), sin(a)) * wr, Color("8a8a8a"), 1.5)
	var seat := Vector2(fx.call(w * 0.38), bottom - hh * 0.45)
	var bars := Vector2(fx.call(w * 0.74), bottom - hh * 0.52)
	var pedal := Vector2(fx.call(w * 0.48), bottom - wr)
	draw_polyline(PackedVector2Array([back, seat, pedal, back]), Color("6b4a3a"), 3.0) # telaio arrugginito
	draw_polyline(PackedVector2Array([pedal, bars, front]), Color("6b4a3a"), 3.0)
	# Il signore: busto bianco, pettorina, testa pelata e rossa
	var hip := seat + Vector2(0, -hh * 0.04)
	var shoulder := Vector2(fx.call(w * 0.5), bottom - hh * 0.82)
	draw_line(hip, pedal, Color("3b3b44"), 4.0) # gamba
	draw_line(hip, shoulder, Color("f2f0ea"), 11.0) # maglietta bianca
	draw_line(hip.lerp(shoulder, 0.2), hip.lerp(shoulder, 0.85), Color("b9c25a"), 8.0) # pettorina
	draw_line(hip.lerp(shoulder, 0.5) + Vector2(-4, 0), hip.lerp(shoulder, 0.5) + Vector2(4, 0), Color("c8c8c8"), 2.0) # striscia catarifrangente
	var head := shoulder + Vector2(fx.call(w * 0.56) - shoulder.x, -hh * 0.1)
	var rage := 0.5 + 0.5 * sin(t / 90.0)
	draw_circle(head, hh * 0.1, Color("c0533f").lerp(Color("d8644a"), rage))
	draw_line(head + Vector2(-hh * 0.05 * dir, -hh * 0.02), head + Vector2(hh * 0.07 * dir, -hh * 0.035), ink, 2.0) # sopracciglio arrabbiato
	draw_line(shoulder, bars, Color("f2f0ea"), 3.0) # braccio sul manubrio
	# Braccio alzato con la catena che gira
	var hand := shoulder + Vector2(-hh * 0.08 * dir, -hh * 0.28)
	draw_line(shoulder, hand, Color("f2f0ea"), 3.0)
	var spin := t / 70.0
	var tip := hand + Vector2(cos(spin), sin(spin) * 0.45) * hh * 0.42
	var links := PackedVector2Array()
	for i in 7:
		var f := float(i) / 6.0
		links.append(hand.lerp(tip, f) + Vector2(0, sin(f * PI) * 3.0))
	draw_polyline(links, Color("9aa0a6"), 2.5)


func _draw_bell_warning(r: Rect2, dir: int, t: float) -> void:
	# Il segnale sta sul bordo della vista da cui entrerà, all'altezza del percorso
	var s := view_rect.size.x / float(game.world.width)
	var y := clampf(r.get_center().y, view_rect.position.y + 40 * s, view_rect.end.y - 40 * s)
	var x := view_rect.position.x + 70 * s if dir > 0 else view_rect.end.x - 70 * s
	if (dir > 0 and r.position.x > view_rect.position.x) or (dir < 0 and r.end.x < view_rect.end.x):
		x = r.get_center().x # già dentro la vista: il segnale sta sopra al punto di partenza
	var pulse := 1.0 + 0.12 * sin(t / 60.0)
	var col := Color("e67e22") # arancio: non è il colore di nessun giocatore
	draw_circle(Vector2(x, y), 22 * s * pulse, Color(0.1, 0.08, 0.06, 0.75))
	draw_arc(Vector2(x, y), 22 * s * pulse, 0, TAU, 24, col, 3 * s)
	var font := ThemeDB.fallback_font
	var size := int(16 * s)
	var text := "DRIN DRIN!"
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(x - tw / 2, y - 30 * s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_string(font, Vector2(x - 4 * s, y + 6 * s), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), col)


# Pioggia su tutta l'arena: gocce oblique in posizioni fisse che scorrono col tempo dell'arena
func _draw_rain(strength: float, t: float) -> void:
	var w := stage_width() + 800.0
	var hgt: float = game.world.height + 600.0
	var drops := int(160.0 * strength)
	var col := Color(0.78, 0.84, 0.88, 0.3 * strength)
	for i in drops:
		var sx := fposmod(float(i) * 0.6180339 * w, w)
		var sy := fposmod(float(i) * 0.4142136 * hgt + t * 0.9, hgt)
		var p := Vector2(sx - 400.0, sy - 300.0)
		draw_line(p, p + Vector2(-5.0, 16.0), col, 1.0)


# Corsa: checkpoint (asta grigia, bandierina verde quando la si prende) e arrivo a scacchi
func _draw_course() -> void:
	var cps: Array = stage.get("checkpoints") if stage.get("checkpoints") != null else []
	for i in range(1, cps.size()):
		var c: Dictionary = cps[i]
		draw_rect(Rect2(c.x - 2, c.y - 70, 4, 70), Color("dddddd"))
		var flag := Color("2ecc71") if i <= _reached else Color("999999")
		draw_colored_polygon(PackedVector2Array([Vector2(c.x + 2, c.y - 70), Vector2(c.x + 28, c.y - 62), Vector2(c.x + 2, c.y - 54)]), flag)
	var g: Variant = stage.get("goal")
	if g == null:
		return
	var cell := 20.0
	for y in range(0, int(g.height), int(cell)):
		for x in range(0, int(g.width), int(cell)):
			var white := (x + y) / int(cell) % 2 == 0
			draw_rect(Rect2(g.x + x, g.y + y, minf(cell, g.width - x), minf(cell, g.height - y)), Color(1, 1, 1, 0.75) if white else Color(0.07, 0.07, 0.07, 0.75))
	var label := "ARRIVO"
	var size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string_outline(_font, Vector2(g.x + g.width / 2 - size.x / 2, g.y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color.BLACK)
	draw_string(_font, Vector2(g.x + g.width / 2 - size.x / 2, g.y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffcf4a"))


func _draw_fighter(p: Dictionary, now: float) -> void:
	var fw: float = game.fighter.width
	var fh: float = game.fighter.height
	# Chi è appena rientrato lampeggia finché è invulnerabile; chi ha perso la rete no, è solo trasparente (#107)
	var away: bool = p.get("away", false)
	# Chi fa la suprema propria (#102) è invulnerabile ma appeso alla liana: non lampeggia
	# Col fiore (#231) si è intoccabili per 8 s: invece di lampeggiare si ha l'alone verde
	var powered: bool = p.get("powerup") == "fiore" and not away
	var high: bool = p.get("powerup") == "bong" and not away # col bong (#302) si fuma ma si resta colpibili
	var blink: bool = p.invulnerable and not away and not powered and not _supreme_view.holds(p.id, now)
	if p.respawning or (blink and int(now / 100) % 2 == 0):
		return
	var character := _look(p)
	var head := fh # altezza della testa sopra i piedi: lo sprite può essere più alto del corpo
	if _textures.has(character.id):
		# footY (E7 passo 4): i piedi possono stare più su del bordo basso, la testa resta sopra di loro
		head = maxf(fh, float(character.sprite.get("footY", character.sprite.frameHeight)) * character.sprite.get("scale", 1.0))
	if powered:
		_draw_power_aura(p, now, fh)
	var ready := FighterPose.supreme_ready(p, float(game.get("supreme", {}).get("max", 100)))
	if ready and not _supreme_ready.get(p.id, false):
		_sparks.append({"x": p.x, "y": p.y - fh / 2, "age": 0.0, "size": fh * 1.2, "color": SUPREME_GOLD}) # appena pronta
	_supreme_ready[p.id] = ready
	if ready:
		_draw_supreme_ready(p, now, fh)
	var charge := float(p.get("charge", 0.0))
	if charge > 0.0:
		_draw_charge(Vector2(p.x, p.y - fh / 2), charge, now)
	var react := _reaction_transform(p, now)
	if _textures.has(character.id):
		_draw_sprite(p, character, now, react)
	else:
		draw_set_transform_matrix(react)
		var color := Access.color(p.color)
		if p.hitstun or p.get("stunned", false) or p.get("grabbedBy") != null:
			color = color.lightened(0.5)
		color.a = FighterPose.away_alpha(p)
		var body := Rect2(p.x - fw / 2, p.y - fh, fw, fh)
		draw_rect(body, color)
		if p.id == my_id:
			draw_rect(body, Color.WHITE, false, 3.0)
		# Occhio dalla parte in cui si guarda
		draw_circle(Vector2(p.x + p.facing * fw * 0.22, p.y - fh * 0.78), 5.0, Color.WHITE)
		draw_circle(Vector2(p.x + p.facing * fw * 0.27, p.y - fh * 0.78), 2.5, Color.BLACK)
		draw_set_transform(Vector2.ZERO)
	if powered or high:
		_draw_power_smoke(p, now, fh)
	if p.get("powerup") == "birra" and not away:
		_draw_tyrolean_hat(Vector2(p.x, p.y - fh), float(p.facing), now)
	if p.get("powerup") == "spore" and not away:
		# Infettati dal filo di Kirschner (#358): spore verdi che salgono intorno al corpo
		for k in 6:
			var t := fmod(now / 1400.0 + k / 6.0, 1.0)
			draw_circle(Vector2(p.x + sin(k * 2.1 + now / 500.0) * fw * 0.6, p.y - fh * t), 3.5, Color(0.66, 0.77, 0.42, 1.0 - t))
	if p.get("powerup") == "micelio" and not away:
		# Dr. Micelium più forte (#358): un alone di micelio che pulsa
		draw_arc(Vector2(p.x, p.y - fh * 0.5), fh * (0.62 + 0.04 * sin(now / 160.0)), 0, TAU, 32, Color(0.66, 0.77, 0.42, 0.55), 4.0)
	if p.get("powerup") == "trip" and not away:
		# In viaggio coi funghetti (#302): tre spirali colorate che girano sopra la testa
		for k in 3:
			var a := now / 300.0 + k * TAU / 3.0
			var c := Color.from_hsv(fmod(now / 2000.0 + k / 3.0, 1.0), 0.7, 1.0)
			draw_circle(Vector2(p.x + cos(a) * 22.0, p.y - fh - 14.0 + sin(a) * 6.0), 5.0, c)

	# Appeso al bordo (#110): il braccio arriva fino allo spigolo, sopra la testa.
	# Chi ha l'animazione ledge nello spritesheet (#171) ha già la mano disegnata sullo spigolo.
	var own_hang: bool = _textures.has(character.id) and FighterPose.has_own(character.sprite.animations, "ledge")
	if str(p.get("ledge", "")) == "hang" and not own_hang:
		var hand := Vector2(p.x + p.facing * fw / 2, p.y - float(game.ledge.hangOffsetY))
		var shoulder := Vector2(p.x + p.facing * fw * 0.2, p.y - fh * 0.55)
		var arm := Access.color(p.color).darkened(0.2)
		draw_line(shoulder, hand, arm, 6.0)
		draw_circle(hand, 6.0, arm)

	# Presa (#109): il braccio di chi tiene arriva a chi è tenuto, se lo sprite non ha la sua posa
	var own_grab: bool = _textures.has(character.id) and FighterPose.has_own(character.sprite.animations, "grab")
	if _holding.has(p.id) and not own_grab:
		var reach: float = fw / 2 + float(game.attacks.grab.range) * 0.6
		var hand := Vector2(p.x + p.facing * reach, p.y - fh * 0.55)
		var arm := Access.color(p.color).darkened(0.2)
		arm.a = FighterPose.away_alpha(p)
		draw_line(Vector2(p.x + p.facing * fw * 0.2, p.y - fh * 0.55), hand, arm, 6.0)
		draw_circle(hand, 7.0, arm)

	# Scudo (#109): una bolla del colore del giocatore che rimpicciolisce con i punti rimasti
	if p.get("shielding", false):
		var r := FighterPose.shield_radius(float(p.get("shieldHp", 0)), float(game.shield.maxHp), fh)
		var bubble := Access.color(p.color).lightened(0.3)
		var lit: float = 1.0 - float(_shield_hits[p.id]) / game.effects.shieldFlashMs if _shield_hits.has(p.id) else 0.0
		bubble = bubble.lerp(Color.WHITE, 0.6 * lit) # si illumina quando para un colpo
		bubble.a = (0.35 + 0.3 * lit) * FighterPose.away_alpha(p)
		var center := Vector2(p.x, p.y - fh / 2)
		draw_circle(center, r, bubble)
		bubble.a = 0.9 * FighterPose.away_alpha(p)
		draw_arc(center, r, 0, TAU, 40, bubble, 3.0)

	# Stordito dopo la rottura dello scudo: stelline che girano sopra la testa
	if p.get("stunned", false):
		for i in int(game.effects.stunStars):
			var a := now / 300.0 + TAU * i / float(game.effects.stunStars)
			var star := Vector2(p.x + cos(a) * fw * 0.6, p.y - head - 18 - Access.px(16) + sin(a) * 6) # sopra il nome
			_draw_star(star, 6.0, Color(1, 0.9, 0.3))

	# Allenamento: il corpo che si può colpire, lo stesso rettangolo della fisica
	if show_hitboxes:
		draw_rect(Rect2(p.x - fw / 2, p.y - fh, fw, fh), Color(0.3, 1, 0.5, 0.9), false, 2.0)

	# Colpo in corso: la stessa hitbox di attackBox() in src/shared/physics/attacks.ts,
	# spostata da boxX/boxY per le varianti direzionali (#2)
	# Si può nascondere dalle opzioni; in allenamento "Mostra hitbox" lo fa vedere comunque
	var spec := FighterPose.attack_spec(game, p.characterId, str(p.attack)) if p.attack != null and (attack_boxes or show_hitboxes) else {}
	if not spec.is_empty(): # un attacco che questa versione non conosce non ha rettangolo
		var front: float = spec.get("boxX", fw / 2)
		var o := Vector2(p.x, p.y)
		var vine: Variant = _supreme_view.origin(p.id) if p.attack == "supreme" else null
		if vine != null:
			o = vine # la suprema di Bonobot colpisce sulla liana (#102), come hitOrigin() in supreme.ts
		var dog: Variant = _companions.position_of(p.id) if _companions.is_biting(p.id) else null
		var y: float = o.y + spec.get("boxY", -fh * 0.7)
		if dog != null:
			# morde il beagle (#369): davanti a lui e alto quanto il colpo, come biteBox() in companion.ts
			o = dog
			front = float(game.characters[p.characterId].companion.width) / 2.0
			y = o.y - float(spec.height)
		var x: float = o.x + front if p.facing == 1 else o.x - front - spec.range
		var c := Color("ff9f43") if str(p.attack).begins_with("heavy") else Color.WHITE
		c.a = 0.85 if p.attackActive else 0.25
		draw_rect(Rect2(x, y, spec.range, spec.height), c)

	var label := "%s  %d%%" % [p.name, roundi(p.percent)]
	var size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, Access.px(16))
	draw_string(_font, Vector2(p.x - size.x / 2, p.y - head - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), Color.WHITE)
	if away:
		var note := "disconnesso"
		var note_size := _font.get_string_size(note, HORIZONTAL_ALIGNMENT_CENTER, -1, Access.px(13))
		draw_string(_font, Vector2(p.x - note_size.x / 2, p.y - head - 10 - Access.px(18)), note, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(13), Color(1, 0.8, 0.3))
	if p.id == my_id and _textures.has(character.id):
		# Un triangolino sopra il nome dice chi sei, al posto del bordo bianco del rettangolo
		var top: float = p.y - head - 30
		draw_colored_polygon(PackedVector2Array([Vector2(p.x - 7, top - 10), Vector2(p.x + 7, top - 10), Vector2(p.x, top)]), Color.WHITE)

	# Bandiera: chi la porta ha una bandierina del colore della squadra sopra la testa
	if p.get("carrier", false):
		var top: float = p.y - head - 34
		draw_rect(Rect2(p.x - 1, top - 30, 3, 30), Color.WHITE)
		var team_color := Access.team_color(game, int(p.team))
		draw_colored_polygon(PackedVector2Array([Vector2(p.x + 2, top - 30), Vector2(p.x + 26, top - 22), Vector2(p.x + 2, top - 14)]), team_color)


# Un fotogramma dello spritesheet, con i piedi dello sprite su quelli del giocatore
# e girato dalla parte in cui guarda
func _draw_sprite(p: Dictionary, character: Dictionary, now: float, react := Transform2D.IDENTITY) -> void:
	var sheet: Dictionary = character.sprite
	var anims: Dictionary = sheet.animations # tutti gli stati, già risolti con il ripiego (export:godot)
	var name := FighterPose.animation_for(p, _holding.has(p.id))
	var state: Dictionary = _anims.get(p.id, {})
	var prev_name: String = state.get("name", "")
	var kind: String = str(p.attack) if p.attack != null else ""
	# Sul server il colpo finisce quando la hitbox si spegne, prima del recupero disegnato:
	# se si resta fermi a terra lasciamo finire l'animazione del colpo
	var prev_kind: String = state.get("kind", "")
	if name == "idle" and kind == "" and prev_kind != "" and anims.has(prev_name):
		if now - float(state.since) < FighterPose.animation_ms(anims[prev_name], FighterPose.attack_spec(game, p.characterId, prev_kind)):
			name = prev_name
	# Gli stati di passaggio si mostrano solo a chi li ha disegnati: il ripiego fermerebbe la corsa o il salto
	var flying: bool = p.hitstun and not p.onGround
	if name == "hit" and FighterPose.has_own(anims, "tumble") and flying:
		# Una volta lanciato si continua a rotolare finché dura lo stordimento, anche rallentando
		if prev_name == "tumble" or Vector2(p.vx, p.vy).length() > float(game.effects.tumbleSpeed):
			name = "tumble"
	var air_jump: float = float(_air_jumps.get(p.id, -1.0))
	if (name == "jump" or name == "fall") and FighterPose.has_own(anims, "doubleJump") and air_jump >= 0.0:
		if now - air_jump < FighterPose.animation_ms(anims.doubleJump):
			name = "doubleJump"
	var since := now
	if (name == "idle" or name == "walk") and FighterPose.has_own(anims, "land"):
		# Atterraggio: dal passaggio aria -> terra dello stato disegnato, non dall'evento che arriva prima
		if prev_name in ["jump", "fall", "doubleJump", "recovery", "tumble"]:
			name = "land"
		elif prev_name == "land" and now - float(state.since) < FighterPose.animation_ms(anims.land):
			name = "land"
	var taunted: float = float(_taunts.get(p.id, -1.0))
	if name == "idle" and FighterPose.has_own(anims, "taunt") and taunted >= 0.0 and now - taunted < FighterPose.animation_ms(anims.taunt):
		name = "taunt"
		since = taunted
	elif name == "doubleJump":
		since = air_jump # la capriola parte dal momento del doppio salto, non da quando la si disegna
	var new_attack: bool = p.attack != null and not bool(state.get("attacking", false))
	if prev_name != name or new_attack:
		state = {"name": name, "since": since, "kind": kind}
		_anims[p.id] = state
	if FighterPose.smash_charging(p):
		state["since"] = now # il colpo caricato resta fermo sul primo fotogramma finché non si lascia il tasto
	state["attacking"] = p.attack != null
	var a: Dictionary = anims[name]
	var attack := FighterPose.attack_spec(game, p.characterId, str(state.get("kind", "")))
	var frame := FighterPose.sprite_frame(a, now - float(state.since), attack)
	var fw: float = sheet.frameWidth
	var fh: float = sheet.frameHeight
	# Nel foglio unico ogni animazione è una riga; nel formato cartella è un PNG a sé, con una riga sola
	var texture: Texture2D = _textures[character.id]
	var row: float = a.get("row", 0)
	if _state_textures.has(character.id):
		texture = _state_textures[character.id][a.src]
	var src := Rect2(frame * fw, row * fh, fw, fh)
	var scale: float = sheet.get("scale", 1.0) # 0.5 per i disegni fatti a 2x
	draw_set_transform_matrix(react * Transform2D(0.0, Vector2(p.facing * scale, scale), 0.0, Vector2(p.x, p.y)))
	var foot_y: float = sheet.get("footY", fh) # dove stanno i piedi nel fotogramma: sotto c'è chi è appeso al bordo
	draw_texture_rect_region(texture, Rect2(-fw / 2, -foot_y, fw, fh), src, FighterPose.sprite_modulate(int(_variants.get(p.id, 0)), FighterPose.away_alpha(p), FighterPose.charge_flash(p, now, Access.calm)))
	draw_set_transform(Vector2.ZERO)


# Stellina a quattro punte
func _draw_star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var rr := r if k % 2 == 0 else r * 0.4
		var a := TAU * k / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, color)


# Freccia sul bordo dello schermo per chi è stato lanciato fuori (o resta indietro nella Corsa)
func _draw_offscreen_markers() -> void:
	var w: float = game.world.width
	for id in player_ids:
		var p: Variant = _sampled.get(id)
		if p == null or p.respawning or p.eliminated:
			continue
		var cx: float = p.x
		var cy: float = p.y - game.fighter.height / 2.0
		if view_rect.has_point(Vector2(cx, cy)):
			continue
		# Con la telecamera lontana tutto si rimpicciolisce: la freccia resta della stessa misura sullo schermo
		var s := view_rect.size.x / w
		var inner := view_rect.grow(-16 * s)
		var m := Vector2(clampf(cx, inner.position.x, inner.end.x), clampf(cy, inner.position.y, inner.end.y))
		var dir := (Vector2(cx, cy) - m).normalized()
		var side := dir.orthogonal() * 9 * s
		draw_colored_polygon(PackedVector2Array([m + dir * 14 * s, m - dir * 4 * s + side, m - dir * 4 * s - side]), Access.color(p.color))


static func _color(n: Variant) -> Color:
	return Color.hex((int(n) << 8) | 0xff)
