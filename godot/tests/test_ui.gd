# Il design system (ui.gd): contrasto dei colori, pulsanti che non spostano il layout, numeri a cifre uguali
extends RefCounted

var runner


# Rapporto di contrasto WCAG tra due colori (1 = uguali, 21 = nero su bianco)
static func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a) + 0.05
	var lb := _luminance(b) + 0.05
	return maxf(la, lb) / minf(la, lb)


# Luminanza relativa WCAG: i canali sRGB riportati a lineari (get_luminance di Godot non lo fa)
static func _luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


func test_colori_leggibili() -> void:
	runner.check(_contrast(UI.TEXT, UI.CARD) >= 7.0, "testo sui pannelli: %.1f" % _contrast(UI.TEXT, UI.CARD))
	runner.check(_contrast(UI.TEXT, UI.GRAPE_HI) >= 4.5, "scritta dei pulsanti: %.1f" % _contrast(UI.TEXT, UI.GRAPE_HI))
	runner.check(_contrast(UI.INK, UI.PRIMARY) >= 7.0, "inchiostro sul giallo: %.1f" % _contrast(UI.INK, UI.PRIMARY))
	runner.check(_contrast(UI.WARN, UI.CARD) >= 4.5, "avvisi sui pannelli: %.1f" % _contrast(UI.WARN, UI.CARD))
	runner.check(_contrast(UI.LILAC, UI.CARD) >= 4.5, "titoletti sui pannelli: %.1f" % _contrast(UI.LILAC, UI.CARD))
	runner.check(_contrast(UI.FOCUS, UI.BG) >= 7.0, "il fuoco del pad si vede sul fondo")


func test_premuto_non_sposta_il_layout() -> void:
	var up := UI.button_box(UI.GRAPE_HI)
	var down := UI.button_box(UI.GRAPE_HI, true)
	runner.check(is_equal_approx(up.content_margin_top + up.content_margin_bottom, down.content_margin_top + down.content_margin_bottom), "stessa altezza del contenuto")
	runner.check(down.content_margin_top > up.content_margin_top, "premuto la scritta scende")
	runner.check(down.expand_margin_top < 0.0 and up.shadow_offset.y > down.shadow_offset.y, "premuto la lastra scende sull'ombra")


func test_numeri_a_cifre_uguali() -> void:
	var f := UI.numbers()
	var one := f.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var eight := f.get_string_size("8888", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	runner.check(is_equal_approx(one, eight), "la percentuale non balla: %.1f contro %.1f" % [one, eight])


func test_tema_con_fuoco_e_interruttori() -> void:
	var t := UI.theme()
	runner.check(t.get_stylebox("focus", "Button") is StyleBoxFlat, "fuoco dei pulsanti")
	var on: Texture2D = t.get_icon("checked", "CheckButton")
	runner.check(on != null and on.get_width() > on.get_height(), "interruttore disegnato: %s" % [on])
	runner.check(t.get_font("font", "Button") == UI.display(), "pulsanti nel font dei titoli")


func test_scheda_principale_scrive_a_inchiostro() -> void:
	var b := UI.choice_card("Gioca", "Con gli amici", func(): pass)
	UI.set_primary(b)
	var labels := b.find_children("*", "Label", true, false)
	runner.check(labels[0].get_theme_color("font_color") == UI.INK, "titolo a inchiostro sul giallo")
	runner.check(b.get_theme_color("font_color") == UI.INK, "anche la scritta del pulsante")
	b.free()


func test_avviso_vuoto_non_si_vede() -> void:
	var host := Control.new()
	var empty := UI.toast(host, "")
	runner.check(empty.self_modulate.a == 0.0, "vuoto: niente targhetta")
	var full := UI.toast(host, "Link copiato")
	runner.check(full.self_modulate.a == 1.0, "con il testo si vede")
	host.free()
