# Il movimento secondario del lottatore a pezzi (#404), uno per giocatore. Solo disegno: parte dalla posa delle
# chiavi (rig_view.gd) e ci aggiunge quello che una posa fissa non sa fare:
# - un passaggio breve tra uno stato e l'altro, invece del taglio netto;
# - il respiro da fermi e il busto che si piega in corsa;
# - la testa che guarda l'avversario più vicino;
# - crocchia e ricciolo su una molla smorzata, che restano indietro e oscillano quando la testa scatta;
# - lo smear del mattarello: si allunga quando la mano gira veloce (lo legge rig_view.draw()).
extends RefCounted

const BLEND_MS := 80.0 # il passaggio tra due stati
const BREATH_HZ := 0.45 # respiri al secondo, da ferma
const RUN_LEAN := 4.0 # gradi in più del busto a tutta corsa
const LOOK_MAX := 14.0 # gradi: quanto gira la testa verso l'avversario
const LOOK_RATE := 8.0 # quanto in fretta ci arriva (1/s)
const HAIR_K := 140.0 # rigidità della molla della crocchia (1/s²)
const HAIR_DAMP := 9.0 # smorzamento: sotto il critico (2√k ≈ 24) la crocchia supera e torna
const HAIR_MAX := 22.0 # gradi
const SMEAR_FROM := 700.0 # gradi al secondo della mano sotto cui il mattarello non si allunga
const SMEAR_FULL := 3500.0 # e sopra cui si allunga del massimo
const SMEAR_MAX := 0.45
const SMEAR_FADE := 5.0 # quanto in fretta torna corto (1/s)

var token := "" # lo stato in corso: quando cambia parte il passaggio
var since := 0.0
var blend_ms := BLEND_MS
var from := PackedFloat32Array() # l'ultima posa disegnata dello stato di prima
var last := PackedFloat32Array()
var last_ms := -1.0
var hair := 0.0 # la molla della crocchia: dove sta e quanto va veloce, in gradi
var hair_v := 0.0
var look := 0.0
var hand := 0.0
var smear := 0.0 # quanto è allungato il mattarello adesso (0 = normale)


# La posa da disegnare adesso. ctx (tutto facoltativo):
#   token: cambia quando cambia lo stato; blend_ms: quanto dura il passaggio
#   vx, vy: velocità in px/s, vx nel verso dello sguardo; look: Vector2 dai piedi all'avversario più vicino, x nel
#   verso dello sguardo (null se non c'è); idle: è ferma; run: da 0 a 1 quanto corre; head_free: da 0 a 1 quanto la
#   testa è libera di guardare (poco durante i colpi, che hanno già la loro testa)
func apply(rig: RefCounted, pose: PackedFloat32Array, now: float, ctx: Dictionary) -> PackedFloat32Array:
	var dt := clampf((now - last_ms) / 1000.0, 0.0, 0.05) if last_ms >= 0.0 else 0.0
	last_ms = now
	var t := str(ctx.get("token", ""))
	if t != token:
		token = t
		since = now
		from = last
		blend_ms = float(ctx.get("blend_ms", BLEND_MS))
	var p := pose.duplicate()
	var w := clampf((now - since) / maxf(1.0, blend_ms), 0.0, 1.0)
	if w < 1.0 and from.size() == p.size():
		p = rig.blend(from, p, w * w * (3.0 - 2.0 * w))
	if ctx.get("idle", false):
		var breath := sin(now / 1000.0 * TAU * BREATH_HZ)
		rig.add(p, "spine_2", 1.2 * breath)
		rig.add(p, "spine_3", 1.0 * breath)
		rig.add(p, "neck", -0.8 * breath)
		p[1] -= 0.6 * (0.5 + 0.5 * breath) # si alza un poco quando inspira
	var run := clampf(float(ctx.get("run", 0.0)), 0.0, 1.0)
	if run > 0.0:
		rig.add(p, "spine_1", RUN_LEAN * 0.3 * run)
		rig.add(p, "spine_2", RUN_LEAN * 0.4 * run)
		rig.add(p, "spine_3", RUN_LEAN * 0.3 * run)
		rig.add(p, "neck", -RUN_LEAN * 0.6 * run)
	var target := 0.0
	var at: Variant = ctx.get("look")
	if at is Vector2 and at.x > -40.0: # chi sta dietro non si guarda: per girarsi c'è il cambio di verso
		target = clampf(rad_to_deg(atan2(at.y, maxf(absf(at.x), 80.0))), -LOOK_MAX, LOOK_MAX) * float(ctx.get("head_free", 1.0))
	look = lerpf(look, target, 1.0 - exp(-dt * LOOK_RATE))
	rig.add(p, "neck", look * 0.3)
	rig.add(p, "head", look * 0.7)
	_hair(rig, p, dt, float(ctx.get("vx", 0.0)), float(ctx.get("vy", 0.0)))
	var hand_now: float = rig.turn_of(p, "hand_R")
	if dt > 0.0 and last.size() == p.size():
		var speed := absf(wrapf(hand_now - hand, -180.0, 180.0)) / dt
		var want := clampf((speed - SMEAR_FROM) / (SMEAR_FULL - SMEAR_FROM), 0.0, 1.0) * SMEAR_MAX
		smear = maxf(want, smear - dt * SMEAR_FADE)
	hand = hand_now
	last = p
	return p


# La crocchia segue la testa con una molla: quando la testa (o il corpo) cambia di colpo resta indietro, poi supera e torna.
# A velocità costante non resta piegata: conta solo il cambio
func _hair(rig: RefCounted, p: PackedFloat32Array, dt: float, vx: float, vy: float) -> void:
	var drive: float = rig.turn_of(p, "head") - vx * 0.02 + vy * 0.012
	if last.is_empty():
		hair = drive
		hair_v = 0.0
	var steps := ceili(dt / 0.01)
	for i in steps:
		var h := dt / steps
		hair_v += (HAIR_K * (drive - hair) - HAIR_DAMP * hair_v) * h
		hair += hair_v * h
	var off := clampf(hair - drive, -HAIR_MAX, HAIR_MAX)
	rig.add(p, "tuft_back", off)
	rig.add(p, "tuft_front", off * 0.6)
