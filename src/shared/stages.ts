// Le arene. Aggiungerne una = un blocco qui (e, se ha uno sfondo, una cartella in public/assets/stages/<id>/).
// La fisica legge solo questi dati, il client li disegna: un'arena non ha codice suo.

import { WORLD } from "./constants";
import { generateCourse, seedFromCourseId } from "./courseGenerator";
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

// Piattaforma sottile che si muove (ascensore, montacarichi). La posizione dipende solo dal
// tempo dell'arena (elementPosition in physics/elements.ts), così server e client la calcolano uguale.
export interface MovingPlatform {
  width: number;
  path: { x: number; y: number }[]; // punti toccati in ordine (bordo sinistro, superficie), almeno 2
  periodMs: number; // durata di un giro completo, soste comprese
  loop?: boolean; // true: dall'ultimo punto torna dritto al primo; altrimenti fa avanti e indietro
  pauseMs?: number; // sosta a ogni punto, come un ascensore al piano
  offsetMs?: number; // sfasamento, per far partire due piattaforme in momenti diversi
}

// Trappola: un rettangolo che, quando è acceso, toglie percentuale e lancia via chi lo tocca
export interface Hazard extends Rect {
  kind: string; // solo per il disegno: "spuntoni", "fuoco", "laser"...
  damage: number; // percentuale aggiunta
  knockback: number; // pixel/s di lancio di base
  knockbackGrowth: number; // pixel/s in più per ogni punto di percentuale
  angleDeg: number; // direzione del lancio: 90 = dritto in alto, 45 = in diagonale lontano dal centro della trappola
  periodMs?: number; // se c'è, la trappola si accende e si spegne a ciclo
  activeMs?: number; // per quanto resta accesa in ogni ciclo
  offsetMs?: number;
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
  // Solo per i percorsi della modalità Corsa (#57)
  width?: number; // larghezza del mondo se più larga dello schermo: la telecamera segue
  checkpoints?: { x: number; y: number }[]; // dove si ricompare dopo una caduta (y = superficie)
  goal?: Rect; // chi lo tocca vince
  // Elementi dinamici (#14 passo 4)
  movers?: MovingPlatform[];
  hazards?: Hazard[];
}

// Larghezza del mondo di un'arena: lo schermo, o di più per i percorsi
export const stageWidth = (stage: StageSpec) => stage.width ?? WORLD.width;

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

  // Un capannone con un ascensore in mezzo, una navetta che fa avanti e indietro,
  // il fuoco che si accende nella fossa e gli spuntoni ai bordi (#14 passo 4).
  // TODO community: un posto nostro con ascensori e trappole (un magazzino, un cantiere, la palestra?)
  fabbrica: {
    id: "fabbrica",
    name: "La Fabbrica",
    solids: [
      { x: 140, y: 560, width: 300, height: 90 },
      { x: 840, y: 560, width: 300, height: 90 },
      { x: 440, y: 640, width: 400, height: 60 }, // la fossa, sotto il livello delle isole
    ],
    platforms: [],
    movers: [
      // Ascensore: sale e scende in mezzo alla fossa, fermandosi a ogni piano
      { width: 140, path: [{ x: 570, y: 540 }, { x: 570, y: 260 }], periodMs: 7000, pauseMs: 1200 },
      // Navetta: attraversa l'arena da un'isola all'altra
      { width: 150, path: [{ x: 150, y: 400 }, { x: 980, y: 400 }], periodMs: 9000, pauseMs: 600 },
    ],
    hazards: [
      // Fuoco nella fossa: acceso 1,5 s ogni 4 s, lancia in alto
      { kind: "fuoco", x: 440, y: 610, width: 400, height: 30, damage: 8, knockback: 600, knockbackGrowth: 4, angleDeg: 80, periodMs: 4000, activeMs: 1500 },
      // Spuntoni sempre accesi sui bordi esterni delle isole
      { kind: "spuntoni", x: 140, y: 540, width: 60, height: 20, damage: 10, knockback: 500, knockbackGrowth: 6, angleDeg: 60 },
      { kind: "spuntoni", x: 1080, y: 540, width: 60, height: 20, damage: 10, knockback: 500, knockbackGrowth: 6, angleDeg: 60 },
    ],
    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },
    spawns: [
      { x: 300, y: 560 },
      { x: 980, y: 560 },
      { x: 380, y: 560 },
      { x: 900, y: 560 },
      { x: 240, y: 560 },
      { x: 1040, y: 560 },
      { x: 340, y: 560 },
      { x: 940, y: 560 },
    ],
    respawn: { x: WORLD.width / 2, y: 160 },
    colors: { sky: 0x22201f, solid: 0x4a4f57, solidEdge: 0xf1c40f, platform: 0xc0c6cc },
  },
};

// Le arene generate si ricreano dal seme; si tengono le ultime per non rigenerarle a ogni chiamata
const generated = new Map<string, StageSpec>();

// Un id sconosciuto (o mancante) diventa l'arena base; "casuale-<seme>" un'arena generata,
// "corsa-<seme>" un percorso della modalità Corsa
export function getStage(id: string | undefined): StageSpec {
  if (id && Object.hasOwn(STAGES, id)) return STAGES[id];
  if (!id) return STAGES[DEFAULT_STAGE_ID];
  const seed = seedFromStageId(id);
  const courseSeed = seedFromCourseId(id);
  if (seed === null && courseSeed === null) return STAGES[DEFAULT_STAGE_ID];
  let stage = generated.get(id);
  if (!stage) {
    if (generated.size > 50) generated.clear();
    stage = seed !== null ? generateStage(seed) : generateCourse(courseSeed!);
    generated.set(id, stage);
  }
  return stage;
}
