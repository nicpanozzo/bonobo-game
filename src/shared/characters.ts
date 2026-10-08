// I personaggi giocabili. Aggiungerne uno = un blocco qui e una cartella in public/assets/characters/<id>/.
// Cambiano aspetto e statistiche (E11 passo B); le mosse proprie arrivano con le speciali (E10).

import { CHARACTER_STATS, DEFAULT_SPECIALS, RECOVERY, type AttackSpec } from "./constants";
import type { SpecialKind } from "./types";

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
  "supreme", // suprema (#101)
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
  recovery: "jump",
  taunt: "idle",
  shield: "idle",
  grab: "light", // presa e chi tiene (#109)
  throw: "grab", // i quattro lanci
  grabbed: "hit", // chi è tenuto
  special: "heavy",
  supreme: "special", // senza disegno, la posa della speciale (e poi del pesante)
};

export interface SpriteAnimation {
  row: number;
  frames: number;
  fps: number;
  loop: boolean;
  hitFrame?: number; // solo negli attacchi, vedi SpriteStateSpec
}

// Formato a foglio unico: un PNG con una riga per animazione (Egiainuso, Bonobot)
export interface SpriteSheetSpec {
  path: string; // relativo alla radice del sito
  frameWidth: number; // pixel
  frameHeight: number;
  columns: number; // fotogrammi per riga nel PNG
  scale?: number; // grandezza a schermo rispetto al PNG: 0.5 per i disegni fatti a 2x (manca = 1)
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
}
export interface SpriteFolderSpec {
  dir: string; // cartella relativa alla radice del sito, es. "assets/characters/<id>"
  frameWidth: number; // pixel, uguale in tutti i PNG
  frameHeight: number;
  scale?: number; // come in SpriteSheetSpec: 0.5 per i disegni fatti a 2x
  filter?: SpriteFilter;
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
  lifeMs: number; // dopo quanto sparisce da solo
  maxAlive: number; // proiettili dello stesso giocatore in volo insieme
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
export type SpecialSpec = ProjectileSpecial | DashSpecial | ChargeSpecial | CounterSpecial;
export type SpecialSet = Record<SpecialSlot, SpecialSpec>;

export interface CharacterSpec {
  id: string;
  name: string;
  sprite?: SpriteSheetSpec | SpriteFolderSpec; // senza sprite si disegna il rettangolo colorato
  stats?: Partial<CharacterStats>; // quelle che mancano valgono 1
  specials?: Partial<SpecialSet>; // quelle che mancano sono DEFAULT_SPECIALS (E10)
  recovery?: Partial<AttackSpec & typeof RECOVERY>; // numeri propri del recupero (#11): quelli che mancano restano i soliti
}

export const DEFAULT_CHARACTER_ID = "default";

export const CHARACTERS: Record<string, CharacterSpec> = {
  default: {
    id: "default",
    name: "Bonobo",
  },

  // Creatura blu sulla barchetta col remo, proposta da @MauroGrecchi (#37)
  egiainuso: {
    id: "egiainuso",
    name: "Egiainuso",
    // Con la barchetta addosso è un po' più pesante e lento di Bonobot (E11)
    // TODO community: statistiche provvisorie, da confermare con @MauroGrecchi
    stats: { weight: 1.05, speed: 0.9, airSpeed: 0.95, jump: 0.95 },
    sprite: {
      path: "assets/characters/egiainuso/egiainuso.png",
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
    sprite: {
      path: "assets/characters/bonobot/bonobot.png",
      frameWidth: 256,
      frameHeight: 240,
      columns: 24,
      scale: 0.5,
      animations: {
        idle: { row: 0, frames: 24, fps: 12, loop: true }, // respiro e peso che si sposta, 2 s
        walk: { row: 1, frames: 10, fps: 24, loop: true }, // galoppo sulle nocche alla velocità di groundSpeed
        jump: { row: 2, frames: 7, fps: 24, loop: false },
        fall: { row: 3, frames: 12, fps: 24, loop: true },
        light: { row: 4, frames: 7, fps: 24, loop: false, hitFrame: 1 }, // schiaffo di rovescio: colpisce nei fotogrammi 2-4
        heavy: { row: 5, frames: 18, fps: 24, loop: false, hitFrame: 6 }, // martello a due pugni: colpisce nei fotogrammi 7-10
        hit: { row: 6, frames: 8, fps: 24, loop: false },
        doubleJump: { row: 7, frames: 9, fps: 24, loop: false }, // capriola in avanti che si apre verso la caduta
        tumble: { row: 8, frames: 12, fps: 24, loop: true }, // rotola all'indietro quando vola via dopo un colpo forte
        ledge: { row: 9, frames: 24, fps: 12, loop: true }, // appeso allo spigolo, piedi contro la parete, dondola piano
        climb: { row: 10, frames: 10, fps: 24, loop: false }, // si tira su e torna in piedi in LEDGE.climbMs
      },
    },
  },
};

// Un id sconosciuto (o mancante) diventa il personaggio base
export function getCharacter(id: string | undefined): CharacterSpec {
  return (id && Object.hasOwn(CHARACTERS, id) && CHARACTERS[id]) || CHARACTERS[DEFAULT_CHARACTER_ID];
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
      return { ...hit, damage: sp.damage, startupMs: sp.startupMs, activeMs: sp.lifeMs, cooldownMs: sp.cooldownMs };
    case "charge":
      return { ...hit, damage: sp.damage, startupMs: sp.minMs, activeMs: sp.activeMs, cooldownMs: sp.maxMs + sp.activeMs + sp.endLagMs };
  }
}

// Le tre speciali di un personaggio: le sue, e per quelle che mancano DEFAULT_SPECIALS
export function specialsFor(id: string | undefined): SpecialSet {
  return { ...DEFAULT_SPECIALS, ...getCharacter(id).specials };
}
