# La polvere a terra presa dalla superficie su cui si poggia (Nicola, 25 ottobre 2026): pietra, mattoni, legno, erba,
# metallo. Il materiale viene dalla skin del pezzo (art.solidSkin/platformSkin/pieces in stages.ts) o, se il pezzo è a
# tinta unita, da quello dell'arena. Ricolora la polvere e i sassolini di particle_fx.dust_burst e aggiunge il dettaglio
# del materiale (fili d'erba, schegge di legno, scintille). Solo disegno, funzioni pure come particle_fx.gd.

const ParticleFx := preload("res://scripts/particle_fx.gd")

# tint: colore della polvere (null = la polvere beige di sempre); grit: i tre colori dei sassolini;
# dust: quanta polvere resta (1 = tutta); extra: il dettaglio del materiale
const MATERIALS := {
	"dust": {"tint": null, "grit": [], "dust": 1.0, "extra": ""},
	"stone": {"tint": Color("d6d0c4"), "grit": [Color("c2bcb0"), Color("9a958b"), Color("75716a")], "dust": 0.9, "extra": ""},
	"brick": {"tint": Color("d99a7a"), "grit": [Color("c0593e"), Color("963f2c"), Color("dc8458")], "dust": 0.9, "extra": ""},
	"wood": {"tint": Color("e0cba8"), "grit": [Color("b0824f"), Color("865f37"), Color("cfa268")], "dust": 0.5, "extra": "splinters"},
	"grass": {"tint": Color("c3cf9f"), "grit": [Color("7a5c3c"), Color("5e472f"), Color("8c6a45")], "dust": 0.55, "extra": "blades"},
	"metal": {"tint": Color("c4c8d0"), "grit": [Color("8d939c"), Color("6b7079"), Color("a9aeb6")], "dust": 0.45, "extra": "sparks"},
}

# Il materiale delle skin delle arene disegnate (Padova, il palazzo, Bologna)
const SKIN_MATERIAL := {
	"pietra": "stone", "riva": "stone", "fianco": "stone", "lastra": "stone", "balcone": "stone",
	"piazza": "stone", "base": "stone", "davanzale": "stone", "portico": "stone",
	"legno": "wood", "coppi": "brick", "mattoni": "brick", "merlo": "brick",
}

# Le arene a tinta unita: [materiale dei solidi, materiale delle piattaforme]
const STAGE_MATERIAL := {
	"palco": ["wood", "wood"], "palestra": ["wood", "wood"], "musica": ["wood", "wood"],
	"isole": ["grass", "dust"], "fabbrica": ["metal", "metal"],
	"padova": ["stone", "stone"], "padova-palazzo": ["stone", "stone"], "bologna": ["stone", "wood"],
}

const BLADE := [Color("6fa83f"), Color("8cc04f"), Color("4f8a2f")]


# Il materiale sotto ai piedi in (x, y): il pezzo (solido o piattaforma) con il bordo alto lì, o quello dell'arena
static func material_at(stage: Dictionary, x: float, y: float) -> String:
	for kind in ["solids", "platforms"]:
		var list: Array = stage.get(kind, [])
		for i in list.size():
			var s: Dictionary = list[i]
			if absf(float(s.y) - y) <= 8.0 and x >= float(s.x) - 6.0 and x <= float(s.x) + float(s.width) + 6.0:
				return material_of(stage, kind, i)
	return material_of(stage, "solids", -1)


# Il materiale del pezzo i di kind ("solids" o "platforms"); i = -1 per quello di base dell'arena
static func material_of(stage: Dictionary, kind: String, i: int) -> String:
	var art: Dictionary = stage.get("art", {}) if stage.get("art") is Dictionary else {}
	var name: Variant = art.get("solidSkin" if kind == "solids" else "platformSkin")
	var pieces: Variant = art.get("pieces")
	if i >= 0 and pieces is Dictionary and pieces.get(kind) is Array and i < pieces[kind].size():
		name = pieces[kind][i]
	if name != null and SKIN_MATERIAL.has(name):
		return SKIN_MATERIAL[name]
	var by_stage: Array = STAGE_MATERIAL.get(str(stage.get("id", "")), [])
	if by_stage.is_empty():
		return "dust"
	return by_stage[0 if kind == "solids" else 1]


# Ricolora la polvere e i sassolini (dust_burst, brake_puff) col materiale; ne tiene una parte se il materiale fa poca
# polvere. Il fumo e l'aria restano com'erano
static func restyle(list: Array, material: String) -> Array:
	var m: Dictionary = MATERIALS.get(material, MATERIALS.dust)
	if material == "dust" or m.is_empty():
		return list
	var out: Array = []
	var n := 0
	for p in list:
		var kind: String = p.get("kind", "tex")
		if kind == "tex" and p.get("ramp") == ["dust"]:
			n += 1
			if fmod(n * 0.618, 1.0) >= float(m.dust): # tiene una frazione "dust", sparsa in modo uniforme
				continue
			if m.tint != null:
				p.ramp = ["tint"]
				p.tint = m.tint
		elif kind == "grit" and not (m.grit as Array).is_empty():
			p.col = m.grit[int(absf(float(p.vx))) % 3]
		out.append(p)
	return out


# Il dettaglio del materiale: fili d'erba, schegge di legno o scintille, più fitti con power
static func extra(material: String, key: int, x: float, y: float, power := 1.0) -> Array:
	var m: Dictionary = MATERIALS.get(material, {})
	var r := RandomNumberGenerator.new()
	r.seed = key * 7349 + 5
	var out: Array = []
	match str(m.get("extra", "")):
		"blades": # fili d'erba strappati che volteggiano e ricadono
			for i in roundi(5 * power):
				var sd := 1.0 if i % 2 == 1 else -1.0
				out.append({"kind": "grit", "x": x, "y": y, "oy": -2.0, "vx": sd * r.randf_range(20, 60), "vy": -r.randf_range(60, 120),
					"drag": 2.2, "gy": 220.0, "life": r.randf_range(0.5, 0.75), "s": r.randf_range(1.0, 1.4), "stretch": 3.2,
					"spin": sd * r.randf_range(5, 10), "col": BLADE[i % 3], "floor": y})
		"splinters": # schegge di legno lunghe e sottili
			for i in roundi(3 * power):
				var sd := 1.0 if i % 2 == 1 else -1.0
				out.append({"kind": "grit", "x": x, "y": y, "oy": -2.0, "vx": sd * r.randf_range(40, 90), "vy": -r.randf_range(70, 130),
					"drag": 1.0, "gy": 420.0, "life": r.randf_range(0.4, 0.6), "s": r.randf_range(0.9, 1.2), "stretch": 2.6,
					"spin": sd * r.randf_range(10, 16), "col": m.grit[i % 3], "floor": y})
		"sparks": # il metallo strisciato fa scintille basse
			for i in roundi(5 * power):
				var sd := 1.0 if i % 2 == 1 else -1.0
				out.append({"kind": "spark", "x": x, "y": y, "oy": -1.0, "vx": sd * r.randf_range(90, 200), "vy": -r.randf_range(40, 110),
					"drag": 3.0, "gy": 600.0, "life": r.randf_range(0.18, 0.32), "w": r.randf_range(0.8, 1.3),
					"col": Color("fff1b0") if i % 3 == 0 else Color("ffb04a")})
	return out
