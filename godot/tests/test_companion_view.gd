# Test del disegno del compagno (#369), il beagle di Lampione
extends RefCounted

var runner


func test_segue_lo_snapshot_e_sparisce_senza_compagno() -> void:
	var view: RefCounted = preload("res://scripts/companion_view.gd").new()
	view.on_snapshot([{"id": "a", "companion": {"x": 100, "y": 500, "facing": 1, "onGround": true}}, {"id": "b"}])
	view.advance()
	runner.check(view.position_of("a") == Vector2(100, 500), "parte dove dice lo snapshot")
	runner.check(view.position_of("b") == null, "chi non ha compagno non ne ha")
	view.on_snapshot([{"id": "a", "companion": {"x": 140, "y": 500, "facing": 1, "onGround": true}}])
	view.advance()
	var x: float = view.position_of("a").x
	runner.check(x > 100 and x < 140, "tra due snapshot va verso il nuovo posto, senza scatti")
	view.on_snapshot([{"id": "a"}])
	view.advance()
	runner.check(view.position_of("a") == null, "senza compagno nello snapshot non si disegna")


func test_morde_solo_negli_attacchi_del_compagno() -> void:
	var View := preload("res://scripts/companion_view.gd")
	var characters := {"lampione": {"companion": {"bites": ["light", "heavy"]}}, "default": {}}
	runner.check(View.biting({"characterId": "lampione", "attack": "light"}, characters), "il leggero lo fa il beagle")
	runner.check(not View.biting({"characterId": "lampione", "attack": "lightAir"}, characters), "in aria no")
	runner.check(not View.biting({"characterId": "lampione", "attack": null}, characters), "senza attacco no")
	runner.check(not View.biting({"characterId": "default", "attack": "light"}, characters), "senza compagno no")


func test_lampeggia_se_colpito_e_fa_la_nuvoletta_al_ko() -> void:
	var view: RefCounted = preload("res://scripts/companion_view.gd").new()
	view.on_snapshot([{"id": "a", "companion": {"x": 100, "y": 500, "facing": 1, "onGround": true, "percent": 0}}], {}, 0)
	view.advance()
	view.on_snapshot([{"id": "a", "companion": {"x": 100, "y": 500, "facing": 1, "onGround": true, "percent": 8}}], {}, 50)
	view.advance()
	runner.check(view.poof_count() == 0, "colpito ma ancora in gioco")
	view.on_snapshot([{"id": "a"}], {}, 100)
	runner.check(view.poof_count() == 1, "sparito col padrone in gioco: KO")
	view.on_snapshot([{"id": "a", "respawning": true}], {}, 150)
	runner.check(view.poof_count() == 1, "chi esce dall'arena non fa altre nuvolette")
