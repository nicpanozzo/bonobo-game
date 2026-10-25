# Polvere presa dalla superficie (terrain_fx.gd) e accento del lottatore (fighter_fx.gd)
extends RefCounted

var runner

const ParticleFx := preload("res://scripts/particle_fx.gd")
const TerrainFx := preload("res://scripts/terrain_fx.gd")
const FighterFx := preload("res://scripts/fighter_fx.gd")

const PADOVA := {"id": "padova", "solids": [{"x": 100, "y": 520, "width": 1720}], "platforms": [{"x": 600, "y": 410, "width": 180}],
	"art": {"solidSkin": "pietra", "platformSkin": "lastra", "pieces": {"solids": ["fianco"]}}}
const BOLOGNA := {"id": "bologna", "solids": [{"x": 100, "y": 2000, "width": 2000}], "platforms": [{"x": 100, "y": 1880, "width": 180}, {"x": 100, "y": 1760, "width": 180}],
	"art": {"solidSkin": "base", "platformSkin": "legno", "pieces": {"solids": ["piazza"], "platforms": ["portico", "coppi"]}}}


# Il materiale viene dalla skin del pezzo sotto ai piedi, o dall'arena se è a tinta unita
func test_materiale_dalla_superficie() -> void:
	runner.check(TerrainFx.material_at(PADOVA, 500, 520) == "stone", "Padova: la piazza è pietra")
	runner.check(TerrainFx.material_at(BOLOGNA, 150, 1760) == "brick", "Bologna: il tetto dei portici è di coppi")
	runner.check(TerrainFx.material_at(BOLOGNA, 150, 1880) == "stone", "Bologna: il passaggio dei portici è di pietra")
	var isole := {"id": "isole", "solids": [{"x": 0, "y": 500, "width": 400}], "platforms": [{"x": 500, "y": 300, "width": 200}]}
	runner.check(TerrainFx.material_at(isole, 100, 500) == "grass", "Isole: l'isola è d'erba")
	runner.check(TerrainFx.material_at(isole, 600, 300) == "dust", "Isole: la piattaforma resta polvere")
	runner.check(TerrainFx.material_at({"id": "casuale-12"}, 0, 0) == "dust", "un'arena senza materiale resta come prima")


# La polvere prende il colore del materiale; il legno ne fa meno; sulla polvere di sempre non cambia nulla
func test_ricolora_la_polvere() -> void:
	var base := ParticleFx.dust_burst(7, 0, 0)
	runner.check(TerrainFx.restyle(base.duplicate(true), "dust").size() == base.size(), "polvere: tutto com'era")
	var stone := TerrainFx.restyle(base.duplicate(true), "stone")
	var tinted := stone.filter(func(p): return p.get("ramp") == ["tint"])
	runner.check(not tinted.is_empty() and tinted[0].tint == TerrainFx.MATERIALS.stone.tint, "pietra: polvere grigia")
	var dusty := func(l: Array) -> int: return l.filter(func(p): return p.get("kind", "tex") == "tex").size()
	runner.check(dusty.call(TerrainFx.restyle(base.duplicate(true), "wood")) < dusty.call(stone), "il legno fa meno polvere della pietra")
	runner.check(not TerrainFx.extra("grass", 1, 0, 0).is_empty(), "l'erba lancia fili d'erba")
	runner.check(TerrainFx.extra("stone", 1, 0, 0).is_empty(), "la pietra non ha dettagli in più")


# Solo i tre lottatori con uno stile hanno l'accento; il doppio salto ha l'anello del loro colore
func test_accento_del_lottatore() -> void:
	runner.check(FighterFx.style_of("bradipo") == "", "Bradipo resta con gli effetti di tutti")
	for id in ["marcomunista", "egiainuso", "orsoblu"]:
		var style := FighterFx.style_of(id)
		runner.check(not FighterFx.ground(style, 3, 0, 0).is_empty(), "%s: accento a terra" % id)
		runner.check(not FighterFx.air_jump(style, 3, 0, 0).is_empty(), "%s: doppio salto" % id)
		runner.check(not FighterFx.air_jump_marks(style, 0, 0, 380.0).is_empty(), "%s: anello del doppio salto" % id)
	runner.check(FighterFx.ground("", 3, 0, 0).is_empty(), "senza stile niente accento")


# I quadratini di Egiainuso stanno sulla griglia di 4 px e spariscono a fine vita
func test_pixel_sulla_griglia() -> void:
	var p: Dictionary = FighterFx.ground("glitch", 5, 13, 21)[0]
	var at := FighterFx.pixel_at(p, 0.1)
	runner.check(fmod(at.x, 4.0) == 0.0 and fmod(at.y, 4.0) == 0.0, "a scatti di 4 px (%s)" % at)
	runner.check(FighterFx.pixel_visible(p, 0.01), "appena nato si vede")
	runner.check(not FighterFx.pixel_visible(p, float(p.life)), "a fine vita sparisce")
