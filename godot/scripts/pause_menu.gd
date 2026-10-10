# Menu con Esc (o Start sul pad) durante la partita (come src/client/PauseMenu.ts). La partita è online e non
# si ferma: il menu spegne solo i tasti di chi lo apre.
extends Control

signal resumed
signal left

var settings: Settings
var link := ""
var _note: Label
var _dim: Control
var _in_options := false
var _options_button: Button
var _report := {} # dati della partita per il tasto Segnala (#214)

const ISSUES_URL := "https://github.com/nicpanozzo/bonobo-game/issues/new"


func setup(s: Settings, room_link: String, report := {}) -> void:
	settings = s
	link = room_link
	_report = report
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.overlay(380)
	_dim = parts[0]
	add_child(_dim)
	var box: VBoxContainer = parts[1]
	box.add_child(UI.header("Menu"))
	var resume_button := UI.button("Riprendi", resume, true)
	box.add_child(resume_button)
	_options_button = UI.button("Opzioni", _open_options)
	box.add_child(_options_button)
	box.add_child(UI.button("Copia link della stanza", func():
		UI.copy(link)
		_note.text = "Link copiato: incollalo sul Discord"))
	box.add_child(UI.button("Segnala un problema", _send_report))
	box.add_child(UI.button("Esci alla lobby", func():
		queue_free()
		left.emit()))
	_note = UI.note("La partita continua mentre il menu è aperto.")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_note)
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	box.add_child(UI.note(UI.version_text(game if game is Dictionary else {}), 0.5))
	UI.keep_focus(self, resume_button)


# Apre una issue nuova già compilata e copia lo stesso testo, per chi preferisce il Discord
func _send_report() -> void:
	var game = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var body := report_body(_report, UI.version_text(game if game is Dictionary else {}), OS.get_name())
	UI.copy(body)
	OS.shell_open(report_url(body))
	_note.text = "Si apre GitHub con i dati della partita: scrivi cosa è successo. Il testo è anche negli appunti."


static func report_url(body: String) -> String:
	return "%s?title=%s&body=%s" % [ISSUES_URL, "Segnalazione: ".uri_encode(), body.uri_encode()]


# Il testo della segnalazione: due domande per chi gioca, poi i dati della partita
static func report_body(r: Dictionary, version: String, system: String) -> String:
	var fighters := []
	for p in r.get("players", []):
		var who := "%s (%s)" % [p.get("name", "?"), p.get("characterId", "?")]
		if p.get("id") == r.get("me"):
			who += ", io"
		fighters.append(who)
	var rules: Dictionary = r.get("rules", {})
	var lines := [
		"**Cosa è successo:**", "", "", "**Cosa ti aspettavi:**", "", "", "---",
		"- Versione: %s" % version,
		"- Sistema: %s" % system,
		"- Server: %s" % r.get("server", "?"),
		"- Stanza: %s" % r.get("room", "?"),
		"- Arena: %s" % r.get("stage", "?"),
		"- Modalità: %s" % rules.get("mode", "?"),
		"- Lottatori: %s" % (", ".join(fighters) if not fighters.is_empty() else "nessuno"),
	]
	return "\n".join(lines)


func resume() -> void:
	queue_free()
	resumed.emit()


func _open_options() -> void:
	_in_options = true
	_dim.hide()
	var options := preload("res://scripts/options.gd").new()
	add_child(options)
	options.setup(settings)
	options.closed.connect(func():
		_in_options = false
		_dim.show()
		_options_button.grab_focus())


# Esc, B o Start riprendono la partita
func _input(event: InputEvent) -> void:
	if _in_options or event.is_echo():
		return
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if start or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()
