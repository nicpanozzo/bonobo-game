# Prova di #196 da far vedere al gruppo: a sinistra Bonobot com'è oggi (spritesheet a 24 fotogrammi
# al secondo), a destra lo stesso personaggio animato in tempo reale con Skeleton2D, con i passaggi
# morbidi tra un'animazione e l'altra.
#   godot --path godot res://prototipi/scheletro/prova.tscn
# Tasti: A/D cammina, doppio tocco di A/D (o Maiusc) scatta a quattro zampe, J schiaffo, K martello;
# senza tasti gira da sola.
# Per la GIF: godot --path godot res://prototipi/scheletro/prova.tscn -- --registra=/cartella
extends Node2D

const DIR := "res://prototipi/scheletro/bonobot"
const SHEET := "res://data/assets/characters/bonobot/bonobot.png"
const BLEND := 0.15 # secondi di passaggio morbido tra due animazioni
const RECORD_FPS := 50.0
const SHOW := 1.2 # disegni a 2x mostrati a metà e ingranditi di 2.4 per vederli bene
# Spritesheet di oggi: riga, fotogrammi e fps (come characters.ts)
# (lo scatto oggi non c'è: per confronto il galoppo della camminata)
const SHEET_ANIMS := {"idle": [0, 24, 12], "walk": [1, 10, 24], "light": [4, 7, 24], "heavy": [5, 18, 24], "dash": [1, 10, 24]}
const ONE_SHOT := ["light", "heavy"]
const DEMO := [["idle", 1.2], ["walk", 1.6], ["dash", 1.44], ["walk", 0.8], ["idle", 0.6], ["light", 0.42], ["idle", 0.5], ["heavy", 0.75], ["idle", 1.0]]
const DOUBLE_TAP := 0.25 # secondi tra due tocchi per lo scatto

var _figure: Node2D
var _player: AnimationPlayer
var _sheet: Sprite2D
var _sheet_anim := "idle"
var _sheet_since := 0.0
var _t := 0.0
var _record_dir := ""
var _frame := 0
var _demo_i := 0
var _demo_left := 0.0
var _manual := false
var _current := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--registra="):
			_record_dir = arg.trim_prefix("--registra=")
	RenderingServer.set_default_clear_color(Color("27313a"))
	var floor_rect := ColorRect.new()
	floor_rect.color = Color("3d4a54")
	floor_rect.position = Vector2(0, 420)
	floor_rect.size = Vector2(2000, 200)
	add_child(floor_rect)
	_label("Oggi: spritesheet, 24 fotogrammi al secondo", Vector2(70, 450))
	_label("Proposta: scheletro in Godot, a ogni frame,\ncon passaggi morbidi tra le animazioni", Vector2(530, 450))
	_label("A/D cammina · doppio tocco scatta · J schiaffo · K martello · senza tasti va da sola", Vector2(250, 515), 14)

	_sheet = Sprite2D.new()
	_sheet.texture = load(SHEET)
	_sheet.region_enabled = true
	_sheet.centered = false
	_sheet.scale = Vector2(SHOW, SHOW) # stessa misura a schermo della figura a destra
	add_child(_sheet)

	_figure = CostruisciScheletro.costruisci(DIR)
	_figure.position = Vector2(700, 420)
	_figure.scale *= SHOW * 1.55 # stessa altezza a schermo del Bonobot di oggi
	add_child(_figure)
	_player = _figure.get_node("AnimationPlayer")
	_play("idle")
	if _record_dir != "":
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for smoke in _figure.find_children("Fumo", "", true, false):
			smoke.manual = true


func _play(anim: String) -> void:
	if anim == _current and not anim in ONE_SHOT:
		return
	_current = anim
	_player.play(anim, BLEND)
	_sheet_anim = anim
	_sheet_since = _t


func _process(delta: float) -> void:
	var dt := 1.0 / RECORD_FPS if _record_dir != "" else delta
	_t += dt
	_choose(dt)
	if _record_dir != "":
		_player.advance(dt)
		for smoke in _figure.find_children("Fumo", "", true, false):
			smoke.step(dt)
	_draw_sheet()
	if _record_dir != "":
		_save_frame.call_deferred()


# Tasti, oppure la sequenza dimostrativa
var _last_tap := {-1: -10.0, 1: -10.0}
var _prev_dir := 0
var _dashing := false


func _choose(dt: float) -> void:
	var dir := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var slap := Input.is_physical_key_pressed(KEY_J)
	var hammer := Input.is_physical_key_pressed(KEY_K)
	if dir != 0 or slap or hammer:
		_manual = true
	if _manual:
		if dir != 0 and dir != _prev_dir: # tocco nuovo: due in fretta dalla stessa parte = scatto
			_dashing = _t - float(_last_tap[dir]) < DOUBLE_TAP or Input.is_physical_key_pressed(KEY_SHIFT)
			_last_tap[dir] = _t
		_prev_dir = dir
		if _current in ONE_SHOT and _player.is_playing() and _player.current_animation == _current:
			return
		if slap:
			_play("light")
		elif hammer:
			_play("heavy")
		elif dir != 0:
			_figure.scale.x = absf(_figure.scale.x) * dir
			_sheet.flip_h = dir < 0
			_play("dash" if _dashing else "walk")
		else:
			_dashing = false
			_play("idle")
		return
	_demo_left -= dt
	if _demo_left <= 0.0:
		var step: Array = DEMO[_demo_i % DEMO.size()]
		_demo_i += 1
		_demo_left = float(step[1])
		_play(String(step[0]))
		if _record_dir != "" and _demo_i > DEMO.size():
			get_tree().quit()


func _draw_sheet() -> void:
	var a: Array = SHEET_ANIMS[_sheet_anim]
	var frames: int = a[1]
	var frame := int((_t - _sheet_since) * float(a[2]))
	frame = mini(frame, frames - 1) if _sheet_anim in ONE_SHOT else frame % frames
	_sheet.region_rect = Rect2(frame * 256, int(a[0]) * 240, 256, 240)
	# fotogramma 256x240 disegnato a 2x: a metà, per 1.6 come la figura; piedi in basso al centro
	_sheet.position = Vector2(250 - 128 * SHOW, 420 - 240 * SHOW)


func _save_frame() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [_record_dir, _frame])
	_frame += 1


func _label(text: String, pos: Vector2, size := 16) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
