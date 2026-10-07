// Presa e lanci (#109, E8 passo 2): scudo + leggero afferra chi sta davanti, anche se si para.
// Chi tiene dà colpetti col leggero o lancia nella direzione tenuta; chi è tenuto preme tasti per liberarsi.
// Il triangolo: l'attacco batte la presa (un colpo nello stesso tick vince), la presa batte lo scudo.

import { GRAB } from "../constants";
import type { AttackKind, InputState } from "../types";
import { attackBox, attackSpecFor, bodyBox, canBeHit, launch, overlap, startAttack } from "./attacks";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { clearStun } from "./shield";

// Si tiene qualcuno o si è tenuti: la posizione la decide stepGrabs, il resto del passo salta
export const inGrab = (f: Fighter) => f.holding !== null || f.grabbedBy !== null;

// Prima del movimento: fa partire la presa e tiene fermo chi la sta facendo. true se si è fermi
export function grabbing(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  if (f.hitstun) f.grabLagTimer = 0; // colpito durante la presa: la presa sfuma
  if (f.grabLagTimer > 0) {
    f.grabLagTimer = Math.max(0, f.grabLagTimer - dtMs);
    if (f.onGround) f.vx = 0;
    return true;
  }
  if (!canStartGrab(f)) return false;
  startAttack(f, "grab", ctx);
  f.shielding = false; // la presa parte anche dallo scudo alzato
  f.shieldTimer = 0;
  const spec = attackSpecFor(f, "grab");
  f.grabLagTimer = spec.startupMs + spec.activeMs + GRAB.whiffLagMs;
  f.vx = 0;
  return true;
}

function canStartGrab(f: Fighter): boolean {
  return (
    f.input.shield &&
    pressed(f, "light") &&
    f.onGround &&
    !f.attack &&
    f.cooldownTimer === 0 &&
    !f.hitstun &&
    f.stunTimer === 0 &&
    f.shieldStunTimer === 0 &&
    f.dodgeTimer === 0 &&
    f.ledge === null &&
    !f.helpless
  );
}

// Dopo i colpi: la presa attiva afferra il più vicino nel suo rettangolo. Chi è appena stato colpito
// (o ha perso la presa perché colpito) non entra: il colpo nello stesso tick vince
export function resolveGrabs(fighters: Fighter[], ctx: PhysicsContext): void {
  for (const f of fighters) {
    if (f.attack !== "grab" || !f.attackActive || inGrab(f) || f.hitstunTimer > 0) continue;
    const box = attackBox(f);
    let best: Fighter | null = null;
    for (const t of fighters) {
      if (t === f || !canBeHit(t) || inGrab(t) || t.hitstunTimer > 0 || t.ledge !== null) continue;
      if (ctx.canHit && !ctx.canHit(f, t)) continue;
      if (!overlap(box, bodyBox(t))) continue;
      if (!best || Math.abs(t.x - f.x) < Math.abs(best.x - f.x)) best = t;
    }
    if (best) connect(f, best, ctx);
  }
}

function connect(f: Fighter, t: Fighter, ctx: PhysicsContext): void {
  f.holding = t.id;
  f.attack = null;
  f.attackActive = false;
  f.grabLagTimer = 0;
  f.cooldownTimer = 0;
  f.pummelTimer = 0;
  f.vx = 0;
  t.grabbedBy = f.id;
  t.grabTimer = GRAB.holdBaseMs + GRAB.holdPerPercentMs * t.percent;
  t.attack = null;
  t.attackActive = false;
  t.dodgeTimer = 0;
  t.shielding = false;
  t.shieldTimer = 0;
  t.shieldStunTimer = 0;
  t.shieldDropTimer = 0;
  t.lastHitById = f.id;
  clearStun(t);
  place(f, t);
  ctx.events.push({ type: "grab", id: f.id, targetId: t.id, x: Math.round(t.x), y: Math.round(t.y) });
}

// Prima del passo dei lottatori: tenuta, divincolarsi, colpetti e lanci
export function stepGrabs(fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  const byId = new Map(fighters.map((f) => [f.id, f]));
  for (const holder of fighters) {
    if (holder.holding === null) continue;
    const target = byId.get(holder.holding);
    // Un colpo, un KO o un'uscita dalla stanza spezzano la presa
    if (!target || target.grabbedBy !== holder.id || broken(holder) || broken(target)) {
      holder.holding = null;
      if (target?.grabbedBy === holder.id) target.grabbedBy = null;
      continue;
    }
    target.grabTimer -= dtMs + GRAB.mashMs * newPresses(target);
    if (target.grabTimer <= 0) {
      release(holder, target, ctx);
      continue;
    }
    const kind = throwKind(holder);
    if (kind) {
      throwTarget(holder, target, kind, ctx);
      continue;
    }
    holder.pummelTimer = Math.max(0, holder.pummelTimer - dtMs);
    if (pressed(holder, "light") && holder.pummelTimer === 0) pummel(holder, target, ctx);
    place(holder, target);
  }
  // Chi tiene non c'è più (o non tiene più lui): si è liberi
  for (const f of fighters) {
    if (f.grabbedBy !== null && byId.get(f.grabbedBy)?.holding !== f.id) f.grabbedBy = null;
  }
}

const broken = (f: Fighter) => f.eliminated || f.respawning || f.away || f.hitstunTimer > 0;

// Tasti appena premuti: ognuno accorcia la tenuta di GRAB.mashMs
function newPresses(f: Fighter): number {
  let n = 0;
  for (const key of Object.keys(f.input) as (keyof InputState)[]) if (f.input[key] && !f.prevInput[key]) n++;
  return n;
}

// La direzione tenuta da chi tiene sceglie il lancio: su e giù vincono su avanti e indietro
function throwKind(f: Fighter): AttackKind | null {
  if (f.input.up) return "throwUp";
  if (f.input.down) return "throwDown";
  if (f.input.left === f.input.right) return null;
  const dir = f.input.right ? 1 : -1;
  return dir === f.facing ? "throwForward" : "throwBack";
}

function throwTarget(holder: Fighter, target: Fighter, kind: AttackKind, ctx: PhysicsContext): void {
  holder.holding = null;
  target.grabbedBy = null;
  startAttack(holder, kind, ctx);
  holder.grabLagTimer = attackSpecFor(holder, kind).cooldownMs; // fermi mentre si lancia
  // throwBack ha l'angolo oltre 90°: con lo stesso verso di chi tiene, il bersaglio vola dietro di lui
  launch(target, holder, kind, Math.round(target.x), Math.round(target.y - 40), ctx);
}

function pummel(holder: Fighter, target: Fighter, ctx: PhysicsContext): void {
  consume(holder, "light");
  holder.pummelTimer = GRAB.pummelEveryMs;
  target.percent = Math.min(999, target.percent + GRAB.pummelDamage);
  ctx.events.push({
    type: "hit",
    attackerId: holder.id,
    targetId: target.id,
    kind: "grab",
    damage: GRAB.pummelDamage,
    percent: target.percent,
    knockback: 0,
    x: Math.round(target.x),
    y: Math.round(target.y - 40),
  });
}

// Liberato: ci si allontana un po' tutti e due
function release(holder: Fighter, target: Fighter, ctx: PhysicsContext): void {
  holder.holding = null;
  target.grabbedBy = null;
  target.vx = holder.facing * GRAB.releaseSpeed;
  holder.vx = -holder.facing * GRAB.releaseSpeed;
  ctx.events.push({ type: "grabRelease", id: holder.id, targetId: target.id });
}

// Chi è tenuto sta davanti a chi lo tiene, voltato verso di lui
function place(holder: Fighter, target: Fighter): void {
  target.x = holder.x + holder.facing * GRAB.holdDistance;
  target.y = holder.y;
  target.vx = target.vy = 0;
  target.onGround = holder.onGround;
  target.facing = (-holder.facing) as 1 | -1;
}
