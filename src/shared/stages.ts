// Le arene. Aggiungerne una = un blocco qui (e, se ha uno sfondo, una cartella in public/assets/stages/<id>/).
// La fisica legge solo questi dati, il client li disegna: un'arena non ha codice suo.

import { BOLOGNA, WORLD } from "./constants";
import { generateCourse, seedFromCourseId } from "./courseGenerator";
import { generateStage, seedFromStageId } from "./stageGenerator";
import { SALA_PROVE } from "./music/sala-prove";
import { songMovers } from "./musicStage";

export interface Rect {
  x: number; // bordo sinistro, pixel
  y: number; // superficie su cui si cammina
  width: number;
  height: number;
  on?: TimeWindows; // pezzo a tempo (#433): c'è solo dentro queste finestre del tempo dell'arena; senza, sempre
  forLeader?: number; // premio (#433): c'è solo se questa squadra era in testa ai punti torre a prizeAtMs (in pareggio nessuno)
}

// Finestre [da ms, a ms) del tempo dell'arena (#433): fuori il pezzo non c'è, niente ci sta sopra, fa male o spinge
export type TimeWindows = [number, number][];

export interface ThinPlatform {
  x: number; // bordo sinistro
  y: number; // superficie (alle estremità, se è ad arco)
  width: number;
  arch?: number; // piattaforma ad arco (#244): pixel di cui sale la superficie al centro, come un ponte
  y2?: number; // piattaforma inclinata (#246): altezza dell'estremità destra (y è la sinistra), come una scala
  on?: TimeWindows; // pezzo a tempo (#433), come quello dei blocchi pieni
  forLeader?: number; // premio (#433), come quello dei blocchi pieni
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
  kind?: string; // solo per il disegno: "barca" (#264), "nota" (#423); altrimenti la piattaforma con le strisce gialle e nere
  // Arena musicale (#423): al posto di path, le posizioni a tempo [ms nel giro, x, y], in ordine di tempo;
  // tra una e l'altra la piattaforma va dritta. path resta per il riquadro in cui si muove (predizione, editor)
  keys?: [number, number, number][];
  on?: [number, number][]; // finestre [da ms, a ms) del giro in cui la piattaforma c'è; senza, c'è sempre
  tint?: number; // solo per il disegno: il colore della traccia che la muove
  group?: string; // i bottoni sonori (pads) con questo gruppo la cambiano per un po' (#423)
}

// Bottone sonoro (#423): un pezzo dell'arena che si attiva saltandoci sopra o colpendolo. Suona e per
// effect.durationMs cambia le piattaforme mobili del suo gruppo; poi resta scarico per cooldownMs
export interface SoundPad {
  x: number; // bordo sinistro
  y: number; // la superficie su cui poggia (il bottone sporge sopra di PAD.heightPx)
  width: number;
  sound: string; // suono e disegno: "accordo", "cassa", "piatto"
  cooldownMs: number; // da quando lo si preme a quando si può ripremere
  effect: PadEffect;
}

// Postazione (#433): un pezzo di pavimento da cui si guida qualcosa, come in Lovers in a Dangerous Spacetime. Chi ci sta
// sopra a terra e preme attacco la usa coi suoi tasti (su e giù, attacco; salto per uscire). Logica in physics/stations.ts
export interface Station {
  kind: "bombarda" | "munizioni"; // bombarda: spara palle di mortadella; munizioni: carica le casse per una bombarda
  x: number; // bordo sinistro dell'area su cui si sta
  y: number; // superficie
  width: number;
  team?: number; // solo questa squadra la usa (nelle modalità a squadre); senza, chiunque
  on?: TimeWindows; // postazione a tempo (#433): fuori dalle finestre non si usa e chi c'è viene buttato fuori
  // Bombarda (senza, valgono i numeri di STATION in constants.ts)
  dir?: 1 | -1; // verso cui spara: 1 a destra, -1 a sinistra
  aimMinDeg?: number; // gradi sopra l'orizzontale
  aimMaxDeg?: number;
  ammoMax?: number;
  ballSpeedPxS?: number; // pixel/s di uscita della palla; senza, STATION.ballSpeedPxS
  autoAmmoMs?: number; // una palla in più ogni tanti ms anche senza munizioni (1 contro 1); senza, solo dalle casse
  // Munizioni
  feeds?: number; // indice in stations della bombarda che rifornisce
  loadMs?: number; // ms di attacco tenuto per caricare una cassa
  deliveryMs?: number; // ms di salita della cassa (l'ascensore disegnato resta una piattaforma mobile normale)
  crate?: number; // palle in una cassa
}

export interface PadEffect {
  group: string; // le piattaforme mobili con questo group
  durationMs: number; // quanto dura l'effetto
  on?: boolean; // le accende tutte, anche fuori dalle loro note
  dy?: number; // le sposta in verticale di tanto (negativo = su), entrando e uscendo dolcemente
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
  // Brano registrato: public/assets/music/<track>.ogg, in partita al posto del sintetizzatore e in giro intero.
  // Il preset sopra resta come ripiego se il file non si carica
  track?: string;
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
  // Quanto vale in verticale la parallasse degli strati e dello sfondo vivo (#400), da 0 a 1 (1 se manca): con 0 in
  // verticale lo sfondo resta attaccato al palco, così quando la telecamera sale non si staccano strade e prati
  verticalParallax?: number;
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
  // Con file (#378) l'acqua è dipinta: una striscia che si ripete in orizzontale, col pelo dell'acqua in cima (scale come
  // le altre immagini, 0,5 se manca; deep è la tinta del fondo sotto la striscia). floaters: ogni everyMs una cosa
  // gira lenta attorno al canale ad anello (fogli di life.sheets in kinds)
  outerWater?: {
    y: number;
    highY?: number;
    flood?: number;
    file?: string;
    scale?: number;
    deep?: string;
    // chi galleggia gira attorno al canale (#378): un giro in lapMs sull'ovale cx, cy, rx, ry; dietro è grande backK
    // underX: oltre questa distanza da cx passa sotto i ponti di profilo alle punte dell'isola, coperto (pixel)
    floaters?: { lapMs: number; cx: number; cy: number; rx: number; ry: number; backK?: number; underX?: number; kinds: string[] };
  };
  // Chi passa in primissimo piano (#378): figure sfocate (fogli di sheets, row per i fogli a righe) che attraversano la
  // strada davanti a tutto, alla y dei piedi, grandi k volte. Ognuna ogni everyMs, in crossMs, da from a to e ritorno
  near?: {
    from: number;
    to: number;
    figures: { sheet: string; row?: number; y: number; k: number; everyMs: number; crossMs: number; offsetMs?: number }[];
    // chi sta fermo (#378): i ragazzi alla ringhiera, animati sul posto a fps fotogrammi al secondo
    still?: { sheet: string; row?: number; x: number; y: number; k: number; fps: number; flip?: boolean }[];
  };
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
  floatersAfter?: boolean; // dopo questa decorazione il gioco disegna chi galleggia nella parte lontana del canale (#378)
  shadow?: boolean; // false: niente ombra del sole a terra (#378), per un pavimento o una vasca che hanno già la loro dipinta
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
  // Il gambo che regge la piattaforma (#378), come lo spruzzo della fontana di Padova: un foglio di sfondo vivo
  // (art.life.sheets) stirato dalla base (baseY, y del mondo) fino al fondo della piattaforma, largo width pixel di mondo.
  // Con hub il getto va dal mozzo (hub) alla piattaforma piegandosi: esce dritto in su e ci arriva dritto da sotto; se il
  // mozzo sta sopra la base, un getto unico largo 1,5 volte sale prima dalla base fino al mozzo
  // crown (un foglio di life.sheets): la corona d'acqua dove il getto batte sotto la piattaforma, che ricade a rami
  stem?: { sheet: string; baseY: number; width: number; hub?: { x: number; y: number }; crown?: string };
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
  if (art.life?.outerWater?.file) files.push(art.life.outerWater.file);
  return [...new Set(files)];
}

// Zoom della telecamera per un'arena (#240): un'arena più larga dello schermo si allontana di più
// per mostrarsi intera quando i lottatori si sparpagliano. Lo zoom più lontano resta comunque quello
// che riempie le zone di espulsione, se è più vicino di minZoom.
export interface StageCamera {
  minZoom?: number; // più piccolo = più lontano (CAMERA.minZoom se manca)
  maxZoom?: number; // quanto si avvicina quando i lottatori sono vicini (CAMERA.maxZoom se manca)
  floorY?: number; // y del mondo sempre inquadrata (#400), come Smash: chi sale in cima non perde di vista la piazza
}

// Getto d'acqua (#253): una colonna larga width che dalla base (y) sale per height pixel. A ogni giro, dopo
// la calma, ci sono le bolle (warnMs) e poi il getto (activeMs): chi è nella colonna viene spinto in alto a
// speed pixel/s, senza danno. Con dir è una raffica: stessa zona, ma spinge di lato (WIND). Dipende solo dal tempo dell'arena, come le trappole.
export interface Jet {
  x: number; // bordo sinistro
  y: number; // base della colonna
  width: number;
  height: number; // quanto sale la colonna d'acqua
  speed: number; // pixel/s verso l'alto (o verso dir) dati a chi ci sta dentro
  dir?: "left" | "right"; // raffica orizzontale (#433): senza, il getto spinge in alto
  periodMs: number;
  warnMs: number; // bolle prima del getto
  activeMs: number; // durata del getto
  offsetMs?: number;
  idle?: number; // solo grafica (#288): pixel dello zampillo a riposo, come una fontana che non si spegne mai
  on?: TimeWindows; // getto a tempo (#433): fuori dalle finestre non c'è, nemmeno le bolle
}

// Fase di un'arena che cambia durante la partita (#433). La fase attiva al tempo t è l'ultima con startMs <= t.
// blastZone e respawn, se ci sono, prendono il posto di quelli dell'arena (la fisica li legge da stageAt in
// physics/timed.ts); name, announce, warnMs e camera sono solo per il client (scritta della fase, telecamera).
export interface StagePhase {
  id: string; // nome stabile per il codice e i test
  name: string; // nome da mostrare
  startMs: number; // da quando vale, nel tempo dell'arena; la prima fase parte da 0
  announce?: string; // la scritta all'arrivo della fase
  warnMs?: number; // quanto prima di startMs il client avvisa
  blastZone?: { left: number; right: number; top: number; bottom: number }; // zone di espulsione della fase
  respawn?: { x: number; y: number }; // dove si ricompare durante la fase
  camera?: StageCamera; // zoom della telecamera durante la fase
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
  spawns: { x: number; y: number; team?: number }[]; // punti di partenza, uno per giocatore (y = piedi), in coppie simmetriche; `team` = squadra che parte lì nelle modalità a squadre (#433)
  respawn: { x: number; y: number }; // dove si ricompare dopo aver perso una vita
  colors: { sky: number; solid: number; solidEdge: number; platform: number }; // finché non c'è uno sfondo disegnato
  width?: number; // larghezza del mondo se più larga dello schermo (#240): nelle arene la telecamera inquadra tutti, nella Corsa segue
  height?: number; // altezza del mondo se più alta dello schermo (720): arene verticali, i pezzi stanno tra 0 e height; senza vale WORLD.height
  camera?: StageCamera; // zoom della telecamera per quest'arena (#240): senza, valgono CAMERA.minZoom e maxZoom
  // Solo per i percorsi della modalità Corsa (#57)
  checkpoints?: { x: number; y: number }[]; // dove si ricompare dopo una caduta (y = superficie)
  goal?: Rect; // chi lo tocca vince
  // Elementi dinamici (#14 passo 4)
  movers?: MovingPlatform[];
  hazards?: Hazard[];
  jets?: Jet[]; // getti d'acqua a tempo che spingono in alto (#253)
  phases?: StagePhase[]; // l'arena cambia a fasi durante la partita (#433), in ordine di startMs
  prizeAtMs?: number; // premio (#433): a questo tempo dell'arena si congela la squadra in testa ai punti torre; i pezzi con forLeader ci sono solo per lei
  prizeShowMs?: number; // tempo dell'arena a cui il client annuncia il premio (senza, prizeAtMs)
  itemSpots?: ItemSpot[]; // zone dove gli oggetti cadono più spesso (#253)
  music?: StageMusic; // musica della partita (E12 passo 4)
  song?: StageSong; // arena musicale (#423): il brano registrato a cui sono legate le piattaforme
  pads?: SoundPad[]; // bottoni sonori (#423)
  stations?: Station[]; // postazioni: bombarde e munizioni (#433)
  art?: StageArt; // sfondo a strati (E12 passo 3)
  // Nascosta (#408): resta nella repo e il server la avvia ancora per id, ma la lobby non la mostra e non può essere
  // l'arena predefinita. Per rimetterla in gioco basta togliere il campo.
  hidden?: boolean;
}

// Il brano di un'arena musicale (#423): public/assets/music/<id>.ogg, suonato in giro allineato al tempo dell'arena
export interface StageSong {
  id: string;
  lengthMs: number; // durata di un giro del brano, uguale al periodMs delle sue piattaforme
  bpm?: number; // battiti al minuto: Godot fa ballare lo sfondo a tempo (#423)
}

// Larghezza del mondo di un'arena: lo schermo, o di più per i percorsi
export const stageWidth = (stage: StageSpec) => stage.width ?? WORLD.width;
// Altezza del mondo di un'arena: lo schermo, o di più per le arene verticali
export const stageHeight = (stage: StageSpec) => stage.height ?? WORLD.height;

export const DEFAULT_STAGE_ID = "palco";

// La giostra d'acqua (#378, idea di Nicola dalle foto di Riccardo): getti che partono dallo stesso ugello al centro e
// reggono una piattaforma ciascuno, ognuno alla sua altezza. Girano attorno al centro come una giostra vista di lato:
// la piattaforma va avanti e indietro (raggio r) e, passando dietro, sale appena (la profondità, depth × r), passando
// davanti scende. Il giro è un ovale chiuso di 36 lati: i movers ad anello sanno già portare chi ci sta sopra.
export interface CarouselJet {
  y: number; // altezza della piattaforma (la sua superficie) al centro dell'ovale
  r: number; // quanto va lontano dal centro, a destra e a sinistra
  width: number;
}

export function fountainCarousel(cx: number, jets: CarouselJet[], periodMs: number, depth = 0.14): MovingPlatform[] {
  const sides = 36;
  const round = (v: number) => Math.round(v * 10) / 10;
  return jets.map((j, k) => ({
    width: j.width,
    path: Array.from({ length: sides }, (_, i) => {
      const a = (i / sides) * Math.PI * 2;
      return { x: round(cx + j.r * Math.cos(a) - j.width / 2), y: round(j.y - depth * j.r * Math.sin(a)) };
    }),
    periodMs,
    loop: true,
    offsetMs: Math.round((k * periodMs) / jets.length),
  }));
}

// Finestre di un pezzo che lampeggia (#433): c'è per presentMs, sparisce per goneMs, e così via da fromMs a untilMs
// (tempo dell'arena). offsetMs sfasa il ciclo (da 0 a presentMs + goneMs) per far sparire pezzi vicini in momenti diversi.
export function blinkWindows(fromMs: number, untilMs: number, presentMs: number, goneMs: number, offsetMs = 0): TimeWindows {
  const period = presentMs + goneMs;
  const out: TimeWindows = [];
  let t = fromMs;
  while (t < untilMs) {
    const c = (t - fromMs + offsetMs) % period; // dove siamo nel ciclo
    if (c < presentMs) {
      const end = Math.min(untilMs, t + presentMs - c);
      out.push([t, end]);
      t = end + goneMs;
    } else t += period - c; // siamo nella pausa: si aspetta il prossimo ciclo
  }
  return out;
}

// Chiavi di un ascensore che va su e giù fra low e high (#433), per un mover con keys: da fromMs a toMs del tempo
// dell'arena, un giro ogni cycleMs (salita e discesa a metà ciascuna, con una sosta pauseMs a ogni piano)
export function liftKeys(x: number, low: number, high: number, fromMs: number, toMs: number, cycleMs: number, pauseMs: number): [number, number, number][] {
  const keys: [number, number, number][] = [];
  const leg = (cycleMs - 2 * pauseMs) / 2;
  for (let t = fromMs; t < toMs; t += cycleMs) {
    keys.push([t, x, low], [t + pauseMs, x, low], [t + pauseMs + leg, x, high], [t + pauseMs * 2 + leg, x, high]);
  }
  return keys;
}

const MAIN = { x: 240, y: 560, width: 800, height: 80 };

// Bologna (#433): le finestre dei pezzi. La Garisenda c'è dalle torri al crollo, l'Asinelli resta; la rampa e i detriti
// arrivano dopo il crollo e restano; il tetto dell'Asinelli e i suoi pezzi sono della zuffa
const BOLOGNA_FROM_TOWERS: TimeWindows = [[BOLOGNA.towersMs, BOLOGNA.horizonMs]];
const BOLOGNA_GARISENDA: TimeWindows = [[BOLOGNA.towersMs, BOLOGNA.collapseMs]];
const BOLOGNA_RAMP: TimeWindows = [[BOLOGNA.rampMs, BOLOGNA.horizonMs]];
const BOLOGNA_BRAWL: TimeWindows = [[BOLOGNA.brawlMs, BOLOGNA.horizonMs]];
const BOLOGNA_ASINELLI_STATIONS: TimeWindows = [[BOLOGNA.towersMs, BOLOGNA.brawlMs]]; // le postazioni dell'Asinelli non ci sono nella zuffa
const BOLOGNA_PIAZZA: TimeWindows = [[0, BOLOGNA.towersMs]];

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
  // con al centro la fontana dell'Isola Memmia: dall'idea di Nicola (#378) i suoi tre spruzzi portano in giro tre tazze
  // su cui si sta in piedi. Le statue del Prato reggono le lastre, dietro si vede l'isola con le statue e il ponticello,
  // e un signore arrabbiato in bici attraversa tutto gridando. Larga 1,5 schermi: la telecamera si allontana fino a 0,6.
  padova: {
    id: "padova",
    name: "Padova",
    width: 1920,
    // floorY (#400): chi sale sulla tazza più alta vede ancora la piazza e il bordo del canale sotto di sé
    camera: { minZoom: 0.6, floorY: 600 },
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
    ],
    hazards: [
      // Il ciclista arrabbiato (#229): entra da fuori, attraversa la piazza ed esce. Più lento e più cattivo dal #288
      // TODO community: il grido "CANCAROOOO!" da registrare (chi lo fa?)
      { kind: "ciclista", x: 0, y: 0, width: 80, height: 95, damage: 13, knockback: 620, knockbackGrowth: 5, angleDeg: 35,
        travel: { path: [{ x: -160, y: 425 }, { x: 2080, y: 425 }], periodMs: 20000, warnMs: 1200, crossMs: 4200, alternate: true, offsetMs: 7000 } },
    ],
    // L'idea di Nicola (#378): dall'ugello al centro della vasca escono tre getti, come nelle foto della fontana vera, e
    // ognuno regge una tazza di marmo su cui si sta in piedi. Girano lenti attorno al centro come una giostra: il più
    // basso (y 320, un salto doppio dal pavimento) va più largo, quello in mezzo sale a 225, e il più alto, quasi dritto,
    // regge la tazza più grande a y 125: la cima del gioco, sopra le lastre delle statue (330).
    movers: fountainCarousel(960, [
      { y: 320, r: 160, width: 120 },
      { y: 225, r: 115, width: 120 },
      { y: 125, r: 60, width: 180 },
    ], 21000),
    // Gli oggetti cadono spesso sulla fontana e sulle lastre delle statue: rischio e premio, e un motivo per salire
    itemSpots: [
      { x: 840, y: 520, width: 240, weight: 3 },
      { x: 600, y: 410, width: 180, weight: 2 },
      { x: 1140, y: 410, width: 180, weight: 2 },
      { x: 470, y: 330, width: 140, weight: 2 },
      { x: 1310, y: 330, width: 140, weight: 2 },
      { x: 220, y: 380, width: 180, weight: 2 },
      { x: 1520, y: 380, width: 180, weight: 2 },
    ],
    blastZone: { left: -300, right: 2220, top: -420, bottom: 1000 },
    spawns: [300, 450, 200, 600, 380, 520, 250, 660].flatMap((x) => [{ x, y: 520 }, { x: 1920 - x, y: 520 }]).slice(0, 8),
    respawn: { x: 960, y: 40 }, // sopra la tazza più alta (#378)
    colors: { sky: 0x7aa0c4, solid: 0x6f6a60, solidEdge: 0xe8e2d2, platform: 0xd9d4c7 },
    // "Massima Tackenza" di Riccardo (#286): barocco veneziano da battaglia, Fa maggiore, 133 bpm, 2:55 in giro.
    // Il preset resta come ripiego se il file non si carica
    music: { bpm: 116, chords: ["F", "Am", "Bb", "C"], lead: "triangle", track: "massima-tackenza" },
    // Disegnati col codice da tools/arene/padova.py (#280), a 2x: chi disegna in Krita può sostituirli, stessi nomi e misure
    art: {
      verticalParallax: 0, // in verticale lo sfondo resta attaccato all'isola (#400): la strada non si stacca più
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
        // il fianco ovale (#378) lo disegna la decorazione fianco.png: il materiale mette solo la copertina chiara
        fianco: { file: "vuoto.png", edge: "bordo.png" },
        lastra: { file: "vuoto.png", depth: 12 }, // le lastre si disegnano intere, con i capi, come decorazioni (#378)
      },
      solidSkin: "pietra",
      platformSkin: "lastra",
      pieces: {
        solids: ["fianco"],
        platforms: ["lastra", "lastra", "lastra", "lastra", "lastra", "lastra"],
      },
      // Cancaro Man (#270, dal disegno di Riccardo): la pedalata in 8 fotogrammi da tools/arene/ciclista.py
      // TODO community: la voce del "CANCAROOOO!" da registrare; intanto c'è il fumetto
      // Le tre tazze della giostra d'acqua (#378): ogni getto parte dall'ugello al centro della vasca (y 492) e va fino alla
      // sua tazza, inclinato quando lei è lontana dal centro. La tazza in cima è più grande (larga 180 invece di 120)
      moverSprites: [0, 1, 2].map((mover) => ({
        mover, file: mover === 2 ? "tazza-grande.png" : "tazza.png", frames: 4, fps: 8, scale: 0.5, footX: mover === 2 ? 210 : 150, footY: 24,
        stem: { sheet: "getto", crown: "corona", baseY: 484, width: mover === 2 ? 60 : 52, hub: { x: 960, y: 482 } },
      })),
      hazardSprites: [
        { hazard: 0, file: "ciclista.png", frames: 8, fps: 16, scale: 0.58, footX: 150, footY: 312, shout: { text: "CANCAROOOO!", x: 200, y: 110 } },
      ],
      props: [
        // Le anse del canale ai lati (#378): il canale è un anello ovale e si chiude attorno alle punte dell'isola
        // Il canale dietro e attorno all'isola (#378), le anse ai lati, la fila di statue sulla sponda di là e i ponticelli
        { file: "canale-dietro.png", x: 960, y: 644, floatersAfter: true },
        { file: "ansa.png", x: 960, y: 604 },
        { file: "ponticelli.png", x: 960, y: 690 },
        // il parco oltre il vialetto, ai lati: i platani più lontani, più piccoli
        { file: "platano.png", x: -330, y: 566, scale: 0.3 },
        { file: "platano.png", x: 2250, y: 566, scale: 0.3, flip: true },
        // Il piano dell'isola in profondità (#300): il lastricato dietro il bordo, su cui poggiano statue e platani
        { file: "piano.png", x: 960, y: 524, scale: 0.5, shadow: false }, // è il pavimento: niente ombra a terra
        // Due platani sulla piazza (#288), dietro alle statue: la chioma sta sopra le teste e lascia vedere il palco
        { file: "platano.png", x: 410, y: 522, scale: 0.5 },
        { file: "platano.png", x: 1510, y: 522, scale: 0.5, flip: true },
        // la metà vicina dell'isola ovale (#378): il prato davanti alla linea dove si gioca, il cordolo e il muro nel canale
        { file: "fianco.png", x: 960, y: 660 },
        { file: "fontana.png", x: 960, y: 524, shadow: false }, // la fontana dell'Isola Memmia: la vasca, i paracarri e la ringhiera
        // la metà vicina della ringhiera: tutta dietro la linea dove si combatte, quindi dietro a chi ci passa (#378)
        { file: "fontana-davanti.png", x: 960, y: 530, shadow: false },
        // La sponda di qua del canale (#378), sfocata davanti a tutto: il canale resta una striscia stretta come quello vero
        { file: "primo-piano.png", x: 960, y: 1100, scale: 1, front: true },
        // I ponti del Prato davanti (#378, dalle foto di Riccardo): dalla piazza dove si gioca al parco di qua del canale.
        // Solo paesaggio: non si attraversano (vengono verso la telecamera, fuori dal piano di gioco)
        { file: "ponti-davanti.png", x: 960, y: 780, front: true },
        // Le statue del Prato in primissimo piano (#378), sfocate e trasparenti, solo fuori dall'isola
        { file: "statue-primo-piano.png", x: 960, y: 1100, scale: 1, front: true, opacity: 0.45 },
        // Le statue che reggono le lastre: il giovane con l'alloro, il filosofo con la barba, la dama col velo
        { file: "statua-ponte.png", x: 690, y: 522, scale: 0.5 },
        { file: "statua-ponte.png", x: 1230, y: 522, scale: 0.5, flip: true },
        { file: "statua-alta.png", x: 540, y: 522, scale: 0.5 },
        { file: "statua-alta.png", x: 1380, y: 522, scale: 0.5, flip: true },
        { file: "statua-piazza.png", x: 310, y: 522, scale: 0.5 },
        { file: "statua-piazza.png", x: 1610, y: 522, scale: 0.5, flip: true },
        // le lastre rette dalle statue (#378): intere, con la cornice e i capi, sopra le mani delle statue
        { file: "lastra-180.png", x: 690, y: 428, scale: 0.5, shadow: false },
        { file: "lastra-180.png", x: 1230, y: 428, scale: 0.5, shadow: false, flip: true },
        { file: "lastra-140.png", x: 540, y: 348, scale: 0.5, shadow: false },
        { file: "lastra-140.png", x: 1380, y: 348, scale: 0.5, shadow: false, flip: true },
        { file: "lastra-180.png", x: 310, y: 398, scale: 0.5, shadow: false },
        { file: "lastra-180.png", x: 1610, y: 398, scale: 0.5, shadow: false, flip: true },
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
          getto: { file: "getto.png", frames: 4 },
          // Chi galleggia nel canale (#378, idea di Riccardo): la bici tutta rovinata e il tizio ubriaco a pancia in su
          corona: { file: "corona.png", frames: 6 }, // la corona dei getti sotto le tazze (#378)
          // chi passa sfocato in primissimo piano (#378)
          ragazzi: { file: "ragazzi.png", frames: 6, rows: 4 }, // i ragazzi alla ringhiera (#378)
          "passanti-sfocati": { file: "passanti-sfocati.png", frames: 8, rows: 9 },
          "bici-sfocata": { file: "bici-sfocata.png", frames: 4 },
          "bici-rotta": { file: "bici-rotta.png", frames: 2 },
          ubriaco: { file: "ubriaco.png", frames: 4 },
        },
        // Il canale dell'Isola Memmia (#378, idea di Riccardo): acqua stagnante attorno all'isola, a filo degli archi di
        // mattoni sotto la piazza. Chi ci cade fa uno spruzzo e affonda come nel vuoto di prima (blastZone.bottom). Una bici
        // rovinata e un ubriaco che dorme a galla fanno piano il giro dell'anello, in due minuti e mezzo
        // In primissimo piano, sul vialetto e sulla strada davanti al canale, passa gente sfocata (#378, idea di Riccardo):
        // sotto il canale, dove il gioco non c'è, così non copre niente
        near: {
          from: -560, to: 2480,
          // i ragazzi alla ringhiera vicino alle bici, di spalle mentre guardano la rissa (idea di Riccardo): uno seduto
          // sulla ringhiera, uno che indica, uno che esulta e uno che filma col telefono
          still: [
            { sheet: "ragazzi", row: 0, x: 404, y: 693, k: 1.0, fps: 3 },
            { sheet: "ragazzi", row: 1, x: 442, y: 708, k: 1.02, fps: 4 },
            { sheet: "ragazzi", row: 2, x: 486, y: 710, k: 1.04, fps: 5 },
            { sheet: "ragazzi", row: 3, x: 526, y: 709, k: 1.0, fps: 2 },
          ],
          figures: [
            { sheet: "passanti-sfocati", row: 0, y: 742, k: 2.2, everyMs: 26000, crossMs: 19000 },
            { sheet: "bici-sfocata", y: 940, k: 2.6, everyMs: 33000, crossMs: 8000, offsetMs: 9000 },
            { sheet: "passanti-sfocati", row: 4, y: 760, k: 2.3, everyMs: 41000, crossMs: 24000, offsetMs: 21000 },
            { sheet: "passanti-sfocati", row: 3, y: 980, k: 2.8, everyMs: 47000, crossMs: 10000, offsetMs: 30000 },
            { sheet: "bici-sfocata", y: 744, k: 2.2, everyMs: 52000, crossMs: 11000, offsetMs: 40000 },
          ],
        },
        outerWater: {
          y: 622, file: "canale.png", deep: "26382f",
          floaters: { lapMs: 150000, cx: 960, cy: 554, rx: 1080, ry: 94, backK: 0.45, underX: 850, kinds: ["bici-rotta", "ubriaco"] },
        },
        birds: { y: 40, parallax: 0.2, everyMs: 14000 },
        // Sulle punte delle lastre delle statue
        pigeons: [{ x: 485, y: 330 }, { x: 1435, y: 330 }, { x: 235, y: 380 }, { x: 1685, y: 380 }],
        // Lo sfondo è salito per stare dietro il piano dell'isola (#300 e #378, LIFT in padova.py): prato e bar 96 px, strada 82
        walkers: { y: 414, parallax: 0.75, count: 14, umbrellas: true },
        // Il tram e il traffico passano sulla strada davanti ai portici (#278): più giù le piazze li coprirebbero
        vehicles: { y: 406, parallax: 0.5, everyMs: 23000, kind: "tram" },
        traffic: { y: 406, parallax: 0.5, everyMs: 2600, kinds: ["auto", "auto", "auto", "vespa", "vespa", "furgone", "bici", "bus"] },
        flyers: { y: 90, parallax: 0.6, count: 7 }, // rondini sul Prato, di notte i pipistrelli
        planes: { y: -60, everyMs: 75000 },
        bar: { x: 120, y: 414, parallax: 0.8, tables: 3, spacing: 72 }, // il chiosco dello spritz sul prato: a terra come panchine e passanti (#378)
        daycycle: {
          cycleMs: 240000, // un giorno intero in 4 minuti: alba, giorno, tramonto e notte
          startAt: 0.8, // si parte poco dopo l'alba
          sky: true, // il cielo vivo dietro alle sagome di Santa Giustina e del Santo (#267)
          lamps: [90, 390, 690, 990, 1290, 1590, 1890, 2190].map((x) => ({ x: x - 260, y: 313, parallax: 0.75 })), // i lampioni del prato
          // Di notte i vetri accesi delle case e della città lontana, e le lanterne dei lampioni (#288)
          lightLayers: [0, 1, 2].map((i) => ({ file: `sfondo-${i}-luci.png`, parallax: [0.15, 0.45, 0.75][i] })),
        },
      },
    },
  },

  // Padova · il palazzo (#378): la Padova di prima dell'idea di Nicola, conservata com'era il 18 ottobre 2026, con il
  // palazzo signorile e i suoi balconi al centro e lo zampillo che lancia in alto. I disegni sono una copia ferma.
  // Nascosta dal 20 ottobre 2026 (#408): tenuta per le emergenze, si avvia ancora per id. Per rimetterla nella lobby
  // basta togliere la riga hidden.
  "padova-palazzo": {
    id: "padova-palazzo",
    name: "Padova · il palazzo",
    hidden: true,
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
  // Arena musicale (#423, idea di Nicola): le tracce del brano muovono le piattaforme. Il basso alza e abbassa i due
  // ascensori ai lati (uno al contrario dell'altro), gli accordi spostano la navetta in mezzo, la melodia accende i
  // tasti in alto come un piano roll (più acuta la nota, più a destra e più in alto) e il battimani una piattaforma in cima.
  // Per un altro brano: npm run midi:import su un altro MIDI con tracce dagli stessi nomi (src/shared/music/README.md)
  musica: {
    id: "musica",
    name: "Sala Prove",
    solids: [MAIN],
    platforms: [],
    movers: songMovers(SALA_PROVE, [
      { role: "lift", track: "Basso", x: 90, width: 130, yLow: 520, yHigh: 360, tint: 0x4fc3f7, group: "basso" },
      { role: "lift", track: "Basso", x: 1060, width: 130, yLow: 520, yHigh: 360, invert: true, tint: 0x4fc3f7, group: "basso" },
      { role: "slide", track: "Accordi", y: 420, width: 200, xLow: 340, xHigh: 740, tint: 0x81c784, group: "accordi" },
      {
        role: "keys",
        track: "Melodia",
        group: "melodia",
        width: 90,
        slots: [0, 1, 2, 3, 4, 5, 6, 7].map((i) => ({ x: 250 + i * 100, y: 330 - i * 12 })),
        tint: 0xffb74d,
      },
      { role: "keys", track: "Batteria", pitches: [39], width: 100, slots: [{ x: 590, y: 190 }], tint: 0xf06292 },
    ]),
    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },
    spawns: [0.3, 0.7, 0.45, 0.55, 0.2, 0.8, 0.37, 0.63].map((f) => ({ x: MAIN.x + MAIN.width * f, y: MAIN.y })),
    respawn: { x: WORLD.width / 2, y: 160 },
    colors: { sky: 0x170f2e, solid: 0x2b2145, solidEdge: 0xff4fd8, platform: 0x9ad0ff },
    // Tre bottoni sonori sul pavimento: ci si salta sopra o si colpiscono, suonano e per qualche secondo cambiano la mappa.
    // Poi restano scarichi per un po', così non si possono tenere sempre accesi
    pads: [
      // L'accordo accende tutti i tasti della melodia: per 4 s c'è una scala fino in cima
      { x: 262, y: MAIN.y, width: 56, sound: "accordo", cooldownMs: 12000, effect: { group: "melodia", durationMs: 4000, on: true } },
      // Il piatto alza di colpo la navetta degli accordi sopra i tasti: un passaggio verso la cima. Non sotto il punto
      // di rientro (x 640): chi ricompare ci cadrebbe sopra e lo premerebbe
      { x: 560, y: MAIN.y, width: 56, sound: "piatto", cooldownMs: 9000, effect: { group: "accordi", durationMs: 3500, dy: -190 } },
      // La cassa spara in alto gli ascensori del basso
      { x: 962, y: MAIN.y, width: 56, sound: "cassa", cooldownMs: 12000, effect: { group: "basso", durationMs: 4000, dy: -150 } },
    ],
    song: { id: SALA_PROVE.id, lengthMs: SALA_PROVE.lengthMs, bpm: SALA_PROVE.bpm },
    music: { bpm: SALA_PROVE.bpm, chords: ["Am", "F", "C", "G"], lead: "square" }, // se il brano non si carica
  },
  // Bologna (#433, nome provvisorio): arena a squadre che cambia col tempo dell'arena. Solo dati e colori semplici, i disegni verranno.
  // Squadra 1 sulla Garisenda (sinistra), squadra 2 sull'Asinelli (destra), una piazza larga e alta 2400 con il suolo a y 2000
  // 1) "Sotto le Torri" 0-45 s: piazza, portici e traffico leggero. 2) "Ognuno sulla sua torre" fino a 2:30: l'ingorgo
  // fa male a terra e ognuno sale sulla sua torre. 3) "Crolla la Garisenda" fino a 2:45: la torre cede, la rampa la appoggia
  // all'Asinelli. 4) "La grande zuffa": in cima, con merli che lampeggiano, vento, fulmini e dalle 4:30 la polvere che sale.
  // Le torri sono pari: 8 pezzi utili e 2 postazioni ciascuna, con un salto di 300 px in mezzo. La Garisenda è più larga e
  // bassa (passi da 95 px, cima a y 1180), l'Asinelli più stretta e alta (passi da 120 px, cima a y 980).
  bologna: {
    id: "bologna",
    name: "Bologna",
    width: 2200,
    height: 2400,
    solids: [
      { x: 100, y: 2000, width: 2000, height: 400 }, // la piazza (via Rizzoli ci passa in mezzo)
      { x: 400, y: 1940, width: 600, height: 60 }, // la base della Garisenda: parte la squadra 1
      { x: 1300, y: 1940, width: 400, height: 60 }, // la base dell'Asinelli: parte la squadra 2
    ],
    platforms: [
      // Portici ai lati: il passaggio coperto (y 1880) e il tetto (y 1760). Restano sempre: al riparo dall'ingorgo
      { x: 100, y: 1880, width: 180 },
      { x: 100, y: 1760, width: 180 },
      { x: 1920, y: 1880, width: 180 },
      { x: 1920, y: 1760, width: 180 },
      // Garisenda (da 0:45 a 2:30): scala, balconi di legno, finestre. Pezzi 4-11
      { x: 790, y: 1845, y2: 1940, width: 190, on: BOLOGNA_GARISENDA }, // scala
      { x: 570, y: 1750, width: 170, on: BOLOGNA_GARISENDA }, // balcone di legno
      { x: 410, y: 1655, width: 120, on: BOLOGNA_GARISENDA }, // finestra
      { x: 550, y: 1560, y2: 1655, width: 220, on: BOLOGNA_GARISENDA }, // scala
      { x: 810, y: 1465, width: 150, on: BOLOGNA_GARISENDA }, // postazione (A) della Garisenda
      { x: 590, y: 1370, width: 150, on: BOLOGNA_GARISENDA }, // balcone di legno
      { x: 410, y: 1275, width: 110, on: BOLOGNA_GARISENDA }, // finestra
      { x: 630, y: 1180, width: 160, on: BOLOGNA_GARISENDA }, // postazione (B) della Garisenda: la cima
      // Asinelli (da 0:45): stessi pezzi, più stretti e più alti
      { x: 1310, y: 1820, y2: 1940, width: 140, on: BOLOGNA_FROM_TOWERS }, // scala
      { x: 1510, y: 1700, width: 130, on: BOLOGNA_FROM_TOWERS }, // balcone di legno
      { x: 1370, y: 1580, width: 100, on: BOLOGNA_FROM_TOWERS }, // finestra
      { x: 1500, y: 1460, y2: 1580, width: 150, on: BOLOGNA_FROM_TOWERS }, // scala
      { x: 1320, y: 1340, width: 140, on: BOLOGNA_FROM_TOWERS }, // postazione (A) dell'Asinelli
      { x: 1520, y: 1220, width: 130, on: BOLOGNA_FROM_TOWERS }, // balcone di legno
      { x: 1370, y: 1100, width: 100, on: BOLOGNA_FROM_TOWERS }, // finestra
      { x: 1470, y: 980, width: 140, on: BOLOGNA_FROM_TOWERS }, // postazione (B) dell'Asinelli: la cima
      // La Garisenda caduta appoggiata all'Asinelli (da 2:34): una rampa a quattro tratti, dalla base fino alla finestra a mezza altezza
      { x: 770, y: 1940, y2: 1850, width: 160, on: BOLOGNA_RAMP },
      { x: 930, y: 1850, y2: 1760, width: 160, on: BOLOGNA_RAMP },
      { x: 1090, y: 1760, y2: 1670, width: 160, on: BOLOGNA_RAMP },
      { x: 1250, y: 1670, y2: 1580, width: 160, on: BOLOGNA_RAMP },
      // Detriti sospesi (da 2:36): una scala di pezzi di torre dalla rampa fino al tetto
      { x: 1150, y: 1575, width: 120, on: BOLOGNA_RAMP },
      { x: 960, y: 1480, width: 110, on: BOLOGNA_RAMP },
      { x: 790, y: 1385, width: 110, on: BOLOGNA_RAMP },
      { x: 960, y: 1290, width: 110, on: BOLOGNA_RAMP },
      { x: 1100, y: 1180, width: 110, on: BOLOGNA_RAMP },
      { x: 1130, y: 1075, width: 100, on: BOLOGNA_RAMP },
      // La grande zuffa (da 2:45): il tetto dell'Asinelli e quattro merli che lampeggiano, sfasati di 2 s l'uno dall'altro
      { x: 1270, y: 980, width: 460, on: BOLOGNA_BRAWL },
      ...[1280, 1390, 1580, 1680].map((x, i) => ({
        x,
        y: 900,
        width: 70,
        on: blinkWindows(BOLOGNA.brawlMs, BOLOGNA.horizonMs, BOLOGNA.merlonPresentMs, BOLOGNA.merlonGoneMs, i * 2000),
      })),
      // I ponteggi del premio (da 2:45, solo per la squadra in testa ai punti torre al crollo): due per lato del tetto, la
      // squadra 1 a sinistra e la 2 a destra, sotto il bordo per risalire più facilmente. In fondo: gli indici sopra non cambiano
      { x: 1150, y: 1010, width: 110, on: BOLOGNA_BRAWL, forLeader: 1 },
      { x: 1020, y: 1120, width: 110, on: BOLOGNA_BRAWL, forLeader: 1 },
      { x: 1740, y: 1010, width: 110, on: BOLOGNA_BRAWL, forLeader: 2 },
      { x: 1870, y: 1120, width: 110, on: BOLOGNA_BRAWL, forLeader: 2 },
    ],
    movers: [
      // Il ponteggio della Garisenda (0:45-2:30): un ascensore fuori dalla torre, fino alla finestra più alta
      { width: 90, path: [{ x: 300, y: 1940 }, { x: 300, y: 1275 }], periodMs: BOLOGNA.liftPeriodMs, offsetMs: 0,
        keys: liftKeys(300, 1940, 1275, BOLOGNA.towersMs, BOLOGNA.collapseMs, 15000, 1500), on: BOLOGNA_GARISENDA },
      // Il montacarichi dell'Asinelli (da 0:45): pari alla Garisenda, fino alla finestra più alta
      { width: 90, path: [{ x: 1710, y: 1940 }, { x: 1710, y: 1100 }], periodMs: BOLOGNA.liftPeriodMs,
        keys: liftKeys(1710, 1940, 1100, BOLOGNA.towersMs, BOLOGNA.horizonMs, 20000, 1500), on: BOLOGNA_FROM_TOWERS },
    ],
    hazards: [
      // Traffico leggero della piazza (0-45 s), alto solo 50 px: chi sta sui portici e sulle basi è al riparo
      { kind: "ciclista", x: 0, y: 0, width: 80, height: 50, damage: 10, knockback: 600, knockbackGrowth: 5, angleDeg: 35, on: BOLOGNA_PIAZZA,
        travel: { path: [{ x: -160, y: 1950 }, { x: 2260, y: 1950 }], periodMs: 9000, warnMs: 1200, crossMs: 3600, alternate: true } },
      { kind: "auto", x: 0, y: 0, width: 150, height: 50, damage: 12, knockback: 650, knockbackGrowth: 5, angleDeg: 35, on: BOLOGNA_PIAZZA,
        travel: { path: [{ x: 2260, y: 1950 }, { x: -260, y: 1950 }], periodMs: 10000, warnMs: 1200, crossMs: 3000, alternate: true, offsetMs: 4500 } },
      // L'ingorgo in via Rizzoli (da 0:45 a 2:30): ondate di 3 s con 1 s di pausa, a sinistra e a destra sfasate, che lanciano in alto
      // (verso le torri). offsetMs fa partire il primo giro a 0:45
      ...[{ x: 100, offsetMs: 3000 }, { x: 1100, offsetMs: 1000 }].map(({ x, offsetMs }) => ({
        kind: "ingorgo", x, y: 1944, width: 1000, height: 56, damage: 7, knockback: 650, knockbackGrowth: 4, angleDeg: 85,
        periodMs: BOLOGNA.jamPeriodMs, activeMs: BOLOGNA.jamActiveMs, offsetMs, on: BOLOGNA_GARISENDA,
      })),
      // I mattoni della Garisenda (2:30-2:36): cadono dalla cima sulla sua base. L'ultimo punto un pixel a sinistra per i
      // pari fa lanciare a sinistra, per i dispari a destra (la trappola che viaggia lancia verso dove va)
      ...[420, 520, 620, 720, 830].map((x, i) => ({
        kind: "mattone", x: 0, y: 0, width: 70, height: 70, damage: 9, knockback: 600, knockbackGrowth: 4, angleDeg: 60,
        on: [[BOLOGNA.collapseMs, BOLOGNA.bricksEndMs]] as TimeWindows,
        travel: { path: [{ x, y: 1100 }, { x: x + (i % 2 === 0 ? -1 : 1), y: 1930 }], periodMs: 2400, warnMs: 600, crossMs: 1000, offsetMs: (2000 + i * 500) % 2400 },
      })),
      // Il fulmine sul punto più alto dell'Asinelli (da 2:45): un lampo di mezzo secondo ogni 20 s
      { kind: "fulmine", x: 1450, y: 820, width: 120, height: 160, damage: 18, knockback: 800, knockbackGrowth: 6, angleDeg: 90,
        periodMs: BOLOGNA.lightningPeriodMs, activeMs: 500, offsetMs: 10000, on: BOLOGNA_BRAWL },
      // La polvere che sale (da 4:30): lenta, resta alta a lungo. Il giro è scritto perché la calma finisca a 4:30 (periodMs - totale)
      { kind: "polvere", x: 0, y: 1500, width: 2200, height: 300, damage: 8, knockback: 600, knockbackGrowth: 3, angleDeg: 88,
        on: [[BOLOGNA.dustMs, BOLOGNA.horizonMs]],
        flood: { highY: 1000, periodMs: BOLOGNA.dustMs + 193000, warnMs: 8000, riseMs: 60000, holdMs: 120000, fallMs: 5000, lowSafe: true } },
    ],
    // Le raffiche della cima (da 2:45): una a sinistra e una a destra, sfasate di mezzo giro
    jets: (["left", "right"] as const).map((dir, i) => ({
      x: 1130, y: 1040, width: 600, height: 300, speed: 600, dir,
      periodMs: BOLOGNA.windPeriodMs, warnMs: 1500, activeMs: 2500, offsetMs: i * (BOLOGNA.windPeriodMs / 2), on: BOLOGNA_BRAWL,
    })),
    phases: [
      { id: "piazza", name: "Sotto le Torri", startMs: 0,
        blastZone: { left: -180, right: 2380, top: 1300, bottom: 2500 }, respawn: { x: 1150, y: 1500 },
        camera: { minZoom: 0.5, maxZoom: 1.1, floorY: 2080 } },
      { id: "torri", name: "Ognuno sulla sua torre", startMs: BOLOGNA.towersMs, announce: "INGORGO IN VIA RIZZOLI!", warnMs: 5000,
        blastZone: { left: -180, right: 2380, top: 300, bottom: 2500 }, respawn: { x: 1150, y: 1100 },
        camera: { minZoom: 0.45, maxZoom: 1.0, floorY: 2080 } },
      { id: "crollo", name: "Crolla la Garisenda", startMs: BOLOGNA.collapseMs, announce: "LA GARISENDA CEDE!", warnMs: 6000,
        blastZone: { left: -180, right: 2380, top: 300, bottom: 2500 }, respawn: { x: 1150, y: 1100 },
        camera: { minZoom: 0.45, maxZoom: 1.0, floorY: 2080 } },
      // TODO community: la scritta della zuffa (provvisoria)
      { id: "zuffa", name: "La grande zuffa", startMs: BOLOGNA.brawlMs, announce: "TUTTI SULL'ASINELLI!", warnMs: 5000,
        blastZone: { left: -180, right: 2380, top: 100, bottom: 1650 }, respawn: { x: 1500, y: 740 },
        camera: { minZoom: 0.5, maxZoom: 1.1, floorY: 1350 } },
    ],
    // Postazioni (#433): su ogni torre una bombarda sulla cima e le munizioni in fondo, vicino all'ascensore (le casse
    // "salgono con l'ascensore"). Ci sono dalla fase 2 fino al crollo (Garisenda) o alla zuffa (Asinelli)
    stations: [
      { kind: "bombarda", x: 635, y: 1180, width: 150, team: 1, dir: 1, aimMinDeg: BOLOGNA.aimMinDeg, aimMaxDeg: BOLOGNA.aimMaxDeg, ammoMax: 6, ballSpeedPxS: BOLOGNA.ballSpeedPxS, autoAmmoMs: BOLOGNA.autoAmmoMs, on: BOLOGNA_GARISENDA },
      { kind: "munizioni", x: 400, y: 1940, width: 110, team: 1, feeds: 0, on: BOLOGNA_GARISENDA },
      { kind: "bombarda", x: 1475, y: 980, width: 130, team: 2, dir: -1, aimMinDeg: BOLOGNA.aimMinDeg, aimMaxDeg: BOLOGNA.aimMaxDeg, ammoMax: 6, ballSpeedPxS: BOLOGNA.ballSpeedPxS, autoAmmoMs: BOLOGNA.autoAmmoMs, on: BOLOGNA_ASINELLI_STATIONS },
      { kind: "munizioni", x: 1590, y: 1940, width: 110, team: 2, feeds: 2, on: BOLOGNA_ASINELLI_STATIONS },
    ],
    // Il premio: chi ha più punti torre al crollo trova dei ponteggi nella zuffa
    prizeAtMs: BOLOGNA.collapseMs,
    prizeShowMs: BOLOGNA.brawlMs,
    camera: { minZoom: 0.5, maxZoom: 1.1, floorY: 2080 },
    blastZone: { left: -180, right: 2380, top: 1300, bottom: 2500 }, // come la prima fase
    // Prime otto partenze: quattro sulla base della Garisenda (squadra 1), quattro su quella dell'Asinelli (squadra 2)
    spawns: [
      { x: 460, y: 1940, team: 1 }, { x: 570, y: 1940, team: 1 }, { x: 680, y: 1940, team: 1 }, { x: 790, y: 1940, team: 1 },
      { x: 1360, y: 1940, team: 2 }, { x: 1450, y: 1940, team: 2 }, { x: 1550, y: 1940, team: 2 }, { x: 1640, y: 1940, team: 2 },
    ],
    respawn: { x: 1150, y: 1500 },
    // "La Rossa": mattoni caldi con il bordo chiaro, legno ocra, cielo del tramonto; lontano dai colori dei giocatori (stile-grafico, sez. 7)
    colors: { sky: 0x3b2634, solid: 0x8a4a35, solidEdge: 0xf0d9b5, platform: 0xc49a5a },
    music: { bpm: 112, chords: ["Dm", "Bb", "F", "C"], lead: "triangle" },
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
