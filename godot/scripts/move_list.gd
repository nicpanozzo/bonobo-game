# Lista delle mosse del lottatore, come la "Move list" dei picchiaduro: ogni mossa con il suo nome, i tasti
# (quelli salvati nelle opzioni) e una riga su a cosa serve. Si apre dal menu di pausa.
# rows() è pura e la usano i test; il resto è solo il pannello.
extends Control

signal closed

const Lobby := preload("res://scripts/lobby.gd") # face_texture: il ritratto del lottatore

# Cosa fa una speciale, dal suo tipo (SpecialSpec in characters.ts)
const SPECIAL_HINTS := {
	"projectile": "tira da lontano",
	"dash": "scatta in avanti colpendo",
	"charge": "tieni premuto per caricare, lascia per colpire",
	"counter": "para un colpo e risponde più forte",
	"drop": "piomba giù colpendo chi sta sotto",
}


# [sezione, [[mossa, tasti, a cosa serve], ...]] per un personaggio. keys: azione -> nome del tasto ("K", "B"...)
static func rows(game: Dictionary, character_id: String, keys: Dictionary) -> Array:
	var c: Dictionary = game.characters.get(character_id, game.characters.get(game.get("defaultCharacterId", ""), {}))
	var k := func(action: String) -> String: return str(keys.get(action, "?"))
	var plus := func(a: String, b: String) -> String: return "%s + %s" % [k.call(a), k.call(b)]
	var attacks := [
		["Leggero", k.call("light"), "veloce, apre le combo"],
		["Combo di leggeri", "%s %s %s" % [k.call("light"), k.call("light"), k.call("light")], "leggero di fila quando entra: due colpi e un finale che lancia"],
		["Leggero in su", plus.call("up", "light"), "sopra la testa"],
		["Leggero in giù", plus.call("down", "light"), "sgambetto basso"],
		["Leggero in aria", k.call("light") + " saltando", "per le combo in aria"],
		["Pesante", k.call("heavy"), "tienilo premuto a terra per caricarlo: lampeggi e picchi più forte"],
		["Pesante in su", plus.call("up", "heavy"), "lancia in verticale, si carica anche lui"],
		["Pesante in giù", plus.call("down", "heavy"), "spazzata radente, si carica anche lui"],
		["Pesante in aria", k.call("heavy") + " saltando", "il colpo forte in aria"],
		["Attacco in corsa", "%s + %s" % [k.call("run"), k.call("heavy")], "il pesante mentre corri: scivoli avanti colpendo"],
	]
	var specials := []
	var sp: Dictionary = c.get("specials", {})
	var slots := [["neutral", k.call("special"), "da fermo"], ["side", "%s/%s + %s" % [k.call("left"), k.call("right"), k.call("special")], "con una direzione"], ["down", plus.call("down", "special"), "con giù"]]
	for slot in slots:
		var s: Dictionary = sp.get(slot[0], {})
		if s.is_empty():
			continue
		specials.append([str(s.get("name", "Speciale")), slot[1], "%s, %s" % [SPECIAL_HINTS.get(str(s.get("type", "")), "mossa speciale"), slot[2]]])
	var supreme: Dictionary = c.get("supreme", {}) if c.get("supreme") is Dictionary else {}
	specials.append([str(supreme.get("name", "Suprema")), plus.call("special", "heavy"), "insieme, con la barra piena: il lottatore brilla d'oro"])
	var defense := [
		["Scudo", k.call("shield"), "para i colpi ma si consuma"],
		["Presa", plus.call("shield", "light"), "afferra chi si ripara; poi una direzione per lanciarlo"],
		["Schivata", plus.call("shield", "left") + " o " + k.call("shield") + " in aria", "invulnerabile per un attimo: a terra rotoli, in aria schivi"],
		["Rialzata al volo", k.call("shield") + " prima di toccare terra", "dopo un colpo ti rialzi subito, con una direzione rotoli"],
		["Recupero", plus.call("up", "heavy") + " in aria", "una spinta in su per tornare sul palco"],
		["Corsa", "%s + %s/%s" % [k.call("run"), k.call("left"), k.call("right")], "tienila con una direzione: scatti e poi corri"],
		["Doppio salto", k.call("jump") + " in aria", "il secondo salto, una volta per volo"],
		["Provocazione", k.call("taunt"), "per far arrabbiare gli amici"],
	]
	return [["Attacchi", attacks], ["Speciali", specials], ["Difesa e movimento", defense]]


# Il primo tasto di ogni azione, dalla tastiera o dal pad (come lo schema del primo avvio)
static func keys_for(s: Settings, pad: bool, kind := "xbox") -> Dictionary:
	var out := {}
	var bindings: Dictionary = s.pad_bindings if pad else s.bindings
	for action in bindings:
		var codes: Array = bindings[action]
		if codes.is_empty():
			out[action] = "nessun tasto"
		else:
			out[action] = Settings.pad_label(codes[0], kind) if pad else Settings.key_label(codes[0])
	return out


# Con i comandi touch: la levetta per le direzioni, i tasti a schermo col loro nome
static func touch_keys() -> Dictionary:
	var out := {"left": "sinistra", "right": "destra", "up": "su", "down": "giù", "run": "levetta in fondo", "taunt": "solo da tastiera o pad", "dodge": "Scudo + levetta"}
	for action in TouchControls.BUTTONS:
		out[action] = TouchControls.BUTTONS[action].label
	return out


func setup(game: Dictionary, character_id: String, keys: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(700)
	add_child(parts[0])
	var box: VBoxContainer = parts[1]
	var c: Dictionary = game.characters.get(character_id, {})
	# In cima il ritratto del lottatore accanto al titolo, come la scheda delle mosse dei picchiaduro
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UI.GAP_M)
	box.add_child(head)
	var face := Lobby.face_texture(c) if not c.is_empty() else null
	if face != null:
		var pic := TextureRect.new()
		pic.texture = face
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(52, 52)
		head.add_child(pic)
	var title := UI.header("Mosse di %s" % str(c.get("name", "lottatore")))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var scroll := ScrollContainer.new()
	# Sul telefono (Phone) lo schermo è alto 480: la lista scorre in quello che resta sotto il titolo
	scroll.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - 200 if Phone.active else 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", UI.GAP_S)
	scroll.add_child(list)
	for section in rows(game, character_id, keys):
		list.add_child(_section(section[0]))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 5)
		list.add_child(grid)
		for r in section[1]:
			var move := UI.label(r[0])
			move.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
			grid.add_child(move)
			grid.add_child(_keycap(r[1]))
			var hint := UI.note(r[2])
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD
			hint.custom_minimum_size = Vector2(250, 0)
			hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(hint)
	var back := UI.button("Indietro", close, true)
	box.add_child(back)
	UI.keep_focus(self, back)


# Il titolo di una sezione su una targhetta gialla storta, scritto a inchiostro
func _section(text: String) -> Control:
	var l := UI.label(text.to_upper(), UI.SIZE_SMALL, UI.INK)
	l.add_theme_font_override("font", UI.display())
	var plate := UI.button_box(UI.BANANA, false, 4)
	plate.content_margin_top = 1
	plate.content_margin_bottom = 2
	plate.shadow_offset = Vector2(2, 3)
	l.add_theme_stylebox_override("normal", plate)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


# I tasti di una mossa su un tasto disegnato: incavato, col bordo sotto più spesso come un tasto vero
func _keycap(text: String) -> Control:
	var l := UI.label(text, UI.SIZE_SMALL + 1, UI.BANANA)
	l.add_theme_font_override("font", UI.font(UI.WEIGHT_BLACK))
	var cap := StyleBoxFlat.new()
	cap.bg_color = UI.FIELD
	cap.border_color = UI.BORDER
	cap.set_border_width_all(2)
	cap.border_width_bottom = 4
	cap.set_corner_radius_all(5)
	cap.content_margin_left = 9
	cap.content_margin_right = 9
	cap.content_margin_top = 1
	cap.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", cap)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func close() -> void:
	queue_free()
	closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
