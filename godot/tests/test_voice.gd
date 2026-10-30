# Chat vocale (voice.gd) con un ponte finto al posto del browser: chi si collega a chi, con che ruolo,
# dove vanno i messaggi, silenzia e disattiva audio, audio di posizione, preferenze salvate
extends RefCounted

var runner

const PATH := "user://test_voice.cfg"
const AUDIO := {"master": 0.8, "sfx": 0.7, "music": 0.35}


# Registra le chiamate al browser: [metodo, argomenti...]
class FakeBridge extends RefCounted:
	var calls: Array = []

	func join(cfg: Dictionary) -> void: calls.append(["join", cfg])
	func leave() -> void: calls.append(["leave"])
	func add_peer(id: String, polite: bool) -> void: calls.append(["add_peer", id, polite])
	func remove_peer(id: String) -> void: calls.append(["remove_peer", id])
	func signal_in(from: String, kind: String, data: String) -> void: calls.append(["signal_in", from, kind, data])
	func set_muted(on: bool) -> void: calls.append(["set_muted", on])
	func set_deafened(on: bool) -> void: calls.append(["set_deafened", on])
	func set_output_volume(v: float) -> void: calls.append(["set_output_volume", v])
	func set_peer_volume(id: String, v: float) -> void: calls.append(["set_peer_volume", id, v])
	func set_peer_gain(id: String, gain: float, pan: float) -> void: calls.append(["set_peer_gain", id, gain, pan])
	func set_mode(m: String) -> void: calls.append(["set_mode", m])
	func set_ptt(down: bool) -> void: calls.append(["set_ptt", down])
	func set_vad_threshold(t: float) -> void: calls.append(["set_vad_threshold", t])
	func set_input_device(id: String) -> void: calls.append(["set_input_device", id])
	func list_devices() -> void: calls.append(["list_devices"])
	func test_mic(on: bool, loopback: bool) -> void: calls.append(["test_mic", on, loopback])

	func named(method: String) -> Array:
		return calls.filter(func(c): return c[0] == method)

	func last(method: String) -> Array:
		var all := named(method)
		return all[-1] if not all.is_empty() else []


func _settings() -> Settings:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return Settings.new(AUDIO, PATH)


# Una voce nella stanza come "m", con i messaggi in uscita raccolti in out
func _voice(out: Array, id := "m") -> Array:
	var v := VoiceChat.new()
	var b := FakeBridge.new()
	v.setup(_settings(), b)
	v.signal_out.connect(func(to, kind, data): out.append(["voice", to, kind, data]))
	v.state_out.connect(func(st): out.append(["voiceState", st]))
	v.on_welcome(id)
	return [v, b]


func _joined(out: Array, others: Array) -> Array:
	var vb := _voice(out)
	var v: VoiceChat = vb[0]
	var states := []
	for id in others:
		states.append({"id": id, "on": true, "muted": false, "deafened": false})
	v.on_config({"iceServers": [{"urls": "stun:x"}], "states": states})
	v.join()
	v.on_bridge_event("joined", {"ok": true})
	return vb


func _free(vb: Array) -> void:
	(vb[0] as VoiceChat).free()


func test_si_entra_solo_chiedendo() -> void:
	var out := []
	var vb := _voice(out)
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.on_config({"iceServers": [], "states": [{"id": "a", "on": true, "muted": false, "deafened": false}]})
	runner.check(b.named("join").is_empty(), "il microfono non si chiede da solo")
	runner.check(v.phase == VoiceChat.OFF and v.participants().size() == 1, "si vede chi è in voce anche da fuori")
	_free(vb)


func test_entrata_e_collegamenti() -> void:
	var out := []
	var vb := _joined(out, ["a", "z"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	var cfg: Dictionary = b.last("join")[1]
	runner.check(cfg.myId == "m" and cfg.iceServers.size() == 1, "join col mio id e i server ICE: %s" % [cfg])
	runner.check(v.phase == VoiceChat.ON, "dentro")
	runner.check(out.has(["voiceState", {"on": true, "muted": false, "deafened": false}]), "si dice al server: %s" % [out])
	var adds := b.named("add_peer")
	runner.check(adds.size() == 2, "un collegamento per ognuno: %s" % [adds])
	# Perfect negotiation: educato è l'id più piccolo. "m" < "z", "m" > "a"
	runner.check(adds.has(["add_peer", "z", true]) and adds.has(["add_peer", "a", false]), "ruoli: %s" % [adds])
	_free(vb)


func test_ruoli_simmetrici() -> void:
	runner.check(VoiceChat.polite("abc", "abd") and not VoiceChat.polite("abd", "abc"), "uno solo è educato")
	runner.check(VoiceChat.polite("B", "a"), "confronto per codice, come in JavaScript")


func test_microfono_negato() -> void:
	var out := []
	var vb := _voice(out)
	var v: VoiceChat = vb[0]
	var notes := []
	v.notice.connect(func(t, warn): notes.append([t, warn]))
	v.join()
	v.on_bridge_event("joined", {"ok": false, "error": "denied"})
	runner.check(v.phase == VoiceChat.OFF and v.error == "denied", "resta fuori")
	runner.check(notes.size() == 1 and notes[0][1] and "lucchetto" in notes[0][0], "lo spiega: %s" % [notes])
	runner.check(out.filter(func(o): return o[0] == "voiceState").is_empty(), "il server non sa niente")
	_free(vb)


func test_messaggi_col_destinatario_giusto() -> void:
	var out := []
	var vb := _joined(out, ["a"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	out.clear()
	v.on_bridge_event("signal", {"to": "a", "kind": "offer", "data": "{\"sdp\":1}"})
	runner.check(out == [["voice", "a", "offer", "{\"sdp\":1}"]], "uscita: %s" % [out])
	v.on_signal({"from": "a", "kind": "answer", "data": "x"})
	runner.check(b.last("signal_in") == ["signal_in", "a", "answer", "x"], "entrata: %s" % [b.last("signal_in")])
	# Troppo lungo per il server: non parte
	out.clear()
	v.on_bridge_event("signal", {"to": "a", "kind": "ice", "data": "x".repeat(VoiceChat.MAX_SIGNAL + 1)})
	runner.check(out.is_empty(), "scartato")
	_free(vb)


func test_offerta_prima_dello_stato() -> void:
	var out := []
	var vb := _joined(out, [])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.on_signal({"from": "b", "kind": "offer", "data": "o"})
	runner.check(b.last("add_peer") == ["add_peer", "b", false], "collegamento creato: %s" % [b.last("add_peer")])
	runner.check(b.last("signal_in")[1] == "b", "e l'offerta passa")
	_free(vb)


func test_fuori_dalla_voce_i_messaggi_si_ignorano() -> void:
	var out := []
	var vb := _voice(out)
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.on_signal({"from": "a", "kind": "offer", "data": "o"})
	runner.check(b.named("signal_in").is_empty() and b.named("add_peer").is_empty(), "niente collegamenti")
	_free(vb)


func test_entra_ed_esce_un_altro() -> void:
	var out := []
	var vb := _joined(out, [])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.on_state({"id": "q", "on": true, "muted": false, "deafened": false})
	runner.check(b.last("add_peer") == ["add_peer", "q", true], "entra: %s" % [b.last("add_peer")])
	v.on_state({"id": "q", "on": true, "muted": true, "deafened": false})
	runner.check(b.named("add_peer").size() == 1, "silenziarsi non ricollega")
	runner.check(v.participants()[1].muted, "si vede silenziato")
	v.on_state({"id": "q", "on": false, "muted": false, "deafened": false})
	runner.check(b.last("remove_peer") == ["remove_peer", "q"], "esce: chiuso")
	runner.check(v.participants().size() == 1, "resto solo io")
	# Rientra (ricarica la pagina con lo stesso id): collegamento nuovo
	v.on_state({"id": "q", "on": true, "muted": false, "deafened": false})
	runner.check(b.named("add_peer").size() == 2, "ricollegato")
	_free(vb)


func test_bye_chiude() -> void:
	var out := []
	var vb := _joined(out, ["a"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.on_signal({"from": "a", "kind": "bye", "data": ""})
	runner.check(b.last("remove_peer") == ["remove_peer", "a"], "chiuso")
	runner.check(not v.peers.has("a"), "tolto")
	_free(vb)


func test_uscita() -> void:
	var out := []
	var vb := _joined(out, ["a", "b"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	out.clear()
	v.leave()
	runner.check(b.named("leave").size() == 1 and b.named("remove_peer").size() == 2, "tutto chiuso: %s" % [b.calls])
	var byes := out.filter(func(o): return o[0] == "voice" and o[2] == "bye")
	runner.check(byes.size() == 2, "saluta tutti: %s" % [out])
	runner.check(out[-1] == ["voiceState", {"on": false, "muted": false, "deafened": false}], "e lo dice al server: %s" % [out])
	runner.check(v.phase == VoiceChat.OFF, "fuori")
	_free(vb)


func test_rientro_dopo_caduta_di_rete() -> void:
	var out := []
	var vb := _joined(out, ["a"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	out.clear()
	# Stesso id: il server rimanda la config, si ridice che siamo in voce, i collegamenti restano
	v.on_welcome("m")
	v.on_config({"iceServers": [], "states": [{"id": "a", "on": true, "muted": false, "deafened": false}]})
	runner.check(out == [["voiceState", {"on": true, "muted": false, "deafened": false}]], "ridetto: %s" % [out])
	runner.check(b.named("remove_peer").is_empty() and b.named("add_peer").size() == 1, "collegamento tenuto")
	# Id nuovo: i collegamenti vecchi non valgono più, si rifanno
	v.on_welcome("n")
	runner.check(b.last("remove_peer") == ["remove_peer", "a"], "chiusi")
	v.on_config({"iceServers": [], "states": [{"id": "a", "on": true, "muted": false, "deafened": false}]})
	runner.check(b.last("add_peer") == ["add_peer", "a", false], "rifatti col ruolo nuovo: %s" % [b.last("add_peer")])
	_free(vb)


func test_silenzia_e_disattiva_audio() -> void:
	var out := []
	var vb := _joined(out, ["a"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.toggle_mute()
	runner.check(v.muted and b.last("set_muted") == ["set_muted", true], "microfono spento")
	runner.check(out[-1] == ["voiceState", {"on": true, "muted": true, "deafened": false}], "detto: %s" % [out[-1]])
	v.toggle_mute()
	# Disattiva audio: non senti e il microfono si spegne (come Discord)
	v.toggle_deafen()
	runner.check(v.deafened and v.effective_muted(), "audio disattivato spegne anche il microfono")
	runner.check(b.last("set_deafened") == ["set_deafened", true] and b.last("set_muted") == ["set_muted", true], "al browser: %s" % [b.calls.slice(-2)])
	v.toggle_deafen()
	runner.check(not v.deafened and not v.effective_muted(), "riattivato: il microfono torna acceso")
	# Silenziato prima di disattivare: riattivando resta silenziato
	v.toggle_mute()
	v.toggle_deafen()
	v.toggle_deafen()
	runner.check(v.muted, "il microfono resta spento com'era")
	# Microfono acceso mentre l'audio è disattivato: riattiva tutto
	v.toggle_deafen()
	v.toggle_mute()
	runner.check(not v.deafened and not v.muted, "come su Discord")
	_free(vb)


func test_tasti() -> void:
	var out := []
	var vb := _joined(out, [])
	var v: VoiceChat = vb[0]
	runner.check(v.handle_key(KEY_N) and v.muted, "N spegne il microfono")
	runner.check(v.handle_key(KEY_B) and v.deafened, "B disattiva l'audio")
	runner.check(not v.handle_key(KEY_M), "M resta della musica")
	_free(vb)


func test_parlare() -> void:
	var out := []
	var vb := _joined(out, ["a"])
	var v: VoiceChat = vb[0]
	var talk := []
	v.speaking_changed.connect(func(id, on): talk.append([id, on]))
	v.on_bridge_event("levels", {"me": 0.7, "open": true, "peers": {"a": {"l": 0.6, "s": "connected", "q": 3, "rtt": 40}}})
	runner.check(v.is_speaking("m") and v.is_speaking("a"), "parlano tutti e due: %s" % [talk])
	runner.check(v.links.a.q == 3 and v.links.a.rtt == 40, "qualità: %s" % [v.links])
	# Silenziato: il proprio anello si spegne anche se il livello è alto
	v.toggle_mute()
	runner.check(not v.is_speaking("m"), "silenziato non parla")
	# Chi è silenziato per me non si accende
	v.set_local_mute("a", true)
	v._speaking.clear()
	v._set_speaking("a", false)
	v.on_bridge_event("levels", {"me": 0.0, "open": false, "peers": {"a": {"l": 0.9, "s": "connected", "q": 3}}})
	runner.check(not v.is_speaking("a"), "silenziato per me")
	_free(vb)


func test_volume_e_silenzia_per_me() -> void:
	var out := []
	var vb := _joined(out, ["a"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.set_roster([{"id": "a", "name": "Nico", "color": 0xff0000}])
	v.set_peer_volume("a", 1.5)
	runner.check(b.last("set_peer_volume") == ["set_peer_volume", "a", 1.5], "al browser: %s" % [b.last("set_peer_volume")])
	runner.check(v.settings.voice_volumes == {"Nico": 1.5}, "salvato per nome")
	v.set_local_mute("a", true)
	runner.check(b.last("set_peer_volume") == ["set_peer_volume", "a", 0.0], "silenziato per me = volume zero")
	v.set_local_mute("a", false)
	runner.check(b.last("set_peer_volume") == ["set_peer_volume", "a", 1.5], "torna il volume scelto")
	v.set_peer_volume("a", 9.0)
	runner.check(v.peer_volume("a") == 2.0, "al massimo 200%")
	_free(vb)


func test_audio_di_posizione() -> void:
	runner.check(VoiceChat.spatial_gain(0.0) == 1.0 and VoiceChat.spatial_gain(400.0) == 1.0, "vicino: pieno")
	runner.check(is_equal_approx(VoiceChat.spatial_gain(2000.0), VoiceChat.SPATIAL_FLOOR), "a 20 m: il minimo")
	runner.check(is_equal_approx(VoiceChat.spatial_gain(5000.0), VoiceChat.SPATIAL_FLOOR), "oltre: il minimo")
	var mid := VoiceChat.spatial_gain(1200.0)
	runner.check(mid < 1.0 and mid > VoiceChat.SPATIAL_FLOOR, "in mezzo scende: %s" % mid)
	runner.check(VoiceChat.spatial_pan(500.0) > 0.0 and VoiceChat.spatial_pan(-500.0) < 0.0, "destra e sinistra")
	runner.check(VoiceChat.spatial_pan(9999.0) == VoiceChat.PAN_MAX, "mai tutto da una parte")


func test_posizione_in_sala_e_in_partita() -> void:
	var out := []
	var vb := _joined(out, ["a", "b"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	var snap := {"players": [
		{"id": "m", "name": "Io", "x": 0.0, "z": 0.0},
		{"id": "a", "name": "A", "x": 300.0, "z": 0.0},
		{"id": "b", "name": "B", "x": -3000.0, "z": 0.0},
	]}
	v.on_hall_snapshot(snap)
	var gains := {}
	for c in b.named("set_peer_gain"):
		gains[c[1]] = [c[2], c[3]]
	runner.check(gains.a[0] == 1.0 and gains.a[1] > 0.0, "A vicino, a destra: %s" % [gains])
	runner.check(is_equal_approx(gains.b[0], VoiceChat.SPATIAL_FLOOR) and gains.b[1] < 0.0, "B lontano, a sinistra: %s" % [gains])
	# Lo stesso snapshot non riscrive niente
	var n := b.named("set_peer_gain").size()
	v.on_hall_snapshot(snap)
	runner.check(b.named("set_peer_gain").size() == n, "niente chiamate inutili")
	# In partita: tutti pieni e al centro
	v.on_match_snapshot(snap.players)
	runner.check(b.last("set_peer_gain").slice(2) == [1.0, 0.0], "in partita pieno: %s" % [b.last("set_peer_gain")])
	# Spento dalle opzioni: anche in sala pieno
	v.settings.voice.spatial = false
	v.on_hall_snapshot(snap)
	var last_b: Array = b.named("set_peer_gain").filter(func(c): return c[1] == "b")[-1]
	runner.check(last_b.slice(2) == [1.0, 0.0], "senza posizione: %s" % [last_b])
	_free(vb)


func test_entrata_automatica() -> void:
	var out := []
	var vb := _voice(out)
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.settings.voice.auto_join = true
	v.on_config({"iceServers": [], "states": []})
	runner.check(b.named("join").size() == 1, "entra da sola")
	v.on_bridge_event("joined", {"ok": false, "error": "denied"})
	v.on_config({"iceServers": [], "states": []})
	runner.check(b.named("join").size() == 1, "dopo un no non insiste")
	_free(vb)


func test_uscita_dalla_stanza() -> void:
	var out := []
	var vb := _joined(out, ["a"])
	var v: VoiceChat = vb[0]
	var b: FakeBridge = vb[1]
	v.reset_room()
	runner.check(v.phase == VoiceChat.OFF and v.states.is_empty() and v.peers.is_empty(), "tutto pulito")
	runner.check(b.named("leave").size() == 1, "microfono chiuso")
	_free(vb)


func test_fuori_dal_browser() -> void:
	var v := VoiceChat.new()
	var notes := []
	v.notice.connect(func(t, _w): notes.append(t))
	v.setup(_settings(), null) # nei test headless non c'è il browser
	runner.check(not v.supported, "niente voce")
	v.join()
	v.toggle_mute()
	v.on_config({"iceServers": [], "states": [{"id": "a", "on": true}]})
	runner.check(v.phase == VoiceChat.OFF and notes == ["La chat vocale funziona nel browser"], "lo dice e basta: %s" % [notes])
	v.free()


func test_preferenze_salvate() -> void:
	var s := _settings()
	runner.check(s.voice == Settings.VOICE_DEFAULTS and s.voice_keys == Settings.VOICE_KEY_DEFAULTS, "default")
	s.voice.mode = "ptt"
	s.voice.vad_threshold = 0.3
	s.voice.spatial = false
	s.voice.volume = 1.5
	s.voice_volumes = {"Nico": 0.5}
	s.voice_muted = {"Gigi": true}
	s.assign_voice("ptt", KEY_G)
	var again := Settings.new(AUDIO, PATH)
	runner.check(again.voice.mode == "ptt" and is_equal_approx(again.voice.vad_threshold, 0.3) and not again.voice.spatial, "ricaricate: %s" % [again.voice])
	runner.check(again.voice.volume == 1.5 and again.voice_volumes == {"Nico": 0.5} and again.voice_muted == {"Gigi": true}, "volumi per nome")
	runner.check(again.voice_keys.ptt == [KEY_G], "tasto: %s" % [again.voice_keys])


func test_tasti_della_voce_e_del_gioco() -> void:
	var s := _settings()
	# V alla provocazione: la voce lo perde
	var from := s.assign("taunt", 1, KEY_V)
	runner.check(from == "voice:ptt" and s.voice_keys.ptt.is_empty(), "V tolto da Parla: %s" % from)
	runner.check(Settings.action_label(from).begins_with("Voce:"), Settings.action_label(from))
	# K alla voce: il pesante lo perde
	from = s.assign_voice("mute", KEY_K)
	runner.check(from == "heavy" and not s.bindings.heavy.has(KEY_K) and s.voice_keys.mute == [KEY_K], "K tolto al pesante: %s" % from)
	# Tra azioni della voce
	from = s.assign_voice("deafen", KEY_K)
	runner.check(from == "voice:mute" and s.voice_keys.mute.is_empty(), "K passa ad Audio")
	runner.check(s.voice_key_label("deafen") == "K", s.voice_key_label("deafen"))


func test_preferenze_vecchie_col_tasto_v() -> void:
	# Chi aveva già dato V a un'azione del gioco la tiene: Parla resta senza tasto
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var cfg := ConfigFile.new()
	cfg.set_value("keys", "taunt", [KEY_V])
	cfg.save(PATH)
	var s := Settings.new(AUDIO, PATH)
	runner.check(s.bindings.taunt == [KEY_V] and s.voice_keys.ptt.is_empty(), "%s %s" % [s.bindings.taunt, s.voice_keys])
	runner.check(s.voice_keys.mute == [KEY_N], "gli altri restano")


func test_bip() -> void:
	for kind in ["join", "leave", "peer_join", "peer_leave", "mute", "unmute"]:
		var st := VoiceChat.bleep_stream(kind)
		runner.check(st.data.size() > 1000, "%s ha un suono" % kind)


func test_avviso_di_entrata() -> void:
	var s := _settings()
	var v := VoiceChat.new()
	v.setup(s, FakeBridge.new())
	runner.check("N" in v.join_hint(), v.join_hint())
	s.voice.mode = "ptt"
	runner.check("Tieni premuto V per parlare" in v.join_hint(), v.join_hint())
	v.free()


func test_codice_javascript() -> void:
	var js: String = preload("res://scripts/voice_web.gd").SOURCE
	for name in ["join", "leave", "addPeer", "removePeer", "signal", "setMuted", "setDeafened", "setPeerVolume", "setPeerGain",
			"setOutputVolume", "setInputDevice", "listDevices", "setMode", "setPtt", "setVadThreshold", "testMic", "setHandler"]:
		runner.check(("%s: " % name) in js, "manca %s nel JavaScript" % name)
	runner.check("echoCancellation: true" in js and "noiseSuppression: true" in js and "autoGainControl: true" in js, "audio pulito")
