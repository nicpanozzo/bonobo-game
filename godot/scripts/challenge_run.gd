# Un tentativo di sfida (E15 passo 3): riquadro in alto con tempo e punteggio, poi medaglia e Riprova.
# Fa lo stesso conto di ChallengeRun in src/shared/challenges.ts, dagli eventi e dal tempo dell'arena
# (stageMs degli snapshot, non l'orologio del client). Non decide niente della partita: è solo per chi gioca.
extends Control

signal retry_requested # main.gd rimanda al server reset e percentuale, poi chiama start()
signal back_requested # torna all'elenco delle sfide

const Challenges := preload("res://scripts/challenges.gd")

var challenge: Dictionary
var settings: Settings
var my_id := ""
var score: Variant = null # null finché in koTime non c'è il KO
var done := false
var _start_ms := -1.0
var _now_ms := 0.0
var _hits := 0 # palleggio in corso
var _juggled := "" # chi stiamo palleggiando
var _title: Label
var _goal: Label
var _live: Label
var _result: Label
var _buttons: HBoxContainer
var _retry: Button


func setup(c: Dictionary, s: Settings) -> void:
	challenge = c
	settings = s
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 56)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	panel.add_child(box)
	_title = UI.header(c.title)
	_goal = UI.label(c.text)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD
	_live = UI.label("", UI.SIZE_BIG, UI.ACCENT)
	_result = UI.note(Challenges.thresholds_text(c))
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	for l in [_title, _goal, _live, _result]:
		box.add_child(l)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", UI.GAP_M)
	_retry = UI.button("Riprova", func(): retry_requested.emit(), true)
	_buttons.add_child(_retry)
	_buttons.add_child(UI.button("Altre sfide", func(): back_requested.emit()))
	_buttons.hide()
	box.add_child(_buttons)
	start()


# Nuovo tentativo: il tempo riparte dal prossimo snapshot
func start() -> void:
	score = null if challenge.goal == "koTime" else 0
	done = false
	_start_ms = -1.0
	_hits = 0
	_juggled = ""
	_buttons.hide()
	_result.text = Challenges.thresholds_text(challenge)
	_result.remove_theme_color_override("font_color")
	_title.text = challenge.title
	_show_live()


func elapsed() -> float:
	return 0.0 if _start_ms < 0 else (_now_ms - _start_ms) / 1000.0


func on_snapshot(snap: Dictionary) -> void:
	if done:
		return
	_now_ms = float(snap.get("stageMs", 0))
	if _start_ms < 0:
		_start_ms = _now_ms
	for e in snap.get("events", []):
		on_event(e)
		if done:
			return
	# Tornato a terra e ripreso, il palleggio ricomincia da zero
	if _juggled != "":
		var in_play := false
		for p in snap.get("players", []):
			if str(p.id) == _juggled:
				in_play = bool(p.get("hitstun", false)) or not bool(p.get("onGround", true))
		if not in_play:
			_hits = 0
			_juggled = ""
	var limit := float(challenge.limitSec)
	if elapsed() >= limit:
		match str(challenge.goal):
			"survive":
				_finish(limit)
			"damage":
				_finish(roundf(float(score)))
			_:
				_finish(score)
		return
	_show_live()


func on_event(e: Dictionary) -> void:
	if done:
		return
	var t := snappedf(minf(elapsed(), float(challenge.limitSec)), 0.1)
	var type := str(e.get("type", ""))
	match str(challenge.goal):
		"koTime":
			if type == "ko" and str(e.get("byId", "")) == my_id and str(e.get("id", "")) != my_id:
				_finish(t)
		"survive":
			if type == "ko" and str(e.get("id", "")) == my_id:
				_finish(t)
		"damage":
			if type == "hit" and str(e.get("attackerId", "")) == my_id:
				score = float(score) + float(e.get("damage", 0))
		"juggle":
			if type == "hit" and str(e.get("attackerId", "")) == my_id:
				if str(e.targetId) != _juggled:
					_hits = 0
				_juggled = str(e.targetId)
				_hits += 1
				score = maxi(int(score), _hits)
				if int(score) >= int(challenge.medals[2]): # oro: inutile aspettare la fine
					_finish(score)


func medal() -> int:
	return Challenges.medal_for(challenge, score) if done else 0


func _show_live() -> void:
	var left := maxf(0.0, float(challenge.limitSec) - elapsed())
	match str(challenge.goal):
		"koTime", "survive":
			_live.text = "%.1f s" % elapsed()
		_:
			_live.text = "%s · mancano %d s" % [Challenges.score_text(challenge, score), ceili(left)]


func _finish(final: Variant) -> void:
	score = final
	done = true
	var m := medal()
	_title.text = Challenges.MEDALS[m] + "!" if m > 0 else "Niente medaglia"
	_live.text = Challenges.score_text(challenge, score)
	var record := false
	if score != null:
		record = settings.record_medal(str(challenge.id), m, float(score), Challenges.lower_is_better(challenge))
	var saved: Dictionary = settings.medals.get(challenge.id, {})
	_result.text = "Nuovo record!" if record else ("Record: %s" % Challenges.score_text(challenge, saved.best) if not saved.is_empty() else Challenges.thresholds_text(challenge))
	_result.add_theme_color_override("font_color", Challenges.MEDAL_COLORS[m])
	_buttons.show()
	if is_inside_tree():
		_retry.grab_focus()
