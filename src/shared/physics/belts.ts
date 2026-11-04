// Nastri trasportatori (La Fabbrica): chi sta a terra su un nastro viene spostato nel suo verso, come dal vento a terra.
// Il verso dipende solo dal tempo dell'arena e dalle leve (bottoni con effect.flip): Godot rifà lo stesso calcolo
// (belt_velocity in stage_motion.gd) con i tempi delle pressioni dello snapshot, per disegnare il nastro che scorre.

import { BELT, TICK_RATE } from "../constants";
import type { Belt, SoundPad } from "../stages";
import type { Fighter, PhysicsContext } from "./fighter";

const mod = (a: number, b: number) => ((a % b) + b) % b;

// Quante leve del gruppo del nastro sono tirate all'istante timeMs
export function beltLevers(b: Belt, timeMs: number, pads: SoundPad[] | undefined, pressedMs: (number | null)[] | undefined): number {
  if (!b.group || !pads || !pressedMs) return 0;
  let n = 0;
  pads.forEach((p, i) => {
    const at = pressedMs[i];
    if (at == null || !p.effect.flip || p.effect.group !== b.group) return;
    const since = timeMs - at;
    if (since >= 0 && since < p.effect.durationMs) n++;
  });
  return n;
}

// Il verso del giro automatico: dir nei giri pari, al contrario nei dispari
export function beltAutoDir(b: Belt, timeMs: number): 1 | -1 {
  if (!b.flipEveryMs) return b.dir;
  return mod(Math.floor(timeMs / b.flipEveryMs), 2) === 0 ? b.dir : (-b.dir as 1 | -1);
}

// Velocità del nastro (pixel/s, col segno: positiva verso destra). Una leva tirata lo inverte, due o più lo invertono
// e lo mandano a BELT.turboMult
export function beltVelocity(b: Belt, timeMs: number, pads: SoundPad[] | undefined, pressedMs: (number | null)[] | undefined): number {
  const levers = beltLevers(b, timeMs, pads, pressedMs);
  const dir = beltAutoDir(b, timeMs) * (levers > 0 ? -1 : 1);
  return dir * b.speed * (levers >= 2 ? BELT.turboMult : 1);
}

// Se f sta a terra sopra il nastro b: conta il centro dei piedi, come per i bottoni
export function onBelt(f: Fighter, b: Belt): boolean {
  return f.onGround && f.riding < 0 && Math.abs(f.y - b.y) <= BELT.feetTolerancePx && f.x >= b.x && f.x <= b.x + b.width;
}

export function applyBelts(fighters: Fighter[], ctx: PhysicsContext, dtMs = 1000 / TICK_RATE): void {
  const belts = ctx.stage.belts ?? [];
  if (belts.length === 0) return;
  const t = ctx.timeMs ?? 0;
  for (const f of fighters) {
    if (f.eliminated || f.respawning || f.ledgeIndex >= 0) continue;
    const b = belts.find((bb) => onBelt(f, bb));
    if (!b) continue;
    // Spostamento diretto, come il vento a terra: i piedi restano a terra e chi cammina contro avanza più piano
    f.x += (beltVelocity(b, t, ctx.stage.pads, ctx.padsMs) * dtMs) / 1000;
  }
}
