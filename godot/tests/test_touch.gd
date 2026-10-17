# Comandi touch (E18): levetta e tasti a schermo diventano gli stessi tasti di tastiera e pad
extends RefCounted

var runner


func _touch(index: int, pos: Vector2, down := true) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = down
	return e


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func test_la_levetta_parte_dove_si_appoggia_il_pollice() -> void:
	var t := TouchControls.new()
	runner.check(t.handle(_touch(0, Vector2(300, 500))), "un tocco a sinistra prende la levetta")
	runner.check(t.active, "dopo un tocco i comandi touch sono attivi")
	runner.check(not t.pressed("left") and not t.pressed("right"), "appena appoggiato non si va da nessuna parte")
	t.handle(_drag(0, Vector2(380, 510)))
	runner.check(t.pressed("right") and not t.pressed("down"), "spostato a destra: destra, non giù")
	t.handle(_drag(0, Vector2(300, 600)))
	runner.check(t.pressed("down") and not t.pressed("right"), "spostato in basso: giù")
	t.handle(_drag(0, Vector2(150, 380)))
	runner.check(t.pressed("left") and t.pressed("up"), "in alto a sinistra: sinistra e su")
	t.handle(_touch(0, Vector2(150, 380), false))
	runner.check(not t.pressed("left") and not t.pressed("up"), "alzato il pollice si torna fermi")
	t.free()


func test_tasti_insieme_alla_levetta() -> void:
	var t := TouchControls.new()
	var jump: Vector2 = TouchControls.BUTTONS.jump.pos
	var light: Vector2 = TouchControls.BUTTONS.light.pos
	t.handle(_touch(0, Vector2(200, 550)))
	t.handle(_drag(0, Vector2(290, 550)))
	t.handle(_touch(1, jump))
	runner.check(t.pressed("right") and t.pressed("jump"), "si corre e si salta con due dita")
	t.handle(_drag(1, light))
	runner.check(t.pressed("light") and not t.pressed("jump"), "scivolando sul leggero si passa a quello")
	t.handle(_touch(1, light, false))
	runner.check(not t.pressed("light") and t.pressed("right"), "alzato un dito, l'altro resta")
	t.free()


func test_pausa_e_tocco_libero() -> void:
	var t := TouchControls.new()
	var paused := [false]
	var tapped := [false]
	t.pause_pressed.connect(func(): paused[0] = true)
	t.free_tap.connect(func(): tapped[0] = true)
	t.handle(_touch(0, TouchControls.PAUSE.pos))
	runner.check(paused[0], "il tasto in alto mette in pausa")
	runner.check(not t.handle(_touch(1, Vector2(800, 200))), "un tocco nel vuoto a destra non è un comando")
	runner.check(tapped[0], "ma chiede la rivincita a partita finita")
	t.free()


func test_tastiera_o_pad_spengono_il_touch() -> void:
	var t := TouchControls.new()
	t.handle(_touch(0, TouchControls.BUTTONS.heavy.pos))
	runner.check(t.pressed("heavy"), "pesante premuto")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_J
	t.handle(key)
	runner.check(not t.active and not t.pressed("heavy"), "un tasto della tastiera spegne i comandi touch")
	t.free()


# E18 passo 2
func test_tasto_in_piu_per_il_pannello() -> void:
	var t := TouchControls.new()
	var got := [""]
	t.extra_pressed.connect(func(n: String): got[0] = n)
	t.extras = {"panel": "Pannello"}
	runner.check(t.handle(_touch(0, TouchControls.extra_rect(0).get_center())), "il tasto in più prende il tocco")
	runner.check(got[0] == "panel", "e dice quale: %s" % got[0])
	t.extras = {}
	got[0] = ""
	t.handle(_touch(1, TouchControls.extra_rect(0).get_center()))
	runner.check(got[0] == "", "tolto, non c'è più")
	t.free()


func test_telefono_in_verticale() -> void:
	runner.check(TouchControls.portrait(Vector2(390, 844)), "390x844 è in verticale")
	runner.check(not TouchControls.portrait(Vector2(844, 390)), "844x390 è in orizzontale")


# E18 passo 3
func test_mancini_e_tasti_grandi() -> void:
	var t := TouchControls.new()
	t.configure({"size": 2, "opacity": 1, "left_handed": true})
	var jump := t.button_pos("jump")
	runner.check(jump.x < 640.0, "per i mancini il salto è a sinistra: %s" % [jump])
	runner.check(t.handle(_touch(0, jump)) and t.pressed("jump"), "e si preme lì")
	runner.check(t.handle(_touch(1, Vector2(1000, 550))), "la levetta è a destra")
	t.handle(_drag(1, Vector2(900, 550)))
	runner.check(t.pressed("left"), "e va a sinistra")
	var normal := TouchControls.new()
	runner.check(not normal.handle(_touch(0, jump)) or not normal.pressed("jump"), "senza opzioni il salto non è a sinistra")
	t.free()
	normal.free()


func test_levetta_in_fondo_corre() -> void:
	var t := TouchControls.new()
	t.handle(_touch(0, Vector2(300, 500)))
	t.handle(_drag(0, Vector2(380, 500)))
	runner.check(t.pressed("right") and not t.pressed("run"), "piegata a metà si cammina")
	t.handle(_drag(0, Vector2(500, 500)))
	runner.check(t.pressed("right") and t.pressed("run"), "piegata fino in fondo si corre")
	t.handle(_drag(0, Vector2(150, 500)))
	runner.check(t.pressed("left") and t.pressed("run"), "anche a sinistra")
	runner.check(TouchControls.hint("run") == "levetta tutta di lato", TouchControls.hint("run"))
	t.free()


func test_guide_col_touch() -> void:
	runner.check(TouchControls.hint("jump") == "tasto Salto", TouchControls.hint("jump"))
	runner.check(TouchControls.hint("up") == "levetta in su", TouchControls.hint("up"))
	runner.check(TouchControls.hint("taunt") != "", "la provocazione dice che non c'è")
