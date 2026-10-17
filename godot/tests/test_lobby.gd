# Lobby a pagine (lobby.gd, #250): Partita → Arena → Lottatore; Crea, Entra o Contro un bot
extends RefCounted

var runner

const Lobby := preload("res://scripts/lobby.gd")


func _lobby(start_join: bool, params := {}, start_kind := "") -> Control:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var lobby: Control = Lobby.new()
	runner.root.add_child(lobby)
	var p := {"name": "Nic", "room": "vecchia", "server": "http://localhost:3000"}
	p.merge(params, true)
	lobby.setup(game, p, func(r): return "http://x/?room=" + r, start_kind if start_kind != "" else ("join" if start_join else "create"))
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
	lobby._set_kind("bot")
	runner.check(lobby._creating, "contro un bot si crea una stanza")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.bot == Lobby.QUICK_BOT, "bot di riserva: %s" % c.bot)
	runner.check(c.room != "vecchia" and c.room != lobby._clean_room(lobby._new_room.text), "stanza tutta sua: %s" % c.room)
	lobby._bot.select(4)
	c = _last_choice(lobby, lobby._submit)
	runner.check(c.bot == "difficile", "il bot scelto nelle regole: %s" % c.bot)
	lobby._bot.select(0)
	c = _last_choice(lobby, lobby._submit)
	runner.check(c.bot == Lobby.QUICK_BOT, "senza bot scelto, quello di riserva: %s" % c.bot)
	lobby.free()


func test_pagine_e_briciole() -> void:
	var lobby := _lobby(false)
	runner.check(lobby._page == "match", "si parte dalla Partita")
	runner.check(lobby.flow() == ["match", "stage", "fighter"], "creando: partita, arena, lottatore")
	lobby._forward()
	runner.check(lobby._page == "stage", "Avanti porta all'arena")
	runner.check(lobby._pages.stage.visible and not lobby._pages.match.visible, "si vede solo l'arena")
	lobby._forward()
	runner.check(lobby._page == "fighter" and lobby._next_button.text == "Combatti!", "ultimo passo: %s" % lobby._next_button.text)
	var got := {}
	lobby.join_requested.connect(func(c): got.merge(c))
	lobby._forward()
	runner.check(got.has("room"), "dall'ultimo passo si entra")
	lobby._back()
	runner.check(lobby._page == "stage", "Indietro torna all'arena")
	var back := [false]
	lobby.back_requested.connect(func(): back[0] = true)
	lobby._back()
	lobby._back()
	runner.check(back[0], "dal primo passo Indietro torna al titolo")
	lobby.free()


func test_senza_arena_in_corsa_e_entrando() -> void:
	var lobby := _lobby(false)
	lobby._set_mode("race")
	runner.check(lobby.flow() == ["match", "fighter"], "in Corsa niente arena")
	lobby._set_kind("join")
	runner.check(lobby.flow() == ["match", "fighter"], "entrando niente arena")
	lobby._room.text = ""
	lobby._forward()
	runner.check(lobby._page == "match", "senza stanza non si va avanti")
	lobby._room.text = "amici"
	lobby._forward()
	runner.check(lobby._page == "fighter" and lobby._next_button.text == "Entra!", "poi il lottatore: %s" % lobby._next_button.text)
	lobby.free()


func test_scheda_del_lottatore() -> void:
	var lobby := _lobby(false, {"char": "bonobot"})
	runner.check(lobby._big_name.text == "Bonobot", "il lottatore scelto in grande: %s" % lobby._big_name.text)
	runner.check(lobby._big_moves.text.contains("Suprema: Omar"), lobby._big_moves.text)
	var b: Button = lobby._card(lobby._chars, "orsoblu")
	b.pressed.emit()
	runner.check(lobby._big_name.text == "Capt. OrsoBlu" and lobby._character == "orsoblu", "cambia con il riquadro")
	runner.check(lobby._big_moves.text.begins_with("Speciali: Schizzo"), lobby._big_moves.text)
	runner.check(lobby._summary.text.ends_with("Capt. OrsoBlu"), "e nel riassunto: %s" % lobby._summary.text)
	lobby.free()


func test_skin_del_lottatore() -> void:
	var lobby := _lobby(false, {"char": "lampione", "skin": "jax"})
	runner.check(lobby._skin == "jax", "la skin ricordata resta: %s" % lobby._skin)
	var shown := lobby._big_skins.get_children().filter(func(n): return not n.is_queued_for_deletion()).size()
	runner.check(shown == 3, "la scritta, Base e Jax: %d" % shown)
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.skin == "jax", "e va nella scelta: %s" % [c])
	lobby._card(lobby._chars, "bonobot").pressed.emit()
	runner.check(lobby._skin == "", "un altro lottatore torna all'aspetto base")
	var look := FighterPose.look(lobby.game, "lampione", "jax")
	runner.check(look.id == "lampione/jax" and str(look.sprite.dir).ends_with("skins/jax"), "il disegno della skin: %s" % look.id)
	runner.check(FighterPose.look(lobby.game, "bonobot", "jax").id == "bonobot", "chi non ha la skin resta com'è")
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


func test_parte_da_contro_un_bot() -> void:
	var lobby := _lobby(false, {}, "bot")
	runner.check(lobby._kind == "bot", "dal titolo Da solo → Contro un bot")
	runner.check(lobby._rules_box.visible, "si vedono regole e avversario")
	runner.check(_bot_id(lobby) == Lobby.QUICK_BOT, "c'è già un avversario: %s" % _bot_id(lobby))
	lobby.free()


func _bot_id(lobby: Control) -> String:
	return Lobby.BOTS[lobby._bot.selected][0]


func test_modalita_e_selettori() -> void:
	var lobby := _lobby(false)
	lobby._set_mode("flag")
	runner.check(lobby._stocks_label.text == "PUNTI" and lobby._ff.visible, "in Bandiera punti e fuoco amico")
	lobby._set_mode("training")
	runner.check(not lobby._stocks_box.visible and not lobby._time_box.visible, "in Allenamento niente vite né tempo")
	runner.check(_bot_id(lobby) == "manichino", "e c'è il manichino")
	lobby._stocks._step(1)
	lobby._stocks._step(1)
	runner.check(lobby._stocks.selected == 4, "le frecce cambiano le vite")
	lobby._stocks._step(1)
	runner.check(lobby._stocks.selected == 0, "e dopo l'ultimo si ricomincia")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.rules.mode == "training" and c.rules.stocks == 1, "le regole scelte: %s" % [c.rules])
	lobby.free()


# Anteprima che mostra già il palco (#284): la lobby non ci disegna sopra i pezzi; senza il segno sì
func test_anteprima_che_mostra_gia_il_palco() -> void:
	var Preview := preload("res://scripts/stage_preview.gd")
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(not Preview.draws_pieces(game.stages.padova), "Padova: l'anteprima basta")
	runner.check(Preview.draws_pieces(game.stages.palco), "il Palco: i pezzi sopra lo sfondo")
	runner.check(Preview.draws_pieces({"art": {"previewFull": true}}), "senza immagine si disegnano i pezzi")
	var p: Control = Preview.new()
	runner.check(p.clip_contents, "il disegno resta nel riquadro")
	p.free()


func test_torna_dalla_partita_sulla_stessa_stanza() -> void:
	var lobby := _lobby(false, {"room": "serata", "kind": "create", "rejoin": true})
	runner.check(lobby._new_room.text == "serata", "si ripropone la stanza di prima: %s" % lobby._new_room.text)
	lobby.open_page("fighter")
	runner.check(lobby._page == "fighter", "Cambia lottatore apre i lottatori")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.room == "serata" and c.kind == "create", "e si rientra lì: %s" % [c])
	lobby.free()
	lobby = _lobby(false, {"room": "vecchia", "kind": "create"})
	runner.check(lobby._new_room.text != "vecchia", "aprendo il gioco la stanza è nuova")
	lobby.free()
