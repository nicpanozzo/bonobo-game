// Contatto con l'arena: blocchi pieni, piattaforme sottili, zone di espulsione, vite e ritorno in gioco.

import { COURSE, FIGHTER, RESPAWN_INVULNERABLE_MS, RESPAWN_MS } from "../constants";
import type { Fighter, PhysicsContext } from "./fighter";

export function collideWithStage(f: Fighter, prevY: number, ctx: PhysicsContext): void {
  const half = FIGHTER.width / 2;
  const wasOnGround = f.onGround;
  f.onGround = false;

  for (const s of ctx.stage.solids) {
    // Blocco pieno: si atterra sopra...
    const over = f.x + half > s.x && f.x - half < s.x + s.width;
    if (!over) continue;
    if (f.vy >= 0 && prevY <= s.y && f.y >= s.y) {
      land(f, s.y);
      break;
    }
    if (f.y > s.y && f.y - FIGHTER.height < s.y + s.height) {
      // ...e non lo si attraversa di lato o da sotto
      if (prevY - FIGHTER.height >= s.y + s.height - 1) {
        f.y = s.y + s.height + FIGHTER.height;
        f.vy = Math.max(0, f.vy);
      } else {
        const center = s.x + s.width / 2;
        f.x = f.x < center ? s.x - half : s.x + s.width + half;
        f.vx = 0;
      }
    }
  }

  // Piattaforme sottili: solo dall'alto, e non se si sta premendo giù
  if (!f.onGround && f.vy >= 0 && f.dropTimer === 0) {
    for (const p of ctx.stage.platforms) {
      const over = f.x + half > p.x && f.x - half < p.x + p.width;
      if (over && prevY <= p.y && f.y >= p.y) {
        land(f, p.y);
        break;
      }
    }
  }

  if (f.onGround && !wasOnGround) ctx.events.push({ type: "land", id: f.id, x: Math.round(f.x), y: Math.round(f.y) });

  // Se si cammina oltre il bordo si resta con il salto in aria
  if (wasOnGround && !f.onGround && f.jumpsLeft === FIGHTER.maxJumps) f.jumpsLeft = FIGHTER.maxJumps - 1;
}

function land(f: Fighter, y: number) {
  f.y = y;
  f.vy = 0;
  f.onGround = true;
  f.jumpsLeft = FIGHTER.maxJumps;
  f.recoveryUsed = false;
  f.helpless = false;
}

export function outOfBlastZone(f: Fighter, ctx: PhysicsContext): boolean {
  const z = ctx.stage.blastZone;
  return f.x < z.left || f.x > z.right || f.y < z.top || f.y > z.bottom;
}

export function loseStock(f: Fighter, ctx: PhysicsContext): void {
  if (!ctx.unlimitedStocks) f.stocks -= 1;
  ctx.events.push({
    type: "ko",
    id: f.id,
    byId: f.lastHitById,
    x: Math.round(f.x),
    y: Math.round(f.y),
    stocksLeft: Math.max(0, f.stocks),
  });
  f.attack = null;
  f.attackActive = false;
  f.hitstunTimer = 0;
  f.hitstun = false;
  f.lastHitById = null;
  if (f.stocks <= 0) {
    f.eliminated = true;
    return;
  }
  f.respawning = true;
  f.respawnTimer = RESPAWN_MS;
}

export function respawn(f: Fighter, ctx: PhysicsContext): void {
  f.respawning = false;
  // Nei percorsi si riparte dall'ultimo checkpoint, nelle arene dal punto di ritorno
  const cp = ctx.stage.checkpoints?.[f.checkpoint];
  f.x = cp ? cp.x : ctx.stage.respawn.x;
  f.y = cp ? cp.y - COURSE.respawnHeight : ctx.stage.respawn.y;
  f.vx = 0;
  f.vy = 0;
  f.percent = 0;
  f.jumpsLeft = FIGHTER.maxJumps;
  f.recoveryUsed = false;
  f.helpless = false;
  f.invulnerableTimer = RESPAWN_INVULNERABLE_MS;
  f.invulnerable = true;
  ctx.events.push({ type: "respawn", id: f.id });
}
