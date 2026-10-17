// Rialzata al volo (TECH, come il tech di Smash e Brawlhalla): chi vola via stordito e preme scudo poco prima
// di toccare terra si rialza subito, fermo o rotolando nella direzione tenuta, ed è intoccabile per un attimo.
// Lo chiama stepFighter in index.ts: tickTech prima di muoversi, landTech dopo le collisioni.

import { TECH } from "../constants";
import type { Fighter, PhysicsContext } from "./fighter";

// Lo scudo appena premuto in volo da storditi apre la finestra; una pressione ogni lockoutMs
export function tickTech(f: Fighter, dtMs: number): void {
  f.techTimer = Math.max(0, f.techTimer - dtMs);
  f.techLockout = Math.max(0, f.techLockout - dtMs);
  if (f.hitstun && !f.onGround && f.input.shield && !f.prevInput.shield && f.techLockout === 0) {
    f.techTimer = TECH.windowMs;
    f.techLockout = TECH.lockoutMs;
  }
}

// Appena atterrati: con la finestra aperta lo stordimento finisce e si rotola (o ci si rialza sul posto)
export function landTech(f: Fighter, wasOnGround: boolean, ctx: PhysicsContext): void {
  if (!f.onGround || wasOnGround || !f.hitstun || f.techTimer === 0) return;
  const dir = (f.input.right ? 1 : 0) - (f.input.left ? 1 : 0);
  f.techTimer = 0;
  f.hitstunTimer = 0;
  f.hitstun = false;
  f.vx = dir * TECH.rollSpeed;
  f.vy = 0;
  f.dodgeTimer = TECH.rollMs; // si scivola come nella schivata: niente controlli fino alla fine
  f.invulnerableTimer = Math.max(f.invulnerableTimer, TECH.invulnerableMs);
  f.invulnerable = true;
  if (dir !== 0) f.facing = dir as 1 | -1;
  ctx.events.push({ type: "dodge", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: false });
}
