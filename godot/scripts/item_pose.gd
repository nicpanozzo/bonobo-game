extends RefCounted
# Pose con gli oggetti (docs/clip-flow/pose-oggetti.md): quale stato mostra chi tiene, lancia, consuma, porta o
# cavalca un oggetto, dalla categoria dell'oggetto (items.ts) e dagli eventi. Si usa solo uno stato che il lottatore
# ha disegnato davvero: chi non l'ha resta com'era. E dove si disegna l'oggetto in mano, dal punto della presa
# (mani.json, esportato in sprite.hands). Solo disegno: ascolta snapshot ed eventi, non tocca la fisica.

const FighterPose := preload("res://scripts/fighter_pose.gd")

# Stati in cui non si cambia posa per l'oggetto: colpito, preso, scudo, bordo, ancora, speciali, suprema
const BUSY := ["hit", "grabbed", "grab", "throw", "shield", "ledge", "climb", "anchorHang", "anchorClimb", "tumble", "jumpSquat", "recovery", "supreme", "taunt"]
const STILL := ["idle", "land"]
const MOVING := ["walk", "dash"]
const NOT_EATEN := ["veleno", "trip", "spore", "micelio"] # powerUp che arrivano da un colpo, non da qualcosa che si mangia
const RIDE_FAST := 260.0 # px/s: sopra si va forte sulla cavalcatura

# Dove si tiene ogni oggetto, nelle sue misure (w, h) con l'origine al centro come lo disegna world_view:
# [x della presa / w, y della presa / h, direzione dalla presa verso la punta]. Chi non c'è si tiene dal centro
const GRIP := {
	"scopa": [0.0, -0.42, PI / 2], # dal fondo del manico, la saggina in giù
	"ombrellone": [0.0, 0.2, -PI / 2], # dal fondo del palo, la cupola in su
	"pesce": [0.42, 0.0, PI], # per la coda, la testa in avanti
	"anguilla": [0.42, 0.0, PI],
	"pistola": [-0.3, 0.25, 0.0], # dal calcio, la canna in avanti
	"sparabolle": [-0.3, 0.25, 0.0],
	"sparabolleTriplo": [-0.3, 0.25, 0.0],
	"idrante": [0.0, 0.2, 0.0],
}
const MOUNT_GRIP := [0.0, 0.35, 0.0] # le cavalcature: la pedana sotto i piedi

var throws := {} # id -> {t, item, up}: l'ultimo lancio
var eats := {} # id -> quando ha consumato
var shots := {} # id -> l'ultimo sparo
var jets := {} # id -> l'ultimo getto carico
var dashes := {} # id -> l'ultimo scatto sulla cavalcatura


func reset() -> void:
	throws = {}
	eats = {}
	shots = {}
	jets = {}
	dashes = {}


func on_event(e: Dictionary, now: float) -> void:
	match str(e.get("type", "")):
		"itemThrow":
			throws[str(e.id)] = {"t": now, "item": int(e.itemId), "up": null, "cat": ""}
		"powerUp":
			if not (str(e.get("kind", "")) in NOT_EATEN) and int(e.get("itemId", -1)) >= 0:
				eats[str(e.id)] = now
		"gear":
			match str(e.get("phase", "")):
				"shot":
					shots[str(e.id)] = now
				"jet":
					jets[str(e.id)] = now
				"charge":
					dashes[str(e.id)] = now


# L'oggetto che id tiene in mano ({} se nessuno)
static func held_item(items: Array, id: String) -> Dictionary:
	for it in items:
		if it.get("heldBy") == id:
			return it
	return {}


static func category(game: Dictionary, kind: String) -> String:
	return str(game.get("items", {}).get(kind, {}).get("category", ""))


# Lo stato da mostrare al posto di name e da quando ([stato, since], since -1 = come prima)
func pick(name: String, p: Dictionary, anims: Dictionary, items: Array, game: Dictionary, now: float) -> Array:
	if name in BUSY or name.begins_with("special"):
		return [name, -1.0]
	var id := str(p.id)
	# appena lanciato: la posa del lancio parte dal fotogramma in cui l'oggetto lascia la mano
	if throws.has(id):
		var th: Dictionary = throws[id]
		if th.up == null:
			for it in items:
				if int(it.id) == int(th.item):
					th.up = absf(float(it.get("vy", 0.0))) > absf(float(it.get("vx", 0.0))) * 1.2 and float(it.get("vy", 0.0)) < 0.0
					th.cat = category(game, str(it.kind))
		var want := "carryToss" if th.cat == "peso" else ("itemThrowUp" if th.up == true else "itemThrow")
		if FighterPose.has_own(anims, want) and now - float(th.t) < _left(anims[want]):
			return [want, float(th.t) - _hit_ms(anims[want])]
	if eats.has(id) and FighterPose.has_own(anims, "itemEat") and now - float(eats[id]) < FighterPose.animation_ms(anims.itemEat):
		return ["itemEat", float(eats[id])]
	var it := held_item(items, id)
	if it.is_empty():
		return [name, -1.0]
	var want := ""
	var since := -1.0
	var attack := str(p.attack) if p.get("attack") != null else ""
	match category(game, str(it.kind)):
		"impugnatura":
			if attack.begins_with("heavy") or attack == "dashAttack":
				want = "gripHeavy"
			elif attack.begins_with("light"):
				want = "gripLight"
			elif name in STILL:
				want = "gripIdle"
			elif name in MOVING:
				want = "gripWalk"
		"sparo":
			if jets.has(id) and FighterPose.has_own(anims, "aimCharge") and now - float(jets[id]) < FighterPose.animation_ms(anims.aimCharge):
				return ["aimCharge", float(jets[id])]
			if shots.has(id) and FighterPose.has_own(anims, "aimShoot") and now - float(shots[id]) < FighterPose.animation_ms(anims.aimShoot):
				return ["aimShoot", float(shots[id])]
			if attack == "" and name in STILL:
				want = "aimIdle"
			elif attack == "" and name in MOVING:
				want = "aimWalk"
		"lancio", "consumo":
			if name in STILL:
				want = "itemHold"
		"peso":
			if name in STILL:
				want = "carryIdle"
			elif name in MOVING:
				want = "carryWalk"
		"cavalcatura":
			if attack != "":
				pass
			elif not p.get("onGround", true):
				want = "rideHop"
			elif absf(float(p.get("vx", 0.0))) > RIDE_FAST or (dashes.has(id) and now - float(dashes[id]) < 500.0):
				want = "rideDash"
			else:
				want = "rideIdle"
	if want != "" and FighterPose.has_own(anims, want):
		return [want, since]
	return [name, -1.0]


# Quanto resta da mostrare di una posa partita dal fotogramma del lancio
static func _left(a: Dictionary) -> float:
	return FighterPose.animation_ms(a) - _hit_ms(a)


static func _hit_ms(a: Dictionary) -> float:
	return float(a.get("hitFrame", 0)) / float(a.fps) * 1000.0


# Il punto della presa nel fotogramma (dai piedi, rivolto a destra): [x, y, gradi, lunghezza] o null
static func hand_point(sheet: Dictionary, src: String, frame: int) -> Variant:
	var hands: Variant = sheet.get("hands")
	if not (hands is Dictionary) or not hands.has(src):
		return null
	var pts: Array = hands[src]
	for k in range(clampi(frame, 0, pts.size() - 1), -1, -1): # dove il segnaposto non si vedeva, quello di prima
		if pts[k] != null:
			return pts[k]
	return null


# La presa nel mondo: {pos, angle} da un punto di hand_point, per chi sta in (x, y) rivolto a facing, disegnato a scale
static func hand_world(h: Array, x: float, y: float, facing: float, scale: float, react := Transform2D.IDENTITY) -> Dictionary:
	var pos: Vector2 = react * (Transform2D(0.0, Vector2(facing * scale, scale), 0.0, Vector2(x, y)) * Vector2(float(h[0]), float(h[1])))
	var deg := deg_to_rad(float(h[2]))
	return {"pos": pos, "angle": deg if facing >= 0.0 else PI - deg, "facing": signf(facing) if facing != 0.0 else 1.0}


# Dove va il centro dell'oggetto e come ruota perché la sua presa stia sulla mano: [centro, rotazione, specchio]
static func held_transform(kind: String, cat: String, w: float, h: float, hand: Dictionary, item_scale: float) -> Array:
	var g: Array = GRIP.get(kind, MOUNT_GRIP if cat == "cavalcatura" else [0.0, 0.0, 0.0])
	var m: float = hand.facing
	var turn := cat in ["impugnatura", "sparo", "cavalcatura"]
	var axis: float = float(g[2]) if m > 0.0 else PI - float(g[2])
	var rot: float = float(hand.angle) - axis if turn else 0.0
	var grip := Vector2(m * float(g[0]) * w, float(g[1]) * h) * item_scale
	return [hand.pos - grip.rotated(rot), rot, m]
