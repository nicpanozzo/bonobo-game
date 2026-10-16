# Palestra, tutorial e sfide (E15): apre la stanza tutta propria, mostra il pannello dell'allenamento, il riquadro
# del tutorial o la sfida in corso, e passa loro eventi e snapshot. main.gd la crea e la chiama; qui non si decide
# niente della partita: i comandi dell'allenamento vanno al server come sempre.
extends RefCounted

var _m: Node # main.gd: collegamento, mondo, menu e preferenze
var training: Control # pannello dell'allenamento, solo nelle stanze "training"
var tutorial: Control # riquadro del tutorial a tappe, solo se si è entrati da "Tutorial"
var challenge_run: Control # sfida in corso, solo se si è entrati da "Sfide"
var picked: Dictionary = {} # sfida appena scelta nell'elenco
var speed := 1.0 # velocità scelta nel pannello dell'allenamento


func _init(main_node: Node) -> void:
	_m = main_node


# All'ingresso nella stanza: in una sfida niente pannello, perché rallentatore e percentuale cambierebbero il risultato
func on_welcome(data: Dictionary) -> void:
	var challenge: Dictionary = _m.params.get("challenge", {})
	set_training(data.get("rules", {}).get("mode", "") == "training" and challenge.is_empty())
	set_tutorial(_m.params.get("tutorial", false))
	set_challenge(not challenge.is_empty())


func on_event(e: Dictionary) -> void:
	if is_instance_valid(training):
		training.on_event(e, _m.world.my_id)
	if is_instance_valid(tutorial):
		tutorial.on_event(e, _m.world.my_id)


func on_snapshot(data: Dictionary) -> void:
	if is_instance_valid(training):
		training.on_snapshot(data)
	if is_instance_valid(challenge_run):
		challenge_run.on_snapshot(data)


# Uscendo dalla stanza spariscono tutti
func close_all() -> void:
	set_training(false)
	set_tutorial(false)
	set_challenge(false)


# Sfide e tutorial hanno la loro fine: niente Rivincita e Cambia lottatore
func hides_results() -> bool:
	return is_instance_valid(challenge_run) or is_instance_valid(tutorial)


# In palestra compaiono il conta combo e il pannello; altrove spariscono, hitbox comprese
func set_training(on: bool) -> void:
	if on == is_instance_valid(training):
		return
	if not on:
		training.queue_free()
		training = null
		_m.world.show_hitboxes = false
		return
	training = preload("res://scripts/training.gd").new()
	training.theme = UI.theme()
	_m.ui_layer.add_child(training)
	training.setup(_m.game)
	training.command.connect(command)
	training.hitboxes_toggled.connect(func(on_off: bool): _m.world.show_hitboxes = on_off)


# Comandi del pannello: al server; la velocità serve anche alla predizione, che va solo a velocità normale
func command(data: Dictionary) -> void:
	if data.has("speed"):
		speed = float(data.speed)
		_m._apply_prediction()
	_m.socket.emit("training", data)


# Dal titolo: una palestra tutta propria, col tutorial e lo sparring o col manichino.
# Stanza nuova ogni volta: i comandi dell'allenamento valgono solo da soli
func join_gym(with_tutorial: bool) -> void:
	var tut: Dictionary = _m.game.get("tutorial", {})
	_m._join({
		"name": _player_name(),
		"room": ("tutorial-" if with_tutorial else "palestra-") + str(randi() % 100000),
		"char": _m.settings.profile.get("char", ""),
		"stage": str(tut.get("stage", "")) if with_tutorial else "",
		"rules": {"mode": "training"},
		"bot": str(tut.get("bot", "manichino")) if with_tutorial else "manichino",
		"tutorial": with_tutorial,
		"gym": true,
	})


func set_tutorial(on: bool) -> void:
	if on == is_instance_valid(tutorial):
		return
	if not on:
		tutorial.queue_free()
		tutorial = null
		return
	tutorial = preload("res://scripts/tutorial.gd").new()
	tutorial.theme = UI.theme()
	_m.ui_layer.add_child(tutorial)
	tutorial.setup(_m.settings, _m.game)
	# "Fatto!": lo stesso suono di un punto
	tutorial.lesson_done.connect(func(_i: int): _m.audio.on_event({"type": "flag"}))


# Elenco delle sfide sopra il titolo o la lobby; on_pick parte con la sfida in picked
func show_challenges(on_pick: Callable, on_close: Callable) -> void:
	var list := preload("res://scripts/challenges.gd").new()
	list.theme = UI.theme()
	_m.ui_layer.add_child(list)
	list.setup(_m.game, _m.settings)
	list.chosen.connect(func(c: Dictionary):
		picked = c
		list.queue_free()
		on_pick.call())
	list.closed.connect(on_close)


# Ogni sfida in una palestra nuova tutta propria, col suo bot e la sua arena
func join_challenge(c: Dictionary) -> void:
	_m._join({
		"name": _player_name(),
		"room": "sfida-" + str(randi() % 100000),
		"char": _m.settings.profile.get("char", ""),
		"stage": str(c.stage),
		"rules": {"mode": "training"},
		"bot": str(c.bot),
		"challenge": c,
		"gym": true,
	})


func set_challenge(on: bool) -> void:
	if is_instance_valid(challenge_run):
		challenge_run.queue_free()
		challenge_run = null
	if not on:
		return
	challenge_run = preload("res://scripts/challenge_run.gd").new()
	challenge_run.theme = UI.theme()
	challenge_run.my_id = _m.world.my_id
	_m.ui_layer.add_child(challenge_run)
	challenge_run.setup(_m.params.challenge, _m.settings)
	start_challenge()
	challenge_run.retry_requested.connect(start_challenge)
	challenge_run.back_requested.connect(func():
		_m._leave()
		show_challenges(func(): join_challenge.call_deferred(picked), func(): pass))


# Tutti al loro posto e il bot alla percentuale della sfida (comandi dell'allenamento), poi si riparte
func start_challenge() -> void:
	_m.socket.emit("training", {"reset": true, "percent": float(_m.params.challenge.get("botPercent", 0))})
	challenge_run.start()


func _player_name() -> String:
	var player_name := str(_m.settings.profile.get("name", ""))
	return player_name if player_name != "" else "Bonobo"
