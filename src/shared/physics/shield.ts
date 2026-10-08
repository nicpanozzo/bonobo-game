// Scudo (#109, E8 passo 1): tenuto a terra para i colpi da ogni lato. Il colpo parato toglie punti di scudo
// invece di dare percentuale e knockback; lo scudo si consuma anche da solo e a 0 si rompe: saltino e stordimento.
// Su fa saltare fuori dallo scudo, una direzione (o la schivata) fa rotolare con la schivata che c'è già (#3).

import { INPUT, SHIELD } from "../constants";
import { pressed, type Fighter, type PhysicsContext } from "./fighter";

// Un passo di scudo e stordimento. true se si è fermi (scudo alzato, colpo parato, attesa dopo averlo
// abbassato, stordimento): il resto del passo salta controlli e attacchi, gravità e movimento restano.
export function holdShield(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  const dt = dtMs / 1000;

  // Stordito dopo la rottura: fermo e colpibile. Un colpo vero lo fa finire (resolveHits)
  if (f.stunTimer > 0) {
    f.stunTimer = Math.max(0, f.stunTimer - dtMs);
    f.stunned = f.stunTimer > 0;
    slide(f, dt);
    return true;
  }
  f.stunned = false;

  // Un colpo vero (es. una trappola, che lo scudo non para) lo abbassa subito
  if (f.hitstun) {
    lower(f);
    f.shieldStunTimer = 0;
    return false;
  }

  // Fermi sullo scudo dopo un colpo parato, scivolando indietro
  if (f.shieldStunTimer > 0) {
    f.shieldStunTimer = Math.max(0, f.shieldStunTimer - dtMs);
    slide(f, dt);
    return true;
  }

  if (f.input.shield && f.onGround && !f.attack && f.dodgeTimer === 0) {
    // Fuori dallo scudo senza attesa: il salto salta, una direzione o la schivata rotolano (la schivata va nel buffer, E6)
    if (pressed(f, "jump") || pressed(f, "dodge")) {
      lower(f);
      return false;
    }
    if (pressed(f, "left") || pressed(f, "right")) {
      lower(f);
      f.buffer.dodge = INPUT.bufferMs;
      return false;
    }
    f.shieldTimer += dtMs;
    f.shielding = f.shieldTimer >= SHIELD.raiseMs;
    if (f.shielding) {
      f.shieldHp -= SHIELD.drainPerSec * dt;
      if (f.shieldHp <= 0) {
        breakShield(f, ctx);
        return true;
      }
    }
    slide(f, dt);
    return true;
  }

  // Abbassato: a terra si resta fermi un attimo
  if (f.shieldTimer > 0) {
    if (f.shielding && f.onGround) f.shieldDropTimer = SHIELD.dropMs;
    lower(f);
  }
  f.shieldHp = Math.min(SHIELD.maxHp, f.shieldHp + SHIELD.regenPerSec * dt);
  if (f.shieldDropTimer > 0) {
    f.shieldDropTimer = Math.max(0, f.shieldDropTimer - dtMs);
    slide(f, dt);
    return true;
  }
  return false;
}

// Un colpo (attacco o oggetto) preso sullo scudo: toglie punti, spinge indietro nella direzione dir e ferma un attimo
export function hitShield(f: Fighter, attackerId: string, damage: number, dir: 1 | -1, x: number, y: number, ctx: PhysicsContext): void {
  f.shieldHp -= damage;
  f.vx = dir * (SHIELD.pushBase + SHIELD.pushPerDamage * damage);
  f.shieldStunTimer = SHIELD.stunBaseMs + SHIELD.stunPerDamageMs * damage;
  ctx.events.push({ type: "shield", id: f.id, attackerId, damage, shieldHp: Math.max(0, Math.round(f.shieldHp)), x, y });
  if (f.shieldHp <= 0) breakShield(f, ctx);
}

// Si rientra dopo un KO con lo scudo pieno e senza stordimento
export function resetShield(f: Fighter): void {
  lower(f);
  clearStun(f);
  f.shieldStunTimer = 0;
  f.shieldDropTimer = 0;
  f.shieldHp = SHIELD.maxHp;
}

// Un colpo vero sveglia chi è stordito
export function clearStun(f: Fighter): void {
  f.stunTimer = 0;
  f.stunned = false;
}

function breakShield(f: Fighter, ctx: PhysicsContext): void {
  lower(f);
  f.shieldStunTimer = 0;
  f.shieldDropTimer = 0;
  f.shieldHp = SHIELD.hpAfterBreak;
  f.stunTimer = SHIELD.breakStunMs;
  f.stunned = true;
  f.vx = 0;
  f.vy = -SHIELD.breakPopSpeed;
  f.onGround = false;
  ctx.events.push({ type: "shieldBreak", id: f.id, x: Math.round(f.x), y: Math.round(f.y) });
}

function lower(f: Fighter): void {
  f.shielding = false;
  f.shieldTimer = 0;
}

// A terra la scivolata si ferma piano; in aria si tiene lo slancio
function slide(f: Fighter, dt: number): void {
  if (!f.onGround) return;
  const slow = SHIELD.pushFriction * dt;
  f.vx = Math.abs(f.vx) <= slow ? 0 : f.vx - Math.sign(f.vx) * slow;
}
