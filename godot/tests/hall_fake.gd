# Una sala d'attesa finta, senza server: per i test della sala 3D e gli screenshot (tools/screenshot.gd).
# Le zone sono una copia di hallLayout() di src/shared/hall.ts; se cambia là, qui basta che resti credibile.
extends RefCounted

const ZONES := [
	{"kind": "mode", "id": "ffa", "x": -880, "z": 520, "r": 170, "label": "Tutti contro tutti"},
	{"kind": "mode", "id": "teams", "x": -440, "z": 520, "r": 170, "label": "Squadre"},
	{"kind": "mode", "id": "flag", "x": 0, "z": 520, "r": 170, "label": "Bandiera"},
	{"kind": "mode", "id": "race", "x": 440, "z": 520, "r": 170, "label": "Corsa"},
	{"kind": "mode", "id": "party", "x": 880, "z": 520, "r": 170, "label": "Bonobo Party"},
	{"kind": "fighter", "id": "default", "x": -475, "z": -300, "r": 70, "label": "Bonobo"},
	{"kind": "fighter", "id": "orsoblu", "x": -665, "z": -300, "r": 70, "label": "Capt. OrsoBlu"},
	{"kind": "fighter", "id": "bonobot", "x": -855, "z": -300, "r": 70, "label": "Bonobot"},
	{"kind": "fighter", "id": "elvedeo", "x": -1045, "z": -300, "r": 70, "label": "Elvedeo"},
	{"kind": "fighter", "id": "egiainuso", "x": -1235, "z": -300, "r": 70, "label": "Egiainuso"},
	{"kind": "fighter", "id": "lampione", "x": -1425, "z": -300, "r": 70, "label": "Lampione"},
	{"kind": "fighter", "id": "bradipo", "x": -1615, "z": -300, "r": 70, "label": "Bradipo Giallo"},
	{"kind": "fighter", "id": "giovannifrana", "x": -380, "z": -680, "r": 70, "label": "Giovanni fRana"},
	{"kind": "fighter", "id": "marcomunista", "x": -570, "z": -680, "r": 70, "label": "Marcomunista"},
	{"kind": "fighter", "id": "lendmar", "x": -760, "z": -680, "r": 70, "label": "Lendmar"},
	{"kind": "fighter", "id": "drmicelium", "x": -950, "z": -680, "r": 70, "label": "Dr. Micelium"},
	{"kind": "fighter", "id": "coachcartier", "x": -1140, "z": -680, "r": 70, "label": "Electronmaster"},
	{"kind": "fighter", "id": "nonnagina", "x": -1330, "z": -680, "r": 70, "label": "Nonna Gina"},
	{"kind": "fighter", "id": "opus", "x": -1520, "z": -680, "r": 70, "label": "Maestro Opus"},
	{"kind": "stage", "id": "palco", "x": 530, "z": -260, "r": 120, "label": "Il Palco"},
	{"kind": "stage", "id": "isole", "x": 830, "z": -260, "r": 120, "label": "Il Diluvio"},
	{"kind": "stage", "id": "fabbrica", "x": 1130, "z": -260, "r": 120, "label": "La Fabbrica"},
	{"kind": "stage", "id": "palestra", "x": 1430, "z": -260, "r": 120, "label": "La Palestra"},
	{"kind": "stage", "id": "padova", "x": 380, "z": -660, "r": 120, "label": "Padova"},
	{"kind": "stage", "id": "musica", "x": 680, "z": -660, "r": 120, "label": "Sala Prove"},
	{"kind": "stage", "id": "bologna", "x": 980, "z": -660, "r": 120, "label": "Bologna"},
	{"kind": "stage", "id": "casuale", "x": 1280, "z": -660, "r": 120, "label": "Casuale"},
	{"kind": "ready", "id": "ready", "x": 0, "z": 0, "r": 260, "label": "Pronti"},
	{"kind": "trampoline", "id": "trampolino-sinistra", "x": -1000, "z": 150, "r": 110, "label": "Trampolino"},
	{"kind": "trampoline", "id": "trampolino-destra", "x": 1000, "z": 150, "r": 110, "label": "Trampolino"},
	{"kind": "botAdd", "id": "bot-chiama", "x": -1260, "z": 520, "r": 90, "label": "Chiama un bot"},
	{"kind": "botRemove", "id": "bot-via", "x": -1500, "z": 520, "r": 90, "label": "Manda via un bot"},
	{"kind": "computer", "id": "computer", "x": 1380, "z": 520, "r": 90, "label": "Regole della partita"},
	{"kind": "gong", "id": "gong", "x": 130, "z": -740, "r": 90, "label": "Gong"},
	{"kind": "throne", "id": "trono", "x": -130, "z": -740, "r": 80, "label": "Trono del campione"},
	{"kind": "court", "id": "campo", "x": 2300, "z": 0, "r": 600, "label": "Campo da basket"},
	{"kind": "hoop", "id": "canestro", "x": 2742, "z": 0, "r": 23, "label": "Canestro"},
	{"kind": "chessboard", "id": "scacchiera", "x": -2300, "z": 0, "r": 280, "label": "Scacchi giganti"},
	{"kind": "rack", "id": "rastrelliera", "x": 2140, "z": -800, "r": 80, "label": "Palloni"},
]
const WIDTH := 5800 # HALL.width: la zona giochi ai lati
const HOOP := Vector3(2742, 305, 0) # centro del ferro, cm
const CHESS_X := -2300
const CHESS_SQUARE := 70
const PIECES := {"king": [180, 27], "queen": [165, 26], "bishop": [135, 23], "knight": [120, 24], "rook": [110, 24], "pawn": [90, 20]} # h, r in cm
const BACK_RANK := ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"]

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
		"stunMs": 0, "throne": false, "holding": null, "baskets": 0,
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
		"t": t, "width": WIDTH, "depth": 1800, "zones": ZONES.duplicate(true), "players": players, "votes": votes,
		"leading": {"mode": "ffa", "stageId": "palco"}, "countdownMs": null, "need": null, "events": [],
		"board": BOARD.duplicate(true), "props": props(), "rules": {"mode": "ffa", "stocks": 3, "timeLimitSec": 240, "friendlyFire": false, "teamCount": 2, "supremeSpeed": 1, "itemAmount": 2, "itemKinds": ["banana", "bong"]},
	}
	snap.merge(extra, true)
	return snap


# Gli oggetti come li mette il server a inizio sala (makeProps in src/shared/hall.ts): tre palloni sulla
# rastrelliera, due da spiaggia, i 32 pezzi degli scacchi coi bianchi verso la telecamera
static func props() -> Array:
	var out := []
	for i in 3:
		out.append(prop("ball-%d" % (i + 1), "basketball", 2060 + i * 40, 12, -800, 12))
	out.append(prop("beach-1", "beachball", -200, 60, -420, 60))
	out.append(prop("beach-2", "beachball", 200, 60, -420, 60))
	for color in ["white", "black"]:
		var side := 1 if color == "white" else -1
		var c := "w" if color == "white" else "b"
		for f in 8:
			var kind: String = BACK_RANK[f]
			var id := "chess-%s-%s" % [c, kind] if kind in ["king", "queen"] else "chess-%s-%s-%s" % [c, kind, "abcdefgh"[f]]
			out.append(piece(id, kind, color, f, 3.5 * side))
			out.append(piece("chess-%s-pawn-%s" % [c, "abcdefgh"[f]], "pawn", color, f, 2.5 * side))
	return out


static func prop(id: String, kind: String, x: float, y: float, z: float, r: float, extra := {}) -> Dictionary:
	var p := {"id": id, "kind": kind, "x": x, "y": y, "z": z, "r": r, "yaw": 0.0, "spin": 0.0, "tilt": 0.0, "tiltDir": 0.0, "holder": null}
	p.merge(extra, true)
	return p


static func piece(id: String, kind: String, color: String, file: int, rank: float) -> Dictionary:
	var spec: Array = PIECES[kind]
	return prop(id, "chess", CHESS_X + (file - 3.5) * CHESS_SQUARE, 0, rank * CHESS_SQUARE, spec[1],
		{"piece": kind, "color": color, "h": spec[0], "yaw": 0.0 if color == "white" else PI})


static func find(list: Array, id: String) -> Dictionary:
	for p in list:
		if p.id == id:
			return p
	return {}


# Una serata tipo: sei amici e un bot, chi vota, chi è sul trono, chi salta sul trampolino
static func party(t: float, scene := "sala") -> Dictionary:
	var wob := sin(t / 400.0) * 20.0
	var players := [
		player("p0", "Davide", "bonobot", 0xe74c3c, 60, -330 + wob * 0.2, {"host": true, "modeVote": "ffa", "stageVote": "palco", "facing": -1}),
		player("p1", "Nicola", "nonnagina", 0x3498db, -880, 500, {"modeVote": "ffa", "moving": false}),
		player("p2", "Riccardo", "orsoblu", 0x2ecc71, 380, -60 + wob, {"moving": true, "ready": true, "modeVote": "teams", "stageVote": "bologna"}),
		player("p3", "Marta", "elvedeo", 0xf1c40f, -130, -740, {"throne": true, "modeVote": "ffa", "stageVote": "palco"}),
		player("p4", "Gianlu", "default", 0x9b59b6, -170, 120, {"ready": true, "modeVote": "ffa", "stageVote": "palco"}),
		player("p5", "Elena", "bradipo", 0xe67e22, 1000, 150, {"y": 180.0 + absf(wob) * 4.0, "onGround": false, "modeVote": "race"}),
		player("p6", "Bonobot", "bonobot", 0x1abc9c, 160, 230, {"bot": true, "ready": true, "facing": -1}),
		player("p7", "Pietro", "lampione", 0xff7675, -440, 560, {"away": true, "modeVote": "teams"}),
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
	elif scene == "basket":
		# partita al campo: Riccardo tira da tre in salto, il pallone è in volo sopra il ferro, gli altri guardano
		var spots := [[2180, 330], [1900, -150], [2080, 60], [2450, -330], [1960, -420], [1820, 420], [2480, 380], [2280, 620]]
		for i in players.size():
			players[i].x = spots[i][0]
			players[i].z = spots[i][1]
			players[i].throne = false
			players[i].away = false
			players[i].y = 0.0
			players[i].onGround = true
			players[i].moving = false
			players[i].ready = false
		players[0].holding = "ball-2"
		players[0].facing = 1
		players[1].baskets = 4
		players[2].baskets = 2
		players[3].baskets = 7
		players[2].y = 70.0
		players[2].onGround = false
		players[4].emote = true
		var list: Array = extra.get("props", props())
		var k := fposmod(t / 1400.0, 1.0) * 0.25 + 0.72 # la parte finale dell'arco, sopra il ferro
		var from := Vector3(2100, 260, 120)
		var to := HOOP + Vector3(-8, 0, 0)
		var arc := from.lerp(to, k) + Vector3(0, sin(k * PI) * 260, 0)
		var shot := find(list, "ball-1")
		shot.merge({"x": arc.x, "y": arc.y, "z": arc.z, "yaw": 0.0, "spin": fposmod(t / 60.0, TAU)}, true)
		var held := find(list, "ball-2")
		held.merge({"x": players[0].x, "y": 195, "z": players[0].z, "holder": "p0"}, true)
		var loose := find(list, "ball-3")
		loose.merge({"x": 2500, "y": 12, "z": 300, "yaw": 1.0, "spin": t / 200.0}, true)
		var beach := find(list, "beach-2")
		beach.merge({"x": 1550, "y": 140, "z": 560, "spin": t / 500.0, "yaw": 0.4}, true)
		extra = {"props": list, "need": null}
	elif scene == "scacchi":
		# alla scacchiera: qualche pezzo già per terra, il re nero sta cadendo
		var spots := [[-2180, 520], [-2700, 520], [-1850, 120], [-2450, -480], [-1850, -300], [-2900 + 120, 80], [-1700, 520], [-2250, 640]]
		for i in players.size():
			players[i].x = spots[i][0]
			players[i].z = spots[i][1]
			players[i].throne = false
			players[i].away = false
			players[i].y = 0.0
			players[i].onGround = true
			players[i].moving = false
		players[0].facing = -1
		var list: Array = props()
		var fallen := {"chess-w-pawn-e": [PI / 2, -PI / 2], "chess-b-pawn-d": [PI / 2, 0.4], "chess-b-knight-g": [PI / 2, -2.4], "chess-w-bishop-f": [PI / 2, 2.2], "chess-b-king": [0.95, -1.9]}
		for id in fallen:
			var pc := find(list, id)
			pc.tilt = fallen[id][0]
			pc.tiltDir = fallen[id][1]
		find(list, "chess-w-pawn-e").z = -20
		find(list, "chess-b-pawn-d").x = CHESS_X - 40
		find(list, "chess-b-pawn-d").z = -40
		extra = {"props": list, "need": null}
	elif scene == "computer":
		# al computer delle regole (#567): io davanti allo schermo, due amici che guardano
		players[0].x = 1300
		players[0].z = 590
		players[0].facing = 1
		players[2].x = 1540
		players[2].z = 630
		players[2].moving = false
		players[4].x = 1160
		players[4].z = 430
		players[4].ready = false
		extra = {"need": null, "botLevel": "difficile"}
	elif scene == "solo":
		# da solo nel cerchio dei pronti: la sala ha chiamato un manichino fermo e si parte
		players = [
			player("p1", "Nicola", "orsoblu", 0x3498db, -60, 60, {"host": true, "ready": true}),
			player("bot-sala-1", "Manichino", "bonobot", 0x1abc9c, 260, 330, {"bot": true, "ready": true, "facing": -1}),
		]
		extra = {"countdownMs": 3200.0, "need": null, "botLevel": "manichino"}
	elif scene == "galleria":
		players[0].x = -1235
		players[0].z = -220
		players[0].characterId = "egiainuso"
		players[1].x = 1130
		players[1].z = -180
		players[1].stageVote = "fabbrica"
		players[2].x = -1045
		players[2].z = -200
	return snapshot(t, players, extra)
