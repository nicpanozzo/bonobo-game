// Bordo del palco (#110): ci si aggrappa agli spigoli in alto dei blocchi pieni.
// Da appesi si resta fermi; si esce saltando (su), lasciandosi andare (giù o lontano dal palco),
// con un colpo o dopo LEDGE.maxHangMs. Le altre risalite (normale, con attacco, rotolata) sono il passo 2.

import { FIGHTER, LEDGE } from "../constants";
import type { StageSpec } from "../stages";
import { pressed, type Fighter, type PhysicsContext } from "./fighter";

export interface Ledge {
  x: number; // spigolo
  y: number;
  side: 1 | -1; // da che parte c'è il vuoto: -1 spigolo sinistro, 1 spigolo destro
}

type Rect = StageSpec["solids"][number];

const inside = (r: Rect, x: number, y: number) => x > r.x && x < r.x + r.width && y > r.y && y < r.y + r.height;

// Gli spigoli in alto dei blocchi pieni, tranne quelli che un altro blocco continua (di lato o sopra).
// Piattaforme sottili e ascensori non hanno bordo.
export function ledgesOf(stage: StageSpec): Ledge[] {
  const out: Ledge[] = [];
  for (const s of stage.solids) {
    for (const side of [-1, 1] as const) {
      const x = side === -1 ? s.x : s.x + s.width;
      // Appena fuori dallo spigolo, sotto e sopra: se c'è un altro blocco il bordo non è libero
      const covered = stage.solids.some((t) => t !== s && (inside(t, x + side, s.y + 1) || inside(t, x + side, s.y - 1)));
      if (!covered) out.push({ x, y: s.y, side });
    }
  }
  return out;
}

// La mano sta sulla spalla verso il palco, LEDGE.hangOffsetY sopra i piedi
function canReach(f: Fighter, l: Ledge): boolean {
  if ((f.x - l.x) * l.side < 0) return false; // il centro deve essere già fuori dal palco
  const handX = f.x - l.side * (FIGHTER.width / 2);
  const handY = f.y - LEDGE.hangOffsetY;
  return Math.abs(handX - l.x) <= LEDGE.grabBoxX && Math.abs(handY - l.y) <= LEDGE.grabBoxY;
}

// Chi è in aria e scende (o è inerme dopo il recupero) si aggrappa a uno spigolo libero vicino.
// Si chiama dopo che tutti si sono mossi: a parità di spigolo vince chi viene prima nella lista.
export function tryGrabLedge(f: Fighter, fighters: readonly Fighter[], ctx: PhysicsContext): void {
  if (f.ledge || f.onGround || f.eliminated || f.respawning) return;
  if (f.hitstun || f.dodgeTimer > 0 || f.input.down || f.regrabTimer > 0) return;
  if (f.vy < 0 && !f.helpless) return;
  if (f.ledgeGrabs >= LEDGE.maxGrabs) return;

  const ledges = ledgesOf(ctx.stage);
  for (let i = 0; i < ledges.length; i++) {
    const l = ledges[i];
    if (!canReach(f, l)) continue;
    if (fighters.some((o) => o !== f && o.ledge && o.ledgeIndex === i)) continue; // occupato: non si prende

    f.ledge = "hang";
    f.ledgeIndex = i;
    f.ledgeTimer = 0;
    f.ledgeGrabs += 1;
    f.x = l.x + l.side * (FIGHTER.width / 2);
    f.y = l.y + LEDGE.hangOffsetY;
    f.vx = 0;
    f.vy = 0;
    f.facing = (-l.side) as 1 | -1; // verso il palco
    f.attack = null;
    f.attackActive = false;
    // Si ridanno salto in aria, recupero e schivata in aria
    f.jumpsLeft = FIGHTER.maxJumps - 1;
    f.recoveryUsed = false;
    f.helpless = false;
    f.airDodgeUsed = false;
    const invulnerable = f.ledgeGrabs === 1;
    if (invulnerable) {
      f.invulnerableTimer = Math.max(f.invulnerableTimer, LEDGE.invulnMs);
      f.invulnerable = true;
    }
    ctx.events.push({ type: "ledgeGrab", id: f.id, x: Math.round(l.x), y: Math.round(l.y), invulnerable });
    return;
  }
}

export function releaseLedge(f: Fighter): void {
  f.ledge = null;
  f.ledgeIndex = -1;
  f.ledgeTimer = 0;
  f.regrabTimer = LEDGE.regrabMs;
}

// Un passo da appesi. true se si resta appesi (il resto del passo si salta).
export function holdLedge(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  if (!f.ledge) return false;
  // Un colpo stacca dal bordo: si vola via con la spinta del colpo
  if (f.hitstunTimer > 0) {
    releaseLedge(f);
    return false;
  }
  // Su: salto dal bordo, il salto in aria resta
  if (pressed(f, "up")) {
    releaseLedge(f);
    f.vy = -FIGHTER.jumpSpeed;
    ctx.events.push({ type: "jump", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: false });
    return true;
  }
  // Giù o lontano dal palco: ci si lascia andare
  const away = f.facing === 1 ? "left" : "right";
  f.ledgeTimer += dtMs;
  if (pressed(f, "down") || pressed(f, away) || f.ledgeTimer >= LEDGE.maxHangMs) {
    releaseLedge(f);
    return false;
  }
  f.vx = 0;
  f.vy = 0;
  return true;
}
