// Esporta in JSON i dati del gioco che servono al client Godot (godot/data/game.json):
// arene, personaggi e numeri. Così Godot li legge invece di ricopiarli a mano.
// Copia anche gli spritesheet dei personaggi in godot/data/<path>, perché Godot vede solo la sua cartella.
// Da rilanciare quando cambiano stages.ts, characters.ts o constants.ts: npm run export:godot

import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, extname } from "node:path";
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

// Audio registrato (E13): public/assets/{sfx,music,announcer}/<nome>_<n>.ogg e characters/<id>/voice/.
// Si copia in godot/data/assets e l'elenco va in game.json (audioFiles), perché Godot non elenca bene
// le cartelle dentro il gioco esportato. Senza file per un suono, Godot usa quello sintetizzato.
const AUDIO_EXT = new Set([".ogg", ".wav"]);
const publicDir = fileURLToPath(new URL("../public/", import.meta.url));
const godotData = fileURLToPath(new URL("../godot/data/", import.meta.url));

// I file audio di una cartella raggruppati per nome: hitHeavy_1.ogg e hitHeavy_2.ogg sono varianti di hitHeavy
function audioGroup(dir: string): Record<string, string[]> {
  const groups: Record<string, string[]> = {};
  const abs = publicDir + dir;
  if (!existsSync(abs)) return groups;
  for (const file of readdirSync(abs).sort()) {
    if (!AUDIO_EXT.has(extname(file))) continue;
    const name = basename(file, extname(file)).replace(/_\d+$/, "");
    (groups[name] ??= []).push(`${dir}/${file}`);
  }
  return groups;
}

const voices: Record<string, Record<string, string[]>> = {};
for (const id of existsSync(publicDir + "assets/characters") ? readdirSync(publicDir + "assets/characters") : []) {
  const group = audioGroup(`assets/characters/${id}/voice`);
  if (Object.keys(group).length) voices[id] = group;
}
const audioFiles = { sfx: audioGroup("assets/sfx"), music: audioGroup("assets/music"), announcer: audioGroup("assets/announcer"), voices };

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
  audioFiles,
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

// I file audio: la cartella di destinazione si rifà da zero, così un file tolto sparisce anche da Godot
for (const dir of ["assets/sfx", "assets/music", "assets/announcer"]) rmSync(godotData + dir, { recursive: true, force: true });
for (const group of [audioFiles.sfx, audioFiles.music, audioFiles.announcer, ...Object.values(voices)]) {
  for (const path of Object.values(group).flat()) {
    mkdirSync(dirname(godotData + path), { recursive: true });
    copyFileSync(publicDir + path, godotData + path);
    console.log(`Copiato ${path}`);
  }
}
