// Il compagno di un lottatore (#369), per ora il beagle di Lampione: lo segue da solo, corre,
// salta sulle piattaforme e cade. Se resta troppo indietro o esce dall'arena torna accanto a lui.

import { getCharacter, type CompanionSpec } from "../characters";
import { COMPANION, FIGHTER } from "../constants";
import type { CompanionState } from "../types";
import type { Fighter, PhysicsContext } from "./fighter";
import { platformSurfaceY } from "./stage";

export interface Companion {
  x: number; // centro
  y: number; // piedi
  vx: number;
  vy: number;
  facing: 1 | -1;
  onGround: boolean;
}

export const companionOf = (characterId: string): CompanionSpec | null => getCharacter(characterId).companion ?? null;

// Il compagno sta facendo l'attacco in corso di f? (il beagle morde negli attacchi base, #369 passo 2)
export const biting = (f: Fighter): boolean => !!f.pet && !!f.attack && !!companionOf(f.characterId)?.bites.includes(f.attack);

// Il rettangolo del morso: davanti al compagno, alto quanto lui
export function biteBox(f: Fighter, range: number, height: number): { x: number; y: number; w: number; h: number } {
  const c = f.pet!;
  const half = (companionOf(f.characterId)?.width ?? 0) / 2;
  return { x: c.facing === 1 ? c.x + half : c.x - half - range, y: c.y - height, w: range, h: height };
}

// Accanto a f, un po' dietro: lì aspetta
const homeX = (f: Fighter) => f.x - f.facing * COMPANION.gapPx;

function placeBeside(f: Fighter): Companion {
  return { x: homeX(f), y: f.y, vx: 0, vy: 0, facing: f.facing, onGround: f.onGround };
}

// Un tick del compagno di f, dopo che f si è mosso
export function stepCompanion(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const spec = companionOf(f.characterId);
  if (!spec || f.eliminated) {
    f.pet = null;
    return;
  }
  // Mentre f è fuori gioco il compagno lo aspetta dove ricompare
  if (!f.pet || f.respawning) {
    f.pet = placeBeside(f);
    return;
  }
  const c = f.pet;
  const dt = dtMs / 1000;
  const dx = homeX(f) - c.x;
  const z = ctx.stage.blastZone;
  if (Math.abs(dx) > COMPANION.teleportPx || Math.abs(f.y - c.y) > COMPANION.teleportPx || c.y > z.bottom || c.x < z.left || c.x > z.right) {
    f.pet = placeBeside(f);
    return;
  }
  // Il morso: all'inizio dell'attacco scatta in avanti dalla parte in cui guarda f, poi frena
  if (biting(f)) {
    c.facing = f.facing;
    if (f.attackTimer < dtMs) c.vx = f.facing * COMPANION.lungeSpeed;
    else c.vx = Math.sign(c.vx) * Math.max(0, Math.abs(c.vx) - COMPANION.lungeFriction * dt);
    move(c, spec, f, dt, ctx);
    return;
  }
  // Corre verso il suo posto e si ferma vicino; in aria va più piano
  const want = Math.abs(dx) < COMPANION.slackPx ? 0 : Math.sign(dx) * FIGHTER.groundSpeed * spec.speed;
  const accel = (c.onGround ? COMPANION.groundAccel : COMPANION.airAccel) * dt;
  c.vx += Math.max(-accel, Math.min(accel, want - c.vx));
  if (Math.abs(c.vx) > 1) c.facing = c.vx > 0 ? 1 : -1;
  else if (Math.abs(f.x - c.x) > 4) c.facing = f.x > c.x ? 1 : -1;
  // Salta se f è più in alto, su una piattaforma
  if (c.onGround && (f.onGround && c.y - f.y > COMPANION.jumpIfAbovePx)) c.vy = -spec.jump;
  move(c, spec, f, dt, ctx);
}

function move(c: Companion, spec: CompanionSpec, f: Fighter, dt: number, ctx: PhysicsContext) {
  c.vy = Math.min(FIGHTER.maxFallSpeed, c.vy + FIGHTER.gravity * dt);
  const prevY = c.y;
  c.x += c.vx * dt;
  c.y += c.vy * dt;
  land(c, prevY, spec.width / 2, f.onGround && f.y - c.y > COMPANION.jumpIfAbovePx, ctx);
}

// Come gli oggetti: si posa su blocchi e piattaforme venendo dall'alto. Le piattaforme le attraversa
// in salita, e anche in discesa quando f è a terra più in basso (drop: lo raggiunge)
function land(c: Companion, prevY: number, half: number, drop: boolean, ctx: PhysicsContext) {
  c.onGround = false;
  if (c.vy < 0) return;
  for (const s of drop ? ctx.stage.solids : [...ctx.stage.solids, ...ctx.stage.platforms]) {
    const over = c.x + half > s.x && c.x - half < s.x + s.width;
    const sy = "height" in s ? s.y : platformSurfaceY(s, c.x);
    if (over && prevY <= sy && c.y >= sy) {
      c.y = sy;
      c.vy = 0;
      c.onGround = true;
      return;
    }
  }
}

// Quello che va nello snapshot
export const companionState = (c: Companion): CompanionState => ({ x: Math.round(c.x), y: Math.round(c.y), facing: c.facing, onGround: c.onGround });
