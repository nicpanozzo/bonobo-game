# Tappe del tutorial (tutorial.gd, E15): ognuna si completa solo con il suo evento, fatto da chi gioca
extends RefCounted

var runner

const Tutorial := preload("res://scripts/tutorial.gd")


func _lessons() -> Array:
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	return game.tutorial.lessons


func _lesson(id: String) -> Dictionary:
	for l in _lessons():
		if l.id == id:
			return l
	return {}


func test_tappe_in_game_json() -> void:
	runner.check(_lessons().size() >= 10, "le tappe arrivano da game.json")


func test_salto_e_doppio_salto() -> void:
	var jump := {"type": "jump", "id": "me", "air": false}
	runner.check(Tutorial.done(_lesson("salto"), jump, "me"), "salto da terra")
	runner.check(not Tutorial.done(_lesson("salto"), jump, "bot"), "il salto di un altro non conta")
	runner.check(not Tutorial.done(_lesson("doppio"), jump, "me"), "un salto da terra non è il doppio salto")
	runner.check(Tutorial.done(_lesson("doppio"), {"type": "jump", "id": "me", "air": true}, "me"), "doppio salto")


func test_colpi_e_ko_contano_per_chi_li_fa() -> void:
	var hit := {"type": "hit", "attackerId": "me", "targetId": "bot", "kind": "light"}
	runner.check(Tutorial.done(_lesson("colpo"), hit, "me"), "colpo dato")
	runner.check(not Tutorial.done(_lesson("colpo"), {"type": "hit", "attackerId": "bot", "targetId": "me"}, "me"), "colpo preso")
	runner.check(Tutorial.done(_lesson("fuori"), {"type": "ko", "id": "bot", "byId": "me"}, "me"), "KO dato")
	runner.check(not Tutorial.done(_lesson("fuori"), {"type": "ko", "id": "me", "byId": null}, "me"), "caduta propria")
	runner.check(not Tutorial.done(_lesson("leggero"), {"type": "attack", "id": "me", "kind": "heavy"}, "me"), "pesante non vale come leggero")
