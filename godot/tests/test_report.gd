# Tasto Segnala del menu di pausa (#214): testo e indirizzo della issue già compilata
extends RefCounted

var runner

const PauseMenu := preload("res://scripts/pause_menu.gd")


func test_testo_con_i_dati_della_partita() -> void:
	var r := {"server": "https://bonobo-game.onrender.com", "room": "abc", "stage": "Il Palco", "rules": {"mode": "ffa"}, "me": "p1",
		"players": [{"id": "p1", "name": "Nicola", "characterId": "bonobot"}, {"id": "p2", "name": "Luca", "characterId": "elvedeo"}]}
	var body := PauseMenu.report_body(r, "v0.2.0 · build 7", "Web")
	for part in ["**Cosa è successo:**", "Versione: v0.2.0 · build 7", "Sistema: Web", "Stanza: abc", "Arena: Il Palco", "Modalità: ffa", "Nicola (bonobot), io, Luca (elvedeo)"]:
		runner.check(body.contains(part), "manca: " + part)
	runner.check(PauseMenu.report_body({}, "v1", "Linux").contains("Lottatori: nessuno"), "senza partita non si rompe")


func test_indirizzo_della_issue() -> void:
	var url := PauseMenu.report_url("a & b\nc #1")
	runner.check(url.begins_with("https://github.com/nicpanozzo/bonobo-game/issues/new?title=Segnalazione"), url)
	runner.check(url.contains("body=a%20%26%20b%0Ac%20%231"), "testo codificato: " + url)
