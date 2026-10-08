# Misura quanto costa un frame del client: _process e _draw di world_view.gd e hud.gd
# con 8 lottatori che si muovono, colpi e KO finti. Non serve il server.
# Uso: godot --headless --path godot --script res://tools/bench_client.gd
# (con -- --frames=N per cambiare la durata). In headless non si disegna davvero:
# si misura il costo degli script, che è la parte che scriviamo noi.
# Con -- --check (E3 passo 4) divide i frame in 3 giri, tiene il migliore ed esce con 1
# se supera perfBudget.clientScriptUs di game.json (PERF_BUDGET in constants.ts).
extends SceneTree

const PLAYERS := 8
const SEND_MS := 1000.0 / 30.0 # SEND_RATE in constants.ts

var frames := 600
var _world: Node2D
var _hud: Control
var _frame := 0
var _server_t := 0.0
var _last_send := -1000.0
var _rng := RandomNumberGenerator.new()
var _percent := {} # id -> danno: sale solo ai colpi, come in partita
var _check := false
var _budget_us := 0.0
var _rounds: Array[float] = [] # µs di script per frame di ogni giro (con --check)
var _round_start_us := 0


# Sottoclassi che cronometrano _process e _draw senza toccare gli script veri
class TimedWorld extends "res://scripts/world_view.gd":
	var process_us := 0
	var draw_us := 0
	func _process(delta: float) -> void:
		var t := Time.get_ticks_usec()
		super(delta)
		process_us += Time.get_ticks_usec() - t
	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super()
		draw_us += Time.get_ticks_usec() - t


class TimedHud extends "res://scripts/hud.gd":
	var process_us := 0
	var draw_us := 0
	func _process(delta: float) -> void:
		var t := Time.get_ticks_usec()
		super(delta)
		process_us += Time.get_ticks_usec() - t
	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super()
		draw_us += Time.get_ticks_usec() - t


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg == "--check":
			_check = true
	_rng.seed = 1
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	_budget_us = float(game.get("perfBudget", {}).get("clientScriptUs", 0))
	_world = TimedWorld.new()
	_world.setup(game)
	_world.my_id = "p0"
	root.add_child(_world)
	_hud = TimedHud.new()
	_hud.game = game
	_hud.size = Vector2(game.world.width, game.world.height)
	root.add_child(_hud)
	_hud.on_welcome({"id": "p0", "room": "bench", "stageId": game.defaultStageId, "rules": {"mode": "ffa", "stocks": 3}}, _world.stage)


func _process(_delta: float) -> bool:
	var now := float(Time.get_ticks_msec())
	if now - _last_send >= SEND_MS:
		_last_send = now
		_server_t = now
		var snap := _snapshot()
		for e in snap.events:
			_world.on_event(e)
		_world.on_snapshot(snap)
		_hud.on_snapshot(snap)
	_frame += 1
	var w: TimedWorld = _world
	var h: TimedHud = _hud
	var round_frames := frames / 3
	if _check and _frame % round_frames == 0 and _rounds.size() < 3:
		var total := w.process_us + w.draw_us + h.process_us + h.draw_us
		_rounds.append((total - _round_start_us) / float(round_frames))
		_round_start_us = total
	if _frame < frames:
		return false
	print("%d giocatori, %d frame" % [PLAYERS, frames])
	print("world_view: _process %.1f µs, _draw %.1f µs per frame" % [w.process_us / float(frames), w.draw_us / float(frames)])
	print("hud:        _process %.1f µs, _draw %.1f µs per frame" % [h.process_us / float(frames), h.draw_us / float(frames)])
	print("totale script %.1f µs per frame (a 60 fps un frame ne ha 16667)" % [(w.process_us + w.draw_us + h.process_us + h.draw_us) / float(frames)])
	if _check:
		quit(check_budget(_rounds, _budget_us))
	return true


# Il migliore dei giri contro il budget: 0 se ci sta, 1 se lo supera. Nella CI scrive anche il riassunto del job
static func check_budget(rounds: Array[float], budget_us: float) -> int:
	var best: float = rounds.min() if not rounds.is_empty() else INF
	var ok := budget_us > 0 and best <= budget_us
	print("migliore di %d giri: %.1f µs per frame, budget %.0f µs: %s" % [rounds.size(), best, budget_us, "dentro" if ok else "SUPERATO"])
	var summary := OS.get_environment("GITHUB_STEP_SUMMARY")
	if summary != "":
		var f := FileAccess.open(summary, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
			f.store_string("### Prestazioni del client Godot\n\n| Misura | Valore | Budget |\n|---|---|---|\n| Script per frame (world_view e hud) | %.0f µs | %.0f µs%s |\n\n" % [best, budget_us, "" if ok else " ❌"])
	if not ok:
		printerr("Budget del client superato (PERF_BUDGET.clientScriptUs in constants.ts)")
	return 0 if ok else 1


# Snapshot finto: lottatori che corrono avanti e indietro e saltano, con colpi e KO ogni tanto
func _snapshot() -> Dictionary:
	var players: Array = []
	var events: Array = []
	var s := _server_t / 1000.0
	for i in PLAYERS:
		var x := 640.0 + sin(s * 0.7 + i) * 420.0
		var y := 560.0 - absf(sin(s * 2.0 + i * 0.5)) * 200.0
		var hit := _rng.randf() < 0.05
		if hit:
			_percent[i] = fmod(_percent.get(i, 0.0) + 12.0, 160.0)
		players.append({
			"id": "p%d" % i, "name": "Bonobo %d" % i, "characterId": "default", "color": 0x3498db + i * 0x101010,
			"team": 0, "x": x, "y": y, "vx": cos(s * 0.7 + i) * 300.0, "vy": -400.0 if hit else 0.0,
			"facing": 1 if cos(s * 0.7 + i) > 0 else -1, "percent": _percent.get(i, 0.0), "stocks": 3,
			"onGround": y > 555.0, "attack": "light" if i % 3 == 0 else null, "attackActive": i % 2 == 0,
			"hitstun": hit, "respawning": false, "invulnerable": false, "eliminated": false, "carrier": false,
		})
		if hit:
			events.append({"type": "hit", "attackerId": "p%d" % ((i + 1) % PLAYERS), "targetId": "p%d" % i, "kind": "heavy", "damage": 12, "knockback": 900, "x": x, "y": y - 40})
	if _rng.randf() < 0.02:
		events.append({"type": "ko", "id": "p1", "byId": "p2", "x": -50.0, "y": 300.0})
	if _rng.randf() < 0.1:
		events.append({"type": "land", "id": "p3", "x": 400.0, "y": 560.0})
	return {"t": _server_t, "players": players, "events": events, "winnerId": null, "timeLeftMs": 90000, "teamScores": null}
