# Le scritte sopra la sala d'attesa 3D (hall_view.gd): codice della stanza con "Copia link", chi c'è (pronto, voto,
# corona di chi ha creato la stanza, bot), cosa si giocherebbe adesso, il conto alla rovescia enorme al centro,
# cosa manca per partire e i tasti. Legge solo l'HallSnapshot: le scelte si fanno camminando nella sala.
extends Control

signal copy_link_requested

const HallIcons := preload("res://scripts/hall_icons.gd")

const MARGIN := 16.0 # dal bordo dello schermo, pixel
const LIST_W := 290.0 # larghezza della colonna dei giocatori, pixel
const MODE_NAMES := {"ffa": "Tutti contro tutti", "teams": "A squadre", "flag": "Ruba bandiera", "race": "Corsa"}
const PUNCH_S := 0.35 # quanto dura il colpo di un numero del conto alla rovescia, secondi

var my_id := ""
var room_code := "":
	set(v):
		room_code = v
		if _code != null:
			_code.text = v.to_upper() if v != "" else "—"
var settings: Settings = null # se main.gd lo passa, i tasti del suggerimento sono quelli scelti dal giocatore

var game: Dictionary
var _snap: Dictionary = {}
var _labels := {} # "mode/ffa" -> scritta della pedana
var _room_card: PanelContainer
var _code: Label
var _copy: Button
var _list: VBoxContainer
var _list_sig := ""
var _layout_sig := ""
var _lead_card: PanelContainer
var _lead_mode: Label
var _lead_stage: Label
var _lead_rules: Label # le regole di chi ha creato la stanza: vite, tempo, oggetti
var _count: Label
var _count_left := -1.0 # ms al via, scende anche tra uno snapshot e l'altro
var _count_shown := ""
var _punch := 0.0
var _need_card: PanelContainer
var _need: Label
var _hint: Label
var _hoops_card: PanelContainer # i canestri di questa sala: i primi tre
var _hoops_rows: VBoxContainer
var _hoops_sig := "-"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(game_data: Dictionary) -> void:
	game = game_data
	for c in get_children():
		c.queue_free()
	# vignetta: i bordi dello schermo più scuri, la sala sembra più profonda e le scritte si leggono meglio
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.12), Color(0.01, 0.0, 0.04, 0.6)])
	var vt := GradientTexture2D.new()
	vt.gradient = g
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.0, 1.0)
	vt.width = 128
	vt.height = 128
	var vignette := TextureRect.new()
	vignette.texture = vt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# in alto a sinistra: la stanza e chi c'è
	_room_card = _card(Color(0.04, 0.02, 0.1, 0.78), UI.ACCENT)
	add_child(_room_card)
	var room_box := VBoxContainer.new()
	room_box.add_theme_constant_override("separation", 6)
	_room_card.add_child(room_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	room_box.add_child(top)
	var room_l := _label("STANZA", UI.SIZE_NOTE, Color(1, 1, 1, 0.6))
	room_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(room_l)
	_code = _label(room_code.to_upper() if room_code != "" else "—", UI.SIZE_BIG, UI.ACCENT)
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_code)
	_copy = UI.small_button("Copia link", func(): copy_link_requested.emit())
	_copy.focus_mode = Control.FOCUS_NONE # in sala i tasti muovono il lottatore, non il fuoco
	top.add_child(_copy)
	var sep := ColorRect.new()
	sep.color = Color(UI.ACCENT, 0.35)
	sep.custom_minimum_size = Vector2(0, 2)
	room_box.add_child(sep)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	room_box.add_child(_list)
	# in alto a destra: cosa si giocherebbe adesso
	_lead_card = _card(Color(0.04, 0.02, 0.1, 0.78), Color("b06bff"))
	add_child(_lead_card)
	var lead_box := VBoxContainer.new()
	lead_box.add_theme_constant_override("separation", 2)
	_lead_card.add_child(lead_box)
	var lead_l := _label("SI GIOCA", UI.SIZE_NOTE, Color(1, 1, 1, 0.6))
	lead_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lead_box.add_child(lead_l)
	_lead_mode = _label("", UI.SIZE_BIG, Color.WHITE)
	_lead_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lead_box.add_child(_lead_mode)
	_lead_stage = _label("", UI.SIZE_BODY, UI.ACCENT)
	_lead_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lead_box.add_child(_lead_stage)
	_lead_rules = _label("", UI.SIZE_NOTE, Color(1, 1, 1, 0.7))
	_lead_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lead_box.add_child(_lead_rules)
	# sotto: la classifica dei canestri della sala, solo quando qualcuno ne ha fatto uno
	_hoops_card = _card(Color(0.04, 0.02, 0.1, 0.72), Color("ff7a1a"))
	_hoops_card.visible = false
	add_child(_hoops_card)
	var hoops_box := VBoxContainer.new()
	hoops_box.add_theme_constant_override("separation", 2)
	_hoops_card.add_child(hoops_box)
	var hoops_top := HBoxContainer.new()
	hoops_top.alignment = BoxContainer.ALIGNMENT_END
	hoops_top.add_theme_constant_override("separation", 6)
	hoops_box.add_child(hoops_top)
	hoops_top.add_child(_label("CANESTRI", UI.SIZE_NOTE, Color(1, 1, 1, 0.6)))
	hoops_top.add_child(_icon(HallIcons.basketball(), 16))
	_hoops_rows = VBoxContainer.new()
	_hoops_rows.add_theme_constant_override("separation", 0)
	hoops_box.add_child(_hoops_rows)
	# al centro: il conto alla rovescia
	_count = _label("", 190, UI.ACCENT)
	_count.add_theme_color_override("font_outline_color", Color("3a1600"))
	_count.add_theme_constant_override("outline_size", 22)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.visible = false
	add_child(_count)
	# in basso: cosa manca e i tasti
	_need_card = _card(Color(0.04, 0.02, 0.1, 0.82), UI.OK)
	add_child(_need_card)
	_need = _label("", UI.SIZE_SMALL if Phone.active else UI.SIZE_BODY, Color.WHITE)
	_need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_need_card.add_child(_need)
	_hint = _label(controls_hint(settings), UI.SIZE_NOTE, Color(1, 1, 1, 0.75))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 6)
	add_child(_hint)
	resized.connect(_layout)
	_layout()


func on_snapshot(snap: Dictionary) -> void:
	if game.is_empty():
		setup({})
	_snap = snap
	_labels.clear()
	for z in snap.get("zones", []):
		if z is Dictionary:
			_labels["%s/%s" % [z.get("kind", ""), z.get("id", "")]] = str(z.get("label", ""))
	_update_list(snap.get("players", []) if snap.get("players") is Array else [])
	var leading: Dictionary = snap.get("leading", {}) if snap.get("leading") is Dictionary else {}
	_lead_mode.text = mode_name(str(leading.get("mode", "ffa")))
	_lead_stage.text = stage_name(str(leading.get("stageId", "")))
	_lead_rules.text = rules_text(snap.get("rules", {}) if snap.get("rules") is Dictionary else {}, str(leading.get("mode", "ffa")))
	_lead_rules.visible = _lead_rules.text != ""
	_update_hoops(snap.get("players", []) if snap.get("players") is Array else [])
	var cd: Variant = snap.get("countdownMs")
	_count_left = float(cd) if cd != null else -1.0
	var need: Variant = snap.get("need")
	_need.text = need_text(need, _count_left >= 0.0)
	_need_card.visible = _need.text != ""
	# si rifà la disposizione solo quando cambia qualcosa che ha una misura (30 snapshot al secondo)
	var sig := "%s|%s|%s|%s|%s|%s|%s" % [_list_sig, _need.text, _lead_mode.text, _lead_stage.text, _lead_rules.text, size, _hoops_sig]
	if sig != _layout_sig:
		_layout_sig = sig
		_layout()


func _process(delta: float) -> void:
	if _count == null:
		return
	if _count_left >= 0.0:
		_count_left = maxf(0.0, _count_left - delta * 1000.0)
	var text := count_text(_count_left)
	if text != _count_shown:
		_count_shown = text
		_count.text = text
		_punch = 1.0 if text != "" else 0.0
	_count.visible = text != ""
	if _count.visible:
		_punch = maxf(0.0, _punch - delta / PUNCH_S)
		var e := _punch * _punch
		_count.pivot_offset = _count.size / 2.0
		_count.scale = Vector2.ONE * (1.0 + e * 0.8)
		_count.modulate = Color(1, 1, 1, 1.0 - e * 0.3)
		# più si avvicina il via più è caldo
		var n := text.to_int()
		_count.add_theme_color_override("font_color", UI.ACCENT if n >= 4 else (Color("ff9a3c") if n >= 2 else Color("ff5a4a")))


# Il numero del conto alla rovescia: "5", "4", ... "1", mai 0; "" senza conto
static func count_text(left_ms: float) -> String:
	if left_ms < 0.0:
		return ""
	return str(maxi(1, ceili(left_ms / 1000.0)))


# Cosa manca per partire: quello che dice il server, o l'invito al cerchio; durante il conto niente
static func need_text(need: Variant, counting: bool) -> String:
	if counting:
		return ""
	if need != null and str(need) != "":
		return str(need)
	return "Tutti nel cerchio dei pronti per partire!"


# Le regole della stanza in una riga ("3 vite · 4 min · oggetti"); la modalità è quella in testa al voto
static func rules_text(rules: Dictionary, mode: String) -> String:
	if rules.is_empty():
		return ""
	var parts: Array[String] = []
	var stocks := int(rules.get("stocks", 0))
	if mode == "flag":
		parts.append("%d punti" % stocks if stocks > 0 else "")
	elif mode != "race" and stocks > 0:
		parts.append("1 vita" if stocks == 1 else "%d vite" % stocks)
	var sec := int(rules.get("timeLimitSec", 0))
	if sec > 0:
		parts.append("%d min" % (sec / 60) if sec % 60 == 0 else "%d:%02d" % [sec / 60, sec % 60])
	else:
		parts.append("senza tempo")
	var items: Variant = rules.get("itemKinds")
	var has_items := int(rules.get("itemAmount", 0)) > 0 and (not (items is Array) or not (items as Array).is_empty())
	parts.append("oggetti" if has_items else "senza oggetti")
	return " · ".join(parts.filter(func(x: String): return x != ""))


func mode_name(id: String) -> String:
	return str(_labels.get("mode/" + id, MODE_NAMES.get(id, id)))


func stage_name(id: String) -> String:
	if id == "":
		return ""
	if _labels.has("stage/" + id):
		return str(_labels["stage/" + id])
	var stages: Variant = game.get("stages")
	if stages is Dictionary and stages.has(id):
		return str(stages[id].get("name", id))
	return "Arena a sorpresa" if id == "casuale" else id


# Il suggerimento dei tasti, coi tasti scelti nelle opzioni (o quelli di base)
static func controls_hint(s: Settings) -> String:
	var keys := func(action: String) -> String:
		var list: Array = s.bindings.get(action, []) if s != null else Settings.DEFAULT_BINDINGS.get(action, [])
		return Settings.key_label(int(list[0])) if not list.is_empty() else "?"
	var move := "Frecce/WASD"
	if s != null:
		move = "%s %s %s %s" % [keys.call("up"), keys.call("left"), keys.call("down"), keys.call("right")]
	return "Muoviti: %s  ·  Salta: %s  ·  %s spingi, tira (col pallone)  ·  %s prendi, cambia colore sul piedistallo  ·  %s inchino" % [
		move, keys.call("jump"), keys.call("light"), keys.call("heavy"), keys.call("taunt")]


# I primi tre per canestri fatti in questa sala (chi ne ha almeno uno): [{name, baskets, color, me}]
static func hoop_leaders(players: Array, me := "") -> Array:
	var list := []
	for p in players:
		if p is Dictionary and int(p.get("baskets", 0)) > 0:
			list.append({"name": str(p.get("name", "")), "baskets": int(p.get("baskets", 0)), "color": p.get("color", 0xffffff), "me": str(p.get("id", "")) == me})
	list.sort_custom(func(a, b): return a.baskets > b.baskets if a.baskets != b.baskets else a.name < b.name)
	return list.slice(0, 3)


func _update_hoops(players: Array) -> void:
	var leaders := hoop_leaders(players, my_id)
	var sig := JSON.stringify(leaders)
	if sig == _hoops_sig:
		return
	_hoops_sig = sig
	for c in _hoops_rows.get_children():
		c.queue_free()
	for i in leaders.size():
		var r: Dictionary = leaders[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var dot := ColorRect.new()
		dot.color = Access.color(r.color)
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var who := _label("%s" % r.name, UI.SIZE_NOTE if Phone.active else UI.SIZE_SMALL, UI.ACCENT if r.me else Color.WHITE)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(who)
		row.add_child(_label(str(r.baskets), UI.SIZE_SMALL, Color("ffb04a")))
		_hoops_rows.add_child(row)
	_hoops_card.visible = not leaders.is_empty()


func _icon(tex: Texture2D, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _update_list(players: Array) -> void:
	var sig := ""
	for p in players:
		if p is Dictionary:
			sig += "%s|%s|%s|%s|%s|%s|%s|%s|%s;" % [p.get("id"), p.get("name"), p.get("color"), p.get("ready"), p.get("modeVote"), p.get("bot"), p.get("away"), p.get("host"), p.get("throne")]
	if sig == _list_sig:
		return
	_list_sig = sig
	for c in _list.get_children():
		c.queue_free()
	for p in players:
		if p is Dictionary:
			_list.add_child(_player_row(p))


# Una riga della lista: pallino del colore, nome, corona, bot, voto, spunta dei pronti
func _player_row(p: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.modulate = Color(1, 1, 1, 0.45 if p.get("away", false) else 1.0)
	var dot := ColorRect.new()
	dot.color = Access.color(p.get("color", 0xffffff))
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var mine := str(p.get("id", "")) == my_id
	var who := _label(str(p.get("name", "")) + (" (tu)" if mine else ""), UI.SIZE_NOTE if Phone.active else UI.SIZE_SMALL, UI.ACCENT if mine else Color.WHITE)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(who)
	if p.get("host", false):
		var crown := CrownIcon.new()
		crown.custom_minimum_size = Vector2(18, 14)
		crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crown)
	if p.get("bot", false):
		row.add_child(_tag("BOT", Color("2ecc71")))
	if p.get("throne", false):
		row.add_child(_tag("RE", UI.ACCENT))
	var vote: Variant = p.get("modeVote")
	if vote != null and str(vote) != "":
		row.add_child(_tag(short_mode(str(vote)), Color("b06bff")))
	var check := TextureRect.new()
	check.texture = HallIcons.check()
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.custom_minimum_size = Vector2(18, 18)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.modulate = Color(1, 1, 1, 1.0 if p.get("ready", false) else 0.0) # il posto resta: le righe non ballano
	row.add_child(check)
	return row


static func short_mode(id: String) -> String:
	match id:
		"ffa": return "TUTTI"
		"teams": return "SQUADRE"
		"flag": return "BANDIERA"
		"race": return "CORSA"
	return id.to_upper()


func _tag(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(col, 0.25)
	box.border_color = col
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", box)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_label(text, 11, col.lightened(0.35)))
	return p


func _layout() -> void:
	if _room_card == null:
		return
	var s := size
	if s.x <= 0.0:
		return
	var phone := Phone.active
	var m := MARGIN * (0.75 if phone else 1.0)
	var list_w := minf(LIST_W if not phone else 240.0, s.x * 0.36)
	_room_card.position = Vector2(m, m)
	_room_card.size = Vector2(list_w, 0)
	_room_card.reset_size()
	_room_card.size.x = list_w
	var lead_w := minf(300.0 if not phone else 240.0, s.x * 0.34)
	_lead_card.reset_size()
	_lead_card.size.x = lead_w
	_lead_card.position = Vector2(s.x - lead_w - m, m)
	var hoops_w := minf(220.0 if not phone else 180.0, s.x * 0.28)
	_hoops_card.reset_size()
	_hoops_card.size.x = hoops_w
	_hoops_card.position = Vector2(s.x - hoops_w - m, _lead_card.position.y + _lead_card.size.y + 10.0)
	_count.size = Vector2(s.x * 0.4, s.y * 0.4)
	_count.position = Vector2(s.x * 0.3, s.y * 0.18)
	_hint.visible = not phone # sul telefono ci sono i tasti a schermo, e lo spazio in basso è loro
	_hint.size = Vector2(s.x - m * 2.0, 22)
	_hint.position = Vector2(m, s.y - m - 20)
	# la richiesta in basso al centro, su una riga: sul telefono tra la levetta e i tasti a schermo, più stretta
	var need_w := minf(440.0, s.x * 0.5) if phone else minf(640.0, s.x - m * 2.0)
	_need.custom_minimum_size = Vector2(need_w - 28, 0)
	_need.autowrap_mode = TextServer.AUTOWRAP_OFF
	_need.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_need.clip_text = true
	_need_card.reset_size()
	_need_card.size.x = need_w
	var bottom := s.y - m if phone else s.y - m - 20 - 8
	_need_card.position = Vector2((s.x - need_w) / 2.0, bottom - _need_card.size.y)


func _label(text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI.font(UI.WEIGHT_BOLD))
	l.add_theme_font_size_override("font_size", Access.px(font_size))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _card(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Color(border, 0.7)
	box.border_width_left = 0
	box.border_width_top = 0
	box.border_width_right = 0
	box.border_width_bottom = 3
	box.set_corner_radius_all(UI.RADIUS_CARD)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


# La coroncina di chi ha creato la stanza (il font non ha il simbolo)
class CrownIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.3), Vector2(w * 0.25, h * 0.6), Vector2(w * 0.5, 0),
			Vector2(w * 0.75, h * 0.6), Vector2(w, h * 0.3), Vector2(w, h)])
		draw_colored_polygon(pts, UI.ACCENT)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("7a3b00"), 1.0)
