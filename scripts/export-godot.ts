// Esporta in JSON i dati del gioco che servono al client Godot (godot/data/game.json):
// arene, personaggi e numeri. Così Godot li legge invece di ricopiarli a mano.
// Copia anche gli sprite dei personaggi in godot/data/ (foglio unico o un PNG per stato), perché Godot vede solo la sua cartella.
// Da rilanciare quando cambiano stages.ts, characters.ts o constants.ts: npm run export:godot

import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { CHARACTERS, DEFAULT_CHARACTER_ID, isSpriteFolder, resolvedAnimations, SPECIAL_KINDS, SPECIAL_SLOTS, specialAttackSpec, specialsFor, spriteStatePath } from "../src/shared/characters";
import { ATTACKS, AUDIO, CAMERA, COLORS, EFFECTS, FIGHTER, INPUT, ITEM_RULES, LEDGE, NET, PROTOCOL_VERSION, RUMBLE, SHIELD, TEAM_COLORS, TEAM_NAMES, WORLD } from "../src/shared/constants";
import { RECONNECT, RECONNECT_HOLD_MS } from "../src/shared/constants";
import { COLORS_COLORBLIND, TEAM_COLORS_COLORBLIND } from "../src/shared/constants";
import { TRAINING } from "../src/shared/constants";
import { SUPREME } from "../src/shared/constants";
import { LESSONS, TUTORIAL_BOT, TUTORIAL_STAGE_ID } from "../src/shared/tutorial";
import { CHALLENGES } from "../src/shared/challenges";
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

// Larghezza e altezza di un PNG, lette dall'intestazione (IHDR)
function pngSize(file: string): { width: number; height: number } {
  const head = readFileSync(file).subarray(0, 24);
  if (head.toString("latin1", 12, 16) !== "IHDR") throw new Error(`${file} non è un PNG`);
  return { width: head.readUInt32BE(16), height: head.readUInt32BE(20) };
}

// Gli sprite dei personaggi (E7 passo 2). Nel formato cartella ogni stato è un PNG a sé: il numero di
// fotogrammi si ricava dalla larghezza e va in game.json, così Godot non deve aprire i file per saperlo.
const spriteFiles: string[] = [];
const spriteErrors: string[] = [];
const characters: Record<string, unknown> = {};
for (const [id, spec] of Object.entries(CHARACTERS)) {
  // Le speciali (E10) arrivano già complete: le sue e, per quelle che mancano, DEFAULT_SPECIALS
  // specialAttacks: le stesse speciali lette come attacchi (specialAttackSpec), per disegnare il colpo in Godot
  const specials = specialsFor(id);
  const specialAttacks = Object.fromEntries(SPECIAL_SLOTS.map((slot) => [SPECIAL_KINDS[slot], specialAttackSpec(specials[slot])]));
  const c = { ...spec, specials, specialAttacks };
  characters[id] = c;
  if (!c.sprite) continue;
  // In game.json ogni stato c'è, con i dati del disegno che lo mostra (src): il ripiego si decide qui,
  // una volta sola, e Godot non controlla cosa manca (E7 passo 3)
  if (!isSpriteFolder(c.sprite)) {
    spriteFiles.push(c.sprite.path);
    characters[id] = { ...c, sprite: { ...c.sprite, animations: resolvedAnimations(c.sprite.animations) } };
    continue;
  }
  const sprite = c.sprite;
  const animations: Record<string, object> = {};
  for (const [state, a] of Object.entries(sprite.animations)) {
    const path = spriteStatePath(sprite, state as keyof typeof sprite.animations);
    if (!existsSync(publicDir + path)) {
      spriteErrors.push(`${id}: manca public/${path} (lo stato "${state}" è nel blocco del personaggio)`);
      continue;
    }
    const { width, height } = pngSize(publicDir + path);
    if (height !== sprite.frameHeight || width % sprite.frameWidth !== 0 || width === 0) {
      spriteErrors.push(`${id}: public/${path} è ${width}×${height}, ma i fotogrammi sono ${sprite.frameWidth}×${sprite.frameHeight}: la larghezza dev'essere un multiplo di ${sprite.frameWidth} e l'altezza ${sprite.frameHeight}`);
      continue;
    }
    const frames = width / sprite.frameWidth;
    if (a.hitFrame !== undefined && (a.hitFrame < 0 || a.hitFrame >= frames)) {
      spriteErrors.push(`${id}: hitFrame ${a.hitFrame} di "${state}" è fuori dai ${frames} fotogrammi di public/${path} (si conta da 0)`);
    }
    animations[state] = { ...a, frames };
    spriteFiles.push(path);
  }
  // Un PNG nella cartella che il blocco non nomina non si usa: lo si dice, potrebbe essere un nome sbagliato
  for (const file of existsSync(publicDir + sprite.dir) ? readdirSync(publicDir + sprite.dir) : []) {
    if (extname(file) === ".png" && !Object.hasOwn(sprite.animations, basename(file, ".png"))) {
      console.warn(`Attenzione: ${sprite.dir}/${file} non è uno stato di ${id} in characters.ts, non si usa`);
    }
  }
  characters[id] = { ...c, sprite: { ...sprite, animations: resolvedAnimations(animations) } };
}
if (spriteErrors.length) {
  console.error(`Sprite dei personaggi da correggere:\n- ${spriteErrors.join("\n- ")}`);
  process.exit(1);
}

const data = {
  version: pkg.version,
  protocol: PROTOCOL_VERSION,
  world: WORLD,
  fighter: { width: FIGHTER.width, height: FIGHTER.height },
  attacks: ATTACKS,
  ledge: { hangOffsetY: LEDGE.hangOffsetY }, // bordo del palco (#110): dove sta la mano di chi è appeso
  shield: { maxHp: SHIELD.maxHp }, // scudo (#109): la bolla è grande in proporzione ai punti rimasti
  supreme: { max: SUPREME.max }, // barra della suprema (#101): piena a questo valore
  stageCheck: stageCheckData(), // altezze di salto per il controllo delle arene nell'editor (E12)
  net: NET,
  reconnect: { ...RECONNECT, holdMs: RECONNECT_HOLD_MS }, // riconnessione dopo un calo di rete (#107)
  audio: AUDIO,
  audioFiles,
  input: INPUT,
  rumble: RUMBLE,
  training: TRAINING, // allenamento (E15): velocità ammesse e percentuale massima del pannello
  tutorial: { stage: TUTORIAL_STAGE_ID, bot: TUTORIAL_BOT, lessons: LESSONS }, // tutorial a tappe (E15 passo 2)
  challenges: CHALLENGES, // sfide con medaglie (E15 passo 3)
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
  characters, // CHARACTERS, con i fotogrammi degli sprite in formato cartella
};

const out = new URL("../godot/data/game.json", import.meta.url);
writeFileSync(out, JSON.stringify(data, null, 2) + "\n");
console.log(`Scritto ${out.pathname}`);

for (const path of spriteFiles) {
  mkdirSync(dirname(godotData + path), { recursive: true });
  copyFileSync(publicDir + path, godotData + path);
  console.log(`Copiato ${path}`);
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
