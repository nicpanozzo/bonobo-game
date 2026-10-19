# Controlli automatici sugli sprite dei lottatori (#384 C1 e C2), su tutti i personaggi e le skin:
# - C1: il primo fotogramma mostrato di ogni azione da tasto cambia già la sagoma rispetto al fermo;
# - C2: nel fotogramma d'impatto di ogni colpo qualcosa del disegno sta nella zona del colpo.
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
const KNOWN_OFF := {
	"bradipo": ["lightUp"], # la posa del foglio di Marco non alza il braccio sopra la testa
}


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
			# Il fotogramma d'impatto, o l'unica posa di chi ne ha una sola
			var hit := int(a.get("hitFrame", int(a.frames) - 1))
			var img := _frame(sprite, state, hit)
			# La zona come attackBox() in attacks.ts, guardando a destra, rispetto ai piedi, in pixel del PNG
			var x0 := (float(spec.get("boxX", fw / 2.0))) / scale + float(sprite.frameWidth) / 2.0
			var y0 := float(spec.get("boxY", -fh * 0.7)) / scale + foot
			var zone := Rect2i(roundi(x0), roundi(y0), roundi(float(spec.range) / scale), roundi(float(spec.height) / scale))
			zone = zone.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
			var inside := 0
			for y in range(zone.position.y, zone.end.y, 2):
				for x in range(zone.position.x, zone.end.x, 2):
					inside += int(_solid(img, x, y))
			runner.check(inside >= 4, "%s, %s: nel fotogramma %d niente del disegno nella zona del colpo %s" % [look[0], state, hit, zone])
