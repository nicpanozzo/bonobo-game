// Mosse speciali (E10, #111): tasto speciale da fermi (neutra), con una direzione (laterale) o con giù.
// Quale mossa è, e con che numeri, lo dice il personaggio (specialsFor in characters.ts).
// Qui il motore dello scatto e del contrattacco; proiettili e carica arrivano col passo 3.

import { SPECIAL_KINDS, specialsFor, type SpecialSlot } from "../characters";
import { SPECIAL_MOVES } from "../constants";
import { launch, startAttack } from "./attacks";
import { consume, type Fighter, type PhysicsContext } from "./fighter";

// Il tasto speciale è stato premuto e si può attaccare (lo controlla tryStartAttack)
export function tryStartSpecial(f: Fighter, ctx: PhysicsContext): void {
  const slot: SpecialSlot = f.input.down ? "down" : f.input.left !== f.input.right ? "side" : "neutral";
  const sp = specialsFor(f.characterId)[slot];
  if (sp.type === "dash") {
    if (!f.onGround && f.airDashUsed) return; // in aria una volta sola fino all'atterraggio
    if (f.input.left !== f.input.right) f.facing = f.input.right ? 1 : -1;
    f.airDashUsed = !f.onGround;
    startAttack(f, SPECIAL_KINDS[slot], ctx);
    f.specialTimer = sp.startupMs + sp.durationMs + sp.endLagMs;
  } else if (sp.type === "counter") {
    startAttack(f, SPECIAL_KINDS[slot], ctx);
    f.specialTimer = sp.startupMs + sp.windowMs + sp.endLagMs;
  }
  else consume(f, "special"); // projectile e charge: col passo 3 (per ora il tasto non fa niente)
}

// Un passo della speciale in corso: true se si è fermi (controlli e attacchi saltano, la gravità resta)
export function specialing(f: Fighter, dtMs: number): boolean {
  if (f.onGround) f.airDashUsed = false;
  if (f.specialTimer <= 0) return false;
  if (f.hitstun) {
    f.specialTimer = 0; // colpiti: la mossa finisce
    return false;
  }
  f.specialTimer = Math.max(0, f.specialTimer - dtMs);
  if (f.attack === SPECIAL_KINDS.side && f.attackActive) {
    const sp = specialsFor(f.characterId).side;
    if (sp.type === "dash") {
      // Lo scatto: dritto in avanti, senza cadere
      f.vx = f.facing * sp.speed;
      f.vy = 0;
      return true;
    }
  }
  // Avvio e attesa finale: a terra fermi, in aria si frena (dopo lo scatto si andrebbe via a 900 px/s)
  f.vx = f.onGround ? 0 : f.vx * Math.pow(0.5, dtMs / SPECIAL_MOVES.airBrakeHalfLifeMs);
  return true;
}

// Il contrattacco è nella finestra in cui para
export function isCountering(f: Fighter): boolean {
  return f.attack === SPECIAL_KINDS.down && f.attackActive && specialsFor(f.characterId).down.type === "counter";
}

// Un colpo di attacker su chi contrattacca: lui non prende niente e risponde con un colpo più forte
export function counterHit(f: Fighter, attacker: Fighter, damage: number, x: number, y: number, ctx: PhysicsContext): void {
  const sp = specialsFor(f.characterId).down;
  if (sp.type !== "counter") return;
  f.facing = attacker.x >= f.x ? 1 : -1; // si gira verso chi ha colpito, anche se arrivava da dietro
  f.attack = null;
  f.attackActive = false;
  f.specialTimer = 0;
  f.cooldownTimer = 0;
  ctx.events.push({ type: "counter", id: f.id, attackerId: attacker.id, x, y });
  const answer = Math.max(sp.minDamage, damage * sp.multiplier);
  launch(attacker, f, SPECIAL_KINDS.down, Math.round(attacker.x), Math.round(attacker.y - 40), ctx, Math.round(answer * 10) / 10);
}
