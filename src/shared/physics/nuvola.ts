// La Nuvola di Marcomunista (speciale laterale, Nicola 12/11/2026): una grossa nuvola lilla che avanza piano per
// lifeMs. Non fa danno: chi ci entra resta sballato (NUVOLA.sballoMs dopo esserne uscito), con gravità bassa e
// passo lento, così galleggia ed è facile da colpire in aria. Chi l'ha tirata ci può atterrare sopra una volta:
// si ferma, fa un saltello e riprende il doppio salto
import type { ProjectileSpecial } from "../characters";
import { FIGHTER, NUVOLA } from "../constants";
import { bodyBox, canBeHit, overlap } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";
import { boxOf, type Projectile } from "./projectiles";

type End = (p: Projectile, reason: "hit" | "blocked" | "expired" | "wall") => void;

export function stepCloud(p: Projectile, sp: ProjectileSpecial, fighters: Fighter[], byId: Map<string, Fighter>, dtMs: number, ctx: PhysicsContext, end: End): void {
  const owner = byId.get(p.ownerId);
  p.ageMs += dtMs;
  const z = ctx.stage.blastZone;
  if (!owner || p.ageMs >= sp.lifeMs || p.x < z.left || p.x > z.right) {
    end(p, "expired");
    return;
  }
  p.x += (p.vx * dtMs) / 1000;
  const box = boxOf(p, sp);
  for (const t of fighters) {
    if (t === owner || !canBeHit(t) || t.away || (ctx.canHit && !ctx.canHit(owner, t))) continue;
    if (overlap(box, bodyBox(t))) t.sballoMs = NUVOLA.sballoMs;
  }
  rest(p, box, owner, ctx);
}

// Lui che scende sulla nuvola ci si posa sopra: saltello e doppio salto di nuovo, una volta per nuvola
function rest(p: Projectile, box: { x: number; y: number; w: number; h: number }, f: Fighter, ctx: PhysicsContext): void {
  if (p.rested || f.onGround || f.vy <= 0 || f.hitstun) return;
  if (f.x < box.x || f.x > box.x + box.w || f.y < box.y || f.y > box.y + NUVOLA.restTopPx) return;
  p.rested = true;
  f.y = box.y;
  f.vy = -NUVOLA.restHopVy;
  f.jumpsLeft = Math.max(f.jumpsLeft, FIGHTER.maxJumps - 1);
  f.floatMs = 0;
  ctx.events.push({ type: "hatBounce", id: f.id, x: Math.round(f.x), y: Math.round(box.y) });
}
