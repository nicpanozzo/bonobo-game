# Il pubblico di Bologna (#433): i flash dei turisti ai KO e ai colpi forti, dai punti di art.life.crowd
extends RefCounted

var runner

const StageCrowd := preload("res://scripts/stage_crowd.gd")


func test_flash_per_evento() -> void:
	runner.check(StageCrowd.flashes_for({"type": "ko"}, 900.0) == StageCrowd.KO_FLASHES, "un KO, tanti flash")
	runner.check(StageCrowd.flashes_for({"type": "hit", "knockback": 1200}, 900.0) == StageCrowd.HIT_FLASHES, "un colpo forte, un paio")
	runner.check(StageCrowd.flashes_for({"type": "hit", "knockback": 300}, 900.0) == 0, "un colpo leggero, niente")
	runner.check(StageCrowd.flashes_for({"type": "jump"}, 900.0) == 0, "il resto niente")


func test_i_punti_di_bologna() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var crowd: RefCounted = StageCrowd.new()
	crowd.setup(game.stages.bologna)
	runner.check(not crowd.is_empty(), "Bologna ha il pubblico")
	var none: RefCounted = StageCrowd.new()
	none.setup({"id": "x"})
	runner.check(none.is_empty(), "un'arena senza art non ce l'ha")
	none.flash(5, 0.0)
	crowd.flash(StageCrowd.MAX_FLASHES + 10, 0.0)
	runner.check(crowd._flashes.size() == StageCrowd.MAX_FLASHES, "al massimo MAX_FLASHES alla volta")
