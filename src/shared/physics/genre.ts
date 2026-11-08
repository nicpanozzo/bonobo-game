// Il Palco: il genere che suona cambia le regole. Senza dischi il DJ gira da solo (stage.genres.order, uno ogni
// everyMs); un disco (bottone con effect.genre) impone il suo per effect.durationMs, e vince l'ultimo premuto.
// metal: colpi più forti e fiamme (trappole con genre "metal"); reggae: gravità da luna; techno: le piattaforme
// della techno si accendono a turno ogni GENRE.technoBlinkBeats battiti. Dipende solo dal tempo dell'arena e dalle
// pressioni dei bottoni: Godot rifà lo stesso calcolo (genre_at in stage_motion.gd) con lo snapshot.

import { GENRE } from "../constants";
import type { Genre, StageSpec } from "../stages";

const mod = (a: number, b: number) => ((a % b) + b) % b;

// Il genere del DJ quando nessuno tocca i dischi
export function autoGenre(stage: StageSpec, timeMs: number): Genre | null {
  const g = stage.genres;
  if (!g || g.order.length === 0 || timeMs < g.startMs) return null; // la prova del suono
  return g.order[mod(Math.floor((timeMs - g.startMs) / g.everyMs), g.order.length)];
}

// Il genere che suona all'istante timeMs: quello dell'ultimo disco ancora in effetto, altrimenti quello del DJ
export function genreAt(stage: StageSpec, timeMs: number, pressedMs?: (number | null)[]): Genre | null {
  if (!stage.genres) return null;
  let best: Genre | null = null;
  let bestAt = -Infinity;
  const pads = stage.pads ?? [];
  for (let i = 0; i < pads.length; i++) {
    const at = pressedMs?.[i];
    const genre = pads[i].effect.genre;
    if (at == null || !genre) continue;
    if (timeMs >= at && timeMs - at < pads[i].effect.durationMs && at > bestAt) {
      best = genre;
      bestAt = at;
    }
  }
  return best ?? autoGenre(stage, timeMs);
}

// Il giro della techno (0 o 1): le piattaforme con beat uguale ci sono, le altre no
export function technoBeat(stage: StageSpec, timeMs: number): number {
  const g = stage.genres;
  if (!g) return 0;
  return mod(Math.floor(timeMs / (g.beatMs * GENRE.technoBlinkBeats)), 2);
}

// Se un pezzo con genre (e beat) c'è col genere g all'istante timeMs
export function genreOk(p: { genre?: Genre; beat?: number }, g: Genre | null, beat: number): boolean {
  if (!p.genre) return true;
  if (p.genre !== g) return false;
  return p.beat === undefined || p.beat === beat;
}

// Moltiplicatori del genere: la gravità e il lancio dei colpi
export const genreGravity = (g: Genre | null): number => (g === "reggae" ? GENRE.reggaeGravityMult : 1);
export const genreKnockback = (g: Genre | null): number => (g === "metal" ? GENRE.metalKnockbackMult : 1);
