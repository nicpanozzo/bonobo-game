// Il Cappello boomerang di Marcomunista (speciale neutra, Nicola 12/11/2026): il cappello va avanti frenando, si
// ferma a mezz'aria, poi torna da lui; colpisce una volta all'andata e una al ritorno. Fermo a mezz'aria ci si
// rimbalza sopra come Mario: un salto in più per volo, con un'onda d'urto lilla che manda in su chi è vicino.
// Finché il cappello è via, Marcomunista non può fluttuare (fattanza.ts)
import { HAT, HITSTOP } from "../constants";
import type { ProjectileSpecial } from "../characters";
import { bodyBox, canBeHit, launch, overlap } from "./attacks";
import { fattanzaLevel } from "./fattanza";
import type { Fighter, PhysicsContext } from "./fighter";
import { boxOf, specOf, type Projectile } from "./projectiles";
import { hitShield } from "./shield";

type End = (p: Projectile, reason: "hit" | "blocked" | "expired" | "wall") => void;

// Il cappello di f è in giro (tirato e non ancora ripreso)
export const hatAway = (f: Fighter, ctx: PhysicsContext): boolean =>
  !!ctx.projectiles?.list.some((p) => p.ownerId === f.id && !!specOf(p).boomerang);

export function stepHat(p: Projectile, sp: ProjectileSpecial, fighters: Fighter[], byId: Map<string, Fighter>, dtMs: number, ctx: PhysicsContext, end: End): void {
  const owner = byId.get(p.ownerId);
  if (!owner || owner.eliminated || owner.respawning) {
    end(p, "expired");
    return;
  }
  const dt = dtMs / 1000;
  p.hatDir ??= p.vx >= 0 ? 1 : -1;
  p.hatHit ??= [];
  p.ageMs += dtMs;
  const hover = HAT.hoverMs[fattanzaLevel(owner)];
  if (!p.hatBack && p.ageMs < HAT.outMs) {
    // Andata: frena fino a fermarsi
    p.vx = p.hatDir * sp.speed * (1 - p.ageMs / HAT.outMs);
    p.vy = 0;
    const next = { ...boxOf(p, sp), x: boxOf(p, sp).x + p.vx * dt };
    if (ctx.stage.solids.some((s) => overlap(next, { x: s.x, y: s.y, w: s.width, h: s.height }))) {
      p.ageMs = HAT.outMs; // contro un muro si ferma subito lì
      p.vx = 0;
    }
  } else if (!p.hatBack && p.ageMs < HAT.outMs + hover) {
    p.vx = p.vy = 0; // fermo a mezz'aria: ci si può rimbalzare sopra
    bounce(p, owner, fighters, ctx);
  } else {
    if (!p.hatBack) {
      p.hatBack = true;
      p.hatHit = []; // al ritorno può prendere di nuovo
    }
    // Ritorno: dritto verso le sue mani
    const tx = owner.x;
    const ty = owner.y - 60;
    const dx = tx - p.x;
    const dy = ty - p.y;
    const d = Math.hypot(dx, dy);
    if (d < HAT.catchPx || p.ageMs >= sp.lifeMs) {
      end(p, "expired"); // ripreso al volo
      return;
    }
    p.vx = (dx / d) * HAT.returnSpeed;
    p.vy = (dy / d) * HAT.returnSpeed;
  }
  p.x += p.vx * dt;
  p.y += p.vy * dt;
  strike(p, sp, owner, fighters, ctx);
}

// Il cappello colpisce chi tocca, una volta per tratto, e continua il suo giro
function strike(p: Projectile, sp: ProjectileSpecial, owner: Fighter, fighters: Fighter[], ctx: PhysicsContext): void {
  if (p.vx === 0 && p.vy === 0) return; // fermo non fa male: è una piattaforma
  const box = boxOf(p, sp);
  const dir: 1 | -1 = p.vx >= 0 ? 1 : -1;
  for (const t of fighters) {
    if (t === owner || !canBeHit(t) || t.away || p.hatHit!.includes(t.id)) continue;
    if (ctx.canHit && !ctx.canHit(owner, t)) continue;
    if (!overlap(box, bodyBox(t))) continue;
    p.hatHit!.push(t.id);
    const x = Math.round(p.x);
    const y = Math.round(p.y);
    if (t.shielding) {
      hitShield(t, owner.id, sp.damage, dir, x, y, ctx);
      continue;
    }
    launch(t, { ...owner, facing: dir }, "specialNeutral", x, y, ctx);
    t.hitstopTimer = Math.max(t.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * sp.damage));
  }
}

// Scendendo sul cappello fermo ci si rimbalza sopra, con l'onda d'urto
function bounce(p: Projectile, f: Fighter, fighters: Fighter[], ctx: PhysicsContext): void {
  if (f.onGround || f.vy <= 0 || f.hitstun || f.stunTimer > 0) return;
  if (f.hatBounces >= HAT.maxBounces[fattanzaLevel(f)]) return;
  if (Math.abs(f.x - p.x) > HAT.bounceHalfWidth || f.y < p.y - HAT.bounceAbovePx || f.y > p.y + HAT.bounceBelowPx) return;
  f.hatBounces++;
  f.vy = -HAT.bounceVy;
  f.y = Math.min(f.y, p.y - HAT.bounceAbovePx / 2);
  f.floatMs = 0; // e si può fluttuare di nuovo
  ctx.events.push({ type: "hatBounce", id: f.id, x: Math.round(p.x), y: Math.round(p.y) });
  for (const t of fighters) {
    if (t === f || !canBeHit(t) || t.away || (ctx.canHit && !ctx.canHit(f, t))) continue;
    const b = bodyBox(t);
    if (Math.hypot(t.x - p.x, b.y + b.h / 2 - p.y) > HAT.shockRadius) continue;
    launch(t, f, "specialNeutral", Math.round(t.x), Math.round(b.y + b.h / 2), ctx, undefined, HAT.shockHit);
  }
}
