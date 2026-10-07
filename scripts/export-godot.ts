// Esporta in JSON i dati del gioco che servono al client Godot (godot/data/game.json):
// arene, personaggi e numeri. Così Godot li legge invece di ricopiarli a mano.
// Copia anche gli spritesheet dei personaggi in godot/data/<path>, perché Godot vede solo la sua cartella.
// Da rilanciare quando cambiano stages.ts, characters.ts o constants.ts: npm run export:godot

import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { CHARACTERS, DEFAULT_CHARACTER_ID } from "../src/shared/characters";
import { ATTACKS, AUDIO, CAMERA, COLORS, EFFECTS, FIGHTER, INPUT, ITEM_RULES, LEDGE, NET, PROTOCOL_VERSION, RUMBLE, SHIELD, TEAM_COLORS, TEAM_NAMES, WORLD } from "../src/shared/constants";
import { RECONNECT, RECONNECT_HOLD_MS } from "../src/shared/constants";
import { COLORS_COLORBLIND, TEAM_COLORS_COLORBLIND } from "../src/shared/constants";
import { ITEMS } from "../src/shared/items";
import { DEFAULT_STAGE_ID, STAGES } from "../src/shared/stages";
import { stageCheckData } from "../src/shared/stageCheck";

// La versione del gioco ha una fonte sola, package.json (E2, #106)
const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as { version: string };

const data = {
  version: pkg.version,
  protocol: PROTOCOL_VERSION,
  world: WORLD,
  fighter: { width: FIGHTER.width, height: FIGHTER.height },
  attacks: ATTACKS,
  ledge: { hangOffsetY: LEDGE.hangOffsetY }, // bordo del palco (#110): dove sta la mano di chi è appeso
  shield: { maxHp: SHIELD.maxHp }, // scudo (#109): la bolla è grande in proporzione ai punti rimasti
  stageCheck: stageCheckData(), // altezze di salto per il controllo delle arene nell'editor (E12)
  net: NET,
  reconnect: { ...RECONNECT, holdMs: RECONNECT_HOLD_MS }, // riconnessione dopo un calo di rete (#107)
  audio: AUDIO,
  input: INPUT,
  rumble: RUMBLE,
  camera: CAMERA,
  effects: EFFECTS,
  items: ITEMS,
  itemRules: ITEM_RULES,
  colors: COLORS,
  teamColors: TEAM_COLORS,
  colorsColorblind: COLORS_COLORBLIND,
  teamColorsColorblind: TEAM_COLORS_COLORBLIND,
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
