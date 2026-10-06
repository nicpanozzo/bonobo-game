// Corsa, controllo in aria, salti, caduta veloce e gravità.

import { FIGHTER, FLAG, HITSTUN_AIR_DRAG, RECOVERY } from "../constants";
import { startAttack } from "./attacks";
import { pressed, type Fighter, type PhysicsContext } from "./fighter";

// Cosa fa il lottatore con i tasti premuti (solo se non è stordito)
export function applyControls(f: Fighter, dt: number, ctx: PhysicsContext): void {
  if (f.hitstun) {
    if (!f.onGround) f.vx *= HITSTUN_AIR_DRAG;
    return;
  }

  const dir = (f.input.right ? 1 : 0) - (f.input.left ? 1 : 0);
  const speed = f.carrier ? FLAG.carrierSpeed : 1; // la bandiera pesa
  // Durante un attacco da terra si resta fermi, in aria si mantiene lo slancio
  if (f.onGround) {
    f.vx = f.attack ? 0 : dir * FIGHTER.groundSpeed * speed;
  } else if (dir !== 0) {
    f.vx += dir * FIGHTER.airAccel * dt;
    const max = FIGHTER.airSpeed * speed;
    f.vx = Math.max(-max, Math.min(max, f.vx));
  } else {
    const slow = FIGHTER.airFriction * dt;
    f.vx = Math.abs(f.vx) <= slow ? 0 : f.vx - Math.sign(f.vx) * slow;
  }
  if (dir !== 0 && !f.attack) f.facing = dir as 1 | -1;

  // Recupero (#11): in aria, K premuto tenendo su. Vince sul salto se i due tasti arrivano insieme.
  if (!f.onGround && !f.attack && !f.recoveryUsed && f.input.up && pressed(f, "heavy")) {
    f.vy = -RECOVERY.speed;
    f.vx = dir * RECOVERY.drift;
    f.recoveryUsed = true;
    f.helpless = true;
    startAttack(f, "recovery", ctx);
    return;
  }

  // Salto e doppio salto
  if (pressed(f, "up") && f.jumpsLeft > 0) {
    ctx.events.push({ type: "jump", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: !f.onGround });
    f.vy = -(f.onGround ? FIGHTER.jumpSpeed : FIGHTER.doubleJumpSpeed);
    f.jumpsLeft -= 1;
    f.onGround = false;
  }

  // Giù: attraversa le piattaforme sottili, in aria cade più veloce
  if (pressed(f, "down")) f.dropTimer = FIGHTER.dropThroughMs;

  // Provocazione: solo da fermi a terra, la usano voci e animazioni (#16)
  if (pressed(f, "taunt") && f.onGround && !f.attack) ctx.events.push({ type: "taunt", id: f.id });
}

export function applyGravity(f: Fighter, dt: number): void {
  const fastFall = f.input.down && !f.hitstun;
  const maxFall = fastFall ? FIGHTER.fastFallSpeed : FIGHTER.maxFallSpeed;
  f.vy = Math.min(f.vy + FIGHTER.gravity * dt, f.hitstun ? Infinity : maxFall);
  if (fastFall && !f.onGround && f.vy > 0) f.vy = Math.max(f.vy, maxFall * 0.8);
}
