# Il link della serata copiato dal Discord: l'app lo riconosce e propone di entrare (title.gd, lobby.gd)
extends RefCounted

var runner

const Lobby := preload("res://scripts/lobby.gd")
const Title := preload("res://scripts/title.gd")

const TUNNEL := "https://gatto-blu.trycloudflare.com"


func test_link_dentro_un_messaggio() -> void:
	var text := "Venite? Si gioca! https://nicpanozzo.github.io/bonobo-game/godot/?room=amici&server=" + TUNNEL.uri_encode() + " dai"
	var found := Lobby.parse_link(text)
	runner.check(found.get("room") == "amici", "stanza: %s" % found)
	runner.check(found.get("server") == TUNNEL, "server: %s" % found)
	var wrapped := Lobby.parse_link("<https://x/godot/?server=http%3A%2F%2F192.168.1.5%3A3000&room=casa>")
	runner.check(wrapped.get("room") == "casa" and wrapped.get("server") == "http://192.168.1.5:3000", "link tra parentesi del Discord: %s" % wrapped)
	runner.check(Lobby.parse_link("amici").is_empty(), "solo il nome della stanza non è un link")


func test_invito_dagli_appunti() -> void:
	var link := "https://nicpanozzo.github.io/bonobo-game/godot/?room=Amici&server=" + TUNNEL.uri_encode()
	var found := Title.invite_from(link)
	runner.check(found.get("room") == "amici" and found.get("server") == TUNNEL, "invito: %s" % found)
	runner.check(Title.invite_from(link, "amici").is_empty(), "chi ospita la stanza non riceve il suo invito")
	runner.check(Title.invite_from("ciao a tutti").is_empty(), "testo qualsiasi: niente invito")
	runner.check(Title.invite_from("https://x/?server=" + TUNNEL).is_empty(), "senza stanza: niente invito")
	# La pagina servita dal server di gioco non scrive il server nel link
	var same := Title.invite_from("https://bonobo-game.onrender.com/godot/?room=sera")
	runner.check(same.get("server") == "https://bonobo-game.onrender.com", "server preso dall'indirizzo: %s" % same)
	runner.check(not Title.invite_from("https://nicpanozzo.github.io/bonobo-game/godot/?room=sera").has("server"), "dal sito: server di sempre")


func test_proprio_link_non_e_un_invito() -> void:
	var link := "https://x/?room=mia&server=" + TUNNEL
	UI.copy(link)
	runner.check(Title.invite_from(link).is_empty(), "il link appena copiato dal gioco stesso")
	UI.last_copied = ""


func test_dove_si_gioca() -> void:
	runner.check(Title.invite_detail({"server": "http://192.168.1.5:3000"}).contains("Wi-Fi"), "in casa")
	runner.check(Title.invite_detail({"server": TUNNEL}).contains("chi ospita"), "dal tunnel")
	runner.check(Title.invite_detail({}).contains("lottatore"), "server di sempre")


func test_scheda_in_cima_al_menu() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var title: Control = Title.new()
	runner.root.add_child(title)
	title.setup(game, true)
	var got := []
	title.invite_requested.connect(func(i): got.append(i))
	title._show_invite(Title.invite_from("https://x/?room=sera&server=" + TUNNEL))
	runner.check(title._invite_card != null and title._invite_card.get_index() == 0, "scheda dell'invito in cima")
	title._invite_card.pressed.emit()
	runner.check(got.size() == 1 and got[0].room == "sera", "il clic entra nella stanza: %s" % [got])
	title._show_invite({})
	runner.check(title._invite_card == null, "appunti senza link: la scheda sparisce")
	title.free()
