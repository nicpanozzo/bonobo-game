# Pre-partita sopra l'arena: l'attesa di chi deve ancora dire Pronto, poi la presentazione e 3, 2, 1, VIA!
# Solo disegno: fasi e tempi li decide il server (snapshot.prematch); qui si chiede soltanto di essere pronti.
extends Control

signal ready_changed(ready: bool)

const GO_MS := 900.0 # quanto resta il VIA! dopo matchStart, ms
const PANEL_W := 560.0 # larghezza del pannello dell'attesa, pixel
const PANEL_Y := 96.0 # dove comincia il pannello, pixel dall'alto
const ROW_H := 34.0 # una riga per lottatore, pixel
const COUNT_COLORS := ["ffcf4a", "ff9a3c", "ff5a4a"] # 1, 2, 3: più si avvicina il VIA più è caldo
const GO_COLOR := Color("7dff6a")
const SYNC_MS := 1000 # dopo quanto, se il server non è d'accordo sul Pronto, vince lui, ms

var game: Dictionary
var my_id := ""
var _pre: Dictionary = {} # snapshot.prematch: {} = partita in corso (o server di prima, senza pre-partita)
var _players: Array = []
var _left_ms := 0.0 # ms al VIA: scende anche tra uno snapshot e l'altro, così i numeri non scattano
var _go_ms := 0.0 # ms rimasti del VIA!
var _asked := false # Pronto chiesto da qui: si vede subito, senza aspettare lo snapshot dopo
var _asked_at := 0 # ms dell'ultimo Pronto chiesto
var _font: Font = UI.font()
var _button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = UI.button("Sono pronto!", func(): set_ready(not is_ready()), true)
	_button.focus_mode = Control.FOCUS_NONE # niente fuoco: i tasti restano al lottatore
	_button.custom_minimum_size = Vector2(240, 0)
	_button.theme = UI.theme()
	_button.visible = false
	add_child(_button)


func reset() -> void:
	_pre = {}
	_players = []
	_left_ms = 0.0
	_go_ms = 0.0
	_asked = false
	_button.visible = false
	queue_redraw()


func on_snapshot(snap: Dictionary) -> void:
	var was_on := not _pre.is_empty()
	var pre: Variant = snap.get("prematch")
	_pre = pre if pre is Dictionary else {}
	_players = snap.get("players", [])
	for e in snap.get("events", []):
		if e.type == "matchStart" and was_on:
			_go_ms = GO_MS
	if not _pre.is_empty():
		_left_ms = float(_pre.get("leftMs", 0))
		# Il server ha l'ultima parola, ma il Pronto appena chiesto ha il tempo di arrivargli
		var server_ready: bool = _pre.get("ready", []).has(my_id)
		if server_ready == _asked or Time.get_ticks_msec() - _asked_at > SYNC_MS:
			_asked = server_ready
	else:
		_asked = false
	queue_redraw()


func waiting() -> bool:
	return _pre.get("phase", "") == "waiting"


# Al 3, 2, 1 il server tiene fermi i lottatori: la predizione si spegne, se no si vedrebbe partire e tornare indietro
func frozen() -> bool:
	return _pre.get("phase", "") == "starting"


func is_ready() -> bool:
	return _asked


func set_ready(value: bool) -> void:
	if not waiting() or value == _asked:
		return
	_asked = value
	_asked_at = Time.get_ticks_msec()
	ready_changed.emit(value)
	queue_redraw()


func _process(delta: float) -> void:
	_button.visible = waiting()
	if waiting():
		_button.text = "Non sono più pronto" if _asked else "Sono pronto!"
		_button.position = Vector2((size.x - _button.size.x) / 2, PANEL_Y + _panel_h() + 12)
	if frozen():
		_left_ms = maxf(0.0, _left_ms - delta * 1000.0)
	if _go_ms > 0:
		_go_ms -= delta * 1000.0
	if not _pre.is_empty() or _go_ms > 0:
		queue_redraw()


func _draw() -> void:
	var w: float = size.x if size.x > 0 else game.world.width
	var h: float = size.y if size.y > 0 else game.world.height
	if waiting():
		_draw_waiting(w)
	elif frozen():
		_draw_countdown(w, h)
	elif _go_ms > 0:
		_draw_big("VIA!", Vector2(w / 2, h * 0.42), 200, GO_COLOR, 1.0 - _go_ms / GO_MS)


func _panel_h() -> float:
	return 120.0 + _players.size() * ROW_H


func _draw_waiting(w: float) -> void:
	var r := Rect2(w / 2 - PANEL_W / 2, PANEL_Y, PANEL_W, _panel_h())
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.04, 0.1, 0.82)
	box.border_color = Color("ffcf4a")
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	draw_style_box(box, r)
	var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 400.0) % 3)
	_centered("IN ATTESA DEI LOTTATORI" + dots, Vector2(w / 2, r.position.y + 42), 30, Color("ffcf4a"))
	var y := r.position.y + 82
	for p in _players:
		var on: bool = _asked if p.id == my_id else _pre.ready.has(p.id)
		draw_circle(Vector2(r.position.x + 34, y - 7), 9, Color.hex((int(p.get("color", 0xffffff)) << 8) | 0xff))
		var label: String = str(p.get("name", "?")) + (" (tu)" if p.id == my_id else "")
		_outlined(label, Vector2(r.position.x + 54, y), 22, Color.WHITE)
		var tag := "PRONTO!" if on else "si sta scaldando"
		var size_px := Access.px(20)
		var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		_outlined(tag, Vector2(r.end.x - 24 - tw, y), 20, GO_COLOR if on else Color("9a9aa8"))
		y += ROW_H
	_centered(hint(_players.size(), _asked, _pre.get("autoStartMs")), Vector2(w / 2, r.end.y - 18), 18, Color("d8d8e8"))


# La riga in fondo al pannello: cosa fare adesso
static func hint(players: int, me_ready: bool, auto_start_ms: Variant) -> String:
	if players < 2:
		return "Manda il link agli amici: si comincia appena arriva qualcuno"
	var text := "Aspettiamo gli altri" if me_ready else "Provoca (T) o premi Invio quando sei pronto"
	if auto_start_ms != null:
		text += " · si parte comunque tra %d s" % ceili(float(auto_start_ms) / 1000.0)
	return text


# Il numero del conto alla rovescia: "" durante la presentazione, poi "3", "2", "1"
static func count_label(left_ms: float, countdown_ms: float) -> String:
	if left_ms > countdown_ms:
		return ""
	return str(clampi(ceili(left_ms / 1000.0), 1, 9))


func _draw_countdown(w: float, h: float) -> void:
	var countdown: float = float(game.get("prematch", {}).get("countdownMs", 3000))
	var label := count_label(_left_ms, countdown)
	if label == "":
		_draw_big("PREPARATEVI!", Vector2(w / 2, h * 0.42), 96, Color("ffcf4a"), 0.0)
		return
	var n := int(label)
	var into := 1.0 - fmod(_left_ms, 1000.0) / 1000.0 # da 0 a 1 dentro il secondo di questo numero
	_draw_big(label, Vector2(w / 2, h * 0.42), 220, Color(COUNT_COLORS[clampi(n - 1, 0, 2)]), into)


# Testo enorme che arriva grande e si assesta, poi sfuma: t da 0 (appena comparso) a 1
func _draw_big(text: String, center: Vector2, px: int, color: Color, t: float) -> void:
	var pop := 1.0 + 0.7 * pow(1.0 - clampf(t * 3.0, 0.0, 1.0), 3.0)
	color.a = 1.0 - smoothstep(0.75, 1.0, t)
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	draw_set_transform(center, 0.0, Vector2(pop, pop))
	var at := Vector2(-s.x / 2, s.y * 0.3)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 14, Color(0, 0, 0, color.a))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
	draw_set_transform(Vector2.ZERO)


func _centered(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Access.px(size_px))
	_outlined(text, Vector2(pos.x - s.x / 2, pos.y), size_px, color)


func _outlined(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	size_px = Access.px(size_px)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, Color.BLACK)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
