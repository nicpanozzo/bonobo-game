# I titoli di coda (#24): chi ha fatto il gioco e cosa. La apre la lobby.
# Hai contribuito? Aggiungi una riga a PEOPLE nella tua PR (nome, ruolo, cosa hai fatto).
extends Control

signal closed

# TODO community: ruoli e nomi come ognuno preferisce comparire
const PEOPLE := [
	["Nicola (@nicpanozzo)", "Idea e organizzazione", "Ha messo in piedi il gioco, la roadmap e il gruppo"],
	["@MauroGrecchi", "Personaggi", "Egiainuso, la creatura blu sulla barchetta (#37)"],
	["@GiovannifRana", "Playtest e arte", "Segnalazioni su KO e respawn (#8, #9), direzione artistica (#41), Bonobot (#20)"],
	["Claude Code", "Codice", "Agente che ha scritto parte del codice per gli umani del gruppo"],
]


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(540)
	add_child(parts[0])
	var box: VBoxContainer = parts[1]
	box.add_child(UI.label("Crediti", 28, UI.ACCENT))
	box.add_child(UI.label("Bonobo Game è fatto dal nostro canale Discord", 13, Color(UI.TEXT, 0.7)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for p in PEOPLE:
		var who := UI.label("%s · %s" % [p[0], p[1]], 17)
		list.add_child(who)
		var what := UI.label(p[2], 14, Color(UI.TEXT, 0.75))
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(what)
	box.add_child(scroll)
	box.add_child(UI.label("Asset e licenze: public/assets/CREDITS.md", 13, Color(UI.TEXT, 0.7)))
	var actions := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var close_button := UI.button("Chiudi", close, true)
	actions.add_child(close_button)
	box.add_child(actions)
	UI.keep_focus(self, close_button)


func close() -> void:
	queue_free()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
