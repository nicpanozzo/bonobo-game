// Attacchi: inizio, finestra attiva, hitbox e cosa succede a chi viene colpito.

import { characterStats } from "../characters";
import { ATTACKS, FIGHTER, HITSTOP, HITSTUN_PER_KNOCKBACK } from "../constants";
import type { AttackKind } from "../types";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { clearStun, hitShield } from "./shield";

export function tryStartAttack(f: Fighter, ctx: PhysicsContext): void {
  if (f.hitstun || f.attack || f.cooldownTimer > 0 || f.helpless || f.dodgeTimer > 0) return;
  if (pressed(f, "heavy")) startAttack(f, variant(f, "heavy"), ctx);
  else if (pressed(f, "light")) startAttack(f, variant(f, "light"), ctx);
}

// La variante viene dai tasti tenuti: su vince su tutto, poi l'aria, poi giù (a terra)
export function variant(f: Fighter, base: "light" | "heavy"): AttackKind {
  if (f.input.up) return `${base}Up`;
  if (!f.onGround) return `${base}Air`;
  if (f.input.down) return `${base}Down`;
  return base;
}

export function startAttack(f: Fighter, kind: AttackKind, ctx: PhysicsContext) {
  f.attack = kind;
  f.attackTimer = 0;
  f.cooldownTimer = ATTACKS[kind].cooldownMs;
  f.alreadyHit.clear();
  consume(f, "light", "heavy"); // anche il recupero e l'attacco dal bordo passano da qui
  ctx.events.push({ type: "attack", id: f.id, kind });
}

export function updateAttack(f: Fighter, dtMs: number): void {
  if (!f.attack) {
    f.attackActive = false;
    return;
  }
  const spec = ATTACKS[f.attack];
  f.attackTimer += dtMs;
  f.attackActive = f.attackTimer >= spec.startupMs && f.attackTimer < spec.startupMs + spec.activeMs;
  if (f.attackTimer >= spec.startupMs + spec.activeMs) {
    f.attack = null;
    f.attackActive = false;
  }
}

type Box = { x: number; y: number; w: number; h: number };

// Rettangolo del colpo, dalla parte in cui si guarda (boxX/boxY lo spostano per le varianti)
export function attackBox(f: Fighter): Box {
  const spec = ATTACKS[f.attack ?? "light"];
  const front = spec.boxX ?? FIGHTER.width / 2;
  const x = f.facing === 1 ? f.x + front : f.x - front - spec.range;
  const y = f.y + (spec.boxY ?? -FIGHTER.height * 0.7);
  return { x, y, w: spec.range, h: spec.height };
}

export function bodyBox(f: Fighter): Box {
  return { x: f.x - FIGHTER.width / 2, y: f.y - FIGHTER.height, w: FIGHTER.width, h: FIGHTER.height };
}

export function overlap(a: Box, b: Box): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

// La presa e i lanci (#109): niente hitbox, li gestisce grab.ts
export const isGrabKind = (kind: AttackKind) => kind === "grab" || kind.startsWith("throw");

export const canBeHit = (f: Fighter) => !f.eliminated && !f.respawning && !f.invulnerable;

export function resolveHits(fighters: Fighter[], ctx: PhysicsContext): void {
  for (const attacker of fighters) {
    if (!attacker.attackActive || !attacker.attack || attacker.eliminated || attacker.respawning) continue;
    if (isGrabKind(attacker.attack)) continue; // presa e lanci non colpiscono col rettangolo (grab.ts)
    const spec = ATTACKS[attacker.attack];
    const box = attackBox(attacker);
    for (const target of fighters) {
      if (target === attacker || !canBeHit(target) || attacker.alreadyHit.has(target.id)) continue;
      if (ctx.canHit && !ctx.canHit(attacker, target)) continue;
      const body = bodyBox(target);
      if (!overlap(box, body)) continue;

      attacker.alreadyHit.add(target.id);
      // Il fermo si somma a quello in corso solo fino al massimo (più colpi nello stesso tick)
      const stop = Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * spec.damage);
      attacker.hitstopTimer = Math.max(attacker.hitstopTimer, stop);
      target.hitstopTimer = Math.max(target.hitstopTimer, stop);
      // Punto d'impatto: il centro della parte di hitbox che tocca il bersaglio
      const ix = (Math.max(box.x, body.x) + Math.min(box.x + box.w, body.x + body.w)) / 2;
      const iy = (Math.max(box.y, body.y) + Math.min(box.y + box.h, body.y + body.h)) / 2;

      // Sullo scudo (#109): niente percentuale né knockback, solo punti di scudo
      if (target.shielding) {
        hitShield(target, attacker.id, spec.damage, attacker.facing, Math.round(ix), Math.round(iy), ctx);
        continue;
      }

      launch(target, attacker, attacker.attack, Math.round(ix), Math.round(iy), ctx);
    }
  }
}

// Il colpo vero: percentuale e volo nella direzione in cui guarda chi colpisce. Lo usano anche i lanci della presa
export function launch(target: Fighter, attacker: Fighter, kind: AttackKind, x: number, y: number, ctx: PhysicsContext): void {
  const spec = ATTACKS[kind];
  // Stile Smash/Brawlhalla: il danno non toglie vita, fa volare più lontano
  target.percent = Math.min(999, target.percent + spec.damage);
  const knockback = (spec.baseKnockback + spec.knockbackGrowth * target.percent) / characterStats(target.characterId).weight; // E11
  const angle = (spec.angleDeg * Math.PI) / 180;
  target.vx = attacker.facing * Math.cos(angle) * knockback;
  target.vy = -Math.sin(angle) * knockback;
  target.onGround = false;
  target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
  target.attack = null;
  target.attackActive = false;
  target.facing = (-attacker.facing) as 1 | -1;
  target.lastHitById = attacker.id;
  // Chi viene colpito può di nuovo usare il recupero (#11)
  target.recoveryUsed = false;
  target.helpless = false;
  clearStun(target);
  ctx.events.push({
    type: "hit",
    attackerId: attacker.id,
    targetId: target.id,
    kind,
    damage: spec.damage,
    percent: target.percent,
    knockback: Math.round(knockback),
    x,
    y,
  });
}
