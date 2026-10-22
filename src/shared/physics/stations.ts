// Postazioni dell'arena (#433), come in Lovers in a Dangerous Spacetime. Regole uguali per tutti i tipi:
// chi sta a terra sopra una postazione libera e preme attacco la usa; intanto resta fermo nel mondo e i suoi tasti
// guidano lei (su e giù mirano, attacco agisce, salto fa uscire). Un colpo o una presa lo buttano fuori, poi per
// STATION.reenterMs non rientra. Con `team` la usa solo quella squadra (fuori dalle modalità a squadre, chiunque).
//   useStation()    dentro stepFighter, al posto dei controlli: entra, mira, spara, carica, esce
//   stepStations()  alla fine di stepWorld: chi è stato colpito esce, casse e munizioni, palle di mortadella in volo
// Tipi: "bombarda" spara palle di mortadella ad arco (+1 punto torre alla squadra per ogni avversario preso);
// "munizioni" carica casse tenendo attacco, che dopo deliveryMs arrivano alla bombarda di `feeds`; "gru" cala pezzi del Tetris
// (crane.ts): destra/sinistra li spostano, attacco leggero o su li girano, attacco pesante li lascia cadere.

import { STATION } from "../constants";
import type { Station } from "../stages";
import type { CannonballState, StationState } from "../types";
import { arcadeHit, isArcade } from "./arcade";
import { bodyBox, canBeHit, overlap } from "./attacks";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { hangCells, newHeld, steerCrane, type Held } from "./crane";
import { pieceOn } from "./timed";

interface Slot {
  user: string | null;
  aim: number; // gradi
  ammo: number;
  readyAt: number; // tempo dell'arena da cui la bombarda spara di nuovo
  autoAt: number; // tempo dell'arena della prossima palla automatica (autoAmmoMs)
  loadAt: number | null; // munizioni: quando è pronta la cassa in carica
  crates: number[]; // munizioni: arrivo delle casse in salita
  held: Held | null; // gru: il pezzo appeso
  nextAt: number; // gru: tempo dell'arena da cui pende il pezzo nuovo
}

interface Ball extends CannonballState {
  from: number; // indice della bombarda che l'ha sparata
}

export interface StationWorld {
  slots: Slot[];
  balls: Ball[];
  nextId: number;
  points: Record<number, number>; // punti torre per squadra
  prize?: number; // premio: la squadra in testa ai punti torre congelata a prizeAtMs (0 = pareggio o nessun punto); prima, undefined
  reenter: Record<string, number>; // chi -> tempo dell'arena da cui può rientrare in una postazione
}

const now = (ctx: PhysicsContext) => ctx.timeMs ?? 0;
const aimRange = (s: Station): [number, number] => [s.aimMinDeg ?? STATION.aimMinDeg, s.aimMaxDeg ?? STATION.aimMaxDeg];
export const ammoMax = (s: Station) => s.ammoMax ?? STATION.ammoMax;

function world(ctx: PhysicsContext): StationWorld {
  const t = now(ctx);
  ctx.stations ??= {
    slots: (ctx.stage.stations ?? []).map((s) => {
      const [lo, hi] = aimRange(s);
      return { user: null, aim: Math.round((lo + hi) / 2), ammo: Math.min(STATION.startAmmo, ammoMax(s)), readyAt: 0, autoAt: t + (s.autoAmmoMs ?? Infinity), loadAt: null, crates: [], held: null, nextAt: 0 };
    }),
    balls: [],
    nextId: 1,
    points: {},
    reenter: {},
  };
  return ctx.stations;
}

// Premio (#433): a prizeAtMs si congela la squadra con più punti torre (strettamente: in pareggio nessuno).
// Si chiama a ogni tick prima di stageAt; la rivincita (resetStations) lo azzera. Torna la squadra del premio, 0 se nessuna
export function freezePrize(ctx: PhysicsContext): number {
  const at = ctx.stage.prizeAtMs;
  if (at === undefined) return 0;
  const w = world(ctx);
  if (w.prize === undefined && now(ctx) >= at) {
    const ranked = Object.entries(w.points).sort((a, b) => b[1] - a[1]);
    w.prize = ranked.length > 0 && ranked[0][1] > (ranked[1]?.[1] ?? 0) ? Number(ranked[0][0]) : 0;
  }
  return w.prize ?? 0;
}

// La squadra del premio già congelata (senza congelare), 0 se ancora no
export const prizeLeader = (ctx: PhysicsContext): number => ctx.stations?.prize ?? 0;

// Con i piedi sulla superficie della postazione
export const standingOn = (f: Fighter, s: Station) =>
  f.onGround && Math.abs(f.y - s.y) <= STATION.standTolerancePx && f.x >= s.x && f.x <= s.x + s.width;

// Fuori dalle modalità a squadre tutti hanno team 0 e possono usare tutto
export const mayUse = (f: Fighter, s: Station) => !s.team || !f.team || f.team === s.team;

const attackPressed = (f: Fighter) => pressed(f, "light") || pressed(f, "heavy");

function event(ctx: PhysicsContext, phase: "enter" | "exit" | "fire" | "load" | "ammo" | "boom", index: number, id: string | null, x: number, y: number) {
  ctx.events.push({ type: "station", phase, index, id, x: Math.round(x), y: Math.round(y) });
}

// Il perno della canna e la direzione in cui punta
export function barrel(s: Station, aim: number) {
  const a = (aim * Math.PI) / 180;
  const dir = s.dir ?? 1;
  return { x: s.x + s.width / 2, y: s.y - STATION.pivotPx, dx: dir * Math.cos(a), dy: -Math.sin(a) };
}

// true se f è (o entra adesso) in una postazione: stepFighter salta controlli, attacchi e gravità
export function useStation(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  const list = ctx.stage.stations;
  if (!list?.length) return false;
  const w = world(ctx);
  const t = now(ctx);
  if (f.station === undefined) {
    if (!f.onGround || f.attack || f.hitstun || f.grabbedBy || f.holding || f.shielding || f.input.shield || f.jumpSquatTimer > 0) return false;
    if (!attackPressed(f) || (w.reenter[f.id] ?? -Infinity) > t) return false;
    const i = list.findIndex((s, k) => w.slots[k].user === null && pieceOn(s, t) && mayUse(f, s) && standingOn(f, s));
    if (i < 0) return false;
    w.slots[i].user = f.id;
    f.station = i;
    consume(f, "light", "heavy"); // la pressione che fa entrare non spara
    f.vx = f.vy = 0;
    f.dashing = false;
    f.dashTimer = 0;
    event(ctx, "enter", i, f.id, f.x, f.y);
    return true;
  }
  const i = f.station;
  const s = list[i];
  const slot = w.slots[i];
  f.vx = f.vy = 0;
  if (pressed(f, "jump")) {
    consume(f, "jump");
    leave(f, w, i, ctx);
    return true;
  }
  if (s.kind === "bombarda") aimAndFire(f, s, slot, i, dtMs, w, ctx);
  else if (s.kind === "gru") {
    if (steerCrane(f, s, i, slot.held, dtMs, ctx)) {
      slot.held = null;
      slot.nextAt = t + STATION.gruCooldownMs;
    }
  } else loadCrate(f, s, slot, i, list, w, t, ctx);
  return true;
}

function aimAndFire(f: Fighter, s: Station, slot: Slot, i: number, dtMs: number, w: StationWorld, ctx: PhysicsContext) {
  const [lo, hi] = aimRange(s);
  const turn = (f.input.up ? 1 : 0) - (f.input.down ? 1 : 0);
  slot.aim = Math.max(lo, Math.min(hi, slot.aim + (turn * STATION.aimDegS * dtMs) / 1000));
  if (!attackPressed(f)) return;
  consume(f, "light", "heavy");
  const t = now(ctx);
  if (slot.ammo <= 0 || t < slot.readyAt) return;
  slot.ammo--;
  slot.readyAt = t + STATION.fireMs;
  const b = barrel(s, slot.aim);
  const x = b.x + b.dx * STATION.barrelPx;
  const y = b.y + b.dy * STATION.barrelPx;
  const speed = s.ballSpeedPxS ?? STATION.ballSpeedPxS;
  w.balls.push({ id: w.nextId++, ownerId: f.id, from: i, x, y, vx: b.dx * speed, vy: b.dy * speed });
  event(ctx, "fire", i, f.id, x, y);
}

// Attacco tenuto per loadMs: la cassa parte. Lasciato prima, la carica si perde. Con la bombarda già piena
// (contando le casse in salita) non si carica
function loadCrate(f: Fighter, s: Station, slot: Slot, i: number, list: Station[], w: StationWorld, t: number, ctx: PhysicsContext) {
  const fed = s.feeds !== undefined && list[s.feeds]?.kind === "bombarda" ? s.feeds : -1;
  if (!(f.input.light || f.input.heavy) || fed < 0) {
    slot.loadAt = null;
    return;
  }
  consume(f, "light", "heavy");
  const crate = s.crate ?? STATION.crate;
  if (slot.loadAt === null) {
    if (w.slots[fed].ammo + slot.crates.length * crate < ammoMax(list[fed])) slot.loadAt = t + (s.loadMs ?? STATION.loadMs);
    return;
  }
  if (t < slot.loadAt) return;
  slot.loadAt = null;
  slot.crates.push(t + (s.deliveryMs ?? STATION.deliveryMs));
  event(ctx, "load", i, f.id, f.x, s.y);
}

function leave(f: Fighter, w: StationWorld, i: number, ctx: PhysicsContext) {
  w.slots[i].user = null;
  w.slots[i].loadAt = null; // una carica interrotta si perde
  f.station = undefined;
  w.reenter[f.id] = now(ctx) + STATION.reenterMs;
  event(ctx, "exit", i, f.id, f.x, f.y);
}

// Alla fine del tick: fuori chi è stato colpito o preso (gli eventi da firstEvent in poi) o non può più starci;
// casse che arrivano, palle automatiche, palle di mortadella in volo
export function stepStations(fighters: Fighter[], dtMs: number, ctx: PhysicsContext, firstEvent = 0): void {
  const list = ctx.stage.stations;
  if (!list?.length) return;
  const w = world(ctx);
  const t = now(ctx);
  const struck = new Set<string>();
  for (let k = firstEvent; k < ctx.events.length; k++) {
    const e = ctx.events[k];
    if (e.type === "hit" || e.type === "grab") struck.add(e.targetId);
    else if (e.type === "hazard") struck.add(e.id);
  }
  list.forEach((s, i) => {
    const slot = w.slots[i];
    if (slot.user === null) return;
    const f = fighters.find((ff) => ff.id === slot.user);
    if (!f) {
      slot.user = null; // uscito dalla stanza
      slot.loadAt = null;
      return;
    }
    const out = struck.has(f.id) || f.hitstunTimer > 0 || f.grabbedBy !== null || f.stunned || f.respawning || f.eliminated || f.away || isArcade(f);
    if (out || f.station !== i || !pieceOn(s, t)) leave(f, w, i, ctx);
  });
  list.forEach((s, i) => {
    const slot = w.slots[i];
    if (s.kind === "munizioni" && slot.crates.some((at) => at <= t)) {
      const fed = s.feeds !== undefined ? list[s.feeds] : undefined;
      const arrived = slot.crates.filter((a) => a <= t).length;
      slot.crates = slot.crates.filter((a) => a > t);
      if (fed?.kind === "bombarda") {
        const target = w.slots[s.feeds!];
        target.ammo = Math.min(ammoMax(fed), target.ammo + arrived * (s.crate ?? STATION.crate));
        event(ctx, "ammo", s.feeds!, null, fed.x + fed.width / 2, fed.y);
      }
    }
    if (s.kind === "gru") {
      if (!pieceOn(s, t)) slot.held = null; // fuori finestra la gru non c'è
      else if (!slot.held && t >= slot.nextAt) slot.held = newHeld(s, ctx);
    }
    if (s.kind === "bombarda" && s.autoAmmoMs) {
      if (slot.ammo >= ammoMax(s)) slot.autoAt = t + s.autoAmmoMs; // piena: il conto riparte quando spara
      else if (t >= slot.autoAt) {
        slot.ammo++;
        slot.autoAt = t + s.autoAmmoMs;
      }
    }
  });
  stepBalls(fighters, dtMs, w, ctx);
}

// Le palle di mortadella: arco, poi si schiantano su un blocco pieno o su un lottatore. Fuori dall'arena spariscono
function stepBalls(fighters: Fighter[], dtMs: number, w: StationWorld, ctx: PhysicsContext) {
  if (w.balls.length === 0) return;
  const dt = dtMs / 1000;
  const r = STATION.ballRadiusPx;
  const z = ctx.stage.blastZone;
  const gone = new Set<Ball>();
  for (const b of w.balls) {
    b.vy += STATION.ballGravityPxS2 * dt;
    b.x += b.vx * dt;
    b.y += b.vy * dt;
    if (b.x < z.left || b.x > z.right || b.y < z.top || b.y > z.bottom) {
      gone.add(b);
      continue;
    }
    const box = { x: b.x - r, y: b.y - r, w: 2 * r, h: 2 * r };
    if (ctx.stage.solids.some((s) => overlap(box, { x: s.x, y: s.y, w: s.width, h: s.height }))) {
      gone.add(b);
      event(ctx, "boom", b.from, b.ownerId, b.x, b.y);
      continue;
    }
    const owner = fighters.find((f) => f.id === b.ownerId);
    for (const target of fighters) {
      if (target.id === b.ownerId || !canBeHit(target) || target.away) continue;
      if (owner && ctx.canHit && !ctx.canHit(owner, target)) continue; // niente fuoco amico se le regole non lo vogliono
      if (!overlap(box, bodyBox(target))) continue;
      const blocked = target.shielding;
      arcadeHit(target, owner ?? null, STATION.ballDamage, STATION.ballKnockback, STATION.ballKnockbackGrowth, STATION.ballAngleDeg, b.vx >= 0 ? 1 : -1, b.x, b.y, "mortadella", ctx);
      // Un punto torre per ogni avversario preso (non sullo scudo, non un compagno)
      if (!blocked && owner && owner.team > 0 && target.team !== owner.team) w.points[owner.team] = (w.points[owner.team] ?? 0) + 1;
      gone.add(b);
      event(ctx, "boom", b.from, b.ownerId, b.x, b.y);
      break;
    }
  }
  w.balls = w.balls.filter((b) => !gone.has(b));
}

// Rivincita: postazioni libere, munizioni, punti e gru da capo (i blocchi della gru stanno in ctx.arcade, che la rivincita azzera)
export function resetStations(fighters: Fighter[], ctx: PhysicsContext): void {
  ctx.stations = undefined;
  for (const f of fighters) f.station = undefined;
}

// Quello che va nello snapshot, solo nelle arene con postazioni
export function stationSnapshot(ctx: PhysicsContext): { stations?: StationState[]; cannonballs?: CannonballState[]; towerPoints?: Record<number, number>; prizeTeam?: number } {
  const list = ctx.stage.stations;
  if (!list?.length) return {};
  const w = world(ctx);
  return {
    ...(w.prize && { prizeTeam: w.prize }),
    stations: list.map((s, i) => {
      const slot = w.slots[i];
      if (s.kind === "gru") return { user: slot.user, readyAt: Math.round(slot.nextAt), ...(slot.held && { piece: { kind: slot.held.kind, cells: hangCells(s, slot.held) } }) };
      if (s.kind === "bombarda") return { user: slot.user, aim: Math.round(slot.aim), ammo: slot.ammo, readyAt: Math.round(slot.readyAt) };
      return { user: slot.user, ...(slot.loadAt !== null && { load: Math.round(slot.loadAt) }), crates: slot.crates.map(Math.round) };
    }),
    cannonballs: w.balls.map((b) => ({ id: b.id, ownerId: b.ownerId, x: Math.round(b.x), y: Math.round(b.y), vx: Math.round(b.vx), vy: Math.round(b.vy) })),
    towerPoints: { ...w.points },
  };
}
