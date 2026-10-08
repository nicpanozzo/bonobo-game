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
const SHOTS := ["lobby", "partita"] # nome del PNG = funzione che prepara la scena (_lobby, _partita)
var _index := -1
var _frame := 0
var _failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	root.theme = load("res://scripts/ui.gd").theme()
	_next()


func _process(_delta: float) -> bool:
	_frame += 1
	if _world != null:
		var snap := _snapshot(_frame)
		_world.on_snapshot(snap)
		_hud.on_snapshot(snap)
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
	if _index < SHOTS.size():
		call("_" + SHOTS[_index])


func _lobby() -> void:
	var lobby: Control = load("res://scripts/lobby.gd").new()
	root.add_child(lobby)
	lobby.setup(_game, {"name": "CI", "room": "ci", "server": "http://localhost:3000"}, func(r): return "http://x/?room=" + r, false)


# Quattro lottatori sul palco di base: due con lo stesso personaggio (colori alternativi), un proiettile e una carica
func _partita() -> void:
	var world: Node2D = load("res://scripts/world_view.gd").new()
	root.add_child(world)
	world.setup(_game)
	world.set_stage(_game.defaultStageId)
	world.my_id = "p0"
	var cam := Camera2D.new()
	cam.position = Vector2(640, 430)
	cam.zoom = Vector2(1.4, 1.4)
	root.add_child(cam)
	cam.make_current()
	_hud = load("res://scripts/hud.gd").new()
	_hud.game = _game
	_hud.size = Vector2(_game.world.width, _game.world.height)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(_hud)
	_hud.on_welcome({"id": "p0", "room": "ci", "stageId": _game.defaultStageId, "rules": {"mode": "ffa", "stocks": 3}}, world.stage)
	world.player_ids = ["p0", "p1", "p2", "p3"]
	_world = world


func _snapshot(frame: int) -> Dictionary:
	var spots := [[420, "default", 0xe74c3c, 0.0], [560, "orsoblu", 0x3498db, 0.7], [760, "bonobot", 0x2ecc71, 0.0], [880, "bonobot", 0xf1c40f, 0.0]]
	var players := []
	for i in spots.size():
		players.append({
			"id": "p%d" % i, "name": "P%d" % (i + 1), "characterId": spots[i][1], "color": spots[i][2], "team": 0,
			"x": spots[i][0], "y": 560, "vx": 0, "vy": 0, "facing": 1 if i < 2 else -1, "percent": i * 37, "stocks": 3,
			"onGround": true, "attack": null, "attackActive": false, "hitstun": false, "respawning": false,
			"invulnerable": false, "eliminated": false, "carrier": false, "ledge": null, "away": false,
			"shielding": i == 3, "shieldHp": 40, "stunned": false, "grabbedBy": null, "charge": spots[i][3],
		})
	var snap := {"t": frame * 16, "players": players, "items": [], "events": [], "stageMs": frame * 16, "winnerId": null, "timeLeftMs": 90000, "teamScores": null,
		"projectiles": [{"id": 1, "ownerId": "p0", "kind": "specialNeutral", "characterId": "default", "x": 500, "y": 470, "vx": 560, "vy": -120}]}
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
