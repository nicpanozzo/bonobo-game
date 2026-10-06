// I personaggi giocabili. Aggiungerne uno = un blocco qui e una cartella in public/assets/characters/<id>/.
// Per ora cambiano solo l'aspetto: statistiche e mosse proprie arrivano con il passo 1 di #13.

export type AnimationName = "idle" | "walk" | "jump" | "fall" | "light" | "heavy" | "hit";

export interface SpriteSheetSpec {
  path: string; // relativo alla radice del sito
  frameWidth: number; // pixel
  frameHeight: number;
  columns: number; // fotogrammi per riga nel PNG
  // Riga del PNG, numero di fotogrammi e velocità di ogni animazione (fotogrammi/s)
  animations: Record<AnimationName, { row: number; frames: number; fps: number; loop: boolean }>;
}

export interface CharacterSpec {
  id: string;
  name: string;
  sprite?: SpriteSheetSpec; // senza sprite si disegna il rettangolo colorato
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
};

// Un id sconosciuto (o mancante) diventa il personaggio base
export function getCharacter(id: string | undefined): CharacterSpec {
  return (id && Object.hasOwn(CHARACTERS, id) && CHARACTERS[id]) || CHARACTERS[DEFAULT_CHARACTER_ID];
}
