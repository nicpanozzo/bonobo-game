# Suprema di Bonobot (#102): dove cade l'orsogufo, da che parte scappa lo gnomo, chi non lampeggia
extends RefCounted

var runner

const SupremeView := preload("res://scripts/supreme_view.gd")
const STAGE := {
	"solids": [{"x": 240, "y": 560, "width": 800, "height": 200}],
	"platforms": [{"x": 400, "y": 420, "width": 160}],
}


func _game() -> Dictionary:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func test_l_ombra_va_sul_terreno_sotto() -> void:
	runner.check(SupremeView.ground_y(STAGE, 600, 560) == 560, "a terra: il blocco")
	runner.check(SupremeView.ground_y(STAGE, 480, 300) == 420, "in aria sopra la piattaforma: la piattaforma")
	runner.check(SupremeView.ground_y(STAGE, 700, 300) == 560, "in aria sopra il blocco: il blocco")
	runner.check(SupremeView.ground_y(STAGE, 100, 300) == 300, "sopra il vuoto: dove si è")


func test_lo_gnomo_scappa_verso_il_bordo_piu_vicino() -> void:
	runner.check(SupremeView.escape_dir(STAGE, 300) == -1, "vicino al bordo sinistro")
	runner.check(SupremeView.escape_dir(STAGE, 1000) == 1, "vicino al bordo destro")


func test_bonobot_ha_omar_e_non_lampeggia_finche_dura() -> void:
	var game := _game()
	var sv := SupremeView.new()
	sv.game = game
	sv.stage = STAGE
	sv.fixed_now = 1000.0
	sv.start({"id": "b", "x": 600.0, "y": 560.0}, game.characters.bonobot)
	sv.start({"id": "d", "x": 600.0, "y": 560.0}, game.characters["default"]) # senza suprema propria: niente scena
	runner.check(sv.origin("b") == Vector2(600.0 + float(game.characters.bonobot.supreme.leapDx), 560.0), "la liana un po' davanti")
	var sp: Dictionary = game.characters.bonobot.supreme
	var total := float(sp.leapMs) + float(sp.pullMs) + float(sp.warnMs) + float(sp.impactMs) + float(sp.recoverMs)
	runner.check(sv.holds("b", 1000.0 + total - 10), "appeso fino alla fine")
	runner.check(not sv.holds("b", 1000.0 + total + 10), "dopo lampeggia di nuovo, se è ancora invulnerabile")
	runner.check(not sv.holds("d", 1000.0), "chi usa la suprema di base non ha la scena")
	sv.free()


func test_numeri_della_suprema_per_personaggio() -> void:
	var game := _game()
	var WorldView := load("res://scripts/world_view.gd")
	var own: Dictionary = WorldView.attack_spec(game, "bonobot", "supreme")
	runner.check(own.get("outward", false) == true, "Bonobot: Omar, ad area")
	var base: Dictionary = WorldView.attack_spec(game, "default", "supreme")
	runner.check(base == game.attacks.supreme, "gli altri: la suprema di base")
