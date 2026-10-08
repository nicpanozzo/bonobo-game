// Scatto (#199): a terra, due tocchi in fretta della stessa direzione fanno scattare il lottatore per
// DASH.durationMs; se si tiene la direzione si continua a correre. È movimento, non colpisce
// (diverso dalla speciale laterale "Scatto" di E10). Lo chiama applyControls in movement.ts.

import { characterStats } from "../characters";
import { DASH } from "../constants";
import type { Fighter, PhysicsContext } from "./fighter";

// Velocità a terra decisa dallo scatto o dalla corsa, oppure null: si cammina come sempre
export function stepDash(f: Fighter, dir: number, dtMs: number, ctx: PhysicsContext): number | null {
  f.dashTapTimer = Math.max(0, f.dashTapTimer - dtMs);
  // Il primo tocco conta solo se è breve: tenuto più di DASH.tapMaxMs è una camminata
  if (dir !== 0 && dir === f.dashTapDir) {
    f.dashHoldMs += dtMs;
    if (f.dashHoldMs > DASH.tapMaxMs) f.dashTapTimer = 0;
  }
  if (!f.onGround || f.attack || f.hitstun) {
    endDash(f);
    return null;
  }
  // Un tocco nuovo: la direzione appena premuta (prima era rilasciata o era l'altra)
  const prevDir = (f.prevInput.right ? 1 : 0) - (f.prevInput.left ? 1 : 0);
  if (dir !== 0 && dir !== prevDir) {
    if (f.dashByTap && !f.dashing && f.dashTapTimer > 0 && f.dashTapDir === dir) startDash(f, dir as 1 | -1, ctx);
    f.dashTapDir = dir;
    f.dashTapTimer = DASH.doubleTapMs;
    f.dashHoldMs = 0;
  }
  if (!f.dashing) return null;
  const speed = characterStats(f.characterId).speed;
  if (dir === -f.facing) {
    endDash(f); // girarsi ferma lo scatto: si cammina dall'altra parte
    return null;
  }
  if (f.dashTimer > 0) {
    f.dashTimer = Math.max(0, f.dashTimer - dtMs);
    return f.facing * DASH.speed * speed; // lo scatto va fino in fondo anche lasciando il tasto
  }
  if (dir === f.facing) return f.facing * DASH.runSpeed * speed; // tenendo premuto si corre
  endDash(f);
  return null;
}

function startDash(f: Fighter, dir: 1 | -1, ctx: PhysicsContext): void {
  f.dashing = true;
  f.dashTimer = DASH.durationMs;
  f.facing = dir;
  ctx.events.push({ type: "dash", id: f.id, x: Math.round(f.x), y: Math.round(f.y) });
}

export function endDash(f: Fighter): void {
  f.dashing = false;
  f.dashTimer = 0;
}
