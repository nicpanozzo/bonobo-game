# Pose con gli oggetti (docs/clip-flow/pose-oggetti.md): stato per categoria, solo se disegnato, e oggetto sulla presa
extends RefCounted

var runner

const ItemPose := preload("res://scripts/item_pose.gd")

const GAME := {"items": {"scopa": {"category": "impugnatura"}, "pistola": {"category": "sparo"}, "cassa": {"category": "peso"},
	"monopattino": {"category": "cavalcatura"}, "ciabatta": {"category": "lancio"}, "caffe": {"category": "consumo"}}}


# Gli stati di un lottatore: disegnati (src = sé stesso) o col ripiego (src = un altro stato)
func _anims(own: Array) -> Dictionary:
	var out := {}
	for s in ["idle", "walk", "light", "heavy", "jump", "gripIdle", "gripWalk", "gripLight", "gripHeavy", "aimIdle", "aimShoot", "itemThrow", "itemThrowUp", "itemEat", "itemHold", "carryIdle", "carryWalk", "carryToss", "rideIdle", "rideDash", "rideHop"]:
		out[s] = {"src": s if s in own or s in ["idle", "walk", "light", "heavy", "jump"] else "idle", "frames": 10, "fps": 20, "loop": false, "hitFrame": 4}
	return out


func _p(extra := {}) -> Dictionary:
	var p := {"id": "a", "attack": null, "onGround": true, "vx": 0.0, "vy": 0.0}
	p.merge(extra, true)
	return p


func test_senza_disegno_resta_com_era() -> void:
	var pose: RefCounted = ItemPose.new()
	var items := [{"id": 1, "kind": "scopa", "heldBy": "a"}]
	var r: Array = pose.pick("idle", _p(), _anims([]), items, GAME, 1000.0)
	runner.check(r[0] == "idle", "chi non ha gripIdle resta fermo normale (%s)" % r[0])


func test_impugnatura() -> void:
	var pose: RefCounted = ItemPose.new()
	var anims := _anims(["gripIdle", "gripWalk", "gripLight", "gripHeavy"])
	var items := [{"id": 1, "kind": "scopa", "heldBy": "a"}]
	runner.check(pose.pick("idle", _p(), anims, items, GAME, 0.0)[0] == "gripIdle", "fermo con la scopa")
	runner.check(pose.pick("walk", _p(), anims, items, GAME, 0.0)[0] == "gripWalk", "cammina con la scopa")
	runner.check(pose.pick("lightUp", _p({"attack": "lightUp"}), anims, items, GAME, 0.0)[0] == "gripLight", "ogni leggero è il colpo leggero con l'arma")
	runner.check(pose.pick("heavyAir", _p({"attack": "heavyAir"}), anims, items, GAME, 0.0)[0] == "gripHeavy", "ogni forte è il colpo forte con l'arma")
	runner.check(pose.pick("hit", _p(), anims, items, GAME, 0.0)[0] == "hit", "colpito resta colpito")


func test_eventi() -> void:
	var pose: RefCounted = ItemPose.new()
	var anims := _anims(["aimIdle", "aimShoot", "itemThrow", "itemThrowUp", "itemEat"])
	var gun := [{"id": 1, "kind": "pistola", "heldBy": "a"}]
	pose.on_event({"type": "gear", "phase": "shot", "id": "a"}, 100.0)
	var r: Array = pose.pick("idle", _p(), anims, gun, GAME, 200.0)
	runner.check(r[0] == "aimShoot" and r[1] == 100.0, "appena sparato: la posa dello sparo, dallo sparo (%s)" % [r])
	runner.check(pose.pick("idle", _p(), anims, gun, GAME, 2000.0)[0] == "aimIdle", "poi torna a mirare")
	pose.on_event({"type": "itemThrow", "id": "a", "itemId": 7}, 3000.0)
	var flying := [{"id": 7, "kind": "ciabatta", "heldBy": null, "vx": 0.0, "vy": -500.0}]
	r = pose.pick("idle", _p(), anims, flying, GAME, 3050.0)
	runner.check(r[0] == "itemThrowUp", "lanciato in alto (%s)" % r[0])
	runner.check(is_equal_approx(float(r[1]), 3000.0 - 200.0), "parte dal fotogramma del lancio: hitFrame 4 a 20 fps (%s)" % r[1])
	pose.on_event({"type": "powerUp", "id": "a", "itemId": 3, "kind": "caffe"}, 5000.0)
	runner.check(pose.pick("walk", _p(), anims, [], GAME, 5100.0)[0] == "itemEat", "il caffè si beve")
	pose.on_event({"type": "powerUp", "id": "a", "itemId": 4, "kind": "veleno"}, 9000.0)
	runner.check(pose.pick("walk", _p(), anims, [], GAME, 9100.0)[0] == "walk", "il veleno del fungo non si mangia")


func test_peso_e_cavalcatura() -> void:
	var pose: RefCounted = ItemPose.new()
	var anims := _anims(["carryIdle", "carryWalk", "rideIdle", "rideDash", "rideHop"])
	var crate := [{"id": 1, "kind": "cassa", "heldBy": "a"}]
	runner.check(pose.pick("walk", _p(), anims, crate, GAME, 0.0)[0] == "carryWalk", "cammina sotto la cassa")
	var ride := [{"id": 2, "kind": "monopattino", "heldBy": "a"}]
	runner.check(pose.pick("walk", _p({"vx": 100.0}), anims, ride, GAME, 0.0)[0] == "rideIdle", "piano: in piedi sulla tavola")
	runner.check(pose.pick("walk", _p({"vx": 400.0}), anims, ride, GAME, 0.0)[0] == "rideDash", "forte: chinato")
	runner.check(pose.pick("jump", _p({"onGround": false}), anims, ride, GAME, 0.0)[0] == "rideHop", "in aria: il salto con la tavola")


func test_presa_nel_mondo() -> void:
	var h: Array = [10.0, -50.0, -30.0, 40.0]
	var right: Dictionary = ItemPose.hand_world(h, 100.0, 200.0, 1.0, 0.5)
	runner.check(right.pos.is_equal_approx(Vector2(105, 175)), "a destra: piedi + punto * scala (%s)" % right.pos)
	var left: Dictionary = ItemPose.hand_world(h, 100.0, 200.0, -1.0, 0.5)
	runner.check(left.pos.is_equal_approx(Vector2(95, 175)), "a sinistra specchiato (%s)" % left.pos)
	runner.check(is_equal_approx(left.angle, PI - deg_to_rad(-30.0)), "e anche l'angolo")


func test_la_presa_dell_oggetto_sta_sulla_mano() -> void:
	for facing in [1.0, -1.0]:
		var hand := {"pos": Vector2(50, 60), "angle": 0.7 if facing > 0.0 else PI - 0.7, "facing": facing}
		var t: Array = ItemPose.held_transform("scopa", "impugnatura", 12.0, 58.0, hand, 1.5)
		# il fondo del manico (0, -0.42 h) trasformato come lo disegna _draw_item: centro, rotazione, specchio
		var grip := Vector2(facing * 0.0, -0.42 * 58.0) * 1.5
		var at: Vector2 = t[0] + grip.rotated(t[1])
		runner.check(at.is_equal_approx(hand.pos), "il manico in mano (%s, guarda %s)" % [at, facing])
		var tip: Vector2 = (Vector2(0, 1) * Vector2(facing, 1)).rotated(t[1]) # la saggina, verso +y nel disegno
		runner.check(absf(tip.angle() - float(hand.angle)) < 0.001 or absf(absf(tip.angle() - float(hand.angle)) - TAU) < 0.001, "la saggina verso la punta del segnaposto (%s)" % facing)
