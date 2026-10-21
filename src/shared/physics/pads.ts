// Bottoni sonori dell'arena (#423): si premono atterrandoci sopra o colpendoli con un attacco. Chi preme un bottone
// carico lo fa suonare (evento "pad") e per un po' cambia le piattaforme del suo gruppo (padFx in elements.ts);
// poi il bottone resta scarico per cooldownMs. Il server tiene i tempi delle pressioni in ctx.padsMs e li manda
// nello snapshot, così Godot disegna lo stesso effetto.

import { PAD } from "../constants";
import type { SoundPad } from "../stages";
import { attackBox, isGrabKind, overlap } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";

// Dove un colpo preme il bottone: sopra di lui fino a PAD.hitPx, così lo prende anche un colpo da in piedi
export const padBox = (p: SoundPad) => ({ x: p.x, y: p.y - PAD.hitPx, w: p.width, h: PAD.hitPx });

// Se il bottone si può premere all'istante timeMs: mai premuto, o passata l'attesa
export function padReady(p: SoundPad, pressedAt: number | null | undefined, timeMs: number): boolean {
  return pressedAt == null || timeMs - pressedAt >= p.cooldownMs;
}

// Chi preme il bottone in questo tick: chi ci è atterrato sopra (gli eventi "land" da firstEvent in poi)
// o chi lo prende con un colpo attivo. Il primo trovato vale; null se nessuno
function presser(p: SoundPad, fighters: Fighter[], ctx: PhysicsContext, firstEvent: number): Fighter | null {
  for (let i = firstEvent; i < ctx.events.length; i++) {
    const e = ctx.events[i];
    if (e.type !== "land" || e.x < p.x || e.x > p.x + p.width || Math.abs(e.y - p.y) > PAD.landTolerancePx) continue;
    const f = fighters.find((ff) => ff.id === e.id);
    if (f) return f;
  }
  for (const f of fighters) {
    if (!f.attackActive || !f.attack || f.eliminated || f.respawning || isGrabKind(f.attack)) continue;
    if (overlap(attackBox(f), padBox(p))) return f;
  }
  return null;
}

export function pressPads(fighters: Fighter[], ctx: PhysicsContext, firstEvent: number): void {
  const pads = ctx.stage.pads ?? [];
  if (pads.length === 0) return;
  const t = ctx.timeMs ?? 0;
  ctx.padsMs ??= pads.map(() => null);
  pads.forEach((p, index) => {
    if (!padReady(p, ctx.padsMs![index], t)) return;
    const f = presser(p, fighters, ctx, firstEvent);
    if (!f) return;
    ctx.padsMs![index] = t;
    ctx.events.push({ type: "pad", index, sound: p.sound, id: f.id, x: Math.round(p.x + p.width / 2), y: Math.round(p.y) });
  });
}
