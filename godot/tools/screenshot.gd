# Fotografa la lobby e una partita finta (lottatori, speciali, HUD) in PNG, senza server.
# Lo usa la CI (E3 passo 3, #83): i PNG si scaricano dalla pagina della CI di ogni PR.
# Uso: xvfb-run -a godot --path godot --script res://tools/screenshot.gd -- --out=/cartella
# Esce con 1 se un'immagine è tutta di un colore (schermo nero o niente disegnato).
extends SceneTree

const SHOT_FRAME := 30 # frame a cui si scatta: il tempo di caricare sprite e font

var _out := "user://screenshots"
var _game: Dictionary
var _world: Node2D # nella partita finta: riceve uno snapshot a ogni frame
var _hud: Control
const SHOTS := ["lobby", "partita", "lobby_squadre", "squadre", "lobby_regole", "musica", "tetris", "pacman", "bassanese", "bologna_piazza", "bologna_torri", "bologna_crollo", "bologna_zuffa", "oggetti", "prepartita_attesa", "prepartita_vs", "prepartita_conto", "fine_partita", "perf"] # nome del PNG = funzione che prepara la scena (_lobby, _partita, ...)
var _index := -1
var _frame := 0
var _failed := false
var _teams := false # la partita finta a tre squadre (#409)
var _music := false # la partita finta nell'arena musicale, durante la Meraviglia (#423)
var _tetris_on := false # la partita finta con uno che gioca a Tetris (#427)
var _pacman_on := false # la partita finta con un Pac-Man e i fantasmini (#427)
var _items_on := false # la partita finta con tutti gli oggetti in fila a terra
var _bassanese_on := false # la partita finta col Bassanese che si guarda in giro e un telefono a terra
var _pre: Dictionary = {} # pre-partita: lo stato messo in snapshot.prematch, vuoto nelle altre partite
var _pre_fighters := 0 # quanti lottatori nella partita finta del pre-partita (0 = tutti)
var _pre_view: Control
var _end_on := false # la partita finta finita: GAME!, vincitore e classifica coi premi (results_view.gd)
var _results: Control
var _world_script: Variant = null # PROVVISORIO (#433)
var _bologna: Dictionary = {} # le fasi di Bologna (#433): {ms, cam, zoom, spots}, vuoto nelle altre partite
# Bologna in quattro momenti: l'auto in piazza, l'ingorgo sotto le torri, la Garisenda che cade coi mattoni, la polvere
const BOLOGNA_SHOTS := {
	"piazza": {"ms": 22000, "cam": Vector2(1100, 1760), "zoom": 0.62, "y": [1940, 1940, 1880, 1940, 1760], "x": [420, 700, 1000, 1500, 1900]},
	"torri": {"ms": 100000, "cam": Vector2(1100, 1520), "zoom": 0.5, "y": [1180, 1940, 1640, 980, 1940], "x": [700, 500, 1500, 1500, 1600]},
	"crollo": {"ms": 151300, "cam": Vector2(1100, 1520), "zoom": 0.5, "y": [980, 1940, 1640, 980, 1940], "x": [1400, 600, 1500, 1600, 1700]},
	"zuffa": {"ms": 308000, "cam": Vector2(1500, 1150), "zoom": 0.6, "y": [980, 980, 980, 980, 980], "x": [1320, 1420, 1520, 1620, 1700]},
}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	root.theme = load("res://scripts/ui.gd").theme()
	_next()


# PROVVISORIO (#433): misura di Bologna lungo la partita. [nome, stageMs, variante, zoom]
const PERF_RUNS := [
	["t000", 0, "", 0.6], ["t030", 30000, "", 0.6], ["t060", 60000, "", 0.6], ["t090", 90000, "", 0.6],
	["t120", 120000, "", 0.6], ["t150", 152000, "", 0.6], ["t180", 180000, "", 0.6], ["t210", 210000, "", 0.6],
	["t240", 240000, "", 0.6], ["t270", 270000, "", 0.6], ["t300", 300000, "", 0.6], ["t330", 330000, "", 0.6],
	["t360", 360000, "", 0.6], ["t390", 390000, "", 0.6], ["t420", 420000, "", 0.6],
	["z300_noluci", 300000, "noluci", 0.6], ["z300_nocielo", 300000, "nocielo", 0.6], ["z300_nopost", 300000, "nopost", 0.6],
	["z300_notrappole", 300000, "notrappole", 0.6], ["z300_nostrati", 300000, "nostrati", 0.6],
	["z300_zoom035", 300000, "", 0.35], ["z022_zoom035", 22000, "", 0.35],
]
const PERF_WARM := 10
const PERF_FRAMES := 60
var _perf_i := -1
var _perf_t0 := 0
var _perf_draw_us := 0
var _perf_calls := 0
var _perf_prims := 0


class TimedWorld extends "res://scripts/world_view.gd":
	var draw_us := 0
	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super()
		draw_us += Time.get_ticks_usec() - t


func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_perf_next()


func _perf_next() -> void:
	for c in root.get_children():
		c.queue_free()
	_perf_i += 1
	_frame = 0
	if _perf_i >= PERF_RUNS.size():
		_world = null
		return
	var run: Array = PERF_RUNS[_perf_i]
	_bologna = BOLOGNA_SHOTS.zuffa.duplicate()
	_bologna.ms = run[1]
	_bologna.zoom = run[3]
	_world_script = TimedWorld
	_partita()
	_world_script = null
	match String(run[2]):
		"noluci":
			_world._light_layers = {}
			_world._light_props = []
		"nocielo":
			_world._life.life = {}
		"nopost":
			for c in root.get_children():
				if c is CanvasLayer:
					c.get_child(0).enabled = false
		"notrappole":
			_world.stage.hazards = []
			_world.stage.jets = []
		"nostrati":
			_world._layers = []


func _perf_process() -> bool:
	if _world == null:
		return false
	var snap := _snapshot(_frame)
	_world.on_snapshot(snap)
	_hud.on_snapshot(snap)
	if _frame == PERF_WARM:
		_perf_t0 = Time.get_ticks_usec()
		_world.draw_us = 0
		_perf_calls = 0
		_perf_prims = 0
	elif _frame > PERF_WARM:
		_perf_calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_perf_prims += int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if _frame < PERF_WARM + PERF_FRAMES:
		return false
	var ms := (Time.get_ticks_usec() - _perf_t0) / 1000.0 / PERF_FRAMES
	print("PERF %-16s frame %6.2f ms, _draw del mondo %6.2f ms, draw call %5d, primitive %7d" % [PERF_RUNS[_perf_i][0], ms,
		_world.draw_us / 1000.0 / PERF_FRAMES, _perf_calls / PERF_FRAMES, _perf_prims / PERF_FRAMES])
	_perf_next()
	return _world == null


func _process(_delta: float) -> bool:
	_frame += 1
	if SHOTS[_index] == "perf":
		if _perf_process():
			quit(1 if _failed else 0)
			return true
		return false
	if _world != null:
		var snap := _snapshot(_frame)
		_world.on_snapshot(snap)
		_hud.on_snapshot(snap)
		if _pre_view != null:
			_pre_view.on_snapshot(snap)
		if _results != null:
			_results.on_snapshot(snap)
	if _frame < SHOT_FRAME:
		return false
	var name: String = SHOTS[_index]
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	if is_blank(image):
		printerr("%s: l'immagine è tutta di un colore" % path)
		_failed = true
	else:
		print("Salvato ", path)
	_next()
	if _index >= SHOTS.size():
		quit(1 if _failed else 0)
		return true
	return false


func _next() -> void:
	for c in root.get_children():
		c.queue_free()
	_index += 1
	_frame = 0
	_world = null
	_hud = null
	_pre_view = null
	_results = null
	if _index < SHOTS.size():
		call("_" + SHOTS[_index])


func _lobby() -> void:
	var lobby: Control = load("res://scripts/lobby.gd").new()
	root.add_child(lobby)
	lobby.setup(_game, {"name": "CI", "room": "ci", "server": "http://localhost:3000"}, func(r): return "http://x/?room=" + r)


# La pagina del lottatore con la scelta della squadra, in una partita a tre squadre (#409)
func _lobby_squadre() -> void:
	var lobby: Control = load("res://scripts/lobby.gd").new()
	root.add_child(lobby)
	lobby.setup(_game, {"name": "CI", "room": "ci", "server": "http://localhost:3000", "team": 2, "rules": {"mode": "teams", "teamCount": 3}}, func(r): return "http://x/?room=" + r)
	lobby.open_page("fighter")


# Le regole di chi crea la stanza, in fondo alla prima pagina: suprema e oggetti
func _lobby_regole() -> void:
	var lobby: Control = load("res://scripts/lobby.gd").new()
	root.add_child(lobby)
	lobby.setup(_game, {"name": "CI", "room": "ci", "server": "http://localhost:3000", "kind": "create", "rules": {"supremeSpeed": 2, "itemAmount": 3, "itemKinds": ["banana", "bong", "fiore"]}}, func(r): return "http://x/?room=" + r, "create")
	var scroll: ScrollContainer = lobby.find_children("*", "ScrollContainer", true, false)[0]
	_scroll_down.call_deferred(scroll)


func _scroll_down(scroll: ScrollContainer) -> void:
	await root.get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


# La stessa partita finta divisa in tre squadre: anelli, nomi colorati, schede a gruppi, vite per squadra
func _squadre() -> void:
	_teams = true
	_partita()
	_hud.on_welcome({"id": "p0", "room": "ci", "stageId": _game.defaultStageId, "rules": {"mode": "teams", "stocks": 3, "teamCount": 3}}, _world.stage)


# Quattro lottatori sul palco di base: due con lo stesso personaggio (colori alternativi), un proiettile e una carica
# La Sala Prove (#423) con i tre bottoni appena premuti: la Meraviglia, i fiori che cantano, la tastiera accesa
func _musica() -> void:
	_teams = false
	_music = true
	_partita()


# Il power-up Tetris (#427): uno gioca dal cabinato, un pezzo cade, blocchi posati e un altro Tetris a terra
func _tetris() -> void:
	_music = false
	_tetris_on = true
	_partita()


# Pac-Man (#427): uno è Pac-Man in mezzo alle palline, gli altri fantasmini spaventati
func _pacman() -> void:
	_tetris_on = false
	_pacman_on = true
	_partita()


# Chiama Bassanese: il Bassanese col telefono all'orecchio che si guarda in giro, e un altro telefono a terra
func _bassanese() -> void:
	_pacman_on = false
	_bassanese_on = true
	_partita()


func _bologna_piazza() -> void:
	_pacman_on = false
	_bassanese_on = false
	_bologna = BOLOGNA_SHOTS.piazza
	_partita()


func _bologna_torri() -> void:
	_bologna = BOLOGNA_SHOTS.torri
	_partita()


func _bologna_crollo() -> void:
	_bologna = BOLOGNA_SHOTS.crollo
	_partita()


func _bologna_zuffa() -> void:
	_bologna = BOLOGNA_SHOTS.zuffa
	_partita()


# Tutti gli oggetti che cadono, in fila a terra, per vedere come sono disegnati
func _oggetti() -> void:
	_bologna = {}
	_items_on = true
	_partita()


# Pre-partita: l'attesa dei Pronto, la presentazione col VS, il 2 del conto alla rovescia
func _prepartita_attesa() -> void:
	_items_on = false
	_pre = {"phase": "waiting", "leftMs": 0, "ready": ["p0", "p2", "p3"], "autoStartMs": 41000}
	_pre_fighters = 0
	_partita()
	_add_prematch()


func _prepartita_vs() -> void:
	_pre = {"phase": "starting", "leftMs": 3700, "ready": [], "autoStartMs": null}
	_pre_fighters = 2
	_partita()
	_add_prematch()


func _prepartita_conto() -> void:
	_pre = {"phase": "starting", "leftMs": 1750, "ready": [], "autoStartMs": null}
	_pre_fighters = 2
	_partita()
	_add_prematch()


func _add_prematch() -> void:
	_pre_view = load("res://scripts/prematch_view.gd").new()
	_pre_view.game = _game
	_pre_view.my_id = "p0"
	_pre_view.portrait_of = _hud._portrait
	_hud.get_parent().add_child(_pre_view)
	_pre_view.size = Vector2(_game.world.width, _game.world.height)
# Fine partita: la classifica è già entrata tutta, coi premi; il vincitore sotto il riflettore
func _fine_partita() -> void:
	_items_on = false
	_pre = {}
	_pre_fighters = 0
	_end_on = true
	_partita()
	_results = load("res://scripts/results_view.gd").new()
	_results.game = _game
	_results.hud = _hud
	_results.size = _hud.size
	_hud.get_parent().add_child(_results)
	_hud.get_parent().move_child(_results, 0) # sotto l'HUD, come in main.gd
	_results.on_snapshot({"players": [], "winnerId": "p1", "events": [{"type": "matchEnd", "winnerId": "p1", "winnerTeam": 0, "durationMs": 133000}]})
	_results._since = Time.get_ticks_msec() - 3500


func _partita() -> void:
	var world: Node2D = _world_script.new() if _world_script != null else load("res://scripts/world_view.gd").new()
	root.add_child(world)
	world.setup(_game)
	world.set_stage("bologna" if not _bologna.is_empty() else ("musica" if _music else _game.defaultStageId))
	world.my_id = "p0"
	var cam := Camera2D.new()
	cam.position = _bologna.cam if not _bologna.is_empty() else Vector2(640, 430)
	cam.zoom = Vector2.ONE * (float(_bologna.zoom) if not _bologna.is_empty() else 1.4)
	root.add_child(cam)
	cam.make_current()
	_hud = load("res://scripts/hud.gd").new()
	_hud.game = _game
	_hud.size = Vector2(_game.world.width, _game.world.height)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var post: Node = load("res://scripts/post_fx.gd").new() # come in main.gd: sotto l'HUD
	post.world = world
	layer.add_child(post)
	layer.add_child(_hud)
	_hud.on_welcome({"id": "p0", "room": "ci", "stageId": _game.defaultStageId, "rules": {"mode": "ffa", "stocks": 3}}, world.stage)
	world.player_ids = ["p0", "p1", "p2", "p3", "p4"]
	_world = world


func _snapshot(frame: int) -> Dictionary:
	var spots := [[420, "default", 0xe74c3c, 0.0], [560, "orsoblu", 0x3498db, 0.7], [760, "bonobot", 0x2ecc71, 0.0], [880, "bonobot", 0xf1c40f, 0.0], [300, "nonnagina", 0x9b59b6, 0.0]] # Nonna Gina a pezzi (#403)
	var players := []
	var teams := [1, 2, 3, 1, 2]
	for i in spots.size():
		var team: int = teams[i] if _teams else 0
		var color: int = int(_game.teamColors[str(team)][0 if i < 3 else 1]) if _teams else spots[i][2]
		players.append({
			"id": "p%d" % i, "name": "P%d" % (i + 1), "characterId": spots[i][1], "color": color, "team": team,
			"x": _bologna.x[i] if not _bologna.is_empty() else spots[i][0], "y": _bologna.y[i] if not _bologna.is_empty() else 560, "vx": 0, "vy": 0, "facing": 1 if i < 2 else -1, "percent": i * 37, "stocks": 3,
			"onGround": true, "attack": null, "attackActive": false, "hitstun": false, "respawning": false,
			"invulnerable": false, "eliminated": false, "carrier": false, "ledge": null, "away": false,
			"shielding": i == 3, "shieldHp": 40, "stunned": false, "grabbedBy": null, "charge": spots[i][3],
		})
	if _pre_fighters > 0:
		players = players.slice(0, _pre_fighters)
		players[0].name = "Nicola"
		players[1].name = "Riccardo"
	var stage_ms := frame * 16 + (9000 if _music else 0) + (int(_bologna.ms) if not _bologna.is_empty() else 0)
	var snap := {"t": frame * 16, "players": players, "items": [], "events": [], "stageMs": stage_ms, "winnerId": null, "timeLeftMs": 90000, "teamScores": null,
		"projectiles": [{"id": 1, "ownerId": "p0", "kind": "specialNeutral", "characterId": "default", "x": 500, "y": 470, "vx": 560, "vy": -120}]}
	if not _pre.is_empty():
		snap.prematch = _pre
	if _music:
		snap.pads = [8800, 8800, 8800] # tutti e tre premuti da poco: la Meraviglia
	if _pacman_on:
		players[1].powerup = "pacman"
		players[1].powerupMs = 5000
		players[1].invulnerable = true
		players[1].y = 470
		players[1].vx = 380
		snap.items = [{"id": 9, "kind": "pacman", "x": 680, "y": 560, "vx": 0, "vy": 0, "heldBy": null, "thrown": false}]
	if _bassanese_on:
		snap.bassanese = [{"id": 1, "ownerId": "p0", "x": 680, "y": 560, "facing": 1, "phase": "look"}]
		snap.items = [{"id": 9, "kind": "bassanese", "x": 480, "y": 560, "vx": 0, "vy": 0, "heldBy": null, "thrown": false}]
		if frame < 3:
			snap.events = [{"type": "bassanese", "phase": "call", "id": "p0", "x": 420, "y": 560}]
	if _tetris_on:
		players[4].powerup = "tetris"
		players[4].powerupMs = 6000
		players[4].invulnerable = true
		var c := 40
		snap.tetris = {
			"pieces": [{"id": 3, "ownerId": "p4", "kind": "T", "cells": [[13 * c, 160], [14 * c, 160], [15 * c, 160], [14 * c, 120]]}],
			"blocks": [{"x": 17 * c, "y": 520, "kind": "I", "ms": 8000}, {"x": 18 * c, "y": 520, "kind": "I", "ms": 8000}, {"x": 19 * c, "y": 520, "kind": "I", "ms": 8000}, {"x": 20 * c, "y": 520, "kind": "I", "ms": 8000},
				{"x": 18 * c, "y": 480, "kind": "O", "ms": 900}, {"x": 19 * c, "y": 480, "kind": "O", "ms": 900}, {"x": 18 * c, "y": 440, "kind": "O", "ms": 900}, {"x": 19 * c, "y": 440, "kind": "O", "ms": 900}],
		}
		snap.items = [{"id": 9, "kind": "tetris", "x": 640, "y": 560, "vx": 0, "vy": 0, "heldBy": null, "thrown": false}]
	if _items_on:
		snap.projectiles = []
		var kinds: Array = _game.droppableItems
		for i in kinds.size():
			snap.items.append({"id": 20 + i, "kind": kinds[i], "x": 380 + i * 75, "y": 560, "vx": 0, "vy": 0, "heldBy": null, "thrown": false})
		for p in players:
			p.y = 300
	if _end_on:
		snap.winnerId = "p1"
		snap.timeLeftMs = 0
		if frame == 1: # i numeri della classifica
			snap.events = [
				{"type": "hit", "attackerId": "p1", "targetId": "p0", "damage": 22}, {"type": "hit", "attackerId": "p1", "targetId": "p2", "damage": 130},
				{"type": "hit", "attackerId": "p0", "targetId": "p1", "damage": 95}, {"type": "hit", "attackerId": "p2", "targetId": "p3", "damage": 60},
				{"type": "hit", "attackerId": "p4", "targetId": "p1", "damage": 31},
				{"type": "ko", "id": "p0", "byId": "p1"}, {"type": "ko", "id": "p2", "byId": "p1"}, {"type": "ko", "id": "p3", "byId": "p1"},
				{"type": "ko", "id": "p3", "byId": "p2"}, {"type": "ko", "id": "p4", "byId": "p0"}, {"type": "ko", "id": "p2", "byId": null},
			]
	return snap


# Vero se tutti i punti di una griglia 16×16 hanno lo stesso colore
static func is_blank(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	for gy in 16:
		for gx in 16:
			var p := image.get_pixel(int((gx + 0.5) * image.get_width() / 16.0), int((gy + 0.5) * image.get_height() / 16.0))
			if not p.is_equal_approx(first):
				return false
	return true
