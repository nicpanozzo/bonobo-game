// Laboratorio delle combo (#594): prova con la fisica vera, senza bot né rete, se un colpo lega al successivo.
// Per ogni personaggio, coppia di mosse A -> B e percentuale del bersaglio dice se B prende per forza dopo A
// (combo vera), se il bersaglio fa in tempo a scappare, o se la catena non finisce mai. Scrive docs/combo/<id>.md
// con le combo che funzionano e le clip che servono per chiuderne altre.
// Uso: npm run combo-lab (i 5 del nucleo) oppure npm run combo-lab -- <id> [<id> ...]
//
// Come prova: A colpisce un Bonobo fermo a quella percentuale. Poi chi attacca insegue (a piedi, di corsa, con un
// salto corto, pieno o doppio) e a ogni tick in cui può prova a far partire B. "Vera" vuol dire che B entra mentre
// il bersaglio è ancora stordito qualunque cosa faccia: fermo, spingendo via o verso chi attacca, o rialzandosi al volo.
import { closeSync, existsSync, mkdirSync, openSync, readSync, writeFileSync } from "node:fs";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { ANIMATION_FALLBACK, getCharacter, isSpriteFolder, type OptionalAnimationName } from "../src/shared/characters";
import { COMBO_LAB } from "../src/shared/constants";
import { anchorSpec } from "../src/shared/physics/anchor";
import { chain, chainCells, confirm, CORE, follow, open, PERCENTS, movesOf, type Cell, type LabMove } from "../src/shared/comboLab";

// Il cuore del laboratorio sta in src/shared/comboLab.ts (lo usa anche il Dojo): qui il rapporto
export * from "../src/shared/comboLab";

// I fotogrammi del PNG di uno stato, 0 se il personaggio non ha quel disegno (lo stato usa un ripiego)
export function framesOf(characterId: string, state: string): number {
  const sprite = getCharacter(characterId).sprite;
  if (!sprite || !isSpriteFolder(sprite)) return 0;
  const path = fileURLToPath(new URL(`../public/${sprite.dir}/${state}.png`, import.meta.url));
  if (!existsSync(path)) return 0;
  const head = Buffer.alloc(24); // la larghezza sta nell'intestazione del PNG, byte 16-19
  const fd = openSync(path, "r");
  readSync(fd, head, 0, 24, 0);
  closeSync(fd);
  return Math.max(1, Math.round(head.readUInt32BE(16) / sprite.frameWidth));
}
export const drawn = (characterId: string, m: LabMove) => framesOf(characterId, m.state) > 0;


export interface Report {
  id: string;
  moves: LabMove[];
  starters: LabMove[]; // le mosse che il laboratorio riesce a far entrare
  grid: Map<string, Cell[]>; // "A>B" -> una cella per percentuale
  endless: string[]; // coppie che non finiscono mai
}

const key = (a: string, b: string) => `${a}>${b}`;

export function analyse(id: string): Report {
  const moves = movesOf(id);
  const followers = moves.filter((m) => !m.thrown);
  const grid = new Map<string, Cell[]>();
  const starters: LabMove[] = [];
  for (const a of moves) {
    if (a.id === "grab") continue;
    let any = false;
    PERCENTS.forEach((p, pi) => {
      const w0 = open(id, a, p);
      if (!w0) return;
      any = true;
      for (const [b, link] of follow(w0, followers)) {
        const cells = grid.get(key(a.id, b)) ?? grid.set(key(a.id, b), PERCENTS.map(() => "." as Cell)).get(key(a.id, b))!;
        cells[pi] = confirm(w0, followers.find((m) => m.id === b)!, link).result === "vera" ? "V" : "s";
      }
    });
    if (any) starters.push(a);
  }
  // Non finisce mai: la stessa coppia continua a legare, A B A B..., oltre COMBO_LAB.endlessHits colpi
  const endless: string[] = [];
  for (const [k, cells] of grid) {
    const [a, b] = k.split(">");
    if (a > b || !cells.includes("V") || !grid.get(key(b, a))?.includes("V")) continue;
    const seq = Array.from({ length: COMBO_LAB.endlessHits + 1 }, (_, i) => (i % 2 ? b : a));
    const from = [a, b].flatMap((first) => {
      const s = first === a ? seq : seq.map((x) => (x === a ? b : a));
      return PERCENTS.filter((p) => chain(id, s, p).real).map((p) => `${s[0]} da ${p}%`);
    });
    if (from.length) endless.push(`${a} e ${b} (${[...new Set(from.map((f) => f.split(" da ")[0]))].join(" o ")} per primo, da ${ranges(from.map((f) => parseInt(f.split(" da ")[1])))}%)`);
  }
  return { id, moves, starters, grid, endless };
}

// 0, 10, 20, 50 -> "0-20, 50"
export function ranges(percents: number[]): string {
  const sorted = [...new Set(percents)].sort((x, y) => x - y);
  const out: string[] = [];
  for (let i = 0; i < sorted.length; i++) {
    let j = i;
    while (j + 1 < sorted.length && sorted[j + 1] - sorted[j] === COMBO_LAB.percentStep) j++;
    out.push(i === j ? `${sorted[i]}` : `${sorted[i]}-${sorted[j]}`);
    i = j;
  }
  return out.join(", ");
}
const where = (cells: Cell[], c: Cell) => ranges(PERCENTS.filter((_, i) => cells[i] === c));

// Le percentuali a cui una catena intera lega davvero
export const chainPercents = (id: string, ids: string[]): number[] => PERCENTS.filter((_, i) => chainCells(id, ids)[i] === "V");

// Le combo che c'erano già: il laboratorio le deve ritrovare
export function known(id: string): { name: string; ids: string[] }[] {
  const out = [{ name: "Combo di leggeri (jab)", ids: ["light", "light", "light"] }];
  const ch = getCharacter(id);
  if (ch.airPop) for (const first of ["throwUp", "lightUp", "heavyUp", "throwDown"]) out.push({ name: "Piano quinquennale", ids: [first, "lightAir", "lightAir", "heavyAir"] });
  if (anchorSpec(id)) for (const last of ["light", "heavy", "specialSide", "dashAttack"]) out.push({ name: "Arrembaggio", ids: ["specialNeutral", last] });
  return out;
}

const arrow = (ids: string[]) => ids.join(" → ");

export function markdown(r: Report): string {
  const ch = getCharacter(r.id);
  const sprite = ch.sprite && isSpriteFolder(ch.sprite) ? ch.sprite : undefined;
  const isDrawn = (moveId: string) => drawn(r.id, r.moves.find((m) => m.id === moveId)!);
  const L: string[] = [];
  L.push(`# Combo di ${ch.name}`, "");
  L.push(`Generato da \`npm run combo-lab -- ${r.id}\` (issue #594): non modificare a mano, rilancia il laboratorio.`, "");
  L.push(`Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi ${ch.name} insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a ${COMBO_LAB.percentMax} a passi di ${COMBO_LAB.percentStep}.`, "");

  const verdict = (ids: string[]) => {
    const cells = chainCells(r.id, ids);
    const v = where(cells, "V");
    const soft = where(cells, "s");
    return { v, text: `${v ? `Vera a ${v}%.` : "Mai vera."}${soft ? ` Entra solo se il bersaglio non reagisce a ${soft}%.` : ""}` };
  };
  L.push("## Combo del personaggio", "");
  if (!ch.combos?.length) L.push("Nessuna combo scritta in `characters.ts` (`combos`).", "");
  for (const c of ch.combos ?? []) L.push(`- **${c.name}**: ${arrow(c.steps.map((s) => s.move))}. ${verdict(c.steps.map((s) => s.move)).text}`);
  if (ch.combos?.length) L.push("");

  L.push("## Combo note", "", "Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.", "");
  const names = [...new Set(known(r.id).map((k) => k.name))];
  for (const name of names) {
    const tries = known(r.id).filter((k) => k.name === name).map((k) => ({ k, ...verdict(k.ids), cells: chainCells(r.id, k.ids) }));
    const found = tries.filter((t) => t.cells.some((c) => c !== "."));
    if (found.length === 0) L.push(`- **${name}**: il laboratorio non la ritrova.`);
    for (const t of found) L.push(`- **${name}**: ${arrow(t.k.ids)}. ${t.text}`);
  }
  L.push("");

  L.push("## Mosse disegnate", "");
  L.push("| Mossa | Fotogrammi | Fotogramma del colpo |", "|---|---|---|");
  const states = [...new Set(r.moves.map((m) => m.state))];
  for (const s of states) {
    const n = framesOf(r.id, s);
    const anim = sprite?.animations[s as OptionalAnimationName];
    if (n) L.push(`| ${s} | ${n} | ${anim?.hitFrame ?? "-"} |`);
  }
  const missing = states.filter((s) => !framesOf(r.id, s));
  L.push("", missing.length ? `Senza disegno proprio: ${missing.map((s) => `${s} (usa ${fallbackOf(r.id, s)})`).join(", ")}.` : "Tutte le mosse del laboratorio hanno il loro disegno.", "");

  const pairs = [...r.grid].map(([k, cells]) => ({ a: k.split(">")[0], b: k.split(">")[1], cells }));
  const real = pairs.filter((p) => p.cells.includes("V"));
  L.push("## Coppie che legano", "", "Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.", "");
  L.push("| Prima | Dopo | Vera a % | Solo se non reagisce a % |", "|---|---|---|---|");
  for (const p of real) if (isDrawn(p.a) && isDrawn(p.b)) L.push(`| ${p.a} | ${p.b} | ${where(p.cells, "V")} | ${where(p.cells, "s") || "-"} |`);
  L.push("");
  const almost = pairs.filter((p) => !p.cells.includes("V") && isDrawn(p.a) && isDrawn(p.b));
  if (almost.length) {
    L.push("### Il bersaglio fa in tempo a scappare", "", "La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.", "");
    for (const a of [...new Set(almost.map((p) => p.a))]) L.push(`- dopo **${a}**: ${almost.filter((p) => p.a === a).map((p) => `${p.b} (${where(p.cells, "s")}%)`).join(", ")}`);
    L.push("");
  }
  L.push("## Catene che non finiscono mai", "");
  L.push(r.endless.length ? r.endless.map((e) => `- ${e}: lega ancora dopo ${COMBO_LAB.endlessHits} colpi. Da sistemare.`).join("\n") : `Nessuna: nessuna coppia continua a legare oltre ${COMBO_LAB.endlessHits} colpi.`, "");

  L.push("## Clip che servono", "");
  const need = r.moves.filter((m) => !drawn(r.id, m)).map((m) => {
    const after = real.filter((p) => p.b === m.id && isDrawn(p.a));
    const before = real.filter((p) => p.a === m.id && isDrawn(p.b));
    return { m, after, before };
  });
  const useful = need.filter((n) => n.after.length + n.before.length > 0).sort((x, y) => y.after.length + y.before.length - (x.after.length + x.before.length));
  if (useful.length === 0) L.push(need.length ? "Nessuna clip mancante chiuderebbe una combo vera in più." : "Nessuna: tutte le mosse del laboratorio sono disegnate.");
  else L.push("Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):", "");
  for (const n of useful) {
    const state = n.m.state;
    L.push(`- **${state}** (oggi usa ${fallbackOf(r.id, state)}), ${n.after.length + n.before.length} combo:`);
    for (const p of n.after) L.push(`  - ${p.a} → ${p.b} a ${where(p.cells, "V")}%`);
    for (const p of n.before) L.push(`  - ${p.a} → ${p.b} a ${where(p.cells, "V")}%`);
  }
  const idle = need.filter((n) => !useful.includes(n)).map((n) => n.m.state);
  if (useful.length && idle.length) L.push("", `Mancano anche, ma oggi non chiudono combo vere: ${[...new Set(idle)].join(", ")}.`);
  L.push("");
  return L.join("\n");
}

function fallbackOf(id: string, state: string): string {
  let s = state.startsWith("special") && state !== "special" ? "special" : state;
  for (let i = 0; i < 4; i++) {
    if (s !== state && framesOf(id, s)) return s;
    s = ANIMATION_FALLBACK[s as OptionalAnimationName] ?? "light";
  }
  return s;
}

// ---------------------------------------------------------------------------------------------------------------

function main(): void {
  const args = process.argv.slice(2);
  const t0 = Date.now();
  if (args[0] === "--uno") {
    // un personaggio solo, in questo processo: scrive il suo file e una riga di riassunto
    const id = args[1];
    const r = analyse(id);
    const dir = fileURLToPath(new URL("../docs/combo/", import.meta.url));
    mkdirSync(dir, { recursive: true });
    writeFileSync(`${dir}${id}.md`, markdown(r));
    const real = [...r.grid.values()].filter((c) => c.includes("V")).length;
    const combos = (getCharacter(id).combos ?? []).map((c) => `${c.name}: ${ranges(chainPercents(id, c.steps.map((s) => s.move))) || "MAI"}`);
    console.log(`${id}: ${real} coppie vere, ${r.endless.length} senza fine. ${combos.join("; ")} -> docs/combo/${id}.md`);
    return;
  }
  const ids = args.length ? args : CORE;
  for (const id of ids) getCharacter(id); // sbaglia subito se l'id non esiste
  // Un processo per personaggio: insieme stanno sotto il minuto
  const self = fileURLToPath(import.meta.url);
  const jobs = ids.map(
    (id) =>
      new Promise<string>((resolve, reject) => {
        execFile(process.execPath, [...process.execArgv, self, "--uno", id], (err, out, errOut) => (err ? reject(new Error(errOut || String(err))) : resolve(out.trim())));
      }),
  );
  Promise.all(jobs).then(
    (lines) => {
      for (const line of lines) console.log(line);
      console.log(`Laboratorio delle combo: ${ids.length} personaggi in ${((Date.now() - t0) / 1000).toFixed(1)} s`);
    },
    (e) => {
      console.error(e);
      process.exit(1);
    },
  );
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
