// Arena musicale (#423): le tracce di un brano (preso da un MIDI con scripts/midi-import.ts) diventano piattaforme
// mobili che si muovono o compaiono a tempo con le note. Qui si calcolano una volta, all'avvio, le chiavi (keys) e le
// finestre (on) delle piattaforme: la fisica e Godot le leggono come quelle di ogni altra piattaforma mobile.

import { MUSIC_STAGE } from "./constants";
import type { MovingPlatform } from "./stages";

export interface SongTrack {
  name: string; // il nome della traccia nel MIDI: è quello con cui la sceglie l'arena
  drums: boolean; // canale 10 del MIDI
  notes: [number, number, number][]; // [inizio ms, durata ms, nota MIDI], in ordine di inizio
}

export interface Song {
  id: string; // anche il nome del file public/assets/music/<id>.ogg
  name: string;
  bpm: number;
  lengthMs: number; // un giro del brano: le piattaforme ripartono da capo con la musica
  tracks: SongTrack[];
}

// Cosa fa una traccia nell'arena. Con group, i bottoni sonori di quel gruppo cambiano le sue piattaforme (stages.ts, pads)
export type TrackRole = { group?: string } & (
  // Ascensore: sta in x e sale con le note più alte (da yLow per la più bassa a yHigh per la più alta).
  // Con invert va al contrario: due ascensori sulla stessa traccia si incrociano
  | { role: "lift"; track: string; x: number; width: number; yLow: number; yHigh: number; invert?: boolean; tint: number }
  // Navetta: sta a y e va a destra con le note più alte, da xLow a xHigh (bordo sinistro)
  | { role: "slide"; track: string; y: number; width: number; xLow: number; xHigh: number; tint: number }
  // Tasti: ogni nota accende per la sua durata la piattaforma della sua altezza, come in un piano roll.
  // Le altezze diverse si dividono gli slot in ordine (la più bassa nel primo); con pitches si prendono solo quelle note
  | { role: "keys"; track: string; slots: { x: number; y: number }[]; width: number; pitches?: number[]; tint: number }
);

const findTrack = (song: Song, name: string) => {
  const t = song.tracks.find((tr) => tr.name === name);
  if (!t) throw new Error(`${song.id}: manca la traccia "${name}"`);
  return t;
};

// Le note che partono insieme (un accordo) contano come una: la più bassa, che è quella che si sente sotto
function melodyLine(notes: [number, number, number][]): [number, number, number][] {
  const out: [number, number, number][] = [];
  for (const n of notes) {
    const last = out[out.length - 1];
    if (last && Math.abs(last[0] - n[0]) < MUSIC_STAGE.chordMs) {
      if (n[2] < last[2]) out[out.length - 1] = n;
    } else out.push(n);
  }
  return out;
}

// Le chiavi di una piattaforma che va dove dice la nota: a ogni nota scivola in glideMs al suo posto e poi resta
function followKeys(notes: [number, number, number][], place: (pitch: number) => { x: number; y: number }, glideMs: number, lengthMs: number): [number, number, number][] {
  const line = melodyLine(notes);
  if (line.length === 0) return [];
  const keys: [number, number, number][] = [];
  let at = place(line[line.length - 1][2]); // il giro prima finiva sull'ultima nota
  for (const [start, , pitch] of line) {
    const to = place(pitch);
    if (to.x === at.x && to.y === at.y) continue;
    const t = Math.max(start, (keys[keys.length - 1]?.[0] ?? -1) + 1);
    if (t + glideMs >= lengthMs) break;
    keys.push([t, at.x, at.y], [t + glideMs, to.x, to.y]);
    at = to;
  }
  return keys.length ? keys : [[0, at.x, at.y]];
}

const span = (pitches: number[]) => {
  const lo = Math.min(...pitches);
  const hi = Math.max(...pitches);
  return (p: number) => (hi > lo ? (p - lo) / (hi - lo) : 0.5);
};

// Le piattaforme di un'arena musicale: una o più per ogni ruolo, in ordine
export function songMovers(song: Song, roles: TrackRole[]): MovingPlatform[] {
  const periodMs = song.lengthMs;
  const out: MovingPlatform[] = [];
  for (const r of roles) {
    const notes = findTrack(song, r.track).notes;
    const k = span(notes.map((n) => n[2]));
    if (r.role === "lift") {
      const y = (p: number) => Math.round(r.yLow + (r.yHigh - r.yLow) * (r.invert ? 1 - k(p) : k(p)));
      const keys = followKeys(notes, (p) => ({ x: r.x, y: y(p) }), MUSIC_STAGE.liftGlideMs, periodMs);
      const ys = keys.map((kk) => kk[2]);
      const path = [{ x: r.x, y: Math.max(...ys) }, { x: r.x, y: Math.min(...ys) }];
      out.push({ width: r.width, path, periodMs, keys, kind: "nota", tint: r.tint, ...(r.group && { group: r.group }) });
    } else if (r.role === "slide") {
      const x = (p: number) => Math.round(r.xLow + (r.xHigh - r.xLow) * k(p));
      const keys = followKeys(notes, (p) => ({ x: x(p), y: r.y }), MUSIC_STAGE.slideGlideMs, periodMs);
      const xs = keys.map((kk) => kk[1]);
      const path = [{ x: Math.min(...xs), y: r.y }, { x: Math.max(...xs), y: r.y }];
      out.push({ width: r.width, path, periodMs, keys, kind: "nota", tint: r.tint, ...(r.group && { group: r.group }) });
    } else {
      const picked = r.pitches ? notes.filter((n) => r.pitches!.includes(n[2])) : notes;
      const heights = [...new Set(picked.map((n) => n[2]))].sort((a, b) => a - b);
      r.slots.forEach((slot, i) => {
        // Più altezze dello stesso slot (quando sono più degli slot) si sommano; una nota tiene la piattaforma
        // almeno minOnMs, così ci si fa in tempo a salire, e le finestre che si toccano diventano una sola
        const mine = picked.filter((n) => heights.indexOf(n[2]) % r.slots.length === i);
        const on: [number, number][] = [];
        for (const [start, dur] of mine) {
          const end = Math.min(periodMs, start + Math.max(dur, MUSIC_STAGE.keyMinOnMs));
          const last = on[on.length - 1];
          if (last && start <= last[1] + MUSIC_STAGE.keyMergeMs) last[1] = Math.max(last[1], end);
          else on.push([start, end]);
        }
        if (on.length === 0) return;
        out.push({ width: r.width, path: [slot, slot], periodMs, on, kind: "nota", tint: r.tint, ...(r.group && { group: r.group }) });
      });
    }
  }
  return out;
}
