// File MIDI (Standard MIDI File, formato 0 e 1) senza dipendenze, per l'arena musicale (#423).
// readMidi dà le note di ogni traccia in millisecondi, già con i cambi di tempo; writeMidi scrive il brano di prova.

export interface MidiNote {
  startMs: number;
  durMs: number;
  pitch: number; // 60 = Do centrale
  velocity: number; // 1-127
}

export interface MidiTrack {
  name: string;
  channel: number; // 0-15; il 9 è la batteria
  program: number; // strumento General MIDI (0-127)
  notes: MidiNote[];
}

export interface MidiSong {
  bpm: number; // il primo tempo del brano
  lengthMs: number; // fino alla fine dell'ultima traccia (l'evento End of Track)
  tracks: MidiTrack[];
}

class Reader {
  pos = 0;
  constructor(readonly buf: Uint8Array) {}
  u8() {
    return this.buf[this.pos++];
  }
  u16() {
    return (this.u8() << 8) | this.u8();
  }
  u32() {
    return ((this.u16() << 16) >>> 0) + this.u16();
  }
  text(n: number) {
    const s = Buffer.from(this.buf.subarray(this.pos, this.pos + n)).toString("latin1");
    this.pos += n;
    return s;
  }
  varLen() {
    let v = 0;
    for (;;) {
      const b = this.u8();
      v = (v << 7) | (b & 0x7f);
      if (!(b & 0x80)) return v;
    }
  }
}

interface RawEvent {
  tick: number;
  kind: "on" | "off" | "tempo" | "name" | "program" | "end";
  channel: number;
  a: number;
  b: number;
  text?: string;
}

function readTrack(r: Reader, end: number): RawEvent[] {
  const out: RawEvent[] = [];
  let tick = 0;
  let status = 0;
  while (r.pos < end) {
    tick += r.varLen();
    let b = r.u8();
    if (b === 0xff) {
      const type = r.u8();
      const len = r.varLen();
      if (type === 0x51) out.push({ tick, kind: "tempo", channel: 0, a: (r.u8() << 16) | (r.u8() << 8) | r.u8(), b: 0 });
      else if (type === 0x03) out.push({ tick, kind: "name", channel: 0, a: 0, b: 0, text: r.text(len) });
      else if (type === 0x2f) {
        out.push({ tick, kind: "end", channel: 0, a: 0, b: 0 });
        r.pos += len;
      } else r.pos += len;
      continue;
    }
    if (b === 0xf0 || b === 0xf7) {
      r.pos += r.varLen();
      continue;
    }
    // Running status: senza byte di stato vale quello dell'evento prima
    if (b & 0x80) status = b;
    else r.pos--;
    b = status;
    const type = b >> 4;
    const channel = b & 0x0f;
    const a = r.u8();
    const two = type !== 0xc && type !== 0xd;
    const v = two ? r.u8() : 0;
    if (type === 0x9 && v > 0) out.push({ tick, kind: "on", channel, a, b: v });
    else if (type === 0x8 || (type === 0x9 && v === 0)) out.push({ tick, kind: "off", channel, a, b: 0 });
    else if (type === 0xc) out.push({ tick, kind: "program", channel, a, b: 0 });
  }
  r.pos = end;
  return out;
}

export function readMidi(data: Uint8Array): MidiSong {
  const r = new Reader(data);
  if (r.text(4) !== "MThd") throw new Error("non è un file MIDI");
  const headLen = r.u32();
  const headEnd = r.pos + headLen;
  r.u16(); // formato
  const count = r.u16();
  const division = r.u16();
  if (division & 0x8000) throw new Error("tempo SMPTE non supportato");
  r.pos = headEnd;
  const raw: RawEvent[][] = [];
  while (raw.length < count && r.pos < data.length) {
    const id = r.text(4);
    const len = r.u32();
    if (id !== "MTrk") {
      r.pos += len;
      continue;
    }
    raw.push(readTrack(r, r.pos + len));
  }
  // Mappa del tempo (in qualunque traccia, di solito la prima): da tick a millisecondi
  const tempos = raw.flat().filter((e) => e.kind === "tempo").sort((x, y) => x.tick - y.tick);
  const ms = (tick: number) => {
    let at = 0;
    let usPerBeat = 500000;
    let out = 0;
    for (const t of tempos) {
      if (t.tick >= tick) break;
      out += ((t.tick - at) * usPerBeat) / division / 1000;
      at = t.tick;
      usPerBeat = t.a;
    }
    return out + ((tick - at) * usPerBeat) / division / 1000;
  };
  let lengthMs = 0;
  const tracks: MidiTrack[] = [];
  for (const events of raw) {
    const name = events.find((e) => e.kind === "name")?.text ?? "";
    const end = events.find((e) => e.kind === "end");
    if (end) lengthMs = Math.max(lengthMs, ms(end.tick));
    // Una traccia di un file formato 0 può avere più canali: se ne fa una per canale
    const byChannel = new Map<number, MidiTrack>();
    const open = new Map<string, RawEvent>();
    const programs = new Map<number, number>();
    for (const e of events) {
      if (e.kind === "program") programs.set(e.channel, e.a);
      if (e.kind !== "on" && e.kind !== "off") continue;
      const key = `${e.channel}:${e.a}`;
      const started = open.get(key);
      if (started) {
        open.delete(key);
        let t = byChannel.get(e.channel);
        if (!t) byChannel.set(e.channel, (t = { name, channel: e.channel, program: programs.get(e.channel) ?? 0, notes: [] }));
        const startMs = ms(started.tick);
        t.notes.push({ startMs, durMs: Math.max(1, ms(e.tick) - startMs), pitch: e.a, velocity: started.b });
      }
      if (e.kind === "on") open.set(key, e);
    }
    for (const t of byChannel.values()) {
      t.notes.sort((x, y) => x.startMs - y.startMs || x.pitch - y.pitch);
      lengthMs = Math.max(lengthMs, ...t.notes.map((n) => n.startMs + n.durMs));
      tracks.push(t);
    }
  }
  const first = tempos[0];
  return { bpm: first ? Math.round(60000000 / first.a) : 120, lengthMs, tracks };
}

// Scrittura (formato 1): la prima traccia ha il tempo, poi una per strumento. Tempi in tick (division per battito)
export interface WriteTrack {
  name: string;
  channel: number;
  program: number;
  notes: { tick: number; dur: number; pitch: number; velocity: number }[];
}

function varLen(v: number): number[] {
  const out = [v & 0x7f];
  while ((v >>= 7)) out.unshift((v & 0x7f) | 0x80);
  return out;
}

function chunk(id: string, body: number[]): number[] {
  const len = body.length;
  return [...Buffer.from(id, "latin1"), (len >>> 24) & 0xff, (len >>> 16) & 0xff, (len >>> 8) & 0xff, len & 0xff, ...body];
}

export function writeMidi(bpm: number, division: number, lengthTicks: number, tracks: WriteTrack[]): Uint8Array {
  const us = Math.round(60000000 / bpm);
  const tempo = [0, 0xff, 0x51, 3, (us >> 16) & 0xff, (us >> 8) & 0xff, us & 0xff, ...varLen(lengthTicks), 0xff, 0x2f, 0];
  const out = [...chunk("MThd", [0, 1, 0, tracks.length + 1, (division >> 8) & 0xff, division & 0xff]), ...chunk("MTrk", tempo)];
  for (const t of tracks) {
    const name = [...Buffer.from(t.name, "latin1")];
    const events: { tick: number; bytes: number[] }[] = [];
    for (const n of t.notes) {
      events.push({ tick: n.tick, bytes: [0x90 | t.channel, n.pitch, n.velocity] });
      events.push({ tick: n.tick + n.dur, bytes: [0x80 | t.channel, n.pitch, 0] });
    }
    // A pari tick prima si spegne, poi si accende: due note uguali di fila restano due note
    events.sort((a, b) => a.tick - b.tick || (a.bytes[0] & 0xf0) - (b.bytes[0] & 0xf0));
    const body = [0, 0xff, 0x03, ...varLen(name.length), ...name, 0, 0xc0 | t.channel, t.program];
    let at = 0;
    for (const e of events) {
      body.push(...varLen(e.tick - at), ...e.bytes);
      at = e.tick;
    }
    body.push(...varLen(Math.max(0, lengthTicks - at)), 0xff, 0x2f, 0);
    out.push(...chunk("MTrk", body));
  }
  return Uint8Array.from(out);
}
