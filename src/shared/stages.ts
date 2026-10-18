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
  previewFull?: boolean; // l'anteprima mostra già il palco (#284): la lobby non ci disegna sopra i pezzi
  scale?: number; // pixel di mondo per pixel dell'immagine (1 se manca)
  dir?: string; // cartella in public/assets/stages/ se diversa dall'id dell'arena (sfondi condivisi)
  // Materiali e decorazioni del palco (#237): solo grafica, la fisica non li vede
  skins?: Record<string, StageSkin>; // materiali per nome
  solidSkin?: string; // materiale di base dei blocchi pieni
  platformSkin?: string; // materiale di base delle piattaforme sottili
  pieces?: { solids?: (string | null)[]; platforms?: (string | null)[] }; // eccezioni per indice; null = tinta unita
  props?: StageProp[]; // decorazioni ferme: statue, archi, lampioni
  hazardSprites?: HazardSprite[]; // animazioni disegnate delle trappole (#270), al posto del disegno fatto col codice
  moverSprites?: MoverSprite[]; // animazioni disegnate delle piattaforme mobili (#273)
  life?: StageLife; // sfondo vivo (#260): solo grafica, calcolata nel client dal tempo dell'arena
}

// Sfondo vivo (#260): elementi animati che non toccano il gioco. Le coordinate sono quelle del mondo come se
// l'elemento stesse su uno strato con quella parallasse (come gli strati di art.layers); si disegna tra gli strati
// giusti. Tutto si ricalcola nel client da stageMs e dalle posizioni dei lottatori: niente in rete.
export type TrafficKind = "auto" | "vespa" | "furgone" | "bici" | "bus";

export interface StageLife {
  birds?: { y: number; parallax: number; everyMs: number }; // stormi che attraversano il cielo all'altezza y
  pigeons?: { x: number; y: number }[]; // piccioni posati (sulle statue): scappano se un lottatore arriva vicino
  walkers?: { y: number; parallax: number; count: number; umbrellas?: boolean }; // passanti sulla linea y; ombrelli con la pioggia
  vehicles?: { y: number; parallax: number; everyMs: number; kind: "tram" | "bus" }; // un veicolo che passa ogni tanto
  // Traffico (#278): ogni everyMs parte un veicolo di uno dei tipi, nei due versi su due corsie, ognuno alla sua velocità
  traffic?: { y: number; parallax: number; everyMs: number; kinds: TrafficKind[] };
  flyers?: { y: number; parallax: number; count: number }; // uccelli vicini da y in giù: rondini di giorno, pipistrelli di notte
  planes?: { y: number; everyMs: number }; // un aereo lontanissimo ogni tanto, con la scia di giorno e le luci di notte
  // Tavolini di un bar (#278): da x verso destra ogni spacing pixel, gente seduta che beve e brinda, il cameriere, le lucine la sera
  bar?: { x: number; y: number; parallax: number; tables: number; spacing: number };
  // Giorno e notte: un giro in cycleMs dall'inizio della partita; startAt da 0 a 1 (0 mezzogiorno, 0,25 tramonto,
  // 0,5 mezzanotte, 0,75 alba). Di notte le stelle; i lampioni si accendono al tramonto e si spengono all'alba
  // Acqua intorno all'arena (#264): da y in giù, davanti a chi cade (splash). Con flood (indice di una trappola con
  // l'acqua alta) sale fino a highY insieme a lei
  outerWater?: { y: number; highY?: number; flood?: number };
  // Fogli di fotogrammi dipinti (#288) per lo sfondo vivo, per nome: nuvole, gabbiano, rondine, pipistrello, piccione.
  // Fotogrammi in fila da sinistra, a 2x (scale 0.5 se manca). Senza, si disegnano le forme semplici di prima
  sheets?: Record<string, { file: string; frames: number; rows?: number; scale?: number }>;
  // Pioggia solo grafica (#288): ogni periodMs piove per rainMs, senza trappole. I passanti aprono l'ombrello
  rain?: { periodMs: number; rainMs: number; offsetMs?: number };
  daycycle?: {
    cycleMs: number;
    startAt?: number;
    lamps?: { x: number; y: number; parallax: number }[];
    windows?: { x: number; y: number; width: number; height: number }[]; // finestre che si accendono di notte, una alla volta
    // Luci della notte precise (#288): immagini con solo i vetri accesi, sopra uno strato (stessa parallasse e misura)
    // o sopra una decorazione (come i props). Si accendono al tramonto e si spengono all'alba
    lightLayers?: { file: string; parallax: number }[];
    lightProps?: { file: string; x: number; y: number; scale?: number }[];
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

// Animazione di una trappola (#270): un foglio di fotogrammi uno accanto all'altro, rivolti a destra (il gioco li
// specchia quando la trappola va a sinistra). Il punto footX, footY dell'immagine (in pixel del fotogramma) va sul
// centro del lato basso del rettangolo che fa male. Solo grafica: la fisica usa sempre il rettangolo.
export interface SpriteStrip {
  file: string;
  frames: number;
  fps: number; // fotogrammi al secondo, sul tempo dell'arena
  scale?: number; // pixel di mondo per pixel dell'immagine (1 se manca)
  footX?: number; // pixel dal bordo sinistro del fotogramma (metà fotogramma se manca)
  footY?: number; // pixel dal bordo alto (il fondo del fotogramma se manca)
}

export interface HazardSprite extends SpriteStrip {
  hazard: number; // indice della trappola in hazards
  shout?: { text: string; x: number; y: number }; // un fumetto che esce da qui (pixel del fotogramma) mentre passa
}

// Animazione di una piattaforma mobile (#273), come quella delle trappole: footX, footY va sul centro della
// superficie. Rivolta a destra; si gira nel verso in cui va, e da ferma verso il centro dell'arena
export interface MoverSprite extends SpriteStrip {
  mover: number; // indice della piattaforma in movers
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
  for (const h of art.hazardSprites ?? []) files.push(h.file);
  for (const m of art.moverSprites ?? []) files.push(m.file);
  for (const l of [...(art.life?.daycycle?.lightLayers ?? []), ...(art.life?.daycycle?.lightProps ?? [])]) files.push(l.file);
  for (const sh of Object.values(art.life?.sheets ?? {})) files.push(sh.file);
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
  idle?: number; // solo grafica (#288): pixel dello zampillo a riposo, come una fontana che non si spegne mai
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

  // Padova, Prato della Valle (#230, idea di Riccardo): un'isola sospesa sopra il Prato (#288), una piazza continua
  // con al centro la fontana dell'Isola Memmia, il cui zampillo ogni tanto lancia in alto chi ci sta sopra. Le statue
  // del Prato reggono le lastre, il palazzo ha i balconi calpestabili, e un signore arrabbiato in bici attraversa
  // tutto gridando. Larga 1,5 schermi: la telecamera si allontana fino a 0,6.
  padova: {
    id: "padova",
    name: "Padova",
    width: 1920,
    camera: { minZoom: 0.6 },
    solids: [
      { x: 100, y: 520, width: 1720, height: 70 }, // la piazza: sotto pendono le fondamenta disegnate, poi il vuoto
    ],
    platforms: [
      { x: 600, y: 410, width: 180 }, // lastre rette dalle statue, larghe per starci in due: ai lati della fontana...
      { x: 1140, y: 410, width: 180 },
      { x: 470, y: 330, width: 140 }, // ...più in alto...
      { x: 1310, y: 330, width: 140 },
      { x: 220, y: 380, width: 180 }, // ...e verso i bordi
      { x: 1520, y: 380, width: 180 },
      // I balconi del palazzo signorile dietro la fontana (idea di Riccardo): la casa è sfondo, i balconi si calpestano
      { x: 800, y: 300, width: 320 }, // il balcone largo del piano nobile
      { x: 900, y: 180, width: 120 }, // il balconcino dell'ultimo piano: la cima dell'arena
    ],
    hazards: [
      // Il ciclista arrabbiato (#229): entra da fuori, attraversa la piazza ed esce. Più lento e più cattivo dal #288
      // TODO community: il grido "CANCAROOOO!" da registrare (chi lo fa?)
      { kind: "ciclista", x: 0, y: 0, width: 80, height: 95, damage: 13, knockback: 620, knockbackGrowth: 5, angleDeg: 35,
        travel: { path: [{ x: -160, y: 425 }, { x: 2080, y: 425 }], periodMs: 20000, warnMs: 1200, crossMs: 4200, alternate: true, offsetMs: 7000 } },
    ],
    // Lo zampillo della fontana (#288): ogni 7 s gorgoglia e poi lancia in alto chi sta sulla vasca, verso lastre e balcone
    jets: [{ x: 915, y: 520, width: 90, height: 320, speed: 1350, periodMs: 7000, warnMs: 1200, activeMs: 1600, offsetMs: 3000, idle: 70 }],
    // Gli oggetti cadono spesso sulla fontana e sulle lastre delle statue: rischio e premio, e un motivo per salire
    itemSpots: [
      { x: 840, y: 520, width: 240, weight: 3 },
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
    // Disegnati col codice da tools/arene/padova.py (#280), a 2x: chi disegna in Krita può sostituirli, stessi nomi e misure
    art: {
      scale: 0.5, // strati, materiali e decorazioni senza scala propria sono a 2x (stile grafico, sezione 5)
      layers: [
        { file: "sfondo-0.png", parallax: 0.15 }, // cielo e Santa Giustina
        { file: "sfondo-1.png", parallax: 0.45 }, // portici, Loggia Amulea, mercato
        { file: "sfondo-2.png", parallax: 0.75 }, // il prato dell'Isola Memmia, alberi e la seconda fila di statue
      ],
      preview: "anteprima.png",
      previewFull: true, // fotografata dal gioco, con il palco e lo sfondo
      skins: {
        pietra: { file: "pietra.png", edge: "bordo.png" },
        riva: { file: "riva.png", edge: "bordo.png" }, // il fianco della piazza, a grandi blocchi
        lastra: { file: "lastra.png", depth: 12 },
        balcone: { file: "balcone.png", depth: 14, rails: [{ file: "balaustra-balcone.png", height: 30, offsetY: 2 }] },
      },
      solidSkin: "pietra",
      platformSkin: "lastra",
      pieces: {
        solids: ["riva"],
        platforms: ["lastra", "lastra", "lastra", "lastra", "lastra", "lastra", "balcone", "balcone"],
      },
      // Cancaro Man (#270, dal disegno di Riccardo): la pedalata in 8 fotogrammi da tools/arene/ciclista.py
      // TODO community: la voce del "CANCAROOOO!" da registrare; intanto c'è il fumetto
      hazardSprites: [
        { hazard: 0, file: "ciclista.png", frames: 8, fps: 16, scale: 0.58, footX: 150, footY: 312, shout: { text: "CANCAROOOO!", x: 200, y: 110 } },
      ],
      props: [
        { file: "palazzo.png", x: 960, y: 522, scale: 0.5 }, // il palazzo signorile: la facciata, dietro a tutto il palco
        // Il piano dell'isola in profondità (#300): il lastricato dietro il bordo, su cui poggiano palazzo, statue e platani
        { file: "piano.png", x: 960, y: 524, scale: 0.5 },
        // Due platani sulla piazza (#288), dietro alle statue: la chioma sta sopra le teste e lascia vedere il palco
        { file: "platano.png", x: 410, y: 522, scale: 0.5 },
        { file: "platano.png", x: 1510, y: 522, scale: 0.5, flip: true },
        { file: "fondamenta.png", x: 960, y: 760 }, // sotto la piazza: le fondamenta di mattoni e pietra, con l'edera
        { file: "fontana.png", x: 960, y: 524 }, // la fontana dell'Isola Memmia: la vasca, i paracarri e la ringhiera
        { file: "fontana-davanti.png", x: 960, y: 530, front: true, opacity: 0.7 }, // il bordo della vasca davanti ai piedi
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
        rain: { periodMs: 40000, rainMs: 12000, offsetMs: 26000 }, // ogni tanto piove: i passanti aprono l'ombrello
        // Nuvole e uccelli dipinti (#288), da tools/arene/vita.py
        sheets: {
          nuvole: { file: "nuvole.png", frames: 8 },
          gabbiano: { file: "gabbiano.png", frames: 8 },
          rondine: { file: "rondine.png", frames: 4 },
          pipistrello: { file: "pipistrello.png", frames: 4 },
          piccione: { file: "piccione.png", frames: 6 },
          passanti: { file: "passanti.png", frames: 8, rows: 9 }, // signore, signora, cane, corsa, passeggino, bastone, laurea, borsa, giornale
          ombrelli: { file: "ombrelli.png", frames: 4 },
          "bar-tavolo": { file: "bar-tavolo.png", frames: 1 },
          "bar-seduti": { file: "bar-seduti.png", frames: 4, rows: 3 }, // sul tavolo, a metà, alla bocca, brindisi
          cameriere: { file: "cameriere.png", frames: 8 },
          // Il traffico e il tram (#288 passo 3c): le macchine sono una per fotogramma, gli altri si animano
          auto: { file: "auto.png", frames: 6 },
          furgone: { file: "furgone.png", frames: 2 },
          vespa: { file: "vespa.png", frames: 2 },
          bici: { file: "bici.png", frames: 4 },
          bus: { file: "bus.png", frames: 1 },
          tram: { file: "tram.png", frames: 1 },
          // L'acqua della fontana (#288 passo 3d): lo zampillo a riposo e il getto acceso
          zampillo: { file: "zampillo.png", frames: 6 },
          getto: { file: "getto.png", frames: 4 },
        },
        birds: { y: 40, parallax: 0.2, everyMs: 14000 },
        // Sulle punte delle lastre delle statue e sul cornicione del palazzo
        pigeons: [{ x: 485, y: 330 }, { x: 1435, y: 330 }, { x: 235, y: 380 }, { x: 1685, y: 380 }, { x: 790, y: 100 }, { x: 1130, y: 100 }],
        // Lo sfondo è salito per stare dietro il piano dell'isola (#300, LIFT in padova.py): prato e bar 30 px, strada 24
        walkers: { y: 480, parallax: 0.75, count: 14, umbrellas: true },
        // Il tram e il traffico passano sulla strada davanti ai portici (#278): più giù le piazze li coprirebbero
        vehicles: { y: 464, parallax: 0.5, everyMs: 23000, kind: "tram" },
        traffic: { y: 464, parallax: 0.5, everyMs: 2600, kinds: ["auto", "auto", "auto", "vespa", "vespa", "furgone", "bici", "bus"] },
        flyers: { y: 90, parallax: 0.6, count: 7 }, // rondini sul Prato, di notte i pipistrelli
        planes: { y: -60, everyMs: 75000 },
        bar: { x: 120, y: 474, parallax: 0.8, tables: 3, spacing: 72 }, // il chiosco dello spritz sul prato
        daycycle: {
          cycleMs: 240000, // un giorno intero in 4 minuti: alba, giorno, tramonto e notte
          startAt: 0.8, // si parte poco dopo l'alba
          sky: true, // il cielo vivo dietro alle sagome di Santa Giustina e del Santo (#267)
          lamps: [90, 390, 690, 990, 1290, 1590, 1890, 2190].map((x) => ({ x: x - 260, y: 379, parallax: 0.75 })), // i lampioni del prato
          // Di notte i vetri accesi del palazzo, delle case e della città lontana, e le lanterne dei lampioni (#288)
          lightLayers: [0, 1, 2].map((i) => ({ file: `sfondo-${i}-luci.png`, parallax: [0.15, 0.45, 0.75][i] })),
          lightProps: [{ file: "palazzo-luci.png", x: 960, y: 522, scale: 0.5 }],
        },
      },
    },
  },

  // Padova · il palazzo (#378): la Padova di prima dell'idea di Nicola, conservata com'era il 18 ottobre 2026, con il
  // palazzo signorile e i suoi balconi al centro e lo zampillo che lancia in alto. I disegni sono una copia ferma.
  "padova-palazzo": {
    id: "padova-palazzo",
    name: "Padova · il palazzo",
    width: 1920,
    camera: { minZoom: 0.6 },
    solids: [
      { x: 100, y: 520, width: 1720, height: 70 }, // la piazza: sotto pendono le fondamenta disegnate, poi il vuoto
    ],
    platforms: [
      { x: 600, y: 410, width: 180 }, // lastre rette dalle statue, larghe per starci in due: ai lati della fontana...
      { x: 1140, y: 410, width: 180 },
      { x: 470, y: 330, width: 140 }, // ...più in alto...
      { x: 1310, y: 330, width: 140 },
      { x: 220, y: 380, width: 180 }, // ...e verso i bordi
      { x: 1520, y: 380, width: 180 },
      // I balconi del palazzo signorile dietro la fontana (idea di Riccardo): la casa è sfondo, i balconi si calpestano
      { x: 800, y: 300, width: 320 }, // il balcone largo del piano nobile
      { x: 900, y: 180, width: 120 }, // il balconcino dell'ultimo piano: la cima dell'arena
    ],
    hazards: [
      // Il ciclista arrabbiato (#229): entra da fuori, attraversa la piazza ed esce. Più lento e più cattivo dal #288
      // TODO community: il grido "CANCAROOOO!" da registrare (chi lo fa?)
      { kind: "ciclista", x: 0, y: 0, width: 80, height: 95, damage: 13, knockback: 620, knockbackGrowth: 5, angleDeg: 35,
        travel: { path: [{ x: -160, y: 425 }, { x: 2080, y: 425 }], periodMs: 20000, warnMs: 1200, crossMs: 4200, alternate: true, offsetMs: 7000 } },
    ],
    // Lo zampillo della fontana (#288): ogni 7 s gorgoglia e poi lancia in alto chi sta sulla vasca, verso lastre e balcone
    jets: [{ x: 915, y: 520, width: 90, height: 320, speed: 1350, periodMs: 7000, warnMs: 1200, activeMs: 1600, offsetMs: 3000, idle: 70 }],
    // Gli oggetti cadono spesso sulla fontana e sulle lastre delle statue: rischio e premio, e un motivo per salire
    itemSpots: [
      { x: 840, y: 520, width: 240, weight: 3 },
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
    // Disegnati col codice da tools/arene/padova.py (#280), a 2x: chi disegna in Krita può sostituirli, stessi nomi e misure
    art: {
      dir: "padova-palazzo", // i disegni di questa versione, fermi: tools/arene/padova.py ora disegna la nuova
      scale: 0.5, // strati, materiali e decorazioni senza scala propria sono a 2x (stile grafico, sezione 5)
      layers: [
        { file: "sfondo-0.png", parallax: 0.15 }, // cielo e Santa Giustina
        { file: "sfondo-1.png", parallax: 0.45 }, // portici, Loggia Amulea, mercato
        { file: "sfondo-2.png", parallax: 0.75 }, // il prato dell'Isola Memmia, alberi e la seconda fila di statue
      ],
      preview: "anteprima.png",
      previewFull: true, // fotografata dal gioco, con il palco e lo sfondo
      skins: {
        pietra: { file: "pietra.png", edge: "bordo.png" },
        riva: { file: "riva.png", edge: "bordo.png" }, // il fianco della piazza, a grandi blocchi
        lastra: { file: "lastra.png", depth: 12 },
        balcone: { file: "balcone.png", depth: 14, rails: [{ file: "balaustra-balcone.png", height: 30, offsetY: 2 }] },
      },
      solidSkin: "pietra",
      platformSkin: "lastra",
      pieces: {
        solids: ["riva"],
        platforms: ["lastra", "lastra", "lastra", "lastra", "lastra", "lastra", "balcone", "balcone"],
      },
      // Cancaro Man (#270, dal disegno di Riccardo): la pedalata in 8 fotogrammi da tools/arene/ciclista.py
      // TODO community: la voce del "CANCAROOOO!" da registrare; intanto c'è il fumetto
      hazardSprites: [
        { hazard: 0, file: "ciclista.png", frames: 8, fps: 16, scale: 0.58, footX: 150, footY: 312, shout: { text: "CANCAROOOO!", x: 200, y: 110 } },
      ],
      props: [
        { file: "palazzo.png", x: 960, y: 522, scale: 0.5 }, // il palazzo signorile: la facciata, dietro a tutto il palco
        // Il piano dell'isola in profondità (#300): il lastricato dietro il bordo, su cui poggiano palazzo, statue e platani
        { file: "piano.png", x: 960, y: 524, scale: 0.5 },
        // Due platani sulla piazza (#288), dietro alle statue: la chioma sta sopra le teste e lascia vedere il palco
        { file: "platano.png", x: 410, y: 522, scale: 0.5 },
        { file: "platano.png", x: 1510, y: 522, scale: 0.5, flip: true },
        { file: "fondamenta.png", x: 960, y: 760 }, // sotto la piazza: le fondamenta di mattoni e pietra, con l'edera
        { file: "fontana.png", x: 960, y: 524 }, // la fontana dell'Isola Memmia: la vasca, i paracarri e la ringhiera
        { file: "fontana-davanti.png", x: 960, y: 530, front: true, opacity: 0.7 }, // il bordo della vasca davanti ai piedi
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
        rain: { periodMs: 40000, rainMs: 12000, offsetMs: 26000 }, // ogni tanto piove: i passanti aprono l'ombrello
        // Nuvole e uccelli dipinti (#288), da tools/arene/vita.py
        sheets: {
          nuvole: { file: "nuvole.png", frames: 8 },
          gabbiano: { file: "gabbiano.png", frames: 8 },
          rondine: { file: "rondine.png", frames: 4 },
          pipistrello: { file: "pipistrello.png", frames: 4 },
          piccione: { file: "piccione.png", frames: 6 },
          passanti: { file: "passanti.png", frames: 8, rows: 9 }, // signore, signora, cane, corsa, passeggino, bastone, laurea, borsa, giornale
          ombrelli: { file: "ombrelli.png", frames: 4 },
          "bar-tavolo": { file: "bar-tavolo.png", frames: 1 },
          "bar-seduti": { file: "bar-seduti.png", frames: 4, rows: 3 }, // sul tavolo, a metà, alla bocca, brindisi
          cameriere: { file: "cameriere.png", frames: 8 },
          // Il traffico e il tram (#288 passo 3c): le macchine sono una per fotogramma, gli altri si animano
          auto: { file: "auto.png", frames: 6 },
          furgone: { file: "furgone.png", frames: 2 },
          vespa: { file: "vespa.png", frames: 2 },
          bici: { file: "bici.png", frames: 4 },
          bus: { file: "bus.png", frames: 1 },
          tram: { file: "tram.png", frames: 1 },
          // L'acqua della fontana (#288 passo 3d): lo zampillo a riposo e il getto acceso
          zampillo: { file: "zampillo.png", frames: 6 },
          getto: { file: "getto.png", frames: 4 },
        },
        birds: { y: 40, parallax: 0.2, everyMs: 14000 },
        // Sulle punte delle lastre delle statue e sul cornicione del palazzo
        pigeons: [{ x: 485, y: 330 }, { x: 1435, y: 330 }, { x: 235, y: 380 }, { x: 1685, y: 380 }, { x: 790, y: 100 }, { x: 1130, y: 100 }],
        // Lo sfondo è salito per stare dietro il piano dell'isola (#300, LIFT in padova.py): prato e bar 30 px, strada 24
        walkers: { y: 480, parallax: 0.75, count: 14, umbrellas: true },
        // Il tram e il traffico passano sulla strada davanti ai portici (#278): più giù le piazze li coprirebbero
        vehicles: { y: 464, parallax: 0.5, everyMs: 23000, kind: "tram" },
        traffic: { y: 464, parallax: 0.5, everyMs: 2600, kinds: ["auto", "auto", "auto", "vespa", "vespa", "furgone", "bici", "bus"] },
        flyers: { y: 90, parallax: 0.6, count: 7 }, // rondini sul Prato, di notte i pipistrelli
        planes: { y: -60, everyMs: 75000 },
        bar: { x: 120, y: 474, parallax: 0.8, tables: 3, spacing: 72 }, // il chiosco dello spritz sul prato
        daycycle: {
          cycleMs: 240000, // un giorno intero in 4 minuti: alba, giorno, tramonto e notte
          startAt: 0.8, // si parte poco dopo l'alba
          sky: true, // il cielo vivo dietro alle sagome di Santa Giustina e del Santo (#267)
          lamps: [90, 390, 690, 990, 1290, 1590, 1890, 2190].map((x) => ({ x: x - 260, y: 379, parallax: 0.75 })), // i lampioni del prato
          // Di notte i vetri accesi del palazzo, delle case e della città lontana, e le lanterne dei lampioni (#288)
          lightLayers: [0, 1, 2].map((i) => ({ file: `sfondo-${i}-luci.png`, parallax: [0.15, 0.45, 0.75][i] })),
          lightProps: [{ file: "palazzo-luci.png", x: 960, y: 522, scale: 0.5 }],
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
