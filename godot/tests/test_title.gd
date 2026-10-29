# Schermata del titolo (title.gd): il fondo animato, il logo disegnato e il menu a piastrelle
extends RefCounted

var runner

const Title := preload("res://scripts/title.gd")
const MenuTile := preload("res://scripts/menu_tile.gd")


func _title(skip := true) -> Control:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var t: Control = Title.new()
	runner.root.add_child(t)
	t.setup(game, skip)
	return t


func test_fondo_logo_e_menu() -> void:
	var t := _title(false)
	runner.check(t.get_child(0).get_script() == preload("res://scripts/title_backdrop.gd"), "il fondo animato è il primo figlio")
	runner.check(t._press.visible and not t._menu.visible, "prima Premi un tasto")
	t._open_menu()
	runner.check(t._menu.visible and not t._press.visible, "poi il menu")
	runner.check(t._first.get_script() == MenuTile and t._first.primary, "Gioca con gli amici è la piastrella gialla")
	runner.check(t._first.title_label.text == "Gioca con gli amici", t._first.title_label.text)
	t.free()


func test_da_solo_e_ritorno() -> void:
	var t := _title()
	var tiles: Array = t._solo.find_children("*", "Button", true, false).filter(func(b): return b.get_script() == MenuTile)
	runner.check(tiles.size() == 4, "quattro strade in Da solo: %d" % tiles.size())
	var got := []
	t.bot_requested.connect(func(): got.append("bot"))
	t._show_solo()
	runner.check(t._solo.visible and not t._menu.visible, "si apre Da solo")
	t._solo_first.pressed.emit()
	runner.check(got == ["bot"], "Contro un bot: %s" % [got])
	t._show_main()
	runner.check(t._menu.visible and not t._solo.visible, "e si torna al menu")
	t.free()


# Sul telefono il menu sta tra i due lottatori del fondo: il fondo esce dai lati e il menu è più stretto
func test_telefono() -> void:
	var was := Phone.active
	Phone.active = true
	var t := _title()
	var backdrop: Control = t.get_child(0)
	runner.check(backdrop.offset_left < 0 and backdrop.offset_right > 0, "il fondo esce dai lati")
	runner.check(t._menu.custom_minimum_size.x == Title.PHONE_MENU_W, "menu stretto: %d" % t._menu.custom_minimum_size.x)
	var solo: Array = t._solo.find_children("*", "Button", true, false).filter(func(b): return b.get_script() == MenuTile)
	runner.check(solo.all(func(b): return not b.detail_label.visible), "in Da solo solo i nomi")
	t.free()
	Phone.active = was


func test_piastrella_scelta() -> void:
	var b: Button = MenuTile.new().setup("Crea", "spiega", "NEW", func(): pass)
	runner.check(not b.hot() and b.title_label.get_theme_color("font_color") == UI.PAPER, "a riposo viola, scritte crema")
	b.set_selected(true)
	runner.check(b.hot() and b.title_label.get_theme_color("font_color") == UI.INK, "scelta: gialla, scritte a inchiostro")
	b.free()
