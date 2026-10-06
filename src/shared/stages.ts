// Le arene. Aggiungerne una = un blocco qui (e, se ha uno sfondo, una cartella in public/assets/stages/<id>/).
// La fisica legge solo questi dati, il client li disegna: un'arena non ha codice suo.

import { WORLD } from "./constants";
import { generateStage, seedFromStageId } from "./stageGenerator";

export interface Rect {
  x: number; // bordo sinistro, pixel
  y: number; // superficie su cui si cammina
  width: number;
  height: number;
}

export interface ThinPlatform {
  x: number; // bordo sinistro
  y: number; // superficie
  width: number;
}

export interface StageSpec {
  id: string;
  name: string;
  solids: Rect[]; // blocchi pieni: ci si cammina sopra e non si attraversano
  platforms: ThinPlatform[]; // sottili: si attraversano dal basso e scendendo con giù
  blastZone: { left: number; right: number; top: number; bottom: number }; // chi esce perde una vita
  spawns: { x: number; y: number }[]; // punti di partenza, uno per giocatore (y = piedi), in coppie simmetriche
  respawn: { x: number; y: number }; // dove si ricompare dopo aver perso una vita
  colors: { sky: number; solid: number; solidEdge: number; platform: number }; // finché non c'è uno sfondo disegnato
}

export const DEFAULT_STAGE_ID = "palco";

const MAIN = { x: 240, y: 560, width: 800, height: 80 };

export const STAGES: Record<string, StageSpec> = {
  // L'arena di partenza: un palco principale e tre piattaforme sottili
  palco: {
    id: "palco",
    name: "Il Palco",
    solids: [MAIN],
    platforms: [
      { x: 340, width: 200, y: 420 },
      { x: 740, width: 200, y: 420 },
      { x: 540, width: 200, y: 290 },
    ],
    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },
    spawns: [0.3, 0.7, 0.45, 0.55, 0.2, 0.8, 0.37, 0.63].map((f) => ({ x: MAIN.x + MAIN.width * f, y: MAIN.y })),
    respawn: { x: WORLD.width / 2, y: 160 },
    colors: { sky: 0x1d2b3a, solid: 0x5a3d26, solidEdge: 0x8b6a45, platform: 0xa0a8b8 },
  },

  // Due isole con un vuoto in mezzo e un ponte sottile sopra: chi cade nel buco perde una vita.
  // TODO community: un nome e un posto nostro per quest'arena (#14)
  isole: {
    id: "isole",
    name: "Le Isole",
    solids: [
      { x: 200, y: 560, width: 340, height: 90 },
      { x: 740, y: 560, width: 340, height: 90 },
    ],
    platforms: [
      { x: 540, width: 200, y: 450 },
      { x: 260, width: 180, y: 410 },
      { x: 840, width: 180, y: 410 },
      { x: 560, width: 160, y: 300 },
    ],
    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },
    spawns: [
      { x: 370, y: 560 },
      { x: 910, y: 560 },
      { x: 270, y: 560 },
      { x: 1010, y: 560 },
      { x: 470, y: 560 },
      { x: 810, y: 560 },
      { x: 320, y: 560 },
      { x: 960, y: 560 },
    ],
    respawn: { x: WORLD.width / 2, y: 170 },
    colors: { sky: 0x123047, solid: 0x2f5d3a, solidEdge: 0x7cbf6a, platform: 0xe8d9a8 },
  },
};

// Le arene generate si ricreano dal seme; si tengono le ultime per non rigenerarle a ogni chiamata
const generated = new Map<string, StageSpec>();

// Un id sconosciuto (o mancante) diventa l'arena base; "casuale-<seme>" un'arena generata
export function getStage(id: string | undefined): StageSpec {
  if (id && Object.hasOwn(STAGES, id)) return STAGES[id];
  const seed = id ? seedFromStageId(id) : null;
  if (seed === null) return STAGES[DEFAULT_STAGE_ID];
  let stage = generated.get(id!);
  if (!stage) {
    if (generated.size > 50) generated.clear();
    stage = generateStage(seed);
    generated.set(id!, stage);
  }
  return stage;
}
