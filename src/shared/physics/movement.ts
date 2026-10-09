// Corsa, controllo in aria, salti, caduta veloce e gravità.

import { characterStats } from "../characters";
import { DODGE, FIGHTER, FLAG, HITSTUN_AIR_DRAG, RECOVERY } from "../constants";
import { startAttack } from "./attacks";
import { endDash, stepDash } from "./dash";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";

// Cosa fa il lottatore con i tasti premuti (solo se non è stordito)
export function applyControls(f: Fighter, dt: number, ctx: PhysicsContext): void {
  const dir = (f.input.right ? 1 : 0) - (f.input.left ? 1 : 0);

  if (f.hitstun) {
    endDash(f);
    f.jumpRising = false;
    if (!f.onGround) {
      f.vx *= HITSTUN_AIR_DRAG;
      // Influenza: tenendo una direzione si corregge un po' il volo, così chi sa dove andare sopravvive di più
      f.vx += dir * FIGHTER.hitstunDriftAccel * dt;
    }
    return;
  }

  // Salto corto: lasciando il tasto mentre si sale si perde parte della spinta
  if (f.jumpRising) {
    if (f.vy >= 0) f.jumpRising = false;
    else if (!f.input.jump && f.shortHop) {
      f.vy *= FIGHTER.shortHopCut;
      f.jumpRising = false;
    }
  }

  // Schivata (#3): mentre dura si scivola alla velocità decisa all'inizio, senza controlli né attacchi
  if (f.dodgeTimer > 0) {
    endDash(f);
    return;
  }
  if (pressed(f, "dodge") && !f.attack && f.dodgeCooldown === 0 && (f.onGround || !f.airDodgeUsed)) {
    consume(f, "dodge");
    f.dodgeTimer = DODGE.durationMs;
    f.dodgeCooldown = DODGE.cooldownMs;
    f.invulnerableTimer = Math.max(f.invulnerableTimer, DODGE.durationMs);
    f.invulnerable = true;
    f.vx = dir * DODGE.speed;
    if (!f.onGround) {
      f.airDodgeUsed = true;
      f.vy = 0; // in aria ci si ferma un attimo, come in Brawlhalla
    }
    if (dir !== 0) f.facing = dir as 1 | -1;
    ctx.events.push({ type: "dodge", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: !f.onGround });
    return;
  }
  const stats = characterStats(f.characterId);
  const speed = f.carrier ? FLAG.carrierSpeed : 1; // la bandiera pesa
  // Durante un attacco da terra si resta fermi, in aria si mantiene lo slancio
  const dashSpeed = stepDash(f, dir, dt * 1000, ctx); // scatto e corsa (#199)
  if (f.onGround && dashSpeed !== null) {
    f.vx = dashSpeed * speed;
  } else if (f.onGround) {
    f.vx = f.attack ? 0 : dir * FIGHTER.groundSpeed * stats.speed * speed;
  } else if (dir !== 0) {
    f.vx += dir * FIGHTER.airAccel * dt;
    const max = FIGHTER.airSpeed * stats.airSpeed * speed;
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
    f.jumpRising = false; // la spinta ora è del recupero: lasciare il salto non la accorcia
    startAttack(f, "recovery", ctx);
    return;
  }

  // Salto e doppio salto
  if (pressed(f, "jump") && f.jumpsLeft > 0) {
    consume(f, "jump"); // una pressione = un salto solo
    const fromGround = f.onGround || f.coyoteTimer > 0; // appena scesi dal bordo vale ancora da terra
    ctx.events.push({ type: "jump", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: !fromGround });
    f.vy = -(fromGround ? FIGHTER.jumpSpeed : FIGHTER.doubleJumpSpeed) * stats.jump;
    f.jumpsLeft -= 1;
    f.onGround = false;
    f.coyoteTimer = 0;
    f.jumpRising = true;
  }

  // Giù: attraversa le piattaforme sottili, in aria cade più veloce
  if (pressed(f, "down")) f.dropTimer = FIGHTER.dropThroughMs;

  // Provocazione: solo da fermi a terra, la usano voci e animazioni (#16)
  if (pressed(f, "taunt") && f.onGround && !f.attack) ctx.events.push({ type: "taunt", id: f.id });
}

// Finito il tempo di grazia senza saltare, il salto da terra è perso (resta quello in aria)
export function tickCoyote(f: Fighter, dtMs: number): void {
  if (f.coyoteTimer === 0) return;
  f.coyoteTimer = Math.max(0, f.coyoteTimer - dtMs);
  if (f.onGround || f.ledgeIndex >= 0) f.coyoteTimer = 0; // a terra o appesi al bordo non serve più
  else if ((f.coyoteTimer === 0 || f.hitstunTimer > 0) && f.jumpsLeft === FIGHTER.maxJumps) {
    f.coyoteTimer = 0;
    f.jumpsLeft = FIGHTER.maxJumps - 1;
  }
}

export function applyGravity(f: Fighter, dt: number): void {
  const fastFall = f.input.down && !f.hitstun;
  const maxFall = fastFall ? FIGHTER.fastFallSpeed : FIGHTER.maxFallSpeed;
  f.vy = Math.min(f.vy + FIGHTER.gravity * characterStats(f.characterId).gravity * dt, f.hitstun ? Infinity : maxFall);
  if (fastFall && !f.onGround && f.vy > 0) f.vy = Math.max(f.vy, maxFall * 0.8);
}
