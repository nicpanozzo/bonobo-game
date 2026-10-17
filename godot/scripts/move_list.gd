# Lista delle mosse del lottatore, come la "Move list" dei picchiaduro: ogni mossa con il suo nome, i tasti
# (quelli salvati nelle opzioni) e una riga su a cosa serve. Si apre dal menu di pausa.
# rows() è pura e la usano i test; il resto è solo il pannello.
extends Control

signal closed

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
	specials.append([str(supreme.get("name", "Suprema")), k.call("supreme"), "con la barra piena: il lottatore brilla d'oro"])
	var defense := [
		["Scudo", k.call("shield"), "para i colpi ma si consuma"],
		["Presa", plus.call("shield", "light"), "afferra chi si ripara; poi una direzione per lanciarlo"],
		["Schivata", k.call("dodge"), "invulnerabile per un attimo, con una direzione rotola"],
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


func setup(game: Dictionary, character_id: String, keys: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(640)
	add_child(parts[0])
	var box: VBoxContainer = parts[1]
	var c: Dictionary = game.characters.get(character_id, {})
	box.add_child(UI.header("Mosse di %s" % str(c.get("name", "lottatore"))))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for section in rows(game, character_id, keys):
		list.add_child(UI.heading(section[0]))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		list.add_child(grid)
		for r in section[1]:
			grid.add_child(UI.label(r[0]))
			var key := UI.label(r[1])
			key.add_theme_color_override("font_color", UI.ACCENT)
			grid.add_child(key)
			var hint := UI.note(r[2])
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD
			hint.custom_minimum_size = Vector2(260, 0)
			hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(hint)
	var back := UI.button("Indietro", close, true)
	box.add_child(back)
	UI.keep_focus(self, back)


func close() -> void:
	queue_free()
	closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
