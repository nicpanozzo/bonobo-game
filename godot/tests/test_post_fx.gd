# Luce e colori dell'arena (post_fx.gd): colori per arena, notte più blu, opzione per spegnerlo
extends RefCounted

var runner

const PostFx := preload("res://scripts/post_fx.gd")
const SunLight := preload("res://scripts/sun_light.gd")


func test_ogni_arena_ha_i_suoi_colori() -> void:
	var palco := PostFx.grade("palco", {})
	var fabbrica := PostFx.grade("fabbrica", {})
	runner.check(palco.gain.r > palco.gain.b and fabbrica.gain.b > fabbrica.gain.r, "il palco è caldo, la fabbrica fredda")
	var other := PostFx.grade("corsa-sconosciuta", {})
	runner.check(other.bloom == PostFx.BASE.bloom, "un'arena senza colori suoi prende quelli di base")


func test_di_notte_i_colori_vanno_verso_il_blu() -> void:
	var day := PostFx.grade("padova", SunLight.light(0.0))
	var night := PostFx.grade("padova", SunLight.light(0.5))
	runner.check(day.gain == PostFx.GRADES.padova.gain, "di giorno restano quelli dell'arena")
	runner.check(night.gain.b > day.gain.b and night.gain.r < day.gain.r and night.bloom > day.bloom, "di notte più blu e le luci brillano")
	var dusk := PostFx.grade("padova", SunLight.light(0.25))
	runner.check(is_equal_approx(dusk.gain.b, day.gain.b), "al tramonto non scatta")
	runner.check(PostFx.GRADES.padova.gain == Color(1.03, 1.0, 0.95), "la tabella non cambia")


func test_si_spegne() -> void:
	var post := PostFx.new()
	post._ready()
	runner.check(post._rect.visible, "acceso di default")
	post.enabled = false
	runner.check(not post._rect.visible, "spento dalle opzioni")
	post.free()
