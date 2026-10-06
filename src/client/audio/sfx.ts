import type { AudioBus } from "./engine";

// Effetti sonori sintetizzati al volo: niente file da scaricare e nessun problema di licenza.
// Per sostituirne uno con un suono registrato da noi, metti il file in public/assets/sfx/
// e aggiungi una riga in SAMPLE_FILES: il file vince sulla sintesi.

export type SoundName = "light" | "heavy" | "hitLight" | "hitHeavy" | "jump" | "doubleJump" | "land" | "ko" | "taunt" | "start" | "victory" | "point";

// TODO community: suoni registrati da noi (#6), es. light: "assets/sfx/pugno.ogg"
export const SAMPLE_FILES: Partial<Record<SoundName, string>> = {};

export interface PlayOptions {
  volume?: number; // 0-1, moltiplica il volume del suono
  pan?: number; // -1 sinistra, 1 destra
  pitch?: number; // 1 = normale
}

const samples = new Map<SoundName, AudioBuffer>();

export async function loadSamples(bus: AudioBus) {
  await Promise.all(
    Object.entries(SAMPLE_FILES).map(async ([name, path]) => {
      try {
        const data = await (await fetch(path)).arrayBuffer();
        samples.set(name as SoundName, await bus.ctx.decodeAudioData(data));
      } catch {
        console.warn(`Suono ${path} non caricato, uso quello sintetizzato`);
      }
    }),
  );
}

export function playSound(bus: AudioBus, name: SoundName, opts: PlayOptions = {}) {
  const { ctx } = bus;
  const out = ctx.createGain();
  out.gain.value = opts.volume ?? 1;
  const panner = ctx.createStereoPanner();
  panner.pan.value = Math.max(-1, Math.min(1, opts.pan ?? 0));
  out.connect(panner).connect(bus.sfx);

  const sample = samples.get(name);
  if (sample) {
    const src = ctx.createBufferSource();
    src.buffer = sample;
    src.playbackRate.value = opts.pitch ?? 1;
    src.connect(out);
    src.start();
    return;
  }
  RECIPES[name](ctx, out, ctx.currentTime, opts.pitch ?? 1);
}

type Recipe = (ctx: AudioContext, out: AudioNode, t: number, pitch: number) => void;

// Un oscillatore con una curva di frequenza e un inviluppo di volume
function tone(ctx: AudioContext, out: AudioNode, t: number, type: OscillatorType, from: number, to: number, dur: number, vol: number) {
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(from, t);
  osc.frequency.exponentialRampToValueAtTime(Math.max(20, to), t + dur);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.005);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  osc.connect(g).connect(out);
  osc.start(t);
  osc.stop(t + dur + 0.02);
}

let noiseBuffer: AudioBuffer | null = null;

// Rumore bianco filtrato: la base di colpi, fruscii e botti
function noise(ctx: AudioContext, out: AudioNode, t: number, filter: BiquadFilterType, freqFrom: number, freqTo: number, dur: number, vol: number) {
  if (!noiseBuffer || noiseBuffer.sampleRate !== ctx.sampleRate) {
    noiseBuffer = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const d = noiseBuffer.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const src = ctx.createBufferSource();
  src.buffer = noiseBuffer;
  const f = ctx.createBiquadFilter();
  f.type = filter;
  f.frequency.setValueAtTime(freqFrom, t);
  f.frequency.exponentialRampToValueAtTime(Math.max(20, freqTo), t + dur);
  const g = ctx.createGain();
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  src.connect(f).connect(g).connect(out);
  src.start(t);
  src.stop(t + dur + 0.02);
}

const RECIPES: Record<SoundName, Recipe> = {
  // Colpo che parte: un fruscio d'aria, più grave per il pesante
  light: (c, o, t, p) => noise(c, o, t, "bandpass", 3000 * p, 1200 * p, 0.08, 0.5),
  heavy: (c, o, t, p) => noise(c, o, t, "bandpass", 1400 * p, 300 * p, 0.22, 0.7),
  // Colpo a segno: schiocco + tonfo; il pesante ha anche un "boom" basso
  hitLight: (c, o, t, p) => {
    noise(c, o, t, "lowpass", 5000 * p, 800, 0.09, 0.6);
    tone(c, o, t, "square", 320 * p, 90 * p, 0.08, 0.25);
  },
  hitHeavy: (c, o, t, p) => {
    noise(c, o, t, "lowpass", 4000 * p, 200, 0.25, 0.8);
    tone(c, o, t, "sawtooth", 180 * p, 45 * p, 0.3, 0.45);
    tone(c, o, t, "sine", 90 * p, 35, 0.35, 0.6);
  },
  jump: (c, o, t, p) => tone(c, o, t, "square", 280 * p, 560 * p, 0.12, 0.12),
  doubleJump: (c, o, t, p) => tone(c, o, t, "square", 420 * p, 900 * p, 0.12, 0.1),
  land: (c, o, t, p) => noise(c, o, t, "lowpass", 900 * p, 120, 0.1, 1),
  // Fuori dall'arena: esplosione e fischio che scende
  ko: (c, o, t, p) => {
    noise(c, o, t, "lowpass", 2500, 60, 0.9, 1);
    tone(c, o, t, "sine", 70, 30, 0.8, 0.9);
    tone(c, o, t + 0.05, "triangle", 1400 * p, 200 * p, 0.6, 0.25);
  },
  taunt: (c, o, t, p) => {
    tone(c, o, t, "triangle", 660 * p, 640 * p, 0.12, 0.2);
    tone(c, o, t + 0.13, "triangle", 880 * p, 860 * p, 0.18, 0.2);
  },
  start: (c, o, t) => {
    [392, 523, 659, 784].forEach((f, i) => tone(c, o, t + i * 0.09, "square", f, f, 0.14, 0.13));
  },
  // Punto in Bandiera: due note che salgono, più brevi della vittoria
  point: (c, o, t) => {
    [659, 988].forEach((f, i) => tone(c, o, t + i * 0.1, "square", f, f, i === 1 ? 0.3 : 0.1, 0.14));
  },
  victory: (c, o, t) => {
    [523, 659, 784, 1047, 784, 1047].forEach((f, i) => tone(c, o, t + i * 0.12, "square", f, f, i === 5 ? 0.5 : 0.14, 0.14));
  },
};
