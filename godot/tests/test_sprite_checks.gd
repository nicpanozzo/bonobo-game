# Controlli automatici sugli sprite dei lottatori (#384 C1 e C2), su tutti i personaggi e le skin:
# - C1: il primo fotogramma mostrato di ogni azione da tasto cambia già la sagoma rispetto al fermo;
# - C2: nel fotogramma d'impatto di ogni colpo qualcosa del disegno sta nella zona del colpo;
# - #243: nel disegno base la zona finisce dove arriva la punta del colpo (né nel vuoto né più corta).
extends RefCounted

var runner

const FighterPose := preload("res://scripts/fighter_pose.gd")

# Azioni che partono da un tasto. La provocazione no: può cominciare piano
const ACTIONS := ["walk", "jump", "doubleJump", "dash", "shield", "grab", "light", "heavy", "lightUp", "lightDown",
	"lightAir", "heavyUp", "heavyDown", "heavyAir", "dashAttack", "recovery", "specialNeutral", "specialSide", "specialDown", "supreme"]
# I colpi con la zona di ATTACKS
const STRIKES := ["light", "heavy", "lightUp", "lightDown", "lightAir", "heavyUp", "heavyDown", "heavyAir", "dashAttack"]
const MIN_CHANGE := 0.05 # frazione della sagoma del fermo che deve cambiare
const STEP := 4 # pixel del PNG tra un campione e l'altro: basta per la sagoma e il test resta veloce
# Colpi che oggi non arrivano nella zona, da ridisegnare con chi ha fatto il foglio (#384 B5). Un colpo nuovo
# fuori zona fa fallire il test; quando uno di questi viene sistemato, lo si toglie da qui
const KNOWN_OFF := {}
const UP := ["lightUp", "heavyUp"]
const TIP_TOLERANCE := 12.0 # pixel di mondo tra la punta del disegno e il bordo della zona (tools/sprite/zone_dei_colpi.py)
const MIN_RUN := 3 # pixel opachi in una colonna o riga perché conti come punta, non un capello


# La punta del colpo nella zona, in pixel del PNG: la riga più alta per i colpi in su, sennò la colonna più avanti.
# -1 se nella fascia della zona non c'è niente
func _tip(img: Image, zone: Rect2i, up: bool) -> int:
	var outer := img.get_height() if up else img.get_width()
	var inner_from := zone.position.x if up else zone.position.y
	var inner_to := zone.end.x if up else zone.end.y
	for i in outer:
		var line := i if up else outer - 1 - i
		var n := 0
		for j in range(maxi(0, inner_from), mini(inner_to, img.get_width() if up else img.get_height())):
			n += int(_solid(img, j, line) if up else _solid(img, line, j))
		if n >= MIN_RUN:
			return line
	return -1


func _game() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))


# Tutti i disegni a cartella: [nome per i messaggi, id del personaggio, sprite]
func _looks(game: Dictionary) -> Array:
	var out := []
	for id in game.characters:
		var c: Dictionary = game.characters[id]
		if c.get("sprite") is Dictionary and c.sprite.has("dir"):
			out.append([id, id, c.sprite])
		var skins: Variant = c.get("skins")
		if skins is Dictionary:
			for skin in skins:
				out.append(["%s/%s" % [id, skin], id, skins[skin].sprite])
	return out


func _frame(sprite: Dictionary, state: String, index: int) -> Image:
	var a: Dictionary = sprite.animations[state]
	var tex: Texture2D = load("res://data/%s/%s.png" % [sprite.dir, a.src])
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var fw := int(sprite.frameWidth)
	return img.get_region(Rect2i(index * fw, 0, fw, int(sprite.frameHeight)))


func _solid(img: Image, x: int, y: int) -> bool:
	return img.get_pixel(x, y).a > 0.5


func test_la_sagoma_cambia_subito() -> void:
	var game := _game()
	for look in _looks(game):
		var sprite: Dictionary = look[2]
		var idle := _frame(sprite, "idle", 0)
		for state in ACTIONS:
			var a: Variant = sprite.animations.get(state)
			if a == null or a.src != state:
				continue # usa il disegno di un altro stato: si controlla lì
			var shown := FighterPose.sprite_frame(a, 0.0, FighterPose.attack_spec(game, look[1], state))
			var img := _frame(sprite, state, shown)
			var solid := 0
			var changed := 0
			for y in range(0, idle.get_height(), STEP):
				for x in range(0, idle.get_width(), STEP):
					var was := _solid(idle, x, y)
					solid += int(was)
					changed += int(was != _solid(img, x, y))
			var k := float(changed) / maxf(1.0, solid)
			runner.check(k >= MIN_CHANGE, "%s, %s: il fotogramma %d è quasi uguale al fermo (cambia il %d%%)" % [look[0], state, shown, roundi(k * 100)])


func test_il_colpo_arriva_nella_zona() -> void:
	var game := _game()
	var fw: float = game.fighter.width
	var fh: float = game.fighter.height
	for look in _looks(game):
		var sprite: Dictionary = look[2]
		var scale := float(sprite.get("scale", 1.0))
		var foot := float(sprite.get("footY", sprite.frameHeight))
		for state in STRIKES:
			var a: Variant = sprite.animations.get(state)
			if a == null or a.src != state or state in KNOWN_OFF.get(look[1], []):
				continue
			var spec := FighterPose.attack_spec(game, look[1], state)
			if spec.is_empty():
				continue
			# Il fotogramma d'impatto, o l'unica posa di chi ne ha una sola; con activeEnd (#506) tutti quelli mostrati
			# mentre il colpo prende: conta il più lontano, come in tools/sprite/zone_dei_colpi.py
			var hit := int(a.get("hitFrame", int(a.frames) - 1))
			var last := int(a.get("activeEnd", hit))
			var img := _frame(sprite, state, hit)
			# La zona come attackBox() in attacks.ts, guardando a destra, rispetto ai piedi, in pixel del PNG
			var x0 := (float(spec.get("boxX", fw / 2.0))) / scale + float(sprite.frameWidth) / 2.0
			var y0 := float(spec.get("boxY", -fh * 0.7)) / scale + foot
			var zone := Rect2i(roundi(x0), roundi(y0), roundi(float(spec.range) / scale), roundi(float(spec.height) / scale))
			zone = zone.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
			var inside := 0
			for f in range(hit, last + 1):
				var shown := _frame(sprite, state, f)
				for y in range(zone.position.y, zone.end.y, 2):
					for x in range(zone.position.x, zone.end.x, 2):
						inside += int(_solid(shown, x, y))
			runner.check(inside >= 4, "%s, %s: nei fotogrammi %d-%d niente del disegno nella zona del colpo %s" % [look[0], state, hit, last, zone])
			if look[0] != look[1]:
				continue # le skin usano le zone del disegno base: cambiano solo l'aspetto
			# La zona intera, anche fuori dal fotogramma: il bordo è quello che la fisica usa
			var full := Rect2(x0, y0, float(spec.range) / scale, float(spec.height) / scale)
			var up: bool = state in UP
			var tip := _tip(img, Rect2i(full), up)
			for f in range(hit + 1, last + 1):
				var t := _tip(_frame(sprite, state, f), Rect2i(full), up)
				if t >= 0:
					tip = t if tip < 0 else (mini(tip, t) if up else maxi(tip, t))
			# di quanto la zona va oltre la punta, in pixel di mondo: poco oltre va bene, tanto è colpire nel vuoto
			var gap := (float(tip) - full.position.y if up else full.end.x - float(tip)) * scale
			runner.check(tip >= 0 and gap >= -TIP_TOLERANCE and gap <= 2 * TIP_TOLERANCE,
				"%s, %s: la zona finisce a %d pixel dalla punta del disegno (rilancia tools/sprite/zone_dei_colpi.py)" % [look[0], state, roundi(gap)])
