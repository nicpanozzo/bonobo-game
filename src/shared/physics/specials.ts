// Mosse speciali (E10, #111): tasto speciale da fermi (neutra), con una direzione (laterale) o con giù.
// Quale mossa è, e con che numeri, lo dice il personaggio (specialsFor in characters.ts).
// Qui il motore di scatto, contrattacco, carica e tiro; il volo dei proiettili è in projectiles.ts.

import { SPECIAL_KINDS, specialsFor, type SpecialSlot } from "../characters";
import { SPECIAL_MOVES } from "../constants";
import type { SpecialKind } from "../types";
import { launch, startAttack } from "./attacks";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { aliveOf, fire } from "./projectiles";

const SLOT_OF = Object.fromEntries(Object.entries(SPECIAL_KINDS).map(([slot, kind]) => [kind, slot])) as Record<SpecialKind, SpecialSlot>;
const specOf = (f: Fighter, kind: SpecialKind) => specialsFor(f.characterId)[SLOT_OF[kind]];

// Il tasto speciale è stato premuto e si può attaccare (lo controlla tryStartAttack)
export function tryStartSpecial(f: Fighter, ctx: PhysicsContext): void {
  const slot: SpecialSlot = f.input.down ? "down" : f.input.left !== f.input.right ? "side" : "neutral";
  const kind = SPECIAL_KINDS[slot];
  const sp = specialsFor(f.characterId)[slot];
  if (sp.type === "dash") {
    if (!f.onGround && f.airDashUsed) return; // in aria una volta sola fino all'atterraggio
    if (f.input.left !== f.input.right) f.facing = f.input.right ? 1 : -1;
    f.airDashUsed = !f.onGround;
    startAttack(f, kind, ctx);
    f.specialTimer = sp.startupMs + sp.durationMs + sp.endLagMs;
  } else if (sp.type === "counter") {
    startAttack(f, kind, ctx);
    f.specialTimer = sp.startupMs + sp.windowMs + sp.endLagMs;
  } else if (sp.type === "projectile") {
    if (aliveOf(f, ctx) >= sp.maxAlive) return consume(f, "special"); // già troppi in volo: il tasto non fa niente
    startAttack(f, kind, ctx);
    f.specialTimer = sp.startupMs; // fermi finché non parte, poi solo l'attesa per attaccare di nuovo
    f.projectileTimer = sp.startupMs;
    f.pendingSpecial = kind;
  } else {
    // La carica: finché si tiene premuto non c'è ancora un attacco, lo fa partire il rilascio
    consume(f, "special");
    f.chargeMs = 0;
    f.charge = 0;
    f.pendingSpecial = kind;
  }
}

// Un passo della speciale in corso: true se si è fermi (controlli e attacchi saltano, la gravità resta)
export function specialing(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  if (f.onGround) f.airDashUsed = false;
  if (f.chargeMs >= 0) return charging(f, dtMs, ctx);
  if (f.specialTimer <= 0) return false;
  if (f.hitstun) {
    cancelSpecial(f); // colpiti: la mossa finisce
    return false;
  }
  f.specialTimer = Math.max(0, f.specialTimer - dtMs);
  if (f.projectileTimer > 0) {
    f.projectileTimer = Math.max(0, f.projectileTimer - dtMs);
    const kind = f.pendingSpecial;
    const sp = kind && specOf(f, kind);
    if (f.projectileTimer === 0 && kind && sp?.type === "projectile") {
      fire(f, kind, sp, ctx);
      f.pendingSpecial = null;
    }
  }
  if (f.attack === SPECIAL_KINDS.side && f.attackActive) {
    const sp = specialsFor(f.characterId).side;
    if (sp.type === "dash") {
      // Lo scatto: dritto in avanti, senza cadere
      f.vx = f.facing * sp.speed;
      f.vy = 0;
      return true;
    }
  }
  brake(f, dtMs);
  return true;
}

// Avvio e attesa finale: a terra fermi, in aria si frena (dopo lo scatto si andrebbe via a 900 px/s)
function brake(f: Fighter, dtMs: number): void {
  f.vx = f.onGround ? 0 : f.vx * Math.pow(0.5, dtMs / SPECIAL_MOVES.airBrakeHalfLifeMs);
}

// La carica tenuta: cresce fino a maxMs, al rilascio (non prima di minMs) parte il colpo moltiplicato.
// Un colpo, lo scudo o la schivata la annullano
function charging(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  const kind = f.pendingSpecial;
  const sp = kind && specOf(f, kind);
  if (!kind || sp?.type !== "charge" || f.hitstun || f.input.shield || pressed(f, "dodge")) {
    cancelSpecial(f);
    return false;
  }
  f.chargeMs = Math.min(sp.maxMs, f.chargeMs + dtMs);
  f.charge = Math.round((f.chargeMs / sp.maxMs) * 100) / 100;
  brake(f, dtMs);
  if (f.chargeMs < sp.maxMs && (f.chargeMs < sp.minMs || f.input.special)) return true;
  // Rilascio: da 1 a maxMultiplier tra minMs e maxMs
  const level = Math.min(1, Math.max(0, (f.chargeMs - sp.minMs) / (sp.maxMs - sp.minMs)));
  cancelSpecial(f);
  startAttack(f, kind, ctx);
  f.chargeMultiplier = 1 + (sp.maxMultiplier - 1) * level;
  f.attackTimer = sp.minMs; // la carica era l'avvio: il colpo è subito attivo
  f.cooldownTimer = sp.activeMs + sp.endLagMs;
  f.specialTimer = sp.activeMs + sp.endLagMs;
  return true;
}

// La speciale in corso finisce senza effetto (colpiti, presi, KO)
export function cancelSpecial(f: Fighter): void {
  f.specialTimer = 0;
  f.projectileTimer = 0;
  f.chargeMs = -1;
  f.charge = 0;
  f.pendingSpecial = null;
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
  endCounter(f, attacker.id, x, y, ctx);
  const answer = Math.max(sp.minDamage, damage * sp.multiplier);
  launch(attacker, f, SPECIAL_KINDS.down, Math.round(attacker.x), Math.round(attacker.y - 40), ctx, Math.round(answer * 10) / 10);
}

// Un proiettile su chi contrattacca: true se lo para (projectiles.ts lo rimanda indietro)
export function counterAbsorbs(f: Fighter, attackerId: string, x: number, y: number, ctx: PhysicsContext): boolean {
  if (!isCountering(f)) return false;
  f.facing = x >= f.x ? 1 : -1;
  endCounter(f, attackerId, x, y, ctx);
  return true;
}

function endCounter(f: Fighter, attackerId: string, x: number, y: number, ctx: PhysicsContext): void {
  f.attack = null;
  f.attackActive = false;
  f.specialTimer = 0;
  f.cooldownTimer = 0;
  ctx.events.push({ type: "counter", id: f.id, attackerId, x, y });
}
