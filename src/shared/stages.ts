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
  y: number; // superficie (alle estremità, se è ad arco)
  width: number;
  arch?: number; // piattaforma ad arco (#244): pixel di cui sale la superficie al centro, come un ponte
  y2?: number; // piattaforma inclinata (#246): altezza dell'estremità destra (y è la sinistra), come una scala
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
  kind?: string; // solo per il disegno: "barca" (#264); altrimenti la piattaforma con le strisce gialle e nere
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
  flood?: HazardFlood; // acqua alta (#228): la superficie sale e scende a ciclo
  travel?: HazardTravel; // trappola che viaggia (#229): passa lungo un percorso, come il ciclista di Padova
}

// Trappola che viaggia (#229): a ogni giro, dopo la calma, c'è l'avviso (il campanello) e poi il passaggio
// lungo path. Fa male solo mentre passa, e lancia nella direzione in cui viaggia. x e y della trappola sono
// ignorati: la posizione la dà il percorso. Dipende solo dal tempo dell'arena, come le altre trappole.
export interface HazardTravel {
  path: { x: number; y: number }[]; // dove passa l'angolo in alto a sinistra del rettangolo, almeno 2 punti
  periodMs: number; // durata di un giro
  warnMs: number; // avviso prima che entri
  crossMs: number; // durata del passaggio da un capo all'altro del percorso
  alternate?: boolean; // un giro all'andata e il successivo al ritorno
  offsetMs?: number; // sfasamento del giro
}

// Acqua alta (#228): la superficie della trappola (y) sale fino a highY e poi torna giù, il fondo
// (y + height) resta fermo. Un giro è calma, avviso (la pioggia), salita, alta, discesa: tutto alla
// fine di periodMs. Dipende solo dal tempo dell'arena, come ascensori e trappole a ciclo.
export interface HazardFlood {
  highY: number; // superficie con l'acqua alta: più in alto di y, quindi un numero più piccolo
  periodMs: number; // durata di un giro completo
  warnMs: number; // avviso prima della salita: l'acqua è ancora bassa ma piove
  riseMs: number; // durata della salita
  holdMs: number; // quanto resta alta
  fallMs?: number; // durata della discesa (riseMs se manca)
  offsetMs?: number; // sfasamento del giro
  lowSafe?: boolean; // l'acqua bassa non fa male (#253): fa male solo mentre sale, resta alta e scende
}

// Musica della partita su un'arena (E12 passo 4): un preset per il sintetizzatore del client Godot (audio.gd).
// Senza, si sente la musica di sempre (132 bpm, La minore, Fa, Do, Sol, melodia a onda quadra).
export interface StageMusic {
  bpm: number; // battiti al minuto, tra AUDIO.musicBpmMin e AUDIO.musicBpmMax
  chords: string[]; // un accordo per battuta, per nome: "C", "F#", "Bb", con "m" se minore ("Am", "C#m")
  lead: StageMusicLead; // timbro della melodia
}

export type StageMusicLead = "square" | "triangle" | "sawtooth" | "sine";
export const STAGE_MUSIC_LEADS: StageMusicLead[] = ["square", "triangle", "sawtooth", "sine"];
export const CHORD_NAME = /^[A-G][#b]?m?$/;

// Uno strato disegnato di un'arena (E12 passo 3): un PNG in public/assets/stages/<id>/
export interface StageLayer {
  file: string; // nome del file nella cartella dell'arena, es. "sfondo-0.png"
  parallax: number; // da 0 (fermo con la telecamera, lontanissimo) a 1 (si muove con il palco)
}

// Lo sfondo illustrato di un'arena: senza, si disegna con i colori di colors
export interface StageArt {
  layers: StageLayer[]; // dal più lontano al più vicino, tutti dietro al palco; centrati sul centro dell'arena
  foreground?: StageLayer; // davanti ai lottatori: leggero e quasi tutto trasparente, per non coprire il gioco
  preview?: string; // immagine 16:9 dell'arena per la lobby
  scale?: number; // pixel di mondo per pixel dell'immagine (1 se manca)
  dir?: string; // cartella in public/assets/stages/ se diversa dall'id dell'arena (sfondi condivisi)
  // Materiali e decorazioni del palco (#237): solo grafica, la fisica non li vede
  skins?: Record<string, StageSkin>; // materiali per nome
  solidSkin?: string; // materiale di base dei blocchi pieni
  platformSkin?: string; // materiale di base delle piattaforme sottili
  pieces?: { solids?: (string | null)[]; platforms?: (string | null)[] }; // eccezioni per indice; null = tinta unita
  props?: StageProp[]; // decorazioni ferme: statue, archi, lampioni
  life?: StageLife; // sfondo vivo (#260): solo grafica, calcolata nel client dal tempo dell'arena
}

// Sfondo vivo (#260): elementi animati che non toccano il gioco. Le coordinate sono quelle del mondo come se
// l'elemento stesse su uno strato con quella parallasse (come gli strati di art.layers); si disegna tra gli strati
// giusti. Tutto si ricalcola nel client da stageMs e dalle posizioni dei lottatori: niente in rete.
export interface StageLife {
  birds?: { y: number; parallax: number; everyMs: number }; // stormi che attraversano il cielo all'altezza y
  pigeons?: { x: number; y: number }[]; // piccioni posati (sulle statue): scappano se un lottatore arriva vicino
  walkers?: { y: number; parallax: number; count: number; umbrellas?: boolean }; // passanti sulla linea y; ombrelli con la pioggia
  vehicles?: { y: number; parallax: number; everyMs: number; kind: "tram" | "bus" }; // un veicolo che passa ogni tanto
  // Giorno e notte: un giro in cycleMs dall'inizio della partita; startAt da 0 a 1 (0 mezzogiorno, 0,25 tramonto,
  // 0,5 mezzanotte, 0,75 alba). Di notte le stelle; i lampioni si accendono al tramonto e si spengono all'alba
  // Acqua intorno all'arena (#264): da y in giù, davanti a chi cade (splash). Con flood (indice di una trappola con
  // l'acqua alta) sale fino a highY insieme a lei
  outerWater?: { y: number; highY?: number; flood?: number };
  daycycle?: {
    cycleMs: number;
    startAt?: number;
    lamps?: { x: number; y: number; parallax: number }[];
    windows?: { x: number; y: number; width: number; height: number }[]; // finestre che si accendono di notte, una alla volta
    sky?: boolean; // cielo vivo (#267): gradiente, sole, luna, stelle e nuvole calcolati, dietro a uno strato del cielo trasparente
  };
}

// Materiale di un pezzo dell'arena (#237): un PNG ripetuto. Nei blocchi si ripete in orizzontale e in verticale,
// nelle piattaforme lungo la superficie (anche ad arco e inclinate), con lo spessore depth
export interface StageSkin {
  file: string;
  edge?: string; // striscia del bordo calpestabile, ripetuta sopra al pezzo: sempre chiara (style guide, sezione 7)
  depth?: number; // spessore delle piattaforme sottili, in pixel di mondo (12 se manca)
  rails?: StageRail[]; // ringhiere che seguono la superficie
}

// Ringhiera (#237): un PNG ripetuto lungo la superficie di una piattaforma, alto height pixel di mondo
export interface StageRail {
  file: string;
  height: number;
  offsetY?: number; // pixel più in basso (+) o più in alto (−) rispetto alla superficie
  front?: boolean; // davanti ai lottatori (altrimenti dietro)
  opacity?: number; // da 0 a 1 (1 se manca): quella davanti si tiene trasparente per non coprire chi ci passa
}

// Decorazione ferma (#237): un PNG con i piedi (il centro del lato basso) in x, y
export interface StageProp {
  file: string;
  x: number;
  y: number;
  scale?: number; // pixel di mondo per pixel dell'immagine (art.scale se manca)
  flip?: boolean; // specchiata in orizzontale
  front?: boolean; // davanti ai lottatori (altrimenti dietro, subito dopo il palco)
  opacity?: number;
}

// Tutti i file che lo sfondo e il palco di un'arena nominano (export e test li cercano in public/assets/stages/<dir>/)
export function stageArtFiles(art: StageArt): string[] {
  const files = [...art.layers, ...(art.foreground ? [art.foreground] : [])].map((l) => l.file);
  if (art.preview) files.push(art.preview);
  for (const skin of Object.values(art.skins ?? {})) {
    files.push(skin.file);
    if (skin.edge) files.push(skin.edge);
    for (const r of skin.rails ?? []) files.push(r.file);
  }
  for (const p of art.props ?? []) files.push(p.file);
  return [...new Set(files)];
}

// Zoom della telecamera per un'arena (#240): un'arena più larga dello schermo si allontana di più
// per mostrarsi intera quando i lottatori si sparpagliano. Lo zoom più lontano resta comunque quello
// che riempie le zone di espulsione, se è più vicino di minZoom.
export interface StageCamera {
  minZoom?: number; // più piccolo = più lontano (CAMERA.minZoom se manca)
  maxZoom?: number; // quanto si avvicina quando i lottatori sono vicini (CAMERA.maxZoom se manca)
}

// Getto d'acqua (#253): una colonna larga width che dalla base (y) sale per height pixel. A ogni giro, dopo
// la calma, ci sono le bolle (warnMs) e poi il getto (activeMs): chi è nella colonna viene spinto in alto a
// speed pixel/s, senza danno. Dipende solo dal tempo dell'arena, come le trappole.
export interface Jet {
  x: number; // bordo sinistro
  y: number; // base della colonna
  width: number;
  height: number; // quanto sale la colonna d'acqua
  speed: number; // pixel/s verso l'alto dati a chi ci sta dentro
  periodMs: number;
  warnMs: number; // bolle prima del getto
  activeMs: number; // durata del getto
  offsetMs?: number;
}

// Zona dove gli oggetti cadono più spesso (#253): una striscia di superficie con un peso. Senza zone, gli oggetti
// cadono a caso sui pezzi larghi almeno 80 px; con le zone, si sceglie a caso tra i pezzi (peso 1) e le zone (il loro peso).
export interface ItemSpot {
  x: number;
  y: number; // superficie su cui cade
  width: number;
  weight: number;
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
  width?: number; // larghezza del mondo se più larga dello schermo (#240): nelle arene la telecamera inquadra tutti, nella Corsa segue
  camera?: StageCamera; // zoom della telecamera per quest'arena (#240): senza, valgono CAMERA.minZoom e maxZoom
  // Solo per i percorsi della modalità Corsa (#57)
  checkpoints?: { x: number; y: number }[]; // dove si ricompare dopo una caduta (y = superficie)
  goal?: Rect; // chi lo tocca vince
  // Elementi dinamici (#14 passo 4)
  movers?: MovingPlatform[];
  hazards?: Hazard[];
  jets?: Jet[]; // getti d'acqua a tempo che spingono in alto (#253)
  itemSpots?: ItemSpot[]; // zone dove gli oggetti cadono più spesso (#253)
  music?: StageMusic; // musica della partita (E12 passo 4)
  art?: StageArt; // sfondo a strati (E12 passo 3)
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
    // Un concerto di notte: cielo e città, tralicci con i fari, il pubblico sotto al palco
    art: {
      layers: [
        { file: "sfondo-0.png", parallax: 0.15 },
        { file: "sfondo-1.png", parallax: 0.45 },
        { file: "sfondo-2.png", parallax: 0.75 },
      ],
      preview: "anteprima.png",
    },
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

    // Più lenta e morbida, da isola. TODO community: un pezzo del canale da rifare?
    music: { bpm: 108, chords: ["C", "Am", "F", "G"], lead: "triangle" },
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

    // Veloce e metallica, da capannone
    music: { bpm: 152, chords: ["Em", "C", "D", "Bm"], lead: "sawtooth" },
  },

  // Palestra del tutorial (E15): un palco con due bordi a cui aggrapparsi e una piattaforma bassa per i salti.
  // TODO community: la palestra di qualcuno del canale?
  palestra: {
    id: "palestra",
    name: "La Palestra",
    solids: [{ x: 290, y: 560, width: 700, height: 80 }],
    platforms: [{ x: 540, width: 200, y: 420 }],
    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },
    spawns: [0.3, 0.7, 0.45, 0.55, 0.2, 0.8, 0.37, 0.63].map((f) => ({ x: 290 + 700 * f, y: 560 })),
    respawn: { x: WORLD.width / 2, y: 160 },
    colors: { sky: 0x2a2433, solid: 0x6b4f3a, solidEdge: 0xd9a066, platform: 0xb8a58c },
  },

  // Padova, Prato della Valle (#230, idea di Riccardo): piazza, ponte ad arco e piazza sopra il canale, con le statue
  // del Prato che reggono le lastre. Il canale sale con la pioggia, il getto della fontana spinge in alto, e un signore
  // arrabbiato in bici attraversa tutto gridando. Larga 1,5 schermi: la telecamera si allontana fino a 0,6.
  padova: {
    id: "padova",
    name: "Padova",
    width: 1920,
    camera: { minZoom: 0.6 },
    solids: [
      // Le piazze sono rive di pietra che scendono fino al canale esterno (#264): l'arena non è sospesa nel vuoto
      { x: 100, y: 520, width: 620, height: 480 }, // piazza sinistra
      { x: 1200, y: 520, width: 620, height: 480 }, // piazza destra
      { x: 720, y: 690, width: 480, height: 310 }, // fondo del canale
    ],
    platforms: [
      // Il ponte va per primo: camminando dalla piazza si resta sul ponte, tenendo giù si scende sulla scala (#246)
      { x: 720, y: 520, width: 480, arch: 25 },
      { x: 742, y: 518, width: 180, y2: 690 }, // scala sinistra, giù fino al fondo del canale
      { x: 998, y: 690, width: 180, y2: 518 }, // scala destra
      { x: 600, y: 410, width: 180 }, // lastre rette dalle statue, larghe per starci in due: ai capi del ponte...
      { x: 1140, y: 410, width: 180 },
      { x: 470, y: 330, width: 140 }, // ...più in alto...
      { x: 1310, y: 330, width: 140 },
      { x: 220, y: 380, width: 180 }, // ...e sulle piazze
      { x: 1520, y: 380, width: 180 },
      // I balconi del palazzo signorile dietro il ponte (idea di Riccardo): la casa è sfondo, i balconi si calpestano
      { x: 800, y: 300, width: 320 }, // il balcone largo del piano nobile, sopra il ponte
      { x: 900, y: 180, width: 120 }, // il balconcino dell'ultimo piano: la cima dell'arena
    ],
    hazards: [
      // Il canale: l'acqua bassa non fa male; con la pioggia sale, copre le scale e fa male finché non riscende
      { kind: "acqua", x: 720, y: 660, width: 480, height: 30, damage: 6, knockback: 550, knockbackGrowth: 3, angleDeg: 85,
        flood: { highY: 550, periodMs: 40000, warnMs: 4000, riseMs: 3000, holdMs: 6000, fallMs: 3000, lowSafe: true } },
      // Il ciclista arrabbiato (#229): entra da fuori, passa sulle piazze e sul ponte, ed esce. Sotto il ponte si è al riparo
      // TODO community: il grido "CANCAROOOO!" da registrare (chi lo fa?)
      { kind: "ciclista", x: 0, y: 0, width: 80, height: 95, damage: 10, knockback: 600, knockbackGrowth: 5, angleDeg: 35,
        travel: { path: [{ x: -160, y: 425 }, { x: 680, y: 425 }, { x: 920, y: 400 }, { x: 1160, y: 425 }, { x: 2080, y: 425 }],
          periodMs: 20000, warnMs: 1000, crossMs: 2800, alternate: true, offsetMs: 7000 } },
    ],
    // Le barche del canale esterno (#264): arrivano quando l'acqua è bassa e si fermano accanto alle rive, così chi
    // è caduto ci può atterrare e risalire con il doppio salto; quando piove aspettano fuori scena
    movers: [
      { kind: "barca", width: 160, path: [{ x: -560, y: 780 }, { x: -150, y: 780 }], periodMs: 40000, pauseMs: 14000, offsetMs: 16000 },
      { kind: "barca", width: 160, path: [{ x: 2380, y: 780 }, { x: 1910, y: 780 }], periodMs: 40000, pauseMs: 14000, offsetMs: 16000 },
    ],
    // Il getto della fontana in fondo al canale (#253): una scorciatoia verso le lastre alte
    jets: [{ x: 930, y: 690, width: 60, height: 300, speed: 1300, periodMs: 9000, warnMs: 1200, activeMs: 1500, offsetMs: 3000 }],
    // Gli oggetti cadono spesso nel canale e sulle lastre delle statue: rischio e premio, e un motivo per salire
    itemSpots: [
      { x: 740, y: 690, width: 440, weight: 3 },
      { x: 600, y: 410, width: 180, weight: 2 },
      { x: 1140, y: 410, width: 180, weight: 2 },
      { x: 470, y: 330, width: 140, weight: 2 },
      { x: 1310, y: 330, width: 140, weight: 2 },
      { x: 220, y: 380, width: 180, weight: 2 },
      { x: 1520, y: 380, width: 180, weight: 2 },
      { x: 800, y: 300, width: 320, weight: 3 }, // il balcone del palazzo
    ],
    blastZone: { left: -300, right: 2220, top: -420, bottom: 1000 },
    spawns: [300, 450, 200, 600, 380, 520, 250, 660].flatMap((x) => [{ x, y: 520 }, { x: 1920 - x, y: 520 }]).slice(0, 8),
    respawn: { x: 960, y: 100 },
    colors: { sky: 0x7aa0c4, solid: 0x6f6a60, solidEdge: 0xe8e2d2, platform: 0xd9d4c7 },
    // Rilassata, da pomeriggio in piazza. TODO community: un pezzo del canale da rifare per Padova?
    music: { bpm: 116, chords: ["F", "Am", "Bb", "C"], lead: "triangle" },
    // Segnaposto disegnati col codice da tools/arene/padova.py: si sostituiscono con i disegni veri, stessi nomi
    art: {
      layers: [
        { file: "sfondo-0.png", parallax: 0.15 }, // cielo e Santa Giustina
        { file: "sfondo-1.png", parallax: 0.45 }, // portici, Loggia Amulea, mercato
        { file: "sfondo-2.png", parallax: 0.75 }, // il prato dell'Isola Memmia, alberi e la seconda fila di statue
      ],
      preview: "anteprima.png",
      skins: {
        pietra: { file: "pietra.png", edge: "bordo.png" },
        riva: { file: "riva.png", edge: "bordo.png" }, // il muro della riva, a grandi blocchi
        fondo: { file: "scala.png" },
        ponte: {
          file: "ponte.png",
          depth: 20,
          rails: [
            { file: "balaustra.png", height: 36, offsetY: 2 }, // la ringhiera traforata del Prato, dietro
            { file: "balaustra.png", height: 28, offsetY: 12, front: true, opacity: 0.45 }, // e quella davanti, trasparente
          ],
        },
        scala: { file: "scala.png", edge: "scala-bordo.png" },
        lastra: { file: "lastra.png", depth: 12 },
        balcone: { file: "balcone.png", depth: 14, rails: [{ file: "balaustra-balcone.png", height: 30, offsetY: 2 }] },
      },
      solidSkin: "pietra",
      platformSkin: "lastra",
      pieces: {
        solids: ["riva", "riva", "fondo"],
        platforms: ["ponte", "scala", "scala", "lastra", "lastra", "lastra", "lastra", "lastra", "lastra", "balcone", "balcone"],
      },
      props: [
        { file: "palazzo.png", x: 960, y: 480, scale: 0.5 }, // il palazzo signorile: la facciata, dietro a tutto il palco
        { file: "arco-ponte.png", x: 960, y: 692 },
        // Le statue che reggono le lastre: il giovane con l'alloro, il filosofo con la barba, la dama col velo
        { file: "statua-ponte.png", x: 690, y: 522, scale: 0.5 },
        { file: "statua-ponte.png", x: 1230, y: 522, scale: 0.5, flip: true },
        { file: "statua-alta.png", x: 540, y: 522, scale: 0.5 },
        { file: "statua-alta.png", x: 1380, y: 522, scale: 0.5, flip: true },
        { file: "statua-piazza.png", x: 310, y: 522, scale: 0.5 },
        { file: "statua-piazza.png", x: 1610, y: 522, scale: 0.5, flip: true },
      ],
      // Sfondo vivo (#260): stormi, piccioni sulle teste delle statue, passanti sul vialetto del prato con l'ombrello
      // quando piove, il tram davanti ai portici e il giorno che passa: tramonto, notte con le stelle e i lampioni, alba
      life: {
        outerWater: { y: 800, highY: 760, flood: 0 }, // il canale esterno, che sale con la pioggia come quello interno
        birds: { y: 40, parallax: 0.2, everyMs: 14000 },
        // Sulle punte delle lastre delle statue e sul cornicione del palazzo
        pigeons: [{ x: 485, y: 330 }, { x: 1435, y: 330 }, { x: 235, y: 380 }, { x: 1685, y: 380 }, { x: 790, y: 100 }, { x: 1130, y: 100 }],
        walkers: { y: 510, parallax: 0.75, count: 9, umbrellas: true },
        vehicles: { y: 540, parallax: 0.45, everyMs: 23000, kind: "tram" },
        daycycle: {
          cycleMs: 240000, // un giorno intero in 4 minuti: alba, giorno, tramonto e notte
          startAt: 0.8, // si parte poco dopo l'alba
          sky: true, // il cielo vivo dietro alle sagome di Santa Giustina e del Santo (#267)
          lamps: [90, 390, 690, 990, 1290, 1590, 1890, 2190].map((x) => ({ x: x - 260, y: 409, parallax: 0.75 })), // i lampioni del prato
          // Le finestre del palazzo che si accendono la sera: la trifora, le bifore, l'ultimo piano, il mezzanino
          windows: [
            { x: 909, y: 220, width: 102, height: 72 },
            { x: 803, y: 230, width: 54, height: 62 },
            { x: 1063, y: 230, width: 54, height: 62 },
            { x: 790, y: 130, width: 16, height: 38 },
            { x: 990, y: 130, width: 16, height: 38 },
            { x: 1120, y: 130, width: 16, height: 38 },
            { x: 852, y: 342, width: 24, height: 20 },
            { x: 1044, y: 342, width: 24, height: 20 },
          ],
        },
      },
    },
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
