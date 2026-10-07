# Vibrazione del pad (E6 passo 5). Come audio.gd ascolta solo gli eventi dello snapshot
# (main.gd la chiama con on_event): vibra quando colpisco, quando sono colpito e al mio KO.
class_name Rumble
extends RefCounted

const OFF := 0
const WEAK := 1
const STRONG := 2
const LEVEL_NAMES := ["Spenta", "Debole", "Forte"]

var spec: Dictionary # RUMBLE di constants.ts, da game.json
var level := STRONG
var my_id := ""


func _init(rumble_spec: Dictionary) -> void:
	spec = rumble_spec


func on_event(e: Dictionary) -> void:
	var r := effect(e)
	if r.x <= 0:
		return
	for device in Input.get_connected_joypads():
		# weak = motore piccolo (vibrazione fine), strong = motore grande
		Input.start_joy_vibration(device, r.x, r.x, r.y)


# Forza (x, da 0 a 1) e durata (y, secondi) per un evento; forza 0 se non mi riguarda
func effect(e: Dictionary) -> Vector2:
	if level == OFF or my_id == "":
		return Vector2.ZERO
	var scale: float = spec.weakScale if level == WEAK else 1.0
	match e.get("type"):
		"hit":
			var mine: bool = e.targetId == my_id
			if not mine and e.attackerId != my_id:
				return Vector2.ZERO
			var k := clampf(float(e.knockback) / spec.hitMaxKnockback, 0, 1)
			var strength: float = lerpf(spec.hitMinStrength, 1.0, k) * (1.0 if mine else spec.attackerScale)
			return Vector2(strength * scale, spec.hitMs / 1000.0)
		"ko":
			if e.id == my_id:
				return Vector2(spec.koStrength * scale, spec.koMs / 1000.0)
	return Vector2.ZERO
