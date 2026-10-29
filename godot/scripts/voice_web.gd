# Il codice JavaScript della chat vocale (window.bonoboVoice), che voice.gd inietta nella pagina nel gioco web.
# Sta in una stringa e non in un file .js perché l'export prende solo script e risorse di Godot.
# Per controllarlo: copia SOURCE in un file e lancia node --check.
extends RefCounted

const SOURCE := r"""
// Chat vocale nel browser (voice.gd la inietta con JavaScriptBridge.eval): WebRTC del browser, un collegamento
// diretto per ogni altro giocatore in voce. Godot decide chi, quando e quanto forte; qui si fa l'audio.
// Parla con Godot solo con handler(tipo, json): signal, joined, levels, devices, error.
(function () {
  "use strict";
  if (window.bonoboVoice) return;

  var LEVEL_MS = 66; // livelli a Godot circa 15 volte al secondo
  var GATE_MS = 20; // il cancello del microfono (voce o tasto) si aggiorna ogni 20 ms
  var HANGOVER_MS = 350; // dopo l'ultima sillaba il microfono resta aperto un attimo: le parole non si tagliano
  var STATS_MS = 2000; // qualità del collegamento (ping, pacchetti persi)
  var RESTART_MS = 4000; // collegamento "disconnected" per tanto: si rinegozia con un riavvio ICE
  var MAX_BITRATE = 64000; // Opus mono: 64 kbit/s è voce pulita anche con la musica sotto

  var handler = null;
  var st = {
    joined: false, joining: false, myId: "", ice: [], mode: "vad", ptt: false, vad: 0.45,
    muted: false, deafened: false, deviceId: "", out: 1, testing: false, loopback: false
  };
  var ctx = null;
  var master = null; // tutte le voci passano da qui: volume della voce e "disattiva audio"
  var mic = null; // { stream, src }
  var micAnalyser = null;
  var gate = null; // GainNode: 0 chiuso, 1 aperto
  var dest = null; // MediaStreamDestination: la traccia mandata agli altri non cambia mai (niente rinegoziazioni)
  var loop = null; // GainNode del "senti la tua voce" nella prova del microfono
  var peers = {};
  var gateTimer = 0;
  var levelTimer = 0;
  var statsTimer = 0;
  var lastLoud = 0;
  var gateOpen = false;
  var micLevel = 0;
  var buf = null;

  function emit(type, payload) {
    if (!handler) return;
    try { handler(type, JSON.stringify(payload === undefined ? {} : payload)); } catch (e) { /* Godot chiuso */ }
  }

  function fail(where, err) {
    emit("error", { where: where, name: (err && err.name) || "Error", message: String((err && err.message) || err) });
  }

  // Livello da 0 a 1 di un analizzatore: RMS in dBFS, da -60 dB (0) a 0 dB (1)
  function level(an) {
    if (!an) return 0;
    if (!buf || buf.length !== an.fftSize) buf = new Float32Array(an.fftSize);
    an.getFloatTimeDomainData(buf);
    var sum = 0;
    for (var i = 0; i < buf.length; i++) sum += buf[i] * buf[i];
    var rms = Math.sqrt(sum / buf.length);
    var db = rms > 0 ? 20 * Math.log10(rms) : -100;
    return Math.max(0, Math.min(1, (db + 60) / 60));
  }

  function ensureCtx() {
    if (!ctx) {
      var AC = window.AudioContext || window.webkitAudioContext;
      ctx = new AC({ latencyHint: "interactive" });
      master = ctx.createGain();
      master.connect(ctx.destination);
      gate = ctx.createGain();
      gate.gain.value = 0;
      dest = ctx.createMediaStreamDestination();
      gate.connect(dest);
      loop = ctx.createGain();
      loop.gain.value = 0;
      loop.connect(ctx.destination);
      micAnalyser = ctx.createAnalyser();
      micAnalyser.fftSize = 512;
      micAnalyser.smoothingTimeConstant = 0.2;
    }
    if (ctx.state === "suspended") ctx.resume().catch(function () {});
    applyOutput();
    return ctx;
  }

  function supported() {
    return !!(window.RTCPeerConnection && navigator.mediaDevices && navigator.mediaDevices.getUserMedia &&
      (window.AudioContext || window.webkitAudioContext));
  }

  function constraints() {
    var a = { echoCancellation: true, noiseSuppression: true, autoGainControl: true, channelCount: 1 };
    if (st.deviceId) a.deviceId = { exact: st.deviceId };
    return { audio: a, video: false };
  }

  // Microfono aperto (una volta sola), collegato all'analizzatore e al cancello
  function openMic() {
    ensureCtx();
    if (mic) return Promise.resolve(mic);
    return navigator.mediaDevices.getUserMedia(constraints()).catch(function (err) {
      // Il microfono scelto non c'è più: si riprova con quello di sistema
      if (st.deviceId && err && (err.name === "OverconstrainedError" || err.name === "NotFoundError")) {
        st.deviceId = "";
        return navigator.mediaDevices.getUserMedia(constraints());
      }
      throw err;
    }).then(function (stream) {
      if (mic) { stopStream(stream); return mic; } // due richieste insieme: vince la prima
      var src = ctx.createMediaStreamSource(stream);
      src.connect(micAnalyser);
      src.connect(gate);
      src.connect(loop);
      mic = { stream: stream, src: src };
      applyMuted();
      listDevices();
      return mic;
    });
  }

  function stopStream(stream) {
    stream.getTracks().forEach(function (t) { t.stop(); });
  }

  function closeMic() {
    if (!mic) return;
    try { mic.src.disconnect(); } catch (e) { /* già staccato */ }
    stopStream(mic.stream);
    mic = null;
    micLevel = 0;
  }

  function applyMuted() {
    // Silenziato o senza audio: anche la traccia del microfono si spegne (la spia del browser lo dice)
    if (mic) mic.stream.getAudioTracks().forEach(function (t) { t.enabled = !(st.muted || st.deafened) || st.testing; });
  }

  function applyOutput() {
    if (!master) return;
    master.gain.setTargetAtTime(st.deafened ? 0 : st.out, ctx.currentTime, 0.02);
  }

  // Il cancello: aperto col tasto premuto (ptt) o quando si parla oltre la soglia (vad)
  function tickGate() {
    if (!mic) { gateOpen = false; return; }
    micLevel = level(micAnalyser);
    var now = Date.now();
    if (micLevel > st.vad) lastLoud = now;
    var want;
    if (st.muted || st.deafened || !st.joined) want = false;
    else if (st.mode === "ptt") want = st.ptt;
    else want = now - lastLoud < HANGOVER_MS;
    if (want !== gateOpen) {
      gateOpen = want;
      // Apre di colpo (la prima sillaba conta), chiude morbido (niente clic)
      gate.gain.setTargetAtTime(want ? 1 : 0, ctx.currentTime, want ? 0.004 : 0.03);
    }
  }

  function tickLevels() {
    var out = { me: micLevel, open: gateOpen, peers: {} };
    Object.keys(peers).forEach(function (id) {
      var p = peers[id];
      out.peers[id] = { l: p.analyser ? level(p.analyser) : 0, s: p.state, q: p.quality, rtt: p.rtt };
    });
    emit("levels", out);
  }

  function startTimers() {
    if (!gateTimer) gateTimer = setInterval(tickGate, GATE_MS);
    if (!levelTimer) levelTimer = setInterval(tickLevels, LEVEL_MS);
    if (!statsTimer) statsTimer = setInterval(tickStats, STATS_MS);
  }

  function stopTimers() {
    clearInterval(gateTimer); clearInterval(levelTimer); clearInterval(statsTimer);
    gateTimer = levelTimer = statsTimer = 0;
  }

  // ---- Collegamenti con gli altri: "perfect negotiation" (MDN), educato = id più piccolo ----

  function send(to, kind, data) {
    emit("signal", { to: to, kind: kind, data: data });
  }

  function addPeer(id, polite) {
    if (!st.joined || peers[id]) return peers[id];
    var pc;
    try {
      pc = new RTCPeerConnection({ iceServers: st.ice, bundlePolicy: "max-bundle" });
    } catch (err) { fail("pc", err); return null; }
    var p = {
      id: id, pc: pc, polite: !!polite, makingOffer: false, ignoreOffer: false, queue: Promise.resolve(),
      el: null, src: null, analyser: null, gain: null, pan: null, vol: 1, spatial: 1, panValue: 0,
      state: "connecting", quality: 0, rtt: -1, lost: 0, recv: 0, restartTimer: 0, closed: false
    };
    peers[id] = p;
    var track = dest.stream.getAudioTracks()[0];
    var sender = pc.addTrack(track, dest.stream);
    tuneSender(sender);

    pc.onnegotiationneeded = function () {
      p.makingOffer = true;
      pc.setLocalDescription().then(function () {
        send(id, pc.localDescription.type, JSON.stringify(pc.localDescription));
      }).catch(function (err) { fail("offer", err); }).then(function () { p.makingOffer = false; });
    };
    pc.onicecandidate = function (e) {
      if (e.candidate) send(id, "ice", JSON.stringify(e.candidate));
    };
    pc.ontrack = function (e) {
      attachRemote(p, e.streams && e.streams[0] ? e.streams[0] : new MediaStream([e.track]));
    };
    var onState = function () {
      var s = pc.connectionState || pc.iceConnectionState;
      if (s === "connected" || s === "completed") {
        p.state = "connected";
        clearTimeout(p.restartTimer); p.restartTimer = 0;
      } else if (s === "failed") {
        p.state = "failed";
        restart(p);
      } else if (s === "disconnected") {
        p.state = "connecting";
        if (!p.restartTimer) p.restartTimer = setTimeout(function () {
          p.restartTimer = 0;
          var now = pc.connectionState || pc.iceConnectionState;
          if (now === "disconnected" || now === "failed") restart(p);
        }, RESTART_MS);
      } else if (s === "closed") {
        p.state = "closed";
      } else {
        p.state = "connecting";
      }
    };
    pc.onconnectionstatechange = onState;
    pc.oniceconnectionstatechange = onState;
    return p;
  }

  // Opus a voce: banda e priorità alte, il resto lo decide il browser (FEC e DTX sono già accesi)
  function tuneSender(sender) {
    if (!sender || !sender.getParameters) return;
    try {
      var params = sender.getParameters();
      if (!params.encodings || !params.encodings.length) params.encodings = [{}];
      params.encodings[0].maxBitrate = MAX_BITRATE;
      params.encodings[0].priority = "high";
      params.encodings[0].networkPriority = "high";
      sender.setParameters(params).catch(function () {});
    } catch (e) { /* browser senza setParameters: va bene lo stesso */ }
  }

  // Riavvio ICE (rete cambiata, Wi-Fi caduto un attimo): rinegozia senza chiudere il collegamento
  function restart(p) {
    if (p.closed) return;
    try {
      if (p.pc.restartIce) p.pc.restartIce();
      else if (!p.polite) {
        p.pc.createOffer({ iceRestart: true }).then(function (o) { return p.pc.setLocalDescription(o); })
          .then(function () { send(p.id, "offer", JSON.stringify(p.pc.localDescription)); })
          .catch(function (err) { fail("restart", err); });
      }
    } catch (err) { fail("restart", err); }
  }

  function onSignal(from, kind, data) {
    if (!st.joined) return;
    if (kind === "bye") { removePeer(from); return; }
    var p = peers[from] || addPeer(from, st.myId < from);
    if (!p) return;
    // In fila per ogni giocatore: un candidato ICE non passa davanti all'offerta che lo precede
    p.queue = p.queue.then(function () { return handleSignal(p, kind, data); }).catch(function (err) {
      if (!p.ignoreOffer) fail(kind, err);
    });
  }

  function handleSignal(p, kind, data) {
    if (p.closed) return null;
    var pc = p.pc;
    var msg = data ? JSON.parse(data) : null;
    if (kind === "offer" || kind === "answer") {
      var collision = msg.type === "offer" && (p.makingOffer || pc.signalingState !== "stable");
      p.ignoreOffer = !p.polite && collision;
      if (p.ignoreOffer) return null;
      return pc.setRemoteDescription(msg).then(function () {
        if (msg.type !== "offer") return null;
        return pc.setLocalDescription().then(function () {
          send(p.id, "answer", JSON.stringify(pc.localDescription));
        });
      });
    }
    if (kind === "ice" && msg) {
      return pc.addIceCandidate(msg).catch(function (err) { if (!p.ignoreOffer) throw err; });
    }
    return null;
  }

  // La voce di un altro: elemento <audio> muto (senza, Chrome non fa passare l'audio a WebAudio)
  // e il grafo WebAudio: volume (fino al 200%), destra/sinistra e analizzatore per l'anello verde
  function attachRemote(p, stream) {
    if (p.closed) return;
    detachRemote(p);
    var el = document.createElement("audio");
    el.muted = true;
    el.autoplay = true;
    el.setAttribute("playsinline", "");
    el.srcObject = stream;
    var played = el.play();
    if (played && played.catch) played.catch(function () {});
    p.el = el;
    p.src = ctx.createMediaStreamSource(stream);
    p.analyser = ctx.createAnalyser();
    p.analyser.fftSize = 512;
    p.analyser.smoothingTimeConstant = 0.2;
    p.gain = ctx.createGain();
    p.src.connect(p.analyser);
    p.src.connect(p.gain);
    if (ctx.createStereoPanner) {
      p.pan = ctx.createStereoPanner();
      p.gain.connect(p.pan);
      p.pan.connect(master);
    } else {
      p.gain.connect(master);
    }
    applyPeer(p);
  }

  function detachRemote(p) {
    [p.src, p.gain, p.pan, p.analyser].forEach(function (n) { if (n) try { n.disconnect(); } catch (e) { /* ok */ } });
    if (p.el) { p.el.srcObject = null; p.el = null; }
    p.src = p.gain = p.pan = p.analyser = null;
  }

  function applyPeer(p) {
    if (!p.gain) return;
    p.gain.gain.setTargetAtTime(p.vol * p.spatial, ctx.currentTime, 0.05);
    if (p.pan) p.pan.pan.setTargetAtTime(p.panValue, ctx.currentTime, 0.05);
  }

  function removePeer(id) {
    var p = peers[id];
    if (!p) return;
    p.closed = true;
    clearTimeout(p.restartTimer);
    detachRemote(p);
    try { p.pc.close(); } catch (e) { /* già chiuso */ }
    delete peers[id];
  }

  // Ping e pacchetti persi: il pallino della qualità (3 buono, 2 così così, 1 brutto)
  function tickStats() {
    Object.keys(peers).forEach(function (id) {
      var p = peers[id];
      if (!p.pc.getStats || p.state !== "connected") { p.quality = 0; return; }
      p.pc.getStats().then(function (report) {
        var rtt = -1, lost = 0, recv = 0, pairId = "";
        report.forEach(function (s) { if (s.type === "transport" && s.selectedCandidatePairId) pairId = s.selectedCandidatePairId; });
        report.forEach(function (s) {
          if (s.type === "candidate-pair" && (s.id === pairId || (!pairId && s.nominated && s.state === "succeeded")) &&
            typeof s.currentRoundTripTime === "number") rtt = s.currentRoundTripTime;
          if (s.type === "inbound-rtp" && s.kind === "audio") { lost += s.packetsLost || 0; recv += s.packetsReceived || 0; }
        });
        var dl = Math.max(0, lost - p.lost), dr = Math.max(0, recv - p.recv);
        p.lost = lost; p.recv = recv;
        var loss = dl + dr > 0 ? dl / (dl + dr) : 0;
        p.rtt = rtt >= 0 ? Math.round(rtt * 1000) : -1;
        if (rtt < 0) p.quality = 2;
        else if (rtt < 0.15 && loss < 0.02) p.quality = 3;
        else if (rtt < 0.35 && loss < 0.08) p.quality = 2;
        else p.quality = 1;
      }).catch(function () {});
    });
  }

  function listDevices() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) { emit("devices", []); return; }
    navigator.mediaDevices.enumerateDevices().then(function (all) {
      var out = [];
      all.forEach(function (d) {
        if (d.kind === "audioinput") out.push({ id: d.deviceId, label: d.label || ("Microfono " + (out.length + 1)) });
      });
      emit("devices", out);
    }).catch(function () { emit("devices", []); });
  }

  function micError(err) {
    var n = (err && err.name) || "";
    if (n === "NotAllowedError" || n === "SecurityError") return "denied";
    if (n === "NotFoundError" || n === "OverconstrainedError") return "nomic";
    if (n === "NotReadableError" || n === "AbortError") return "busy";
    return "error";
  }

  window.bonoboVoice = {
    setHandler: function (cb) { handler = cb; },
    supported: supported,

    // cfg: { myId, iceServers, mode, vad, muted, deafened, deviceId, out }
    join: function (cfgJson) {
      var cfg = typeof cfgJson === "string" ? JSON.parse(cfgJson) : (cfgJson || {});
      if (!supported()) { emit("joined", { ok: false, error: window.isSecureContext === false ? "insecure" : "unsupported" }); return; }
      st.myId = String(cfg.myId || "");
      st.ice = cfg.iceServers || [];
      if (cfg.mode) st.mode = cfg.mode;
      if (typeof cfg.vad === "number") st.vad = cfg.vad;
      st.muted = !!cfg.muted;
      st.deafened = !!cfg.deafened;
      if (typeof cfg.out === "number") st.out = cfg.out;
      if (typeof cfg.deviceId === "string") st.deviceId = cfg.deviceId;
      if (st.joined) { emit("joined", { ok: true }); return; }
      st.joining = true;
      try { ensureCtx(); } catch (err) { st.joining = false; emit("joined", { ok: false, error: "error", message: String(err) }); return; }
      startTimers();
      openMic().then(function () {
        if (!st.joining) return; // uscito mentre il browser chiedeva il permesso
        st.joining = false;
        st.joined = true;
        applyMuted();
        applyOutput();
        emit("joined", { ok: true, deviceId: st.deviceId });
      }).catch(function (err) {
        st.joining = false;
        if (!st.testing) { closeMic(); stopTimers(); }
        emit("joined", { ok: false, error: micError(err), message: String((err && err.message) || err) });
      });
    },

    leave: function () {
      st.joining = false;
      st.joined = false;
      st.ptt = false;
      Object.keys(peers).forEach(removePeer);
      if (!st.testing) { closeMic(); stopTimers(); }
      if (gate) gate.gain.value = 0;
      gateOpen = false;
    },

    addPeer: function (id, polite) { addPeer(String(id), !!polite); },
    removePeer: function (id) { removePeer(String(id)); },
    signal: function (from, kind, data) { onSignal(String(from), String(kind), String(data || "")); },

    setMuted: function (on) { st.muted = !!on; applyMuted(); },
    setDeafened: function (on) { st.deafened = !!on; applyMuted(); applyOutput(); },
    setOutputVolume: function (v) { st.out = Math.max(0, Math.min(2, Number(v) || 0)); applyOutput(); },
    // Volume scelto per quel giocatore (0..2) e posizione nella sala (gain 0..1, pan -1..1)
    setPeerVolume: function (id, v) {
      var p = peers[String(id)];
      if (p) { p.vol = Math.max(0, Math.min(2, Number(v) || 0)); applyPeer(p); }
    },
    setPeerGain: function (id, gain, pan) {
      var p = peers[String(id)];
      if (!p) return;
      var g = Number(gain);
      p.spatial = isNaN(g) ? 1 : Math.max(0, Math.min(1, g));
      p.panValue = Math.max(-1, Math.min(1, Number(pan) || 0));
      applyPeer(p);
    },
    setMode: function (m) { st.mode = m === "ptt" ? "ptt" : "vad"; },
    setPtt: function (down) { st.ptt = !!down; if (gateTimer) tickGate(); },
    setVadThreshold: function (t) { st.vad = Math.max(0, Math.min(1, Number(t) || 0)); },

    setInputDevice: function (id) {
      st.deviceId = String(id || "");
      if (!mic) return;
      // Si cambia la sorgente, non la traccia mandata: gli altri non si accorgono di niente
      closeMic();
      openMic().catch(function (err) { fail("device", err); });
    },
    listDevices: listDevices,

    // Prova del microfono dalle opzioni: livello e, con loopback, la propria voce in cuffia
    testMic: function (on, loopback) {
      st.testing = !!on;
      st.loopback = !!on && !!loopback;
      if (on) {
        try { ensureCtx(); } catch (err) { fail("test", err); return; }
        startTimers();
        openMic().then(function () {
          applyMuted();
          loop.gain.setTargetAtTime(st.loopback ? 1 : 0, ctx.currentTime, 0.02);
        }).catch(function (err) {
          st.testing = false;
          emit("error", { where: "test", name: (err && err.name) || "Error", message: micError(err) });
        });
      } else {
        if (loop) loop.gain.setTargetAtTime(0, ctx.currentTime, 0.02);
        applyMuted();
        if (!st.joined && !st.joining) { closeMic(); stopTimers(); micLevel = 0; tickLevels(); }
      }
    },

    // Per i test (Playwright): stato interno in sola lettura
    debug: function () {
      var out = { joined: st.joined, mic: !!mic, gateOpen: gateOpen, peers: {} };
      Object.keys(peers).forEach(function (id) {
        var p = peers[id];
        out.peers[id] = { state: p.state, signaling: p.pc.signalingState, polite: p.polite, audio: !!p.src };
      });
      return JSON.stringify(out);
    }
  };

  if (navigator.mediaDevices && navigator.mediaDevices.addEventListener) {
    navigator.mediaDevices.addEventListener("devicechange", listDevices);
  }
})();
"""
