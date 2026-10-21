// Il brano di prova dell'arena musicale (#423), scritto da noi: 16 battute a 120 bpm in La minore
// (La-, Fa, Do, Sol), basso, accordi, melodia e batteria. Scrive public/assets/music/midi/sala-prove.mid;
// poi npm run midi:import -- public/assets/music/midi/sala-prove.mid sala-prove
// npx tsx scripts/midi-demo.ts
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { writeMidi, type WriteTrack } from "./midi";

const Q = 480; // tick per battito
const BAR = 4 * Q;
const BARS = 16;
// Fondamentali del giro: La2, Fa2, Do3, Sol2
const ROOTS = [45, 41, 48, 43];
const TRIADS = [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]; // La-, Fa, Do (rivolto), Sol

const bass: WriteTrack = { name: "Basso", channel: 0, program: 38, notes: [] };
const chords: WriteTrack = { name: "Accordi", channel: 1, program: 89, notes: [] };
const lead: WriteTrack = { name: "Melodia", channel: 2, program: 80, notes: [] };
const drums: WriteTrack = { name: "Batteria", channel: 9, program: 0, notes: [] };

for (let bar = 0; bar < BARS; bar++) {
  const t0 = bar * BAR;
  const root = ROOTS[bar % 4];
  // Basso a semiminime: fondamentale, quinta, ottava, quinta (nelle ultime 4 battute sale di più)
  const steps = bar >= 12 ? [0, 7, 12, 15] : [0, 7, 12, 7];
  steps.forEach((s, i) => bass.notes.push({ tick: t0 + i * Q, dur: Q - 40, pitch: root + s, velocity: 100 }));
  for (const p of TRIADS[bar % 4]) chords.notes.push({ tick: t0, dur: BAR - 20, pitch: p, velocity: 60 });
  // Cassa su 1 e 3, rullante su 2 e 4, battimani sull'ultimo ottavo ogni due battute, charleston a ottavi
  for (const b of [0, 2]) drums.notes.push({ tick: t0 + b * Q, dur: Q / 4, pitch: 36, velocity: 110 });
  for (const b of [1, 3]) drums.notes.push({ tick: t0 + b * Q, dur: Q / 4, pitch: 38, velocity: 100 });
  if (bar % 2 === 1) drums.notes.push({ tick: t0 + 3.5 * Q, dur: Q / 4, pitch: 39, velocity: 100 });
  for (let e = 0; e < 8; e++) drums.notes.push({ tick: t0 + (e * Q) / 2, dur: Q / 4, pitch: 42, velocity: e % 2 ? 50 : 75 });
}

// Melodia: due frasi da 8 battute sulla scala pentatonica di La minore. [battito di partenza, durata in battiti, nota]
const A4 = 69, C5 = 72, D5 = 74, E5 = 76, G5 = 79, A5 = 81, G4 = 67, E4 = 64;
const phrase: [number, number, number][] = [
  [0, 1.5, E5], [1.5, 0.5, D5], [2, 2, C5],
  [4, 1, A4], [5, 1, C5], [6, 2, D5],
  [8, 1.5, E5], [9.5, 0.5, G5], [10, 1, E5], [11, 1, D5],
  [12, 3, D5], [15, 1, G4],
  [16, 1.5, A4], [17.5, 0.5, C5], [18, 2, E5],
  [20, 1, A5], [21, 1, G5], [22, 2, E5],
  [24, 1, D5], [25, 1, C5], [26, 1, D5], [27, 1, E5],
  [28, 3, A4], [31, 1, E4],
];
const answer: [number, number, number][] = phrase.map(([b, d, p], i) => {
  // La seconda frase risponde: la stessa ritmica, una nota su tre spostata, e la chiusura sul La alto
  if (i === phrase.length - 2) return [b, d, A5];
  if (i === phrase.length - 1) return [b, d, G5];
  return [b, d, i % 3 === 1 ? (p === G5 ? A5 : p === E5 ? G5 : p === D5 ? E5 : p === C5 ? D5 : C5) : p];
});
for (const [b, d, p] of [...phrase, ...answer.map(([b, d, p]) => [b + 32, d, p] as [number, number, number])]) {
  lead.notes.push({ tick: Math.round(b * Q), dur: Math.round(d * Q) - 30, pitch: p, velocity: 95 });
}

const out = fileURLToPath(new URL("../public/assets/music/midi/", import.meta.url));
mkdirSync(out, { recursive: true });
writeFileSync(out + "sala-prove.mid", writeMidi(120, Q, BARS * BAR, [bass, chords, lead, drums]));
console.log(`scritto ${out}sala-prove.mid`);
