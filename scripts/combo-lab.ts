// Laboratorio delle combo (#594): prova con la fisica vera, senza bot né rete, se un colpo lega al successivo.
// Per ogni personaggio, coppia di mosse A -> B e percentuale del bersaglio dice se B prende per forza dopo A
// (combo vera), se il bersaglio fa in tempo a scappare, o se la catena non finisce mai. Scrive docs/combo/<id>.md
// con le combo che funzionano e le clip che servono per chiuderne altre.
// Uso: npm run combo-lab (i 5 del nucleo) oppure npm run combo-lab -- <id> [<id> ...]
//
// Come prova: A colpisce un Bonobo fermo a quella percentuale. Poi chi attacca insegue (a piedi, di corsa, con un
// salto corto, pieno o doppio) e a ogni tick in cui può prova a far partire B. "Vera" vuol dire che B entra mentre
// il bersaglio è ancora stordito qualunque cosa faccia: fermo, spingendo via o verso chi attacca, o rialzandosi al volo.

import { execFile } from "node:child_process";
import { closeSync, existsSync, mkdirSync, openSync, readSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { ANIMATION_FALLBACK, getCharacter, isSpriteFolder, specialsFor, SPECIAL_KINDS, type OptionalAnimationName, type SpecialSlot } from "../src/shared/characters";
import { COMBO_LAB, FIGHTER, TECH, TICK_RATE } from "../src/shared/constants";
import { anchorSpec } from "../src/shared/physics/anchor";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "../src/shared/physics";
import { getStage, type StageSpec } from "../src/shared/stages";
import type { AttackKind, GameEvent, InputState } from "../src/shared/types";

const DT = 1000 / TICK_RATE;
const FLOOR_Y = 560;
// Un pavimento largo e nient'altro: niente piattaforme, generi musicali o trappole che cambiano il volo
const STAGE: StageSpec = { ...getStage("palestra"), id: "laboratorio", solids: [{ x: -150, y: FLOOR_Y, width: 1580, height: 80 }], platforms: [] };
export const CORE = ["bradipo", "marcomunista", "orsoblu", "egiainuso", "elvedeo"];
export const PERCENTS = Array.from({ length: COMBO_LAB.percentMax / COMBO_LAB.percentStep + 1 }, (_, i) => i * COMBO_LAB.percentStep);

type Keys = Partial<InputState>;
export interface LabMove {
  id: string; // la mossa, o "grab"
  kind: AttackKind;
  state: string; // lo stato dello sprite che la disegna
  where: "ground" | "air" | "any";
  keys: Keys;
  toward?: boolean; // serve la direzione verso il bersaglio (speciale laterale)
  still?: boolean; // senza direzioni (speciale neutra)
  holdTicks?: number; // tick per cui si tiene lo speciale (la carica)
  far?: boolean; // arriva da lontano: proiettili e scatti
  thrown?: boolean; // un lancio: parte solo dalla presa
  hook?: boolean; // l'ancora di OrsoBlu: prende quando tira a bordo
}

// Le mosse che il laboratorio sa fare per un personaggio (non contrattacchi e suprema)
export function movesOf(characterId: string): LabMove[] {
  const normal = (id: AttackKind, where: LabMove["where"], keys: Keys): LabMove => ({ id, kind: id, state: id, where, keys });
  const moves: LabMove[] = [
    normal("light", "ground", { light: true }),
    normal("lightUp", "any", { light: true, up: true }),
    normal("lightDown", "ground", { light: true, down: true }),
    normal("lightAir", "air", { light: true }),
    normal("heavy", "ground", { heavy: true }),
    normal("heavyUp", "ground", { heavy: true, up: true }),
    normal("heavyDown", "ground", { heavy: true, down: true }),
    normal("heavyAir", "air", { heavy: true }),
    normal("dashAttack", "ground", { heavy: true }),
  ];
  const anchor = !!anchorSpec(characterId);
  if (!anchor) moves.push(normal("recovery", "air", { heavy: true, up: true }));
  for (const slot of ["neutral", "side", "down"] as SpecialSlot[]) {
    const sp = specialsFor(characterId)[slot];
    if (sp.type === "counter") continue;
    const kind = SPECIAL_KINDS[slot];
    const hook = anchor && slot === "neutral";
    moves.push({
      id: kind,
      kind,
      state: kind,
      where: "any",
      keys: { special: true, down: slot === "down" },
      toward: slot === "side",
      still: slot === "neutral",
      holdTicks: sp.type === "charge" ? Math.ceil(sp.minMs / DT) + 1 : undefined,
      far: sp.type !== "charge" || hook,
      hook,
    });
  }
  moves.push({ id: "grab", kind: "grab", state: "grab", where: "ground", keys: { shield: true, light: true } });
  for (const [kind, keys] of [["throwForward", {}], ["throwBack", {}], ["throwUp", { up: true }], ["throwDown", { down: true }]] as [AttackKind, Keys][])
    moves.push({ id: kind, kind, state: "throw", where: "ground", keys, thrown: true });
  return moves;
}

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

export interface World {
  a: Fighter;
  t: Fighter;
  fighters: Fighter[];
  ctx: PhysicsContext;
  tick: number;
  jumps: number; // salti già fatti nell'inseguimento
}

function cloneDeep<T extends object>(o: T, shared: string[]): T {
  const c = { ...o } as Record<string, unknown>;
  for (const k in c) {
    const v = c[k];
    if (v === null || typeof v !== "object" || shared.includes(k)) continue;
    c[k] = v instanceof Set ? new Set(v) : structuredClone(v);
  }
  return c as T;
}
// input e prevInput non si copiano: il laboratorio ne mette di nuovi a ogni tick e la fisica non li cambia
const cloneFighter = (f: Fighter) => cloneDeep(f, ["input", "prevInput"]);
function clone(w: World): World {
  const a = cloneFighter(w.a);
  const t = cloneFighter(w.t);
  const ctx = cloneDeep(w.ctx, ["stage", "events"]);
  ctx.events = [];
  return { a, t, fighters: [a, t], ctx, tick: w.tick, jumps: w.jumps };
}

function step(w: World, aKeys: Keys, tKeys: Keys = {}): GameEvent[] {
  w.a.input = { ...emptyInput(), ...aKeys };
  w.t.input = { ...emptyInput(), ...tKeys };
  w.ctx.events.length = 0;
  stepWorld(w.fighters, DT, w.ctx);
  w.tick++;
  return w.ctx.events;
}

function newWorld(characterId: string, percent: number, gap: number): World {
  const ctx: PhysicsContext = { stage: STAGE, events: [] };
  const mk = (id: string, ch: string, index: number) => createFighter({ id, name: id, characterId: ch, color: 0, team: 0, index, stocks: 3 }, STAGE);
  const a = mk("a", characterId, 0);
  const t = mk("t", "default", 1); // il bersaglio è sempre un Bonobo: peso 1
  a.x = 560;
  t.x = a.x + gap;
  a.y = t.y = FLOOR_Y;
  a.facing = 1;
  t.facing = -1;
  const w: World = { a, t, fighters: [a, t], ctx, tick: 0, jumps: 0 };
  for (let i = 0; i < 6; i++) step(w, {});
  t.percent = percent;
  return w;
}

// B è entrata in questo tick?
function landed(events: GameEvent[], w: World, m: LabMove): boolean {
  if (m.id === "grab") return events.some((e) => e.type === "grab" && e.id === w.a.id);
  return events.some((e) => e.type === "hit" && e.attackerId === w.a.id && e.targetId === w.t.id && e.kind === m.kind);
}

// Il bersaglio non può fare niente: stordito (anche nel fermo del colpo) o tenuto
const locked = (w: World) => w.t.grabbedBy === w.a.id || w.t.hitstunTimer > DT || (w.t.hitstopTimer > 0 && w.t.hitstunTimer > 0);
const gone = (w: World) => w.t.respawning || w.t.eliminated || w.a.respawning;

// I tasti della mossa nel tick in cui parte
function pressKeys(w: World, m: LabMove, base: Keys): Keys {
  const side = w.t.x >= w.a.x ? 1 : -1;
  const keys: Keys = { ...base, ...m.keys };
  if (m.still) keys.left = keys.right = false;
  if (m.toward) {
    keys.right = side === 1;
    keys.left = side === -1;
  }
  if (m.id === "throwForward" || m.id === "throwBack") {
    const dir = m.id === "throwForward" ? w.a.facing : -w.a.facing;
    keys.right = dir === 1;
    keys.left = dir === -1;
  }
  if (m.thrown) keys.shield = false;
  return keys;
}

// La mossa può partire adesso? (gli stessi controlli della fisica, per non provare a vuoto)
function canTry(w: World, m: LabMove): boolean {
  const { a, t } = w;
  if (m.thrown) return a.holding === t.id;
  if (a.holding !== null || a.hitstopTimer > 0 || a.attack || a.hitstun || a.helpless || a.jumpSquatTimer > 0 || a.landingTimer > 0) return false;
  if (a.specialTimer > 0 || a.grabLagTimer > 0 || a.chargeMs >= 0 || a.dodgeTimer > 0) return false;
  if (m.where !== "any" && (m.where === "ground") !== a.onGround) return false;
  if (m.id === "heavy" && a.dashing) return false;
  if (m.id === "dashAttack" && !a.dashing) return false;
  if (a.cooldownTimer > 0 && !(m.id !== "grab" && (a.comboTimer > 0 || (m.id === "light" && a.jabTimer > 0)))) return false;
  const reach = COMBO_LAB.reachPx * (m.far ? 2 : 1);
  return Math.abs(t.x - a.x) <= reach && Math.abs(t.y - a.y) <= reach;
}

function started(w: World, m: LabMove, events: GameEvent[]): boolean {
  if (m.thrown) return landed(events, w, m);
  if (m.hook) return !!w.a.anchor;
  if (m.holdTicks) return w.a.chargeMs >= 0 || w.a.attack === m.kind;
  return w.a.attack === m.kind;
}

// Come si insegue: a piedi o di corsa, da terra o saltando
interface Chase {
  name: string;
  run: boolean;
  jump: "none" | "hop" | "full" | "double";
}
const CHASES: Chase[] = [
  { name: "a piedi", run: false, jump: "none" },
  { name: "di corsa", run: true, jump: "none" },
  { name: "salto corto", run: true, jump: "hop" },
  { name: "salto", run: true, jump: "full" },
  { name: "doppio salto", run: true, jump: "double" },
];
const NEAR = 30; // pixel: più vicino di così non ci si muove più verso il bersaglio

function chaseKeys(w: World, c: Chase): Keys {
  const { a, t } = w;
  const dx = t.x - a.x;
  const side = dx >= 0 ? 1 : -1;
  const far = Math.abs(dx) > NEAR;
  const go = far || a.facing !== side;
  const keys: Keys = { right: go && side === 1, left: go && side === -1, run: c.run && far };
  if (c.jump === "none") return keys;
  const free = a.hitstopTimer === 0 && !a.attack && !a.hitstun && a.specialTimer <= 0 && a.grabLagTimer <= 0 && a.holding === null;
  if (w.jumps === 0) {
    if (free && a.onGround && a.jumpSquatTimer === 0 && a.landingTimer === 0) {
      keys.jump = true;
      w.jumps = 1;
    }
  } else if (c.jump !== "hop" && w.jumps === 1 && (a.jumpSquatTimer > 0 || a.jumpRising)) keys.jump = true; // tenuto: salto pieno
  if (c.jump === "double" && w.jumps === 1 && free && !a.onGround && a.jumpSquatTimer === 0 && a.vy > -250 && t.y < a.y - 50) {
    if (a.input.jump) keys.jump = false; // si lascia per ripremere
    else {
      keys.jump = true;
      w.jumps = 2;
    }
  } else if (w.jumps === 2 && a.jumpRising) keys.jump = true;
  return keys;
}

// Cosa fa il bersaglio per uscirne
export type Defense = "fermo" | "via" | "dentro" | "scudo";
const DEFENSES: Defense[] = ["fermo", "via", "dentro", "scudo"];

function defendKeys(w: World, d: Defense): Keys {
  if (d === "fermo") return {};
  const { a, t } = w;
  const away = t.x >= a.x ? 1 : -1;
  if (d === "dentro") return t.hitstun ? { right: away === -1, left: away === 1 } : {};
  const keys: Keys = { right: away === 1, left: away === -1 };
  if (d === "via") keys.jump = !t.hitstun && w.tick % 2 === 0;
  else if (t.hitstun && !t.onGround) keys.shield = t.techLockout === 0 && t.vy > 0 && FLOOR_Y - t.y <= t.vy * (TECH.windowMs / 1000) * 0.75; // la rialzata al volo
  else keys.shield = t.onGround || w.tick % 2 === 0; // a terra lo scudo, in aria la schivata
  return keys;
}

export interface Link {
  result: "vera" | "scappa";
  world: World; // subito dopo il colpo
  chase: string;
  ticks: number; // tick tra il colpo prima e questo
}

const MAX_TRY_TICKS = 70;

// Fa partire m adesso e guarda se entra
function tryMove(w0: World, m: LabMove, c: Chase, d: Defense): Link | null {
  const w = clone(w0);
  let wasLocked = locked(w);
  let events = step(w, pressKeys(w, m, chaseKeys(w, c)), defendKeys(w, d));
  if (!started(w, m, events)) return null;
  for (let i = 1; ; i++) {
    if (landed(events, w, m)) return { result: wasLocked ? "vera" : "scappa", world: w, chase: c.name, ticks: w.tick - w0.tick };
    const { a } = w;
    const busy = a.attack || a.specialTimer > 0 || a.chargeMs >= 0 || a.grabLagTimer > 0 || a.anchor?.phase === "fly" || (m.far && !m.hook && (w.ctx.projectiles?.list.some((p) => p.ownerId === a.id) ?? false));
    if (!busy || gone(w) || i >= MAX_TRY_TICKS) return null;
    const keys = chaseKeys(w, c);
    keys.jump = false; // durante la mossa non si salta
    if (m.holdTicks && i < m.holdTicks) keys.special = true;
    wasLocked = locked(w);
    events = step(w, keys, defendKeys(w, d));
  }
}

// Dopo un colpo entrato (w0), quali di queste mosse entrano e come. Si ferma al primo "vera" di ogni mossa
export function follow(w0: World, moves: LabMove[], d: Defense = "fermo"): Map<string, Link> {
  const found = new Map<string, Link>();
  const escapeTicks = d === "fermo" ? Math.ceil(COMBO_LAB.escapeMs / DT) : 0;
  for (const c of CHASES) {
    const todo = moves.filter((m) => found.get(m.id)?.result !== "vera" && (c.jump === "none" || m.where !== "ground"));
    if (todo.length === 0) continue;
    const w = clone(w0);
    w.jumps = 0;
    let free = 0; // tick da quando il bersaglio non è più stordito
    while (!gone(w) && free <= escapeTicks && w.tick - w0.tick < 240) {
      const isLocked = locked(w);
      for (const m of todo) {
        const old = found.get(m.id);
        if (old && (old.result === "vera" || !isLocked)) continue;
        if (!canTry(w, m)) continue;
        const link = tryMove(w, m, c, d);
        if (link && (!old || link.result === "vera")) found.set(m.id, { ...link, ticks: link.world.tick - w0.tick });
      }
      if (todo.every((m) => found.get(m.id)?.result === "vera")) break;
      step(w, chaseKeys(w, c), defendKeys(w, d));
      free = locked(w) ? 0 : free + 1;
    }
  }
  return found;
}

// Una "vera" vale solo se entra qualunque cosa faccia il bersaglio
export function confirm(w0: World, m: LabMove, link: Link): Link {
  if (link.result !== "vera") return link;
  for (const d of DEFENSES.slice(1)) if (follow(w0, [m], d).get(m.id)?.result !== "vera") return { ...link, result: "scappa" };
  return link;
}

// Il primo colpo: A entra su un Bonobo fermo a quella percentuale. null se il laboratorio non riesce a farla entrare
export function open(characterId: string, m: LabMove, percent: number): World | null {
  if (m.id === "grab") return null;
  const hit = (w: World, keysAt: (i: number) => Keys | null, ticks = 90): World | null => {
    for (let i = 0; i < ticks; i++) {
      const keys = keysAt(i);
      if (!keys) return null;
      if (landed(step(w, keys), w, m)) return w;
    }
    return null;
  };
  if (m.thrown) {
    const w = newWorld(characterId, percent, FIGHTER.width + 10);
    for (let i = 0; i < 30 && w.a.holding === null; i++) step(w, i === 0 ? { shield: true, light: true } : {});
    if (w.a.holding === null) return null;
    return hit(w, () => pressKeys(w, m, {}), 3);
  }
  if (m.id === "dashAttack") {
    for (const near of [150, 120, 90, 60]) {
      const w = newWorld(characterId, percent, 280);
      let pressedAt = -1;
      const r = hit(w, (i) => {
        if (pressedAt < 0 && w.a.dashing && w.t.x - w.a.x < near) pressedAt = i;
        return pressedAt === i ? { heavy: true, right: true, run: true } : pressedAt < 0 ? { right: true, run: true } : {};
      });
      if (r) return r;
    }
    return null;
  }
  if (m.where === "air") {
    // In aria: il colpo più tardi possibile che entra ancora (scendendo), prima col salto corto e poi col salto pieno
    for (const full of [false, true])
      for (let k = full ? 50 : 30; k >= 4; k--) {
        const w = newWorld(characterId, percent, FIGHTER.width + 10);
        const r = hit(w, (i) => (i === k ? pressKeys(w, m, {}) : { jump: i === 0 || (full && i < 20) }), k + 30);
        if (r) return r;
      }
    return null;
  }
  const gaps = [FIGHTER.width + 10, 110, 180, 260];
  for (const gap of m.hook ? gaps.reverse() : gaps) {
    const w = newWorld(characterId, percent, gap);
    const hold = m.holdTicks ?? 0;
    const r = hit(w, (i) => (i === 0 ? pressKeys(w, m, {}) : i < hold ? { special: true } : {}), 120);
    if (r) return r;
  }
  return null;
}

// Una catena di mosse da una percentuale: quanti colpi entrano di fila (il primo conta 1) e se tutti i legami sono veri
export function chain(characterId: string, ids: string[], percent: number): { hits: number; real: boolean; world: World | null } {
  const all = movesOf(characterId);
  const by = (id: string) => {
    const m = all.find((x) => x.id === id);
    if (!m) throw new Error(`${characterId}: mossa sconosciuta al laboratorio: ${id}`);
    return m;
  };
  let w: World | null = open(characterId, by(ids[0]), percent);
  if (!w) return { hits: 0, real: false, world: null };
  let real = true;
  for (let i = 1; i < ids.length; i++) {
    const m = by(ids[i]);
    const first: Link | undefined = follow(w, [m]).get(m.id);
    if (!first) return { hits: i, real: false, world: w };
    const link: Link = confirm(w, m, first);
    real &&= link.result === "vera";
    w = link.world;
  }
  return { hits: ids.length, real, world: w };
}

// Una catena a tutte le percentuali: V lega davvero, s entra solo se il bersaglio non reagisce
export function chainCells(id: string, ids: string[]): Cell[] {
  return PERCENTS.map((p) => {
    const c = chain(id, ids, p);
    return c.hits < ids.length ? "." : c.real ? "V" : "s";
  });
}

// ---------------------------------------------------------------------------------------------------------------
// Il rapporto di un personaggio

export type Cell = "V" | "s" | "."; // vera, scappa, niente
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
