# La schermata del computer della sala (#567): mostra le regole arrivate dal server e rimanda quelle scelte
extends RefCounted

var runner

const RulesPanel := preload("res://scripts/hall_rules_panel.gd")


func _panel(rules: Dictionary, bot_level := "semplice") -> Control:
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var p: Control = RulesPanel.new()
	p.setup(game, Settings.new({"master": 0.8, "sfx": 0.7, "music": 0.35}, "user://test_hall_rules.cfg"), rules, bot_level)
	return p


func test_le_regole_tornano_come_arrivano() -> void:
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var kinds: Array = game.droppableItems.slice(0, 2)
	var p := _panel({"stocks": 4, "timeLimitSec": 180, "teamCount": 3, "friendlyFire": true, "supremeSpeed": 2, "itemAmount": 1, "itemKinds": kinds}, "difficile")
	var r: Dictionary = p.chosen_rules()
	runner.check(r.stocks == 4 and r.timeLimitSec == 180 and r.teamCount == 3 and r.friendlyFire, "vite, tempo, squadre, fuoco amico: %s" % r)
	runner.check(float(r.supremeSpeed) == 2.0 and r.itemAmount == 1, "suprema e quantità: %s" % r)
	runner.check(r.itemKinds == kinds, "gli oggetti accesi: %s" % [r.itemKinds])
	runner.check(not r.has("mode"), "la modalità si vota, non si manda")
	runner.check(p.chosen_bot_level() == "difficile", "il livello dei bot")
	p.free()


func test_i_bot_possono_stare_fermi() -> void:
	var p := _panel({"stocks": 3}, "manichino")
	runner.check(p.chosen_bot_level() == "manichino", "il livello manichino resta: %s" % p.chosen_bot_level())
	p.free()


func test_ogni_oggetto_ha_il_suo_interruttore() -> void:
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var p := _panel({"stocks": 3})
	runner.check((p.chosen_rules().itemKinds as Array).size() == (game.droppableItems as Array).size(), "senza elenco sono tutti accesi, uno per oggetto di game.json")
	p.free()


func test_un_tempo_strano_non_si_perde() -> void:
	var p := _panel({"stocks": 3, "timeLimitSec": 240})
	runner.check(p.chosen_rules().timeLimitSec == 240, "4 minuti restano 4 minuti: %s" % p.chosen_rules().timeLimitSec)
	p.sync({"stocks": 2, "timeLimitSec": 0}, "facile", true)
	runner.check(p.chosen_rules().stocks == 2 and p.chosen_rules().timeLimitSec == 0 and p.chosen_bot_level() == "facile", "lo snapshot nuovo aggiorna la schermata")
	p.free()
