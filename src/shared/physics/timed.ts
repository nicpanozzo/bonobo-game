// Pezzi a tempo e fasi dell'arena (#433): blocchi, piattaforme, trappole e getti che ci sono solo in certe finestre
// del tempo dell'arena, e fasi che cambiano zone di espulsione e punto di ritorno. Dipende solo da ctx.timeMs:
// Godot rifà gli stessi calcoli (piece_on in predict/movement.gd, piece_alpha in stage_motion.gd).

import type { StagePhase, StageSpec, TimeWindows } from "../stages";

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
  return !!stage.phases?.length || stage.solids.some((s) => s.on || s.forLeader) || stage.platforms.some((p) => p.on || p.forLeader);
}

interface ViewCache {
  timed: boolean;
  solids: boolean[]; // quali c'erano nell'ultima vista
  platforms: boolean[];
  phase: number;
  leader: number; // la squadra del premio con cui è fatta la vista
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
    c = { timed: stageIsTimed(base), solids: [], platforms: [], phase: -2, leader: 0, view: base };
    caches.set(base, c);
  }
  if (!c.timed) return base;
  const phase = phaseIndexAt(base, timeMs);
  let same = phase === c.phase && leader === c.leader;
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
  bases.set(view, base);
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
