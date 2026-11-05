// Oggetti pesanti e da cavalcare (Nicola, 5 novembre 2026), come gear.ts: quello che fanno oltre a cadere,
// farsi raccogliere e farsi lanciare (items.ts). Ognuno ha la sua versione rara, alla The Binding of Isaac.
//   peso: la cassa che rotta lascia un oggetto (d'oro: tre), la lavatrice che va in centrifuga (impazzita: salta addosso)
//   cavalcatura: il monopattino (a razzo: va da solo e plana), il carrello che raccoglie chi investe (da tre: ne tiene tre)
// Numeri in RIDE (constants.ts), catalogo in ITEMS (items.ts).

import { characterStats } from "../characters";
import { FIGHTER, HITSTOP, HITSTUN_PER_KNOCKBACK, ITEM_RULES, RIDE } from "../constants";
import { ITEMS } from "../items";
import { bodyBox } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";
import { pickKind, type Item, type ItemWorld } from "./items";
import { clearStun, hitShield } from "./shield";
import { chargeFromHit } from "./supreme";

// Lo stato in più degli oggetti di questo modulo: non viaggia in rete, il client vede posizione ed eventi
interface RideState {
  spinMs?: number; // la lavatrice in centrifuga: ms che restano
  tickMs?: number; // ms al prossimo colpo della centrifuga
  hopMs?: number; // la lavatrice impazzita: ms al prossimo salto
  armed?: boolean; // la lavatrice scagliata: alla prossima volta a terra parte la centrifuga
  spinBy?: string; // chi l'ha scagliata: a lui i KO, lei non lo colpisce
  fuelMs?: number; // il monopattino a razzo: ms di razzo che restano
  chargeCd?: number; // ms prima del prossimo scatto
  ramCd?: Record<string, number>; // ms prima di poter investire di nuovo ognuno
  riders?: { id: string; ms: number }[]; // chi è dentro il carrello e da quanto
}
type RideItem = Item & RideState;

export const isHeavy = (kind: string) => ITEMS[kind]?.category === "peso";
export const isMount = (kind: string) => !!ITEMS[kind]?.mount;

// La lavatrice in centrifuga non si raccoglie (items.ts)
export const spinning = (item: Item) => ((item as RideItem).spinMs ?? 0) > 0;

// Chi porta un pesante o cavalca (Fighter.carrying), per movimento e salto. Si aggiorna dopo input e passo degli oggetti
export function markCarriers(world: ItemWorld, fighters: Fighter[]): void {
  for (const f of fighters) {
    const held = world.items.find((i) => i.heldBy === f.id && (isHeavy(i.kind) || isMount(i.kind)));
    f.carrying = held?.kind;
    if (!held) f.rideChargeMs = 0;
  }
}

// Quanto si va veloci (movement.ts)
export function rideSpeedMult(f: Fighter): number {
  if (!f.carrying) return 1;
  if (isHeavy(f.carrying)) return RIDE.heavy.speedMult;
  const spec = ITEMS[f.carrying];
  if (spec.mount === "carrello") return (spec.seats ?? 1) > 1 ? RIDE.cart.turboSpeedMult : RIDE.cart.speedMult;
  return RIDE.mount.speedMult;
}

// Quanto si salta (movement.ts)
export function rideJumpMult(f: Fighter): number {
  if (!f.carrying) return 1;
  return isHeavy(f.carrying) ? RIDE.heavy.jumpMult : RIDE.mount.jumpMult;
}

// Col monopattino a razzo in aria si cade piano (movement.ts)
export const rideGravityMult = (f: Fighter) => (f.carrying && ITEMS[f.carrying].mount === "razzo" && f.vy > 0 ? RIDE.rocket.gravityMult : 1);

// Lo scatto (J) e il razzo spingono in avanti da soli, sopra a quello che chiedono i tasti (applyControls in movement.ts)
export function rideDrive(f: Fighter): void {
  if (!f.carrying || f.hitstun) return;
  if ((f.rideChargeMs ?? 0) > 0) f.vx = f.facing * RIDE.mount.chargeSpeed;
  else if (ITEMS[f.carrying].mount === "razzo") f.vx = f.facing * RIDE.rocket.speed;
}

// J o K in sella (handleItemInput in items.ts): J scatta, o catapulta chi è nel carrello; K scende e il mezzo va avanti da solo
export function mountInput(item: Item, f: Fighter, light: boolean, ctx: PhysicsContext, fighters: Fighter[]): void {
  const it = item as RideItem;
  if (light) {
    if ((it.riders?.length ?? 0) > 0) return catapult(it, f, fighters, ctx);
    if ((it.chargeCd ?? 0) > 0) return;
    f.rideChargeMs = RIDE.mount.chargeMs;
    it.chargeCd = RIDE.mount.chargeCooldownMs;
    ctx.events.push({ type: "gear", phase: "charge", kind: item.kind, id: f.id, x: Math.round(f.x), y: Math.round(f.y) });
    return;
  }
  if ((it.riders?.length ?? 0) > 0) catapult(it, f, fighters, ctx);
  item.heldBy = null;
  item.thrown = true;
  item.thrownBy = f.id;
  item.vx = f.facing * RIDE.mount.dismountSpeed;
  item.vy = -ITEM_RULES.throwLift * 0.5;
  f.rideChargeMs = 0;
  f.carrying = undefined;
  f.vy = Math.min(f.vy, -FIGHTER.doubleJumpSpeed * 0.6); // si salta giù dal mezzo
  f.onGround = false;
  ctx.events.push({ type: "itemThrow", itemId: item.id, id: f.id, x: Math.round(item.x), y: Math.round(item.y) });
}

// Un oggetto in mano a holder, dopo il passo dei lottatori (stepItems in items.ts): il pesante sopra la testa, il mezzo
// sotto i piedi che investe chi tocca. Restituisce true se ha messo lui l'oggetto al suo posto
export function carried(world: ItemWorld, item: Item, holder: Fighter, fighters: Fighter[], dtMs: number, ctx: PhysicsContext): boolean {
  const spec = ITEMS[item.kind];
  if (isHeavy(item.kind)) {
    item.x = holder.x;
    item.y = holder.y - FIGHTER.height - 2;
    return true;
  }
  if (!spec.mount) return false;
  const it = item as RideItem;
  item.x = holder.x;
  item.y = holder.y;
  it.chargeCd = Math.max(0, (it.chargeCd ?? 0) - dtMs);
  holder.rideChargeMs = Math.max(0, (holder.rideChargeMs ?? 0) - dtMs);
  if (spec.mount === "razzo") {
    it.fuelMs = (it.fuelMs ?? RIDE.rocket.fuelMs) - dtMs;
    if (it.fuelMs <= 0) {
      rocketBoom(it, holder, fighters, ctx);
      return true;
    }
  }
  if (spec.mount === "carrello") holdRiders(it, holder, fighters, dtMs, ctx);
  ram(it, holder, fighters, dtMs, ctx);
  return true;
}

// Investire: chi va abbastanza svelto (o col razzo) colpisce chi tocca; il carrello invece lo raccoglie dentro
function ram(it: RideItem, holder: Fighter, fighters: Fighter[], dtMs: number, ctx: PhysicsContext) {
  const spec = ITEMS[it.kind];
  const cds = (it.ramCd ??= {});
  for (const id of Object.keys(cds)) cds[id] = Math.max(0, cds[id] - dtMs);
  if (Math.abs(holder.vx) < RIDE.mount.ramSpeed) return;
  const box = { x: it.x - spec.width / 2 - 6, y: it.y - spec.height - FIGHTER.height * 0.3, w: spec.width + 12, h: spec.height + FIGHTER.height * 0.3 };
  for (const t of fighters) {
    if (t === holder || t.eliminated || t.respawning || t.invulnerable || (cds[t.id] ?? 0) > 0) continue;
    if (ctx.canHit && !ctx.canHit(holder, t)) continue;
    if (it.riders?.some((r) => r.id === t.id)) continue;
    const b = bodyBox(t);
    if (!(box.x < b.x + b.w && box.x + box.w > b.x && box.y < b.y + b.h && box.y + box.h > b.y)) continue;
    cds[t.id] = RIDE.mount.ramCooldownMs;
    const dir = (Math.sign(holder.vx) || holder.facing) as 1 | -1;
    if (spec.mount === "carrello" && !t.shielding && (it.riders?.length ?? 0) < (spec.seats ?? 1)) {
      (it.riders ??= []).push({ id: t.id, ms: 0 });
      t.attack = null;
      t.attackActive = false;
      t.hitstunTimer = 0;
      t.hitstun = false;
      t.stunned = true;
      t.stunTimer = RIDE.cart.holdMs + 100;
      t.lastHitById = holder.id;
      ctx.events.push({ type: "gear", phase: "scoop", kind: it.kind, id: t.id, x: Math.round(t.x), y: Math.round(t.y) });
      continue;
    }
    const m = RIDE.mount;
    strike(t, holder, spec.damage, m.ramKnockback, m.ramGrowth, m.ramAngleDeg, dir, it.kind, ctx);
    ctx.events.push({ type: "gear", phase: "ram", kind: it.kind, id: t.id, x: Math.round(t.x), y: Math.round(t.y) });
  }
}

// Chi è nel carrello sta lì, stordito, finché non lo si catapulta, non lo colpisce qualcuno o non passa holdMs
function holdRiders(it: RideItem, holder: Fighter, fighters: Fighter[], dtMs: number, ctx: PhysicsContext) {
  if (!it.riders?.length) return;
  it.riders = it.riders.filter((r) => {
    const t = fighters.find((f) => f.id === r.id);
    return !!t && !t.eliminated && !t.respawning && !t.hitstun && t.stunned;
  });
  it.riders.forEach((r, k) => {
    const t = fighters.find((f) => f.id === r.id)!;
    r.ms += dtMs;
    t.x = holder.x + holder.facing * (k - 1) * 10;
    t.y = holder.y - RIDE.cart.seatLift - k * 6;
    t.vx = holder.vx;
    t.vy = 0;
    t.onGround = false;
    t.stunTimer = Math.max(t.stunTimer, 100);
  });
  if (it.riders.some((r) => r.ms >= RIDE.cart.holdMs)) catapult(it, holder, fighters, ctx);
}

// Fuori tutti dal carrello, in avanti e in alto
function catapult(it: RideItem, holder: Fighter, fighters: Fighter[], ctx: PhysicsContext) {
  const c = RIDE.cart;
  for (const r of it.riders ?? []) {
    const t = fighters.find((f) => f.id === r.id);
    if (!t) continue;
    clearStun(t);
    strike(t, holder, c.catapultDamage, c.catapultKnockback, c.catapultGrowth, c.catapultAngleDeg, holder.facing, it.kind, ctx);
  }
  it.riders = [];
  ctx.events.push({ type: "gear", phase: "launch", kind: it.kind, id: holder.id, x: Math.round(holder.x), y: Math.round(holder.y) });
}

// Il razzo finisce: scoppia sotto i piedi, il guidatore vola in alto (non si fa male) e il monopattino sparisce
function rocketBoom(it: RideItem, holder: Fighter, fighters: Fighter[], ctx: PhysicsContext) {
  const r = RIDE.rocket;
  it.heldBy = null;
  it.lifeMs = 0;
  holder.carrying = undefined;
  holder.vy = -FIGHTER.jumpSpeed;
  holder.onGround = false;
  ctx.events.push({ type: "gear", phase: "boom", kind: it.kind, id: holder.id, x: Math.round(it.x), y: Math.round(it.y), r: r.boomRadius });
  for (const t of fighters) {
    if (t === holder || t.eliminated || t.respawning || t.invulnerable) continue;
    if (ctx.canHit && !ctx.canHit(holder, t)) continue;
    const b = bodyBox(t);
    const nx = Math.max(b.x, Math.min(it.x, b.x + b.w));
    const ny = Math.max(b.y, Math.min(it.y, b.y + b.h));
    if ((nx - it.x) ** 2 + (ny - it.y) ** 2 > r.boomRadius ** 2) continue;
    strike(t, holder, r.boomDamage, r.boomKnockback, RIDE.mount.ramGrowth, 60, (Math.sign(t.x - it.x) || 1) as 1 | -1, it.kind, ctx);
  }
}

// Un oggetto non in mano, dopo volo e colpi (stepItems in items.ts). wasThrown: era in volo lanciato a inizio passo.
// La cassa scagliata si rompe dove colpisce o tocca terra; la lavatrice va in centrifuga; il carrello lasciato libera chi c'è dentro
export function stepRideItem(world: ItemWorld, item: Item, fighters: Fighter[], dtMs: number, ctx: PhysicsContext, wasThrown: boolean): void {
  const spec = ITEMS[item.kind];
  const it = item as RideItem;
  if (it.riders?.length) {
    for (const r of it.riders) {
      const t = fighters.find((f) => f.id === r.id);
      if (t) clearStun(t);
    }
    it.riders = [];
  }
  if (spec.crate && wasThrown && (item.lifeMs <= 0 || item.onGround)) return breakCrate(world, item, ctx);
  if (!spec.washer) return;
  if (wasThrown) {
    it.armed = true;
    it.spinBy ??= item.thrownBy ?? undefined;
    if (item.lifeMs <= 0) {
      // ha colpito qualcuno: non sparisce, rimbalza indietro e cade
      item.lifeMs = ITEM_RULES.lifeMs;
      item.vx *= -0.25;
    }
  }
  if (it.armed && item.onGround) {
    it.armed = false;
    it.spinMs = spec.washer === "matta" ? RIDE.washer.crazySpinMs : RIDE.washer.spinMs;
    it.tickMs = 0;
    it.hopMs = RIDE.washer.hopEveryMs;
    ctx.events.push({ type: "gear", phase: "spin", kind: item.kind, id: it.spinBy ?? "", x: Math.round(item.x), y: Math.round(item.y) });
  }
  if ((it.spinMs ?? 0) > 0) spin(it, fighters, dtMs, ctx);
}

// La cassa si rompe e ne escono oggetti della stanza (mai altre casse)
function breakCrate(world: ItemWorld, item: Item, ctx: PhysicsContext) {
  const spec = ITEMS[item.kind];
  item.lifeMs = 0;
  ctx.events.push({ type: "gear", phase: "break", kind: item.kind, id: item.thrownBy ?? "", x: Math.round(item.x), y: Math.round(item.y) });
  const kinds = world.kinds.filter((k) => !ITEMS[k].crate);
  if (kinds.length === 0) return;
  const n = spec.crate ?? 1;
  for (let k = 0; k < n; k++) {
    const kind = pickKind(world.random(), kinds);
    const spread = n === 1 ? 0 : (k / (n - 1)) * 2 - 1;
    const out: Item = {
      id: world.nextId++,
      kind,
      x: Math.round(item.x),
      y: Math.round(item.y - 4),
      vx: spread * RIDE.crate.popVx,
      vy: -RIDE.crate.popVy,
      heldBy: null,
      thrown: false,
      onGround: false,
      riding: -1,
      thrownBy: null,
      lifeMs: ITEM_RULES.lifeMs,
      loadMs: -1,
    };
    world.items.push(out);
    ctx.events.push({ type: "itemSpawn", itemId: out.id, kind, x: out.x, y: out.y });
  }
}

// La centrifuga: chi tocca la lavatrice prende un colpetto ogni tickMs; quella impazzita salta verso l'avversario più vicino
function spin(it: RideItem, fighters: Fighter[], dtMs: number, ctx: PhysicsContext) {
  const spec = ITEMS[it.kind];
  const w = RIDE.washer;
  it.spinMs = Math.max(0, (it.spinMs ?? 0) - dtMs);
  it.tickMs = (it.tickMs ?? 0) - dtMs;
  const by = fighters.find((f) => f.id === it.spinBy);
  const foes = fighters.filter((t) => t !== by && !t.eliminated && !t.respawning && !(by && ctx.canHit && !ctx.canHit(by, t)));
  if (spec.washer === "matta" && it.onGround) {
    it.hopMs = (it.hopMs ?? 0) - dtMs;
    if (it.hopMs <= 0 && it.spinMs > 0) {
      it.hopMs = w.hopEveryMs;
      let best: Fighter | null = null;
      for (const t of foes) if (!best || Math.abs(t.x - it.x) + Math.abs(t.y - it.y) < Math.abs(best.x - it.x) + Math.abs(best.y - it.y)) best = t;
      const dir = best ? Math.sign(best.x - it.x) || 1 : 0;
      it.vx = dir * w.hopVx;
      it.vy = -w.hopVy;
      it.onGround = false;
      ctx.events.push({ type: "gear", phase: "hop", kind: it.kind, id: it.spinBy ?? "", x: Math.round(it.x), y: Math.round(it.y) });
    }
  }
  if (it.tickMs > 0) return;
  it.tickMs = w.tickMs;
  const box = { x: it.x - spec.width / 2 - w.reach, y: it.y - spec.height - w.reach, w: spec.width + 2 * w.reach, h: spec.height + w.reach };
  for (const t of foes) {
    if (t.invulnerable) continue;
    const b = bodyBox(t);
    if (!(box.x < b.x + b.w && box.x + box.w > b.x && box.y < b.y + b.h && box.y + box.h > b.y)) continue;
    const dir = (Math.sign(t.x - it.x) || 1) as 1 | -1;
    if (t.shielding) {
      hitShield(t, it.spinBy ?? "", w.damage, dir, Math.round(t.x), Math.round(t.y - FIGHTER.height / 2), ctx);
      continue;
    }
    strike(t, by ?? null, w.damage, w.knockback, w.knockbackGrowth, w.angleDeg, dir, it.kind, ctx);
  }
}

// Un colpo dato da un oggetto di questo modulo: percentuale e volo come per gli oggetti lanciati, lo scudo para
function strike(t: Fighter, by: Fighter | null, damage: number, base: number, growth: number, angleDeg: number, dir: 1 | -1, itemKind: string, ctx: PhysicsContext) {
  const x = Math.round(t.x);
  const y = Math.round(t.y - FIGHTER.height / 2);
  if (t.shielding) {
    hitShield(t, by?.id ?? "", damage, dir, x, y, ctx);
    return;
  }
  t.percent = Math.min(999, t.percent + damage);
  if (by) chargeFromHit(by, t, damage);
  const knockback = (base + growth * t.percent) / characterStats(t.characterId).weight;
  const angle = (angleDeg * Math.PI) / 180;
  t.vx = dir * Math.cos(angle) * knockback;
  t.vy = -Math.sin(angle) * knockback;
  t.onGround = false;
  t.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
  t.hitstun = true;
  t.attack = null;
  t.attackActive = false;
  t.facing = (-dir) as 1 | -1;
  if (by) t.lastHitById = by.id;
  clearStun(t);
  t.hitstopTimer = Math.max(t.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * damage));
  ctx.events.push({ type: "hit", attackerId: by?.id ?? "", targetId: t.id, kind: "item", itemKind, damage, percent: t.percent, knockback: Math.round(knockback), x, y });
}
