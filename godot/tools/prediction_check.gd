# Quanto sbaglia la predizione (E17): un giocatore finto corre avanti e indietro e salta su un server
# vero, con un ritardo finto in andata e ritorno; a ogni snapshot si misura di quanto il predittore
# deve correggersi. Pochi pixel = il proprio lottatore va dove poi lo mette il server.
# Uso: npm run dev, poi godot --headless --path godot --script res://tools/prediction_check.gd -- --lag=150
# (anche --server=... e --seconds=N)
extends SceneTree

var game: Dictionary
var socket := SocketIO.new()
var pr := Predictor.new()
var my_id := ""
var last_input := {}
var frames := 0
var corrections: Array = []
var active := 0
var snaps := 0
var lag := 150
var server := "http://localhost:3000"
var seconds := 12.0
var _start := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lag="):
			lag = int(a.substr(6))
		elif a.begins_with("--server="):
			server = a.substr(9)
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
	_start = Time.get_ticks_msec()
	game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	pr.setup(game)
	socket.lag_ms = lag
	socket.connected.connect(func(): socket.emit("join", {"room": "lagtest", "name": "P", "protocol": int(game.protocol), "stageId": "palco"}))
	socket.event_received.connect(_on_event)
	socket.connect_to(server)

func _on_event(name: String, data: Variant) -> void:
	var now := float(Time.get_ticks_msec())
	if name == "welcome":
		my_id = data.id
		pr.set_stage(data.stage)
	elif name == "snapshot" and my_id != "":
		for p in data.players:
			if p.id == my_id:
				snaps += 1
				# Dove il predittore metteva il lottatore per adesso, prima e dopo aver visto lo snapshot
				var before := Vector2.INF
				if pr.is_active():
					pr._advance(now)
					before = Vector2(pr._state.x, pr._state.y)
				pr.on_server(p, now)
				if pr.is_active():
					active += 1
					if before != Vector2.INF:
						corrections.append(before.distance_to(Vector2(pr._state.x, pr._state.y)))

func _process(_d: float) -> bool:
	socket.poll()
	frames += 1
	var t := pr.local_tick(Time.get_ticks_msec())
	# Destra, fermo, sinistra, fermo, 45 tick ciascuno; un salto ogni 70 tick, tenuto 12 (salto corto)
	var phase := (t / 45) % 4
	var input := {"left": phase == 2, "right": phase == 0, "jump": t % 70 < 12, "down": false, "up": false, "light": false, "heavy": false, "taunt": false, "dodge": false, "shield": false, "special": false, "supreme": false}
	if input != last_input and my_id != "":
		last_input = input
		var sent := input.duplicate()
		sent.seq = t
		socket.emit("input", sent)
		pr.record_input(input, t)
	if Time.get_ticks_msec() - _start > seconds * 1000.0:
		corrections.sort()
		var n := corrections.size()
		var mean := 0.0
		for c in corrections:
			mean += c
		print("ritardo %d: snapshot %d, con predizione %d, correzioni %d: media %.2f px, mediana %.2f, 95%% %.2f, max %.2f" % [lag, snaps, active, n, mean / maxf(n, 1), corrections[n / 2] if n else 0.0, corrections[int(n * 0.95)] if n else 0.0, corrections[-1] if n else 0.0])
		quit(0 if active > 0 else 1)
		return true
	return false
