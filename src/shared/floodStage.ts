// Il Diluvio: l'arena delle Isole sommersa da un mare che sale per tutta la partita. Si parte sull'isola in fondo e si
// combatte arrampicandosi su relitti che galleggiano (assi, porte, tetti), zattere che vanno avanti e indietro e ogni
// tanto una cima larga (un tetto, un campanile, una collina), fino all'Arca in cima, dove il mare si ferma.
// I pezzi si generano da un seme fisso, così server e client li hanno uguali. Ognuno c'è solo da quando la cima del
// cielo (FLOOD.skyPx sopra il mare) lo raggiunge a quando il mare lo sommerge: in ogni momento la fisica e gli oggetti
// vedono solo la fetta vicina alla superficie.

import { FLOOD, STAGE_CHECK, WORLD } from "./constants";
import { rng } from "./stageGenerator";
import { riseTimeMs } from "./physics/timed";
import type { MovingPlatform, Rect, StageRise, StageSpec, ThinPlatform } from "./stages";

export const FLOOD_LAYOUT = {
  height: 9400, // altezza del mondo
  waterY: 9120, // la superficie all'inizio, sotto l'isola
  islandY: 9000, // l'isola di partenza
  arkY: 1080, // il ponte dell'Arca, in cima
  rowGapPx: 120, // tra una fila di relitti e l'altra: meno di un salto
  firstRowY: 8880,
  lastRowY: 1200,
  seed: 4040,
};

export const FLOOD_RISE: StageRise = {
  startMs: FLOOD.startMs,
  pxPerS: FLOOD.pxPerS,
  accelPxPerS2: FLOOD.accelPxPerS2,
  stepMs: FLOOD.stepMs,
  waterY: FLOOD_LAYOUT.waterY,
  maxPx: FLOOD_LAYOUT.waterY - FLOOD_LAYOUT.arkY - 140, // il mare si ferma 140 px sotto il ponte dell'Arca
};

// Le finestre di un pezzo con la superficie a y: da quando il cielo lo raggiunge a quando il mare lo sommerge
function floodWindow(y: number): [number, number][] {
  const from = riseTimeMs(FLOOD_RISE, FLOOD_RISE.waterY - y - FLOOD.skyPx);
  const to = riseTimeMs(FLOOD_RISE, FLOOD_RISE.waterY - y + FLOOD.drownPx);
  return [[Math.round(from), Number.isFinite(to) ? Math.round(to) : 1e12]];
}

// Sposta x quanto basta perché il pezzo largo w stia a portata di salto (STAGE_CHECK.sideReach) da uno della fila sotto
function nearRow(x: number, w: number, below: { x: number; width: number }[]): number {
  if (below.length === 0) return x;
  const gap = (b: { x: number; width: number }) => Math.max(0, b.x - (x + w), x - (b.x + b.width));
  const best = below.reduce((a, b) => (gap(b) < gap(a) ? b : a));
  const reach = STAGE_CHECK.sideReach - 20;
  if (gap(best) <= reach) return x;
  return x < best.x ? best.x - w - reach : best.x + best.width + reach;
}

export interface FloodPieces {
  solids: Rect[];
  platforms: ThinPlatform[];
  movers: MovingPlatform[];
}

export function floodPieces(): FloodPieces {
  const r = rng(FLOOD_LAYOUT.seed);
  const L = FLOOD_LAYOUT;
  const solids: Rect[] = [
    { x: 240, y: L.islandY, width: 800, height: 260, on: floodWindow(L.islandY) }, // l'isola di partenza (finisce sott'acqua presto)
  ];
  const platforms: ThinPlatform[] = [];
  const movers: MovingPlatform[] = [];
  let row = 0;
  let below: { x: number; width: number }[] = [solids[0]];
  for (let y = L.firstRowY; y >= L.lastRowY; y -= L.rowGapPx, row++) {
    const on = floodWindow(y);
    const here: { x: number; width: number }[] = [];
    const add = (x: number, width: number) => {
      const p = { x: Math.max(40, Math.min(WORLD.width - 40 - width, nearRow(x, width, below))), y, width, on };
      platforms.push(p);
      here.push(p);
    };
    if (row % 10 === 6) {
      // Una cima larga, ora a sinistra ora a destra: un posto dove fermarsi a combattere
      const w = 340 + Math.round(r.next() * 8) * 10;
      const x = row % 20 === 6 ? 120 + Math.round(r.next() * 10) * 10 : WORLD.width - 120 - w - Math.round(r.next() * 10) * 10;
      const top = { x: nearRow(x, w, below), y, width: w, height: 70, on };
      solids.push(top);
      here.push(top);
      add(top.x < 640 ? 820 : 260, 160); // e dall'altra parte un relitto per salire
      below = here;
      continue;
    }
    if (row % 8 === 3) {
      // Una zattera che va da una parte all'altra (resta anche sott'acqua, ma lì è fuori dalla zona)
      const w = 150;
      movers.push({ width: w, path: [{ x: 70, y }, { x: WORLD.width - 70 - w, y }], periodMs: 9000 + (row % 3) * 1500, pauseMs: 600, offsetMs: (row * 1700) % 9000, kind: "zattera" });
      // E un relitto fermo nella stessa fila, così la scalata non dipende da dove sta la zattera
      add(row % 16 === 3 ? 420 : 740, 120);
      below = here;
      continue;
    }
    // Due o tre relitti per fila, ognuno nella sua fetta di larghezza, sfasati tra una fila e l'altra
    const count = r.next() < 0.45 ? 3 : 2;
    const zone = Math.floor((WORLD.width - 120) / count);
    for (let k = 0; k < count; k++) {
      const w = 110 + Math.round(r.next() * 8) * 10;
      const x0 = 60 + k * zone;
      const x = x0 + Math.round((r.next() * Math.max(0, zone - w)) / 10) * 10;
      add(x, w);
    }
    below = here;
  }
  // L'Arca: il ponte su cui finisce la scalata, sempre lì (il mare si ferma prima)
  solids.push({ x: 290, y: L.arkY, width: 700, height: 120 });
  platforms.push({ x: 520, y: L.arkY - 120, width: 240 }); // il tetto della cabina
  return { solids, platforms, movers };
}

// I pezzi dell'arena, fatti una volta sola
const PIECES = floodPieces();

export function floodStage(): StageSpec {
  const L = FLOOD_LAYOUT;
  return {
    id: "isole",
    name: "Il Diluvio",
    height: L.height,
    camera: { minZoom: 0.55 },
    solids: PIECES.solids,
    platforms: PIECES.platforms,
    movers: PIECES.movers,
    rise: FLOOD_RISE,
    // All'inizio: fondo poco sotto la superficie, cielo FLOOD.skyPx sopra. Poi salgono col mare (stageAt)
    blastZone: { left: -250, right: WORLD.width + 250, top: L.waterY - FLOOD.skyPx, bottom: L.waterY + 40 },
    spawns: [0.3, 0.7, 0.45, 0.55, 0.2, 0.8, 0.37, 0.63].map((f) => ({ x: 240 + 800 * f, y: L.islandY })),
    respawn: { x: WORLD.width / 2, y: L.waterY - FLOOD.respawnPx },
    colors: { sky: 0x2a3a4a, solid: 0x6b4a2b, solidEdge: 0xe8d9a8, platform: 0xc8a676 },
    // Più lenta e morbida, da isola, ma in minore: il cielo è in tempesta
    music: { bpm: 112, chords: ["Am", "F", "C", "G"], lead: "triangle" },
  };
}
