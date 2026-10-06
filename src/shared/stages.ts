// Le arene. Aggiungerne una = un blocco qui (e, se ha uno sfondo, una cartella in public/assets/stages/<id>/).
// La fisica legge solo questi dati, il client li disegna: un'arena non ha codice suo.

import { WORLD } from "./constants";

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
  spawns: { x: number; y: number }[]; // punti di partenza, uno per giocatore (y = piedi)
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
    spawns: [0.3, 0.7, 0.45, 0.55].map((f) => ({ x: MAIN.x + MAIN.width * f, y: MAIN.y })),
    respawn: { x: WORLD.width / 2, y: 160 },
    colors: { sky: 0x1d2b3a, solid: 0x5a3d26, solidEdge: 0x8b6a45, platform: 0xa0a8b8 },
  },
};

// Un id sconosciuto (o mancante) diventa l'arena base
export function getStage(id: string | undefined): StageSpec {
  return (id && Object.hasOwn(STAGES, id) && STAGES[id]) || STAGES[DEFAULT_STAGE_ID];
}
