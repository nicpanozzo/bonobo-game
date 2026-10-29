# Lobby a pagine (lobby.gd, #250): Partita → Arena → Lottatore; Crea, Entra o Contro un bot
extends RefCounted

var runner

const Lobby := preload("res://scripts/lobby.gd")
const FighterPose := preload("res://scripts/fighter_pose.gd")


# hall: la lobby della sala d'attesa 3D (quella del gioco); i test di prima provano quella con modalità e arena
func _lobby(start_join: bool, params := {}, start_kind := "", hall := false) -> Control:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var lobby: Control = Lobby.new()
	lobby.hall = hall
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


# Senza una scelta salvata si parte da un lottatore disegnato (Bonobot), non dal rettangolo del bonobo
# fatto col codice; una scelta salvata vince sempre, anche se è proprio il bonobo
func test_lottatore_di_partenza() -> void:
	var lobby := _lobby(false)
	runner.check(lobby._character == "bonobot", "senza scelta: Bonobot, non %s" % lobby._character)
	runner.check(lobby._summary.text.ends_with("Bonobot"), "e nel riassunto: %s" % lobby._summary.text)
	lobby.free()
	lobby = _lobby(false, {"char": ""})
	runner.check(lobby._character == "bonobot", "profilo salvato senza lottatore: Bonobot")
	lobby.free()
	lobby = _lobby(false, {"char": "default"})
	runner.check(lobby._character == "default", "la scelta salvata resta: %s" % lobby._character)
	lobby.free()
	lobby = _lobby(false, {"char": "elvedeo"})
	runner.check(lobby._character == "elvedeo" and lobby._big_name.text == "Elvedeo", "anche un altro: %s" % lobby._big_name.text)
	lobby.free()
	var game := {"defaultCharacterId": "default", "characters": {"default": {}, "tizio": {"sprite": {}}}}
	runner.check(Lobby.default_fighter(game) == "tizio", "senza Bonobot il primo disegnato")
	runner.check(Lobby.default_fighter({"defaultCharacterId": "default", "characters": {"default": {}}}) == "default", "senza disegni il bonobo")


# Le pagine stanno in uno schermo da 1280x720 senza scorrere: la prima creando, la seconda entrando con la squadra
func test_pagine_senza_scorrere() -> void:
	for kind in ["create", "bot", "join"]:
		var lobby := _lobby(false, {}, kind, true)
		lobby.size = Vector2(1280, 720)
		var scroll: ScrollContainer = lobby.find_children("*", "ScrollContainer", true, false)[0]
		var bars: Array = scroll.get_parent().get_children().filter(func(c): return c != scroll)
		var room: float = 720.0 - bars.reduce(func(acc, c): return acc + c.get_combined_minimum_size().y, 0.0)
		for page in ["match", "fighter"]:
			lobby._show_page(page, false)
			var need: float = lobby._pages[page].get_combined_minimum_size().y + Lobby.PAGE_TOP + UI.GAP_L
			runner.check(need <= room, "%s, %s: serve %d, c'è %d" % [kind, page, need, room])
		lobby.free()


func test_skin_del_lottatore() -> void:
	var lobby := _lobby(false, {"char": "lampione", "skin": "jax"})
	runner.check(lobby._skin == "jax", "la skin ricordata resta: %s" % lobby._skin)
	var shown: Array = lobby._big_skins.get_children().filter(func(n): return not n.is_queued_for_deletion())
	runner.check(shown.size() == 2 and shown[0].text == "Skin: Jax", "il nome della skin e i pallini: %s" % [shown.map(func(n): return n.text)])
	runner.check(lobby._skin_arrows.all(func(a): return a.visible), "le frecce del carosello si vedono")
	lobby._next_skin(1)
	runner.check(lobby._skin == "", "dopo l'ultima si torna alla base")
	lobby._next_skin(-1)
	runner.check(lobby._skin == "jax", "e indietro si torna a Jax")
	runner.check(lobby._summary.text.ends_with("Lampione (Jax)"), "il riassunto dice la skin: %s" % lobby._summary.text)
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.skin == "jax", "e va nella scelta: %s" % [c])
	lobby._card(lobby._chars, "bonobot").pressed.emit()
	runner.check(lobby._skin == "", "un altro lottatore torna all'aspetto base")
	runner.check(not lobby._skin_arrows[0].visible, "chi non ha skin non ha le frecce")
	var look := FighterPose.look(lobby.game, "lampione", "jax")
	runner.check(look.id == "lampione/jax" and str(look.sprite.dir).ends_with("skins/jax"), "il disegno della skin: %s" % look.id)
	runner.check(FighterPose.look(lobby.game, "bonobot", "jax").id == "bonobot", "chi non ha la skin resta com'è")
	lobby.free()


func test_entra_con_il_link_incollato() -> void:
	var lobby := _lobby(false)
	lobby._room.text = "https://bonobo.example/godot/?room=Amici&server=https%3A%2F%2Fsrv.example"
	lobby._on_room_text(lobby._room.text)
	runner.check(not lobby._creating, "il link porta su Entra")
	runner.check(lobby._room.text == "amici", "resta la stanza, già pulita: %s" % lobby._room.text)
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


# Suprema più veloce e oggetti scelti: arrivano nelle regole, gli oggetti solo dove cadono
func test_suprema_e_oggetti() -> void:
	var lobby := _lobby(false, {"rules": {"mode": "ffa", "supremeSpeed": 2, "itemAmount": 0, "itemKinds": ["banana"]}})
	runner.check(lobby._items_box.visible, "in tutti contro tutti si scelgono gli oggetti")
	runner.check(lobby._item_checks.size() >= 2 and lobby._item_checks["banana"].button_pressed and not lobby._item_checks["bong"].button_pressed, "tornano quelli scelti")
	runner.check(lobby._item_checks["banana"].disabled, "con Nessuno i tipi non si scelgono")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(is_equal_approx(float(c.rules.supremeSpeed), 2.0) and c.rules.itemAmount == 0 and c.rules.itemKinds == ["banana"], "nella scelta: %s" % [c.rules])
	lobby._set_mode("flag")
	runner.check(not lobby._items_box.visible, "in Bandiera niente oggetti")
	lobby.free()


# Squadre (#409): quante squadre nelle regole, la tua squadra nella pagina del lottatore
func test_squadre_e_la_tua_squadra() -> void:
	var lobby := _lobby(false, {"rules": {"mode": "teams", "teamCount": 3}, "team": 3})
	runner.check(lobby._team_count_box.visible, "a squadre si sceglie quante squadre")
	runner.check(lobby._team_picker.get_child_count() == 4, "Automatica e tre squadre: %d" % lobby._team_picker.get_child_count())
	runner.check(lobby._team_picker.selected == 3, "la squadra di prima resta scelta")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.rules.teamCount == 3 and c.team == 3, "regole e squadra nella scelta: %s %s" % [c.rules, c.team])
	# Con due squadre la Verde non c'è più: si torna ad Automatica
	lobby._team_count.select(0)
	lobby._sync_rules()
	runner.check(lobby._team_picker.selected == 0, "squadra che non c'è più: automatica")
	lobby._set_mode("ffa")
	runner.check(not lobby._team_box.visible and not lobby._team_count_box.visible, "tutti contro tutti: niente squadre")
	runner.check(_last_choice(lobby, lobby._submit).team == 0, "e nessuna squadra chiesta")
	lobby._set_kind("join")
	runner.check(lobby._team_box.visible, "entrando la squadra si sceglie comunque")
	lobby.free()


func test_arene_nascoste_fuori_dalla_lobby() -> void:
	var lobby := _lobby(false)
	var ids := []
	for b in lobby._stages.get_children():
		if not b.is_queued_for_deletion():
			ids.append(b.get_meta("id"))
	runner.check(lobby.game.stages.has("padova-palazzo"), "la vecchia Padova resta tra le arene, per id (#408)")
	runner.check(not ids.has("padova-palazzo"), "ma non ha la sua carta nella lobby: %s" % [ids])
	runner.check(ids.filter(func(id): return id.begins_with("padova")) == ["padova"], "una sola Padova: %s" % [ids])
	for id in ids:
		runner.check(id.begins_with("casuale-") or not lobby.game.stages[id].get("hidden", false), "%s non è nascosta" % id)
	lobby.free()


# Il lottatore del bot (#383): si sceglie sotto "Bot", parte da Bonobot e va al server con la scelta
func test_lottatore_del_bot() -> void:
	var lobby := _lobby(false)
	runner.check(not lobby._bot_char_box.visible, "senza bot il selettore non c'è")
	runner.check(lobby._bot_char_ids[lobby._bot_char.selected] == Lobby.BOT_CHARACTER_ID, "parte da Bonobot")
	lobby._bot.select(1) # il manichino
	lobby._sync_rules()
	runner.check(lobby._bot_char_box.visible, "con un bot si sceglie il suo lottatore")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.bot == "manichino" and c.botChar == "bonobot", "manichino Bonobot: %s %s" % [c.bot, c.botChar])
	lobby._bot_char.select(lobby._bot_char_ids.find("elvedeo"))
	lobby._bot.select(4)
	c = _last_choice(lobby, lobby._submit)
	runner.check(c.bot == "difficile" and c.botChar == "elvedeo", "bot difficile Elvedeo: %s %s" % [c.bot, c.botChar])
	lobby.free()
	var again := _lobby(false, {"botChar": "lampione"}, "bot")
	runner.check(again._bot_char_box.visible, "contro un bot il selettore c'è subito")
	runner.check(again._bot_char_ids[again._bot_char.selected] == "lampione", "ricorda l'ultima scelta")
	again.free()


# Sala d'attesa 3D: creando, modalità e arena si votano in sala; restano le regole e i passi sono Partita → Lottatore
func test_con_la_sala_niente_modalita_ne_arena() -> void:
	var lobby := _lobby(false, {"rules": {"mode": "training", "stocks": 4}}, "", true)
	runner.check(lobby.flow() == ["match", "fighter"], "creando con la sala niente arena: %s" % [lobby.flow()])
	runner.check(not lobby._mode_cards.visible and not lobby._mode_heading.visible, "le schede delle modalità non si vedono")
	runner.check(lobby._hall_note.visible, "e c'è la nota sulla sala")
	runner.check(lobby._stocks_box.visible and lobby._time_box.visible and lobby._items_box.visible, "vite, tempo e oggetti restano")
	runner.check(lobby._mode_id() == "ffa", "l'allenamento salvato in sala non c'è: %s" % lobby._mode_id())
	runner.check(_bot_id(lobby) == "", "e niente manichino messo da solo")
	runner.check(lobby._summary.text.contains("in sala"), "il riassunto lo dice: %s" % lobby._summary.text)
	lobby._forward()
	runner.check(lobby._page == "fighter" and lobby._next_button.text == "In sala!", "da Partita al Lottatore: %s" % lobby._next_button.text)
	var c := _last_choice(lobby, lobby._forward)
	runner.check(c.get("hall") == true, "la scelta chiede la sala: %s" % [c])
	runner.check(c.rules.stocks == 4 and c.rules.mode == "ffa", "con le regole di chi crea: %s" % [c.rules])
	lobby.free()


func test_con_la_sala_contro_un_bot_ed_entrando() -> void:
	var lobby := _lobby(false, {}, "bot", true)
	runner.check(lobby.flow() == ["match", "fighter"], "contro un bot si va in sala anche lui")
	var c := _last_choice(lobby, lobby._submit)
	runner.check(c.hall == true and c.bot == Lobby.QUICK_BOT, "il bot lo aggiunge la sala: %s %s" % [c.hall, c.bot])
	lobby._set_kind("join")
	lobby._room.text = "serata"
	runner.check(lobby._team_box.visible, "entrando la squadra si sceglie ancora")
	c = _last_choice(lobby, lobby._submit)
	runner.check(c.hall == true and c.room == "serata", "entrando col link: %s" % [c])
	lobby.free()
	var old := _lobby(false)
	runner.check(_last_choice(old, old._submit).get("hall") == false, "senza la sala la scelta non la chiede")
	old.free()
