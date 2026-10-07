# Sfide con medaglie (challenges.gd, challenge_run.gd, E15 passo 3): stesso conto di src/shared/challenges.ts
# e medaglie salvate in un file di prova
extends RefCounted

var runner

const Challenges := preload("res://scripts/challenges.gd")
const Run := preload("res://scripts/challenge_run.gd")
const PATH := "user://test_medals.cfg"


func _settings() -> Settings:
	return Settings.new({"master": 0.8, "sfx": 0.7, "music": 0.35}, PATH)


func _fresh() -> Settings:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return _settings()


func _challenge(id: String) -> Dictionary:
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	for c in game.challenges:
		if c.id == id:
			return c
	return {}


func _run(id: String) -> Control:
	var run: Control = Run.new()
	run.my_id = "me"
	run.setup(_challenge(id), _fresh())
	return run


func _snap(ms: float, events: Array = [], players: Array = []) -> Dictionary:
	return {"stageMs": ms, "events": events, "players": players}


func test_sei_sfide_da_game_json() -> void:
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(game.challenges.size() >= 6, "almeno 6 sfide")


func test_medaglie() -> void:
	var ko := _challenge("primo-ko") # 12, 7, 5 s
	runner.check(Challenges.medal_for(ko, null) == 0, "senza KO niente medaglia")
	runner.check(Challenges.medal_for(ko, 20.0) == 0 and Challenges.medal_for(ko, 7.0) == 2 and Challenges.medal_for(ko, 3.0) == 3, "tempo: meno è meglio")
	var dmg := _challenge("mitraglia") # 60, 85, 100%
	runner.check(Challenges.medal_for(dmg, 59.0) == 0 and Challenges.medal_for(dmg, 60.0) == 1 and Challenges.medal_for(dmg, 140.0) == 3, "danno: più è meglio")
	runner.check(Challenges.score_text(dmg, 87.4) == "87%" and Challenges.score_text(ko, 4.25) == "4.2 s", "punteggi in chiaro")


func test_ko_dal_tempo_dell_arena() -> void:
	var run := _run("primo-ko")
	run.on_snapshot(_snap(10000))
	run.on_snapshot(_snap(13000, [{"type": "ko", "id": "me", "byId": null}]))
	runner.check(not run.done, "cadere da soli non chiude la sfida")
	run.on_snapshot(_snap(16040, [{"type": "ko", "id": "bot", "byId": "me"}]))
	runner.check(run.done and is_equal_approx(float(run.score), 6.0) and run.medal() == 2, "KO dopo 6 s: argento")
	run.free()


func test_palleggio_si_azzera_a_terra() -> void:
	var run := _run("palleggio")
	var hit := {"type": "hit", "attackerId": "me", "targetId": "bot", "damage": 5}
	var air := [{"id": "bot", "hitstun": false, "onGround": false}]
	var ground := [{"id": "bot", "hitstun": false, "onGround": true}]
	run.on_snapshot(_snap(0, [hit, hit, hit, hit], air))
	run.on_snapshot(_snap(500, [], ground))
	run.on_snapshot(_snap(600, [hit, hit], air))
	runner.check(int(run.score) == 4 and not run.done, "il record resta, il palleggio riparte")
	run.on_snapshot(_snap(700, [hit, hit, hit, hit, hit], air))
	runner.check(run.done and run.medal() == 3, "a 7 colpi oro e fine")
	run.free()


func test_resistere_fino_al_limite() -> void:
	var run := _run("resisti")
	run.on_snapshot(_snap(0))
	run.on_snapshot(_snap(60000))
	runner.check(run.done and run.medal() == 3, "60 s in piedi: oro")
	run.free()


func test_medaglie_salvate() -> void:
	var s := _fresh()
	runner.check(s.record_medal("primo-ko", 1, 10.0, true), "primo tentativo è un record")
	runner.check(not s.record_medal("primo-ko", 0, 15.0, true), "peggio non cambia niente")
	runner.check(s.record_medal("primo-ko", 3, 4.0, true), "meglio è un record")
	var again := _settings()
	runner.check(again.medals.get("primo-ko", {}).get("medal", 0) == 3 and is_equal_approx(float(again.medals["primo-ko"].best), 4.0), "restano dopo il riavvio")
	again.reset()
	runner.check(_settings().medals.has("primo-ko"), "Ripristina non toglie le medaglie")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
