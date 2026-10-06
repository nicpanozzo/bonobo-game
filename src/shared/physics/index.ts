// Logica di gioco "pura": niente rete, niente grafica.
// Gira sul server; in futuro può girare anche sul client per la predizione.
// Ogni parte ha il suo file, così chi lavora sul movimento non tocca gli attacchi:
//   fighter.ts   stato del lottatore e creazione
//   movement.ts  corsa, salti, gravità (#3, #11)
//   attacks.ts   attacchi e colpi (#2, #15)
//   stage.ts     contatto con l'arena, KO e respawn (#14)

import { resolveHits, tryStartAttack, updateAttack } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";
import { applyControls, applyGravity } from "./movement";
import { collideWithStage, loseStock, outOfBlastZone, respawn } from "./stage";

export * from "./fighter";
export { resolveHits } from "./attacks";

// Un passo di simulazione per un lottatore (dtMs = durata del tick)
export function stepFighter(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const dt = dtMs / 1000;

  if (f.eliminated) return;
  if (f.respawning) {
    f.respawnTimer -= dtMs;
    if (f.respawnTimer <= 0) respawn(f, ctx);
    f.prevInput = f.input;
    return;
  }

  f.cooldownTimer = Math.max(0, f.cooldownTimer - dtMs);
  f.hitstunTimer = Math.max(0, f.hitstunTimer - dtMs);
  f.invulnerableTimer = Math.max(0, f.invulnerableTimer - dtMs);
  f.dropTimer = Math.max(0, f.dropTimer - dtMs);
  f.hitstun = f.hitstunTimer > 0;
  f.invulnerable = f.invulnerableTimer > 0;

  updateAttack(f, dtMs);
  applyControls(f, dt, ctx);
  tryStartAttack(f, ctx);
  applyGravity(f, dt);

  const prevY = f.y;
  f.x += f.vx * dt;
  f.y += f.vy * dt;

  collideWithStage(f, prevY, ctx);

  if (f.onGround && f.hitstun) f.vx *= 0.8; // attrito quando si atterra stordito

  if (outOfBlastZone(f, ctx)) loseStock(f, ctx);

  f.prevInput = f.input;
}

// Un tick intero: tutti si muovono, poi si risolvono i colpi
export function stepWorld(fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  for (const f of fighters) stepFighter(f, dtMs, ctx);
  resolveHits(fighters, ctx);
}
