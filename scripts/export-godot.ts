// Esporta in JSON i dati del gioco che servono al client Godot (godot/data/game.json):
// arene, personaggi e numeri. Così Godot li legge invece di ricopiarli a mano.
// Copia anche gli spritesheet dei personaggi in godot/data/<path>, perché Godot vede solo la sua cartella.
// Da rilanciare quando cambiano stages.ts, characters.ts o constants.ts: npm run export:godot

import { copyFileSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { CHARACTERS, DEFAULT_CHARACTER_ID } from "../src/shared/characters";
import { ATTACKS, AUDIO, CAMERA, COLORS, FIGHTER, NET, TEAM_COLORS, TEAM_NAMES, WORLD } from "../src/shared/constants";
import { DEFAULT_STAGE_ID, STAGES } from "../src/shared/stages";

const data = {
  world: WORLD,
  fighter: { width: FIGHTER.width, height: FIGHTER.height },
  attacks: ATTACKS,
  net: NET,
  audio: AUDIO,
  camera: CAMERA,
  colors: COLORS,
  teamColors: TEAM_COLORS,
  teamNames: TEAM_NAMES,
  defaultStageId: DEFAULT_STAGE_ID,
  stages: STAGES,
  defaultCharacterId: DEFAULT_CHARACTER_ID,
  characters: CHARACTERS,
};

const out = new URL("../godot/data/game.json", import.meta.url);
writeFileSync(out, JSON.stringify(data, null, 2) + "\n");
console.log(`Scritto ${out.pathname}`);

for (const c of Object.values(CHARACTERS)) {
  if (!c.sprite) continue;
  const from = fileURLToPath(new URL(`../public/${c.sprite.path}`, import.meta.url));
  const to = fileURLToPath(new URL(`../godot/data/${c.sprite.path}`, import.meta.url));
  mkdirSync(dirname(to), { recursive: true });
  copyFileSync(from, to);
  console.log(`Copiato ${c.sprite.path}`);
}
