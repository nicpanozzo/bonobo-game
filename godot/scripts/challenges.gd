# Elenco delle sfide con medaglie (E15 passo 3, #113): le sfide sono dati di src/shared/challenges.ts
# (game.json → challenges), la medaglia migliore di ognuna è nelle preferenze (settings.gd, [medals]).
# Scelta una sfida, main.gd apre una palestra tutta propria e challenge_run.gd la gioca.
extends Control

signal chosen(challenge: Dictionary)
signal closed

const MEDALS := ["", "Bronzo", "Argento", "Oro"]
const MEDAL_COLORS := [Color(1, 1, 1, 0.4), Color("cd7f32"), Color("c0c8d0"), Color("ffcf4a")]


# Come medalFor() in src/shared/challenges.ts: 0 nessuna, 1 bronzo, 2 argento, 3 oro
static func medal_for(c: Dictionary, score: Variant) -> int:
	if score == null:
		return 0
	var medal := 0
	for i in c.medals.size():
		var t: float = c.medals[i]
		if (float(score) <= t) if lower_is_better(c) else (float(score) >= t):
			medal = i + 1
	return medal


static func lower_is_better(c: Dictionary) -> bool:
	return c.goal == "koTime"


# "4.2 s", "87%", "5 colpi"
static func score_text(c: Dictionary, score: Variant) -> String:
	if score == null:
		return "nessun KO"
	match str(c.goal):
		"damage":
			return "%d%%" % roundi(float(score))
		"juggle":
			return "%d colpi" % int(score)
	return "%.1f s" % float(score)


# Le soglie in chiaro: "Oro 5 s · Argento 7 s · Bronzo 12 s"
static func thresholds_text(c: Dictionary) -> String:
	var parts := PackedStringArray()
	for i in [2, 1, 0]:
		parts.append("%s %s" % [MEDALS[i + 1], score_text(c, c.medals[i])])
	return " · ".join(parts)


func setup(game: Dictionary, settings: Settings) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(560)
	add_child(parts[0])
	var box: VBoxContainer = parts[1]
	box.add_child(UI.header("Sfide"))
	box.add_child(UI.note("Una palestra tutta tua: prendi le medaglie, restano salvate."))
	var first: Control = null
	for c in game.get("challenges", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UI.GAP_L)
		var b := UI.button(c.title, func(): chosen.emit(c))
		b.custom_minimum_size = Vector2(220, 0)
		row.add_child(b)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var saved: Dictionary = settings.medals.get(c.id, {})
		var medal := int(saved.get("medal", 0))
		var best := "Da fare" if saved.is_empty() else "%s · record %s" % [MEDALS[medal] if medal > 0 else "Nessuna medaglia", score_text(c, saved.best)]
		info.add_child(UI.label(best, UI.SIZE_SMALL, MEDAL_COLORS[medal]))
		var text := UI.label(c.text, UI.SIZE_NOTE, Color(UI.TEXT, 0.7))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(text)
		row.add_child(info)
		box.add_child(row)
		if first == null:
			first = b
	var close_button := UI.button("Chiudi", close)
	box.add_child(close_button)
	UI.keep_focus(self, first if first != null else close_button)


func close() -> void:
	queue_free()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
