# Esegue ogni tests/test_*.gd e i suoi metodi test_*, esce con 1 se qualcosa fallisce (#83).
# godot --headless --path godot --script res://tests/run_tests.gd
# I test sono RefCounted con un campo `runner` e chiamano runner.check(condizione, messaggio).
extends SceneTree

var failures := 0
var current := ""


func _initialize() -> void:
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f: String): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	var total := 0
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			if not String(m.name).begins_with("test_"):
				continue
			var t: Object = script.new()
			t.set("runner", self)
			current = "%s::%s" % [f.get_basename(), m.name]
			var before := failures
			t.call(m.name)
			total += 1
			print(("ok   " if failures == before else "FAIL ") + current)
	print("%d test, %d falliti" % [total, failures])
	quit(1 if failures > 0 or total == 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("  %s: %s" % [current, msg])
