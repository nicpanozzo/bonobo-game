// Da un file MIDI a un'arena musicale (#423): le note vanno in src/shared/music/<id>.ts (le legge musicStage.ts
// per fare le piattaforme) e il brano si suona con un sintetizzatore semplice in public/assets/music/<id>.ogg
// (con ffmpeg; senza, resta il .wav, che Godot legge lo stesso).
// npm run midi:import -- percorso/brano.mid <id> ["Nome del brano"]
// Poi npm run export:godot. Le tracce si riconoscono dal nome nel MIDI: vedi src/shared/music/README.md
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { readMidi, type MidiTrack } from "./midi";

const [file, id, title] = process.argv.slice(2);
if (!file || !id || !/^[a-z0-9-]+$/.test(id)) {
  console.error('uso: npm run midi:import -- brano.mid <id-minuscolo> ["Nome"]');
  process.exit(1);
}
const song = readMidi(readFileSync(file));
const tracks = song.tracks.filter((t) => t.notes.length > 0);
const lengthMs = Math.round(song.lengthMs);

// --- Le note per il gioco: [inizio ms, durata ms, nota] per traccia, numeri interi ---
const varName = id.replace(/-/g, "_").toUpperCase();
const data = {
  id,
  name: title ?? id,
  bpm: song.bpm,
  lengthMs,
  tracks: tracks.map((t) => ({
    name: t.name || `Traccia ${t.channel + 1}`,
    drums: t.channel === 9,
    notes: t.notes.map((n) => [Math.round(n.startMs), Math.round(n.durMs), n.pitch]),
  })),
};
const ts = [
  `// Generato da scripts/midi-import.ts da ${file.split("/").pop()}: non si modifica a mano, si rilancia l'import.`,
  `import type { Song } from "../musicStage";`,
  ``,
  `export const ${varName}: Song = {`,
  `  id: ${JSON.stringify(data.id)},`,
  `  name: ${JSON.stringify(data.name)},`,
  `  bpm: ${data.bpm},`,
  `  lengthMs: ${data.lengthMs},`,
  `  tracks: [`,
  ...data.tracks.map(
    (t) => `    { name: ${JSON.stringify(t.name)}, drums: ${t.drums}, notes: [${t.notes.map((n) => `[${n.join(", ")}]`).join(", ")}] },`,
  ),
  `  ],`,
  `};`,
  ``,
].join("\n");
const musicDir = fileURLToPath(new URL("../src/shared/music/", import.meta.url));
mkdirSync(musicDir, { recursive: true });
writeFileSync(`${musicDir}${id}.ts`, ts);
console.log(`note: src/shared/music/${id}.ts (${data.tracks.map((t) => `${t.name} ${t.notes.length}`).join(", ")})`);

// --- Il suono: un sintetizzatore piccolo, uno strumento per famiglia General MIDI ---
const RATE = 44100;
const total = Math.ceil((lengthMs / 1000) * RATE);
const tail = RATE * 2; // le code delle note oltre la fine tornano all'inizio: il giro si chiude senza scatti
const mix = new Float32Array(total + tail);
let seed = 1;
const noise = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x3fffffff) - 1;
const hz = (pitch: number) => 440 * 2 ** ((pitch - 69) / 12);

function add(start: number, samples: Float32Array, gain: number) {
  for (let i = 0; i < samples.length && start + i < mix.length; i++) mix[start + i] += samples[i] * gain;
}

function drum(pitch: number, vel: number): Float32Array {
  const kick = pitch <= 36;
  const snare = pitch === 38 || pitch === 40;
  const clap = pitch === 39;
  const len = Math.round(RATE * (kick ? 0.35 : snare || clap ? 0.2 : 0.06));
  const out = new Float32Array(len);
  let phase = 0;
  let prev = 0;
  for (let i = 0; i < len; i++) {
    const t = i / RATE;
    if (kick) {
      phase += (2 * Math.PI * (45 + 110 * Math.exp(-t * 30))) / RATE;
      out[i] = Math.sin(phase) * Math.exp(-t * 9);
    } else if (snare) {
      phase += (2 * Math.PI * 185) / RATE;
      out[i] = (noise() * 0.7 + Math.sin(phase) * 0.4) * Math.exp(-t * 22);
    } else if (clap) {
      const burst = t < 0.03 ? Math.exp(-(t % 0.01) * 300) : Math.exp(-(t - 0.03) * 25);
      out[i] = noise() * burst * 0.8;
    } else {
      const n = noise();
      out[i] = (n - prev) * 0.5 * Math.exp(-t * 60); // rumore passa-alto: il charleston
      prev = n;
    }
    out[i] *= vel / 127;
  }
  return out;
}

function tone(t: MidiTrack, pitch: number, durMs: number, vel: number): Float32Array {
  const family = Math.floor(t.program / 8); // 4 bassi, 10 lead, 11 pad (General MIDI)
  const bassy = family === 4;
  const pad = family === 11;
  const release = pad ? 0.4 : 0.08;
  const len = Math.round(RATE * (durMs / 1000 + release));
  const out = new Float32Array(len);
  const f = hz(pitch);
  const hold = (durMs / 1000) * RATE;
  let lp = 0;
  for (let i = 0; i < len; i++) {
    const s = i / RATE;
    const attack = Math.min(1, s / (pad ? 0.15 : 0.005));
    const env = attack * (i < hold ? (pad ? 1 : 0.6 + 0.4 * Math.exp(-s * 6)) : Math.exp(-((i - hold) / RATE) / (release / 4)));
    const ph = (f * s) % 1;
    let v: number;
    if (bassy) {
      v = 2 * ph - 1; // dente di sega, poi addolcito
      lp += (v - lp) * 0.08;
      v = lp * 1.6;
    } else if (pad) {
      v = [0.997, 1, 1.004].reduce((a, d) => a + (2 * Math.abs(2 * ((f * d * s) % 1) - 1) - 1), 0) / 3;
    } else if (family === 10) {
      const vib = 1 + 0.004 * Math.sin(2 * Math.PI * 5.5 * s) * Math.min(1, s * 3);
      v = ((f * vib * s) % 1) < 0.5 ? 0.5 : -0.5; // onda quadra
    } else v = 2 * Math.abs(2 * ph - 1) - 1;
    out[i] = v * env * (vel / 127);
  }
  return out;
}

const GAIN: Record<string, number> = { drums: 0.7, bass: 0.55, pad: 0.16, lead: 0.32, other: 0.3 };
for (const t of tracks) {
  const family = Math.floor(t.program / 8);
  const kind = t.channel === 9 ? "drums" : family === 4 ? "bass" : family === 11 ? "pad" : family === 10 ? "lead" : "other";
  for (const n of t.notes) {
    const start = Math.round((n.startMs / 1000) * RATE);
    add(start, kind === "drums" ? drum(n.pitch, n.velocity) : tone(t, n.pitch, n.durMs, n.velocity), GAIN[kind]);
  }
}
// Un'eco leggera a tre ottavi di battito, poi le code tornano all'inizio del giro
const delay = Math.round((60 / song.bpm) * 0.75 * RATE);
for (let i = delay; i < mix.length; i++) mix[i] += mix[i - delay] * 0.22;
for (let i = 0; i < tail; i++) mix[i % total] += mix[total + i];
const loop = mix.subarray(0, total);
let peak = 0;
for (const v of loop) peak = Math.max(peak, Math.abs(v));
const norm = peak > 0 ? 0.89 / peak : 1;

const wav = Buffer.alloc(44 + total * 2);
wav.write("RIFF", 0, "latin1");
wav.writeUInt32LE(36 + total * 2, 4);
wav.write("WAVEfmt ", 8, "latin1");
wav.writeUInt32LE(16, 16);
wav.writeUInt16LE(1, 20);
wav.writeUInt16LE(1, 22);
wav.writeUInt32LE(RATE, 24);
wav.writeUInt32LE(RATE * 2, 28);
wav.writeUInt16LE(2, 32);
wav.writeUInt16LE(16, 34);
wav.write("data", 36, "latin1");
wav.writeUInt32LE(total * 2, 40);
for (let i = 0; i < total; i++) wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, loop[i] * norm)) * 32767), 44 + i * 2);

const audioDir = fileURLToPath(new URL("../public/assets/music/", import.meta.url));
mkdirSync(audioDir, { recursive: true });
const wavPath = `${audioDir}${id}.wav`;
writeFileSync(wavPath, wav);
try {
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", wavPath, "-c:a", "libvorbis", "-q:a", "4", `${audioDir}${id}.ogg`]);
  rmSync(wavPath);
  console.log(`suono: public/assets/music/${id}.ogg`);
} catch {
  console.log(`suono: public/assets/music/${id}.wav (ffmpeg non c'è: va bene lo stesso, ma pesa di più)`);
}
