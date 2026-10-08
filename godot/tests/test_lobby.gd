# Lobby in due parti (lobby.gd, E14 passo 2): Entra in una stanza / Crea stanza
extends RefCounted

var runner

const Lobby := preload("res://scripts/lobby.gd")


func _lobby(start_join: bool, params := {}) -> Control:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var lobby: Control = Lobby.new()
	runner.root.add_child(lobby)
	var p := {"name": "Nic", "room": "vecchia", "server": "http://localhost:3000"}
	p.merge(params, true)
	lobby.setup(game, p, func(r): return "http://x/?room=" + r, start_join)
	return lobby


func _last_choice(lobby: Control, action: Callable) -> Dictionary:
	var got := {}
	lobby.join_requested.connect(func(c): got.merge(c))
	action.call()
	return got


func test_parte_da_crea_senza_link() -> void:
	var lobby := _lobby(false)
	runner.check(lobby._creating, "si parte da Crea stanza")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.room == lobby._new_room.text and c.room != "vecchia", "stanza nuova: %s" % c.room)
	runner.check(c.bot == "", "nessun bot se non scelto")
	lobby.free()


func test_contro_un_bot() -> void:
	var lobby := _lobby(false)
	var c := _last_choice(lobby, lobby._quick_bot)
	runner.check(c.bot == Lobby.QUICK_BOT, "bot di riserva: %s" % c.bot)
	lobby._bot.select(4)
	c = _last_choice(lobby, lobby._quick_bot)
	runner.check(c.bot == "difficile", "il bot scelto nelle regole: %s" % c.bot)
	lobby.free()


func test_entra_con_il_link_incollato() -> void:
	var lobby := _lobby(false)
	lobby._room.text = "https://bonobo.example/godot/?room=Amici&server=https%3A%2F%2Fsrv.example"
	lobby._on_room_text(lobby._room.text)
	runner.check(not lobby._creating, "il link porta su Entra")
	runner.check(lobby._room.text == "Amici", "resta la stanza: %s" % lobby._room.text)
	runner.check(lobby._server.text == "https://srv.example", "e il server: %s" % lobby._server.text)
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.room == "amici" and c.bot == "", "entra in amici senza bot: %s" % [c])
	lobby.free()


func test_parte_da_entra_con_il_link() -> void:
	var lobby := _lobby(true, {"room": "serata"})
	runner.check(not lobby._creating, "dal link si parte da Entra")
	runner.check(not lobby._advanced.visible, "Avanzate chiuso")
	runner.check(_last_choice(lobby, lobby._submit).room == "serata", "la stanza del link")
	lobby.free()


func test_barre_delle_statistiche() -> void:
	var limits := {"min": 0.8, "max": 1.2}
	runner.check(is_equal_approx(Lobby.stat_fill(1.0, limits), 0.5), "il metro sta a metà")
	runner.check(is_equal_approx(Lobby.stat_fill(1.2, limits), 1.0), "il massimo riempie")
	runner.check(Lobby.stat_fill(0.5, limits) == 0.0, "sotto il minimo: vuota")
	runner.check(Lobby.stat_fill(1.05, limits) > Lobby.stat_fill(0.9, limits), "più alto, più pieno")
	runner.check(is_equal_approx(Lobby.stat_fill(1.0, {}), 0.5), "dati vecchi senza limiti")
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(Lobby.stats_text(game.characters.orsoblu) == "Velocità 90% · Salto 95% · Peso 105%", Lobby.stats_text(game.characters.orsoblu))
	runner.check(Lobby.stats_text({}) == "Velocità 100% · Salto 100% · Peso 100%", "senza stats: come Bonobot")
