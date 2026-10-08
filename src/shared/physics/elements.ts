// Elementi dinamici dell'arena (#14): piattaforme mobili (ascensori) e trappole.
// Tutto dipende solo dal tempo dell'arena (ctx.timeMs): il client Godot rifà gli stessi
// calcoli in world_view.gd e disegna gli elementi senza riceverne le posizioni.

import { FIGHTER, HAZARD, HITSTOP, HITSTUN_PER_KNOCKBACK } from "../constants";
import type { Hazard, MovingPlatform } from "../stages";
import type { Fighter, PhysicsContext } from "./fighter";
import { chargeFromHit } from "./supreme";

const mod = (a: number, b: number) => ((a % b) + b) % b;

// Dove si trova una piattaforma mobile (bordo sinistro, superficie) all'istante timeMs.
// Il giro dura periodMs: a ogni punto c'è la sosta, il resto si divide tra i tratti in base alla lunghezza.
export function moverPosition(m: MovingPlatform, timeMs: number): { x: number; y: number } {
  const pts = m.path;
  if (pts.length < 2) return pts[0] ?? { x: 0, y: 0 };
  const route = m.loop ? [...pts, pts[0]] : [...pts, ...pts.slice(0, -1).reverse()];
  const segments = route.length - 1;
  const pause = m.pauseMs ?? 0;
  const lengths = route.slice(1).map((p, i) => Math.hypot(p.x - route[i].x, p.y - route[i].y));
  const total = lengths.reduce((a, b) => a + b, 0);
  const travel = Math.max(1, m.periodMs - pause * segments);
  let t = mod(timeMs + (m.offsetMs ?? 0), m.periodMs);
  for (let i = 0; i < segments; i++) {
    if (t < pause) return route[i];
    t -= pause;
    const segMs = total > 0 ? (travel * lengths[i]) / total : travel / segments;
    if (t < segMs) {
      const k = t / segMs;
      return { x: route[i].x + (route[i + 1].x - route[i].x) * k, y: route[i].y + (route[i + 1].y - route[i].y) * k };
    }
    t -= segMs;
  }
  return route[segments];
}

// Una trappola senza ciclo è sempre accesa; con il ciclo, lo è nei primi activeMs di ogni giro
export function hazardActive(h: Hazard, timeMs: number): boolean {
  if (!h.periodMs) return true;
  return mod(timeMs + (h.offsetMs ?? 0), h.periodMs) < (h.activeMs ?? h.periodMs / 2);
}

// Chi sta su una piattaforma mobile si sposta con lei (prima di muoversi da solo)
export function carryRider(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const m = f.riding >= 0 ? ctx.stage.movers?.[f.riding] : undefined;
  if (!m || !f.onGround) {
    f.riding = -1;
    return;
  }
  const t = ctx.timeMs ?? 0;
  const before = moverPosition(m, t - dtMs);
  const now = moverPosition(m, t);
  f.x += now.x - before.x;
  f.y += now.y - before.y;
}

// Atterraggio su una piattaforma mobile: come le sottili, ma la superficie si è mossa durante il passo,
// quindi conta dov'era prima (si atterra anche su un ascensore che sale incontro).
// Restituisce l'indice della piattaforma, o -1.
export function landOnMover(f: Fighter, prevY: number, dtMs: number, ctx: PhysicsContext): number {
  const movers = ctx.stage.movers ?? [];
  const t = ctx.timeMs ?? 0;
  const half = FIGHTER.width / 2;
  for (let i = 0; i < movers.length; i++) {
    const now = moverPosition(movers[i], t);
    const before = moverPosition(movers[i], t - dtMs);
    const over = f.x + half > now.x && f.x - half < now.x + movers[i].width;
    if (over && prevY <= Math.max(before.y, now.y) && f.y >= now.y) {
      f.y = now.y;
      return i;
    }
  }
  return -1;
}

const canBeHurt = (f: Fighter) => !f.eliminated && !f.respawning && !f.invulnerable && f.hazardTimer === 0;

// Le trappole accese colpiscono chi le tocca. Il KO resta a chi ha colpito per ultimo:
// buttare qualcuno sugli spuntoni vale.
export function resolveHazards(fighters: Fighter[], ctx: PhysicsContext): void {
  const hazards = ctx.stage.hazards ?? [];
  if (hazards.length === 0) return;
  const t = ctx.timeMs ?? 0;
  const half = FIGHTER.width / 2;
  hazards.forEach((h, index) => {
    if (!hazardActive(h, t)) return;
    for (const f of fighters) {
      if (!canBeHurt(f)) continue;
      const touching = f.x + half > h.x && f.x - half < h.x + h.width && f.y > h.y && f.y - FIGHTER.height < h.y + h.height;
      if (!touching) continue;
      f.percent = Math.min(999, f.percent + h.damage);
      chargeFromHit(null, f, h.damage); // #101: la trappola carica solo chi la prende
      const knockback = h.knockback + h.knockbackGrowth * f.percent;
      const angle = (h.angleDeg * Math.PI) / 180;
      const away = f.x < h.x + h.width / 2 ? -1 : 1;
      f.vx = away * Math.cos(angle) * knockback;
      f.vy = -Math.sin(angle) * knockback;
      f.onGround = false;
      f.riding = -1;
      f.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
      f.hitstun = true;
      f.attack = null;
      f.attackActive = false;
      // Come dopo un colpo (#11): si può di nuovo usare il recupero
      f.recoveryUsed = false;
      f.helpless = false;
      f.hazardTimer = HAZARD.cooldownMs;
      f.hitstopTimer = Math.max(f.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * h.damage));
      ctx.events.push({
        type: "hazard",
        id: f.id,
        index,
        damage: h.damage,
        percent: f.percent,
        knockback: Math.round(knockback),
        x: Math.round(f.x),
        y: Math.round(f.y - FIGHTER.height / 2),
      });
    }
  });
}
