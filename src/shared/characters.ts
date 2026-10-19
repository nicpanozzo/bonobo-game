// I personaggi giocabili. Aggiungerne uno = un blocco qui e una cartella in public/assets/characters/<id>/.
// Cambiano aspetto e statistiche (E11 passo B); le mosse proprie arrivano con le speciali (E10).

import { CHARACTER_STATS, CHARGE_EXAMPLE, DEFAULT_SPECIALS, FIGHTER, RECOVERY, type AttackSpec } from "./constants";
import type { AttackKind, SpecialKind } from "./types";

// Gli stati che ogni lottatore con sprite deve avere
export const ANIMATION_NAMES = ["idle", "walk", "jump", "fall", "light", "heavy", "hit"] as const;
export type AnimationName = (typeof ANIMATION_NAMES)[number];
// Stati facoltativi (E7): chi non li ha mostra quello di ANIMATION_FALLBACK.
// shield, grab, throw, grabbed e special sono posti per scudo, presa, lanci e speciali (E8, E10).
export const OPTIONAL_ANIMATION_NAMES = [
  "doubleJump",
  "tumble",
  "ledge",
  "climb",
  "land",
  "lightUp",
  "lightDown",
  "lightAir",
  "heavyUp",
  "heavyDown",
  "heavyAir",
  "recovery",
  "taunt",
  "shield",
  "grab",
  "throw",
  "grabbed",
  "special",
  "dash", // scatto e corsa dopo il doppio tocco (#199)
  "supreme", // suprema (#101)
  "specialNeutral", // le tre speciali, una per tasto (#257): senza disegno, la posa di "special"
  "specialSide",
  "specialDown",
  "dashAttack", // attacco in corsa: senza disegno, la posa del pesante
] as const;
export type OptionalAnimationName = (typeof OPTIONAL_ANIMATION_NAMES)[number];
export type SpriteState = AnimationName | OptionalAnimationName;
export const SPRITE_STATES: readonly SpriteState[] = [...ANIMATION_NAMES, ...OPTIONAL_ANIMATION_NAMES];

// Ripiego (E7 passo 3): lo stato da mostrare quando manca il disegno. Si segue la catena finché si trova
// uno stato che c'è; ogni catena finisce in uno obbligatorio (lo controlla characters.test.ts).
export const ANIMATION_FALLBACK: Record<OptionalAnimationName, SpriteState> = {
  doubleJump: "jump",
  tumble: "hit",
  ledge: "jump",
  climb: "jump",
  land: "idle",
  lightUp: "light",
  lightDown: "light",
  lightAir: "light",
  heavyUp: "heavy",
  heavyDown: "heavy",
  heavyAir: "heavy",
  dashAttack: "heavy",
  recovery: "jump",
  taunt: "idle",
  shield: "idle",
  grab: "light", // presa e chi tiene (#109)
  throw: "grab", // i quattro lanci
  grabbed: "hit", // chi è tenuto
  special: "heavy",
  dash: "walk", // senza disegno, la camminata (per Bonobot: il galoppo sulle nocche)
  supreme: "special", // senza disegno, la posa della speciale (e poi del pesante)
  specialNeutral: "special",
  specialSide: "special",
  specialDown: "special",
};

export interface SpriteAnimation {
  row: number;
  frames: number;
  fps: number;
  loop: boolean;
  hitFrame?: number; // solo negli attacchi, vedi SpriteStateSpec
  startFrame?: number; // solo negli attacchi, vedi SpriteStateSpec
}

// Formato a foglio unico: un PNG con una riga per animazione (Capt. OrsoBlu, Bonobot)
export interface SpriteSheetSpec {
  path: string; // relativo alla radice del sito
  frameWidth: number; // pixel
  frameHeight: number;
  columns: number; // fotogrammi per riga nel PNG
  scale?: number; // grandezza a schermo rispetto al PNG: 0.5 per i disegni fatti a 2x (manca = 1)
  footY?: number; // pixel dall'alto del fotogramma dove stanno i piedi (manca = frameHeight, il bordo basso)
  filter?: SpriteFilter;
  // Riga del PNG, numero di fotogrammi e velocità di ogni animazione (fotogrammi/s)
  animations: Record<AnimationName, SpriteAnimation> & Partial<Record<OptionalAnimationName, SpriteAnimation>>;
}

// Come si ingrandisce e rimpicciolisce il disegno: "linear" (con mipmap) per l'illustrato, "nearest" per la pixel art
export type SpriteFilter = "linear" | "nearest";

// Formato cartella (E7 passo 2): un PNG per stato, <dir>/<stato>.png, con i fotogrammi in fila da sinistra.
// Il numero di fotogrammi lo ricava npm run export:godot dalla larghezza del PNG. Guida: public/assets/characters/README.md
export interface SpriteStateSpec {
  fps: number; // fotogrammi al secondo
  loop: boolean; // true = ricomincia, false = si ferma sull'ultimo fotogramma
  // Negli attacchi: il fotogramma (da 0) in cui arriva il colpo. Il gioco lo fa cadere quando la hitbox si
  // accende (startupMs di ATTACKS) e fa finire l'animazione con cooldownMs, anche nelle varianti che la usano
  // come ripiego. Senza hitFrame l'animazione va a fps.
  hitFrame?: number;
  // Negli attacchi: il primo fotogramma mostrato (manca = 0). Serve quando il fotogramma 0 è la posa di riposo,
  // uguale a idle: così la sagoma cambia nell'istante in cui si preme il tasto (#384 C1)
  startFrame?: number;
}

// I lottatori a scheletro (tools/rig) partono dalla posa di riposo: negli attacchi si mostra dal fotogramma 1 (#384 C1)
function fromRest<T extends Record<string, SpriteStateSpec>>(animations: T): T {
  return Object.fromEntries(Object.entries(animations).map(([state, a]) => [state, a.hitFrame ? { ...a, startFrame: 1 } : a])) as T;
}
export interface SpriteFolderSpec {
  dir: string; // cartella relativa alla radice del sito, es. "assets/characters/<id>"
  frameWidth: number; // pixel, uguale in tutti i PNG
  frameHeight: number;
  scale?: number; // come in SpriteSheetSpec: 0.5 per i disegni fatti a 2x
  // Pixel dall'alto del fotogramma dove stanno i piedi (manca = frameHeight, il bordo basso).
  // Serve se qualche stato scende sotto i piedi, come chi è appeso al bordo con il corpo sotto lo spigolo
  footY?: number;
  filter?: SpriteFilter;
  // Prova del rig a pezzi in tempo reale (#403): cartella con rig.json, animazioni.json e pezzi/ (tools/rig/).
  // Godot monta i pezzi e interpola le pose; senza, o se il rig non si carica, si usano i PNG degli stati
  rig?: string;
  animations: Record<AnimationName, SpriteStateSpec> & Partial<Record<OptionalAnimationName, SpriteStateSpec>>;
}

export function isSpriteFolder(sprite: SpriteSheetSpec | SpriteFolderSpec): sprite is SpriteFolderSpec {
  return "dir" in sprite;
}

// Il PNG di uno stato nel formato cartella
export function spriteStatePath(sprite: SpriteFolderSpec, state: SpriteState): string {
  return `${sprite.dir}/${state}.png`;
}

// Lo stato che si disegna davvero al posto di "state", seguendo il ripiego
export function resolveAnimation(animations: Partial<Record<SpriteState, unknown>>, state: SpriteState): SpriteState {
  let s = state;
  for (let i = 0; i <= OPTIONAL_ANIMATION_NAMES.length && !Object.hasOwn(animations, s); i++) {
    if (!Object.hasOwn(ANIMATION_FALLBACK, s)) break; // obbligatorio mancante: lo segnala characters.test.ts
    s = ANIMATION_FALLBACK[s as OptionalAnimationName];
  }
  return s;
}

// La tabella completa per Godot: ogni stato, con i dati del disegno che lo mostra e il suo nome in src
export function resolvedAnimations<T extends object>(animations: Partial<Record<SpriteState, T>>): Record<SpriteState, T & { src: SpriteState }> {
  const out = {} as Record<SpriteState, T & { src: SpriteState }>;
  for (const state of SPRITE_STATES) {
    const src = resolveAnimation(animations, state);
    const a = animations[src];
    if (a) out[state] = { ...a, src };
  }
  return out;
}

// Moltiplicatori dei numeri di FIGHTER (1 = come Bonobot, il metro), tra CHARACTER_STATS.min e max
export interface CharacterStats {
  speed: number; // corsa a terra
  airSpeed: number; // velocità massima in aria
  jump: number; // velocità del salto e del doppio salto
  weight: number; // il knockback dei colpi si divide per questo: più pesante, meno si vola
  gravity: number; // caduta: più alta, si scende prima e si salta meno in alto
}

// Mosse speciali (E10, #111): tasto speciale da fermi (neutral), con una direzione (side) o con giù (down).
// Il colpo di ogni speciale si legge come un attacco: percentuale, knockback, angolo e rettangolo davanti
export type SpecialHit = Pick<AttackSpec, "damage" | "baseKnockback" | "knockbackGrowth" | "angleDeg" | "range" | "height" | "boxX" | "boxY">;
export type SpecialSlot = "neutral" | "side" | "down";
export const SPECIAL_SLOTS: readonly SpecialSlot[] = ["neutral", "side", "down"];

interface SpecialBase {
  name: string; // come si chiama nei menu e nel tutorial
}
// Proiettile: parte dopo startupMs e vola dritto (gravity 0) o ad arco; il rettangolo è il proiettile
export interface ProjectileSpecial extends SpecialBase, SpecialHit {
  type: "projectile";
  startupMs: number;
  cooldownMs: number; // dall'inizio della mossa a quando si può attaccare di nuovo
  speed: number; // pixel/s in orizzontale
  gravity: number; // pixel/s²: 0 = dritto
  lift?: number; // pixel/s verso l'alto alla partenza, per i tiri ad arco (con gravity)
  spreadDeg?: number[]; // gradi sopra l'orizzontale, uno per tiro a rotazione: "a caso" ma deterministico
  lifeMs: number; // dopo quanto sparisce da solo
  maxAlive: number; // proiettili dello stesso giocatore in volo insieme
  color?: number; // colore del proiettile in Godot (0xRRGGBB); senza, quello del Tiro
}
// Scatto: si corre in avanti colpendo, in aria una volta sola fino all'atterraggio
export interface DashSpecial extends SpecialBase, SpecialHit {
  type: "dash";
  startupMs: number;
  durationMs: number; // per quanto si scatta, colpendo
  speed: number; // pixel/s
  endLagMs: number; // fermi dopo lo scatto
}
// Carica: si tiene premuto da minMs a maxMs, al rilascio il colpo cresce fino a maxMultiplier
export interface ChargeSpecial extends SpecialBase, SpecialHit {
  type: "charge";
  minMs: number;
  maxMs: number;
  maxMultiplier: number; // danno e knockback alla carica piena
  activeMs: number; // per quanto resta attivo il colpo dopo il rilascio
  endLagMs: number;
}
// Contrattacco: un colpo preso nella finestra non fa danno e si risponde col colpo di questa speciale
export interface CounterSpecial extends SpecialBase, Omit<SpecialHit, "damage"> {
  type: "counter";
  startupMs: number;
  windowMs: number;
  endLagMs: number; // fermi se va a vuoto
  minDamage: number; // danno minimo della risposta...
  multiplier: number; // ...altrimenti il danno parato moltiplicato per questo
}
// Suprema propria (#102). "drop": si salta in alto e in avanti ad afferrare una liana che scende, la si tira,
// e dall'altro capo cade qualcosa in verticale sulla liana. Chi la fa si toglie da sotto con una capriola
// all'indietro e resta imbersagliabile dall'inizio alla fine. Il colpo è un'area centrata sulla liana.
// Il movimento lo calcola la fisica (physics/supreme.ts); fallMs, runSpeed e label servono solo a Godot
export interface DropSupreme {
  type: "drop";
  name: string; // come si chiama nei menu
  label: string; // la scritta sopra quello che cade, come i nomi dei giocatori
  leapMs: number; // il salto verso la liana, che intanto scende
  leapDx: number; // pixel in avanti dal punto di partenza: lì sta la liana
  leapDy: number; // pixel in alto
  pullMs: number; // appesi, si tira la liana
  warnMs: number; // dalla tirata all'impatto: l'ombra a terra
  fallMs: number; // gli ultimi ms dell'ombra in cui si vede cadere (solo disegno)
  flipMs: number; // la capriola all'indietro, subito dopo la tirata (non più lunga di warnMs)
  flipDx: number; // pixel dalla liana a dove si atterra: più di metà area, per non stare sotto
  flipArc: number; // pixel di altezza in più della capriola
  impactMs: number; // per quanto l'impatto colpisce
  recoverMs: number; // dopo l'impatto, fermi (puff), sempre imbersagliabili
  width: number; // area del colpo, pixel, centrata sulla liana
  height: number; // pixel dal terreno in su
  damage: number;
  baseKnockback: number;
  knockbackGrowth: number;
  angleDeg: number; // verso l'alto e lontano dal centro
  runSpeed: number; // pixel/s dello gnomo che scappa dopo il puff (solo disegno)
  art?: DropSupremeArt; // i disegni; senza, Godot non disegna la scena
}
// I disegni della suprema "drop", in dir sotto public/: si sostituiscono i PNG e il codice resta uguale
export interface DropSupremeArt {
  dir: string;
  falling: string; // quello che cade, appeso alla liana dall'alto: nodo della liana in alto al centro
  landed: string; // a terra dopo l'impatto, fino al puff
  runner: string; // chi scappa dopo il puff: fotogrammi in fila, guarda a destra, piedi in basso al centro
  runnerFrames: number;
  runnerFps: number;
  scale: number; // 0.5 per i disegni fatti a 2x
}
// Suprema "spin" (#358): dopo windupMs gira su se stesso per durationMs, muovendosi piano (moveSpeed, frazione
// della corsa a terra), e colpisce chi gli sta intorno ogni hitEveryMs. Imbersagliabile dall'inizio alla fine
export interface SpinSupreme {
  type: "spin";
  name: string; // come si chiama nei menu
  windupMs: number;
  durationMs: number;
  hitEveryMs: number;
  endLagMs: number; // dopo, fermi
  moveSpeed: number;
  width: number; // area del colpo, pixel, centrata su chi gira
  height: number; // pixel dai piedi in su
  damage: number; // per ogni colpo
  baseKnockback: number;
  knockbackGrowth: number;
  angleDeg: number; // verso l'alto e lontano dal centro
}
// Suprema "grab" (#358), snaack di Lampione: dopo windupMs il braccio si allunga davanti fino a reach pixel per
// reachMs; chi tocca viene tirato davanti a chi lo fa e scaraventato giù (angleDeg negativo). A terra
// rimbalza in alto con lo stesso angolo, in aria (fuori dal bordo) cade come una schiacciata. Imbersagliabile
export interface GrabSupreme {
  type: "grab";
  name: string; // come si chiama nei menu
  windupMs: number; // il braccio si allunga
  reachMs: number; // tutto allungato: qui afferra
  endLagMs: number; // il braccio torna, fermi
  reach: number; // pixel davanti a chi la fa
  height: number; // pixel di altezza della mano
  damage: number;
  baseKnockback: number;
  knockbackGrowth: number;
  angleDeg: number; // negativo: verso il basso
}
// Suprema "burst" (#358), IRA di Lendmar: dopo windupMs (si arrabbia) tira waves raffiche, una ogni waveEveryMs,
// di count proiettili della sua speciale neutra, a ventaglio da tutte e due le parti e verso l'alto: in orizzontale
// fino a speed pixel/s, in alto lift pixel/s al centro (meno ai lati). Il danno è quello della speciale neutra
export interface BurstSupreme {
  type: "burst";
  name: string; // come si chiama nei menu
  windupMs: number;
  waves: number;
  waveEveryMs: number;
  count: number; // proiettili per raffica
  speed: number;
  lift: number;
  endLagMs: number; // dopo l'ultima raffica, fermi
  slick?: boolean; // i proiettili che cadono su un blocco lasciano una pozza scivolosa (SLICK, #13)
}
// Suprema "infect" (#358), il filo di Kirschner di Dr. Micelium: dopo windupMs un filo sottile parte davanti fino a
// reach pixel per activeMs. Chi tocca prende le spore (powerup "spore": più lento per SPORE.ms) e chi la fa diventa
// più forte (powerup "micelio" per MICELIO.ms)
export interface InfectSupreme {
  type: "infect";
  name: string; // come si chiama nei menu
  windupMs: number;
  activeMs: number;
  endLagMs: number;
  reach: number; // pixel davanti a chi la fa
  height: number; // pixel di spessore del filo
  damage: number;
  baseKnockback: number;
  knockbackGrowth: number;
  angleDeg: number;
}
// Suprema "rewind" (#358), …COSA? di Marcomunista: dopo windupMs torna dov'era e con la percentuale di backMs prima,
// e chi gli sta entro stunRadius pixel dove arriva resta stordito per stunMs. Imbersagliabile dall'inizio alla fine
export interface RewindSupreme {
  type: "rewind";
  name: string; // come si chiama nei menu
  windupMs: number;
  backMs: number;
  endLagMs: number;
  stunRadius: number;
  stunMs: number;
}
export type SupremeSpec = DropSupreme | SpinSupreme | GrabSupreme | BurstSupreme | InfectSupreme | RewindSupreme;

export type SpecialSpec = ProjectileSpecial | DashSpecial | ChargeSpecial | CounterSpecial;
export type SpecialSet = Record<SpecialSlot, SpecialSpec>;

// Le compagnie del lore (#13), dalla cartella delle schede: chi viene da dove. Nella lobby sono badge sul lottatore
export const CREWS = {
  cuamm: "Cuamm", // lo zoccolo duro: il collegio a Padova
  cologna: "Cologna Veneta",
  schio: "Schio",
  lolhardcore: "Lol Hardcore", // conosciuti giocando a LoL, più competitivi
} as const;
export type CrewId = keyof typeof CREWS;

// Una skin (#339): solo un altro disegno dello stesso lottatore. Fisica, colpi e statistiche non cambiano
export interface SkinSpec {
  name: string; // nella lobby, es. "Jax"
  sprite: SpriteFolderSpec; // con portrait.png nella stessa cartella
}

// Il compagno (#369): il disegno è in Godot, qui solo come si muove
export interface CompanionSpec {
  name: string; // come si chiama nei menu
  width: number; // pixel
  height: number;
  speed: number; // corsa, in multipli di FIGHTER.groundSpeed
  jump: number; // pixel/s verso l'alto quando salta
  bites: AttackKind[]; // attacchi del padrone che fa il compagno, partendo da dove è lui (#369 passo 2)
}

export interface CharacterSpec {
  id: string;
  name: string;
  crews?: CrewId[]; // compagnie del lore, mostrate come badge nella lobby
  skins?: Record<string, SkinSpec>; // aspetti alternativi da scegliere nella lobby (#339)
  sprite?: SpriteSheetSpec | SpriteFolderSpec; // senza sprite si disegna il rettangolo colorato
  stats?: Partial<CharacterStats>; // quelle che mancano valgono 1
  specials?: Partial<SpecialSet>; // quelle che mancano sono DEFAULT_SPECIALS (E10)
  supreme?: SupremeSpec; // senza, la suprema di base (ATTACKS.supreme, #101)
  companion?: CompanionSpec; // un compagno che lo segue da solo (#369)
  recovery?: Partial<AttackSpec & typeof RECOVERY>; // numeri propri del recupero (#11): quelli che mancano restano i soliti
  quotes?: CharacterQuotes; // le battute della scheda, scritte in un fumetto (solo disegno, Godot)
  strikeColor?: string; // colore della scia dei suoi colpi, "#rrggbb" (#384 B2); senza, bianca o arancio per i pesanti
  // I suoi colpi normali (#384 D2): ritocchi di ATTACKS, tempi e zone entro ATTACK_TWEAK (lo controlla characters.test.ts)
  attacks?: Partial<Record<TweakableAttack, Partial<AttackSpec>>>;
}

// Gli attacchi normali che un personaggio può ritoccare: non le speciali, la suprema, il recupero, presa e lanci
export type TweakableAttack = "light" | "heavy" | "lightUp" | "lightDown" | "lightAir" | "heavyUp" | "heavyDown" | "heavyAir" | "dashAttack";

// Le battute dalla scheda del personaggio (#13). Solo testo: le voci registrate restano a parte (E13)
export interface CharacterQuotes {
  taunt?: string; // la provocazione, quando provoca
  ko?: string; // l'urlo quando va KO
  victory?: string; // nella schermata finale, quando vince (senza, la provocazione)
}

export const DEFAULT_CHARACTER_ID = "default";

// Gli sprite provvisori dei lottatori della community (#13): pezzi disegnati col codice sullo scheletro di Bonobot,
// in piedi, con le sue animazioni e la corsa umana (tools/rig/genera_pezzi_lottatore.py e animazioni_lottatore.py).
// Stessi stati e tempi di Bonobot, tranne la suprema, che resta quella di base
function communitySprite(id: string): SpriteFolderSpec {
  return {
    dir: `assets/characters/${id}`,
    frameWidth: 336,
    frameHeight: 368,
    footY: 286,
    scale: 0.5,
    animations: fromRest({
      idle: { fps: 12, loop: true },
      walk: { fps: 24, loop: true }, // corsa in piedi alla velocità di groundSpeed
      jump: { fps: 24, loop: false },
      fall: { fps: 24, loop: true },
      light: { fps: 24, loop: false, hitFrame: 2 },
      heavy: { fps: 24, loop: false, hitFrame: 8 },
      hit: { fps: 24, loop: false },
      doubleJump: { fps: 24, loop: false },
      tumble: { fps: 24, loop: true },
      ledge: { fps: 12, loop: true },
      climb: { fps: 24, loop: false },
      land: { fps: 24, loop: false },
      taunt: { fps: 12, loop: false },
      dash: { fps: 24, loop: true },
      shield: { fps: 12, loop: true },
      grab: { fps: 24, loop: false, hitFrame: 2 },
      throw: { fps: 24, loop: false, hitFrame: 0 },
      grabbed: { fps: 12, loop: true },
      lightUp: { fps: 24, loop: false, hitFrame: 2 },
      lightDown: { fps: 24, loop: false, hitFrame: 2 },
      lightAir: { fps: 24, loop: false, hitFrame: 2 },
      heavyUp: { fps: 24, loop: false, hitFrame: 7 },
      heavyDown: { fps: 24, loop: false, hitFrame: 6 },
      heavyAir: { fps: 24, loop: false, hitFrame: 5 },
      recovery: { fps: 24, loop: false, hitFrame: 0 },
      specialNeutral: { fps: 24, loop: false, hitFrame: 5 },
      specialSide: { fps: 24, loop: false, hitFrame: 3 }, // in piedi: carica, due giri di corsa, frena
      specialDown: { fps: 24, loop: false, hitFrame: 1 },
    }),
  };
}

// I lottatori dai fogli delle pose a colori (tools/sprite/foglio_a_colori.py): una posa per stato, due per la corsa.
// Misure del fotogramma e dei piedi come le stampa lo script
// extra: le pose che il foglio non ha, disegnate a parte nel suo stile (la mossa resta quella della scheda)
function sheetSprite(id: string, frameWidth: number, frameHeight: number, footY: number, extra: Partial<SpriteFolderSpec["animations"]> = {}): SpriteFolderSpec {
  return {
    dir: `assets/characters/${id}`,
    frameWidth,
    frameHeight,
    footY,
    scale: 0.5, // il foglio è disegnato grande come un disegno a 2x
    animations: {
      idle: { fps: 1, loop: true },
      walk: { fps: 6, loop: true }, // passo e corsa del foglio, alternati
      jump: { fps: 1, loop: false },
      fall: { fps: 1, loop: false },
      light: { fps: 1, loop: false }, // "Side Tilt"
      heavy: { fps: 1, loop: false }, // "Side Smash"
      hit: { fps: 1, loop: false }, // nel foglio non c'è: il fermo piegato all'indietro
      land: { fps: 1, loop: false }, // "Crouch"
      dash: { fps: 1, loop: false },
      lightUp: { fps: 1, loop: false },
      lightDown: { fps: 1, loop: false },
      lightAir: { fps: 1, loop: false }, // "Neutral Air"
      heavyUp: { fps: 1, loop: false },
      heavyDown: { fps: 1, loop: false },
      heavyAir: { fps: 1, loop: false }, // "Forward Air"
      recovery: { fps: 1, loop: false }, // "Up Air"
      shield: { fps: 1, loop: false },
      grab: { fps: 1, loop: false },
      throw: { fps: 1, loop: false }, // "Throw (forward)"
      specialNeutral: { fps: 1, loop: false }, // "Pummel": le mani alla bocca
      specialDown: { fps: 1, loop: false }, // "Shield", per il contrattacco
      supreme: { fps: 1, loop: false }, // "Final Smash"
      ...extra,
    },
  };
}

// Una suprema "drop" con i tempi di quella di Omar (Bonobot, già provati al playtest #257) e i disegni provvisori
// fatti da tools/rig/genera_supreme_drop.py in assets/characters/<id>/supreme/<nome>-{cade,a-terra,corre}.png
function communityDrop(id: string, art: string, name: string, more: Partial<DropSupreme> = {}): DropSupreme {
  return {
    type: "drop",
    name,
    label: name,
    leapMs: 325,
    leapDx: 60,
    leapDy: 110,
    pullMs: 195,
    warnMs: 650,
    fallMs: 390,
    flipMs: 455,
    flipDx: 130,
    flipArc: 50,
    impactMs: 100,
    recoverMs: 390,
    width: 132,
    height: 150,
    damage: 35,
    baseKnockback: 600,
    knockbackGrowth: 11,
    angleDeg: 70,
    runSpeed: 520,
    art: {
      dir: `assets/characters/${id}/supreme`,
      falling: `${art}-cade.png`,
      landed: `${art}-a-terra.png`,
      runner: `${art}-corre.png`,
      runnerFrames: 4,
      runnerFps: 12,
      scale: 0.5,
    },
    ...more,
  };
}

export const CHARACTERS: Record<string, CharacterSpec> = {
  default: {
    id: "default",
    name: "Bonobo",
    // E10: lancia una banana ad arco; scatto e contrattacco sono quelli di base
    // TODO community: nome e numeri della Banana provvisori
    specials: {
      neutral: { type: "projectile", name: "Banana", startupMs: 233, cooldownMs: 600, speed: 560, gravity: 1800, lift: 520, lifeMs: 1400, maxAlive: 1, range: 26, height: 18, damage: 7, baseKnockback: 240, knockbackGrowth: 3.5, angleDeg: 50, color: 0xf2d33a },
    },
  },

  // Creatura blu sulla barchetta col remo, proposta da @MauroGrecchi (#37).
  // Si chiamava Egiainuso: rinominata Capt. OrsoBlu con #178, il nome passa al nuovo personaggio
  orsoblu: {
    id: "orsoblu",
    name: "Capt. OrsoBlu",
    crews: ["cuamm", "lolhardcore"],
    // Con la barchetta addosso è un po' più pesante e lento di Bonobot (E11)
    // TODO community: statistiche provvisorie, da confermare con @MauroGrecchi
    stats: { weight: 1.05, speed: 0.9, airSpeed: 0.95, jump: 0.95 },
    // E10: uno schizzo d'acqua veloce e corto, una remata in avanti e un colpo di remo da caricare
    // TODO community: nomi e numeri provvisori, da confermare con @MauroGrecchi (#37)
    specials: {
      neutral: { type: "projectile", name: "Schizzo", startupMs: 200, cooldownMs: 500, speed: 900, gravity: 0, lifeMs: 550, maxAlive: 2, range: 20, height: 12, damage: 4, baseKnockback: 180, knockbackGrowth: 3, angleDeg: 25, color: 0x6ec8ff },
      side: { type: "dash", name: "Remata", startupMs: 120, durationMs: 300, speed: 760, endLagMs: 320, range: 46, height: 50, damage: 10, baseKnockback: 380, knockbackGrowth: 8, angleDeg: 30 },
      down: { ...CHARGE_EXAMPLE, name: "Colpo di remo" },
    },
    sprite: {
      path: "assets/characters/orsoblu/orsoblu.png",
      frameWidth: 64,
      frameHeight: 96,
      columns: 6,
      filter: "nearest", // pixel art: senza sfumare i pixel
      animations: {
        idle: { row: 0, frames: 4, fps: 4, loop: true },
        walk: { row: 1, frames: 6, fps: 10, loop: true },
        jump: { row: 2, frames: 2, fps: 8, loop: false },
        fall: { row: 3, frames: 2, fps: 6, loop: true },
        light: { row: 4, frames: 3, fps: 20, loop: false },
        heavy: { row: 5, frames: 4, fps: 8, loop: false }, // il colpo di remo cade quando la hitbox si attiva (startupMs)
        hit: { row: 6, frames: 2, fps: 10, loop: true },
      },
    },
  },

  // Bonobo spavaldo con la canna in bocca: personaggio di test e manichino (#20), proposto da Riccardo (GiovannifRana).
  // Animato a pezzi (cutout) su uno scheletro e disegnato a 2x; i colpi seguono startupMs/activeMs di ATTACKS.
  bonobot: {
    id: "bonobot",
    name: "Bonobot",
    // Suprema "Omar" (#102): Bonobot salta ad afferrare la liana, la tira e fa una capriola indietro;
    // l'orsogufo Omar cade sulla liana, schiaccia chi sta lì, fa puff e diventa uno gnomo che scappa.
    // Numeri provvisori dall'issue e da Riccardo (area 132 px), da rivedere al playtest (#22).
    // Dopo il playtest di Riccardo (#257): tempi 1,3 volte più lunghi (circa 1,7 s in tutto) e danno da 28 a 35
    supreme: {
      type: "drop",
      name: "Omar",
      label: "Omar",
      leapMs: 325,
      leapDx: 60,
      leapDy: 110,
      pullMs: 195,
      warnMs: 650,
      fallMs: 390,
      flipMs: 455,
      flipDx: 130,
      flipArc: 50,
      impactMs: 100,
      recoverMs: 390,
      width: 132,
      height: 150,
      damage: 35,
      baseKnockback: 600,
      knockbackGrowth: 11,
      angleDeg: 70,
      runSpeed: 520,
      // Disegni provvisori fatti col codice (sorgenti SVG accanto), da sostituire con quelli di Riccardo
      art: {
        dir: "assets/characters/bonobot/omar",
        falling: "orsogufo-cade.png",
        landed: "orsogufo-a-terra.png",
        runner: "gnomo-corre.png",
        runnerFrames: 4,
        runnerFps: 12,
        scale: 0.5,
      },
    },
    // Speciali proprie (#257 passo 2), idea di Riccardo: soffia il fumo della canna, galoppa sulle nocche, si batte il petto
    // TODO community: nomi e numeri provvisori, da rivedere al playtest (#22)
    specials: {
      // un anello lento e corto, uno alla volta: tiene a distanza più che fare danno
      neutral: { type: "projectile", name: "Anello di fumo", startupMs: 260, cooldownMs: 620, speed: 380, gravity: 0, lifeMs: 900, maxAlive: 1, range: 30, height: 30, damage: 5, baseKnockback: 160, knockbackGrowth: 3, angleDeg: 20, color: 0xd9d3c7 },
      // parte più tardi dello scatto di base (140 ms invece di 100) ma colpisce più forte
      side: { type: "dash", name: "Carica sulle nocche", startupMs: 140, durationMs: 320, speed: 820, endLagMs: 360, range: 48, height: 46, damage: 11, baseKnockback: 400, knockbackGrowth: 8.5, angleDeg: 35 },
      // il contrattacco di base, un po' più lento a chiudersi e più forte nella risposta
      down: { type: "counter", name: "Battuta del petto", startupMs: 60, windowMs: 380, endLagMs: 480, minDamage: 9, multiplier: 1.35, range: 64, height: 64, baseKnockback: 470, knockbackGrowth: 9, angleDeg: 40 },
    },
    // Rifatto con lo scheletro nuovo (#195) nello stile della guida (E7 passo 4): un PNG per stato, fatti da
    // tools/rig/animazioni_bonobot.py e tools/rig/rendi_sprite.py (vedi public/assets/characters/bonobot/README.md)
    sprite: {
      dir: "assets/characters/bonobot",
      frameWidth: 336,
      frameHeight: 368,
      footY: 286, // sotto i piedi restano 82 pixel per il corpo di chi è appeso al bordo
      scale: 0.5,
      animations: fromRest({
        idle: { fps: 12, loop: true }, // respiro, peso che passa da un piede all'altro, battito di ciglia, 2 s
        walk: { fps: 24, loop: true }, // galoppo sulle nocche: mani e piedi a terra scorrono alla velocità di groundSpeed
        jump: { fps: 24, loop: false },
        fall: { fps: 24, loop: true },
        light: { fps: 24, loop: false, hitFrame: 2 }, // schiaffo di rovescio, con il gomito che si apre a frusta
        heavy: { fps: 24, loop: false, hitFrame: 8 }, // martello a due pugni: su in punta di piedi, poi giù di peso
        hit: { fps: 24, loop: false },
        doubleJump: { fps: 24, loop: false }, // capriola in avanti che si apre verso la caduta
        tumble: { fps: 24, loop: true }, // rotola all'indietro quando vola via dopo un colpo forte
        ledge: { fps: 12, loop: true }, // appeso con le due mani, piedi contro la parete, dondola piano
        climb: { fps: 24, loop: false }, // si tira su e torna in piedi in LEDGE.climbMs
        land: { fps: 24, loop: false }, // atterra di peso piegando le ginocchia
        taunt: { fps: 12, loop: false }, // soffia il fumo verso l'avversario e si batte il petto, 2 s
        // #257 passo 3
        dash: { fps: 24, loop: true }, // galoppo più disteso e veloce, alla velocità di DASH.runSpeed
        shield: { fps: 12, loop: true }, // in guardia dentro la bolla, i pugni davanti alla faccia
        grab: { fps: 24, loop: false, hitFrame: 2 }, // si allunga con le due mani, poi tiene l'altro stretto al petto
        throw: { fps: 24, loop: false, hitFrame: 0 }, // scaglia con le braccia in avanti e in alto (si lascia subito)
        grabbed: { fps: 12, loop: true }, // tenuto: si dimena e scalcia
        // #257 passo 4: in ogni hitFrame la mano sta nella zona del colpo (lo controlla tools/rig/animazioni_bonobot.py)
        lightUp: { fps: 24, loop: false, hitFrame: 2 }, // schiaffo verso l'alto, guardando su
        lightDown: { fps: 24, loop: false, hitFrame: 2 }, // spazzata bassa col dorso della mano, accucciato
        lightAir: { fps: 24, loop: false, hitFrame: 2 }, // rovescio in aria
        heavyUp: { fps: 24, loop: false, hitFrame: 7 }, // si accuccia e balza su battendo i pugni sopra la testa
        heavyDown: { fps: 24, loop: false, hitFrame: 6 }, // affondo radente con le due braccia a terra
        heavyAir: { fps: 24, loop: false, hitFrame: 5 }, // martello a due pugni in aria
        recovery: { fps: 24, loop: false, hitFrame: 0 }, // sale avvitandosi con le braccia in alto
        // #257 passo 5: le tre speciali e la suprema. hitFrame cade alla fine dell'avvio della speciale
        specialNeutral: { fps: 24, loop: false, hitFrame: 5 }, // Anello di fumo: prende la canna, tira indietro la testa e soffia
        specialSide: { fps: 24, loop: false, hitFrame: 3 }, // Carica sulle nocche: testa bassa, due giri di galoppo, frena
        specialDown: { fps: 24, loop: false, hitFrame: 1 }, // Battuta del petto: pugni alterni sul petto, poi braccia aperte
        // Omar: salto alla liana, appeso a tirarla, capriola all'indietro, accucciato all'impatto (hitFrame), si rialza
        supreme: { fps: 24, loop: false, hitFrame: 24 },
      }),
    },
  },

  // Gatto rasta grassottello col bong, proposto da @MauroGrecchi (#168). Provvisorio: è il suo foglio ritagliato
  // e ingrandito, un'eccezione alla style guide come Capt. OrsoBlu (vedi public/assets/characters/elvedeo/README.md).
  elvedeo: {
    id: "elvedeo",
    name: "Elvedeo",
    crews: ["cuamm"],
    // Con la pancia è più pesante e un po' lento, salta meno (E11). Peso da 1,15 a 1,05 (#276): con 1,15 vinceva
    // il 67-73% contro il bot in npm run balance, sopra la soglia del 60%
    // TODO community: statistiche provvisorie, da confermare con @MauroGrecchi
    stats: { weight: 1.05, speed: 0.85, airSpeed: 0.95, jump: 0.9 },
    // Speciali proprie (#262), dal foglio di Mauro: la nuvola verde soffiata lontano, la rotolata, il colpo di bong caricato
    // TODO community: nomi e numeri provvisori, da confermare con @MauroGrecchi
    specials: {
      // lenta e larga: copre una zona più che colpire lontano
      neutral: { type: "projectile", name: "Nuvola verde", startupMs: 300, cooldownMs: 700, speed: 260, gravity: 0, lifeMs: 1100, maxAlive: 1, range: 44, height: 40, damage: 6, baseKnockback: 150, knockbackGrowth: 3, angleDeg: 30, color: 0x8fbf6a },
      // più lenta e lunga dello scatto di base, e più bassa: rotola sulla pancia
      side: { type: "dash", name: "Rotolata di pancia", startupMs: 120, durationMs: 360, speed: 700, endLagMs: 380, range: 46, height: 40, damage: 9, baseKnockback: 380, knockbackGrowth: 8, angleDeg: 30 },
      // la carica di esempio, più pesante: parte più tardi e chiude più lenta
      down: { type: "charge", name: "Bongata", minMs: 250, maxMs: 1300, maxMultiplier: 1.8, activeMs: 120, endLagMs: 420, range: 56, height: 54, damage: 12, baseKnockback: 420, knockbackGrowth: 10.5, angleDeg: 45 },
    },
    sprite: {
      dir: "assets/characters/elvedeo",
      frameWidth: 360,
      frameHeight: 200,
      scale: 0.5, // ingrandito a 2x dal foglio originale
      animations: {
        idle: { fps: 12, loop: true }, // fuma, 2 s
        walk: { fps: 20, loop: true }, // a quattro zampe
        jump: { fps: 24, loop: false },
        fall: { fps: 6, loop: true },
        light: { fps: 24, loop: false, hitFrame: 2 }, // soffia la nuvola di fumo verde
        heavy: { fps: 24, loop: false, hitFrame: 6 }, // colpo di bong dall'alto
        hit: { fps: 24, loop: false },
        tumble: { fps: 24, loop: true }, // rotola quando vola via
      },
    },
  },

  // Omino col cappellino e lo zaino, dal foglio delle pose di @Marcomunista (#178): ha preso il nome Egiainuso,
  // che prima era di Capt. OrsoBlu. Una posa per stato (due per la corsa), ritagliate da
  // tools/sprite/egiainuso_dal_foglio.py; un'eccezione alla style guide come Elvedeo (vedi il suo README).
  egiainuso: {
    id: "egiainuso",
    name: "Egiainuso",
    crews: ["lolhardcore"],
    // TODO community: statistiche e mosse speciali di base, da decidere con @Marcomunista
    sprite: {
      dir: "assets/characters/egiainuso",
      frameWidth: 318,
      frameHeight: 238,
      footY: 194,
      scale: 0.5, // il foglio è disegnato grande come un disegno a 2x
      animations: {
        idle: { fps: 1, loop: true },
        walk: { fps: 6, loop: true }, // passo e corsa del foglio, alternati
        jump: { fps: 1, loop: false },
        fall: { fps: 1, loop: false },
        light: { fps: 1, loop: false }, // "Side Tilt"
        heavy: { fps: 1, loop: false }, // "Side Smash"
        hit: { fps: 1, loop: false }, // nel foglio non c'è: il fermo piegato all'indietro
        land: { fps: 1, loop: false }, // "Crouch"
        dash: { fps: 1, loop: false },
        lightUp: { fps: 1, loop: false },
        lightDown: { fps: 1, loop: false },
        lightAir: { fps: 1, loop: false }, // "Neutral Air"
        heavyUp: { fps: 1, loop: false },
        heavyDown: { fps: 1, loop: false },
        heavyAir: { fps: 1, loop: false }, // "Forward Air"
        recovery: { fps: 1, loop: false }, // "Up Air"
        shield: { fps: 1, loop: false },
        grab: { fps: 1, loop: false },
        throw: { fps: 1, loop: false }, // "Throw (forward)"
        supreme: { fps: 1, loop: false }, // "Final Smash"
      },
    },
  },
  // Lottatori dalle schede della community (#13), compilate a ottobre 2026 nella cartella Drive del gruppo.
  // Disegni provvisori fatti col codice (communitySprite), da sostituire con quelli veri.
  // Le supreme chieste che sono "qualcosa che cade dall'alto" usano la drop di Omar (communityDrop); le altre
  // (presa, rotazione, ritorno indietro, pioggia di merda...) richiedono codice nuovo e per ora usano quella di base. TODO community: statistiche e numeri provvisori, da provare al playtest (#22)

  // Baldo: pazzo scatenato, ipercompetitivo, grosso, con i guanti da portiere e la racchetta da ping pong
  lampione: {
    id: "lampione",
    strikeColor: "#ffe9a8", // scia dei colpi: la luce del lampione (#384)
    name: "Lampione",
    quotes: { ko: "Grazie per essere passato nel nostro canale" }, // dalla scheda: l'urlo del KO
    crews: ["cuamm", "schio"],
    sprite: communitySprite("lampione"),
    skins: {
      // Alla Jax di League of Legends, col lampione come arma; a tratto come Egiainuso (tools/rig/rendi_tratto.py)
      jax: { name: "Jax", sprite: { ...communitySprite("lampione/skins/jax"), frameWidth: 324, frameHeight: 262, footY: 223, scale: 0.909 } },
    },
    // pesante, salto esplosivo, bravo negli scatti brevi ma poco agile in aria
    stats: { weight: 1.1, jump: 1.15, speed: 1.05, airSpeed: 0.9 },
    // dalla scheda: "un beagle che fa gli attacchi base" (#369). TODO community: il nome del cane
    companion: { name: "Beagle", width: 44, height: 30, speed: 1.2, jump: 900, bites: ["light", "heavy"] },
    // dalla scheda: "snaack", allunga il braccio, afferra e scaraventa giù (#358)
    supreme: {
      type: "grab",
      name: "snaack",
      windupMs: 260,
      reachMs: 240,
      endLagMs: 450,
      reach: 280,
      height: 50,
      damage: 16,
      baseKnockback: 520,
      knockbackGrowth: 9,
      angleDeg: -70,
    },
    specials: {
      // la battuta di ping pong: pallina dritta e velocissima, colpo piccolo
      neutral: { type: "projectile", name: "3° campione regionale", startupMs: 180, cooldownMs: 480, speed: 1050, gravity: 0, lifeMs: 700, maxAlive: 1, range: 14, height: 14, damage: 5, baseKnockback: 200, knockbackGrowth: 3.5, angleDeg: 25, color: 0xf4f1e8 },
      // il tuffo del portiere, lungo e basso
      side: { type: "dash", name: "Tuffo", startupMs: 140, durationMs: 300, speed: 880, endLagMs: 380, range: 50, height: 40, damage: 10, baseKnockback: 380, knockbackGrowth: 8, angleDeg: 30, boxY: -50 },
      // si scola una Monster mentre para, e risponde carico
      down: { type: "counter", name: "Monster", startupMs: 60, windowMs: 380, endLagMs: 460, minDamage: 9, multiplier: 1.4, range: 60, height: 60, baseKnockback: 460, knockbackGrowth: 9, angleDeg: 40 },
    },
  },

  // Giovanni: bradipo giallo piccoletto, casinista e chiacchierone, suona il basso (anche #335: saltatore, #f5c211).
  // Il disegno è il foglio delle pose di @Marcomunista in #335, una posa per stato (due per la corsa), ritagliate da
  // tools/sprite/foglio_a_colori.py come per Egiainuso (sheetSprite)
  bradipo: {
    id: "bradipo",
    strikeColor: "#ffd84a", // scia dei colpi: giallo come il bradipo (#384)
    name: "Bradipo Giallo",
    crews: ["lolhardcore"],
    // la Bassline col basso a tracolla: tools/sprite/bradipo_bassline.py
    sprite: sheetSprite("bradipo", 298, 200, 185, { specialSide: { fps: 1, loop: false } }),
    // dalla scheda: "DEMACIAAA", gira come Garen e fa danno a chi tocca (#358). Nel foglio è la palla della Final Smash
    supreme: {
      type: "spin",
      name: "DEMACIAAA",
      windupMs: 150,
      durationMs: 1800,
      hitEveryMs: 225, // 8 colpi
      endLagMs: 300,
      moveSpeed: 0.55,
      width: 130,
      height: 100,
      damage: 3,
      baseKnockback: 200,
      knockbackGrowth: 1.6,
      angleDeg: 60,
    },
    // piccolo e leggero, veloce a terra e in aria, salta tanto
    stats: { weight: 0.95, speed: 1.1, airSpeed: 1.1, jump: 1.1 },
    specials: {
      // spara parole: tante, piccole e deboli, in direzioni "un po' a caso" (angoli fissi a rotazione: la fisica è deterministica)
      neutral: { type: "projectile", name: "Ciacole", startupMs: 150, cooldownMs: 320, speed: 820, gravity: 0, spreadDeg: [0, 14, -8, 22, 6, -14], lifeMs: 600, maxAlive: 3, range: 16, height: 12, damage: 3, baseKnockback: 150, knockbackGrowth: 2.5, angleDeg: 25, color: 0xf5c211 },
      // l'onda del basso: lenta, alta e larga, spinge poco
      side: { type: "projectile", name: "Bassline", startupMs: 240, cooldownMs: 700, speed: 420, gravity: 0, lifeMs: 1000, maxAlive: 1, range: 26, height: 70, damage: 5, baseKnockback: 260, knockbackGrowth: 3, angleDeg: 20, color: 0xb48cff },
      down: { type: "counter", name: "Cambio pannolino", startupMs: 50, windowMs: 400, endLagMs: 450, minDamage: 8, multiplier: 1.3, range: 60, height: 60, baseKnockback: 450, knockbackGrowth: 9, angleDeg: 40 },
    },
  },

  // Riccardo: spilungone calciatore, bonaccione e svampito, occhiali e capelli a tendina
  giovannifrana: {
    id: "giovannifrana",
    name: "Giovanni fRana",
    crews: ["cuamm", "cologna"],
    sprite: communitySprite("giovannifrana"),
    // dalla scheda: "Ramarro, sorprendimi". Cade un ramarro gigante appeso per la coda, poi scappa via
    supreme: communityDrop("giovannifrana", "ramarro", "Ramarro"),
    // dalla scheda: pesante e veloce a terra, ma salta poco e cade presto
    stats: { weight: 1.1, speed: 1.1, airSpeed: 0.9, jump: 0.9, gravity: 1.05 },
    specials: {
      // il pallone calciato, con un po' di parabola
      neutral: { type: "projectile", name: "Rigore", startupMs: 240, cooldownMs: 620, speed: 780, gravity: 700, lift: 180, lifeMs: 1200, maxAlive: 1, range: 22, height: 22, damage: 8, baseKnockback: 280, knockbackGrowth: 4, angleDeg: 40, color: 0xffffff },
      // TODO community: la scheda non la dice, una scivolata da calciatore
      side: { type: "dash", name: "Scivolata", startupMs: 120, durationMs: 320, speed: 820, endLagMs: 400, range: 56, height: 28, damage: 9, baseKnockback: 340, knockbackGrowth: 8, angleDeg: 60, boxY: -30 },
      down: { type: "counter", name: "RitTURD", startupMs: 60, windowMs: 400, endLagMs: 480, minDamage: 8, multiplier: 1.3, range: 60, height: 60, baseKnockback: 450, knockbackGrowth: 9, angleDeg: 40 },
    },
  },

  // Marco: "Viva il comunismo", felpa, occhiali, barba e pelato (Egiainuso viene dal suo foglio delle pose, #178)
  marcomunista: {
    id: "marcomunista",
    strikeColor: "#c9a7f0", // scia dei colpi: lilla come lui (#384)
    name: "Marcomunista",
    quotes: { taunt: "Viva il comunismo!" }, // il suo tormentone; la scheda e la #352 non dicono altro
    crews: ["cuamm", "cologna"],
    // Il disegno è il suo foglio delle pose in #352, ritagliato da tools/sprite/foglio_a_colori.py come Bradipo Giallo
    sprite: sheetSprite("marcomunista", 304, 196, 182),
    // dalla scheda: corsa non molto, aria e salto abbastanza, leggero, gravità bassa (la #352 dà lo stile del disegno, non i numeri)
    stats: { weight: 0.95, speed: 0.95, airSpeed: 1.05, jump: 1.05, gravity: 0.95 },
    // dalla scheda: "…COSA?", torna a com'era 3 secondi prima e stordisce chi è vicino (#358)
    supreme: { type: "rewind", name: "…COSA?", windupMs: 500, backMs: 3000, endLagMs: 300, stunRadius: 150, stunMs: 1200 },
    specials: {
      // gira una canna mentre para; tiro e scatto restano quelli di base finché la scheda non li dice
      down: { type: "counter", name: "Rolling", startupMs: 60, windowMs: 420, endLagMs: 460, minDamage: 8, multiplier: 1.3, range: 60, height: 60, baseKnockback: 440, knockbackGrowth: 9, angleDeg: 40 },
    },
  },

  // Michele: magro, un po' emo, iroso e indisposto
  lendmar: {
    id: "lendmar",
    name: "Lendmar",
    crews: ["lolhardcore"],
    sprite: communitySprite("lendmar"),
    // TODO community: la scheda non ha statistiche; magro, quindi leggero e scattante
    stats: { weight: 0.95, speed: 1.05 },
    // dalla scheda: "IRA", si arrabbia e tira merda scivolosa da tutte le parti (#358): tre raffiche della sua speciale neutra, e dove cade restano pozze
    supreme: { type: "burst", name: "IRA", windupMs: 350, waves: 3, waveEveryMs: 260, count: 6, speed: 560, lift: 820, endLagMs: 400, slick: true },
    specials: {
      // lancia merda ad arco
      neutral: { type: "projectile", name: "Fai schifo", startupMs: 230, cooldownMs: 600, speed: 540, gravity: 1800, lift: 540, lifeMs: 1400, maxAlive: 1, range: 24, height: 18, damage: 7, baseKnockback: 230, knockbackGrowth: 3.5, angleDeg: 50, color: 0x6b4a2b },
      // si arrabbia e si getta in avanti: forte ma lascia scoperti
      side: { type: "dash", name: "Burnout", startupMs: 180, durationMs: 300, speed: 950, endLagMs: 460, range: 46, height: 50, damage: 12, baseKnockback: 420, knockbackGrowth: 9, angleDeg: 35 },
    },
  },

  // Gio (@elvedeo): chirurgo traumatologo rasta infettato dai funghi, "vi insegnerò la via del fungo"
  drmicelium: {
    id: "drmicelium",
    strikeColor: "#a8c46b", // scia dei colpi: verde spora (#384)
    name: "Dr. Micelium",
    quotes: { taunt: "Vi insegnerò la via del fungo" },
    crews: ["cuamm"],
    sprite: communitySprite("drmicelium"),
    // tutto nella media: le statistiche restano quelle di Bonobot
    // dalla scheda: "filo di Kirschner", infetta e rallenta il nemico e lui diventa più forte (#358)
    supreme: { type: "infect", name: "Filo di Kirschner", windupMs: 220, activeMs: 200, endLagMs: 380, reach: 340, height: 18, damage: 10, baseKnockback: 200, knockbackGrowth: 3, angleDeg: 30 },
    specials: {
      // un tiro di canna e il fumo infetto: lento, corto, poco danno
      neutral: { type: "projectile", name: "Fumo infetto", startupMs: 260, cooldownMs: 600, speed: 300, gravity: 0, lifeMs: 800, maxAlive: 1, range: 40, height: 36, damage: 4, baseKnockback: 140, knockbackGrowth: 2.5, angleDeg: 25, color: 0xc9a27a },
      // il bisturi sporco di sangue: dritto e veloce
      side: { type: "projectile", name: "Bisturi", startupMs: 200, cooldownMs: 560, speed: 1000, gravity: 0, lifeMs: 650, maxAlive: 1, range: 20, height: 8, damage: 7, baseKnockback: 240, knockbackGrowth: 4, angleDeg: 25, color: 0xd23b3b },
      // la scoreggia di spore: la nube colpisce tutto intorno, davanti e dietro (rettangolo centrato su di lui)
      down: { type: "charge", name: "Nube di spore", minMs: 200, maxMs: 1000, maxMultiplier: 1.6, activeMs: 160, endLagMs: 420, range: 130, height: 80, boxX: -65, boxY: -80, damage: 8, baseKnockback: 360, knockbackGrowth: 8, angleDeg: 70 },
    },
  },

  // Griga (KittySeanKula): l'allenatore con la lavagnetta, le collane d'oro e la tuta verde e gialla
  coachcartier: {
    id: "coachcartier",
    name: "Coach Cartier",
    quotes: { taunt: "Va bene perdere se sei ricco!" },
    crews: ["cuamm", "cologna"], // dal LORE
    sprite: communitySprite("coachcartier"),
    // dalla scheda c'è solo il nome, "MVP": cade il trofeo di MVP e dopo il puff scappa una moneta (il cashback)
    supreme: communityDrop("coachcartier", "mvp", "MVP"),
    // dalla scheda: velocissimo a terra, lento in aria
    stats: { speed: 1.2, airSpeed: 0.8, jump: 0.95, gravity: 0.95 },
    specials: {
      // fa ruotare la collana d'oro e colpisce tutto intorno al rilascio
      neutral: { type: "charge", name: "Cashback", minMs: 200, maxMs: 1100, maxMultiplier: 1.8, activeMs: 500, endLagMs: 400, range: 120, height: 70, boxX: -60, boxY: -76, damage: 9, baseKnockback: 380, knockbackGrowth: 9, angleDeg: 45 },
      // lancia la lavagnetta
      side: { type: "projectile", name: "Corri!", startupMs: 200, cooldownMs: 560, speed: 820, gravity: 0, lifeMs: 800, maxAlive: 1, range: 26, height: 20, damage: 7, baseKnockback: 260, knockbackGrowth: 4, angleDeg: 30, color: 0x2f6b3a },
      // urla e allontana: risposta debole ma che spinge lontano
      down: { type: "counter", name: "Mahmmoney", startupMs: 60, windowMs: 400, endLagMs: 460, minDamage: 6, multiplier: 1.1, range: 80, height: 70, baseKnockback: 560, knockbackGrowth: 10, angleDeg: 35 },
    },
  },

  // Inventata da Claude per Nicola (#384): la nonna di Cologna Veneta che alla domenica dà da mangiare a tutto il
  // Cuamm. Primo personaggio fatto per intero col flusso di #384: scheda in docs/mosse/nonnagina.md, colpi normali
  // propri (attacks) e animazioni sue col mattarello (tools/rig/animazioni_nonnagina.py)
  nonnagina: {
    id: "nonnagina",
    name: "Nonna Gina",
    strikeColor: "#e0ae74", // scia dei colpi: il legno del mattarello
    quotes: { taunt: "Mangia che ti fa bene!", ko: "Ostrega!", victory: "Ti go fato el brodo" },
    crews: ["cologna"],
    sprite: {
      ...communitySprite("nonnagina"),
      frameWidth: 400, // più largo: il mattarello arriva lontano
      rig: "assets/characters/nonnagina/rig", // la prova del rig in tempo reale (#403)
      animations: fromRest({
        ...communitySprite("nonnagina").animations,
        walk: { fps: 24, loop: true }, // passi corti e curvi
        specialSide: { fps: 24, loop: false, hitFrame: 4 }, // la ciabatta parte dalla mano
        supreme: { fps: 24, loop: false }, // tre bracciate di polpette
      }),
    },
    // pesante e lenta a terra, salta poco ma cade piano: non la sposti facilmente
    stats: { weight: 1.15, speed: 0.85, airSpeed: 0.95, jump: 0.9, gravity: 0.95 },
    // i colpi normali col mattarello (#384 D2): più lunghi e un po' più lenti di quelli di tutti
    attacks: {
      light: { damage: 6, startupMs: 50, range: 64 }, // botta di punta
      heavy: { damage: 15, baseKnockback: 450, startupMs: 320, cooldownMs: 860, range: 84, height: 54 }, // mattarellata a due mani
      heavyDown: { damage: 13, startupMs: 280, range: 104 }, // il mattarello rotolato radente
    },
    // dalla scheda: "Pranzo della domenica", tre bracciate di polpette da tutte e due le parti
    supreme: { type: "burst", name: "Pranzo della domenica", windupMs: 300, waves: 3, waveEveryMs: 260, count: 5, speed: 520, lift: 760, endLagMs: 420 },
    specials: {
      // la polpetta, lanciata ad arco dal basso
      neutral: { type: "projectile", name: "Polpetta", startupMs: 220, cooldownMs: 560, speed: 620, gravity: 1500, lift: 420, lifeMs: 1300, maxAlive: 2, range: 20, height: 20, damage: 7, baseKnockback: 240, knockbackGrowth: 4, angleDeg: 45, color: 0x8a4b2a },
      // la ciabatta: dritta, veloce e precisa, come quella delle nonne vere
      side: { type: "projectile", name: "Ciabatta", startupMs: 180, cooldownMs: 600, speed: 980, gravity: 0, lifeMs: 700, maxAlive: 1, range: 30, height: 14, damage: 9, baseKnockback: 300, knockbackGrowth: 5, angleDeg: 30, color: 0x9c3b2e },
      // "Mangia!": para col mattarello di traverso e risponde con una botta che allontana
      down: { type: "counter", name: "Mangia!", startupMs: 60, windowMs: 400, endLagMs: 480, minDamage: 8, multiplier: 1.3, range: 70, height: 60, baseKnockback: 480, knockbackGrowth: 9, angleDeg: 38 },
    },
  },
};

// Un id sconosciuto (o mancante) diventa il personaggio base
export function getCharacter(id: string | undefined): CharacterSpec {
  return (id && Object.hasOwn(CHARACTERS, id) && CHARACTERS[id]) || CHARACTERS[DEFAULT_CHARACTER_ID];
}

// La skin chiesta, se quel lottatore ce l'ha; altrimenti nessuna (l'aspetto base). Arriva dalla rete: non ci si fida
export function skinFor(characterId: string | undefined, skinId: string | undefined): string | undefined {
  const skins = getCharacter(characterId).skins;
  return skinId && skins && Object.hasOwn(skins, skinId) ? skinId : undefined;
}

// Le statistiche di un personaggio, quelle che mancano a 1 e tutte dentro i limiti
const statsCache = new Map<string, CharacterStats>();
export function characterStats(id: string | undefined): CharacterStats {
  const c = getCharacter(id);
  let stats = statsCache.get(c.id);
  if (!stats) {
    const clamp = (v: number | undefined) => Math.min(CHARACTER_STATS.max, Math.max(CHARACTER_STATS.min, v ?? 1));
    const s = c.stats ?? {};
    stats = { speed: clamp(s.speed), airSpeed: clamp(s.airSpeed), jump: clamp(s.jump), weight: clamp(s.weight), gravity: clamp(s.gravity) };
    statsCache.set(c.id, stats);
  }
  return stats;
}

// Da speciale a numeri di un attacco (E10), per la fisica e per Godot: avvio, finestra attiva, attesa totale
// (cooldownMs) e il colpo. Per il contrattacco la finestra è quella in cui para, e il danno è quello minimo
export const SPECIAL_KINDS: Record<SpecialSlot, SpecialKind> = { neutral: "specialNeutral", side: "specialSide", down: "specialDown" };
export function specialAttackSpec(sp: SpecialSpec): AttackSpec {
  const hit = { baseKnockback: sp.baseKnockback, knockbackGrowth: sp.knockbackGrowth, angleDeg: sp.angleDeg, range: sp.range, height: sp.height, boxX: sp.boxX, boxY: sp.boxY };
  switch (sp.type) {
    case "dash":
      return { ...hit, damage: sp.damage, startupMs: sp.startupMs, activeMs: sp.durationMs, cooldownMs: sp.startupMs + sp.durationMs + sp.endLagMs };
    case "counter":
      return { ...hit, damage: sp.minDamage, startupMs: sp.startupMs, activeMs: sp.windowMs, cooldownMs: sp.startupMs + sp.windowMs + sp.endLagMs };
    case "projectile":
      // Niente rettangolo davanti a chi tira: colpisce il proiettile (projectiles.ts), che parte a fine avvio
      return { ...hit, damage: sp.damage, startupMs: sp.startupMs, activeMs: 0, cooldownMs: sp.cooldownMs };
    case "charge":
      return { ...hit, damage: sp.damage, startupMs: sp.minMs, activeMs: sp.activeMs, cooldownMs: sp.maxMs + sp.activeMs + sp.endLagMs };
  }
}

// La suprema propria letta come un attacco (#102), per la fisica e per Godot. Avvio: salto, tirata e ombra;
// finestra attiva: l'impatto; attesa totale: fino alla fine del puff. Il rettangolo è centrato sulla liana
// (attackBox in attacks.ts lo sposta lì). Senza suprema propria, null
const supremeCache = new Map<string, AttackSpec | null>(); // la fisica la legge a ogni tick
export function supremeAttackSpec(id: string | undefined): AttackSpec | null {
  const c = getCharacter(id);
  if (!supremeCache.has(c.id)) supremeCache.set(c.id, toSupremeAttack(c.supreme));
  return supremeCache.get(c.id) ?? null;
}
function toSupremeAttack(sp: SupremeSpec | undefined): AttackSpec | null {
  if (!sp) return null;
  if (sp.type === "rewind") {
    // niente colpo: torna indietro e stordisce (stepRewinds in physics/supreme.ts)
    return { damage: 0, baseKnockback: 0, knockbackGrowth: 0, angleDeg: 0, startupMs: sp.windupMs, activeMs: 100, cooldownMs: sp.windupMs + 100 + sp.endLagMs, range: 0, height: 0 };
  }
  if (sp.type === "burst") {
    // niente colpo corpo a corpo: colpiscono i proiettili (supremeMelee in physics/supreme.ts)
    const activeMs = sp.waves * sp.waveEveryMs;
    return { damage: 0, baseKnockback: 0, knockbackGrowth: 0, angleDeg: 0, startupMs: sp.windupMs, activeMs, cooldownMs: sp.windupMs + activeMs + sp.endLagMs, range: 0, height: 0 };
  }
  if (sp.type === "infect") {
    return {
      damage: sp.damage,
      baseKnockback: sp.baseKnockback,
      knockbackGrowth: sp.knockbackGrowth,
      angleDeg: sp.angleDeg,
      startupMs: sp.windupMs,
      activeMs: sp.activeMs,
      cooldownMs: sp.windupMs + sp.activeMs + sp.endLagMs,
      range: sp.reach,
      height: sp.height,
      boxY: -FIGHTER.height * 0.6, // all'altezza del petto
    };
  }
  if (sp.type === "grab") {
    return {
      damage: sp.damage,
      baseKnockback: sp.baseKnockback,
      knockbackGrowth: sp.knockbackGrowth,
      angleDeg: sp.angleDeg,
      startupMs: sp.windupMs,
      activeMs: sp.reachMs,
      cooldownMs: sp.windupMs + sp.reachMs + sp.endLagMs,
      range: sp.reach,
      height: sp.height,
    };
  }
  if (sp.type === "spin") {
    return {
      damage: sp.damage,
      baseKnockback: sp.baseKnockback,
      knockbackGrowth: sp.knockbackGrowth,
      angleDeg: sp.angleDeg,
      startupMs: sp.windupMs,
      activeMs: sp.durationMs,
      cooldownMs: sp.windupMs + sp.durationMs + sp.endLagMs,
      range: sp.width,
      height: sp.height,
      boxX: -sp.width / 2, // tutto intorno
      boxY: -sp.height + 8,
      outward: true,
    };
  }
  const startupMs = sp.leapMs + sp.pullMs + sp.warnMs;
  return {
    damage: sp.damage,
    baseKnockback: sp.baseKnockback,
    knockbackGrowth: sp.knockbackGrowth,
    angleDeg: sp.angleDeg,
    startupMs,
    activeMs: sp.impactMs,
    cooldownMs: startupMs + sp.impactMs + sp.recoverMs,
    range: sp.width,
    height: sp.height,
    boxX: -sp.width / 2, // centrata sulla liana
    boxY: -sp.height + 10, // fin sotto il terreno: prende anche chi è un po' più in basso
    outward: true,
  };
}

// Le tre speciali di un personaggio: le sue, e per quelle che mancano DEFAULT_SPECIALS.
// La fisica la chiede più volte per lottatore a ogni tick: l'insieme si compone una volta per personaggio
const specialSets = new WeakMap<CharacterSpec, SpecialSet>();
export function specialsFor(id: string | undefined): SpecialSet {
  const c = getCharacter(id);
  let set = specialSets.get(c);
  if (!set) {
    set = Object.freeze({ ...DEFAULT_SPECIALS, ...c.specials });
    specialSets.set(c, set);
  }
  return set;
}
