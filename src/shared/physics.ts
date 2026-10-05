// Logica di gioco "pura": niente rete, niente grafica.
// Gira sul server; in futuro può girare anche sul client per la predizione.

import { ATTACK, FIGHTER, RESPAWN_MS, WORLD } from "./constants";
import type { InputState, PlayerState } from "./types";

export interface Fighter extends PlayerState {
  input: InputState;
  attackTimer: number; // ms rimanenti di colpo attivo
  cooldownTimer: number; // ms prima di poter colpire ancora
  hitstunTimer: number;
  respawnTimer: number;
  alreadyHit: Set<string>; // chi ha già preso questo colpo
}

export const emptyInput = (): InputState => ({ left: false, right: false, jump: false, attack: false });

export function spawnX(index: number): number {
  const slots = [0.25, 0.75, 0.4, 0.6];
  return WORLD.width * slots[index % slots.length];
}

export function stepFighter(f: Fighter, dtMs: number): void {
  const dt = dtMs / 1000;

  if (f.ko) {
    f.respawnTimer -= dtMs;
    return;
  }

  f.attackTimer = Math.max(0, f.attackTimer - dtMs);
  f.cooldownTimer = Math.max(0, f.cooldownTimer - dtMs);
  f.hitstunTimer = Math.max(0, f.hitstunTimer - dtMs);
  f.hitstun = f.hitstunTimer > 0;

  if (!f.hitstun) {
    // Movimento orizzontale
    const dir = (f.input.right ? 1 : 0) - (f.input.left ? 1 : 0);
    f.vx = dir * FIGHTER.speed;
    if (dir !== 0) f.facing = dir as 1 | -1;

    // Salto
    if (f.input.jump && f.onGround) {
      f.vy = -FIGHTER.jumpSpeed;
      f.onGround = false;
    }

    // Attacco
    if (f.input.attack && f.cooldownTimer === 0) {
      f.attackTimer = ATTACK.activeMs;
      f.cooldownTimer = ATTACK.cooldownMs;
      f.alreadyHit.clear();
    }
  } else {
    f.vx *= 0.9; // attrito durante il knockback
  }
  f.attacking = f.attackTimer > 0;

  // Gravità e integrazione
  f.vy += FIGHTER.gravity * dt;
  f.x += f.vx * dt;
  f.y += f.vy * dt;

  // Pavimento
  if (f.y >= WORLD.floorY) {
    f.y = WORLD.floorY;
    f.vy = 0;
    f.onGround = true;
  }

  // Bordi dello schermo
  const half = FIGHTER.width / 2;
  f.x = Math.max(half, Math.min(WORLD.width - half, f.x));
}

// Rettangolo del colpo davanti al personaggio
function attackBox(f: Fighter) {
  const x = f.facing === 1 ? f.x + FIGHTER.width / 2 : f.x - FIGHTER.width / 2 - ATTACK.range;
  const y = f.y - FIGHTER.height * 0.75;
  return { x, y, w: ATTACK.range, h: ATTACK.height };
}

function bodyBox(f: Fighter) {
  return { x: f.x - FIGHTER.width / 2, y: f.y - FIGHTER.height, w: FIGHTER.width, h: FIGHTER.height };
}

function overlap(a: { x: number; y: number; w: number; h: number }, b: typeof a): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

export function resolveHits(fighters: Fighter[]): void {
  for (const attacker of fighters) {
    if (!attacker.attacking || attacker.ko) continue;
    const box = attackBox(attacker);
    for (const target of fighters) {
      if (target === attacker || target.ko || attacker.alreadyHit.has(target.id)) continue;
      if (!overlap(box, bodyBox(target))) continue;

      attacker.alreadyHit.add(target.id);
      target.hp = Math.max(0, target.hp - ATTACK.damage);
      target.vx = attacker.facing * ATTACK.knockbackX;
      target.vy = -ATTACK.knockbackY;
      target.onGround = false;
      target.hitstunTimer = ATTACK.hitstunMs;
      target.attackTimer = 0;

      if (target.hp === 0) {
        target.ko = true;
        target.respawnTimer = RESPAWN_MS;
        attacker.kos += 1;
      }
    }
  }
}

export function respawn(f: Fighter, index: number): void {
  f.x = spawnX(index);
  f.y = WORLD.floorY;
  f.vx = 0;
  f.vy = 0;
  f.hp = FIGHTER.maxHp;
  f.ko = false;
  f.hitstunTimer = 0;
  f.attackTimer = 0;
}
