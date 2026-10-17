// Contatto con l'arena: blocchi pieni, piattaforme sottili, zone di espulsione, vite e ritorno in gioco.

import { COURSE, FIGHTER, RESPAWN_INVULNERABLE_MS, RESPAWN_MS, SUPREME } from "../constants";
import { landOnMover } from "./elements";
import type { Fighter, PhysicsContext } from "./fighter";
import { resetShield } from "./shield";
import type { ThinPlatform } from "../stages";

// Superficie di una piattaforma sottile al punto x: dritta, ad arco come un ponte (#244), alta y alle
// estremità e arch pixel più su al centro, o inclinata come una scala (#246), da y a sinistra a y2 a destra.
// Il port della predizione (predict/movement.gd) e il disegno (world_view.gd) rifanno lo stesso calcolo.
export function platformSurfaceY(p: ThinPlatform, x: number): number {
  if (p.y2 !== undefined) {
    const u = Math.max(0, Math.min(1, (x - p.x) / p.width));
    return p.y + (p.y2 - p.y) * u;
  }
  if (!p.arch) return p.y;
  const half = p.width / 2;
  const u = Math.max(-1, Math.min(1, (x - (p.x + half)) / half));
  return p.y - p.arch * (1 - u * u);
}

// Piattaforme non dritte (ad arco o inclinate): chi ci cammina segue la superficie
const curved = (p: ThinPlatform) => !!p.arch || p.y2 !== undefined;

// Quanto dislivello in un passo si segue camminando: sulle rampe cresce con la pendenza, così regge anche lo scatto
function snapPx(p: ThinPlatform): number {
  const slope = p.y2 !== undefined ? Math.abs(p.y2 - p.y) / p.width : 0;
  return FIGHTER.archSnapPx + slope * FIGHTER.slopeSnapStepPx;
}

export function collideWithStage(f: Fighter, prevY: number, ctx: PhysicsContext, dtMs = 0): void {
  const half = FIGHTER.width / 2;
  const wasOnGround = f.onGround;
  f.onGround = false;
  f.riding = -1;

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

  // Da un blocco pieno si sale camminando su una rampa che parte poco più su dei piedi (#246)
  if (f.onGround && wasOnGround && f.dropTimer === 0) {
    for (const p of ctx.stage.platforms) {
      if (p.y2 === undefined || !(f.x + half > p.x && f.x - half < p.x + p.width)) continue;
      const sy = platformSurfaceY(p, f.x);
      if (sy < f.y && f.y - sy <= snapPx(p)) {
        land(f, sy);
        break;
      }
    }
  }

  // Piattaforme sottili: solo dall'alto, e non subito dopo aver premuto giù. Durante la discesa con giù
  // una piattaforma ad arco o inclinata più in basso ti prende (#246): così dal ponte si scende sulla scala
  if (!f.onGround && f.vy >= 0) {
    for (const p of ctx.stage.platforms) {
      const over = f.x + half > p.x && f.x - half < p.x + p.width;
      if (!over) continue;
      const sy = platformSurfaceY(p, f.x);
      if (f.dropTimer > 0) {
        // ...ma solo se è chiaramente più in basso di dove si è premuto giù, non la stessa da cui si scende
        if (curved(p) && sy > f.dropFromY + snapPx(p) && prevY <= sy && f.y >= sy) {
          land(f, sy);
          break;
        }
        continue;
      }
      // Sull'arco (#244) e sulle rampe (#246) chi ci cammina segue la superficie, in salita e in discesa
      const follow = curved(p) && wasOnGround && Math.abs(f.y - sy) <= snapPx(p);
      if ((prevY <= sy && f.y >= sy) || follow) {
        land(f, sy);
        break;
      }
    }
  }

  // Piattaforme mobili (#14): come le sottili, e da lì in poi ci si viaggia sopra
  if (!f.onGround && f.vy >= 0 && f.dropTimer === 0) {
    const i = landOnMover(f, prevY, dtMs, ctx);
    if (i >= 0) {
      land(f, f.y);
      f.riding = i;
    }
  }

  if (f.onGround && !wasOnGround) ctx.events.push({ type: "land", id: f.id, x: Math.round(f.x), y: Math.round(f.y) });

  // Se si cammina oltre il bordo si resta con il salto in aria, ma per FIGHTER.coyoteMs
  // il salto vale ancora da terra: chi preme un attimo in ritardo non perde il salto
  if (wasOnGround && !f.onGround && f.jumpsLeft === FIGHTER.maxJumps) {
    // Scendere apposta da una sottile con giù (dropTimer) non dà il tempo di grazia: si è scelto di cadere
    if (f.hitstun || f.dropTimer > 0) f.jumpsLeft = FIGHTER.maxJumps - 1;
    else f.coyoteTimer = FIGHTER.coyoteMs;
  }
}

function land(f: Fighter, y: number) {
  f.y = y;
  f.vy = 0;
  f.onGround = true;
  f.jumpsLeft = FIGHTER.maxJumps;
  f.recoveryUsed = false;
  f.helpless = false;
  f.airDodgeUsed = false;
  f.ledgeGrabs = 0;
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
  if (!SUPREME.keepOnKo) f.supreme = 0; // #101
  f.rewindTrail = []; // col KO il passato si perde: …COSA? non riporta in vita (#358)
  f.powerup = null; // il fiore finisce con la vita (#231)
  f.powerupMs = 0;
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
  f.airDodgeUsed = false;
  f.ledgeGrabs = 0;
  resetShield(f); // scudo pieno, niente stordimento (#109)
  f.invulnerableTimer = RESPAWN_INVULNERABLE_MS;
  f.invulnerable = true;
  ctx.events.push({ type: "respawn", id: f.id });
}
