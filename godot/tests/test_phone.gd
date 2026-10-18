# Modalità telefono (Phone): sul cellulare tutto più grande, e la partita inquadrata come sul computer
extends RefCounted

var runner


func test_la_scelta_nelle_opzioni_vince() -> void:
	runner.check(Phone.wanted(Phone.PHONE), "Telefono la accende anche sul computer")
	runner.check(not Phone.wanted(Phone.COMPUTER), "Computer la spegne anche sul telefono")
	runner.check(Phone.wanted(Phone.AUTO) == Phone.is_mobile_device(), "Automatico guarda il dispositivo")
	runner.check(not Phone.is_mobile_device(), "i test girano su un computer")


func test_schermo_del_telefono_piu_piccolo() -> void:
	var w := Window.new()
	Phone.apply(w, Phone.PHONE)
	runner.check(Phone.active and w.content_scale_size.y == Phone.PHONE_HEIGHT, "alto %d" % w.content_scale_size.y)
	runner.check(w.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "si allarga fino ai bordi del telefono")
	Phone.apply(w, Phone.COMPUTER)
	runner.check(not Phone.active and w.content_scale_size == Phone.DESIGN, "sul computer resta 1280x720")
	w.free()


func test_la_partita_si_vede_uguale() -> void:
	runner.check(is_equal_approx(Phone.view_scale(Vector2(1280, 720), 720), 1.0), "sul computer niente cambia")
	var k := Phone.view_scale(Vector2(1040, 480), 720)
	runner.check(is_equal_approx(k, 480.0 / 720.0), "sul telefono il mondo si disegna più piccolo: %f" % k)
	runner.check(is_equal_approx(480 / k, 720.0), "e si vede alto 720 come sempre")
