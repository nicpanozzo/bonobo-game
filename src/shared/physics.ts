// Logica di gioco "pura": niente rete, niente grafica.
// Gira sul server; in futuro può girare anche sul client per la predizione.

import {
  ATTACKS,
  BLAST_ZONE,
  FIGHTER,
  HITSTUN_AIR_DRAG,
  HITSTUN_PER_KNOCKBACK,
  PLATFORMS,
  RESPAWN_INVULNERABLE_MS,
  RESPAWN_MS,
  RESPAWN_POINT,
  STAGE,
  STOCKS,
} from "./constants";
import type { InputState, PlayerState } from "./types";

export interface Fighter extends PlayerState {
  input: InputState;
  prevInput: InputState; // per riconoscere quando un tasto viene appena premuto
  jumpsLeft: number;
  dropTimer: number; // ms in cui si ignorano le piattaforme sottili
  attackTimer: number; // ms dall'inizio dell'attacco in corso
  cooldownTimer: number; // ms prima di poter attaccare ancora
  hitstunTimer: number;
  respawnTimer: number;
  invulnerableTimer: number;
  alreadyHit: Set<string>; // chi ha già preso questo colpo
}

export const emptyInput = (): InputState => ({
  left: false,
  right: false,
  up: false,
  down: false,
  light: false,
  heavy: false,
});

export function spawnX(index: number): number {
  const slots = [0.3, 0.7, 0.45, 0.55];
  return STAGE.x + STAGE.width * slots[index % slots.length];
}

export function createFighter(id: string, name: string, color: number, index: number): Fighter {
  return {
    id,
    name,
    color,
    x: spawnX(index),
    y: STAGE.y,
    vx: 0,
    vy: 0,
    facing: index % 2 === 0 ? 1 : -1,
    percent: 0,
    stocks: STOCKS,
    onGround: true,
    attack: null,
    attackActive: false,
    hitstun: false,
    respawning: false,
    invulnerable: false,
    eliminated: false,
    input: emptyInput(),
    prevInput: emptyInput(),
    jumpsLeft: FIGHTER.maxJumps,
    dropTimer: 0,
    attackTimer: 0,
    cooldownTimer: 0,
    hitstunTimer: 0,
    respawnTimer: 0,
    invulnerableTimer: 0,
    alreadyHit: new Set(),
  };
}

const pressed = (f: Fighter, key: keyof InputState) => f.input[key] && !f.prevInput[key];

export function stepFighter(f: Fighter, dtMs: number): void {
  const dt = dtMs / 1000;

  if (f.eliminated) return;
  if (f.respawning) {
    f.respawnTimer -= dtMs;
    if (f.respawnTimer <= 0) respawn(f);
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

  if (!f.hitstun) {
    const dir = (f.input.right ? 1 : 0) - (f.input.left ? 1 : 0);
    // Durante un attacco da terra si resta fermi, in aria si mantiene lo slancio
    if (f.onGround) {
      f.vx = f.attack ? 0 : dir * FIGHTER.groundSpeed;
    } else if (dir !== 0) {
      f.vx += dir * FIGHTER.airAccel * dt;
      f.vx = Math.max(-FIGHTER.airSpeed, Math.min(FIGHTER.airSpeed, f.vx));
    } else {
      const slow = FIGHTER.airFriction * dt;
      f.vx = Math.abs(f.vx) <= slow ? 0 : f.vx - Math.sign(f.vx) * slow;
    }
    if (dir !== 0 && !f.attack) f.facing = dir as 1 | -1;

    // Salto e doppio salto
    if (pressed(f, "up") && f.jumpsLeft > 0) {
      f.vy = -(f.onGround ? FIGHTER.jumpSpeed : FIGHTER.doubleJumpSpeed);
      f.jumpsLeft -= 1;
      f.onGround = false;
    }

    // Giù: attraversa le piattaforme sottili, in aria cade più veloce
    if (pressed(f, "down")) f.dropTimer = FIGHTER.dropThroughMs;

    if (!f.attack && f.cooldownTimer === 0) {
      if (pressed(f, "heavy")) startAttack(f, "heavy");
      else if (pressed(f, "light")) startAttack(f, "light");
    }
  } else if (!f.onGround) {
    f.vx *= HITSTUN_AIR_DRAG;
  }

  // Gravità
  const maxFall = f.input.down && !f.hitstun ? FIGHTER.fastFallSpeed : FIGHTER.maxFallSpeed;
  f.vy = Math.min(f.vy + FIGHTER.gravity * dt, f.hitstun ? Infinity : maxFall);
  if (f.input.down && !f.hitstun && !f.onGround && f.vy > 0) f.vy = Math.max(f.vy, maxFall * 0.8);

  const prevY = f.y;
  f.x += f.vx * dt;
  f.y += f.vy * dt;

  collideWithStage(f, prevY);

  if (f.onGround && f.hitstun) f.vx *= 0.8; // attrito quando si atterra stordito

  if (outOfBlastZone(f)) loseStock(f);

  f.prevInput = f.input;
}

function startAttack(f: Fighter, kind: "light" | "heavy") {
  f.attack = kind;
  f.attackTimer = 0;
  f.cooldownTimer = ATTACKS[kind].cooldownMs;
  f.alreadyHit.clear();
}

function updateAttack(f: Fighter, dtMs: number) {
  if (!f.attack) {
    f.attackActive = false;
    return;
  }
  const spec = ATTACKS[f.attack];
  f.attackTimer += dtMs;
  f.attackActive = f.attackTimer >= spec.startupMs && f.attackTimer < spec.startupMs + spec.activeMs;
  if (f.attackTimer >= spec.startupMs + spec.activeMs) {
    f.attack = null;
    f.attackActive = false;
  }
}

function collideWithStage(f: Fighter, prevY: number) {
  const half = FIGHTER.width / 2;
  const wasOnGround = f.onGround;
  f.onGround = false;

  // Palco principale: si atterra sopra...
  const overStage = f.x + half > STAGE.x && f.x - half < STAGE.x + STAGE.width;
  if (overStage && f.vy >= 0 && prevY <= STAGE.y && f.y >= STAGE.y) {
    land(f, STAGE.y);
  } else if (overStage && f.y > STAGE.y && f.y - FIGHTER.height < STAGE.y + STAGE.thickness) {
    // ...e non lo si attraversa di lato o da sotto
    if (prevY - FIGHTER.height >= STAGE.y + STAGE.thickness - 1) {
      f.y = STAGE.y + STAGE.thickness + FIGHTER.height;
      f.vy = Math.max(0, f.vy);
    } else {
      const center = STAGE.x + STAGE.width / 2;
      f.x = f.x < center ? STAGE.x - half : STAGE.x + STAGE.width + half;
      f.vx = 0;
    }
  }

  // Piattaforme sottili: solo dall'alto, e non se si sta premendo giù
  if (!f.onGround && f.vy >= 0 && f.dropTimer === 0) {
    for (const p of PLATFORMS) {
      const over = f.x + half > p.x && f.x - half < p.x + p.width;
      if (over && prevY <= p.y && f.y >= p.y) {
        land(f, p.y);
        break;
      }
    }
  }

  // Se si cammina oltre il bordo si resta con il salto in aria
  if (wasOnGround && !f.onGround && f.jumpsLeft === FIGHTER.maxJumps) f.jumpsLeft = FIGHTER.maxJumps - 1;
}

function land(f: Fighter, y: number) {
  f.y = y;
  f.vy = 0;
  f.onGround = true;
  f.jumpsLeft = FIGHTER.maxJumps;
}

function outOfBlastZone(f: Fighter): boolean {
  return f.x < BLAST_ZONE.left || f.x > BLAST_ZONE.right || f.y < BLAST_ZONE.top || f.y > BLAST_ZONE.bottom;
}

function loseStock(f: Fighter) {
  f.stocks -= 1;
  f.attack = null;
  f.attackActive = false;
  f.hitstunTimer = 0;
  f.hitstun = false;
  if (f.stocks <= 0) {
    f.eliminated = true;
    return;
  }
  f.respawning = true;
  f.respawnTimer = RESPAWN_MS;
}

function respawn(f: Fighter) {
  f.respawning = false;
  f.x = RESPAWN_POINT.x;
  f.y = RESPAWN_POINT.y;
  f.vx = 0;
  f.vy = 0;
  f.percent = 0;
  f.jumpsLeft = FIGHTER.maxJumps;
  f.invulnerableTimer = RESPAWN_INVULNERABLE_MS;
  f.invulnerable = true;
}

// Rettangolo del colpo davanti al personaggio
function attackBox(f: Fighter) {
  const spec = ATTACKS[f.attack ?? "light"];
  const x = f.facing === 1 ? f.x + FIGHTER.width / 2 : f.x - FIGHTER.width / 2 - spec.range;
  const y = f.y - FIGHTER.height * 0.7;
  return { x, y, w: spec.range, h: spec.height };
}

function bodyBox(f: Fighter) {
  return { x: f.x - FIGHTER.width / 2, y: f.y - FIGHTER.height, w: FIGHTER.width, h: FIGHTER.height };
}

function overlap(a: { x: number; y: number; w: number; h: number }, b: typeof a): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

const canBeHit = (f: Fighter) => !f.eliminated && !f.respawning && !f.invulnerable;

export function resolveHits(fighters: Fighter[]): void {
  for (const attacker of fighters) {
    if (!attacker.attackActive || !attacker.attack || attacker.eliminated || attacker.respawning) continue;
    const spec = ATTACKS[attacker.attack];
    const box = attackBox(attacker);
    for (const target of fighters) {
      if (target === attacker || !canBeHit(target) || attacker.alreadyHit.has(target.id)) continue;
      if (!overlap(box, bodyBox(target))) continue;

      attacker.alreadyHit.add(target.id);
      // Stile Smash/Brawlhalla: il danno non toglie vita, fa volare più lontano
      target.percent = Math.min(999, target.percent + spec.damage);
      const knockback = spec.baseKnockback + spec.knockbackGrowth * target.percent;
      const angle = (spec.angleDeg * Math.PI) / 180;
      target.vx = attacker.facing * Math.cos(angle) * knockback;
      target.vy = -Math.sin(angle) * knockback;
      target.onGround = false;
      target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
      target.attack = null;
      target.attackActive = false;
      target.facing = (-attacker.facing) as 1 | -1;
    }
  }
}

// Riporta tutti all'inizio partita
export function resetForMatch(f: Fighter, index: number): void {
  Object.assign(f, createFighter(f.id, f.name, f.color, index), { input: f.input, prevInput: f.prevInput });
}

export const isAlive = (f: Fighter) => !f.eliminated;

