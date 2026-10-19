# Movimento secondario del lottatore a pezzi (rig_motion.gd, #404)
extends RefCounted

var runner

const RigView := preload("res://scripts/rig_view.gd")
const RigMotion := preload("res://scripts/rig_motion.gd")


func _nonna() -> RefCounted:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	return RigView.open("res://data/" + str(game.characters.nonnagina.sprite.rig))


func _rest(rig: RefCounted) -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(2 + rig.parents.size())
	return p


func _bone(rig: RefCounted, p: PackedFloat32Array, name: String) -> float:
	return p[2 + int(rig.names[name])]


func test_passaggio_breve_tra_stati() -> void:
	var rig := _nonna()
	if rig == null:
		return
	var m := RigMotion.new()
	var a := _rest(rig)
	var b := _rest(rig)
	b[0] = 20.0
	m.apply(rig, a, 1000.0, {"token": "idle"})
	var start: PackedFloat32Array = m.apply(rig, b, 1016.0, {"token": "walk"})
	runner.check(start[0] < 4.0, "appena cambia stato si parte dalla posa di prima (%s)" % start[0])
	var mid: PackedFloat32Array = m.apply(rig, b, 1056.0, {"token": "walk"})
	runner.check(mid[0] > 5.0 and mid[0] < 20.0, "a metà passaggio sta in mezzo (%s)" % mid[0])
	var done: PackedFloat32Array = m.apply(rig, b, 1100.0, {"token": "walk"})
	runner.check(is_equal_approx(done[0], 20.0), "dopo BLEND_MS è la posa nuova")


func test_crocchia_resta_indietro_e_si_ferma() -> void:
	var rig := _nonna()
	if rig == null:
		return
	var m := RigMotion.new()
	var still := _rest(rig)
	var turned := _rest(rig)
	rig.add(turned, "head", 30.0)
	var t := 0.0
	m.apply(rig, still, t, {})
	t += 16.0
	var first: PackedFloat32Array = m.apply(rig, turned, t, {})
	runner.check(_bone(rig, first, "tuft_back") < -10.0, "la testa scatta: la crocchia resta indietro (%s)" % _bone(rig, first, "tuft_back"))
	var overshoot := 0.0
	var last := first
	for i in 120:
		t += 16.0
		last = m.apply(rig, turned, t, {})
		overshoot = maxf(overshoot, _bone(rig, last, "tuft_back"))
	runner.check(overshoot > 0.5, "poi supera e torna (%s)" % overshoot)
	runner.check(absf(_bone(rig, last, "tuft_back")) < 0.5, "e da ferma si ferma (%s)" % _bone(rig, last, "tuft_back"))


func test_guarda_l_avversario() -> void:
	var rig := _nonna()
	if rig == null:
		return
	var m := RigMotion.new()
	var p := _rest(rig)
	var out := p
	for i in 60:
		out = m.apply(rig, p, i * 16.0, {"look": Vector2(200, -150)})
	runner.check(_bone(rig, out, "head") < -5.0, "l'avversario più in alto: alza la testa (%s)" % _bone(rig, out, "head"))
	var back := RigMotion.new()
	for i in 60:
		out = back.apply(rig, p, i * 16.0, {"look": Vector2(-300, -150)})
	runner.check(absf(_bone(rig, out, "head")) < 0.5, "chi sta dietro non si guarda")


func test_respiro_e_smear() -> void:
	var rig := _nonna()
	if rig == null:
		return
	var m := RigMotion.new()
	var p := _rest(rig)
	var lo := 99.0
	var hi := -99.0
	for i in 150:
		var out: PackedFloat32Array = m.apply(rig, p, i * 16.0, {"idle": true})
		lo = minf(lo, _bone(rig, out, "spine_2"))
		hi = maxf(hi, _bone(rig, out, "spine_2"))
	runner.check(hi - lo > 1.5 and m.smear == 0.0, "da ferma respira e il mattarello non si allunga (%s..%s)" % [lo, hi])
	var swing := _rest(rig)
	rig.add(swing, "hand_R", 90.0)
	m.apply(rig, swing, 150 * 16.0 + 16.0, {"idle": true})
	runner.check(m.smear > 0.3, "un colpo veloce allunga il mattarello (%s)" % m.smear)
