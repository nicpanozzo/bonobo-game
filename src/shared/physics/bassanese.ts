// Chiama Bassanese (idea di Nicola, 24 ottobre 2026). Chi raccoglie il telefono chiama il Bassanese: entra da un lato
// dell'arena e la attraversa tutta, di superficie in superficie, guardandosi in giro come chi cerca qualcosa, poi se ne
// va dall'altra parte. Chi tocca vola via, tranne chi l'ha chiamato e i suoi compagni.
//   callBassanese()  dalla raccolta del telefono (items.ts): prepara il giro
//   stepBassanese()  alla fine di stepWorld: avanza lungo il giro e colpisce
// Il giro si decide tutto alla chiamata, con le superfici dell'arena di quel momento, così il client non deve indovinarlo.

import { BASSANESE } from "../constants";
import { stageHeight, stageWidth, type Rect } from "../stages";
import type { BassaneseState } from "../types";
import { arcadeHit } from "./arcade";
import { bodyBox } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";

// Un tratto del giro: camminata, salto o occhiata in giro. y sono i piedi
interface Leg {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  ms: number;
  kind: "walk" | "jump" | "look";
  hop?: number; // salto: pixel sopra il punto più alto
}

export interface Bassanese {
  id: number;
  ownerId: string;
  legs: Leg[];
  leg: number; // il tratto in corso
  legMs: number; // ms passati nel tratto
  hitAt: Record<string, number>; // chi ha colpito -> tempo dell'arena
  x: number;
  y: number;
  facing: 1 | -1;
}

export interface BassaneseWorld {
  list: Bassanese[];
  nextId: number;
}

function bassaneseWorld(ctx: PhysicsContext): BassaneseWorld {
  ctx.bassanese ??= { list: [], nextId: 1 };
  return ctx.bassanese;
}

// Le superfici su cui si può camminare: piene e sottili, larghe abbastanza, dentro l'arena e non coperte da un blocco
function surfaces(ctx: PhysicsContext): Rect[] {
  const width = stageWidth(ctx.stage);
  const height = stageHeight(ctx.stage);
  const all = [...ctx.stage.solids, ...ctx.stage.platforms.map((p) => ({ x: p.x, y: p.y, width: p.width, height: 1 }))];
  const inside = (x: number, y: number, s: Rect) => x > s.x && x < s.x + s.width && y > s.y + 1 && y < s.y + s.height;
  return all
    .map((s) => {
      const left = Math.max(s.x, 0);
      return { x: left, y: s.y, width: Math.min(s.x + s.width, width) - left, height: s.height };
    })
    .filter((s) => s.width >= BASSANESE.minSurfacePx && s.y > 0 && s.y < height)
    .filter((s) => !ctx.stage.solids.some((o) => inside(s.x + s.width / 2, s.y - 2, o)));
}

const jumpLeg = (x0: number, y0: number, x1: number, y1: number, speed: number): Leg => ({
  x0,
  y0,
  x1,
  y1,
  kind: "jump",
  ms: Math.max(BASSANESE.jumpMinMs / speed, (Math.abs(x1 - x0) / (BASSANESE.jumpPxS * speed)) * 1000),
  hop: BASSANESE.hopPx,
});

// Il giro: entra da un lato, passa tutte le superfici in ordine da quel lato all'altro (ogni superficie da un capo
// all'altro, con un'occhiata in giro appena arriva) e salta fuori dall'altra parte
function route(dir: 1 | -1, tops: Rect[], ctx: PhysicsContext, speed: number): Leg[] {
  const width = stageWidth(ctx.stage);
  const legs: Leg[] = [];
  const first = tops[0];
  let x = dir > 0 ? -BASSANESE.enterPx : width + BASSANESE.enterPx;
  let y = first.y - BASSANESE.hopPx;
  for (const s of tops) {
    const near = dir > 0 ? s.x + BASSANESE.endInsetPx : s.x + s.width - BASSANESE.endInsetPx;
    const far = dir > 0 ? s.x + s.width - BASSANESE.endInsetPx : s.x + BASSANESE.endInsetPx;
    legs.push(jumpLeg(x, y, near, s.y, speed));
    legs.push({ x0: near, y0: s.y, x1: near, y1: s.y, ms: BASSANESE.lookMs / speed, kind: "look" });
    legs.push({ x0: near, y0: s.y, x1: far, y1: s.y, ms: (Math.abs(far - near) / (BASSANESE.walkPxS * speed)) * 1000, kind: "walk" });
    [x, y] = [far, s.y];
  }
  const out = dir > 0 ? width + BASSANESE.enterPx : -BASSANESE.enterPx;
  legs.push({ ...jumpLeg(x, y, out, y - BASSANESE.hopPx * 3, speed * 1.5), hop: BASSANESE.hopPx * 2 });
  return legs;
}

const totalMs = (legs: Leg[]) => legs.reduce((sum, l) => sum + l.ms, 0);

// Il telefono è stato raccolto da f: il Bassanese arriva dal lato più lontano, così attraversa l'arena verso di lui
export function callBassanese(f: Fighter, ctx: PhysicsContext): void {
  const world = bassaneseWorld(ctx);
  const all = surfaces(ctx);
  if (all.length === 0) return;
  const dir: 1 | -1 = f.x > stageWidth(ctx.stage) / 2 ? 1 : -1;
  all.sort((a, b) => dir * (a.x + a.width / 2 - (b.x + b.width / 2)));
  // Nelle arene piene di superfici (Bologna) ne visita alcune, sparse da un capo all'altro
  const n = Math.min(all.length, BASSANESE.maxSurfaces);
  const tops = n === all.length ? all : Array.from({ length: n }, (_, i) => all[Math.round((i * (all.length - 1)) / (n - 1))]);
  // Nelle arene grandi il giro starebbe troppo: si cammina più svelti (i salti corti non accelerano del tutto, si riprova)
  let speed = 1;
  let legs = route(dir, tops, ctx, speed);
  for (let i = 0; i < 3 && totalMs(legs) > BASSANESE.maxMs; i++) {
    speed *= totalMs(legs) / BASSANESE.maxMs;
    legs = route(dir, tops, ctx, speed);
  }
  const b: Bassanese = { id: world.nextId++, ownerId: f.id, legs, leg: 0, legMs: 0, hitAt: {}, x: legs[0].x0, y: legs[0].y0, facing: dir };
  world.list.push(b);
  ctx.events.push({ type: "bassanese", phase: "call", id: f.id, x: Math.round(f.x), y: Math.round(f.y) });
}

// Dove si trova lungo il tratto: in linea retta, i salti con un arco sopra il punto più alto
function place(b: Bassanese) {
  const l = b.legs[b.leg];
  const k = l.ms > 0 ? Math.min(1, b.legMs / l.ms) : 1;
  b.x = l.x0 + (l.x1 - l.x0) * k;
  b.y = l.y0 + (l.y1 - l.y0) * k - (l.kind === "jump" ? (Math.max(0, l.y0 - Math.min(l.y0, l.y1)) + (l.hop ?? 0)) * 4 * k * (1 - k) : 0);
  if (l.x1 !== l.x0) b.facing = l.x1 > l.x0 ? 1 : -1;
}

export function stepBassanese(fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  const world = ctx.bassanese;
  if (!world || world.list.length === 0) return;
  for (const b of world.list) {
    b.legMs += dtMs;
    while (b.leg < b.legs.length && b.legMs >= b.legs[b.leg].ms) {
      b.legMs -= b.legs[b.leg].ms;
      b.leg++;
    }
    if (b.leg >= b.legs.length) {
      ctx.events.push({ type: "bassanese", phase: "leave", id: b.ownerId, x: Math.round(b.x), y: Math.round(b.y) });
      continue;
    }
    place(b);
    hitWithBassanese(b, fighters, ctx);
  }
  world.list = world.list.filter((b) => b.leg < b.legs.length);
}

// Chi tocca il Bassanese vola via verso dove cammina; lo stesso lottatore non lo riprende subito
function hitWithBassanese(b: Bassanese, fighters: Fighter[], ctx: PhysicsContext) {
  const owner = fighters.find((f) => f.id === b.ownerId);
  const now = ctx.timeMs ?? 0;
  const half = BASSANESE.width / 2;
  for (const target of fighters) {
    if (target.id === b.ownerId || target.eliminated || target.respawning || target.invulnerable || target.away) continue;
    if (owner && ctx.canHit && !ctx.canHit(owner, target)) continue;
    if (now - (b.hitAt[target.id] ?? -Infinity) < BASSANESE.hitAgainMs) continue;
    const body = bodyBox(target);
    if (body.x > b.x + half || body.x + body.w < b.x - half || body.y > b.y || body.y + body.h < b.y - BASSANESE.height) continue;
    b.hitAt[target.id] = now;
    const y = Math.max(body.y, b.y - BASSANESE.height / 2);
    arcadeHit(target, owner ?? null, BASSANESE.damage, BASSANESE.knockback, BASSANESE.knockbackGrowth, BASSANESE.angleDeg, b.facing, target.x, y, "bassanese", ctx);
  }
}

// Quello che va nello snapshot, solo quando c'è un Bassanese in giro
export function bassaneseState(ctx: PhysicsContext): BassaneseState[] | undefined {
  const list = ctx.bassanese?.list;
  if (!list || list.length === 0) return undefined;
  return list.map((b) => ({
    id: b.id,
    ownerId: b.ownerId,
    x: Math.round(b.x),
    y: Math.round(b.y),
    facing: b.facing,
    phase: b.legs[b.leg].kind,
  }));
}
