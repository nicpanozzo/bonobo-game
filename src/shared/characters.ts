// I personaggi giocabili. Aggiungerne uno = un blocco qui e una cartella in public/assets/characters/<id>/.
// Cambiano aspetto e statistiche (E11 passo B); le mosse proprie arrivano con le speciali (E10).

import { CHARACTER_STATS } from "./constants";

// Gli stati che ogni lottatore con sprite deve avere
export const ANIMATION_NAMES = ["idle", "walk", "jump", "fall", "light", "heavy", "hit"] as const;
export type AnimationName = (typeof ANIMATION_NAMES)[number];
// Animazioni facoltative (#103): chi non le ha usa al loro posto jump (doppio salto) e hit (lanciato);
// per il bordo (#110, #171) appeso e risalita usano jump.
// Gli stati di E7 passo 2 (atterraggio, varianti dei colpi, recupero, provocazione) hanno già il nome;
// shield, grab e special sono posti per E8, E9 ed E10. Finché il passo 3 non porta il ripiego, Godot non li usa.
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
  "special",
] as const;
export type OptionalAnimationName = (typeof OPTIONAL_ANIMATION_NAMES)[number];
export interface SpriteAnimation {
  row: number;
  frames: number;
  fps: number;
  loop: boolean;
}

// Formato a foglio unico: un PNG con una riga per animazione (Egiainuso, Bonobot)
export interface SpriteSheetSpec {
  path: string; // relativo alla radice del sito
  frameWidth: number; // pixel
  frameHeight: number;
  columns: number; // fotogrammi per riga nel PNG
  scale?: number; // grandezza a schermo rispetto al PNG: 0.5 per i disegni fatti a 2x (manca = 1)
  // Riga del PNG, numero di fotogrammi e velocità di ogni animazione (fotogrammi/s)
  animations: Record<AnimationName, SpriteAnimation> & Partial<Record<OptionalAnimationName, SpriteAnimation>>;
}

// Formato cartella (E7 passo 2): un PNG per stato, <dir>/<stato>.png, con i fotogrammi in fila da sinistra.
// Il numero di fotogrammi lo ricava npm run export:godot dalla larghezza del PNG. Guida: public/assets/characters/README.md
export interface SpriteStateSpec {
  fps: number; // fotogrammi al secondo
  loop: boolean; // true = ricomincia, false = si ferma sull'ultimo fotogramma
}
export interface SpriteFolderSpec {
  dir: string; // cartella relativa alla radice del sito, es. "assets/characters/<id>"
  frameWidth: number; // pixel, uguale in tutti i PNG
  frameHeight: number;
  scale?: number; // come in SpriteSheetSpec: 0.5 per i disegni fatti a 2x
  animations: Record<AnimationName, SpriteStateSpec> & Partial<Record<OptionalAnimationName, SpriteStateSpec>>;
}

export function isSpriteFolder(sprite: SpriteSheetSpec | SpriteFolderSpec): sprite is SpriteFolderSpec {
  return "dir" in sprite;
}

// Il PNG di uno stato nel formato cartella
export function spriteStatePath(sprite: SpriteFolderSpec, state: AnimationName | OptionalAnimationName): string {
  return `${sprite.dir}/${state}.png`;
}

// Moltiplicatori dei numeri di FIGHTER (1 = come Bonobot, il metro), tra CHARACTER_STATS.min e max
export interface CharacterStats {
  speed: number; // corsa a terra
  airSpeed: number; // velocità massima in aria
  jump: number; // velocità del salto e del doppio salto
  weight: number; // il knockback dei colpi si divide per questo: più pesante, meno si vola
  gravity: number; // caduta: più alta, si scende prima e si salta meno in alto
}

export interface CharacterSpec {
  id: string;
  name: string;
  sprite?: SpriteSheetSpec | SpriteFolderSpec; // senza sprite si disegna il rettangolo colorato
  stats?: Partial<CharacterStats>; // quelle che mancano valgono 1
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
        light: { row: 4, frames: 7, fps: 24, loop: false }, // schiaffo di rovescio: colpisce nei fotogrammi 2-4
        heavy: { row: 5, frames: 18, fps: 24, loop: false }, // martello a due pugni: colpisce nei fotogrammi 7-10
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
