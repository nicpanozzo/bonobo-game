extends SceneTree
func _w(n: int) -> void:
	for i in n:
		await process_frame
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var port := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): port = a.substr(6)
	change_scene_to_file("res://main.tscn")
	await _w(5)
	root.get_texture().get_image().save_png("/tmp/claude-0/-home-claude-bonobo-game/62814bb6-b4c9-56e0-8d44-14a0213d3bf8/scratchpad/conn-%s-0.png" % port)
	await _w(240)
	var m = current_scene
	print(port, ": collegamento visibile=", is_instance_valid(m.connecting), " playing=", m.playing)
	root.get_texture().get_image().save_png("/tmp/claude-0/-home-claude-bonobo-game/62814bb6-b4c9-56e0-8d44-14a0213d3bf8/scratchpad/conn-%s.png" % port)
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	await _w(5)
	print(port, ": dopo Esc lobby=", is_instance_valid(m.lobby), " collegamento=", is_instance_valid(m.connecting), " pausa=", is_instance_valid(m.pause_menu))
	quit()
