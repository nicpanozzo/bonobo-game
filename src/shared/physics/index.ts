// Logica di gioco "pura": niente rete, niente grafica.
// Gira sul server; in futuro può girare anche sul client per la predizione.
// Ogni parte ha il suo file, così chi lavora sul movimento non tocca gli attacchi:
//   fighter.ts   stato del lottatore e creazione
//   movement.ts  corsa, salti, gravità (#3, #11)
//   attacks.ts   attacchi e colpi (#2, #15)
//   stage.ts     contatto con l'arena, KO e respawn (#14)
//   elements.ts  ascensori e trappole (#14)
//   ledge.ts     bordo del palco (#110)

import { resolveHits, tryStartAttack, updateAttack } from "./attacks";
import { carryRider, resolveHazards } from "./elements";
import type { Fighter, PhysicsContext } from "./fighter";
import { holdLedge, tryGrabLedge } from "./ledge";
import { applyControls, applyGravity } from "./movement";
import { collideWithStage, loseStock, outOfBlastZone, respawn } from "./stage";

export * from "./fighter";
export { resolveHits } from "./attacks";
export { hazardActive, moverPosition } from "./elements";
export { ledgesOf } from "./ledge";

// Un passo di simulazione per un lottatore (dtMs = durata del tick)
export function stepFighter(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const dt = dtMs / 1000;

  if (f.eliminated) return;
  // Disconnesso con il posto tenuto (#107): fermo dov'è, intoccabile, nessun timer avanza
  if (f.away) {
    f.vx = f.vy = 0;
    f.attackActive = false;
    f.invulnerable = true;
    f.prevInput = f.input;
    return;
  }
  if (f.respawning) {
    f.respawnTimer -= dtMs;
    if (f.respawnTimer <= 0) respawn(f, ctx);
    f.prevInput = f.input;
    return;
  }

  // L'ascensore porta anche chi è fermo per un colpo
  carryRider(f, dtMs, ctx);

  // Hitstop (#15): tutto resta fermo, timer compresi. prevInput non si aggiorna,
  // così un tasto premuto durante il fermo vale al primo passo dopo.
  if (f.hitstopTimer > 0) {
    f.hitstopTimer = Math.max(0, f.hitstopTimer - dtMs);
    return;
  }
  f.cooldownTimer = Math.max(0, f.cooldownTimer - dtMs);
  f.hitstunTimer = Math.max(0, f.hitstunTimer - dtMs);
  f.invulnerableTimer = Math.max(0, f.invulnerableTimer - dtMs);
  f.dropTimer = Math.max(0, f.dropTimer - dtMs);
  f.dodgeTimer = Math.max(0, f.dodgeTimer - dtMs);
  f.dodgeCooldown = Math.max(0, f.dodgeCooldown - dtMs);
  f.hazardTimer = Math.max(0, f.hazardTimer - dtMs);
  f.regrabTimer = Math.max(0, f.regrabTimer - dtMs);
  f.hitstun = f.hitstunTimer > 0;
  f.invulnerable = f.invulnerableTimer > 0;
  if (f.hitstun) f.ledgeGrabs = 0; // un colpo ridà le prese del bordo (#110)

  // Appesi al bordo si resta fermi: niente controlli, attacchi né gravità
  if (holdLedge(f, dtMs, ctx)) {
    f.prevInput = f.input;
    return;
  }

  updateAttack(f, dtMs);
  applyControls(f, dt, ctx);
  tryStartAttack(f, ctx);
  applyGravity(f, dt);

  const prevY = f.y;
  f.x += f.vx * dt;
  f.y += f.vy * dt;

  collideWithStage(f, prevY, ctx, dtMs);

  if (f.onGround && f.hitstun) f.vx *= 0.8; // attrito quando si atterra stordito

  if (outOfBlastZone(f, ctx)) loseStock(f, ctx);

  f.prevInput = f.input;
}

// Un tick intero: l'arena va avanti, tutti si muovono, poi si risolvono i colpi e le trappole
export function stepWorld(fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  ctx.timeMs = (ctx.timeMs ?? 0) + dtMs;
  for (const f of fighters) stepFighter(f, dtMs, ctx);
  for (const f of fighters) if (!f.away) tryGrabLedge(f, fighters, ctx);
  resolveHits(fighters, ctx);
  resolveHazards(fighters, ctx);
}
