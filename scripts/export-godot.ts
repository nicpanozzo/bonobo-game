// Esporta in JSON i dati del gioco che servono al client Godot (godot/data/game.json):
// arene, personaggi e numeri. Così Godot li legge invece di ricopiarli a mano.
// Da rilanciare quando cambiano stages.ts, characters.ts o constants.ts: npm run export:godot

import { writeFileSync } from "node:fs";
import { CHARACTERS, DEFAULT_CHARACTER_ID } from "../src/shared/characters";
import { ATTACKS, COLORS, FIGHTER, NET, TEAM_COLORS, TEAM_NAMES, WORLD } from "../src/shared/constants";
import { DEFAULT_STAGE_ID, STAGES } from "../src/shared/stages";

const data = {
  world: WORLD,
  fighter: { width: FIGHTER.width, height: FIGHTER.height },
  attacks: ATTACKS,
  net: NET,
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
