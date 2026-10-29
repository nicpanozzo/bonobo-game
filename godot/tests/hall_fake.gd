# Una sala d'attesa finta, senza server: per i test della sala 3D e gli screenshot (tools/screenshot.gd).
# Le zone sono una copia di hallLayout() di src/shared/hall.ts; se cambia là, qui basta che resti credibile.
extends RefCounted

const ZONES := [
	{"kind": "mode", "id": "ffa", "x": -660, "z": -680, "r": 170, "label": "Tutti contro tutti"},
	{"kind": "mode", "id": "teams", "x": -220, "z": -680, "r": 170, "label": "Squadre"},
	{"kind": "mode", "id": "flag", "x": 220, "z": -680, "r": 170, "label": "Bandiera"},
	{"kind": "mode", "id": "race", "x": 660, "z": -680, "r": 170, "label": "Corsa"},
	{"kind": "fighter", "id": "default", "x": -1380, "z": -380, "r": 70, "label": "Bonobo"},
	{"kind": "fighter", "id": "orsoblu", "x": -1200, "z": -380, "r": 70, "label": "Capt. OrsoBlu"},
	{"kind": "fighter", "id": "bonobot", "x": -1020, "z": -380, "r": 70, "label": "Bonobot"},
	{"kind": "fighter", "id": "elvedeo", "x": -1380, "z": -180, "r": 70, "label": "Elvedeo"},
	{"kind": "fighter", "id": "egiainuso", "x": -1200, "z": -180, "r": 70, "label": "Egiainuso"},
	{"kind": "fighter", "id": "lampione", "x": -1020, "z": -180, "r": 70, "label": "Lampione"},
	{"kind": "fighter", "id": "bradipo", "x": -1380, "z": 20, "r": 70, "label": "Bradipo Giallo"},
	{"kind": "fighter", "id": "giovannifrana", "x": -1200, "z": 20, "r": 70, "label": "Giovanni fRana"},
	{"kind": "fighter", "id": "marcomunista", "x": -1020, "z": 20, "r": 70, "label": "Marcomunista"},
	{"kind": "fighter", "id": "lendmar", "x": -1380, "z": 220, "r": 70, "label": "Lendmar"},
	{"kind": "fighter", "id": "drmicelium", "x": -1200, "z": 220, "r": 70, "label": "Dr. Micelium"},
	{"kind": "fighter", "id": "coachcartier", "x": -1020, "z": 220, "r": 70, "label": "Electronmaster"},
	{"kind": "fighter", "id": "nonnagina", "x": -1380, "z": 420, "r": 70, "label": "Nonna Gina"},
	{"kind": "stage", "id": "palco", "x": 1080, "z": -400, "r": 120, "label": "Il Palco"},
	{"kind": "stage", "id": "isole", "x": 1360, "z": -400, "r": 120, "label": "Le Isole"},
	{"kind": "stage", "id": "fabbrica", "x": 1080, "z": -120, "r": 120, "label": "La Fabbrica"},
	{"kind": "stage", "id": "palestra", "x": 1360, "z": -120, "r": 120, "label": "La Palestra"},
	{"kind": "stage", "id": "padova", "x": 1080, "z": 160, "r": 120, "label": "Padova"},
	{"kind": "stage", "id": "musica", "x": 1360, "z": 160, "r": 120, "label": "Sala Prove"},
	{"kind": "stage", "id": "bologna", "x": 1080, "z": 440, "r": 120, "label": "Bologna"},
	{"kind": "stage", "id": "casuale", "x": 1360, "z": 440, "r": 120, "label": "Casuale"},
	{"kind": "ready", "id": "ready", "x": 0, "z": 100, "r": 260, "label": "Pronti"},
	{"kind": "trampoline", "id": "trampolino-sinistra", "x": -620, "z": 250, "r": 110, "label": "Trampolino"},
	{"kind": "trampoline", "id": "trampolino-destra", "x": 620, "z": 250, "r": 110, "label": "Trampolino"},
	{"kind": "botAdd", "id": "bot-chiama", "x": -720, "z": 650, "r": 90, "label": "Chiama un bot"},
	{"kind": "botRemove", "id": "bot-via", "x": -480, "z": 650, "r": 90, "label": "Manda via un bot"},
	{"kind": "gong", "id": "gong", "x": 1250, "z": -720, "r": 90, "label": "Gong"},
	{"kind": "throne", "id": "trono", "x": -1250, "z": -720, "r": 80, "label": "Trono del campione"},
]

const BOARD := [
	{"name": "Nicola", "rating": 1312, "tier": "Silverback", "wins": 31, "matches": 44, "streak": 4},
	{"name": "Davide", "rating": 1244, "tier": "Gorilla", "wins": 25, "matches": 41, "streak": 0},
	{"name": "Riccardo", "rating": 1187, "tier": "Gorilla", "wins": 20, "matches": 38, "streak": 3},
	{"name": "Marta", "rating": 1096, "tier": "Orango", "wins": 14, "matches": 30, "streak": 1},
	{"name": "Gianlu", "rating": 1041, "tier": "Babbuino", "wins": 11, "matches": 29, "streak": 0},
	{"name": "Elena", "rating": 998, "tier": "Babbuino", "wins": 8, "matches": 22, "streak": 2},
	{"name": "Pietro", "rating": 962, "tier": "Babbuino", "wins": 6, "matches": 20, "streak": 0},
	{"name": "Sara", "rating": 930, "tier": "Scimmietta", "wins": 3, "matches": 12, "streak": 0},
]


# Un giocatore della sala: nome, lottatore, colore, dove sta (cm) e qualche campo in più
static func player(id: String, name: String, character_id: String, color: int, x: float, z: float, extra := {}) -> Dictionary:
	var p := {
		"id": id, "name": name, "characterId": character_id, "skinId": "", "color": color,
		"x": x, "y": 0.0, "z": z, "facing": 1, "moving": false, "onGround": true, "ready": false,
		"modeVote": null, "stageVote": null, "bot": false, "away": false, "host": false, "emote": false,
		"stunMs": 0, "throne": false,
	}
	p.merge(extra, true)
	return p


static func snapshot(t: float, players: Array, extra := {}) -> Dictionary:
	var votes := {"mode": {}, "stage": {}}
	for p in players:
		if p.modeVote != null:
			votes.mode[p.modeVote] = int(votes.mode.get(p.modeVote, 0)) + 1
		if p.stageVote != null:
			votes.stage[p.stageVote] = int(votes.stage.get(p.stageVote, 0)) + 1
	var snap := {
		"t": t, "width": 3000, "depth": 1800, "zones": ZONES.duplicate(true), "players": players, "votes": votes,
		"leading": {"mode": "ffa", "stageId": "palco"}, "countdownMs": null, "need": null, "events": [],
		"board": BOARD.duplicate(true), "rules": {"mode": "ffa", "stocks": 3, "timeLimitSec": 240, "friendlyFire": false, "teamCount": 2, "supremeSpeed": 1, "itemAmount": 2, "itemKinds": ["banana", "bong"]},
	}
	snap.merge(extra, true)
	return snap


# Una serata tipo: sei amici e un bot, chi vota, chi è sul trono, chi salta sul trampolino
static func party(t: float, scene := "sala") -> Dictionary:
	var wob := sin(t / 400.0) * 20.0
	var players := [
		player("p0", "Davide", "bonobot", 0xe74c3c, 60, -330 + wob * 0.2, {"host": true, "modeVote": "ffa", "stageVote": "palco", "facing": -1}),
		player("p1", "Nicola", "nonnagina", 0x3498db, -660, -640, {"modeVote": "ffa", "moving": false}),
		player("p2", "Riccardo", "orsoblu", 0x2ecc71, 380, -60 + wob, {"moving": true, "ready": true, "modeVote": "teams", "stageVote": "bologna"}),
		player("p3", "Marta", "elvedeo", 0xf1c40f, -1250, -700, {"throne": true, "modeVote": "ffa", "stageVote": "palco"}),
		player("p4", "Gianlu", "default", 0x9b59b6, -170, 120, {"ready": true, "modeVote": "ffa", "stageVote": "palco"}),
		player("p5", "Elena", "bradipo", 0xe67e22, 620, 250, {"y": 180.0 + absf(wob) * 4.0, "onGround": false, "modeVote": "race"}),
		player("p6", "Bonobot", "bonobot", 0x1abc9c, 160, 230, {"bot": true, "ready": true, "facing": -1}),
		player("p7", "Pietro", "lampione", 0xff7675, -220, -560, {"away": true, "modeVote": "teams"}),
	]
	var extra := {"need": "Servono tutti nel cerchio: mancano 3 giocatori"}
	if scene == "conto" or scene == "via":
		var spots := [[-120, 40], [120, 40], [0, 170], [-180, 190], [190, 180], [0, -60], [-60, 260], [80, 300]]
		for i in players.size():
			players[i].x = spots[i][0]
			players[i].z = spots[i][1]
			players[i].ready = true
			players[i].throne = false
			players[i].away = false
			players[i].y = 0.0
			players[i].onGround = true
			players[i].moving = false
		players[3].emote = true
		extra = {"countdownMs": 3200.0 if scene == "conto" else null, "need": null}
	elif scene == "galleria":
		players[0].x = -1200
		players[0].z = -110
		players[0].characterId = "egiainuso"
		players[1].x = 1080
		players[1].z = -40
		players[1].stageVote = "fabbrica"
		players[2].x = -1020
		players[2].z = 60
	return snapshot(t, players, extra)
