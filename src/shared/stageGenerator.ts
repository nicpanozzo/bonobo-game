// Arene generate da un seme: lo stesso seme dà la stessa arena su server e client,
// quindi in rete basta mandare l'id "casuale-<seme>".
// Le arene sono simmetriche, come quasi tutte quelle dei platform fighter competitivi:
// nessuno parte avvantaggiato.

import { STAGE_GEN, WORLD } from "./constants";
import type { Rect, StageSpec, ThinPlatform } from "./stages";

export const RANDOM_STAGE_PREFIX = "casuale-";
const MAX_SEED = 999_999;

const PALETTES: StageSpec["colors"][] = [
  { sky: 0x1d2b3a, solid: 0x5a3d26, solidEdge: 0x8b6a45, platform: 0xa0a8b8 },
  { sky: 0x2b1d3a, solid: 0x3d2a5a, solidEdge: 0x7a5aa8, platform: 0xc8a0e0 },
  { sky: 0x13302a, solid: 0x2e4a2a, solidEdge: 0x6a9a4a, platform: 0xb8d8a0 },
  { sky: 0x3a2418, solid: 0x6a3a1e, solidEdge: 0xc07a3a, platform: 0xf0c890 },
  { sky: 0x0e1a2e, solid: 0x2a3550, solidEdge: 0x5a7ab0, platform: 0x9ad0f0 },
];

export function randomStageId(): string {
  return `${RANDOM_STAGE_PREFIX}${Math.floor(Math.random() * MAX_SEED)}`;
}

// Il seme dentro un id "casuale-123", o null se l'id non è di un'arena generata
export function seedFromStageId(id: string): number | null {
  const m = /^casuale-(\d{1,6})$/.exec(id);
  return m ? Number(m[1]) : null;
}

// Numeri pseudo-casuali ripetibili (mulberry32): niente Math.random qui dentro
function rng(seed: number) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  // Intero in [min, max] a passi di 10 pixel, così le arene restano "pulite"
  const range = ([min, max]: number[]) => min + Math.round((next() * (max - min)) / 10) * 10;
  return { next, range };
}

export function generateStage(seed: number): StageSpec {
  const r = rng(seed);
  const cx = WORLD.width / 2;
  const groundY = r.range(STAGE_GEN.groundY);
  const thickness = r.range(STAGE_GEN.groundThickness);

  // Base: un palco unico o due isole con un vuoto in mezzo
  const solids: Rect[] = [];
  const islands = r.next() < STAGE_GEN.islandsChance;
  if (islands) {
    const w = r.range(STAGE_GEN.islandWidth);
    const gap = r.range(STAGE_GEN.islandGap);
    solids.push({ x: cx - gap / 2 - w, y: groundY, width: w, height: thickness });
    solids.push({ x: cx + gap / 2, y: groundY, width: w, height: thickness });
  } else {
    const w = r.range(STAGE_GEN.singleWidth);
    solids.push({ x: cx - w / 2, y: groundY, width: w, height: thickness });
  }
  const left = solids[0].x;
  const right = solids[solids.length - 1].x + solids[solids.length - 1].width;
  const span = right - left;

  // Piattaforme sottili, a piani: ogni piano si raggiunge con un salto da quello sotto
  const platforms: ThinPlatform[] = [];
  const pw = () => r.range(STAGE_GEN.platformWidth);
  const tier1 = groundY - r.range(STAGE_GEN.tierStep);
  const pairOnTier1 = islands || r.next() < 0.6;
  if (pairOnTier1) {
    const w = pw();
    const offset = Math.max(w / 2 + 40, Math.round((span * (0.22 + r.next() * 0.1)) / 10) * 10);
    platforms.push({ x: cx - offset - w / 2, y: tier1, width: w });
    platforms.push({ x: cx + offset - w / 2, y: tier1, width: w });
  } else {
    const w = pw();
    platforms.push({ x: cx - w / 2, y: tier1, width: w });
  }
  if (r.next() < STAGE_GEN.secondTierChance || islands) {
    // Con le isole c'è sempre una piattaforma centrale in alto, sopra il vuoto
    const w = pw();
    const tier2 = tier1 - r.range(STAGE_GEN.tierStep);
    if (pairOnTier1) {
      platforms.push({ x: cx - w / 2, y: tier2, width: w });
    } else {
      const offset = w / 2 + 60;
      platforms.push({ x: cx - offset - w / 2, y: tier2, width: w });
      platforms.push({ x: cx + offset - w / 2, y: tier2, width: w });
    }
  }

  // Partenze sui blocchi pieni, a coppie simmetriche
  const spawns = islands
    ? [solids[0].x + solids[0].width * 0.5, solids[1].x + solids[1].width * 0.5, solids[0].x + solids[0].width * 0.25, solids[1].x + solids[1].width * 0.75]
    : [0.3, 0.7, 0.45, 0.55].map((f) => left + span * f);

  const top = Math.min(...platforms.map((p) => p.y));
  return {
    id: `${RANDOM_STAGE_PREFIX}${seed}`,
    name: `Arena casuale n. ${seed}`,
    solids,
    platforms,
    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },
    spawns: spawns.map((x) => ({ x: Math.round(x), y: groundY })),
    respawn: { x: cx, y: Math.max(100, Math.min(200, top - 130)) },
    colors: PALETTES[Math.floor(r.next() * PALETTES.length)],
  };
}
