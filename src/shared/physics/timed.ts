// Pezzi a tempo e fasi dell'arena (#433): blocchi, piattaforme, trappole e getti che ci sono solo in certe finestre
// del tempo dell'arena, e fasi che cambiano zone di espulsione e punto di ritorno. Dipende solo da ctx.timeMs:
// Godot rifà gli stessi calcoli (piece_on in predict/movement.gd, piece_alpha in stage_motion.gd).

import type { StagePhase, StageRise, StageSpec, TimeWindows } from "../stages";

// Se un pezzo c'è all'istante timeMs: senza finestre sempre, altrimenti solo dentro una [da, a)
export function pieceOn(p: { on?: TimeWindows }, timeMs: number): boolean {
  return !p.on || p.on.some(([from, to]) => timeMs >= from && timeMs < to);
}

// Un pezzo del premio (forLeader) c'è solo se la squadra in testa congelata a prizeAtMs è la sua; tutti gli altri non ne dipendono
export const prizeOk = (p: { forLeader?: number }, leader: number) => p.forLeader === undefined || p.forLeader === leader;

// Indice della fase attiva: l'ultima con startMs <= timeMs (le fasi sono in ordine), -1 se non ce ne sono
export function phaseIndexAt(stage: StageSpec, timeMs: number): number {
  const phases = stage.phases ?? [];
  let i = -1;
  while (i + 1 < phases.length && phases[i + 1].startMs <= timeMs) i++;
  return i;
}

export function phaseAt(stage: StageSpec, timeMs: number): StagePhase | undefined {
  return stage.phases?.[phaseIndexAt(stage, timeMs)];
}

// Un'arena cambia nel tempo se ha fasi o blocchi e piattaforme a tempo (trappole e getti si saltano dove si usano)
export function stageIsTimed(stage: StageSpec): boolean {
  return !!stage.phases?.length || !!stage.rise || stage.solids.some((s) => s.on || s.forLeader) || stage.platforms.some((p) => p.on || p.forLeader);
}

interface ViewCache {
  timed: boolean;
  solids: boolean[]; // quali c'erano nell'ultima vista
  platforms: boolean[];
  phase: number;
  leader: number; // la squadra del premio con cui è fatta la vista
  step: number; // Il Diluvio: lo scalino del mare con cui è fatta la vista
  view: StageSpec;
}

const caches = new WeakMap<StageSpec, ViewCache>();
const bases = new WeakMap<StageSpec, StageSpec>(); // vista -> arena da cui viene

// L'arena di partenza di una vista fatta da stageAt (o l'arena stessa)
export const baseStage = (stage: StageSpec): StageSpec => bases.get(stage) ?? stage;

// L'arena com'è all'istante timeMs: solo i blocchi e le piattaforme che ci sono, e zone di espulsione e ritorno della
// fase attiva. Trappole, getti e piattaforme mobili restano tutti (gli eventi e i disegni li chiamano per indice).
// Un'arena che non cambia torna così com'è; le altre fanno una vista nuova solo quando cambia qualcosa.
// Gli indici dei blocchi cambiano con la vista: chi ne tiene uno (gli spigoli, ledge.ts) lo rimappa (remapLedges)
// leader: la squadra in testa congelata a prizeAtMs (0 = nessuna, ancora nessuno o pareggio): fa parte della chiave della vista
export function stageAt(stage: StageSpec, timeMs: number, leader = 0): StageSpec {
  const base = baseStage(stage);
  let c = caches.get(base);
  if (!c) {
    c = { timed: stageIsTimed(base), solids: [], platforms: [], phase: -2, leader: 0, step: -1, view: base };
    caches.set(base, c);
  }
  if (!c.timed) return base;
  const phase = phaseIndexAt(base, timeMs);
  const step = base.rise ? riseStep(base.rise, timeMs) : 0;
  let same = phase === c.phase && leader === c.leader && step === c.step;
  same = track(base.solids, c.solids, timeMs, leader) && same;
  same = track(base.platforms, c.platforms, timeMs, leader) && same;
  if (same) return c.view;
  const cache = c;
  const p = base.phases?.[phase];
  const view: StageSpec = {
    ...base,
    solids: base.solids.filter((_, i) => cache.solids[i]),
    platforms: base.platforms.filter((_, i) => cache.platforms[i]),
    blastZone: p?.blastZone ?? base.blastZone,
    respawn: p?.respawn ?? base.respawn,
  };
  if (base.rise) {
    // Il mare è salito: zone di espulsione e punto di ritorno salgono con lui
    const up = riseOffset(base.rise, step * base.rise.stepMs);
    const z = view.blastZone;
    view.blastZone = { ...z, top: z.top - up, bottom: z.bottom - up };
    view.respawn = { x: view.respawn.x, y: view.respawn.y - up };
  }
  bases.set(view, base);
  c.step = step;
  c.phase = phase;
  c.leader = leader;
  c.view = view;
  return view;
}

// Aggiorna chi c'è adesso; true se non è cambiato niente
function track(pieces: { on?: TimeWindows; forLeader?: number }[], seen: boolean[], timeMs: number, leader: number): boolean {
  let same = seen.length === pieces.length;
  seen.length = pieces.length;
  for (let i = 0; i < pieces.length; i++) {
    const on = pieceOn(pieces[i], timeMs) && prizeOk(pieces[i], leader);
    if (seen[i] !== on) {
      seen[i] = on;
      same = false;
    }
  }
  return same;
}

// Lo scalino del mare (Il Diluvio): la vista cambia una volta ogni stepMs, non a ogni passo
export function riseStep(r: NonNullable<StageSpec["rise"]>, timeMs: number): number {
  return Math.floor(Math.max(0, timeMs) / r.stepMs);
}

// Dove sta la superficie del mare all'istante timeMs (a scalini, come la zona di espulsione)
export function waterAt(stage: StageSpec, timeMs: number): number | null {
  const r = baseStage(stage).rise;
  return r ? r.waterY - riseOffset(r, riseStep(r, timeMs) * r.stepMs) : null;
}

// Di quanto è salito il mare all'istante timeMs (pixel, verso l'alto), senza scalini
export function riseOffset(r: StageRise, timeMs: number): number {
  const s = Math.max(0, timeMs - r.startMs) / 1000;
  return Math.min(r.maxPx, r.pxPerS * s + 0.5 * (r.accelPxPerS2 ?? 0) * s * s);
}

// L'istante (ms) in cui il mare è salito di px; Infinity se non ci arriva mai
export function riseTimeMs(r: StageRise, px: number): number {
  if (px <= 0) return 0;
  if (px > r.maxPx) return Infinity;
  const a = r.accelPxPerS2 ?? 0;
  const s = a > 0 ? (-r.pxPerS + Math.sqrt(r.pxPerS * r.pxPerS + 2 * a * px)) / a : px / r.pxPerS;
  return r.startMs + s * 1000;
}
