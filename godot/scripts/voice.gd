# Chat vocale tra chi è nella stanza, come su Discord: audio diretto tra i giocatori (WebRTC del browser),
# il server fa solo da centralino (messaggi voice e voiceState, vedi src/shared/types.ts).
# Qui c'è la parte che decide: chi collegare e con che ruolo, silenzia e disattiva audio, volumi,
# audio di posizione in sala, tasti, bip. L'audio vero lo fa il JavaScript di voice_web.gd, dietro
# un "ponte" (WebBridge qui sotto) che nei test si sostituisce con uno finto.
# Fuori dal browser (app desktop) la voce non c'è: supported resta false e il pannello lo dice.
class_name VoiceChat
extends Node

signal changed # chi c'è, chi è silenziato, entrato o uscito: il pannello si rifà
signal levels_changed # livelli della voce, circa 15 volte al secondo: anelli verdi e misuratore
signal speaking_changed(id: String, on: bool) # per la sala: chi sta parlando
signal muted_changed(id: String, muted: bool) # per la sala: microfono spento o audio disattivato
signal signal_out(to: String, kind: String, data: String) # main.gd lo manda col messaggio voice
signal state_out(state: Dictionary) # main.gd lo manda col messaggio voiceState
signal notice(text: String, warn: bool) # un avviso a tempo (main.gd lo mostra con UI.toast)
signal devices_changed

enum { OFF, JOINING, ON }

const VoiceWeb := preload("res://scripts/voice_web.gd")
const MAX_SIGNAL := 8192 # come VOICE.maxSignalBytes: il server scarta i messaggi più lunghi
# Anelli verdi: sopra questo livello (0..1, da -60 a 0 dB) uno sta parlando, e lo resta per HOLD_MS
const SPEAK_LEVEL := 0.22
const HOLD_MS := 300
# Audio di posizione in sala (cm): pieno fino a NEAR_CM, poi scende fino a FLOOR a FAR_CM e oltre
const SPATIAL_NEAR_CM := 400.0
const SPATIAL_FAR_CM := 2000.0
const SPATIAL_FLOOR := 0.25 # chi è lontano si sente ancora: la sala è piccola e si sta insieme
const PAN_CM := 1000.0 # a 10 m di lato la voce è tutta da quella parte (fino a PAN_MAX)
const PAN_MAX := 0.7 # mai del tutto in un orecchio solo: con le cuffie stanca
const GAIN_STEP := 0.02 # sotto questa differenza non si riscrive il volume al browser
const UNKNOWN_NAME := "Giocatore"

static var current: VoiceChat # quello della partita in corso, per opzioni e menu di pausa
static var _hinted := false # l'avviso "Premi V per parlare" già mostrato

var settings: Settings
var bridge: Object # WebBridge nel browser, uno finto nei test, null dove la voce non c'è
var supported := false
var my_id := ""
var phase := OFF
var muted := false
var deafened := false
var ice_servers: Array = []
var states := {} # id → {on, muted, deafened}: dal server, anche di chi non è collegato con noi
var peers := {} # id → true: collegati nel browser
var roster := {} # id → {name, color, look}: dagli snapshot
var levels := {} # id → livello 0..1 della voce (my_id = il proprio microfono)
var links := {} # id → {s: "connecting"/"connected"/"failed", q: qualità 0..3, rtt: ms}
var gate_open := false # il proprio microfono sta mandando voce
var devices: Array = [] # [{id, label}] dei microfoni
var testing := false # prova del microfono dalle opzioni
var spatial_on := false # in sala: volume e lato per posizione
var hotkeys := true # main.gd li spegne fuori dalla stanza
var error := ""

var _speaking := {} # id → ms dell'ultima volta sopra la soglia
var _speaking_on := {} # id → true finché parla
var _spatial := {} # id → Vector2(gain, pan) mandato al browser
var _sent_volume := {} # id → volume mandato al browser
var _ptt_down := false
var _muted_before_deafen := false
var _auto_tried := false # entrata automatica già tentata in questa stanza
var _sounds := {}
var _player := AudioStreamPlayer.new()


# b: il ponte da usare (nei test); senza, nel browser si crea quello vero
func setup(s: Settings, b: Object = null) -> void:
	settings = s
	bridge = b
	if bridge == null and OS.has_feature("web"):
		bridge = WebBridge.new(on_bridge_event)
	supported = bridge != null
	if bridge != null:
		bridge.set_mode(str(settings.voice.mode))
		bridge.set_vad_threshold(float(settings.voice.vad_threshold))
		bridge.set_output_volume(float(settings.voice.volume))
	settings.changed.connect(_apply_settings)
	_player.bus = "Effetti" if AudioServer.get_bus_index("Effetti") >= 0 else "Master"
	_player.volume_db = -8.0
	if _player.get_parent() == null:
		add_child(_player)


func _exit_tree() -> void:
	if current == self:
		current = null


func is_on() -> bool:
	return phase == ON


# ---- Dal server ----

# Il welcome di una stanza: con un id nuovo (rientro dopo una caduta) i vecchi collegamenti non valgono più
func on_welcome(id: String) -> void:
	if id != my_id and my_id != "":
		_drop_peers()
	my_id = id


# Subito dopo il welcome: server STUN/TURN e chi è già in voce
func on_config(data: Dictionary) -> void:
	ice_servers = data.get("iceServers", []) if data.get("iceServers") is Array else []
	var fresh := {}
	for st in data.get("states", []) if data.get("states") is Array else []:
		if st is Dictionary and str(st.get("id", "")) != "":
			fresh[str(st.id)] = _clean_state(st)
	# Chi era in voce e non c'è più: si chiude
	for id in states.keys():
		if not fresh.has(id):
			_peer_gone(id)
	states = fresh
	if phase == ON:
		_announce() # dopo una caduta il server ci ha dimenticati: si ridice che siamo in voce
		_connect_all()
	elif phase == OFF and supported and not _auto_tried and bool(settings.voice.auto_join):
		_auto_tried = true
		join()
	for id in states:
		muted_changed.emit(id, states[id].muted or states[id].deafened)
	changed.emit()


func on_state(data: Dictionary) -> void:
	var id := str(data.get("id", ""))
	if id == "" or id == my_id:
		return
	var st := _clean_state(data)
	var was: Dictionary = states.get(id, {})
	states[id] = st
	if not st.on:
		states.erase(id)
		if was.get("on", false):
			_peer_gone(id)
			if phase == ON:
				_bleep("peer_leave")
	elif phase == ON and not peers.has(id):
		_add_peer(id)
		if not was.get("on", false):
			_bleep("peer_join")
	if was.get("muted") != st.get("muted") or was.get("deafened") != st.get("deafened"):
		muted_changed.emit(id, st.on and (st.muted or st.deafened))
	changed.emit()


func on_signal(data: Dictionary) -> void:
	if phase != ON:
		return
	var from := str(data.get("from", ""))
	var kind := str(data.get("kind", ""))
	if from == "" or from == my_id or not kind in ["offer", "answer", "ice", "bye"]:
		return
	if kind == "bye":
		_peer_gone(from)
		changed.emit()
		return
	if not peers.has(from):
		_add_peer(from) # l'offerta è arrivata prima del suo voiceState: va bene lo stesso
	bridge.signal_in(from, kind, str(data.get("data", "")))


# ---- Comandi di chi gioca ----

func join() -> void:
	if not supported:
		notice.emit("La chat vocale funziona nel browser", true)
		return
	if phase != OFF:
		return
	phase = JOINING
	error = ""
	bridge.join({
		"myId": my_id, "iceServers": ice_servers, "mode": str(settings.voice.mode),
		"vad": float(settings.voice.vad_threshold), "muted": muted, "deafened": deafened,
		"deviceId": str(settings.voice.device), "out": float(settings.voice.volume),
	})
	changed.emit()


func leave() -> void:
	if phase == OFF:
		return
	var was_on := phase == ON
	for id in peers:
		_send(id, "bye", "")
	_drop_peers()
	bridge.leave()
	phase = OFF
	gate_open = false
	_set_ptt(false)
	_set_speaking(my_id, false)
	if was_on:
		state_out.emit({"on": false, "muted": muted, "deafened": deafened})
		_bleep("leave")
	changed.emit()


func toggle_join() -> void:
	if phase == OFF:
		join()
	else:
		leave()


# Microfono: come su Discord, riaccenderlo a audio disattivato riaccende anche l'audio
func toggle_mute() -> void:
	if deafened:
		deafened = false
		muted = false
	else:
		muted = not muted
	_push_mute()
	_bleep("mute" if muted else "unmute")


# Disattiva audio: non senti nessuno e il microfono si spegne; riattivandolo il microfono torna com'era
func toggle_deafen() -> void:
	deafened = not deafened
	if deafened:
		_muted_before_deafen = muted
	else:
		muted = _muted_before_deafen
	_push_mute()
	_bleep("mute" if deafened else "unmute")


func effective_muted() -> bool:
	return muted or deafened


# Uscita dalla stanza: si chiude tutto senza salutare (il server sa già che non ci siamo)
func reset_room() -> void:
	if phase != OFF and bridge != null:
		bridge.leave()
	peers.clear()
	states.clear()
	roster.clear()
	levels.clear()
	links.clear()
	_spatial.clear()
	_sent_volume.clear()
	for id in _speaking_on.keys():
		_set_speaking(id, false)
	phase = OFF
	gate_open = false
	_ptt_down = false
	my_id = ""
	_auto_tried = false
	spatial_on = false
	changed.emit()


func set_peer_volume(id: String, v: float) -> void:
	var name := name_of(id)
	settings.voice_volumes[name] = clampf(v, 0.0, 2.0)
	if is_equal_approx(v, 1.0):
		settings.voice_volumes.erase(name)
	settings.save()
	_apply_peer(id)


func peer_volume(id: String) -> float:
	return float(settings.voice_volumes.get(name_of(id), 1.0))


# Silenziato solo per me (non lo sente nessun altro)
func set_local_mute(id: String, on: bool) -> void:
	if on:
		settings.voice_muted[name_of(id)] = true
	else:
		settings.voice_muted.erase(name_of(id))
	settings.save()
	_apply_peer(id)
	changed.emit()


func is_local_muted(id: String) -> bool:
	return settings.voice_muted.has(name_of(id))


func set_input_device(id: String) -> void:
	settings.voice.device = id
	settings.save()
	if bridge != null:
		bridge.set_input_device(id)


func refresh_devices() -> void:
	if bridge != null:
		bridge.list_devices()


func test_mic(on: bool) -> void:
	testing = on and supported
	if bridge != null:
		bridge.test_mic(on, true)
	if not on:
		levels.erase(my_id)
		levels_changed.emit()


# ---- Snapshot: nomi e, in sala, posizioni ----

# I giocatori della sala o della partita: nome, colore e lottatore per il pannello
func set_roster(players: Array) -> void:
	var any_new := false
	for p in players:
		if not p is Dictionary or str(p.get("id", "")) == "":
			continue
		var id := str(p.id)
		var entry: Dictionary = roster.get(id, {})
		var name := str(p.get("name", UNKNOWN_NAME))
		var renamed: bool = entry.get("name", "") != name
		entry.name = name
		entry.color = p.get("color", 0xffffff)
		entry.char = str(p.get("characterId", ""))
		entry.skin = str(p.get("skinId", p.get("skin", "")))
		roster[id] = entry
		if renamed:
			any_new = true
			_apply_peer(id) # il volume scelto va per nome
	if any_new:
		changed.emit()


# Sala d'attesa: chi è vicino si sente forte, chi è lontano piano, da destra o sinistra
func on_hall_snapshot(snap: Dictionary) -> void:
	var players: Array = snap.get("players", []) if snap.get("players") is Array else []
	set_roster(players)
	spatial_on = bool(settings.voice.spatial)
	var me := {}
	for p in players:
		if p is Dictionary and str(p.get("id", "")) == my_id:
			me = p
	for p in players:
		if not p is Dictionary:
			continue
		var id := str(p.get("id", ""))
		if id == my_id or not peers.has(id):
			continue
		var g := Vector2(1.0, 0.0)
		if spatial_on and not me.is_empty():
			var d := Vector2(float(p.get("x", 0.0)) - float(me.get("x", 0.0)), float(p.get("z", 0.0)) - float(me.get("z", 0.0)))
			g = Vector2(spatial_gain(d.length()), spatial_pan(d.x))
		_set_spatial(id, g)


# In partita tutti a volume pieno, al centro
func on_match_snapshot(players: Array) -> void:
	set_roster(players)
	if spatial_on or not _spatial.is_empty():
		spatial_on = false
		for id in peers:
			_set_spatial(id, Vector2(1.0, 0.0))


static func spatial_gain(dist_cm: float) -> float:
	if dist_cm <= SPATIAL_NEAR_CM:
		return 1.0
	var t := clampf((dist_cm - SPATIAL_NEAR_CM) / (SPATIAL_FAR_CM - SPATIAL_NEAR_CM), 0.0, 1.0)
	return lerpf(1.0, SPATIAL_FLOOR, t)


static func spatial_pan(dx_cm: float) -> float:
	return clampf(dx_cm / PAN_CM, -1.0, 1.0) * PAN_MAX


# Ruolo nella "perfect negotiation": l'educato cede se le offerte si incrociano. Educato = id più piccolo
static func polite(mine: String, other: String) -> bool:
	return mine < other


# ---- Per il pannello ----

func name_of(id: String) -> String:
	return str(roster.get(id, {}).get("name", UNKNOWN_NAME))


func in_voice_count() -> int:
	var n := 1 if phase == ON else 0
	for id in states:
		if states[id].on and id != my_id:
			n += 1
	return n


func is_speaking(id: String) -> bool:
	return _speaking_on.has(id)


# Chi è in voce, io per primo e poi per nome: {id, name, color, char, skin, me, muted, deafened, speaking, level, quality, state, local_muted}
func participants() -> Array:
	var out := []
	if phase != OFF:
		out.append(_row(my_id, true, muted, deafened))
	var others := []
	for id in states:
		if states[id].on and id != my_id:
			others.append(_row(id, false, states[id].muted, states[id].deafened))
	others.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	out.append_array(others)
	return out


func _row(id: String, me: bool, m: bool, d: bool) -> Dictionary:
	var r: Dictionary = roster.get(id, {})
	var link: Dictionary = links.get(id, {})
	var state := "connected" if me else ("off" if phase != ON else str(link.get("s", "connecting")))
	return {
		"id": id, "name": str(r.get("name", UNKNOWN_NAME)), "color": r.get("color", 0xffffff), "char": str(r.get("char", "")),
		"skin": str(r.get("skin", "")), "me": me, "muted": m, "deafened": d, "speaking": is_speaking(id),
		"level": float(levels.get(id, 0.0)), "quality": int(link.get("q", 3 if me else 0)), "state": state,
		"rtt": int(link.get("rtt", -1)), "local_muted": not me and is_local_muted(id), "joining": me and phase == JOINING,
	}


# ---- Dal ponte (browser) ----

func on_bridge_event(type: String, payload: Variant) -> void:
	match type:
		"signal":
			if payload is Dictionary and phase == ON:
				_send(str(payload.get("to", "")), str(payload.get("kind", "")), str(payload.get("data", "")))
		"joined":
			_on_joined(payload if payload is Dictionary else {})
		"levels":
			if payload is Dictionary:
				_on_levels(payload)
		"devices":
			devices = payload if payload is Array else []
			devices_changed.emit()
		"error":
			# Gli errori di collegamento si riprovano da soli: si scrivono e basta
			push_warning("voce: %s" % [payload])
			if payload is Dictionary and str(payload.get("where", "")) == "test":
				testing = false
				notice.emit(mic_error_text(str(payload.get("message", "error"))), true)
				levels_changed.emit()


func _on_joined(p: Dictionary) -> void:
	if phase != JOINING:
		return
	if not p.get("ok", false):
		phase = OFF
		error = str(p.get("error", "error"))
		notice.emit(mic_error_text(error), true)
		changed.emit()
		return
	phase = ON
	_announce()
	_connect_all()
	_bleep("join")
	if not _hinted: # una volta per sessione: poi si sa
		_hinted = true
		notice.emit(join_hint(), false)
	refresh_devices()
	changed.emit()


func _on_levels(p: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var mine := float(p.get("me", 0.0))
	gate_open = bool(p.get("open", false))
	if my_id != "" or testing:
		levels[my_id] = mine
	# Io parlo se il microfono manda davvero (cancello aperto) e c'è voce
	_track(my_id, gate_open and phase == ON and not effective_muted() and mine > minf(SPEAK_LEVEL, float(settings.voice.vad_threshold)), now)
	var remote: Dictionary = p.get("peers", {}) if p.get("peers") is Dictionary else {}
	for id in remote:
		var r: Dictionary = remote[id] if remote[id] is Dictionary else {}
		var l := float(r.get("l", 0.0))
		levels[id] = l
		var old_s := str(links.get(id, {}).get("s", ""))
		links[id] = {"s": str(r.get("s", "connecting")), "q": int(r.get("q", 0)), "rtt": int(r.get("rtt", -1))}
		if old_s != links[id].s:
			changed.emit()
		var st: Dictionary = states.get(id, {})
		_track(id, l > SPEAK_LEVEL and not st.get("muted", false) and not is_local_muted(id), now)
	levels_changed.emit()


func _track(id: String, loud: bool, now: int) -> void:
	if loud:
		_speaking[id] = now
	var on: bool = _speaking.has(id) and now - int(_speaking[id]) < HOLD_MS
	_set_speaking(id, on)


func _set_speaking(id: String, on: bool) -> void:
	if on == _speaking_on.has(id):
		return
	if on:
		_speaking_on[id] = true
	else:
		_speaking_on.erase(id)
		_speaking.erase(id)
	speaking_changed.emit(id, on)


static func mic_error_text(code: String) -> String:
	match code:
		"denied":
			return "Microfono bloccato: permettilo dal lucchetto vicino all'indirizzo e riprova"
		"nomic":
			return "Nessun microfono trovato"
		"busy":
			return "Il microfono è usato da un'altra app"
		"insecure":
			return "La voce va solo su https"
		"unsupported":
			return "Questo browser non ha la chat vocale"
	return "Non riesco ad aprire il microfono"


func join_hint() -> String:
	var ptt := settings.voice_key_label("ptt")
	var mute := settings.voice_key_label("mute")
	if str(settings.voice.mode) == "ptt":
		return "Sei in voce · Tieni premuto %s per parlare" % (ptt if ptt != "" else "il tasto Parla")
	return "Sei in voce · Parla e ti sentono" + (" · %s spegne il microfono" % mute if mute != "" else "")


# ---- Tasti ----

func _process(_delta: float) -> void:
	if phase != ON or str(settings.voice.mode) != "ptt":
		_set_ptt(false)
		return
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var typing := focus is LineEdit or focus is TextEdit
	_set_ptt(hotkeys and not typing and settings.voice_pressed("ptt"))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not hotkeys or not supported:
		return
	handle_key(key.physical_keycode if key.physical_keycode != 0 else key.keycode)


# true se il tasto era della voce (Microfono o Audio)
func handle_key(code: int) -> bool:
	if settings.voice_keys.get("mute", []).has(code):
		toggle_mute()
		return true
	if settings.voice_keys.get("deafen", []).has(code):
		toggle_deafen()
		return true
	return false


func _set_ptt(down: bool) -> void:
	if down == _ptt_down:
		return
	_ptt_down = down
	if bridge != null:
		bridge.set_ptt(down)


# ---- Interni ----

func _clean_state(d: Dictionary) -> Dictionary:
	return {"on": bool(d.get("on", false)), "muted": bool(d.get("muted", false)), "deafened": bool(d.get("deafened", false))}


func _announce() -> void:
	state_out.emit({"on": phase == ON, "muted": muted, "deafened": deafened})


func _push_mute() -> void:
	if bridge != null:
		bridge.set_muted(effective_muted())
		bridge.set_deafened(deafened)
	if phase == ON:
		_announce()
	muted_changed.emit(my_id, effective_muted())
	if effective_muted():
		_set_speaking(my_id, false)
	changed.emit()


func _connect_all() -> void:
	for id in states:
		if states[id].on and id != my_id and not peers.has(id):
			_add_peer(id)
	for id in peers.keys():
		if not states.has(id):
			_peer_gone(id)


func _add_peer(id: String) -> void:
	peers[id] = true
	bridge.add_peer(id, polite(my_id, id))
	_sent_volume.erase(id)
	_spatial.erase(id)
	_apply_peer(id)


func _peer_gone(id: String) -> void:
	if peers.has(id):
		peers.erase(id)
		bridge.remove_peer(id)
	links.erase(id)
	levels.erase(id)
	_spatial.erase(id)
	_sent_volume.erase(id)
	_set_speaking(id, false)
	muted_changed.emit(id, false)


func _drop_peers() -> void:
	for id in peers.keys():
		_peer_gone(id)


func _send(to: String, kind: String, data: String) -> void:
	if to == "" or data.length() > MAX_SIGNAL:
		return
	signal_out.emit(to, kind, data)


func _set_spatial(id: String, g: Vector2) -> void:
	var old: Vector2 = _spatial.get(id, Vector2(-1, -9))
	if absf(old.x - g.x) < GAIN_STEP and absf(old.y - g.y) < GAIN_STEP:
		return
	_spatial[id] = g
	if bridge != null and peers.has(id):
		bridge.set_peer_gain(id, g.x, g.y)


func _apply_peer(id: String) -> void:
	if bridge == null or not peers.has(id):
		return
	var v := 0.0 if is_local_muted(id) else peer_volume(id)
	if is_equal_approx(float(_sent_volume.get(id, -1.0)), v):
		return
	_sent_volume[id] = v
	bridge.set_peer_volume(id, v)


func _apply_settings() -> void:
	if bridge == null:
		return
	bridge.set_mode(str(settings.voice.mode))
	bridge.set_vad_threshold(float(settings.voice.vad_threshold))
	bridge.set_output_volume(float(settings.voice.volume))
	for id in peers:
		_apply_peer(id)


# ---- Bip (sintetizzati, niente file) ----

func _bleep(kind: String) -> void:
	if not bool(settings.voice.get("sounds", true)) or not is_inside_tree():
		return
	if not _sounds.has(kind):
		_sounds[kind] = bleep_stream(kind)
	_player.stream = _sounds[kind]
	_player.play()


# Entrare sale, uscire scende; microfono spento è un tonfo basso, acceso uno alto. Gli altri più piano
static func bleep_stream(kind: String) -> AudioStreamWAV:
	var s := Synth.new(0.32)
	match kind:
		"join":
			s.tone(0.0, "sine", 520, 540, 0.09, 0.35)
			s.tone(0.09, "sine", 780, 800, 0.16, 0.35)
		"leave":
			s.tone(0.0, "sine", 780, 760, 0.09, 0.35)
			s.tone(0.09, "sine", 520, 500, 0.16, 0.35)
		"peer_join":
			s.tone(0.0, "triangle", 660, 990, 0.14, 0.25)
		"peer_leave":
			s.tone(0.0, "triangle", 880, 520, 0.16, 0.25)
		"mute":
			s.tone(0.0, "sine", 420, 300, 0.1, 0.35)
		"unmute":
			s.tone(0.0, "sine", 600, 820, 0.1, 0.35)
	return s.to_stream()


# Il ponte vero: chiama window.bonoboVoice e riceve i suoi messaggi con una callback sola
class WebBridge extends RefCounted:
	var _js # JavaScriptObject di window.bonoboVoice: senza tipo, i suoi metodi Godot non li conosce
	var _cb # JavaScriptObject della callback: va tenuta viva, se no il browser chiama una funzione che non c'è più
	var _on_event: Callable

	func _init(on_event: Callable) -> void:
		_on_event = on_event
		JavaScriptBridge.eval(VoiceWeb.SOURCE, true)
		_js = JavaScriptBridge.get_interface("bonoboVoice")
		_cb = JavaScriptBridge.create_callback(_receive)
		_js.setHandler(_cb)

	func _receive(args: Array) -> void:
		if args.size() < 2:
			return
		_on_event.call(str(args[0]), JSON.parse_string(str(args[1])))

	func join(cfg: Dictionary) -> void:
		_js.join(JSON.stringify(cfg))

	func leave() -> void:
		_js.leave()

	func add_peer(id: String, is_polite: bool) -> void:
		_js.addPeer(id, is_polite)

	func remove_peer(id: String) -> void:
		_js.removePeer(id)

	func signal_in(from: String, kind: String, data: String) -> void:
		_js.call("signal", from, kind, data) # signal è una parola di GDScript

	func set_muted(on: bool) -> void:
		_js.setMuted(on)

	func set_deafened(on: bool) -> void:
		_js.setDeafened(on)

	func set_output_volume(v: float) -> void:
		_js.setOutputVolume(v)

	func set_peer_volume(id: String, v: float) -> void:
		_js.setPeerVolume(id, v)

	func set_peer_gain(id: String, gain: float, pan: float) -> void:
		_js.setPeerGain(id, gain, pan)

	func set_mode(m: String) -> void:
		_js.setMode(m)

	func set_ptt(down: bool) -> void:
		_js.setPtt(down)

	func set_vad_threshold(t: float) -> void:
		_js.setVadThreshold(t)

	func set_input_device(id: String) -> void:
		_js.setInputDevice(id)

	func list_devices() -> void:
		_js.listDevices()

	func test_mic(on: bool, loopback: bool) -> void:
		_js.testMic(on, loopback)
