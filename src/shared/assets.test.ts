// Controllo dei file grafici (E7 passo 5): gira con npm test, quindi anche in CI. Per ogni file dice quale e
// perché, così chi disegna sa cosa correggere senza leggere il codice. La guida è public/assets/characters/README.md.
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { describe, it } from "node:test";
import { inflateSync } from "node:zlib";
import { CHARACTERS, SPRITE_STATES, isSpriteFolder, type SpriteFolderSpec, type SpriteSheetSpec, type DropSupremeArt } from "./characters";

const PUBLIC = new URL("../../public/", import.meta.url);
const ASSETS = new URL("assets/", PUBLIC);
const MAX_FILE_BYTES = 5 * 1024 * 1024; // AGENTS.md: oltre i 5 MB solo dopo averne parlato con il gruppo
const NOT_STATES = new Set(["portrait.png"]); // il ritratto per lobby e HUD, accanto agli stati

// ---------------------------------------------------------------------------------------------------------
// Lettura dei PNG: solo quello che serve al controllo (misure, canale alfa, alfa di un pixel)

export interface PngInfo {
  width: number;
  height: number;
  hasAlpha: boolean; // RGBA, grigio con alfa, o palette/colore con tRNS
  alphaAt: ((x: number, y: number) => number) | null; // 0 = trasparente, 255 = pieno; null se non si legge
}

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const CHANNELS: Record<number, number> = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 };

export function readPng(data: Buffer): PngInfo | string {
  if (data.length < 33 || !data.subarray(0, 8).equals(PNG_SIGNATURE)) return "non è un PNG";
  let width = 0, height = 0, bitDepth = 0, colorType = 0, interlace = 0;
  let trns: Buffer | null = null;
  const idat: Buffer[] = [];
  for (let at = 8; at + 8 <= data.length; ) {
    const len = data.readUInt32BE(at);
    const type = data.toString("latin1", at + 4, at + 8);
    const body = data.subarray(at + 8, at + 8 + len);
    if (type === "IHDR") {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      bitDepth = body[8];
      colorType = body[9];
      interlace = body[12];
    } else if (type === "tRNS") trns = body;
    else if (type === "IDAT") idat.push(body);
    else if (type === "IEND") break;
    at += 12 + len;
  }
  if (!(colorType in CHANNELS)) return `tipo di colore ${colorType} sconosciuto`;
  const hasAlpha = colorType === 4 || colorType === 6 || trns !== null;
  // L'alfa dei pixel si legge solo nei casi comuni: alfa vero o palette, senza interlacciamento
  if (interlace !== 0 || !(colorType === 3 || colorType === 4 || colorType === 6)) return { width, height, hasAlpha, alphaAt: null };
  let raw: Buffer;
  try {
    raw = inflateSync(Buffer.concat(idat));
  } catch {
    return "dati dell'immagine rovinati";
  }
  const bitsPerPixel = CHANNELS[colorType] * bitDepth;
  const stride = Math.ceil((width * bitsPerPixel) / 8);
  const bpp = Math.max(1, bitsPerPixel >> 3); // byte per pixel, per i filtri
  if (raw.length < (stride + 1) * height) return "dati dell'immagine troppo corti";
  const px = new Uint8Array(stride * height);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const src = y * (stride + 1) + 1;
    const row = y * stride;
    const prev = row - stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? px[row + i - bpp] : 0;
      const b = y > 0 ? px[prev + i] : 0;
      const c = i >= bpp && y > 0 ? px[prev + i - bpp] : 0;
      let v = raw[src + i];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      px[row + i] = v & 255;
    }
  }
  const step = bitDepth / 8; // byte per campione (1 o 2), si legge il byte alto
  const alphaAt = (x: number, y: number): number => {
    const row = y * stride;
    if (colorType === 6) return px[row + x * 4 * step + 3 * step];
    if (colorType === 4) return px[row + x * 2 * step + step];
    const bit = x * bitDepth; // palette: l'indice, poi l'alfa da tRNS (manca = pieno)
    const idx = bitDepth === 8 ? px[row + x] : (px[row + (bit >> 3)] >> (8 - bitDepth - (bit & 7))) & ((1 << bitDepth) - 1);
    return trns && idx < trns.length ? trns[idx] : 255;
  };
  return { width, height, hasAlpha, alphaAt };
}

// ---------------------------------------------------------------------------------------------------------
// I controlli, come funzioni pure: ricevono come leggere i PNG e restituiscono i problemi, "file: perché"

export type LoadPng = (path: string) => PngInfo | string | null; // path relativo a public/; null = manca
export type ListDir = (dir: string) => string[]; // i nomi dei file nella cartella (non nelle sottocartelle)

// Ogni fotogramma deve avere il pixel in alto a sinistra trasparente: se è pieno, c'è uno sfondo
function frameBackground(png: PngInfo, frameW: number, frameH: number, frames: { col: number; row: number }[]): number[] {
  if (!png.alphaAt) return [];
  return frames.filter(({ col, row }) => col * frameW < png.width && row * frameH < png.height && png.alphaAt!(col * frameW, row * frameH) !== 0).map((f) => f.col);
}

function transparency(path: string, png: PngInfo, frameW: number, frameH: number, frames: { col: number; row: number }[]): string[] {
  if (!png.hasAlpha) return [`${path}: senza trasparenza, esportalo con il canale alfa (RGBA) e senza il livello di sfondo`];
  const full = frameBackground(png, frameW, frameH, frames);
  if (full.length === 0) return [];
  const which = frames.length === 1 ? "" : ` (fotogramma ${full[0]}${full.length > 1 ? ` e altri ${full.length - 1}` : ""})`;
  return [`${path}: l'angolo in alto a sinistra${which} non è trasparente, togli il livello di sfondo`];
}

function load(loadPng: LoadPng, path: string, problems: string[]): PngInfo | null {
  const png = loadPng(path);
  if (png === null) problems.push(`${path}: manca`);
  else if (typeof png === "string") problems.push(`${path}: ${png}`);
  else return png;
  return null;
}

export function folderProblems(sprite: SpriteFolderSpec, loadPng: LoadPng, listDir: ListDir): string[] {
  const problems: string[] = [];
  const { dir, frameWidth: fw, frameHeight: fh } = sprite;
  const files = listDir(dir).filter((f) => f.toLowerCase().endsWith(".png"));
  for (const state of Object.keys(sprite.animations)) {
    if (!files.includes(`${state}.png`)) problems.push(`${dir}/${state}.png: manca, ma il blocco in characters.ts lo nomina`);
  }
  for (const file of files) {
    const path = `${dir}/${file}`;
    const state = file.slice(0, -4);
    const isPortrait = NOT_STATES.has(file);
    if (!isPortrait && !(SPRITE_STATES as readonly string[]).includes(state)) {
      problems.push(`${path}: "${state}" non è uno stato; i nomi validi sono in SPRITE_STATES (characters.ts) e nella tabella del README`);
      continue;
    }
    const png = load(loadPng, path, problems);
    if (!png) continue;
    if (isPortrait) {
      problems.push(...transparency(path, png, png.width, png.height, [{ col: 0, row: 0 }]));
      continue;
    }
    if (png.width % fw !== 0 || png.width === 0) {
      problems.push(`${path}: larga ${png.width} px, non è un multiplo del fotogramma (frameWidth ${fw}): i fotogrammi vanno in fila, tutti larghi ${fw}`);
    }
    if (png.height !== fh) problems.push(`${path}: alta ${png.height} px, il fotogramma è alto ${fh} (frameHeight)`);
    const frames = Math.floor(png.width / fw);
    const hitFrame = sprite.animations[state as keyof typeof sprite.animations]?.hitFrame;
    if (hitFrame !== undefined && hitFrame >= frames) problems.push(`${path}: hitFrame ${hitFrame} ma i fotogrammi sono ${frames} (si conta da 0)`);
    problems.push(...transparency(path, png, fw, fh, Array.from({ length: frames }, (_, col) => ({ col, row: 0 }))));
  }
  return problems;
}

export function sheetProblems(sprite: SpriteSheetSpec, loadPng: LoadPng): string[] {
  const problems: string[] = [];
  const { path, frameWidth: fw, frameHeight: fh, columns } = sprite;
  const png = load(loadPng, path, problems);
  if (!png) return problems;
  if (png.width !== columns * fw) problems.push(`${path}: larga ${png.width} px, con ${columns} colonne da ${fw} dovrebbe essere ${columns * fw}`);
  if (png.height % fh !== 0) problems.push(`${path}: alta ${png.height} px, non è un multiplo del fotogramma (frameHeight ${fh})`);
  const frames: { col: number; row: number }[] = [];
  for (const [name, a] of Object.entries(sprite.animations)) {
    if ((a.row + 1) * fh > png.height) problems.push(`${path}: l'animazione ${name} è alla riga ${a.row}, ma il foglio ha ${Math.floor(png.height / fh)} righe`);
    if (a.frames > columns) problems.push(`${path}: l'animazione ${name} ha ${a.frames} fotogrammi, ma le colonne sono ${columns}`);
    for (let col = 0; col < Math.min(a.frames, columns); col++) frames.push({ col, row: a.row });
  }
  const tr = transparency(path, png, fw, fh, frames);
  problems.push(...tr.map((p) => p.replace(/\(fotogramma \d+/, "(un fotogramma")));
  return problems;
}

export function supremeArtProblems(art: DropSupremeArt, loadPng: LoadPng): string[] {
  const problems: string[] = [];
  for (const file of [art.falling, art.landed, art.runner]) {
    const path = `${art.dir}/${file}`;
    const png = load(loadPng, path, problems);
    if (!png) continue;
    const frames = file === art.runner ? art.runnerFrames : 1;
    if (png.width % frames !== 0) problems.push(`${path}: larga ${png.width} px, non si divide in ${frames} fotogrammi uguali (runnerFrames)`);
    const fw = Math.floor(png.width / frames);
    problems.push(...transparency(path, png, fw, png.height, Array.from({ length: frames }, (_, col) => ({ col, row: 0 }))));
  }
  return problems;
}

// I percorsi della prima colonna di CREDITS.md: esatto, cartella che finisce con "/", o con "*" (dentro una cartella)
export function creditPatterns(credits: string): string[] {
  return credits
    .split("\n")
    .filter((l) => l.startsWith("|") && !/^\|\s*-/.test(l))
    .map((l) => /`([^`]+)`/.exec(l.split("|")[1] ?? "")?.[1])
    .filter((p): p is string => p !== undefined);
}

export function creditMatches(pattern: string, file: string): boolean {
  if (pattern.endsWith("/")) return file.startsWith(pattern);
  if (!pattern.includes("*")) return file === pattern;
  const re = new RegExp(`^${pattern.split("*").map((s) => s.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join("[^/]*")}$`);
  return re.test(file);
}

// files: relativi a public/assets/. Le righe che puntano fuori (godot/...) non si controllano al contrario
export function creditProblems(files: string[], credits: string): string[] {
  const patterns = creditPatterns(credits);
  const problems = files
    .filter((f) => !patterns.some((p) => creditMatches(p, f)))
    .map((f) => `${f}: nessuna riga in public/assets/CREDITS.md (autore, fonte, licenza); va bene anche una riga per la cartella, es. \`${f.replace(/[^/]+$/, "")}\``);
  for (const p of patterns) {
    if (!p.startsWith("godot/") && !files.some((f) => creditMatches(p, f))) problems.push(`CREDITS.md: la riga \`${p}\` non trova nessun file (rinominato o spostato?)`);
  }
  return problems;
}

// ---------------------------------------------------------------------------------------------------------
// I file veri

function walk(dir: URL, base = ""): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(new URL(`${e.name}/`, dir), `${base}${e.name}/`) : [`${base}${e.name}`],
  );
}
const assetFiles = walk(ASSETS).filter((f) => !f.endsWith(".md")); // i README e i crediti stessi non sono asset
const realPng: LoadPng = (path) => {
  const url = new URL(path, PUBLIC);
  return existsSync(url) ? readPng(readFileSync(url)) : null;
};
const realDir: ListDir = (dir) => {
  const url = new URL(`${dir}/`, PUBLIC);
  return existsSync(url) ? readdirSync(url, { withFileTypes: true }).filter((e) => e.isFile()).map((e) => e.name) : [];
};
const report = (problems: string[]) => assert.equal(problems.length, 0, `\n${problems.join("\n")}\n`);

describe("file grafici (E7 passo 5)", () => {
  for (const c of Object.values(CHARACTERS)) {
    const art = c.supreme?.type === "drop" ? c.supreme.art : undefined;
    if (!c.sprite && !art) continue;
    it(`${c.id}: misure, nomi degli stati e trasparenza`, () => {
      const problems: string[] = [];
      if (c.sprite) problems.push(...(isSpriteFolder(c.sprite) ? folderProblems(c.sprite, realPng, realDir) : sheetProblems(c.sprite, realPng)));
      if (art) problems.push(...supremeArtProblems(art, realPng));
      report(problems);
    });
  }

  it("ogni file è sotto i 5 MB", () => {
    report(
      assetFiles
        .map((f) => [f, statSync(new URL(f, ASSETS)).size] as const)
        .filter(([, size]) => size > MAX_FILE_BYTES)
        .map(([f, size]) => `${f}: ${(size / 1024 / 1024).toFixed(1)} MB, il massimo è 5 MB (per i PNG: palette a 256 colori, vedi il README dei personaggi)`),
    );
  });

  it("ogni file ha una riga in CREDITS.md", () => {
    report(creditProblems(assetFiles, readFileSync(new URL("CREDITS.md", ASSETS), "utf8")));
  });

  it("ogni PNG si legge", () => {
    report(assetFiles.filter((f) => f.endsWith(".png")).flatMap((f) => {
      const png = readPng(readFileSync(new URL(f, ASSETS)));
      return typeof png === "string" ? [`${f}: ${png}`] : [];
    }));
  });
});

// I controlli stessi, su file finti: un PNG sbagliato o senza crediti deve far fallire con file e motivo
describe("i controlli dei file dicono quale file e perché", () => {
  const png = (width: number, height: number, opts: Partial<PngInfo> = {}): PngInfo => ({ width, height, hasAlpha: true, alphaAt: () => 0, ...opts });
  const sprite: SpriteFolderSpec = {
    dir: "assets/characters/prova",
    frameWidth: 100,
    frameHeight: 80,
    animations: {
      idle: { fps: 12, loop: true }, walk: { fps: 24, loop: true }, jump: { fps: 24, loop: false }, fall: { fps: 24, loop: true },
      light: { fps: 24, loop: false, hitFrame: 5 }, heavy: { fps: 24, loop: false }, hit: { fps: 24, loop: false },
    },
  };
  const files: Record<string, PngInfo> = {
    "idle.png": png(600, 80), "walk.png": png(250, 80), "jump.png": png(200, 90), "fall.png": png(200, 80, { hasAlpha: false }),
    "light.png": png(300, 80), "heavy.png": png(300, 80, { alphaAt: (x) => (x === 100 ? 255 : 0) }), "hit.png": png(100, 80),
    "corsa.png": png(100, 80), "portrait.png": png(64, 64),
  };
  const problems = folderProblems(sprite, (p) => files[p.split("/").pop()!] ?? null, () => Object.keys(files));
  const about = (file: string) => problems.filter((p) => p.startsWith(`assets/characters/prova/${file}:`)).join(" | ");

  it("misura sbagliata", () => {
    assert.match(about("walk.png"), /larga 250 px, non è un multiplo del fotogramma \(frameWidth 100\)/);
    assert.match(about("jump.png"), /alta 90 px, il fotogramma è alto 80/);
  });
  it("hitFrame, stato sconosciuto, sfondo pieno", () => {
    assert.match(about("light.png"), /hitFrame 5 ma i fotogrammi sono 3/);
    assert.match(about("corsa.png"), /"corsa" non è uno stato/);
    assert.match(about("fall.png"), /senza trasparenza/);
    assert.match(about("heavy.png"), /fotogramma 1\) non è trasparente/);
  });
  it("i file giusti non danno problemi", () => {
    assert.equal(about("idle.png"), "");
    assert.equal(about("hit.png"), "");
    assert.equal(about("portrait.png"), "");
    assert.equal(problems.length, 6, problems.join("\n"));
  });
  it("file senza crediti e righe senza file", () => {
    const credits = "| File | Autore |\n|---|---|\n| `characters/prova/*.png` | noi |\n| `stages/prova/` | noi |\n| `characters/vecchio.png` | noi |\n| `godot/font.ttf` | altri |";
    const out = creditProblems(["characters/prova/idle.png", "characters/prova/rig/a.png", "stages/prova/sfondo-0.png"], credits);
    assert.deepEqual(out.map((p) => p.split(":")[0]), ["characters/prova/rig/a.png", "CREDITS.md"]);
    assert.match(out[0], /nessuna riga in public\/assets\/CREDITS.md/);
    assert.match(out[1], /`characters\/vecchio.png` non trova nessun file/);
  });
  it("legge un PNG vero: misure e trasparenza", () => {
    const real = readPng(readFileSync(new URL("characters/bonobot/idle.png", ASSETS)));
    assert.ok(typeof real !== "string" && real.width % 336 === 0 && real.height === 368 && real.hasAlpha && real.alphaAt?.(0, 0) === 0);
    assert.equal(readPng(Buffer.from("non sono un png")), "non è un PNG");
  });
});
