// I personaggi giocabili. Aggiungerne uno = un blocco qui e una cartella in public/assets/characters/<id>/.
// Cambiano aspetto e statistiche (E11 passo B); le mosse proprie arrivano con le speciali (E10).

import { CHARACTER_STATS, CHARGE_EXAMPLE, DEFAULT_SPECIALS, RECOVERY, type AttackSpec } from "./constants";
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
  "dash", // scatto e corsa dopo il doppio tocco (#199)
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
  dash: "walk", // senza disegno, la camminata (per Bonobot: il galoppo sulle nocche)
  supreme: "special", // senza disegno, la posa della speciale (e poi del pesante)
};

export interface SpriteAnimation {
  row: number;
  frames: number;
  fps: number;
  loop: boolean;
  hitFrame?: number; // solo negli attacchi, vedi SpriteStateSpec
}

// Formato a foglio unico: un PNG con una riga per animazione (Capt. OrsoBlu, Bonobot)
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
  lift?: number; // pixel/s verso l'alto alla partenza, per i tiri ad arco (con gravity)
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
export type SupremeSpec = DropSupreme;

export type SpecialSpec = ProjectileSpecial | DashSpecial | ChargeSpecial | CounterSpecial;
export type SpecialSet = Record<SpecialSlot, SpecialSpec>;

export interface CharacterSpec {
  id: string;
  name: string;
  sprite?: SpriteSheetSpec | SpriteFolderSpec; // senza sprite si disegna il rettangolo colorato
  stats?: Partial<CharacterStats>; // quelle che mancano valgono 1
  specials?: Partial<SpecialSet>; // quelle che mancano sono DEFAULT_SPECIALS (E10)
  supreme?: SupremeSpec; // senza, la suprema di base (ATTACKS.supreme, #101)
  recovery?: Partial<AttackSpec & typeof RECOVERY>; // numeri propri del recupero (#11): quelli che mancano restano i soliti
}

export const DEFAULT_CHARACTER_ID = "default";

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
    // Numeri provvisori dall'issue e da Riccardo (danno 25-30%, area 132 px, dura poco), da rivedere al playtest (#22)
    supreme: {
      type: "drop",
      name: "Omar",
      label: "Omar",
      leapMs: 250,
      leapDx: 60,
      leapDy: 110,
      pullMs: 150,
      warnMs: 500,
      fallMs: 300,
      flipMs: 350,
      flipDx: 130,
      flipArc: 50,
      impactMs: 100,
      recoverMs: 300,
      width: 132,
      height: 150,
      damage: 28,
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

  // Gatto rasta grassottello col bong, proposto da @MauroGrecchi (#168). Provvisorio: è il suo foglio ritagliato
  // e ingrandito, un'eccezione alla style guide come Capt. OrsoBlu (vedi public/assets/characters/elvedeo/README.md).
  elvedeo: {
    id: "elvedeo",
    name: "Elvedeo",
    // Con la pancia è più pesante e un po' lento, salta meno (E11)
    // TODO community: statistiche provvisorie, da confermare con @MauroGrecchi
    stats: { weight: 1.15, speed: 0.85, airSpeed: 0.95, jump: 0.9 },
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

// Le tre speciali di un personaggio: le sue, e per quelle che mancano DEFAULT_SPECIALS
export function specialsFor(id: string | undefined): SpecialSet {
  return { ...DEFAULT_SPECIALS, ...getCharacter(id).specials };
}
