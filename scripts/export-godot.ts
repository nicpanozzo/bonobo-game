// Esporta in JSON i dati del gioco che servono al client Godot (godot/data/game.json):
// arene, personaggi e numeri. Così Godot li legge invece di ricopiarli a mano.
// Copia anche gli sprite dei personaggi in godot/data/ (foglio unico o un PNG per stato), perché Godot vede solo la sua cartella.
// Da rilanciare quando cambiano stages.ts, characters.ts o constants.ts: npm run export:godot

import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";
import type { SpriteFolderSpec } from "../src/shared/characters";
import { CHARACTERS, CREWS, DEFAULT_CHARACTER_ID, isSpriteFolder, resolvedAnimations, SPECIAL_KINDS, SPECIAL_SLOTS, specialAttackSpec, specialsFor, spriteStatePath, supremeAttackSpec } from "../src/shared/characters";
import { ATTACKS, AUDIO, BIRRA, BONG, CAMERA, FUNGO, COLORS, EFFECTS, FIGHTER, INPUT, ITEM_AMOUNTS, ITEM_RULES, LEDGE, MICELIO, NET, POWERUP, PROTOCOL_VERSION, RUMBLE, SHIELD, SPORE, SUPREME_SPEEDS, TEAM_COLORS, TEAM_NAMES, WORLD } from "../src/shared/constants";
import { RECONNECT, RECONNECT_HOLD_MS } from "../src/shared/constants";
import { COLORS_COLORBLIND, MAX_TEAMS, TEAM_COLORS_COLORBLIND } from "../src/shared/constants";
import { TRAINING } from "../src/shared/constants";
import { DASH, DODGE, RECOVERY, TICK_RATE } from "../src/shared/constants";
import { predictionTraces } from "../src/shared/predictionTraces";
import { HITSTOP, SMASH_CHARGE, SUPREME } from "../src/shared/constants";
import { LESSONS, TUTORIAL_BOT, TUTORIAL_STAGE_ID } from "../src/shared/tutorial";
import { CHALLENGES } from "../src/shared/challenges";
import { DROPPABLE_ITEMS, ITEMS } from "../src/shared/items";
import { DEFAULT_STAGE_ID, STAGES, stageArtFiles } from "../src/shared/stages";
import { stageCheckData } from "../src/shared/stageCheck";
import { RANDOM_STAGE_ART } from "../src/shared/stageGenerator";
import { characterStats } from "../src/shared/characters";
import { CHARACTER_STATS, PERF_BUDGET } from "../src/shared/constants";

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

// Gli stati di uno sprite in formato cartella, con i fotogrammi contati dai PNG e il ripiego già deciso (E7 passo 3).
// id: di chi è, nei messaggi d'errore (il lottatore, o "lottatore, skin ...")
function folderSprite(id: string, sprite: SpriteFolderSpec): SpriteFolderSpec {
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
    if (extname(file) === ".png" && file !== "portrait.png" && !Object.hasOwn(sprite.animations, basename(file, ".png"))) {
      console.warn(`Attenzione: ${sprite.dir}/${file} non è uno stato di ${id} in characters.ts, non si usa`);
    }
  }
  const rig = sprite.rig ? rigFor(id, sprite.rig, animations) : undefined;
  return { ...sprite, rig, animations: resolvedAnimations(animations) as SpriteFolderSpec["animations"] };
}

// La prova del rig in tempo reale (#403): da rig.json e animazioni.json di tools/rig/ un file solo per Godot,
// <rig>/godot.json, con le ossa in ordine (i genitori prima), i pezzi già in ordine di disegno (inchiostro compreso)
// e per ogni stato i fotogrammi come [radice x, radice y, gradi di ogni osso]. Ritorna il percorso in godot/data
const rigFiles: Record<string, string> = {};
interface RigBone { name: string; parent: string | null; head: [number, number]; deform: boolean }
interface RigPiece { name: string; bone: string; z: number; image: string; x: number; y: number; ink?: string; inkZ?: number }
interface RigFrame { bones: Record<string, number>; root: [number, number] }
// Le pose chiave (#404, tools/rig/animazioni_nonnagina.py): t in fasi dell'attacco (0-3) o in ms, e = curva d'arrivo
interface RigKeys { time: "phase" | "ms"; ms?: number; loop?: boolean; spec?: Record<string, number>; keys: (RigFrame & { t: number; e: string })[] }
function rigFor(id: string, dir: string, animations: Record<string, object>): string | undefined {
  const rigPath = `${publicDir}${dir}/rig.json`;
  const animPath = `${publicDir}${dir}/animazioni.json`;
  if (!existsSync(rigPath) || !existsSync(animPath)) {
    spriteErrors.push(`${id}: il rig vuole public/${dir}/rig.json e animazioni.json (tools/rig/)`);
    return undefined;
  }
  const rig = JSON.parse(readFileSync(rigPath, "utf8")) as { scale: number; bones: RigBone[]; pieces: RigPiece[] };
  const anim = JSON.parse(readFileSync(animPath, "utf8")) as { animations: Record<string, { frames: RigFrame[] }> };
  const bones = rig.bones.filter((b) => b.deform);
  const index = new Map(bones.map((b, i) => [b.name, i]));
  // stesso ordine di Pittore in rendi_sprite.py: pezzo, poi il suo inchiostro, e un ordinamento stabile per z
  const layers: { z: number; bone: number; name: string; image: string; x: number; y: number }[] = [];
  for (const p of rig.pieces) {
    const bone = index.get(p.bone);
    if (bone === undefined) {
      spriteErrors.push(`${id}: il pezzo ${p.image} sta sull'osso ${p.bone}, che non si muove`);
      continue;
    }
    layers.push({ z: p.z, bone, name: p.name, image: `${dir}/${p.image}`, x: p.x, y: p.y });
    if (p.ink) layers.push({ z: p.inkZ ?? p.z - 0.5, bone, name: p.name, image: `${dir}/${p.ink}`, x: p.x, y: p.y });
  }
  layers.sort((a, b) => a.z - b.z);
  const r = (v: number) => Math.round(v * 100) / 100;
  const states: Record<string, number[][]> = {};
  for (const [state, a] of Object.entries(animations) as [string, { frames: number }][]) {
    const frames = anim.animations[state]?.frames;
    if (!frames) continue; // lo stato senza pose resta a striscia
    if (frames.length !== a.frames) {
      spriteErrors.push(`${id}: "${state}" ha ${frames.length} pose in animazioni.json ma ${a.frames} fotogrammi nel PNG: rifai le strisce con rendi_sprite.py`);
    }
    states[state] = frames.map((f) => [r(f.root[0]), r(f.root[1]), ...bones.map((b) => r(f.bones[b.name] ?? 0))]);
  }
  // le chiavi, se ci sono: Godot le preferisce alle pose cotte (stessa forma: [radice x, radice y, gradi di ogni osso])
  const keysPath = `${publicDir}${dir}/chiavi.json`;
  const pose = (f: RigFrame) => [r(f.root[0]), r(f.root[1]), ...bones.map((b) => r(f.bones[b.name] ?? 0))];
  const keys = existsSync(keysPath) ? (JSON.parse(readFileSync(keysPath, "utf8")) as { states: Record<string, RigKeys> }).states : {};
  const keyed = Object.fromEntries(Object.entries(keys).map(([state, k]) => [state, {
    time: k.time, ms: k.ms ?? 0, loop: k.loop ?? false, spec: k.spec ?? {},
    t: k.keys.map((x) => x.t), e: k.keys.map((x) => x.e), p: k.keys.map(pose),
  }]));
  for (const l of layers) spriteFiles.push(l.image);
  const out = `${dir}/godot.json`;
  rigFiles[out] = JSON.stringify({
    scale: rig.scale,
    bones: bones.map((b) => ({ name: b.name, parent: b.parent === null ? -1 : (index.get(b.parent) ?? -1), head: b.head })),
    pieces: layers.map(({ bone, name, image, x, y }) => ({ bone, name, image, x, y })),
    animations: states,
    keys: keyed,
  }) + "\n";
  return out;
}

const characters: Record<string, unknown> = {};
for (const [id, spec] of Object.entries(CHARACTERS)) {
  // Le speciali (E10) arrivano già complete: le sue e, per quelle che mancano, DEFAULT_SPECIALS
  // specialAttacks: le stesse speciali lette come attacchi (specialAttackSpec), per disegnare il colpo in Godot
  const specials = specialsFor(id);
  const specialAttacks = Object.fromEntries(SPECIAL_SLOTS.map((slot) => [SPECIAL_KINDS[slot], specialAttackSpec(specials[slot])]));
  // stats: tutte e cinque, già dentro i limiti (E11 passo C: le barre della lobby)
  // portrait: il ritratto della lobby, se c'è public/assets/characters/<id>/portrait.png
  const portraitPath = `assets/characters/${id}/portrait.png`;
  const portrait = existsSync(publicDir + portraitPath) ? portraitPath : undefined;
  if (portrait) spriteFiles.push(portrait);
  // supremeAttack: la suprema propria letta come attacco (#102), null per chi usa quella di base
  const c = { ...spec, stats: characterStats(id), portrait, specials, specialAttacks, supremeAttack: supremeAttackSpec(id) };
  characters[id] = c;
  // I disegni della suprema propria (#102): si copiano come gli sprite
  const art = spec.supreme?.type === "drop" ? spec.supreme.art : undefined;
  for (const file of art ? [art.falling, art.landed, art.runner] : []) {
    const path = `${art!.dir}/${file}`;
    if (existsSync(publicDir + path)) spriteFiles.push(path);
    else spriteErrors.push(`${id}: manca public/${path} (disegni della suprema in characters.ts)`);
  }
  if (!c.sprite) continue;
  // In game.json ogni stato c'è, con i dati del disegno che lo mostra (src): il ripiego si decide qui,
  // una volta sola, e Godot non controlla cosa manca (E7 passo 3)
  if (!isSpriteFolder(c.sprite)) {
    spriteFiles.push(c.sprite.path);
    characters[id] = { ...c, sprite: { ...c.sprite, animations: resolvedAnimations(c.sprite.animations) } };
    continue;
  }
  // Le skin (#339): solo un altro disegno, con gli stessi controlli dello sprite del lottatore
  const skins = Object.fromEntries(Object.entries(spec.skins ?? {}).map(([skin, s]) => {
    const portraitPath = `${s.sprite.dir}/portrait.png`;
    if (existsSync(publicDir + portraitPath)) spriteFiles.push(portraitPath);
    return [skin, { ...s, sprite: folderSprite(`${id}, skin ${skin}`, s.sprite), portrait: existsSync(publicDir + portraitPath) ? portraitPath : undefined }];
  }));
  characters[id] = { ...c, sprite: folderSprite(id, c.sprite), skins };
}
// Sfondi delle arene (E12 passo 3): ogni file nominato in art deve esserci
for (const [id, art] of [...Object.entries(STAGES).map(([id, s]) => [id, s.art] as const), ["casuali", RANDOM_STAGE_ART] as const]) {
  const files = art ? stageArtFiles(art) : []; // strati, anteprima, materiali e decorazioni (#237)
  for (const file of files) {
    const path = `assets/stages/${art!.dir ?? id}/${file}`;
    if (existsSync(publicDir + path)) spriteFiles.push(path);
    else spriteErrors.push(`arena ${id}: manca public/${path} (sfondo in stages.ts)`);
  }
}
if (spriteErrors.length) {
  console.error(`Sprite dei personaggi da correggere:\n- ${spriteErrors.join("\n- ")}`);
  process.exit(1);
}

const data = {
  version: pkg.version,
  protocol: PROTOCOL_VERSION,
  tickRate: TICK_RATE, // tick di fisica al secondo: il client numera gli input con il suo tick (E17)
  world: WORLD,
  fighter: FIGHTER, // misure e movimento: il port del movimento per la predizione li usa tutti (E17)
  dash: DASH, // scatto e corsa (#199), per la predizione (E17)
  dodge: DODGE, // schivata (#3), per la predizione (E17)
  attacks: ATTACKS,
  hitstop: HITSTOP, // fermo dei colpi (#15): chi è colpito trema per tanto
  smashCharge: SMASH_CHARGE, // colpi caricati: il pesante a terra tenuto, per la predizione (E17)
  recovery: RECOVERY, // spinta del recupero (#11), per la predizione (E17)
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
  itemAmounts: ITEM_AMOUNTS, // regole della stanza: quanti oggetti cadono
  droppableItems: DROPPABLE_ITEMS, // regole della stanza: quali oggetti si possono scegliere
  supremeSpeeds: SUPREME_SPEEDS, // regole della stanza: velocità della barra della suprema
  powerup: POWERUP, // #231
  bong: BONG, // #302
  fungo: FUNGO, // il fungo di Teemo
  spore: SPORE, // #358
  micelio: MICELIO, // #358
  birra: BIRRA, // #302
  colors: COLORS,
  teamColors: TEAM_COLORS,
  colorsColorblind: COLORS_COLORBLIND,
  teamColorsColorblind: TEAM_COLORS_COLORBLIND,
  teamNames: TEAM_NAMES,
  maxTeams: MAX_TEAMS, // #409
  defaultStageId: DEFAULT_STAGE_ID,
  stages: STAGES,
  defaultCharacterId: DEFAULT_CHARACTER_ID,
  characterStats: CHARACTER_STATS, // limiti delle statistiche, per le barre della lobby (E11)
  perfBudget: { clientScriptUs: PERF_BUDGET.clientScriptUs }, // budget del client per bench_client.gd --check (E3)
  characters, // CHARACTERS, con i fotogrammi degli sprite in formato cartella
  crews: CREWS, // i nomi delle compagnie del lore, per i badge della lobby (#13)
};

const out = new URL("../godot/data/game.json", import.meta.url);
writeFileSync(out, JSON.stringify(data, null, 2) + "\n");
console.log(`Scritto ${out.pathname}`);

// Tracce del movimento per il test del port in GDScript (E17 passo 3): nei test, non nel gioco esportato
const traces = new URL("../godot/tests/data/prediction-traces.json", import.meta.url);
mkdirSync(dirname(traces.pathname), { recursive: true });
writeFileSync(traces, JSON.stringify(predictionTraces()) + "\n");
console.log(`Scritto ${traces.pathname}`);

for (const path of spriteFiles) {
  mkdirSync(dirname(godotData + path), { recursive: true });
  copyFileSync(publicDir + path, godotData + path);
  console.log(`Copiato ${path}`);
}
for (const [path, json] of Object.entries(rigFiles)) {
  writeFileSync(godotData + path, json); // la cartella c'è già: ci sono stati copiati i pezzi
  console.log(`Scritto ${path}`);
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
