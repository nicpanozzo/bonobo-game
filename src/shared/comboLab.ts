// Il cuore del laboratorio delle combo (#594), qui perché lo usa anche il server: il Dojo (#dojo) ci registra la
// dimostrazione di una combo, i tasti tick per tick, e la fa rifare al lottatore vero. Il rapporto in docs/combo/ lo
// scrive scripts/combo-lab.ts, che usa queste funzioni.
//
// Come prova: A colpisce un Bonobo fermo a quella percentuale. Poi chi attacca insegue (a piedi, di corsa, con un
// salto corto, pieno o doppio) e a ogni tick in cui può prova a far partire B. "Vera" vuol dire che B entra mentre
// il bersaglio è ancora stordito qualunque cosa faccia: fermo, spingendo via o verso chi attacca, o rialzandosi al volo.

import { specialsFor, SPECIAL_KINDS, type SpecialSlot } from "./characters";
import { COMBO_LAB, DOJO, FIGHTER, GAME_SPEED, TECH, TICK_RATE } from "./constants";
import { anchorSpec } from "./physics/anchor";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./physics";
import { getStage } from "./stages";
import type { AttackKind, GameEvent, InputState } from "./types";

const DT = 1000 / TICK_RATE;
// Un pavimento largo e nient'altro: niente piattaforme, generi musicali o trappole che cambiano il volo.
// È l'arena del Dojo, così la dimostrazione registrata qui si rifà uguale nella stanza vera
const STAGE = getStage("dojo");
const FLOOR_Y = STAGE.solids[0].y;
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


export interface World {
  a: Fighter;
  t: Fighter;
  fighters: Fighter[];
  ctx: PhysicsContext;
  tick: number;
  jumps: number; // salti già fatti nell'inseguimento
  gap: number; // pixel tra i due alla partenza
  match: boolean; // passi come quelli di Match (combattimento a GAME_SPEED): per il Dojo, che li rifà nella stanza vera
  keys: Keys[]; // i tasti di chi attacca, uno per tick da quando il mondo è nato
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
  return { a, t, fighters: [a, t], ctx, tick: w.tick, jumps: w.jumps, gap: w.gap, match: w.match, keys: w.keys.slice() };
}

function step(w: World, aKeys: Keys, tKeys: Keys = {}): GameEvent[] {
  w.a.input = { ...emptyInput(), ...aKeys };
  w.t.input = { ...emptyInput(), ...tKeys };
  w.ctx.events.length = 0;
  if (w.match) stepWorld(w.fighters, DT * GAME_SPEED, w.ctx, DT);
  else stepWorld(w.fighters, DT, w.ctx);
  w.keys.push(aKeys);
  w.tick++;
  return w.ctx.events;
}

// match: come una stanza d'allenamento (vite infinite, passi di Match); il primo di newWorld è il tick 0 del Dojo
export function newWorld(characterId: string, percent: number, gap: number, match = false): World {
  const ctx: PhysicsContext = { stage: STAGE, events: [], ...(match && { unlimitedStocks: true }) };
  const mk = (id: string, ch: string, index: number) => createFighter({ id, name: id, characterId: ch, color: 0, team: 0, index, stocks: 3 }, STAGE);
  const a = mk("a", characterId, 0);
  const t = mk("t", match ? DOJO.dummyCharacterId : "default", 1); // il bersaglio: un Bonobo (peso 1), nel Dojo il suo manichino
  a.x = DOJO.startX;
  t.x = a.x + gap;
  a.y = t.y = FLOOR_Y;
  a.facing = 1;
  t.facing = -1;
  const w: World = { a, t, fighters: [a, t], ctx, tick: 0, jumps: 0, gap, match, keys: [] };
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
export function open(characterId: string, m: LabMove, percent: number, match = false): World | null {
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
    const w = newWorld(characterId, percent, FIGHTER.width + 10, match);
    for (let i = 0; i < 30 && w.a.holding === null; i++) step(w, i === 0 ? { shield: true, light: true } : {});
    if (w.a.holding === null) return null;
    return hit(w, () => pressKeys(w, m, {}), 3);
  }
  if (m.id === "dashAttack") {
    for (const near of [150, 120, 90, 60]) {
      const w = newWorld(characterId, percent, 280, match);
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
        const w = newWorld(characterId, percent, FIGHTER.width + 10, match);
        const r = hit(w, (i) => (i === k ? pressKeys(w, m, {}) : { jump: i === 0 || (full && i < 20) }), k + 30);
        if (r) return r;
      }
    return null;
  }
  const gaps = [FIGHTER.width + 10, 110, 180, 260];
  for (const gap of m.hook ? gaps.reverse() : gaps) {
    const w = newWorld(characterId, percent, gap, match);
    const hold = m.holdTicks ?? 0;
    const r = hit(w, (i) => (i === 0 ? pressKeys(w, m, {}) : i < hold ? { special: true } : {}), 120);
    if (r) return r;
  }
  return null;
}

// Una catena di mosse da una percentuale: quanti colpi entrano di fila (il primo conta 1) e se tutti i legami sono veri
// match: per il Dojo, che vuole solo una catena che entra su un bersaglio fermo (senza le prove delle difese)
export function chain(characterId: string, ids: string[], percent: number, match = false): { hits: number; real: boolean; world: World | null } {
  const all = movesOf(characterId);
  const by = (id: string) => {
    const m = all.find((x) => x.id === id);
    if (!m) throw new Error(`${characterId}: mossa sconosciuta al laboratorio: ${id}`);
    return m;
  };
  let w: World | null = open(characterId, by(ids[0]), percent, match);
  if (!w) return { hits: 0, real: false, world: null };
  let real = true;
  for (let i = 1; i < ids.length; i++) {
    const m = by(ids[i]);
    const first: Link | undefined = follow(w, [m]).get(m.id);
    if (!first) return { hits: i, real: false, world: w };
    const link: Link = match ? first : confirm(w, m, first);
    real &&= link.result === "vera";
    w = link.world;
  }
  return { hits: ids.length, real, world: w };
}

export type Cell = "V" | "s" | "."; // vera, scappa, niente

// Una catena a tutte le percentuali: V lega davvero, s entra solo se il bersaglio non reagisce
export function chainCells(id: string, ids: string[]): Cell[] {
  return PERCENTS.map((p) => {
    const c = chain(id, ids, p);
    return c.hits < ids.length ? "." : c.real ? "V" : "s";
  });
}

// ---------------------------------------------------------------------------------------------------------------
// Il rapporto di un personaggio

// Una mossa da sola fatta a vuoto, per il Dojo quando non entra su un Bonobo fermo (il leggero in su, il recupero):
// da ferma a terra, o dopo un salto per quelle in aria. 40 tick dopo per vederla finire
export function showMove(characterId: string, id: string): World | null {
  const m = movesOf(characterId).find((x) => x.id === id);
  if (!m || m.thrown || m.id === "grab") return null;
  const w = newWorld(characterId, 0, 200, true);
  const air = m.where === "air";
  if (air) for (let i = 0; i < 12; i++) step(w, { jump: i < 8 });
  const hold = m.holdTicks ?? 1;
  for (let i = 0; i < hold; i++) step(w, i === 0 ? pressKeys(w, m, {}) : m.holdTicks ? { special: true } : {});
  for (let i = 0; i < 40; i++) step(w, {});
  return w;
}
