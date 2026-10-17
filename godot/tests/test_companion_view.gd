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
