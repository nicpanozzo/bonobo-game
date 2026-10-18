# Lista delle mosse dal menu di pausa: nomi delle speciali dal personaggio, tasti salvati, il colpo caricato spiegato
extends RefCounted

var runner

const MoveList := preload("res://scripts/move_list.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


func _all(sections: Array) -> Array:
	var out := []
	for s in sections:
		out.append_array(s[1])
	return out


func test_speciali_col_nome_del_personaggio() -> void:
	var game := _game()
	var rows := _all(MoveList.rows(game, "bonobot", {"special": "U", "heavy": "K", "up": "W"}))
	var names := rows.map(func(r): return r[0])
	var neutral: String = game.characters.bonobot.specials.neutral.name
	runner.check(neutral in names, "la speciale neutra di Bonobot (%s): %s" % [neutral, names])
	var heavy: Array = rows.filter(func(r): return r[0] == "Pesante")[0]
	runner.check(heavy[1] == "K" and heavy[2].contains("caricarlo"), "il pesante dice che si carica: %s" % [heavy])
	var up: Array = rows.filter(func(r): return r[0] == "Pesante in su")[0]
	runner.check(up[1] == "W + K", "tasti combinati: %s" % [up])


func test_corsa_e_attacco_in_corsa() -> void:
	var rows := _all(MoveList.rows(_game(), "bonobot", {"run": "Maiusc", "heavy": "K", "left": "A", "right": "D"}))
	var dash: Array = rows.filter(func(r): return r[0] == "Attacco in corsa")[0]
	runner.check(dash[1] == "Maiusc + K", "attacco in corsa: %s" % [dash])
	var run: Array = rows.filter(func(r): return r[0] == "Corsa")[0]
	runner.check(run[1] == "Maiusc + A/D", "corsa: %s" % [run])
	runner.check(Settings.DEFAULT_BINDINGS.run == [KEY_SHIFT], "la corsa sta su Maiusc")


func test_ogni_personaggio_ha_la_sua_lista() -> void:
	var game := _game()
	for id in game.characters:
		var sections := MoveList.rows(game, id, {})
		runner.check(sections.size() == 3, "tre sezioni per %s" % id)
		runner.check(sections[1][1].size() >= 2, "%s ha speciali e suprema" % id)
	runner.check(MoveList.rows(game, "non-esiste", {}).size() == 3, "personaggio sconosciuto: quello base")


func test_tasti_dalle_opzioni() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_move_list.cfg"))
	var s := Settings.new({"master": 0.8, "sfx": 0.7, "music": 0.35}, "user://test_move_list.cfg")
	var keys := MoveList.keys_for(s, false)
	runner.check(keys.get("heavy", "") != "" and keys.has("special"), "tasti della tastiera: %s" % [keys])
	runner.check(MoveList.keys_for(s, true).has("light"), "tasti del pad")


func test_personaggio_di_chi_apre_il_menu() -> void:
	var r := {"me": "p2", "players": [{"id": "p1", "characterId": "bonobot"}, {"id": "p2", "characterId": "elvedeo"}]}
	runner.check(PauseMenu.my_character(r) == "elvedeo", "il mio lottatore")
	runner.check(PauseMenu.my_character({}) == "", "senza partita niente")


# Sul telefono la lista dice i tasti a schermo, non quelli della tastiera
func test_tasti_touch() -> void:
	var keys := MoveList.touch_keys()
	var attacks: Array = MoveList.rows(_game(), "default", keys)[0][1]
	runner.check(attacks[0][1] == "Leggero", attacks[0][1])
	runner.check(attacks[2][1] == "su + Leggero", attacks[2][1])
	for action in Settings.LABELS:
		runner.check(keys.has(action), "manca %s" % action)
