# Pesanti e cavalcature (ride_view.gd): dove stanno in mano, quando la predizione si spegne, effetti e disegno
extends RefCounted

const RideView := preload("res://scripts/ride_view.gd")

var runner


func test_pesanti_sopra_la_testa_mezzi_sotto_i_piedi() -> void:
	var feet := Vector2(500, 600)
	var hand := Vector2(522, 548)
	runner.check(RideView.held_pos("cassa", feet, 96.0, hand).y < feet.y - 96.0, "la cassa sopra la testa")
	runner.check(RideView.held_pos("monopattino", feet, 96.0, hand).y >= feet.y, "il monopattino sotto i piedi")
	runner.check(RideView.held_pos("banana", feet, 96.0, hand) == hand, "gli altri in mano come prima")


func test_chi_cavalca_lo_decide_il_server() -> void:
	var items := [{"id": 1, "kind": "carrello", "heldBy": "p0"}, {"id": 2, "kind": "banana", "heldBy": "p1"}]
	runner.check(RideView.carrying(items, "p0"), "nel carrello niente predizione")
	runner.check(not RideView.carrying(items, "p1"), "con la banana sì")
	runner.check(not RideView.carrying(items, "p2"), "a mani vuote sì")


func test_gli_eventi_fanno_effetto_e_poi_spariscono() -> void:
	var v = RideView.new()
	var shake: float = v.on_event({"type": "gear", "phase": "break", "kind": "cassaOro", "id": "p0", "x": 400, "y": 600})
	runner.check(shake > 0.0 and v.shards.size() > 0, "la cassa rotta fa schegge e trema")
	v.on_event({"type": "gear", "phase": "launch", "kind": "carrello", "id": "p0", "x": 400, "y": 600})
	runner.check(v.puffs.size() > 0, "la catapulta fa uno sbuffo")
	runner.check(v.on_event({"type": "gear", "phase": "fuse", "kind": "petardo", "id": "p0", "x": 0, "y": 0}) == 0.0, "le fasi degli altri oggetti non sono sue")
	for k in 60:
		v.step(16.0)
	runner.check(v.shards.is_empty() and v.puffs.is_empty(), "dopo un secondo non resta niente")


func test_sa_disegnare_i_suoi_oggetti() -> void:
	for kind in RideView.KINDS:
		runner.check(RideView.draws(kind), "%s si disegna" % kind)
	runner.check(not RideView.draws("banana"), "la banana no")
