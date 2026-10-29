# Classifica a punti (leaderboard_view.gd): le due forme del server, l'ordine e le righe disegnate
extends RefCounted

var runner

const View := preload("res://scripts/leaderboard_view.gd")


func test_tabellone_a_punti() -> void:
	var rows := View.parse_board({"board": [
		{"name": "Bea", "rating": 1012.4, "tier": "Babbuino", "wins": 3, "matches": 5, "streak": 0},
		{"name": "Nic", "rating": 1163, "tier": "Gorilla", "wins": 9, "matches": 12, "streak": 4},
		{"rating": 2000},
	], "updatedAt": 123})
	runner.check(rows.size() == 2, "senza nome non si mostra: %d" % rows.size())
	runner.check(rows[0].name == "Nic" and rows[0].rating == 1163 and rows[0].streak == 4, "il primo per punti: %s" % [rows[0]])
	runner.check(rows[1].rating == 1012 and rows[1].tier == "Babbuino", "punti interi: %s" % [rows[1]])


func test_classifica_della_settimana_di_prima() -> void:
	var rows := View.parse_board([
		{"name": "Ada", "matches": 4, "wins": 1, "kos": 2, "falls": 3, "damageDealt": 90},
		{"name": "Nic", "matches": 6, "wins": 4, "kos": 9, "falls": 1, "damageDealt": 300, "rating": 1080, "tier": "Orango", "streak": 2},
		{"name": "Bo", "matches": 3, "wins": 3, "kos": 4, "falls": 0, "damageDealt": 200},
	])
	runner.check(rows.map(func(r): return r.name) == ["Nic", "Bo", "Ada"], "prima chi ha i punti, poi per vittorie: %s" % [rows.map(func(r): return r.name)])
	runner.check(rows[1].rating == -1 and rows[1].tier == "", "senza punti: %s" % [rows[1]])
	runner.check(View.parse_board("rotto").is_empty() and View.parse_board(null).is_empty(), "risposta strana: vuota")


func test_righe_e_chiusura() -> void:
	var view: Control = View.new()
	runner.root.add_child(view)
	view.setup("http://localhost:3000/", false)
	runner.check(view._server == "http://localhost:3000", "senza la barra in fondo: %s" % view._server)
	view.show_rows([])
	runner.check(view._status.visible and view._status.text.begins_with("Nessuno"), "classifica vuota: %s" % view._status.text)
	view.show_rows(View.parse_board({"board": [{"name": "Nic", "rating": 1163, "tier": "Gorilla", "wins": 9, "matches": 12, "streak": 4}]}))
	runner.check(not view._status.visible, "con le righe l'avviso sparisce")
	var closed := [false]
	view.closed.connect(func(): closed[0] = true)
	view.close()
	runner.check(closed[0], "Chiudi avvisa chi l'ha aperta")
	view.free()
