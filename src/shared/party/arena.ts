// Bonobo Party (#579): arene semplici per i minigiochi, fatte con gli stessi blocchi e piattaforme delle arene vere.
// Niente sfondi nuovi: il client le disegna coi colori, come le arene generate.

import { PREMATCH, WORLD } from "../constants";
import type { StageSpec, ThinPlatform } from "../stages";
import type { Rect } from "../stages";

export interface ArenaParts {
  id: string;
  name: string;
  solids: Rect[];
  platforms?: ThinPlatform[];
  width?: number;
  height?: number;
  sky?: number;
  solid?: number;
  edge?: number;
  platform?: number;
  spawns?: { x: number; y: number }[];
  respawn?: { x: number; y: number };
  camera?: StageSpec["camera"];
  checkpoints?: StageSpec["checkpoints"];
  music?: StageSpec["music"]; // la musica a sintetizzatore, col suo tempo (Sala Prove)
}

// Un'arena da minigioco: zona di espulsione larga attorno al mondo, partenze sul primo blocco se non dette
export function arena(p: ArenaParts): StageSpec {
  const width = p.width ?? WORLD.width;
  const height = p.height ?? WORLD.height;
  const ground = p.solids[0];
  const spawns = p.spawns ?? [0.3, 0.7, 0.45, 0.55, 0.2, 0.8, 0.37, 0.63].map((f) => ({ x: Math.round(ground.x + ground.width * f), y: ground.y }));
  return {
    id: `party-${p.id}`,
    name: p.name,
    hidden: true,
    solids: p.solids,
    platforms: p.platforms ?? [],
    blastZone: { left: -260, right: width + 260, top: -400, bottom: height + 200 },
    spawns,
    respawn: p.respawn ?? { x: Math.round(width / 2), y: Math.max(120, ground.y - 400) },
    colors: { sky: p.sky ?? 0x2b3a55, solid: p.solid ?? 0x5d4a3a, solidEdge: p.edge ?? 0xf2c14e, platform: p.platform ?? 0xc9b48f },
    ...(p.width && { width: p.width }),
    ...(p.height && { height: p.height }),
    ...(p.camera && { camera: p.camera }),
    ...(p.checkpoints && { checkpoints: p.checkpoints }),
    ...(p.music && { music: p.music }),
  };
}

// Il tempo dell'arena riparte da zero alla presentazione: il VIA arriva dopo presentazione e 3, 2, 1
export const GO_STAGE_MS = PREMATCH.introMs + PREMATCH.countdownMs;

// La superficie più alta sotto (x, y) tra blocchi e piattaforme, o null se sotto c'è il vuoto
export function surfaceBelow(stage: StageSpec, x: number, y: number): number | null {
  let best: number | null = null;
  for (const s of [...stage.solids, ...stage.platforms]) {
    if (x < s.x || x > s.x + s.width || s.y < y - 1) continue;
    if (best === null || s.y < best) best = s.y;
  }
  return best;
}
