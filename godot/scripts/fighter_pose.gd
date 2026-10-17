# Come appare un lottatore dai soli campi dello snapshot: animazione, fotogramma, colori della variante,
# scudo, aure. Funzioni pure, senza disegno: le usano world_view.gd, hud.gd e i test.
extends RefCounted

const VARIANT_HUES := [0.5, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875] # spostamento della tinta per la variante 1, 2, ...


const SLOT_OF_KIND := {"specialNeutral": "neutral", "specialSide": "side", "specialDown": "down"}


# La skin di un giocatore dallo snapshot (#339), "" per l'aspetto base
static func skin_of(p: Dictionary) -> String:
	var skin: Variant = p.get("skinId")
	return str(skin) if skin != null else ""


# Il disegno di un lottatore (#339): il suo, o quello della skin se ce l'ha. Con la skin l'id diventa
# "<lottatore>/<skin>", così le texture delle due versioni non si mescolano; il resto (mosse, suprema) è il suo
static func look(game_data: Dictionary, character_id: String, skin_id: String) -> Dictionary:
	var c: Dictionary = game_data.characters.get(character_id, game_data.characters.get(game_data.get("defaultCharacterId", ""), {}))
	var skins: Dictionary = c.get("skins", {})
	if skin_id == "" or not skins.has(skin_id):
		return c
	var out := c.duplicate()
	out.id = "%s/%s" % [c.id, skin_id]
	out.sprite = skins[skin_id].sprite
	out.portrait = skins[skin_id].get("portrait")
	return out


# Chi ha lo stesso personaggio di un altro giocatore prende una variante di colore: il primo in ordine
# di colore resta originale, gli altri 1, 2, ... Il colore lo dà il server, così ogni client vede lo stesso.
# Anche gli eliminati contano: chi resta non cambia colore a metà partita
static func variant_ranks(players: Array) -> Dictionary:
	var by_character := {}
	for p in players:
		if p == null:
			continue
		var id: String = str(p.get("characterId", ""))
		if not by_character.has(id):
			by_character[id] = []
		by_character[id].append(p)
	var ranks := {}
	for id in by_character:
		var same: Array = by_character[id]
		same.sort_custom(func(a, b): return int(a.color) < int(b.color) or (int(a.color) == int(b.color) and str(a.id) < str(b.id)))
		for i in same.size():
			ranks[same[i].id] = i
	return ranks


# Il modulate dello sprite: con una variante il rosso oltre 1 dice allo shader di quanto spostare la tinta,
# con flash (da 0 a 1) il verde oltre 1 gli dice di quanto schiarirlo verso il bianco
static func sprite_modulate(variant: int, alpha: float, flash := 0.0) -> Color:
	var g := 2.0 + clampf(flash, 0.0, 1.0) if flash > 0.0 else 1.0
	if variant <= 0:
		return Color(1, g, 1, alpha)
	return Color(2.0 + VARIANT_HUES[(variant - 1) % VARIANT_HUES.size()], g, 1, alpha)


# Il colpo caricato (SMASH_CHARGE): il pesante a terra tenuto, cioè un attacco in corso con la carica sopra zero.
# La carica della speciale (E10) invece arriva senza attacco
static func smash_charging(p: Dictionary) -> bool:
	return p.get("attack") != null and float(p.get("charge", 0.0)) > 0.0


# Quanto lampeggia lo sprite di chi carica, come in Smash: più veloce e più forte man mano che si carica.
# Con meno lampi (accessibilità) resta un bagliore fermo
static func charge_flash(p: Dictionary, now: float, calm: bool) -> float:
	if not smash_charging(p):
		return 0.0
	var charge := clampf(float(p.charge), 0.0, 1.0)
	if calm:
		return 0.2 + 0.2 * charge
	var hz := 4.0 + 8.0 * charge
	return (0.5 + 0.5 * sin(now / 1000.0 * TAU * hz)) * (0.25 + 0.5 * charge)


# I numeri di un attacco per un personaggio, come attackSpecFor() in src/shared/physics/attacks.ts:
# quelli di ATTACKS con i ritocchi del personaggio (il recupero). {} se l'attacco non esiste
static func attack_spec(game_data: Dictionary, character_id: String, kind: String) -> Dictionary:
	if kind == "supreme": # la suprema (#101, #102): quella del personaggio, o quella di base
		var c: Dictionary = game_data.characters.get(character_id, {})
		var own: Variant = c.get("supremeAttack")
		return own if own is Dictionary else game_data.attacks.get("supreme", {})
	if kind.begins_with("special"): # le speciali (E10) sono del personaggio
		var c: Dictionary = game_data.characters.get(character_id, game_data.characters.get(game_data.get("defaultCharacterId", ""), {}))
		return c.get("specialAttacks", {}).get(kind, {})
	var spec: Dictionary = game_data.attacks.get(kind, {})
	if kind != "recovery" or spec.is_empty():
		return spec
	var character: Dictionary = game_data.characters.get(character_id, {})
	var own: Variant = character.get("recovery")
	return spec.merged(own, true) if own is Dictionary else spec


# Il personaggio ha il disegno di questo stato, non quello del ripiego
static func has_own(animations: Dictionary, name: String) -> bool:
	return animations.has(name) and str(animations[name].get("src", name)) == name


# Il fotogramma da mostrare dopo elapsed_ms. Negli attacchi con hitFrame il fotogramma d'impatto cade quando
# la hitbox si accende (startupMs) e l'animazione finisce con cooldownMs; senza, si va a fps.
static func sprite_frame(a: Dictionary, elapsed_ms: float, attack: Dictionary = {}) -> int:
	var frames := int(a.frames)
	if attack.is_empty() or not a.has("hitFrame"):
		var f := int(elapsed_ms / 1000.0 * float(a.fps))
		return f % frames if a.loop else mini(f, frames - 1)
	var hit := int(a.hitFrame)
	var startup: float = attack.startupMs
	if elapsed_ms < startup:
		return int(elapsed_ms / startup * hit)
	var rest := maxf(1.0, animation_ms(a, attack) - startup)
	return mini(hit + int((elapsed_ms - startup) / rest * (frames - hit)), frames - 1)


# Quanto dura un giro dell'animazione, in ms
static func animation_ms(a: Dictionary, attack: Dictionary = {}) -> float:
	if not attack.is_empty() and a.has("hitFrame"):
		return maxf(float(attack.cooldownMs), float(attack.startupMs) + float(attack.activeMs))
	return float(a.frames) / float(a.fps) * 1000.0


# Chi ha perso la rete (#107) si vede semitrasparente finché rientra o il suo posto scade
static func away_alpha(p: Dictionary) -> float:
	return 0.4 if p.get("away", false) else 1.0


# Quale animazione mostrare, dai soli campi dello snapshot (animationFor in fighters.ts)
static func animation_for(p: Dictionary, holding := false) -> String:
	if p.hitstun or p.get("stunned", false): # lo stordito dopo lo scudo rotto (#109) ha la posa di chi è colpito
		return "hit"
	if p.get("grabbedBy") != null:
		return "grabbed" # tenuto con la presa (#109); senza disegno, la posa di chi è colpito
	if holding:
		return "grab" # chi tiene resta nella posa della presa
	if p.attack != null and str(p.attack).begins_with("throw"):
		return "throw" # i quattro lanci; senza disegno, la posa della presa
	if p.attack != null and str(p.attack).begins_with("special"):
		# le speciali (E10): specialNeutral, specialSide o specialDown (#257); senza disegno "special", poi il pesante
		return str(p.attack)
	if p.attack != null:
		# Lo stato del colpo preciso (lightUp, heavyAir, recovery...): chi non l'ha disegnato mostra il ripiego.
		# L'attacco dal bordo (#110) non ha uno stato suo: usa il colpo leggero
		return "light" if p.attack == "ledgeAttack" else str(p.attack)
	var ledge := str(p.get("ledge", ""))
	if ledge == "hang":
		return "ledge" # appeso al bordo (#110)
	if ledge == "climb":
		return "climb"
	if ledge == "roll":
		return "walk"
	if p.get("shielding", false):
		return "shield" # scudo (#109): chi non l'ha disegnato resta fermo, dentro la bolla
	if not p.onGround:
		return "jump" if p.vy < 0 else "fall"
	if p.get("dashing", false):
		return "dash" # scatto e corsa (#199); senza disegno, la camminata
	if absf(p.vx) > 20:
		return "walk"
	return "idle"


# Raggio della bolla: copre il lottatore con lo scudo pieno, a vuoto ne resta un terzo
static func shield_radius(hp: float, max_hp: float, fighter_height: float) -> float:
	var full := fighter_height * 0.62
	return lerpf(full / 3.0, full, clampf(hp / max_hp, 0.0, 1.0))


# Velocità delle schegge della bolla rotta: a raggiera, un po' più verso l'alto
static func shard_velocities(n: int) -> Array:
	var out := []
	for i in n:
		var a := TAU * i / float(n)
		out.append(Vector2(cos(a), sin(a) - 0.5) * 320.0)
	return out


# Alone della carica (E10): cresce con la carica, da giallo ad arancione
static func charge_radius(fighter_height: float, charge: float) -> float:
	return fighter_height * (0.45 + 0.35 * clampf(charge, 0.0, 1.0))


# Il colore del proiettile: quello della speciale del personaggio, poi quello del personaggio base
static func projectile_color(game_data: Dictionary, character_id: String, kind: String) -> Color:
	var slot: String = SLOT_OF_KIND.get(kind, "neutral")
	for id in [character_id, str(game_data.get("defaultCharacterId", ""))]:
		var c: Dictionary = game_data.characters.get(id, {})
		var sp: Dictionary = c.get("specials", {}).get(slot, {})
		if sp.has("color"):
			return Color.hex((int(sp.color) << 8) | 0xff)
	return Color(1, 0.85, 0.3)


# Potenziati dal fiore (#231): quanto si vede l'alone. Pieno e lento che respira; negli ultimi secondi
# lampeggia per avvisare che sta finendo
static func aura_alpha(ms_left: float, now_ms: float, ending_ms: float) -> float:
	if ms_left <= 0.0:
		return 0.0
	if ms_left < ending_ms and int(now_ms / 120.0) % 2 == 0:
		return 0.15
	return 0.45 + 0.12 * sin(now_ms / 420.0)


# Quanto è fatto il proprio lottatore (#302): da 0,25 appena fumato a 1 prima di crollare; 0 se non lo è
static func high_level(p: Variant, high_ms: float) -> float:
	if p is Dictionary and p.get("powerup") == "trip":
		return 0.45 # i funghetti (#302): un viaggio leggero, sempre uguale
	if not (p is Dictionary) or p.get("powerup") != "bong":
		return 0.0
	return 0.25 + 0.75 * clampf(1.0 - float(p.get("powerupMs", 0)) / high_ms, 0.0, 1.0)
