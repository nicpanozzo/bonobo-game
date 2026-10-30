# Il riquadro della chat vocale, in alto a destra come l'overlay di Discord: chi è in voce, con il ritratto
# che si accende di verde quando parla, microfono spento, audio disattivato, qualità del collegamento.
# In sala ha i pulsanti (Entra, microfono, audio, impostazioni, esci); in partita è compatto, solo le righe:
# lì valgono i tasti (N, B, V) e il menu di pausa. Un clic su un giocatore: volume (0-200%) e "silenzia per me".
# Le icone sono disegnate col codice: i font del gioco non hanno questi simboli.
class_name VoicePanel
extends Control

signal settings_requested

const FighterPose := preload("res://scripts/fighter_pose.gd")

const WIDTH := 236.0
const WIDTH_PHONE := 214.0
const MARGIN := 12.0 # dal bordo destro dello schermo
const PAD := 8.0 # dentro il riquadro
const HEADER_H := 24.0
const ROW_H := 30.0
const ROW_H_COMPACT := 24.0
const ROW_H_PHONE := 34.0 # sul telefono le righe si toccano col dito
const BAR_H := 38.0
const BAR_H_PHONE := 44.0
const MAX_ROWS := 8 # i giocatori di una stanza
# Spazio lasciato in basso (pixel): in partita le schede dell'HUD, sul telefono i tasti a schermo a destra,
# in sala la riga dei tasti e, sul telefono, la richiesta in basso. Se le righe non ci stanno si vedono
# io e chi parla per primi
const RESERVE_MATCH := 150.0
const RESERVE_MATCH_PHONE := 205.0
const RESERVE_HALL := 50.0
const RESERVE_HALL_PHONE := 90.0
const LEAN := 8.0 # quanto pende la lastra, come le schede dell'HUD
const QUALITY_COLORS := [Color(0.55, 0.5, 0.65), UI.PUNCH, UI.BANANA, UI.MINT] # 0 = mi collego

var voice: VoiceChat
var area := "" # "hall", "match" o "" (nascosto): lo decide main.gd
var top := 48.0 # dove comincia dall'alto, sotto quello che c'è già in alto a destra (pixel)
var portrait_of: Callable # look → [Texture2D, Rect2] o []: lo stesso dell'HUD, con la sua cache
var game: Dictionary = {}

var _rows: Array = []
var _visible: Array = [] # le righe disegnate, nell'ordine in cui si vedono
var _bar: HBoxContainer
var _join: Button
var _mic: Button
var _deaf: Button
var _gear: Button
var _leave: Button
var _popup: PopupPanel
var _popup_id := ""
var _shown_sig := ""


func setup(v: VoiceChat) -> void:
	voice = v
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", UI.GAP_S)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_join = UI.small_button("Entra in voce", func(): voice.toggle_join())
	UI.set_primary(_join)
	_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.add_child(_join)
	_mic = _icon_button("mic", "Microfono (%s)", "mute", func(): voice.toggle_mute())
	_deaf = _icon_button("headset", "Audio (%s)", "deafen", func(): voice.toggle_deafen())
	_gear = _icon_button("gear", "Impostazioni della voce", "", func(): settings_requested.emit())
	_leave = _icon_button("leave", "Esci dalla voce", "", func(): voice.leave())
	for b in [_join, _mic, _deaf, _gear, _leave]:
		b.focus_mode = Control.FOCUS_NONE # in sala i tasti muovono il lottatore, non il fuoco
	voice.changed.connect(_refresh)
	voice.levels_changed.connect(_on_levels)
	_refresh()


func _icon_button(kind: String, tip: String, key_action: String, on_press: Callable) -> Button:
	var b := UI.small_button("", on_press)
	b.custom_minimum_size = Vector2(38, 30)
	b.set_meta("tip", tip)
	b.set_meta("key", key_action)
	var icon := VoiceIcon.new()
	icon.kind = kind
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.add_child(b)
	return b


# ---- Misure (statiche, per i test) ----

static func row_height(compact: bool, phone: bool) -> float:
	if phone:
		return ROW_H_PHONE
	return ROW_H_COMPACT if compact else ROW_H


static func panel_size(rows: int, compact: bool, bar: bool, phone: bool) -> Vector2:
	var k := Access.text_scale
	var h := _fixed_height(bar, phone) + mini(rows, MAX_ROWS) * row_height(compact, phone) * k
	return Vector2((WIDTH_PHONE if phone else WIDTH) * k, h)


static func _fixed_height(bar: bool, phone: bool) -> float:
	var k := Access.text_scale
	return PAD * 2.0 + HEADER_H * k + ((BAR_H_PHONE if phone else BAR_H) * k if bar else 0.0)


# Quante righe ci stanno da top_y in giù, lasciando libero il fondo (compact = in partita)
static func fit_rows(rows: int, screen_h: float, top_y: float, compact: bool, bar: bool, phone: bool) -> int:
	var reserve := (RESERVE_MATCH_PHONE if phone else RESERVE_MATCH) if compact else (RESERVE_HALL_PHONE if phone else RESERVE_HALL)
	var room := screen_h - reserve - top_y - _fixed_height(bar, phone)
	var fit := int(floorf(room / (row_height(compact, phone) * Access.text_scale)))
	return clampi(mini(rows, fit), mini(rows, 1), MAX_ROWS)


# Dove sta il riquadro: in alto a destra, da top in giù, con le righe che ci stanno
static func layout_rect(screen: Vector2, rows: int, top_y: float, compact: bool, bar: bool, phone: bool) -> Rect2:
	var s := panel_size(fit_rows(rows, screen.y, top_y, compact, bar, phone), compact, bar, phone)
	return Rect2(Vector2(screen.x - s.x - MARGIN, top_y), s)


# Le righe da disegnare: tutte se ci stanno, se no io, poi chi parla, poi gli altri
static func pick_rows(rows: Array, count: int) -> Array:
	if rows.size() <= count:
		return rows
	var order := rows.filter(func(r): return r.me)
	order.append_array(rows.filter(func(r): return not r.me and r.speaking))
	order.append_array(rows.filter(func(r): return not r.me and not r.speaking))
	return order.slice(0, count)


# ---- Stato ----

func compact() -> bool:
	return area == "match"


func has_bar() -> bool:
	return not compact()


# In sala sempre; in partita solo se qualcuno è in voce (anche senza di me)
func wanted() -> bool:
	if voice == null or area == "":
		return false
	if area == "hall":
		return true
	return voice.supported and (voice.phase != VoiceChat.OFF or not voice.participants().is_empty())


func _refresh() -> void:
	if voice == null:
		return
	_rows = voice.participants()
	if not voice.supported:
		_rows = []
	var on := voice.phase != VoiceChat.OFF
	_join.visible = not on
	_join.disabled = not voice.supported
	_join.text = "Entra in voce" if voice.supported else "Solo nel browser"
	if not voice.supported:
		_join.add_theme_stylebox_override("disabled", _small_box(UI.GRAPE_HI.darkened(0.3), false))
		_join.add_theme_color_override("font_disabled_color", Color(UI.PAPER, 0.5))
	for b in [_mic, _deaf, _leave]:
		b.visible = on
	_gear.visible = voice.supported
	_style_toggle(_mic, voice.effective_muted())
	_style_toggle(_deaf, voice.deafened)
	(_mic.get_child(0) as VoiceIcon).slash = voice.effective_muted()
	(_deaf.get_child(0) as VoiceIcon).slash = voice.deafened
	for b in [_mic, _deaf, _gear, _leave]:
		var key: String = b.get_meta("key")
		var label: String = voice.settings.voice_key_label(key) if key != "" and voice.settings != null else ""
		var tip: String = b.get_meta("tip")
		b.tooltip_text = tip % label if "%s" in tip else tip
		if "%s" in tip and label == "":
			b.tooltip_text = tip.replace(" (%s)", "")
		b.get_child(0).queue_redraw()
	if is_instance_valid(_popup) and _popup.visible and not _has_row(_popup_id):
		_popup.hide()
	_layout()
	queue_redraw()


# 15 volte al secondo: chi parla e quanto forte, senza rifare le righe
func _on_levels() -> void:
	for r in _rows:
		r.speaking = voice.is_speaking(r.id)
		r.level = float(voice.levels.get(r.id, 0.0))
	queue_redraw()


func _has_row(id: String) -> bool:
	for r in _rows:
		if r.id == id:
			return true
	return false


# Pulsante acceso (microfono spento, audio disattivato): rosso pieno, come su Discord
func _style_toggle(b: Button, active: bool) -> void:
	var fill := UI.PUNCH if active else UI.GRAPE_HI
	b.add_theme_stylebox_override("normal", _small_box(fill, false))
	b.add_theme_stylebox_override("hover", _small_box(fill.lightened(0.14), false))
	b.add_theme_stylebox_override("pressed", _small_box(fill.darkened(0.15), true))
	b.add_theme_stylebox_override("hover_pressed", _small_box(fill.darkened(0.05), true))


static func _small_box(fill: Color, pressed: bool) -> StyleBoxFlat:
	var s := UI.button_box(fill, pressed, 6, UI.SKEW * 0.75)
	s.content_margin_top = 3 + (UI.DROP - 1 if pressed else 0)
	s.content_margin_bottom = 3 - (UI.DROP - 1 if pressed else 0)
	return s


func _process(_delta: float) -> void:
	var want := wanted()
	if visible != want:
		visible = want
	if not want:
		if is_instance_valid(_popup) and _popup.visible:
			_popup.hide()
		return
	_layout()
	# I puntini di "mi collego" si muovono
	for r in _rows:
		if r.state == "connecting" or r.get("joining", false):
			queue_redraw()
			break


func _layout() -> void:
	var screen := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var rows := _rows.size() if voice != null and voice.supported else 2 # fuori dal browser: due righe che lo spiegano
	var r := layout_rect(screen, rows, top, compact(), has_bar(), Phone.active)
	_visible = pick_rows(_rows, fit_rows(rows, screen.y, top, compact(), has_bar(), Phone.active))
	var sig := "%s|%s|%s" % [r, compact(), Access.text_scale]
	if sig == _shown_sig:
		return
	_shown_sig = sig
	position = r.position
	size = r.size
	_bar.visible = has_bar()
	var k := Access.text_scale
	var bar_h := (BAR_H_PHONE if Phone.active else BAR_H) * k
	_bar.position = Vector2(PAD + 2.0, r.size.y - PAD - bar_h + 3.0)
	_bar.size = Vector2(r.size.x - PAD * 2.0 - 4.0, bar_h - 6.0)
	for b in [_mic, _deaf, _gear, _leave]:
		b.custom_minimum_size = Vector2((44.0 if Phone.active else 38.0) * k, bar_h - 8.0)
	queue_redraw()


# ---- Disegno ----

func _draw() -> void:
	if voice == null:
		return
	var k := Access.text_scale
	var w := size.x
	var fade := 0.86 if compact() else 0.94
	UI.draw_plate(self, Rect2(Vector2(LEAN / 2.0, 0), Vector2(w - LEAN, size.y)), Color(UI.NIGHT, fade), LEAN, UI.INK, 3.0, Vector2(3, 4))
	var font := UI.font(UI.WEIGHT_BOLD)
	var display := UI.display()
	# Intestazione: VOCE e quanti sono dentro
	var hy := PAD + HEADER_H * k * 0.5
	draw_icon(self, "mic", Rect2(Vector2(PAD + 2.0, hy - 8.0 * k), Vector2(16, 16) * k), UI.BANANA, false)
	draw_string(display, Vector2(PAD + 22.0 * k, hy + 6.0 * k), "VOCE", HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(UI.SIZE_SUBTITLE), UI.BANANA)
	var count := voice.in_voice_count()
	var info := ""
	if not voice.supported:
		info = ""
	elif voice.phase == VoiceChat.JOINING:
		info = "mi collego" + ".".repeat(1 + (Time.get_ticks_msec() / 400) % 3)
	elif count > 0:
		info = "%d in voce" % count
	else:
		info = "nessuno"
	draw_string(font, Vector2(w * 0.45 - PAD - 4.0, hy + 5.0 * k), info, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.55, Access.px(UI.SIZE_NOTE), UI.LILAC)
	var rh := row_height(compact(), Phone.active) * k
	var y := PAD + HEADER_H * k
	if not voice.supported:
		for i in 2:
			draw_string(font, Vector2(PAD + 6.0, y + rh * (0.65 + i * 0.8)), ["La chat vocale funziona", "nel browser, non nell'app"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(UI.SIZE_NOTE), Color(UI.PAPER, 0.8))
		return
	for i in _visible.size():
		_draw_row(_visible[i], Rect2(PAD, y + i * rh, w - PAD * 2.0, rh), k)


func _draw_row(r: Dictionary, rect: Rect2, k: float) -> void:
	var font := UI.font(UI.WEIGHT_BOLD)
	var av := minf(rect.size.y - 6.0, 24.0 * k)
	var a := Rect2(rect.position + Vector2(4.0, (rect.size.y - av) / 2.0), Vector2(av, av))
	var col := Access.color(r.color)
	var dim: bool = r.state != "connected" and r.state != "off" and not r.me # "off": sono fuori, non c'è collegamento da aspettare
	# Anello verde di chi parla: più forte la voce, più largo il bagliore
	if r.speaking:
		var glow := clampf(float(r.level) * 1.6, 0.35, 1.0)
		draw_rect(a.grow(3.0 + 3.0 * glow), Color(UI.MINT, 0.25 * glow), true)
		draw_rect(a.grow(2.0), UI.MINT, false, 2.5)
	draw_rect(a, col.darkened(0.45), true)
	var drawn := false
	if portrait_of.is_valid() and r.char != "" and not game.is_empty():
		var src: Array = portrait_of.call(FighterPose.look(game, r.char, r.skin))
		if not src.is_empty():
			var reg: Rect2 = src[1]
			var face := Rect2(reg.position, Vector2(reg.size.x, minf(reg.size.y, reg.size.x)))
			draw_texture_rect_region(src[0], a, face, Color(1, 1, 1, 0.5 if dim else 1.0))
			drawn = true
	if not drawn:
		var initial := str(r.name).left(1).to_upper()
		var size_px := Access.px(UI.SIZE_SMALL)
		var tw := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(font, Vector2(a.get_center().x - tw / 2.0, a.get_center().y + size_px * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col.lightened(0.4))
	draw_rect(a, UI.MINT if r.speaking else UI.INK, false, 2.0)
	# A destra le icone: qualità, microfono spento, audio disattivato, silenziato per me
	var x := rect.end.x - 4.0
	var icon := 15.0 * k
	var cy := rect.get_center().y
	if not r.me and r.state != "off":
		var q: int = clampi(int(r.quality), 0, 3) if r.state == "connected" else 0
		var dot: Color = QUALITY_COLORS[q]
		if r.state == "failed":
			dot = UI.PUNCH
		var pulse := 1.0
		if r.state == "connecting":
			pulse = 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() / 300.0))
		draw_circle(Vector2(x - 4.0, cy), 4.0 * k, Color(dot, pulse))
		x -= 12.0 * k
	if r.deafened:
		x -= icon
		draw_icon(self, "headset", Rect2(Vector2(x, cy - icon / 2.0), Vector2(icon, icon)), UI.WARN, true)
		x -= 3.0
	elif r.muted:
		x -= icon
		draw_icon(self, "mic", Rect2(Vector2(x, cy - icon / 2.0), Vector2(icon, icon)), UI.WARN, true)
		x -= 3.0
	if r.local_muted:
		x -= icon
		draw_icon(self, "speaker", Rect2(Vector2(x, cy - icon / 2.0), Vector2(icon, icon)), UI.LILAC, true)
		x -= 3.0
	var name_x := a.end.x + 8.0
	var name_size := Access.px(UI.SIZE_SMALL if not compact() else UI.SIZE_NOTE)
	var name_col := UI.BANANA if r.me else UI.PAPER
	if dim:
		name_col = Color(name_col, 0.6)
	var text := fit_text(font, str(r.name) + (" (tu)" if r.me else ""), name_size, maxf(10.0, x - name_x - 4.0))
	draw_string(font, Vector2(name_x, cy + name_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, name_col)
	# Volume diverso dal 100%: un trattino sotto il nome, lungo quanto il volume
	if not r.me:
		var vol := voice.peer_volume(r.id)
		if not is_equal_approx(vol, 1.0) and not r.local_muted:
			var bar_len := (x - name_x - 8.0) * clampf(vol / 2.0, 0.0, 1.0)
			draw_line(Vector2(name_x, rect.end.y - 3.0), Vector2(name_x + bar_len, rect.end.y - 3.0), Color(UI.BANANA, 0.6), 2.0)


# Il nome accorciato con i puntini se non ci sta
static func fit_text(font: Font, text: String, size_px: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= width:
		return text
	var t := text
	while t.length() > 1 and font.get_string_size(t + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width:
		t = t.left(t.length() - 1)
	return t.strip_edges() + "..."


# Le icone: rect è il quadrato dove stanno, slash le barra (spento)
static func draw_icon(ci: CanvasItem, kind: String, rect: Rect2, color: Color, slash: bool) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	var lw := maxf(1.5, s * 0.1)
	match kind:
		"mic":
			var bw := s * 0.34
			var cap_top := c + Vector2(0, -s * 0.42 + bw / 2.0)
			var cap_bottom := c + Vector2(0, s * 0.02 - bw / 2.0)
			ci.draw_rect(Rect2(cap_top.x - bw / 2.0, cap_top.y, bw, cap_bottom.y - cap_top.y), color)
			ci.draw_circle(cap_top, bw / 2.0, color)
			ci.draw_circle(cap_bottom, bw / 2.0, color)
			ci.draw_arc(c + Vector2(0, -s * 0.08), s * 0.3, 0.0, PI, 12, color, lw, true)
			ci.draw_line(c + Vector2(0, s * 0.22), c + Vector2(0, s * 0.4), color, lw)
			ci.draw_line(c + Vector2(-s * 0.18, s * 0.4), c + Vector2(s * 0.18, s * 0.4), color, lw)
		"headset":
			ci.draw_arc(c + Vector2(0, s * 0.06), s * 0.36, PI, TAU, 14, color, lw * 1.1, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.02), Vector2(s * 0.2, s * 0.34)), color)
			ci.draw_rect(Rect2(c + Vector2(s * 0.25, s * 0.02), Vector2(s * 0.2, s * 0.34)), color)
		"gear":
			for i in 8:
				var ang := TAU * i / 8.0
				var d := Vector2(cos(ang), sin(ang))
				var n := Vector2(-d.y, d.x)
				var r0 := s * 0.22
				var r1 := s * 0.44
				var tw := s * 0.09
				ci.draw_colored_polygon(PackedVector2Array([c + d * r0 - n * tw, c + d * r1 - n * tw, c + d * r1 + n * tw, c + d * r0 + n * tw]), color)
			ci.draw_circle(c, s * 0.3, color)
			ci.draw_circle(c, s * 0.12, UI.INK)
		"leave":
			# Una porta aperta con la freccia che esce
			var l := c.x - s * 0.4
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.05, -s * 0.38), Vector2(l, c.y - s * 0.38), Vector2(l, c.y + s * 0.38), c + Vector2(s * 0.05, s * 0.38)]), color, lw)
			ci.draw_line(c + Vector2(-s * 0.15, 0), c + Vector2(s * 0.4, 0), color, lw)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.46, 0), c + Vector2(s * 0.24, -s * 0.18), c + Vector2(s * 0.24, s * 0.18)]), color)
		"speaker":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.13), c + Vector2(-s * 0.22, -s * 0.13), c + Vector2(s * 0.05, -s * 0.38),
				c + Vector2(s * 0.05, s * 0.38), c + Vector2(-s * 0.22, s * 0.13), c + Vector2(-s * 0.42, s * 0.13)]), color)
			ci.draw_arc(c + Vector2(s * 0.05, 0), s * 0.22, -PI / 3.0, PI / 3.0, 8, color, lw, true)
			ci.draw_arc(c + Vector2(s * 0.05, 0), s * 0.38, -PI / 3.0, PI / 3.0, 10, color, lw, true)
	if slash:
		var a := c + Vector2(-s * 0.42, -s * 0.42)
		var b := c + Vector2(s * 0.42, s * 0.42)
		ci.draw_line(a, b, UI.INK, lw * 2.4)
		ci.draw_line(a, b, color.lightened(0.15), lw)


# ---- Clic su un giocatore: volume e "silenzia per me" ----

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var tap := event as InputEventScreenTouch
	var pos := Vector2(-1, -1)
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
		pos = mb.position
	elif tap != null and tap.pressed:
		pos = tap.position
	if pos.x < 0.0:
		return
	var i := row_at(pos.y)
	if i < 0 or i >= _visible.size():
		return
	accept_event()
	var r: Dictionary = _visible[i]
	if r.me:
		settings_requested.emit()
	else:
		open_peer_menu(r.id, i)


# Indice della riga sotto y (coordinate del riquadro), -1 se nessuna
func row_at(y: float) -> int:
	var k := Access.text_scale
	var y0 := PAD + HEADER_H * k
	var rh := row_height(compact(), Phone.active) * k
	if y < y0:
		return -1
	var i := int((y - y0) / rh)
	return i if i < _visible.size() else -1


func open_peer_menu(id: String, row: int) -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup_id = id
	_popup = PopupPanel.new()
	_popup.theme = UI.theme()
	_popup.add_theme_stylebox_override("panel", UI.panel_box(Color(UI.GRAPE, 0.98), 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UI.GAP_S)
	box.custom_minimum_size = Vector2(250, 0)
	_popup.add_child(box)
	var title := UI.label(voice.name_of(id), UI.SIZE_BODY, UI.BANANA)
	title.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
	box.add_child(title)
	var vol_row := HBoxContainer.new()
	vol_row.add_child(UI.label("Volume", UI.SIZE_SMALL))
	var value := UI.label("%d%%" % roundi(voice.peer_volume(id) * 100.0), UI.SIZE_SMALL)
	value.custom_minimum_size = Vector2(48, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := UI.slider(roundf(voice.peer_volume(id) * 100.0), func(v: float):
		value.text = "%d%%" % roundi(v)
		voice.set_peer_volume(id, v / 100.0)
		queue_redraw(), 200.0, 5.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol_row.add_child(slider)
	vol_row.add_child(value)
	box.add_child(vol_row)
	box.add_child(UI.toggle("Silenzia per me", voice.is_local_muted(id), func(on: bool): voice.set_local_mute(id, on)))
	var link: Dictionary = voice.links.get(id, {})
	if int(link.get("rtt", -1)) >= 0:
		box.add_child(UI.note("Ping %d ms, collegamento diretto" % int(link.rtt)))
	elif str(link.get("s", "")) == "failed":
		box.add_child(UI.note("Non riesco a collegarmi: forse una rete che blocca la voce"))
	add_child(_popup)
	var k := Access.text_scale
	var y := PAD + HEADER_H * k + row * row_height(compact(), Phone.active) * k
	var at := get_global_transform_with_canvas() * Vector2(0.0, y)
	_popup.popup(Rect2i(Vector2i(int(at.x) - 270, maxi(4, int(at.y))), Vector2i(250, 0)))
	# A sinistra del riquadro, attaccato: la larghezza vera si sa solo dopo
	_popup.position.x = maxi(4, int(at.x) - _popup.size.x - 6)


# Un'icona in un pulsante (microfono, cuffie, ingranaggio, esci)
class VoiceIcon extends Control:
	var kind := "mic"
	var slash := false

	func _draw() -> void:
		var s := minf(size.x, size.y) * 0.62
		var b := get_parent() as Button
		var col := UI.PAPER if b == null or not b.disabled else Color(UI.PAPER, 0.4)
		VoicePanel.draw_icon(self, kind, Rect2(size / 2.0 - Vector2(s, s) / 2.0, Vector2(s, s)), col, slash)
