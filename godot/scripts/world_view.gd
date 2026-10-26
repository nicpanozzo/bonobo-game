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
var _strikes := {} # id -> il colpo di cui si disegna la scia e da quando è attivo (#384 B2)
var _punch := {} # lo zoom sui colpi da KO (#384): quando è partito e dove, vuoto se non c'è
var _dust: Array = [] # [{ x, y, dx, age }] sbuffi di polvere
var _trails := {} # id -> Array[Vector2] delle ultime posizioni, per la scia di chi vola
var _particles: Node2D # effetti a particelle (#470): polvere, anello d'aria, impatti, fumo del lancio
var _fx_seed := 0 # ogni gruppo di particelle ha la sua variante
var _fx_last := {} # id -> { vx, facing, ms, smoke, brake }: quello che serve per frenata, inversione e fumo del lancio
var _fall_vy := {} # id -> velocità di caduta all'ultimo frame in aria, per l'atterraggio pesante
var _finish_candidate := {} # { target, point, kb, at }: un colpo che forse chiude la partita, da verificare (#470)
var _warp := {} # il rallentatore solo grafico (#470 passo 2b, time_warp.gd): vuoto se non c'è
var _game_text := {} # { at }: la scritta GAME! dall'evento matchEnd (#470), vuoto se non c'è
var _neg_overlay: ColorRect # la scena in negativo nel colpo che chiude la partita (#470)
var _moment: Node2D # sopra a tutto: la scritta GAME!
var _dodges := {} # id -> ms d'inizio della schivata: per la sagoma chiara (#470 passo 3)
var _dizzy := {} # id -> fino a quando (ms) girano le stelline dopo uno schianto a terra (#470 passo 3)
var _burns := {} # id -> ms in cui è stato preso dal fuoco: la scia di fuliggine (#470 fase 4)
var _ball_trail_ms := 0 # l'ultimo sbuffo di fumo dietro le palle di mortadella (#470 fase 4)
var _fire_caches := {} # indice della trappola -> le particelle già fatte del suo fuoco (ParticleFx.fire_wall)
var _respawn_clouds := {} # id -> { at, x, y, col }: la nuvoletta della rinascita (#470), da quando scende e dove arriva
var _clouds: Array = [] # [{ x, y, dir, age, damage }] nuvole soffiate col bong (#302)
var _poison_clouds: Array = [] # [{ x, y, age }] nubi di veleno del fungo di Teemo che scoppia (#419)
var _blasted := {} # id del fungo di Teemo già scoppiato: una nube sola anche se avvelena più lottatori
var _shrooms := {} # id oggetto -> { since, popped }: da quando il fungo di Teemo è piazzato, per farlo sparire
var _ink := ArcadeView.INK # il colore del contorno di quello che si disegna: gli oggetti usano la loro tinta scura (#498)
var _ink_width := 1.0 # moltiplica lo spessore del contorno (gli oggetti lo hanno sottile, #498)
var _light := Color.WHITE # la luce dell'arena sugli oggetti (#498): moltiplica i loro colori
var _sun := {} # la luce del sole o della luna di questo frame (#288), vuota nelle arene senza ciclo del giorno
var _high_overlay: ColorRect # lo schermo distorto di chi è fatto col bong (#302)
var effects := true # scie e polvere (opzioni → Video), main.gd lo legge dalle preferenze
var outlines := true # contorno uniforme dei lottatori (opzioni → Video → Luce e colori dell'arena, come post_fx.gd)
const OUTLINE_PX := 2.5 # spessore del contorno dei lottatori, in pixel di mondo: uguale per tutti gli sprite
var _beams: Array = [] # [{ x, y, age, color }] raggi dei KO, dal punto di uscita verso il centro
var _shards: Array = [] # [{ x, y, vx, vy, age, color }] schegge di uno scudo rotto (#109)
var _shield_hits := {} # id giocatore -> ms da quando lo scudo ha parato un colpo
var _reactions := {} # id giocatore -> reazione procedurale all'ultimo colpo preso (#305)
var _bounces := {} # id giocatore -> squash & stretch dell'ultimo salto o atterraggio (motion_feel.gd)
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
var _pads_pressed: Array = [] # bottoni sonori (#423): stageMs dell'ultima pressione di ognuno, dallo snapshot
const StageCollapse := preload("res://scripts/stage_collapse.gd")
const HazardFx := preload("res://scripts/hazard_fx.gd")
const BolognaHazards := preload("res://scripts/bologna_hazards.gd") # auto, ingorgo, mattoni e polvere di Bologna (#433)
const StageCrowd := preload("res://scripts/stage_crowd.gd")
var _t_draw := 0.0 # il tempo dell'arena del frame che si sta disegnando (#378, per i ganci dentro le decorazioni)
var _prize_team := 0 # premio (#433): la squadra in testa ai punti torre, dallo snapshot; i pezzi con forLeader ci sono solo per lei
var _collapse := {} # la torre che crolla dell'arena (#433), art.collapse, o vuoto
var _piece_alpha := 1.0 # pezzo a tempo (#433) che si sta disegnando: compare e sparisce sfumando
const TEAM_RING_WIDTH := 0.8 # raggio dell'anello della squadra sotto i piedi, rispetto alla larghezza del lottatore (#409)
const TEAM_RING_SQUASH := 0.28 # l'anello è un ovale schiacciato: sta per terra
const TEAM_NAME_LIGHTEN := 0.35 # il nome sopra la testa ha il colore della squadra, un po' più chiaro
const TEAM_NAME_OUTLINE := 4 # bordo scuro del nome a squadre, pixel
const SHADOW_STEPS := 6 # ovali sovrapposti di un'ombra a terra (#378): più sono, più è sfumata
const SHADOW_STEP_ALPHA := 0.17 # quanto scurisce ognuno: al centro si arriva a circa 2/3 della forza dell'ombra
var _light_layers := {} # parallasse -> [Texture2D, Rect2]: i vetri accesi di quello strato (#288), ritagliati; Rect2 in frazioni dello strato
var _light_props: Array = [] # [texture, decorazione] con i vetri accesi, sopra le decorazioni (#288)
var _life: RefCounted = preload("res://scripts/stage_life.gd").new() # sfondo vivo (#260)
var _crowd: RefCounted = StageCrowd.new() # i flash dei turisti a ogni KO (#433)
var _water: RefCounted = preload("res://scripts/stage_water.gd").new() # getti, fontane e vento (#325)
var _wonder: RefCounted = preload("res://scripts/wonder_stage.gd").new() # l'arena musicale che balla a tempo (#423)
var _arcade: RefCounted = preload("res://scripts/arcade_view.gd").new() # pezzi e blocchi del power-up Tetris (#427)
var _bassanese: RefCounted = preload("res://scripts/bassanese_view.gd").new() # Chiama Bassanese
const BassaneseView := preload("res://scripts/bassanese_view.gd")
var _stations: RefCounted = preload("res://scripts/station_view.gd").new() # postazioni e palle di mortadella (#433)
var _ambient := Color.WHITE # luce del momento del giorno (#267): moltiplica strati e decorazioni, un po' il palco
var _textures := {} # id personaggio -> Texture2D dello spritesheet (nel formato cartella, quella di idle)
var _state_textures := {} # id personaggio -> { stato: Texture2D }, solo per il formato cartella (E7 passo 2)
var _sprite_keep := {} # id personaggio -> quanto è stato rimpicciolito il suo foglio al caricamento (#320), 1 = intero
var _anims := {} # id giocatore -> { name, since }: animazione in corso e da quando
const RigView := preload("res://scripts/rig_view.gd") # prova del lottatore a pezzi in tempo reale (#403)
var _rigs := {} # id personaggio -> RigView, solo per chi ha il rig e l'ha caricato
var use_rigs := not OS.get_cmdline_user_args().has("--no-rig") # con --no-rig si vedono le strisce di prima
const RigMotion := preload("res://scripts/rig_motion.gd") # movimento secondario del rig (#404)
var _rig_motion := {} # id giocatore -> RigMotion
var show_hitboxes := false # allenamento (E15): corpo dei lottatori visibile anche sopra gli sprite
var attack_boxes := true # rettangolo del colpo in corso (opzioni → Video), main.gd lo legge dalle preferenze
var _air_jumps := {} # id giocatore -> quando ha fatto il doppio salto (ms), per l'animazione doubleJump (#103)
var _taunts := {} # id giocatore -> quando ha provocato (ms), per l'animazione taunt (E7)
var _supreme_ready := {} # id giocatore -> true se aveva la suprema pronta all'ultimo disegno: al passaggio un'onda dorata
var _holding := {} # id di chi tiene qualcuno con la presa (#109), dall'ultimo snapshot
var _palette := {} # colori dell'arena già convertiti (stage.colors), per non rifarlo a ogni frame
var _variants := {} # id giocatore -> variante di colore (0 = originale), ricalcolata a ogni snapshot (E11)
const StageMotion := preload("res://scripts/stage_motion.gd")
const ArcadeView := preload("res://scripts/arcade_view.gd")
const FighterPose := preload("res://scripts/fighter_pose.gd")
const HitReaction := preload("res://scripts/hit_reaction.gd") # il corpo si piega dove è colpito (#305)
const MotionFeel := preload("res://scripts/motion_feel.gd") # squash & stretch di salto, atterraggio e corsa
const StrikeFx := preload("res://scripts/strike_fx.gd") # scia dei colpi e linee di velocità (#384)
const ParticleFx := preload("res://scripts/particle_fx.gd") # effetti a particelle (#470)
const ParticleView := preload("res://scripts/particle_view.gd")
const TerrainFx := preload("res://scripts/terrain_fx.gd") # la polvere presa dalla superficie sotto ai piedi
const FighterFx := preload("res://scripts/fighter_fx.gd") # l'accento del lottatore negli effetti di movimento
const TimeWarp := preload("res://scripts/time_warp.gd") # rallentatore solo grafico (#470 passo 2b)


# Il livello della scritta GAME!: chiede a world_view di disegnarci sopra (sopra il negativo e le particelle)
class MomentLayer extends Node2D:
	var view # world_view.gd, senza tipo: la chiamata si risolve a runtime

	func _draw() -> void:
		view.draw_moment(self)

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
		if id == "bassanese":
			return _bassanese.head()
		var p: Variant = buffer.sample(id, Time.get_ticks_msec())
		return Vector2(p.x, float(p.y) - float(game.fighter.height) * 1.15) if p != null and not p.eliminated else null
	add_child(_speech)
	_bassanese.say = func(text: String): _speech.say("bassanese", text) # Chiama Bassanese: cosa dice mentre cerca
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
	_particles = ParticleView.new()
	_particles.max_particles = int(game.effects.get("particleMax", 600))
	add_child(_particles)
	_neg_overlay = ColorRect.new()
	var negativo := ShaderMaterial.new()
	negativo.shader = load("res://shaders/negativo.gdshader")
	_neg_overlay.material = negativo
	_neg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_neg_overlay.visible = false
	add_child(_neg_overlay)
	_moment = MomentLayer.new()
	_moment.view = self
	add_child(_moment)
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
		var rig: RefCounted = RigView.open("res://data/" + str(c.sprite.rig)) if c.sprite.get("rig") != null else null
		if rig != null:
			_rigs[id] = rig
		_textures[id] = states.idle
		_sprite_keep[id] = _kept(states.idle, "res://data/%s/idle.png" % c.sprite.dir)
	else:
		_textures[id] = _sprite_texture("res://data/" + c.sprite.path, filter, k)
		_sprite_keep[id] = _kept(_textures[id], "res://data/" + c.sprite.path)


# Quanto del PNG originale resta nella texture caricata (#320 la rimpicciolisce sugli schermi piccoli)
static func _kept(tex: Texture2D, path: String) -> float:
	var raw: Texture2D = load(path)
	if tex == null or raw == null or raw.get_height() <= 0:
		return 1.0
	return tex.get_size().y / float(raw.get_height())


# Il riquadro di un fotogramma nella texture caricata: i fotogrammi sono in pixel del PNG originale, la texture può
# essere rimpicciolita (keep). Senza questo sugli schermi piccoli si vedeva un pezzo del fotogramma accanto, come un
# secondo lottatore tagliato di fianco a ognuno
static func frame_region(frame: float, row: float, fw: float, fh: float, keep: float) -> Rect2:
	return Rect2(frame * fw * keep, row * fh * keep, fw * keep, fh * keep)


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
	if _particles:
		_particles.clear()
	_fx_last = {}
	_fall_vy = {}
	_respawn_clouds = {}
	_dodges = {}
	_dizzy = {}
	_burns = {}
	_fire_caches = {}
	_warp = {}
	_finish_candidate = {}
	_game_text = {}
	buffer = SnapshotBuffer.new()
	buffer.delay_ms = game.net.interpolationDelayMs
	buffer.teleport_distance = game.net.teleportDistance
	buffer.size = int(game.net.bufferSize)
	buffer.size = maxi(buffer.size, int(game.effects.get("warpBufferFrames", 0))) # il rallentatore disegna fino a 2 s indietro (#470)
	buffer.own_extrapolate_ms = float(game.net.get("ownExtrapolateMaxMs", 0.0))
	player_ids = []
	positions = {}
	_anims = {}
	_air_jumps = {}
	_taunts = {}
	_sparks = []
	_clouds = []
	_poison_clouds = []
	_blasted = {}
	_shrooms = {}
	_beams = []
	_shards = []
	_shield_hits = {}
	_reactions = {}
	_bounces = {}
	_rig_motion = {}
	_items = []
	_projectiles = []
	_puddles = []
	_companions.clear()
	_arcade.clear()
	_bassanese.clear()
	_stations.clear()
	_item_pos = {}
	_dust = []
	_trails = {}
	_strikes = {}
	_flash = 0.0
	_punch = {}
	_supreme_view.clear()
	_speech.clear()
	_spin_view.clear()
	_grab_view.clear()
	_burst_view.clear()
	_rewind_view.clear()
	my_id = ""
	predictor.reset()
	set_stage(game.defaultStageId)


# La luce del sole o della luna di questo frame (#288), vuota nelle arene senza ciclo del giorno: la usa post_fx.gd
func sun_light() -> Dictionary:
	return _sun


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
	_collapse = StageCollapse.config(spec) # la caduta si disegna da stageMs (#433)
	_load_stage_dressing(art.get("dir", spec.id), art)
	_life.setup(spec, stage_width(), world_height())
	_crowd.setup(spec)
	_water.life = _life
	_wonder.setup(spec)
	_arcade.setup(game)
	_stations.setup(spec, game)
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
		var tex: Texture2D = _stage_texture(dir, k.file)
		if tex == null:
			continue
		var rails: Array = []
		for r in k.get("rails", []):
			var rt := _stage_texture(dir, r.file)
			if rt != null:
				rails.append({"tex": rt, "height": float(r.height), "offsetY": float(r.get("offsetY", 0)), "front": bool(r.get("front", false)), "opacity": float(r.get("opacity", 1.0))})
		if texture_is_clear(dir, k.file):
			tex = null # un materiale tutto trasparente (vuoto.png, #380) non si disegna: a piastrelle di 2 pixel erano 30000 disegni a frame
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
				"footX": float(ms.get("footX", tex.get_width() / float(ms.frames) / 2.0)), "footY": float(ms.get("footY", tex.get_height())),
				"stem": ms.get("stem") if ms.get("stem") is Dictionary else {}, "phase": float(ms.mover) * 1.7}
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


# Un'immagine dell'arena senza nemmeno un pixel visibile (#83)
static func texture_is_clear(dir: String, file: String) -> bool:
	var path := "res://data/assets/stages/%s/%s" % [dir, file]
	if not ResourceLoader.exists(path):
		return false
	var img: Image = (load(path) as Texture2D).get_image()
	return img != null and not img.is_compressed() and img.is_invisible()


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


# Un colore del pezzo a tempo che si sta disegnando (#433), trasparente quanto il pezzo
func _faded(c: Color) -> Color:
	return Color(c, c.a * _piece_alpha)


# Il palco prende solo un po' della luce del momento (#267): di notte resta ben leggibile
func _stage_light() -> Color:
	return Color.WHITE.lerp(_ambient, 0.4)


# Un PNG ripetuto dentro un rettangolo, a _layer_scale pixel di mondo per pixel; l'ultima fila e colonna si tagliano
func _draw_tiled(tex: Texture2D, rect: Rect2, mod := Color.WHITE) -> void:
	mod *= _stage_light() * Color(1, 1, 1, _piece_alpha)
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
	mod *= _stage_light() * Color(1, 1, 1, _piece_alpha)
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
	if skin.tex != null:
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
				if skin.tex != null:
					_draw_tiled(skin.tex, Rect2(x0, top, step + 0.5, h))
				if edge != null:
					_draw_tiled(edge, Rect2(x0, top, step + 0.5, minf(edge.get_height() * _layer_scale, h)))
		return
	if skin.tex != null:
		_draw_strip(skin.tex, p, 0.0, skin.depth)
	if edge != null:
		_draw_strip(edge, p, 0.0, minf(edge.get_height() * _layer_scale, skin.depth))


# Ringhiere (#237) di tutte le piattaforme col materiale che le ha: dietro (front = false) o davanti ai lottatori
func _draw_rails(front: bool) -> void:
	for i in stage.platforms.size():
		var skin := _skin_for("platforms", i)
		_piece_alpha = StageMotion.piece_alpha(stage.platforms[i], _t_draw, _prize_team) # pezzi a tempo (#433)
		if skin.is_empty() or _piece_alpha <= 0.0:
			continue
		for r in skin.rails:
			if r.front == front:
				_draw_strip(r.tex, stage.platforms[i], r.offsetY - r.height, r.height, Color(1, 1, 1, r.opacity))
	_piece_alpha = 1.0


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
		if pr.get("floatersAfter", false) and not _life.is_empty(): # chi galleggia dietro l'isola (#378)
			_life.draw_floaters_back(self, _t_draw, _ambient)


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


# Quanto vale in verticale la parallasse degli strati (#400): 1 se l'arena non lo dice
func _vertical_parallax() -> float:
	var art: Variant = stage.get("art")
	return clampf(float(art.get("verticalParallax", 1.0)), 0.0, 1.0) if art is Dictionary else 1.0


func _draw_layer(layer: Array, mod := Color(-1, 0, 0)) -> void:
	var tex: Texture2D = layer[0]
	var size: Vector2 = layer[2] if layer.size() > 2 else tex.get_size()
	var center := Vector2(stage_width() / 2.0, world_height() / 2.0)
	draw_texture_rect(tex, StageMotion.layer_rect(size * _layer_scale, layer[1], center, view_rect.get_center(), _vertical_parallax()), false, _ambient if mod.r < 0.0 else mod)


# Piedi dei lottatori in gioco (non eliminati), per la telecamera
func alive_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for id in _alive:
		if positions.has(id):
			out.append(positions[id])
	return out


# Larghezza del mondo: lo schermo, o di più per i percorsi della Corsa (stageWidth in stages.ts)
# Altezza del mondo: lo schermo, o di più nelle arene verticali (#433); serve a centrare gli strati
func world_height() -> float:
	var h: Variant = stage.get("height")
	return float(h) if h != null else float(game.world.height)


func stage_width() -> float:
	var w: Variant = stage.get("width")
	return float(w) if w != null else float(game.world.width)


func on_snapshot(snap: Dictionary) -> void:
	buffer.own_id = my_id # il proprio lottatore senza ritardo d'interpolazione (E17)
	buffer.push(snap.t, Time.get_ticks_msec(), snap.players, float(snap.get("stageMs", 0)))
	_check_finish(snap) # il colpo che chiude la partita (#470): ora si sa con che velocità vola il bersaglio
	predictor.items_present = not snap.get("items", []).is_empty()
	_puddles = snap.get("puddles", [])
	_pads_pressed = snap.get("pads", []) if snap.get("pads") is Array else [] # bottoni sonori (#423)
	_companions.on_snapshot(snap.players, game.characters)
	_arcade.on_snapshot(snap) # #427
	_bassanese.on_snapshot(snap)
	_stations.on_snapshot(snap, Time.get_ticks_msec()) # #433
	predictor.blocks = _arcade.blocks
	predictor.puddles = _puddles
	predictor.stage_ms = float(snap.get("stageMs", 0)) # pezzi a tempo (#433)
	_prize_team = int(snap.get("prizeTeam", 0)) # premio (#433)
	predictor.prize_team = _prize_team
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
	if not _crowd.is_empty(): # il pubblico fotografa i KO e i colpi forti (#433)
		_crowd.flash(StageCrowd.flashes_for(e, float(game.effects.get("shakeFromKnockback", INF))), Time.get_ticks_msec())
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
			# più grande coi colpi che lanciano più lontano (#384 B2)
			var size := (34.0 if big else 20.0) + float(e.get("damage", 0)) + kb * float(fx.get("sparkPerKnockback", 0.0))
			if effects and _particles: # #470: stella con alone e onda, scintille dalla parte del colpo, fumo sui colpi forti
				_impact(e, big, kb >= float(fx.get("koZoomKnockback", INF)))
			else:
				_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": size, "color": Color(1, 0.85, 0.3) if big else Color.WHITE, "lines": lines})
			# Più il colpo lancia lontano, più lo schermo trema; i colpi enormi fanno anche un lampo
			if kb > fx.shakeFromKnockback:
				_shake = maxf(_shake, minf(fx.shakeMax, (kb - fx.shakeFromKnockback) * fx.shakePerKnockback))
			if kb >= fx.flashKnockback:
				_flash = fx.flashMs
			if kb >= float(fx.get("koZoomKnockback", INF)):
				_punch = {"at": Time.get_ticks_msec(), "x": float(e.x), "y": float(e.y)}
			_maybe_finish(e, kb)
			_react(e)
		"pad":
			# Bottone sonoro (#423): uno sbuffo di scintille del colore del bottone e una scossa leggera
			_sparks.append({"x": e.x, "y": float(e.y) - 10.0, "age": 0.0, "size": 34.0, "color": _color(PAD_COLORS.get(str(e.get("sound", "")), 0xff4fd8))})
			_shake = maxf(_shake, 4.0)
			_wonder.on_pad(e, Time.get_ticks_msec()) # il fiore più vicino commenta (#423)
		"bassanese":
			# Chiama Bassanese: cosa dice entrando e uscendo; mentre cerca parla da bassanese_view (TODO community: le frasi)
			if e.phase == "call":
				_speech.say("bassanese", "Pronto? Sì, arrivo... ma dove l'avrò messo?")
			elif e.phase == "leave":
				_speech.say("bassanese", BassaneseView.LEAVE_LINE, _bassanese.last_head)
		"tetris":
			# Una riga del Tetris che esplode (#427): lampo lungo la riga e scossa
			if e.phase == "line":
				_arcade.on_line(e, Time.get_ticks_msec(), effects) # #470: con gli effetti, la luce arcade
				_shake = maxf(_shake, 10.0)
		"station":
			# Postazioni (#433): la bombarda spara con una scossa, la palla di mortadella si schianta in uno sbuffo rosa
			if e.phase == "fire":
				_shake = maxf(_shake, 6.0)
				_stations.on_fire(int(e.index), Time.get_ticks_msec()) # #470: la canna rincula
				if effects and _particles: # #470: nuvolone di polvere da sparo e anello di fumo
					_cannon_smoke(e)
			elif e.phase == "boom":
				if effects and _particles: # #470: esplosione vera, con le fette di mortadella che ricadono
					_mortadella_boom(e)
				else:
					_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 40.0, "color": Color("f2a7b0")})
				_shake = maxf(_shake, 5.0)
		"hazard":
			# Trappola (#14): scintilla arancione e scossa come un colpo forte
			_sparks.append({"x": e.x, "y": e.y, "age": 0.0, "size": 30.0, "color": Color(1, 0.55, 0.15)})
			_shake = maxf(_shake, minf(game.effects.shakeMax, float(e.knockback) * game.effects.shakePerKnockback))
			var traps: Array = stage.get("hazards") if stage.get("hazards") is Array else []
			var hi := int(e.get("index", -1))
			if hi >= 0 and hi < traps.size() and traps[hi].get("kind", "") == "fuoco": # #470: chi è preso dal fuoco vola via bruciacchiato
				_burns[e.id] = Time.get_ticks_msec()
		"land":
			_land_dust(e)
			_bounces[e.id] = MotionFeel.start(game.effects, "land", Time.get_ticks_msec())
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
			var col: Color = Color(0.66, 0.77, 0.42) if e.kind in ["spore", "micelio"] else SMOKE_GREY if e.kind == "bong" else (Color(0.75, 0.4, 0.95) if e.kind == "trip" else (POISON_GREEN if e.kind == "veleno" else FLOWER_GREEN.lightened(0.3)))
			if e.kind == "veleno" and not _blasted.has(e.itemId):
				# Il fungo di Teemo scoppia (#419): una nube sola dove stava il fungo, e lo schermo trema un po'
				_blasted[e.itemId] = true
				_poison_clouds.append({"x": float(e.x), "y": float(e.y), "age": 0.0})
				_shake = maxf(_shake, 5.0)
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
					_puff(p.x, p.y - float(game.ledge.hangOffsetY), e.id) # polvere sullo spigolo, da dove parte la rotolata
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
					_speech.say(e.id, SpeechBubbles.quote(game.characters.get(p.characterId, {}), "supreme"))
		"dash":
			# Scatto (#199): uno sbuffo di polvere dove parte e uno un po' indietro
			_puff(e.x, e.y, e.id)
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			if p != null:
				_puff(float(e.x) - float(p.facing) * 26.0, float(e.y))
		"jump":
			_bounces[e.id] = MotionFeel.start(game.effects, "jump", Time.get_ticks_msec())
			if not e.get("air", false):
				_puff(e.x, e.y, e.id)
			else:
				_air_jumps[e.id] = Time.get_ticks_msec()
				if effects and _particles: # #470: anello d'aria e sbuffetti spinti giù dal salto
					_particles.add(ParticleFx.air_burst(_next_fx_seed(), e.x, e.y))
					_particles.mark({"kind": "ring", "x": float(e.x), "y": float(e.y), "r0": 16.0, "r1": 76.0, "squash": 0.3, "width": 6.0, "life_ms": float(game.effects.airRingMs)})
					var style := FighterFx.style_of(str(_character_of(e.id).get("id", ""))) # il doppio salto nello stile del lottatore
					_particles.add(FighterFx.air_jump(style, _next_fx_seed(), e.x, e.y))
					for m in FighterFx.air_jump_marks(style, e.x, e.y, float(game.effects.airRingMs)):
						_particles.mark(m)
		"dodge":
			if effects: # #470: per la durata della schivata il lottatore si disegna chiaro e trasparente
				_dodges[e.id] = Time.get_ticks_msec()
		"itemSpawn":
			if effects and _particles: # #470: stelline e uno sbuffo d'aria dove compare l'oggetto
				_particles.add(ParticleFx.item_puff(_next_fx_seed(), e.x, e.y))
				for i in 5:
					var a := i * 1.26 + 0.4
					_particles.mark({"kind": "sparkle", "x": float(e.x) + cos(a) * 16.0, "y": float(e.y) + sin(a) * 16.0,
						"x1": float(e.x) + cos(a) * 52.0, "y1": float(e.y) + sin(a) * 40.0, "size": 10.0, "life_ms": float(game.effects.itemSparkleMs)})
		"itemPick":
			var picker: Variant = positions.get(e.get("id", ""))
			if effects and _particles and picker != null: # #470: stelline che si stringono su chi lo raccoglie
				var c: Vector2 = picker + Vector2(0, -float(game.fighter.height) * 0.5)
				for i in 7:
					var a := i * 0.9
					_particles.mark({"kind": "sparkle", "x": c.x + cos(a) * 44.0, "y": c.y + sin(a) * 36.0, "x1": c.x, "y1": c.y,
						"size": 9.0, "life_ms": float(game.effects.itemPickMs), "col": Color("fff3b0")})
		"matchEnd":
			if effects: # #470: GAME! arriva con la voce dell'annunciatore (audio.gd), sopra il rallentatore
				_game_text = {"at": Time.get_ticks_msec()}
		"ko":
			_shake = game.effects.shakeKo
			# Il raggio prende il colore di chi è uscito, come in Smash
			var p: Variant = buffer.sample(e.id, Time.get_ticks_msec())
			var col: Color = Access.color(p.color) if p != null else Color(1, 0.4, 0.3)
			var ko_at := Vector2(clampf(e.x, view_rect.position.x, view_rect.end.x), clampf(e.y, view_rect.position.y, view_rect.end.y))
			if effects and _particles: # #470: una colonna di fuoco del suo colore che entra dal punto d'uscita
				ko_at = _ko_column(e, col)
			if effects and _is_final_ko(e): # #470: l'ultimo KO al rallentatore, con lo zoom dove è uscito
				_warp = TimeWarp.game(Time.get_ticks_msec(), ko_at, game.effects)
			else:
				_sparks.append({"x": clampf(e.x, 0, stage_width()), "y": clampf(e.y, 0, game.world.height), "age": 0.0, "size": 90.0, "color": Color(1, 0.4, 0.3)})
				_beams.append({"x": e.x, "y": e.y, "age": 0.0, "color": col})
			# La nuvoletta della rinascita (#470) parte in tempo per arrivare quando si ricompare; non nei percorsi
			var spawn: Variant = stage.get("respawn")
			if effects and int(e.get("stocksLeft", 0)) > 0 and spawn is Dictionary and stage.get("goal") == null:
				_respawn_clouds[e.id] = {"at": Time.get_ticks_msec() + float(game.get("respawnMs", 1500)) - float(game.effects.cloudDescentMs),
					"x": float(spawn.x), "y": float(spawn.y), "col": col}
			# L'urlo di chi va KO, dove è uscito ma dentro l'inquadratura
			var at := Vector2(clampf(e.x, view_rect.position.x + 60, view_rect.end.x - 60), clampf(e.y, view_rect.position.y + 90, view_rect.end.y - 40))
			_speech.say(e.id, SpeechBubbles.quote(_character_of(e.id), "ko"), at)


# L'arena ha il pubblico che fotografa i KO (#433): l'audio ci aggiunge gli scatti
func has_crowd() -> bool:
	return not _crowd.is_empty()


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


# Il lampo bianco di chi è appena stato colpito (#384), 0 quando non reagisce
func _hit_flash(id: String, now: float) -> float:
	return HitReaction.flash(_reactions[id], game.effects, now, Access.calm) if _reactions.has(id) else 0.0


# Lo zoom breve della telecamera sui colpi da KO (#384): 1 quando non c'è, poco più di 1 al culmine.
# point è dove avvicinarsi. main.gd lo applica sopra l'inquadratura, senza cambiarla
func punch_zoom(now: float) -> float:
	var wz := TimeWarp.zoom(_warp, now) if effects else 1.0
	if wz > 1.0:
		return wz
	if _punch.is_empty() or not effects or Access.calm:
		return 1.0
	var t := (now - float(_punch.at)) / float(game.effects.koZoomMs)
	if t < 0.0 or t >= 1.0:
		_punch = {}
		return 1.0
	return 1.0 + float(game.effects.koZoom) * sin(PI * t)


func punch_point() -> Vector2:
	if not _warp.is_empty() and effects: # #470: nel colpo decisivo il colpo, poi chi vola via; a GAME! dove è uscito
		return positions.get(_warp.target, _warp.point) if _warp.phase == "follow" else _warp.point
	return Vector2(float(_punch.x), float(_punch.y)) if not _punch.is_empty() else Vector2.ZERO


# La deformazione di chi sta reagendo a un colpo, con il perno sui piedi; identità quando è finita
func _reaction_transform(p: Dictionary, now: float) -> Transform2D:
	if not _reactions.has(p.id):
		return Transform2D.IDENTITY
	var s := HitReaction.sample(_reactions[p.id], game.effects, now)
	if s.angle == 0.0 and s.squash == 0.0 and s.offset == 0.0:
		_reactions.erase(p.id)
		return Transform2D.IDENTITY
	return HitReaction.transform(Vector2(p.x, p.y), s)


# Squash & stretch del movimento (motion_feel.gd), con il perno sui piedi; identità senza effetti
func _motion_transform(p: Dictionary, now: float) -> Transform2D:
	if not effects:
		return Transform2D.IDENTITY
	var sq := 0.0
	if _bounces.has(p.id):
		sq = MotionFeel.squash(_bounces[p.id], game.effects, now)
		if now - float(_bounces[p.id].at) >= float(game.effects.bounceMs):
			_bounces.erase(p.id)
	var angle := MotionFeel.lean(p, game.effects, float(game.fighter.groundSpeed), float(game.dash.runSpeed))
	if sq == 0.0 and angle == 0.0:
		return Transform2D.IDENTITY
	return MotionFeel.transform(Vector2(p.x, p.y), sq, angle)


func _puff(x: float, y: float, id := "") -> void:
	_ground_burst(x, y, 1.0, id) # #470: sbuffi e sassolini al posto dei cerchietti


# Polvere a terra (#470) presa dalla superficie sotto ai piedi (terrain_fx.gd): chi pesa di più ne alza di più, e il
# lottatore id ci aggiunge il suo accento (fighter_fx.gd). id vuoto = solo la superficie
func _ground_burst(x: float, y: float, power := 1.0, id := "", side := 0, kick := 0.0) -> void:
	if not effects or _particles == null:
		return
	var material := TerrainFx.material_at(stage, x, y)
	var spec: Dictionary = _character_of(id) if id != "" else {}
	var weight: float = (spec.get("stats", {}) as Dictionary).get("weight", 1.0)
	var pw := power * pow(clampf(weight, 0.6, 1.6), 1.5)
	var key := _next_fx_seed()
	_particles.add(TerrainFx.restyle(ParticleFx.dust_burst(key, x, y, pw, side, kick), material))
	_particles.add(TerrainFx.extra(material, key, x, y, pw))
	var style := FighterFx.style_of(str(spec.get("id", "")))
	if style != "":
		_particles.add(FighterFx.ground(style, key, x, y, power, kick))
		for m in FighterFx.ground_marks(style, x, y, power):
			_particles.mark(m)


func _next_fx_seed() -> int:
	_fx_seed += 1
	return _fx_seed


# Atterraggio (#470): dopo una caduta veloce o un lancio la polvere è più grande, con un pennacchio
# La schivata (#470 passo 3): x = quanto è bianco (il lampo dello shader dello sprite), y = quanto è opaco.
# Entra e esce morbida lungo la schivata; fuori dalla schivata (0, 1), cioè com'è sempre
func _dodge_look(id: String, now: float) -> Vector2:
	if not effects or not _dodges.has(id):
		return Vector2(0.0, 1.0)
	var k := (now - float(_dodges[id])) / float(game.get("dodge", {}).get("durationMs", 260))
	if k < 0.0 or k >= 1.0:
		return Vector2(0.0, 1.0)
	var a := sin(k * PI)
	return Vector2(0.8 * a, 1.0 - 0.55 * a)


func _land_dust(e: Dictionary) -> void:
	var fx: Dictionary = game.effects
	var crash: bool = (_fx_last.get(e.id, {}) as Dictionary).get("stun_air", false)
	if effects and _particles and crash: # #470 passo 3: schianto da storditi, sbuffo grande e stelline sopra la testa
		_ground_burst(e.x, e.y, float(fx.crashPower), e.id)
		_dizzy[e.id] = Time.get_ticks_msec() + float(fx.crashStarsMs)
		(_fx_last[e.id] as Dictionary).stun_air = false
	elif effects and _particles and float(_fall_vy.get(e.id, 0.0)) >= float(fx.get("heavyLandSpeed", INF)):
		_ground_burst(e.x, e.y, float(fx.heavyLandPower), e.id)
	else:
		_puff(e.x, e.y, e.id)
	_fall_vy.erase(e.id)


# Impatto (#470): la stella la disegna particle_view, le scintille schizzano dalla parte verso cui spinge il colpo
func _impact(e: Dictionary, heavy: bool, ko: bool) -> void:
	var fx: Dictionary = game.effects
	var damage := float(e.get("damage", 0))
	var target: Vector2 = positions.get(e.get("targetId", ""), Vector2(e.x, e.y))
	var from: Vector2 = positions.get(e.get("attackerId", ""), Vector2(e.x, e.y))
	var face := 1.0 if target.x >= from.x else -1.0
	var key := _next_fx_seed()
	_particles.add(ParticleFx.impact_burst(key, e.x, e.y, damage, heavy, ko, face))
	_particles.mark({"kind": "star", "x": float(e.x), "y": float(e.y), "size": ((60.0 if ko else 44.0 if heavy else 30.0) + damage * 1.2),
		"ko": ko, "heavy": heavy, "seed": key, "life_ms": float(fx.impactStarKoMs if ko else fx.impactStarMs),
		"col": Color(1.0, 0.47, 0.24) if ko else Color(1.0, 0.9, 0.6)})


# Particelle che nascono dallo stato e non da un evento (#470): fumo di chi vola via, frenata e inversione a terra.
# Si chiama dal disegno, una volta per lottatore a ogni frame, come la scia di _draw_trail
# Il colpo che chiude la partita (#470 passo 2b, come il Finish Zoom di Smash). Un colpo a chi è all'ultima vita, se il
# suo KO chiude la partita, diventa un candidato; la decisione arriva in on_snapshot, con lo snapshot dello stesso
# istante, dove il bersaglio ha già la velocità del lancio: parte solo se il volo previsto esce dalla zona di espulsione
# anche difendendosi (TimeWarp.predicts_ko). Non nei percorsi e non se un rallentatore è già in corso
func _maybe_finish(e: Dictionary, kb: float) -> void:
	if not effects or not _warp.is_empty() or stage.get("goal") != null:
		return
	if kb < float(game.effects.finishMinKnockback) or e.get("attackerId") == e.get("targetId"):
		return
	var id := str(e.get("targetId", ""))
	var target: Variant = _sampled.get(id)
	if target == null or int(target.get("stocks", 0)) != 1 or not _would_end_match(id):
		return
	_finish_candidate = {"target": id, "point": Vector2(e.x, e.y), "kb": kb, "at": Time.get_ticks_msec()}


# Se esce lui, la partita finisce? Resta in gioco un solo altro lottatore, o solo i compagni di un'altra squadra
func _would_end_match(out_id: String) -> bool:
	var others := 0
	var teams := {}
	for id in _sampled:
		var p: Dictionary = _sampled[id]
		if id == out_id or p.get("eliminated", false):
			continue
		others += 1
		teams[int(p.get("team", 0))] = true
	return others == 1 or (others > 1 and teams.size() == 1 and not teams.has(0))


# La decisione sul candidato (#470): si simula il volo con le regole del server (gravità del personaggio, freno da
# storditi, terreno, velocità del combattimento) e si fa partire il rallentatore solo se esce
func _check_finish(snap: Dictionary) -> void:
	if _finish_candidate.is_empty():
		return
	var c := _finish_candidate
	_finish_candidate = {}
	if Time.get_ticks_msec() - int(c.at) > 250 or not _warp.is_empty() or not (stage.get("blastZone") is Dictionary):
		return
	for p in snap.get("players", []):
		if str(p.id) != str(c.target):
			continue
		var stats: Dictionary = game.characters.get(str(p.get("characterId", "")), {}).get("stats", {})
		var phys := {
			"gravity": float(game.fighter.gravity) * float(stats.get("gravity", 1.0)),
			"drag": float(game.hitstun.airDrag),
			"dt": float(game.get("gameSpeed", 1.0)) / float(game.get("tickRate", 60)),
			"hitstun_ms": float(c.kb) * float(game.hitstun.perKnockback),
			"drift": float(game.fighter.hitstunDriftAccel),
			"air_friction": float(game.fighter.airFriction),
			"max_fall": float(game.fighter.maxFallSpeed),
			"extra_ms": float(game.effects.finishExtraMs),
		}
		if TimeWarp.predicts_ko(Vector2(p.x, p.y), Vector2(p.vx, p.vy), stage.blastZone, stage.get("solids", []), stage.get("platforms", []), phys):
			_warp = TimeWarp.finish(Time.get_ticks_msec(), c.point, str(c.target), game.effects)
		return


# È il KO che chiude la partita? Chi è uscito non ha più vite e resta al massimo uno in gioco, o una squadra sola
func _is_final_ko(e: Dictionary) -> bool:
	if int(e.get("stocksLeft", 1)) > 0 or stage.get("goal") != null:
		return false
	var others := 0
	var teams := {}
	for id in _sampled:
		var p: Dictionary = _sampled[id]
		if id == e.id or p.get("eliminated", false):
			continue
		others += 1
		teams[int(p.get("team", 0))] = true
	return others <= 1 or (teams.size() == 1 and not teams.has(0))


# La scena in negativo del colpo decisivo (#470): un ColorRect con lo shader che legge lo schermo, come lo schermo
# distorto del bong. Niente negativo con "meno scossa e lampi"
func _update_neg_overlay() -> void:
	if _neg_overlay == null:
		return
	var amount := 0.0 if Access.calm or not effects else TimeWarp.negative(_warp, Time.get_ticks_msec())
	_neg_overlay.visible = amount > 0.0
	if amount <= 0.0 or view_rect.size.y <= 0.0:
		return
	_neg_overlay.position = view_rect.position - position
	_neg_overlay.size = view_rect.size
	var mat: ShaderMaterial = _neg_overlay.material
	var point: Vector2 = _warp.point
	mat.set_shader_parameter("amount", amount)
	mat.set_shader_parameter("center", (point - view_rect.position) / view_rect.size)
	mat.set_shader_parameter("aspect", view_rect.size.x / view_rect.size.y)
	mat.set_shader_parameter("t", Time.get_ticks_msec() / 1000.0)


# La scritta GAME! (#470): al centro dell'inquadratura, entra grande e scatta al suo posto, con il contorno scuro
func draw_moment(ci: CanvasItem) -> void:
	if _game_text.is_empty():
		return
	var k := (Time.get_ticks_msec() - float(_game_text.at)) / float(game.effects.gameTextMs)
	var sc := TimeWarp.game_text_scale(k)
	if sc <= 0.0:
		if k >= 1.0:
			_game_text = {}
		return
	var font := UI.font(900)
	var size := int(view_rect.size.y * 0.16)
	var w := font.get_string_size("GAME!", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var alpha := minf(1.0, k / 0.03) * (1.0 if k < 0.9 else (1.0 - k) / 0.1)
	ci.draw_set_transform(view_rect.get_center() - position, -0.06, Vector2(sc, sc))
	var at := Vector2(-w / 2.0, size * 0.35)
	ci.draw_string_outline(font, at, "GAME!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, int(size * 0.16)), Color(0.13, 0.11, 0.15, alpha))
	ci.draw_string(font, at, "GAME!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, alpha))
	ci.draw_set_transform(Vector2.ZERO)


# Rallentatore (#470): main.gd trattiene eventi, HUD e audio mentre il disegno è indietro, e li rilascia quando li raggiunge
func holding() -> bool:
	return buffer.extra_delay_ms > 0.0 or not _warp.is_empty()


func reached(server_t: float) -> bool:
	return buffer.reached(server_t, Time.get_ticks_msec())


# Esplosione del KO a colonna (#470): parte dal bordo dell'inquadratura più vicino al punto d'uscita e punta verso
# il centro, nel colore di chi è uscito, con un bagliore dove entra
func _ko_column(e: Dictionary, col: Color) -> Vector2:
	var inset: float = game.effects.koColumnInset
	var inner := view_rect.grow(-inset)
	var from := Vector2(clampf(e.x, inner.position.x, inner.end.x), clampf(e.y, inner.position.y, inner.end.y))
	var dir := (view_rect.get_center() - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	_particles.add(ParticleFx.ko_column(_next_fx_seed(), from.x, from.y, dir, col))
	var glow_col := col.lightened(0.6)
	_particles.mark({"kind": "glow", "x": from.x, "y": from.y, "size": 220.0, "col": glow_col, "alpha": 0.9, "life_ms": 260.0})
	return from


# Lo sparo della bombarda (#470 fase 4, "Nuvolone di polvere"): un lampo alla bocca, il fumo e un anello di fumo che
# parte lungo la canna
func _cannon_smoke(e: Dictionary) -> void:
	var at := Vector2(e.x, e.y)
	var dir: Vector2 = _stations.muzzle_dir(int(e.index), at)
	_particles.add(ParticleFx.cannon_smoke(_next_fx_seed(), at.x, at.y, dir))
	_particles.mark({"kind": "glow", "x": at.x, "y": at.y, "size": 60.0, "col": Color(1, 0.95, 0.8), "alpha": 1.0, "life_ms": 120.0})
	var to := at + dir * 72.0
	_particles.mark({"kind": "ring", "x": at.x, "y": at.y, "x1": to.x, "y1": to.y, "r0": 12.0, "r1": 40.0, "squash": 0.4,
		"angle": dir.angle() + PI / 2.0, "width": 8.0, "col": Color("f2eff6"), "life_ms": 650.0})


# La palla di mortadella che si schianta (#470 fase 4, "Esplosione vera"): fuoco, fumo nero, schegge, onda d'urto e le
# fette che volano e restano a terra. Lontano da terra niente polvere sollevata
func _mortadella_boom(e: Dictionary) -> void:
	var x: float = e.x
	var y: float = e.y
	var floor_y := _surface_below(x, y - 10.0)
	var near := floor_y - y < 120.0
	_particles.add(ParticleFx.explosion_burst(_next_fx_seed(), x, y, floor_y if near else y + 400.0, near))
	_particles.add(ParticleFx.mortadella_slices(_next_fx_seed(), x, y, 10, floor_y if near else INF))
	_particles.mark({"kind": "glow", "x": x, "y": y, "size": 160.0, "col": Color(1, 1, 0.94), "alpha": 1.0, "life_ms": 70.0})
	_particles.mark({"kind": "glow", "x": x, "y": y, "size": 200.0, "col": Color(1, 0.6, 0.25), "alpha": 0.8, "life_ms": float(game.effects.boomGlowMs)})
	_particles.mark({"kind": "ring", "x": x, "y": y, "r0": 24.0, "r1": 180.0, "squash": 0.55, "width": 6.0, "col": Color("fff6d8"), "life_ms": 320.0})


# Un filo di fumo dietro le palle di mortadella in volo, uno sbuffo ogni ballTrailEveryMs
func _feed_ball_trails() -> void:
	var now := Time.get_ticks_msec()
	if now - _ball_trail_ms < int(game.effects.ballTrailEveryMs):
		return
	_ball_trail_ms = now
	for b in _stations.ball_centers(now):
		var v: Vector2 = b[1]
		_particles.add([ParticleFx.smoke_puff(_next_fx_seed(), b[0].x, b[0].y, -v.x * 0.03, -v.y * 0.03, 0.2)])


# Il fuoco della fossa (#470 fase 4, "Fiamme e fumo nero"): le bocchette che si scaldano prima di accendersi, il
# bagliore in basso e le fiamme a particelle, calcolate dal tempo dell'arena come la fisica (ParticleFx.fire_wall)
func _draw_fire_pit(h: Dictionary, r: Rect2, t: float, index: int) -> void:
	var period: float = maxf(1.0, float(h.get("periodMs", 4000)))
	var active: float = h.get("activeMs", period / 2.0)
	var phase := fposmod(t + float(h.get("offsetMs", 0)), period)
	var heat := 1.0 if phase < active else maxf(maxf(0.0, 1.0 - (phase - active) / 500.0), clampf(1.0 - (period - phase) / 450.0, 0.0, 1.0))
	var n := maxi(1, int(r.size.x / 40.0))
	for i in n:
		var vx := r.position.x + (i + 0.5) * r.size.x / n - 12.0
		draw_rect(Rect2(vx - 2.0, r.end.y - 10.0, 28.0, 10.0), Color("1c1410"))
		draw_rect(Rect2(vx, r.end.y - 8.0, 24.0, 8.0), Color("5a2a1a").lerp(Color("ffb070"), heat))
	if phase < active:
		var glow := Color(1, 0.55, 0.2, 0.7)
		draw_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.end.y - 50.0), Vector2(r.position.x, r.end.y - 50.0)]),
			PackedColorArray([glow, glow, Color(glow, 0.0), Color(glow, 0.0)]))
	if not _fire_caches.has(index):
		_fire_caches[index] = {}
	_particles.set_live("fuoco%d" % index, ParticleFx.fire_wall(r.position.x, r.end.x, r.end.y, r.size.y, t, t - phase, active, _fire_caches[index]))


# La nuvoletta della rinascita (#470): mentre si è fuori scende dall'alto fino al punto di ritorno, poi sta sotto i
# piedi di chi scende e si dissolve in uno sbuffo del suo colore quando tocca terra, risale (salto) o non è più
# invulnerabile. Solo disegno: la fisica non la vede
func _feed_cloud(id: String, p: Dictionary) -> void:
	var c: Dictionary = _respawn_clouds[id]
	var now := Time.get_ticks_msec()
	var col: Color = c.col
	if p.respawning:
		var k := (now - float(c.at)) / float(game.effects.cloudDescentMs)
		if k < 0.0:
			_particles.drop_cloud(id)
			return
		var top := view_rect.position.y - 60.0
		var y := lerpf(top, float(c.y) + 10.0, 1.0 - pow(1.0 - minf(k, 1.0), 2.0))
		_particles.set_cloud(id, Vector2(float(c.x), y), col)
		c.descended = true
		return
	if not c.get("descended", false): # subito dopo il KO lo snapshot disegnato può non essere ancora "fuori": si aspetta
		if now > float(c.at) + float(game.effects.cloudDescentMs) + 3000.0:
			_respawn_clouds.erase(id)
		return
	if p.onGround or not p.invulnerable or float(p.vy) < -50.0 or not effects:
		if _particles.has_cloud(id):
			_particles.drop_cloud(id)
			if effects:
				_particles.add(ParticleFx.cloud_puff(_next_fx_seed(), p.x, float(p.y) + 4.0, col))
		_respawn_clouds.erase(id)
		return
	_particles.set_cloud(id, Vector2(p.x, float(p.y) + 10.0), col)


func _feed_particles(id: String, p: Dictionary) -> void:
	if _respawn_clouds.has(id) and _particles:
		_feed_cloud(id, p)
	if not effects or _particles == null or p.respawning:
		_fx_last.erase(id)
		return
	var fx: Dictionary = game.effects
	var now := Time.get_ticks_msec()
	var vx: float = p.vx
	var vy: float = p.vy
	var last: Dictionary = _fx_last.get(id, {})
	if not p.onGround:
		_fall_vy[id] = vy
		last.stun_air = p.hitstun # in aria da stordito: se tocca terra così è uno schianto (#470 passo 3)
		var ff_at := float(game.fighter.maxFallSpeed) + 50.0
		if not p.hitstun and vy > ff_at and float(last.get("vy", 0.0)) <= ff_at: # inizio della caduta veloce: il brillio
			_particles.mark({"kind": "sparkle", "x": float(p.x) + 12.0 * float(p.facing), "y": float(p.y) - float(game.fighter.height) - 6.0,
				"size": 24.0, "life_ms": float(fx.fastFallGlintMs), "spin": 1.2})
	last.vy = vy
	var heat := ParticleFx.heat(float(p.percent), float(fx.steamFromPercent), float(fx.steamFullPercent))
	if heat > 0.0 and now - int(last.get("steam", 0)) >= ParticleFx.steam_every_ms(heat): # vapore a danno alto
		last.steam = now
		_particles.add([ParticleFx.steam_puff(_next_fx_seed(), p.x, float(p.y) - float(game.fighter.height) * 0.9, heat)])
	if now - int(_burns.get(id, -100000)) < int(fx.burnTrailMs) and now - int(last.get("burn", 0)) >= int(fx.burnEveryMs):
		last.burn = now # preso dal fuoco (#470 fase 4): fuliggine e braci mentre vola via
		_particles.add(ParticleFx.burn_puff(_next_fx_seed(), p.x, float(p.y) - float(game.fighter.height) * 0.5))
	var speed := Vector2(vx, vy).length()
	var trail: float = fx.trailSpeed
	if p.hitstun and not p.onGround and speed > trail and now - int(last.get("smoke", 0)) >= int(fx.smokeEveryMs):
		last.smoke = now
		var center := Vector2(p.x, float(p.y) - float(game.fighter.height) / 2.0)
		_particles.add([ParticleFx.smoke_puff(_next_fx_seed(), center.x, center.y, -vx * 0.06, -vy * 0.06, (speed - trail) / trail)])
	if p.onGround and last.has("vx"):
		var dt := maxf(0.001, (now - int(last.ms)) / 1000.0)
		var last_vx: float = last.vx
		if int(p.facing) != int(last.facing) and absf(vx) > float(fx.turnSpeed):
			_ground_burst(p.x, p.y, 0.9, id, 0, -25.0 * float(p.facing))
		elif absf(vx) > float(fx.brakeSpeed) and (absf(last_vx) - absf(vx)) / dt > float(fx.brakeDecel) and now - int(last.get("brake", 0)) >= int(fx.brakeEveryMs):
			last.brake = now
			var dir := signf(vx)
			var bx := float(p.x) + dir * float(game.fighter.width) * 0.3
			_particles.add(TerrainFx.restyle(ParticleFx.brake_puff(_next_fx_seed(), bx, p.y, dir), TerrainFx.material_at(stage, bx, p.y)))
		var style := FighterFx.style_of(str(p.get("characterId", "")))
		if style != "" and absf(vx) > float(game.dash.runSpeed) * 0.85 and now - int(last.get("step", 0)) >= int(fx.styleStepMs):
			last.step = now # di corsa: un pizzico del suo stile dietro ai piedi
			_particles.add(FighterFx.run_step(style, _next_fx_seed(), p.x, p.y, signf(vx)))
	last.vx = vx
	last.facing = p.facing
	last.ms = now
	_fx_last[id] = last


func _process(delta: float) -> void:
	var fx: Dictionary = game.effects
	var dt_ms := delta * 1000.0
	if not _warp.is_empty(): # il rallentatore (#470): il disegno resta indietro e poi si rimette in pari
		var r: Dictionary = TimeWarp.step(_warp, buffer.extra_delay_ms, dt_ms, Time.get_ticks_msec(), fx)
		_warp = r.warp
		buffer.extra_delay_ms = r.extra
	_update_neg_overlay()
	if _moment:
		_moment.queue_redraw()
	if effects and _particles and not _stations.is_empty(): # #470: il filo di fumo dietro le palle di mortadella
		_feed_ball_trails()
	_sparks = _aged(_sparks, dt_ms, fx.hitSparkMs)
	_dust = _aged(_dust, dt_ms, fx.dustMs)
	_beams = _aged(_beams, dt_ms, fx.koBeamMs)
	for s in _shards:
		s.x += s.vx * delta
		s.y += s.vy * delta
		s.vy += 900.0 * delta # le schegge ricadono
	_shards = _aged(_shards, dt_ms, fx.shardMs)
	_clouds = _aged(_clouds, dt_ms, CLOUD_MS)
	_poison_clouds = _aged(_poison_clouds, dt_ms, POISON_CLOUD_MS)
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
	var h: float = world_height()
	draw_rect(Rect2(-400, -400, stage_width() + 800, h + 800), _palette.sky)
	# Nelle arene grandi (#240) la telecamera si allontana fino alle zone di espulsione: il cielo arriva fin lì
	var bz: Variant = stage.get("blastZone")
	if bz is Dictionary:
		draw_rect(Rect2(bz.left - 200, bz.top - 200, bz.right - bz.left + 400, bz.bottom - bz.top + 400), _palette.sky)
	var t_stage := buffer.sample_stage_ms(Time.get_ticks_msec())
	_t_draw = t_stage
	_wonder.draw_back(self, t_stage, view_rect, _pads_pressed, Time.get_ticks_msec()) # solo nelle arene col brano (#423)
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
			# la grandezza vera dello strato (#382): sugli schermi piccoli la texture è rimpicciolita e i vetri accesi
			# finivano spostati sulle facciate sbagliate (le luci sulla Loggia Amulea che vedeva Riccardo)
			var full: Vector2 = l[2] if l.size() > 2 else (l[0] as Texture2D).get_size()
			var whole := StageMotion.layer_rect(full * _layer_scale, l[1], Vector2(stage_width() / 2.0, h / 2.0), view_center, _vertical_parallax())
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
		_piece_alpha = StageMotion.piece_alpha(s, t_stage, _prize_team) # pezzi a tempo (#433): sfumano entrando e uscendo
		if _piece_alpha <= 0.0:
			continue
		if skin.is_empty():
			draw_rect(Rect2(s.x, s.y, s.width, s.height), _faded(_palette.solid))
			draw_rect(Rect2(s.x, s.y, s.width, 6), _faded(_palette.solidEdge))
			_wonder.draw_floor(self, s, t_stage, _pads_pressed, _pad_fx) # la tastiera del pianoforte (#423)
		else:
			_draw_skinned_solid(s, skin)
	for i in stage.platforms.size():
		var p: Dictionary = stage.platforms[i]
		var skin := _skin_for("platforms", i)
		_piece_alpha = StageMotion.piece_alpha(p, t_stage, _prize_team)
		if _piece_alpha <= 0.0:
			continue
		if not skin.is_empty():
			_draw_skinned_platform(p, skin)
		elif p.get("y2") != null:
			_draw_stairs(p, _faded(_palette.platform))
		elif float(p.get("arch", 0)) != 0.0:
			draw_colored_polygon(StageMotion.arch_polygon(p, 8.0), _faded(_palette.platform))
		else:
			draw_rect(Rect2(p.x, p.y, p.width, 8), _faded(_palette.platform))
	_piece_alpha = 1.0
	_arcade.draw_blocks(self, Time.get_ticks_msec()) # i pezzi del Tetris posati (#427)
	if not _stations.is_empty():
		_stations.draw(self, t_stage) # bombarde e munizioni (#433)
	_arcade.draw_pellets(self, stage, _sampled, stage_width(), Time.get_ticks_msec()) # le palline di Pac-Man
	_draw_rails(false) # ringhiere dietro ai lottatori
	if not _life.is_empty():
		_life.draw_pigeons(self, t_stage, Time.get_ticks_msec(), positions.values(), _threats(t_stage))

	_draw_elements(t_stage) # lo stesso istante di tutto il resto del frame
	_crowd.draw(self, Time.get_ticks_msec()) # i flash dei turisti, dietro ai lottatori (#433)
	_draw_course()

	var now := Time.get_ticks_msec()
	_alive = []
	_sampled = buffer.sample_all(player_ids, now)
	var mine: Variant = predictor.sample(now, _sampled.get(my_id)) if buffer.extra_delay_ms <= 0.0 else null # al rallentatore niente predizione (#470)
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
				_feed_particles(id, p)
				_draw_trail(id, p)
				_draw_speed_lines(p)
				_draw_fighter(p, now)
				_draw_strike(p, now)

	_supreme_view.view_rect = view_rect
	_speech.view_rect = view_rect
	_draw_puddles(now)
	_draw_items(now)
	_bassanese.draw(self, now) # il Bassanese chiamato col telefono
	_draw_projectiles()
	_arcade.draw_pieces(self, _sampled) # i pezzi del Tetris che cadono (#427)
	_stations.draw_balls(self, Time.get_ticks_msec()) # le palle di mortadella (#433)
	_arcade.draw_lines(self, now) # le righe del Tetris che esplodono (#427)
	_arcade.draw_ghosts(self, _sampled, now) # con Pac-Man gli altri sono fantasmini (#427)
	if not _life.is_empty():
		_life.draw_outer_water(self, t_stage, now, _flood_up(t_stage), view_rect, positions) # davanti a chi cade (#264)
	_draw_props(_props_front)
	if not _life.is_empty():
		_life.draw_near(self, t_stage, _ambient) # chi passa sfocato in primissimo piano (#378)
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
	for c in _poison_clouds:
		_draw_poison_cloud(c)

	for b in _beams:
		_draw_beam(b)

	for s in _shards:
		var c: Color = s.color
		c.a = 1.0 - s.age / game.effects.shardMs
		var tip := Vector2(s.vx, s.vy).normalized() * 12.0
		draw_line(Vector2(s.x, s.y) - tip, Vector2(s.x, s.y) + tip, c, 4.0)

	_wonder.draw_front(self, t_stage, view_rect, _pads_pressed) # coriandoli e scritta della Meraviglia (#423)
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
		var word := FighterPose.projectile_word(game, str(pr.characterId), str(pr.kind), int(pr.id))
		if word != "":
			_draw_projectile_word(word, c, vel, color)
			continue
		for i in [3, 2, 1]: # la scia: copie più piccole e trasparenti dietro
			var tc := color
			tc.a = 0.5 - 0.13 * i
			_draw_oval(c - vel * 0.018 * i, angle, size * (1.0 - 0.15 * i), tc)
		_draw_oval(c, angle, size, color)
		_draw_oval(c + Vector2(-2, -2).rotated(angle), angle, size * 0.45, color.lightened(0.6))


# Una parola che vola (le Ciacole di Bradipo): scritta col bordo scuro, inclinata appena verso dove va, con la scia
func _draw_projectile_word(word: String, c: Vector2, vel: Vector2, color: Color) -> void:
	const SIZE := 20
	var tilt := clampf(vel.angle() if vel.x >= 0.0 else vel.angle() - PI, -0.4, 0.4)
	var tw := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	var at := Vector2(-tw / 2.0, SIZE * 0.36)
	for i in [2, 1]:
		var tc := color
		tc.a = 0.45 - 0.15 * i
		draw_set_transform(c - vel * 0.02 * i, tilt)
		draw_string(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, tc)
	draw_set_transform(c, tilt)
	draw_string_outline(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, 5, Color("1e1a17"))
	draw_string(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, color)
	draw_set_transform(Vector2.ZERO)


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
		if it.kind == "fungoTeemo" and owner != null:
			alpha = _teemo_alpha(it, str(owner), now)
			pos += Vector2(0, 3.0 * clampf(float(now - int(_shrooms[it.id].since)) / float(game.get("fungo", {}).get("armMs", 1000)), 0.0, 1.0)) # si arma e affonda un po'
		# A terra l'oggetto è posato e fermo sulla superficie, con la sua ombra (#498): niente ondeggiamento né luccichio.
		# Quando il proprio lottatore è abbastanza vicino da raccoglierlo prende un contorno chiaro
		var lying: bool = holder == null and not it.thrown and absf(float(it.get("vy", 0.0))) < 1.0 and it.kind != "fungo" and not (it.kind == "fungoTeemo" and owner != null)
		var rest := rest_tilt(it.kind, int(it.id)) if lying else 0.0
		var near := lying and _near_me(pos)
		if lying:
			_draw_item_shadow(it.kind, pos, near)
		if near:
			_draw_item(it.kind, pos, spin, float(it.get("load", -1.0)), alpha, rest, lying, true)
		_draw_item(it.kind, pos, spin, float(it.get("load", -1.0)), alpha, rest, lying)
	for id in _item_pos.keys():
		if not seen.has(id):
			_item_pos.erase(id)
			_shrooms.erase(id)


# Il fungo di Teemo piazzato (#419): da quando è a terra, quanto lo vede chi guarda. Chi l'ha lanciato e la sua squadra
# sempre, trasparente; gli altri finché non si arma, poi sfuma e sparisce come in LoL. Armato, "pop" solo per chi l'ha lanciato
func _teemo_alpha(it: Dictionary, owner: String, now: int) -> float:
	if not _shrooms.has(it.id):
		_shrooms[it.id] = {"since": now, "popped": false}
	var cfg: Dictionary = game.get("fungo", {})
	var since := float(now - int(_shrooms[it.id].since))
	var mine := _is_ally(owner)
	if mine and since >= float(cfg.get("armMs", 1000)) and not _shrooms[it.id].popped:
		_shrooms[it.id].popped = true
		_sparks.append({"x": float(it.x), "y": float(it.y) - 10.0, "age": 0.0, "size": 16.0, "color": SHROOM_GREEN.lightened(0.4)})
	return shroom_alpha(mine, since, float(cfg.get("armMs", 1000)), float(cfg.get("stealthMs", 1800)), now)


# Quanto si vede il fungo di Teemo since_ms dopo che si è piazzato. Agli avversari: pieno finché non si arma, poi
# sfuma fino a sparire a stealth_ms. A chi l'ha lanciato: sempre più trasparente fino a metà, e da armato respira piano
static func shroom_alpha(mine: bool, since_ms: float, arm_ms: float, stealth_ms: float, now_ms: float) -> float:
	var arm_t := clampf(since_ms / maxf(arm_ms, 1.0), 0.0, 1.0)
	if mine:
		var breath := 0.08 * sin(now_ms / 400.0) if arm_t >= 1.0 else 0.0
		return lerpf(1.0, 0.5, arm_t) + breath
	return 1.0 - clampf((since_ms - arm_ms) / maxf(stealth_ms - arm_ms, 1.0), 0.0, 1.0)


# Il lottatore id è io o della mia squadra (a squadre): vede i funghi di Teemo che ha lanciato
func _is_ally(id: String) -> bool:
	if id == my_id:
		return true
	var me: Variant = _sampled.get(my_id)
	var them: Variant = _sampled.get(id)
	return me is Dictionary and them is Dictionary and int(me.team) > 0 and int(me.team) == int(them.team)


# L'ombra di un oggetto a terra (#498): quella del sole o della luna come per i lottatori, se l'arena ne ha uno, e sotto
# un'ovale stretta e scura dove tocca la superficie. Se lo si può raccogliere, un chiarore a terra
func _draw_item_shadow(kind: String, base: Vector2, near := false) -> void:
	var w: float = float(game.items.get(kind, {"width": 24}).width) * ITEM_SCALE
	if not _sun.is_empty():
		_draw_shadow(SunLight.shadow(base, w * 0.8, _sun))
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(base + Vector2(cos(a) * w * 0.42, sin(a) * 2.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))
	if near:
		for i in 16:
			pts[i] = base + Vector2(cos(TAU * i / 16.0) * w * 0.7, sin(TAU * i / 16.0) * 5.0)
		draw_colored_polygon(pts, Color(GLOW_INK, 0.22))


# Il proprio lottatore è abbastanza vicino da raccogliere l'oggetto con J o K (#498)
func _near_me(item: Vector2) -> bool:
	var me: Variant = _sampled.get(my_id)
	if not (me is Dictionary) or me.get("eliminated", false) or me.get("respawning", false):
		return false
	return in_pick_range(item, Vector2(me.x, me.y), float(game.itemRules.pickRange), float(game.fighter.height))


# Come handleItemInput sul server (physics/items.ts): abbastanza vicino in orizzontale, all'altezza del corpo
static func in_pick_range(item: Vector2, feet: Vector2, pick_range: float, height: float) -> bool:
	return absf(item.x - feet.x) < pick_range and item.y > feet.y - height and item.y < feet.y + 12.0


# Come si posa un oggetto a terra (#498): la banana coricata un po' storta, gli altri dritti con appena un filo
# d'inclinazione, i funghi e gli arcade dritti. Sempre la stessa per lo stesso oggetto, così non trema
static func rest_tilt(kind: String, id: int) -> float:
	var r := fposmod(sin(id * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
	if kind == "banana":
		return r * 0.22
	if kind in ARCADE_ITEMS or kind in ["fungo", "fungoTeemo", "funghetti"]:
		return 0.0
	return r * 0.05


# Il contorno di un oggetto (#498): la sua tinta, molto più scura, al posto dell'inchiostro nero
static func item_ink(base: Color) -> Color:
	return Color(base.darkened(0.55), 0.9)


# La luce dell'arena sugli oggetti (#498): un filo del colore del cielo, così non sembrano incollati sopra, e col
# sole o la luna (#288) la loro tinta, più calda al tramonto e fredda e più scura di notte
static func item_light(sun: Dictionary, sky: Color) -> Color:
	var l := Color.WHITE.lerp(Color(sky, 1.0), 0.08)
	if sun.is_empty():
		return l
	l = l * Color.WHITE.lerp(sun.tint, 0.45)
	if not bool(sun.sun):
		l = l.darkened(0.25)
	return Color(l, 1.0)


# Un colore di un oggetto sotto la luce dell'arena
func _lit(c: Color) -> Color:
	return Color(c.r * _light.r, c.g * _light.g, c.b * _light.b, c.a)


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


# Gli oggetti sono disegnati come i lottatori: contorno scuro a inchiostro, colore pieno, una luce e un'ombra.
# Più grandi della loro scatola di gioco (ITEM_SCALE), così si riconoscono anche da lontano
# A terra (lying) poggia sulla superficie e si inclina di rest attorno al punto di contatto (#498); glow disegna solo
# il contorno chiaro di chi lo può raccogliere, sotto all'oggetto vero
func _draw_item(kind: String, base: Vector2, spin: float, load: float = -1.0, alpha: float = 1.0, rest := 0.0, lying := false, glow := false) -> void:
	var spec: Dictionary = game.items.get(kind, {"width": 24, "height": 16, "color": 0xffffff})
	var w: float = spec.width
	var h: float = spec.height
	if lying:
		base += Vector2(0, 1.0 - float(ITEM_REST_LIFT.get(kind, 0.0)) * h * ITEM_SCALE) # un pixel dentro la superficie
	var center := base + (Vector2(0, -h / 2) * ITEM_SCALE).rotated(rest)
	draw_set_transform(center, spin + rest, Vector2.ONE * ITEM_SCALE)
	_ink = GLOW_INK if glow else item_ink(_color(spec.color))
	_ink_width = GLOW_INK_WIDTH if glow else ITEM_INK_WIDTH
	_light = Color.WHITE if kind in ARCADE_ITEMS else item_light(_sun, _palette.get("sky", Color.WHITE))
	var now := Time.get_ticks_msec()
	if kind == "banana":
		_draw_banana(w, h)
	elif kind == "fiore":
		# La foglia alla luce dell'arena; da vicino il contorno chiaro è una foglia un po' più grande dietro (#498)
		if glow:
			draw_leaf(self, Vector2(0, h / 2 + 2), h * 1.45, GLOW_INK)
		else:
			draw_leaf(self, Vector2(0, h / 2), h * 1.3, _lit(FLOWER_GREEN.lightened(0.1)))
	elif kind == "pacman":
		# Pac-Man (#427): raggi arcade che girano dietro, la bocca che mastica, l'occhio e una pallina davanti
		_draw_arcade_rays(w, ArcadeView.PAC_YELLOW, now)
		var chew := 0.08 + 0.25 * absf(sin(now / 120.0))
		var pts := PackedVector2Array([Vector2(-w * 0.08, 0)])
		for k in 17:
			pts.append(Vector2.from_angle(chew * PI + (TAU - 2.0 * chew * PI) * k / 16.0) * w / 2.0)
		draw_colored_polygon(pts, ArcadeView.PAC_YELLOW)
		var shade := PackedVector2Array()
		for k in 9:
			shade.append(Vector2.from_angle(PI * 0.35 + PI * 0.55 * k / 8.0) * w * 0.46)
		draw_polyline(shade, ArcadeView.PAC_YELLOW.darkened(0.25), 3.0)
		_ink_outline(pts)
		draw_circle(Vector2(w * 0.04, -w * 0.27), 2.6, ArcadeView.INK)
		draw_circle(Vector2(w * 0.68, 0), 3.5, ArcadeView.INK)
		draw_circle(Vector2(w * 0.68, 0), 2.5, ArcadeView.PELLET)
	elif kind == "bassanese":
		BassaneseView.draw_phone(self, w, h, Time.get_ticks_msec()) # Chiama Bassanese: il telefono che squilla
	elif kind == "tetris":
		# Il Tetris (#427): raggi arcade e un pezzo a T che brilla, con i quadretti in rilievo
		_draw_arcade_rays(w, Color(0.3, 0.85, 1.0), now)
		var q := w / 3.0
		for c: Vector2 in [Vector2(-1.5, -0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5)]:
			_arcade.draw_cell(self, c * q, q, Color("b04df0"))
		_ink_outline(PackedVector2Array([Vector2(-1.5, -0.5) * q, Vector2(1.5, -0.5) * q, Vector2(1.5, 0.5) * q, Vector2(0.5, 0.5) * q,
			Vector2(0.5, 1.5) * q, Vector2(-0.5, 1.5) * q, Vector2(-0.5, 0.5) * q, Vector2(-1.5, 0.5) * q]), 2.5)
	elif kind == "bong":
		_draw_bong(spec, h, load)
	elif kind == "fungo":
		_draw_mushroom(w, h, alpha)
	elif kind == "funghetti":
		_draw_mushroom_bag(w, h)
	elif kind == "fungoTeemo":
		_draw_teemo(w, h, alpha)
	else:
		draw_rect(Rect2(-w / 2, -h / 2, w, h), _lit(_color(spec.color)))
		draw_rect(Rect2(-w / 2, -h / 2, w, h), _ink, false, 2.0 * _ink_width)
	draw_set_transform(Vector2.ZERO)
	_ink = ArcadeView.INK
	_ink_width = 1.0
	_light = Color.WHITE


# Il contorno a inchiostro di un poligono chiuso
func _ink_outline(pts: PackedVector2Array, width := 2.0, alpha := 1.0) -> void:
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(_ink, _ink.a * alpha), width * _ink_width, true)


# Dietro ai power-up arcade (#427): un sole di raggi che gira piano, come nei cabinati
func _draw_arcade_rays(w: float, col: Color, now: int) -> void:
	if Access.calm:
		return
	var turn := now / 2400.0
	var pulse := 0.5 + 0.5 * sin(now / 220.0)
	draw_circle(Vector2.ZERO, w * (0.8 + 0.08 * pulse), Color(col, 0.16 + 0.1 * pulse))
	for k in 8:
		var a := turn + TAU * k / 8.0
		draw_colored_polygon(PackedVector2Array([Vector2.from_angle(a - 0.13) * w * 0.45, Vector2.from_angle(a) * w * (1.05 + 0.1 * pulse), Vector2.from_angle(a + 0.13) * w * 0.45]), Color(col.lightened(0.3), 0.3))


# La banana: una mezzaluna piena che si assottiglia verso le punte, col picciolo, le punte scure e una luce
func _draw_banana(w: float, h: float) -> void:
	var hub := Vector2(0, -h * 0.95)
	var radius := h * 1.3
	var thick := h * 0.78
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 15:
		var u := k / 14.0
		var a := lerpf(PI * 0.2, PI * 0.8, u)
		var t := thick * (0.3 + 0.7 * sin(PI * u))
		outer.append(hub + Vector2.from_angle(a) * (radius + t * 0.5))
		inner.append(hub + Vector2.from_angle(a) * (radius - t * 0.5))
	inner.reverse()
	var body := outer + inner
	draw_colored_polygon(body, _lit(Color("f4c81c")))
	# L'ombra sotto e la luce sopra, due strisce che seguono la curva
	var under := PackedVector2Array()
	var shine := PackedVector2Array()
	for k in 9:
		var a := lerpf(PI * 0.3, PI * 0.7, k / 8.0)
		under.append(hub + Vector2.from_angle(a) * (radius + thick * 0.28))
		shine.append(hub + Vector2.from_angle(a) * (radius - thick * 0.12))
	draw_polyline(under, _lit(Color("d99a12")), 3.5, true)
	draw_polyline(shine, _lit(Color(1, 0.97, 0.75)), 2.0, true)
	_ink_outline(body, 1.5)
	draw_circle(outer[0].lerp(inner[inner.size() - 1], 0.5), 2.8, _lit(Color("4a2e14")))
	var tip := outer[outer.size() - 1].lerp(inner[0], 0.5)
	draw_line(tip, tip + Vector2(-2, -6), _lit(Color("6b4a1e")), 3.5)


# Il bong (#302): tubo di vetro con l'acqua, il fornelletto di lato e il boccaglio in alto.
# In carica l'acqua gorgoglia e sopra c'è la barra
func _draw_bong(spec: Dictionary, h: float, load: float) -> void:
	var w: float = spec.width
	var glass := _lit(Color(0.75, 0.95, 0.9, 0.55))
	var base := Rect2(-w / 2, h * 0.12, w, h * 0.38)
	var neck := Rect2(-w * 0.22, -h / 2, w * 0.44, h * 0.64)
	# Il fornelletto, inclinato verso l'esterno, dietro al vetro
	draw_line(Vector2(w * 0.3, h * 0.32), Vector2(w * 0.85, h * 0.02), _ink, 2.5 + 3.0 * _ink_width)
	draw_line(Vector2(w * 0.3, h * 0.32), Vector2(w * 0.85, h * 0.02), _lit(Color(0.85, 1, 0.95)), 2.5)
	draw_circle(Vector2(w * 0.88, 0), 3.2 + 1.3 * _ink_width, _ink)
	draw_circle(Vector2(w * 0.88, 0), 3.2, _lit(Color("8a5a32")))
	var body := PackedVector2Array([neck.position, Vector2(neck.end.x, neck.position.y), Vector2(neck.end.x, base.position.y), Vector2(base.end.x, base.position.y + 4),
		base.end, Vector2(base.position.x, base.end.y), Vector2(base.position.x, base.position.y + 4), Vector2(neck.position.x, base.position.y)])
	draw_colored_polygon(body, glass)
	var water := _lit(Color(0.35, 0.75, 0.6, 0.85))
	draw_rect(Rect2(base.position.x + 2, base.position.y + base.size.y * 0.35, base.size.x - 4, base.size.y * 0.6), water)
	draw_line(Vector2(base.position.x + 2, base.position.y + base.size.y * 0.35), Vector2(base.end.x - 2, base.position.y + base.size.y * 0.35), water.lightened(0.4), 1.5)
	# Il riflesso sul vetro, una riga chiara a sinistra
	draw_line(neck.position + Vector2(3, 4), Vector2(neck.position.x + 3, base.position.y - 2), Color(1, 1, 1, 0.75), 2.0)
	draw_line(Vector2(base.position.x + 3, base.position.y + 6), Vector2(base.position.x + 3, base.end.y - 4), Color(1, 1, 1, 0.6), 2.0)
	_ink_outline(body)
	draw_line(neck.position + Vector2(-2, 0), Vector2(neck.end.x + 2, neck.position.y), _ink, 3.0 * _ink_width)
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
	var stem := PackedVector2Array([base + Vector2(-w * 0.17, 0), base + Vector2(-w * 0.13, -h * 0.55), base + Vector2(w * 0.13, -h * 0.55), base + Vector2(w * 0.17, 0)])
	draw_colored_polygon(stem, _lit(Color(0.95, 0.9, 0.8, alpha)))
	_ink_outline(stem, 1.5, alpha)
	var cap := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		cap.append(base + Vector2(0, -h * 0.5) + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.55))
	draw_colored_polygon(cap, _lit(Color(0.8, 0.15, 0.2, alpha)))
	draw_line(base + Vector2(-w * 0.42, -h * 0.55), base + Vector2(w * 0.42, -h * 0.55), _lit(Color(0.55, 0.08, 0.12, alpha)), 2.0)
	for d in [Vector2(-0.22, -0.72), Vector2(0.15, -0.85), Vector2(0.3, -0.62)]:
		draw_circle(base + Vector2(d.x * w, d.y * h), maxf(1.5, w * 0.08), _lit(Color(1, 1, 1, alpha)))
	_ink_outline(cap, 1.5, alpha)


# Il sacchetto dei funghetti: tela viola chiusa col laccio dorato, e tre cappelli che spuntano dalla bocca
func _draw_mushroom_bag(w: float, h: float) -> void:
	for k in 3:
		_draw_mushroom(w * 0.5, h * 0.55, 1.0, Vector2((k - 1) * w * 0.24, -h * 0.62 + absf(k - 1) * h * 0.08))
	var cloth := _lit(Color(0.45, 0.25, 0.55))
	var neck := PackedVector2Array([Vector2(-w * 0.36, -h * 0.36), Vector2(w * 0.36, -h * 0.36), Vector2(w * 0.2, -h * 0.12), Vector2(-w * 0.2, -h * 0.12)])
	draw_colored_polygon(neck, cloth.lightened(0.1))
	_ink_outline(neck, 1.5)
	var bag := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		bag.append(Vector2(0, h * 0.14) + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.38))
	draw_colored_polygon(bag, cloth)
	draw_arc(Vector2(-w * 0.1, h * 0.12), w * 0.26, PI * 0.95, PI * 1.45, 8, cloth.lightened(0.3), 2.5)
	_ink_outline(bag)
	draw_line(Vector2(-w * 0.24, -h * 0.17), Vector2(w * 0.24, -h * 0.17), _lit(Color(0.95, 0.8, 0.35)), 2.5)
	draw_circle(Vector2(w * 0.26, -h * 0.13), 2.2, _lit(Color(0.95, 0.8, 0.35)))


# Il fungo di Teemo (#419), ricalcato sulla Trappola velenosa di LoL: cappello bulboso, quasi una palla, verde oliva
# puntinato e più scuro sotto, macchie grandi e irregolari magenta bordate di scuro, gambo corto marrone-grigio
# quasi nascosto. Contorno a inchiostro come il resto del gioco. La base è in basso al centro, alla quota dei piedi.
# Niente draw_set_transform: chi chiama ne ha già una (in mano, in volo, mentre si gonfia)
func _draw_teemo(w: float, h: float, alpha: float, offset := Vector2.ZERO) -> void:
	if alpha <= 0.01:
		return
	var base := offset + Vector2(0, h / 2)
	# Il gambo: corto, si stringe verso il cappello, che ne copre la cima
	var stem := PackedVector2Array([base + Vector2(-w * 0.12, -h * 0.42), base + Vector2(w * 0.1, -h * 0.42), base + Vector2(w * 0.14, 0), base + Vector2(-w * 0.13, 0)])
	draw_colored_polygon(stem, _lit(Color(SHROOM_STEM, alpha)))
	_ink_outline(stem, 1.5, alpha)
	# Il cappello: quasi una palla, col fondo che rientra sotto (la metà bassa dell'ellisse è schiacciata)
	var c := base + Vector2(0, -h * 0.5)
	var rx := w * 0.5
	var ry := h * 0.55
	var cap := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		var y := sin(a) * ry
		cap.append(c + Vector2(cos(a) * rx, y * (0.42 if y > 0.0 else 1.0)))
	draw_colored_polygon(cap, _lit(Color(SHROOM_GREEN.darkened(0.35), alpha)))
	# Sopra il bordo scuro di sotto, la parte in luce
	var lit := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		var y := sin(a) * ry * 0.92
		lit.append(c + Vector2(cos(a) * rx * 0.93, y * (0.12 if y > 0.0 else 1.0) - h * 0.02))
	draw_colored_polygon(lit, _lit(Color(SHROOM_GREEN, alpha)))
	# Riflesso in alto a sinistra e puntini più chiari, la pelle ruvida del fungo
	draw_circle(c + Vector2(-rx * 0.38, -ry * 0.58), w * 0.12, _lit(Color(SHROOM_GREEN.lightened(0.18), alpha * 0.8)))
	for k in 12:
		var u := fmod(k * 0.618, 1.0) * 1.6 - 0.8
		var v := fmod(k * 0.381 + 0.2, 1.0) * -0.85
		draw_circle(c + Vector2(u * rx, v * ry), maxf(0.8, w * 0.018), _lit(Color(SHROOM_GREEN.lightened(0.3), alpha * 0.8)))
	# Le macchie: (u, v) sul cappello in unità del raggio, e la grandezza. Verso i bordi si schiacciano, come su una palla
	for d in [Vector3(-0.5, -0.38, 0.15), Vector3(0.08, -0.78, 0.12), Vector3(0.5, -0.4, 0.13), Vector3(-0.12, -0.1, 0.11), Vector3(0.74, -0.02, 0.08), Vector3(-0.8, -0.06, 0.07), Vector3(0.32, -0.04, 0.06)]:
		var spot := c + Vector2(d.x * rx, d.y * ry)
		var r: float = d.z * w
		var qx := sqrt(maxf(0.25, 1.0 - d.x * d.x))
		var qy := sqrt(maxf(0.35, 1.0 - d.y * d.y))
		var blob := PackedVector2Array()
		for j in 16:
			var a := TAU * j / 16.0
			var wobble := 1.0 + 0.12 * sin(j * 1.9 + d.x * 9.0)
			blob.append(spot + Vector2(cos(a) * r * qx * wobble, sin(a) * r * qy * wobble))
		draw_colored_polygon(blob, _lit(Color(SHROOM_PURPLE, alpha)))
		_ink_outline(blob, 1.0, alpha * 0.6)
		draw_circle(spot + Vector2(-r * 0.3 * qx, -r * 0.3 * qy), r * 0.22, _lit(Color(SHROOM_PURPLE.lightened(0.3), alpha * 0.8)))
	_ink_outline(cap, 2.0, alpha)


# La nube del fungo di Teemo, in quattro tempi come in LoL: il cappello si gonfia e scoppia, la nube
# verde-viola si allarga a cupola fino a blastRadius, ribolle, poi si dissolve dal basso verso l'alto.
# Intanto qualche spora viola schizza fuori e ricade
func _draw_poison_cloud(c: Dictionary) -> void:
	var age: float = c.age
	var spec: Dictionary = game.items.get("fungoTeemo", {"width": 36, "height": 34})
	var w: float = spec.width
	var h: float = spec.height
	var base := Vector2(c.x, c.y)
	if age < SHROOM_POP_MS:
		# 1. Il cappello si gonfia (e sbianca un po') prima di scoppiare
		var swell := age / SHROOM_POP_MS
		draw_set_transform(base - Vector2(0, h / 2), 0.0, Vector2(1.0 + 0.5 * swell, 1.0 + 0.35 * swell))
		_draw_teemo(w, h, 1.0)
		draw_circle(Vector2(0, -h * 0.2), w * 0.5, Color(1, 1, 1, 0.35 * swell))
		draw_set_transform(Vector2.ZERO)
	var t := age - SHROOM_POP_MS * 0.6
	if t < 0.0:
		return
	var k := t / (POISON_CLOUD_MS - SHROOM_POP_MS * 0.6)
	var radius := float(game.get("fungo", {}).get("blastRadius", 70))
	# 2. Si allarga in fretta e frena (ease-out) in circa 200 ms
	var grow := 1.0 - pow(1.0 - clampf(t / 200.0, 0.0, 1.0), 3.0)
	var r := radius * (0.3 + 0.7 * grow)
	# 4. Da metà vita si dissolve: il fronte sale da terra verso la cima
	var fade := clampf((k - 0.5) / 0.5, 0.0, 1.0)
	var center := base - Vector2(0, r * 0.35)
	# Il bordo: sbuffi scuri sulla cupola. Il centro: sbuffi più chiari, davanti
	for layer in 2:
		var n := 12 if layer == 0 else 7
		var spread := 0.62 if layer == 0 else 0.3
		var col := POISON_PURPLE.lerp(POISON_GREEN, 0.35) if layer == 0 else POISON_GREEN.lightened(0.25)
		for i in n:
			var a := PI * 0.95 + PI * 1.1 * i / float(n - 1)
			var wob := Vector2(sin(age / 170.0 + i * 1.7), cos(age / 210.0 + i * 2.3)) * r * 0.05
			var pos := center + Vector2(cos(a) * r * spread * 1.15, sin(a) * r * spread) + wob
			pos.y = minf(pos.y, base.y - 4.0) # la nube sta sopra il terreno
			var low := clampf((pos.y - (base.y - r)) / r, 0.0, 1.0) # 1 = a terra
			var alpha := clampf(1.0 - fade * (1.0 + low * 1.5), 0.0, 1.0) * (0.75 if layer == 0 else 0.6)
			if alpha <= 0.0:
				continue
			draw_circle(pos, r * (0.34 if layer == 0 else 0.3) * (0.9 + 0.1 * sin(i * 2.1 + age / 120.0)), Color(col, alpha))
	# 3. Ribolle: bolle che salgono dentro la nube e scoppiano con un anellino in cima
	for i in 9:
		var bt := fmod(age / 650.0 + i * 0.137, 1.0)
		var bx := base.x + (fmod(i * 0.618, 1.0) - 0.5) * r * 1.3
		var by := base.y - 6.0 - bt * r * 0.95
		var balpha := (1.0 - fade) * 0.9
		if bt < 0.85:
			draw_circle(Vector2(bx, by), 2.0 + 3.0 * bt, Color(POISON_GREEN.lightened(0.45), balpha * 0.8))
		else:
			draw_arc(Vector2(bx, by), 5.0 + 20.0 * (bt - 0.85), 0, TAU, 10, Color(POISON_GREEN.lightened(0.5), balpha), 1.5)
	# Le spore: schizzano fuori a ventaglio verso l'alto e ricadono a terra, dove si spengono
	var ts := age / 1000.0
	for i in 8:
		var a := PI * (0.15 + 0.7 * i / 7.0)
		var speed := 170.0 + 70.0 * fmod(i * 0.37, 1.0)
		var pos := base + Vector2(cos(a) * speed * ts, -sin(a) * speed * ts + 0.5 * 700.0 * ts * ts) - Vector2(0, h * 0.5)
		pos.y = minf(pos.y, base.y - 2.0)
		draw_circle(pos, 2.5, Color(SHROOM_PURPLE.lightened(0.2), clampf(1.0 - k, 0.0, 1.0)))


# Chi è avvelenato dal fungo: una tinta verde sul corpo che pulsa a ogni scatto di danno, bolle verdi che
# salgono dalla testa (più fitte nei primi secondi, quando si è anche rallentati) e una nuvoletta che lo segue
func _draw_poison(p: Dictionary, now: float, fw: float, fh: float) -> void:
	var cfg: Dictionary = game.get("fungo", {})
	var poison_ms := float(cfg.get("poisonMs", 6000))
	var left := float(p.get("powerupMs", 0))
	var pulse := FighterPose.poison_pulse(left, poison_ms, float(cfg.get("poisonTickMs", 500)))
	var slowed := poison_ms - left < float(cfg.get("slowMs", 2000))
	draw_set_transform(Vector2(p.x, p.y - fh * 0.5), 0.0, Vector2(1.0, fh / fw * 0.85))
	draw_circle(Vector2.ZERO, fw * 0.62, Color(POISON_GREEN, 0.14 + 0.3 * pulse))
	draw_set_transform(Vector2.ZERO)
	var n := 8 if slowed else 5
	for k in n:
		var t := fmod(now / 900.0 + k / float(n), 1.0)
		var b := Vector2(p.x + sin(k * 2.3 + now / 400.0) * fw * 0.35, p.y - fh - 4.0 - t * 34.0)
		draw_circle(b, 2.0 + 2.5 * (1.0 - t), Color(POISON_GREEN.lightened(0.3), 0.85 * (1.0 - t)))
	for k in 3:
		var puff := Vector2(p.x - float(p.facing) * fw * 0.15 + (k - 1) * 9.0, p.y - fh - 14.0 + sin(now / 300.0 + k) * 2.0)
		draw_circle(puff, 7.0 - absf(k - 1) * 2.0, Color(POISON_PURPLE, 0.45))


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
const POISON_CLOUD_MS := 1100.0 # ms di vita della nube del fungo di Teemo nel client (#419)
const SHROOM_POP_MS := 120.0 # ms in cui il cappello del fungo di Teemo si gonfia prima di scoppiare
const SHROOM_GREEN := Color("5a7631") # il fungo di Teemo, come la Trappola velenosa di LoL: cappello verde oliva
const SHROOM_PURPLE := Color("b03a74") # le macchie magenta
const SHROOM_STEM := Color("6f604c") # il gambo marrone-grigio
const POISON_GREEN := Color(0.62, 0.9, 0.22) # la nube e il veleno: verde tossico che tira al giallo
const POISON_PURPLE := Color(0.55, 0.25, 0.65)
const ITEM_SCALE := 1.3 # gli oggetti si disegnano un po' più grandi della loro scatola di gioco, per vederli bene
const ITEM_INK_WIDTH := 0.55 # gli oggetti hanno un contorno sottile nella loro tinta scura, non l'inchiostro spesso (#498)
const GLOW_INK := Color(1.0, 0.96, 0.82, 0.95) # il contorno chiaro di un oggetto che si può raccogliere (#498)
const GLOW_INK_WIDTH := 2.6 # e quanto è spesso: sta sotto all'oggetto, ne esce mezzo
const ITEM_REST_LIFT := {"banana": 0.22} # frazione dell'altezza che il disegno scende sotto la base: a terra si alza tanto così
const ARCADE_ITEMS := ["pacman", "tetris", "bassanese"] # power-up arcade: brillano di luce loro, non prendono quella dell'arena
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
	if not _collapse.is_empty(): # la torre che cade, dietro a tutto il resto (#433)
		_shake = maxf(_shake, StageCollapse.draw(self, _collapse, t, view_rect))
	var movers: Array = stage.get("movers") if stage.get("movers") != null else []
	var hubs := {} # i mozzi dei getti della fontana (#378), uno per fontana
	for spr in _mover_sprites.values():
		var st: Dictionary = spr.get("stem", {})
		if st.get("hub") is Dictionary and not hubs.has(str(st.hub)):
			hubs[str(st.hub)] = st
			_water.draw_wheel_trunk(self, _stage_light(), st, t)
	for mi in StageMotion.movers_back_to_front(movers, t): # la giostra d'acqua: prima quelle che passano dietro
		var m: Dictionary = movers[mi]
		var pos := StageMotion.mover_position(m, t)
		var fx := _pad_fx(m, t) # i bottoni sonori la alzano o la accendono (#423)
		pos.y += float(fx.dy)
		if m.get("kind", "") == "nota":
			_draw_note_platform(m, pos, t, fx.on)
			continue
		if not StageMotion.mover_on(m, t): # fuori dalle sue finestre non c'è: l'ascensore della Garisenda dopo il crollo (#433)
			continue
		if m.get("kind", "") == "bus": # il bus di Bologna su cui si sale (#433)
			var stopped := StageMotion.mover_position(m, t + 50.0).distance_to(StageMotion.mover_position(m, t)) < 0.5
			BolognaHazards.draw_bus(self, _life, pos, float(m.width), StageMotion.mover_facing(m, t, stage_width()), stopped, t, _stage_light())
			continue
		if m.get("kind", "") == "campana": # la campana appesa tra le torri di Bologna (#433)
			BolognaHazards.draw_bell(self, m, pos, StageMotion.swing_angle(m.swing, t + float(m.get("offsetMs", 0))), t, _stage_light())
			continue
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
	for st in hubs.values(): # la schiuma all'ugello, sopra i piedi dei getti
		_water.draw_hub_foam(self, _stage_light(), st, t)
	var pads: Array = stage.get("pads") if stage.get("pads") is Array else []
	for i in pads.size():
		_draw_pad(pads[i], _pads_pressed[i] if i < _pads_pressed.size() else null, t)
	var hazards: Array = stage.get("hazards") if stage.get("hazards") != null else []
	for i in hazards.size():
		var h: Dictionary = hazards[i]
		if PredictMovement.piece_on(h, t): # fuori dalle sue finestre la trappola non c'è (#433)
			_draw_hazard(h, StageMotion.hazard_active(h, t), t, i)
	var rain := _rain_now(t) # dall'acqua alta o dalla pioggia dello sfondo vivo (#288)
	if rain > 0.0:
		_draw_rain(rain, t)
	var jets: Array = stage.get("jets") if stage.get("jets") is Array else []
	for j in jets:
		if not PredictMovement.piece_on(j, t): # getto a tempo (#433)
			continue
		if j.get("kind", "") == "tenda": # la bancarella col tendone che fa da molla (#433): si schiaccia sotto chi ci arriva
			BolognaHazards.draw_awning(self, j, BolognaHazards.awning_squash(j, positions.values()), t, _stage_light())
		elif j.get("kind", "") == "corrente": # la corrente calda delle macerie (#433): braci, foglie e carta che salgono
			BolognaHazards.draw_updraft(self, j, t, _stage_light())
		else:
			_water.draw_jet(self, _stage_light(), j, t)


func _draw_hazard(h: Dictionary, on: bool, t: float, index := -1) -> void:
	var r := StageMotion.hazard_rect(h, t)
	var warn := HazardFx.warn_progress(h, t) # l'avviso prima di accendersi (#433), la fisica non cambia
	if warn >= 0.0:
		HazardFx.draw_warning(self, h, r, warn, t, view_rect)
	match h.kind:
		"ciclista":
			_draw_cyclist(h, r, t, index)
		"auto":
			# L'auto della piazza di Bologna (#433): come il ciclista, il clacson prima e poi passa
			var tp := StageMotion.travel_phase(h, t)
			var dir := StageMotion.travel_direction(h, t)
			if tp.phase == "warn":
				_draw_bell_warning(r, dir, t, "PIII PIII!")
			elif tp.phase == "cross":
				var lap := int(floorf((t + float(h.travel.get("offsetMs", 0))) / float(h.travel.periodMs)))
				BolognaHazards.draw_car(self, _life, r, dir, lap, _stage_light())
		"ingorgo":
			BolognaHazards.draw_jam(self, _life, h, r, on, t, _stage_light())
		"mattone":
			var tp := StageMotion.travel_phase(h, t)
			BolognaHazards.draw_brick(self, h, r, tp.phase, tp.k, t, _stage_light())
		"polvere":
			var fp := StageMotion.flood_phase(h, t)
			BolognaHazards.draw_dust(self, r, fp.phase, fp.k, t, _stage_light())
		"fulmine":
			if on:
				HazardFx.draw_lightning(self, r, t, fposmod(t + float(h.get("offsetMs", 0)), float(h.get("periodMs", 1))), view_rect, Access.calm)
				_shake = maxf(_shake, 5.0)
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
			if effects and _particles: # #470 fase 4: fiamme vere a particelle e fumo nero
				_draw_fire_pit(h, r, t, index)
				return
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
	_sun = {}
	if _life.is_empty() or not _life.life.get("daycycle") is Dictionary:
		return
	var l := SunLight.light(_life.sky.day_phase(t))
	_sun = l # anche gli oggetti a terra prendono questa luce e fanno questa ombra (#498)
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
		if not prop_casts_shadow(pr):
			continue
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


# Un pavimento o una vasca con l'ombra già dipinta (shadow: false, #378) non fa ombra a terra: larga quanto il piano
# dell'isola diventava una striscia grigia sul bordo dove si cammina
static func prop_casts_shadow(pr: Dictionary) -> bool:
	return bool(pr.get("shadow", true))


func _draw_shadow(s: Array) -> void:
	if float(s[1]) <= 0.0:
		return
	var pts: PackedVector2Array = s[0]
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	# Un'ombra sfumata (#378, Riccardo: non due cerchi uno dentro l'altro): tanti ovali sempre più piccoli e leggeri
	# uno sopra l'altro, così dal centro scuro si arriva al bordo trasparente senza scalini.
	# q -> c + (q - c) * k, fatto dal motore su tutto il poligono invece che punto per punto in GDScript
	for i in SHADOW_STEPS:
		var k := 1.0 - 0.75 * i / float(SHADOW_STEPS)
		_draw_convex(Transform2D(0.0, Vector2(k, k), 0.0, c * (1.0 - k)) * pts, Color(0.05, 0.05, 0.1, float(s[1]) * SHADOW_STEP_ALPHA))


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
		if x >= float(s.x) and x <= float(s.x) + float(s.width) and float(s.y) >= y and PredictMovement.piece_on(s, _t_draw, _prize_team):
			best = minf(best, float(s.y))
	for p in stage.platforms:
		if x >= float(p.x) and x <= float(p.x) + float(p.width) and PredictMovement.piece_on(p, _t_draw, _prize_team):
			var sy := PredictMovement.surface_y(p, x)
			if sy >= y:
				best = minf(best, sy)
	return best


# La barca del canale (#264): ponte di legno dove si sta in piedi (y), scafo scuro sotto, prua e poppa rialzate
func _pad_fx(m: Dictionary, t: float) -> Dictionary:
	if _pads_pressed.is_empty() or not (stage.get("pads") is Array):
		return {"on": false, "dy": 0.0}
	return StageMotion.pad_fx(m, t, stage.pads, _pads_pressed, float(game.get("pad", {}).get("rampMs", 250)))


# Bottone sonoro (#423): una base scura e un tasto colorato che sporge. Appena premuto si abbassa e brilla;
# finché si ricarica è grigio e una barra si riempie, carico pulsa piano col suo colore
const PAD_COLORS := {"accordo": 0xffb74d, "piatto": 0x81c784, "cassa": 0x4fc3f7}


func _draw_pad(p: Dictionary, pressed_at: Variant, t: float) -> void:
	var w: float = p.width
	var x: float = p.x
	var y: float = p.y
	var h: float = game.get("pad", {}).get("heightPx", 14)
	var col := _color(PAD_COLORS.get(str(p.sound), 0xff4fd8))
	var charge := StageMotion.pad_charge(p, pressed_at, t)
	var since := INF if pressed_at == null else t - float(pressed_at)
	var down := since < 200.0 # schiacciato per un attimo
	draw_rect(Rect2(x - 4, y - 5, w + 8, 5), Color(0.08, 0.06, 0.12)) # la base
	var cap_h := h * (0.35 if down else 1.0)
	var cap := Rect2(x + 4, y - 5 - cap_h, w - 8, cap_h)
	if charge >= 1.0:
		var glow := 0.18 + 0.12 * (0.5 + 0.5 * sin(t / 300.0))
		draw_rect(cap.grow(5), Color(col, glow))
		draw_rect(cap, col)
		draw_rect(Rect2(cap.position, Vector2(cap.size.x, 3)), col.lightened(0.5))
	else:
		if down:
			draw_rect(cap.grow(10), Color(col, 0.5))
		draw_rect(cap, Color(0.35, 0.35, 0.4) if not down else col)
		draw_rect(Rect2(x, y + 3, w * charge, 4), col) # la carica che torna
	# Il simbolo del suono sul tasto: una nota per l'accordo, un cerchio per la cassa, una riga per il piatto
	var c := cap.get_center()
	var ink := Color(0.1, 0.07, 0.15, 0.8)
	match str(p.sound):
		"accordo":
			draw_circle(c + Vector2(-2, 2), 3.0, ink)
			draw_line(c + Vector2(1, 2), c + Vector2(1, -5), ink, 1.5)
		"cassa":
			draw_arc(c, 4.0, 0, TAU, 12, ink, 1.5)
		_:
			draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), ink, 2.0)


# Arena musicale (#423): la piattaforma nel colore della sua traccia. Un tasto spento è solo un contorno tenue,
# che lampeggia nei NOTE_WARN_MS prima della nota: si vede dove comparirà
const NOTE_WARN_MS := 400.0


func _draw_note_platform(m: Dictionary, pos: Vector2, t: float, forced := false) -> void:
	var w: float = m.width
	var tint := _color(m.get("tint", 0x9ad0ff))
	if forced:
		tint = tint.lightened(0.35) # accesa da un bottone: più chiara, si capisce che non è la nota
	if not forced and not StageMotion.mover_on(m, t):
		var next := StageMotion.mover_next_on(m, t)
		var a := 0.12
		if next < NOTE_WARN_MS:
			a = 0.25 + 0.35 * (0.5 + 0.5 * sin(t / 45.0))
		draw_rect(Rect2(pos.x, pos.y, w, 10), Color(tint, a), false, 2.0)
		return
	draw_rect(Rect2(pos.x - 4, pos.y - 4, w + 8, 18), Color(tint, 0.22)) # il bagliore
	draw_rect(Rect2(pos.x, pos.y, w, 10), tint)
	draw_rect(Rect2(pos.x, pos.y, w, 3), tint.lightened(0.5))
	if _wonder.active: # nell'arena musicale ha la faccia e guarda chi le sta più vicino (#423)
		_wonder.draw_face(self, pos, w, tint, t, _nearest_fighter(pos + Vector2(w / 2.0, 0)), _wonder.since_on(m, t))
		return
	# Sotto, tre teste di nota: si capisce che la muove la musica
	for i in 3:
		var c := Vector2(pos.x + w * (i + 1) / 4.0, pos.y + 15)
		draw_circle(c, 3.5, tint.darkened(0.25))


func _nearest_fighter(from: Vector2) -> Variant:
	var best: Variant = null
	for p: Vector2 in positions.values():
		if best == null or p.distance_to(from) < (best as Vector2).distance_to(from):
			best = p
	return best


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
	var stem: Dictionary = spr.get("stem", {})
	if not stem.is_empty(): # lo spruzzo che regge la piattaforma (#378), sotto di lei
		# il getto arriva al bottone sotto la tazza (26 pixel sotto il piano): si vede che è l'acqua a reggerla
		_water.draw_mover_stem(self, _stage_light(), stem, pos.x + w / 2.0, pos.y + (26.0 if stem.get("hub") is Dictionary else 4.0), t, float(spr.get("phase", 0.0)), w)
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
	if _life.has_sheet("bici"):
		# Senza Cancaro Man ma con la bici dipinta dello sfondo vivo (Bologna, #433): quella, larga quanto la trappola
		var sh: Dictionary = _life.sheet("bici")
		_life.draw_frame(self, "bici", int(t / 110.0), Vector2(r.get_center().x, r.end.y), r.size.x / (float(sh.fw) * float(sh.scale)), dir < 0, _stage_light(), true)
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


func _draw_bell_warning(r: Rect2, dir: int, t: float, text := "DRIN DRIN!") -> void:
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
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(x - tw / 2, y - 30 * s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_string(font, Vector2(x - 4 * s, y + 6 * s), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), col)


# Pioggia su tutta l'arena: gocce oblique in posizioni fisse che scorrono col tempo dell'arena
func _draw_rain(strength: float, t: float) -> void:
	var w := stage_width() + 800.0
	var hgt: float = world_height() + 600.0
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
	# A Tetris (#427) si è fuori dalla partita: al posto del lottatore il cabinato
	if p.get("powerup") == "tetris" and not p.respawning:
		_arcade.draw_cabinet(self, p, Access.color(p.color), int(now))
		return
	if p.get("powerup") == "pacman" and not p.respawning:
		_arcade.draw_pacman(self, p, Access.color(p.color), int(now), float(game.get("pacman", {}).get("radiusPx", 34)))
		return
	# Chi fa la suprema propria (#102) è invulnerabile ma appeso alla liana: non lampeggia
	# Col fiore (#231) si è intoccabili per 8 s: invece di lampeggiare si ha l'alone verde
	var powered: bool = p.get("powerup") == "fiore" and not away
	var high: bool = p.get("powerup") == "bong" and not away # col bong (#302) si fuma ma si resta colpibili
	# chi fa la suprema è intoccabile ma non lampeggia: la sta facendo lui (DEMACIAAA dura quasi 2 s)
	var blink: bool = p.invulnerable and not away and not powered and not _supreme_view.holds(p.id, now) and p.get("attack") != "supreme" and _dodge_look(p.id, now).y >= 1.0
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
	if int(p.team) > 0:
		_draw_team_ring(p, fw)
	var react := _reaction_transform(p, now) * _motion_transform(p, now)
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
	if p.get("powerup") == "spore" and not away:
		# Infettati dal filo di Kirschner (#358): spore verdi che salgono intorno al corpo
		for k in 6:
			var t := fmod(now / 1400.0 + k / 6.0, 1.0)
			draw_circle(Vector2(p.x + sin(k * 2.1 + now / 500.0) * fw * 0.6, p.y - fh * t), 3.5, Color(0.66, 0.77, 0.42, 1.0 - t))
	if p.get("powerup") == "micelio" and not away:
		# Dr. Micelium più forte (#358): un alone di micelio che pulsa
		draw_arc(Vector2(p.x, p.y - fh * 0.5), fh * (0.62 + 0.04 * sin(now / 160.0)), 0, TAU, 32, Color(0.66, 0.77, 0.42, 0.55), 4.0)
	if p.get("powerup") == "veleno" and not away:
		_draw_poison(p, now, fw, fh) # avvelenati dal fungo di Teemo (#419)
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
	if p.get("stunned", false) or float(_dizzy.get(p.id, 0.0)) > now: # anche dopo uno schianto a terra (#470)
		for i in int(game.effects.stunStars):
			var a := now / 300.0 + TAU * i / float(game.effects.stunStars)
			var star := Vector2(p.x + cos(a) * fw * 0.6, p.y - head - 18 - Access.px(16) + sin(a) * 6) # sopra il nome
			_draw_star(star, 6.0, Color(1, 0.9, 0.3))

	# Allenamento: il corpo che si può colpire, lo stesso rettangolo della fisica
	if show_hitboxes:
		var hb: Dictionary = game.characters.get(p.characterId, {}).get("hurtbox", {"width": fw, "height": fh})
		draw_rect(Rect2(p.x - hb.width / 2, p.y - hb.height, hb.width, hb.height), Color(0.3, 1, 0.5, 0.9), false, 2.0)

	# Colpo in corso: la stessa hitbox di attackBox() in src/shared/physics/attacks.ts,
	# spostata da boxX/boxY per le varianti direzionali (#2)
	# Si può nascondere dalle opzioni; in allenamento "Mostra hitbox" lo fa vedere comunque
	var spec := FighterPose.attack_spec(game, p.characterId, str(p.attack)) if p.attack != null and (attack_boxes or show_hitboxes) else {}
	if not spec.is_empty(): # un attacco che questa versione non conosce non ha rettangolo
		var c := Color("ff9f43") if str(p.attack).begins_with("heavy") else Color.WHITE
		c.a = 0.85 if p.attackActive else 0.25
		draw_rect(_attack_rect(p, spec), c)

	var label := "%s  %d%%" % [p.name, roundi(p.percent)]
	var size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, Access.px(16))
	var label_pos := Vector2(p.x - size.x / 2, p.y - head - 10)
	if int(p.team) > 0:
		# A squadre il nome ha il colore della squadra, bordato di scuro perché si legga su ogni sfondo (#409)
		draw_string_outline(_font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), TEAM_NAME_OUTLINE, Color(0, 0, 0, 0.85))
		draw_string(_font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), Access.team_color(game, int(p.team)).lightened(TEAM_NAME_LIGHTEN))
	else:
		draw_string(_font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(16), Color.WHITE)
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


# Squadre (#409): un anello del colore della squadra sotto i piedi, come nei picchiaduro a squadre:
# si capisce chi è con chi anche quando i lottatori hanno colori simili o si mescolano
func _draw_team_ring(p: Dictionary, fw: float) -> void:
	var c := Access.team_color(game, int(p.team))
	var rx := fw * TEAM_RING_WIDTH
	draw_set_transform(Vector2(p.x, p.y), 0.0, Vector2(1.0, TEAM_RING_SQUASH))
	draw_circle(Vector2.ZERO, rx, Color(c, 0.28))
	draw_arc(Vector2.ZERO, rx, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 7.0)
	draw_arc(Vector2.ZERO, rx, 0.0, TAU, 32, c, 4.0)
	draw_set_transform(Vector2.ZERO)


# La zona del colpo in corso: la stessa hitbox di attackBox() in src/shared/physics/attacks.ts,
# spostata da boxX/boxY per le varianti direzionali (#2)
func _attack_rect(p: Dictionary, spec: Dictionary) -> Rect2:
	var fw: float = game.fighter.width
	var fh: float = game.fighter.height
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
	if spec.get("bothSides", false) and dog == null:
		return Rect2(o.x - front - spec.range, y, 2.0 * (front + spec.range), spec.height) # davanti e dietro, come attackBox()
	var x: float = o.x + front if p.facing == 1 else o.x - front - spec.range
	return Rect2(x, y, spec.range, spec.height)


# La scia del colpo (#384 B2): una mezzaluna che spazza la zona d'attacco mentre il colpo è attivo.
# Il colore è quello del personaggio (strikeColor in characters.ts), altrimenti bianco o arancio per i pesanti
func _draw_strike(p: Dictionary, now: float) -> void:
	var kind := str(p.attack) if p.attack != null else ""
	# Solo leggeri, pesanti e attacco in corsa: prese, speciali e supreme hanno già i loro disegni
	if not effects or not p.attackActive or not (kind.begins_with("light") or kind.begins_with("heavy") or kind == "dashAttack"):
		_strikes.erase(p.id)
		return
	# Chi ha la scia già disegnata nei fotogrammi (#506) non ne prende una seconda sopra
	var look_sprite: Variant = _look(p).get("sprite")
	if look_sprite is Dictionary and look_sprite.get("drawnSmear", false):
		return
	var spec := FighterPose.attack_spec(game, p.characterId, str(p.attack))
	if spec.is_empty() or spec.get("range") == null:
		return
	if not _strikes.has(p.id) or _strikes[p.id].kind != str(p.attack):
		_strikes[p.id] = {"kind": str(p.attack), "at": now}
	var box := _attack_rect(p, spec)
	var chest := Vector2(p.x, p.y - float(game.fighter.height) * 0.6)
	var progress := _fight_ms(now, float(_strikes[p.id].at)) / maxf(1.0, float(spec.get("activeMs", 100)) * 0.6)
	var heavy: bool = kind.begins_with("heavy") or kind == "dashAttack"
	var own: Variant = game.characters.get(p.characterId, {}).get("strikeColor")
	var col: Color = Color(own) if own is String else (Color(1, 0.75, 0.35) if heavy else Color.WHITE)
	col.a = 0.55
	# Il colpo dai due lati (pesante in giù) ha una scia per lato, ognuna sulla sua metà del rettangolo
	var sides: Array = [[int(p.facing), box]]
	if spec.get("bothSides", false):
		var half := box.size.x / 2.0
		sides = [[1, Rect2(box.position.x + half, box.position.y, half, box.size.y)], [-1, Rect2(box.position, Vector2(half, box.size.y))]]
	for side in sides:
		var arc := StrikeFx.arc_for(chest, side[0], side[1])
		var poly := StrikeFx.crescent(arc, progress, float(game.effects.strikeWidth) * (1.5 if heavy else 1.0))
		if poly.size() >= 3:
			draw_colored_polygon(poly, col)


# Chi vola via forte (lanciato, non chi salta) ha delle linee di velocità dietro, come nei fumetti (#384 B2)
func _draw_speed_lines(p: Dictionary) -> void:
	var vel := Vector2(p.vx, p.vy)
	if not effects or not p.hitstun or vel.length() < float(game.effects.speedLinesSpeed) or p.respawning:
		return
	var fx: Dictionary = game.effects
	var mid := Vector2(p.x, p.y - float(game.fighter.height) * 0.5)
	var col := Color(1, 1, 1, 0.6)
	for l in StrikeFx.speed_lines(mid, vel, int(fx.speedLines), float(fx.speedLinesLength), float(game.fighter.width) * 0.7, hash(p.id)):
		draw_line(l[0], l[1], col, 2.0)


# Tempo del combattimento da since (#384 A4)
func _fight_ms(now: float, since: float) -> float:
	return FighterPose.fight_elapsed(game, now, since)


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
		if _fight_ms(now, float(state.since)) < FighterPose.animation_ms(anims[prev_name], FighterPose.attack_spec(game, p.characterId, prev_kind)):
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
		state = {"name": name, "since": since, "kind": kind, "start": since}
		_anims[p.id] = state
	if FighterPose.smash_charging(p):
		state["since"] = now # il colpo caricato resta fermo sul primo fotogramma finché non si lascia il tasto
	state["attacking"] = p.attack != null
	var a: Dictionary = anims[name]
	var attack := FighterPose.attack_spec(game, p.characterId, str(state.get("kind", "")))
	var dodge := _dodge_look(p.id, now) # #470: la schivata, sagoma chiara e trasparente
	var tint := FighterPose.sprite_modulate(int(_variants.get(p.id, 0)), FighterPose.away_alpha(p) * dodge.y, maxf(maxf(FighterPose.charge_flash(p, now, Access.calm), _hit_flash(p.id, now)), dodge.x))
	var rig: RefCounted = _rigs.get(character.id) if use_rigs else null
	if rig != null and rig.has_state(str(a.src)):
		# a pezzi (#403): stessi stati e stessi tempi, ma la posa si interpola invece di saltare di fotogramma in fotogramma
		var feet := react * Transform2D(0.0, Vector2(p.facing, 1.0), 0.0, Vector2(p.x, p.y))
		# pose chiave e movimento secondario (#404): passaggi tra stati, respiro, sguardo, crocchia, smear del mattarello
		if not _rig_motion.has(p.id):
			_rig_motion[p.id] = RigMotion.new()
		var motion: RefCounted = _rig_motion[p.id]
		var pose: PackedFloat32Array = rig.pose_at(str(a.src), _fight_ms(now, float(state.since)), attack, a)
		pose = motion.apply(rig, pose, now, _rig_context(p, name, state, attack))
		rig.draw(self, feet, pose, tint, motion.smear)
		return
	var frame := FighterPose.sprite_frame(a, _fight_ms(now, float(state.since)), attack)
	var fw: float = sheet.frameWidth
	var fh: float = sheet.frameHeight
	# Nel foglio unico ogni animazione è una riga; nel formato cartella è un PNG a sé, con una riga sola
	var texture: Texture2D = _textures[character.id]
	var row: float = a.get("row", 0)
	if _state_textures.has(character.id):
		texture = _state_textures[character.id][a.src]
	var src := frame_region(frame, row, fw, fh, float(_sprite_keep.get(character.id, 1.0)))
	var scale: float = sheet.get("scale", 1.0) # 0.5 per i disegni fatti a 2x
	draw_set_transform_matrix(react * Transform2D(0.0, Vector2(p.facing * scale, scale), 0.0, Vector2(p.x, p.y)))
	var foot_y: float = sheet.get("footY", fh) # dove stanno i piedi nel fotogramma: sotto c'è chi è appeso al bordo
	if outlines:
		tint.b = outline_tint(OUTLINE_PX, fw * scale, src.size.x)
	draw_texture_rect_region(texture, Rect2(-fw / 2, -foot_y, fw, fh), src, tint)
	draw_set_transform(Vector2.ZERO)


# Il blu del modulate che chiede a palette.gdshader il contorno: 2 + spessore in texel / 8. Lo spessore è in pixel
# di mondo, così uno sprite disegnato grande e rimpicciolito ha lo stesso tratto di uno piccolo.
# drawn: quanto è largo il fotogramma nel mondo; texels: quanto è largo nella texture caricata
static func outline_tint(px: float, drawn: float, texels: float) -> float:
	if drawn <= 0.0 or texels <= 0.0:
		return 1.0
	return 2.0 + clampf(px * texels / drawn, 0.5, 7.9) / 8.0


# Quello che il movimento secondario del rig (rig_motion.gd) sa del giocatore: lo stato, quanto corre, chi ha vicino
func _rig_context(p: Dictionary, name: String, state: Dictionary, attack: Dictionary) -> Dictionary:
	var facing := float(p.facing)
	var near: Variant = null
	var best := 700.0 # oltre non si guarda nessuno
	for id in player_ids:
		var o: Variant = _sampled.get(id)
		if id == p.id or o == null or o.eliminated or o.respawning:
			continue
		var d := Vector2(float(o.x) - float(p.x), float(o.y) - float(p.y))
		if d.length() < best:
			best = d.length()
			near = Vector2(d.x * facing, d.y)
	var startup := float(attack.get("startupMs", -1.0))
	var calm: bool = name in ["idle", "walk", "dash", "shield", "jump", "fall", "land", "jumpSquat"]
	return {
		"token": "%s|%s|%s" % [name, state.get("kind", ""), state.get("start", 0)],
		# nei colpi il passaggio è più corto: l'impatto deve cadere quando si accende la hitbox
		"blend_ms": RigMotion.BLEND_MS if startup < 0.0 else minf(RigMotion.BLEND_MS, startup * 0.5),
		"vx": float(p.vx) * facing, "vy": float(p.vy), "look": near, "idle": name == "idle",
		"run": clampf(absf(float(p.vx)) / float(game.dash.runSpeed), 0.0, 1.0) if name in ["walk", "dash"] else 0.0,
		"head_free": 1.0 if calm else 0.25,
	}


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
