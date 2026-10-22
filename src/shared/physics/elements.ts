// Elementi dinamici dell'arena (#14): piattaforme mobili (ascensori) e trappole.
// Tutto dipende solo dal tempo dell'arena (ctx.timeMs): il client Godot rifà gli stessi
// calcoli in world_view.gd e disegna gli elementi senza riceverne le posizioni.

import { FIGHTER, HAZARD, HITSTOP, HITSTUN_PER_KNOCKBACK, PAD, TICK_RATE, WIND } from "../constants";
import type { Hazard, Jet, MovingPlatform, SoundPad } from "../stages";
import type { Fighter, PhysicsContext } from "./fighter";
import { chargeFromHit } from "./supreme";
import { pieceOn } from "./timed";

const mod = (a: number, b: number) => ((a % b) + b) % b;

// Dove si trova una piattaforma mobile (bordo sinistro, superficie) all'istante timeMs.
// Il giro dura periodMs: a ogni punto c'è la sosta, il resto si divide tra i tratti in base alla lunghezza.
export function moverPosition(m: MovingPlatform, timeMs: number): { x: number; y: number } {
  if (m.keys?.length) return keyedPosition(m.keys, m.periodMs, timeMs + (m.offsetMs ?? 0));
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

// Arena musicale (#423): la posizione tra le due chiavi a cavallo di t; dopo l'ultima si va verso la prima del giro dopo
function keyedPosition(keys: [number, number, number][], periodMs: number, timeMs: number): { x: number; y: number } {
  const t = mod(timeMs, periodMs);
  let lo = 0;
  let hi = keys.length - 1;
  if (t < keys[0][0]) lo = -1;
  else {
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (keys[mid][0] <= t) lo = mid;
      else hi = mid - 1;
    }
  }
  const a = lo < 0 ? keys[keys.length - 1] : keys[lo];
  const b = lo + 1 < keys.length ? keys[lo + 1] : keys[0];
  const ta = lo < 0 ? a[0] - periodMs : a[0];
  const tb = lo + 1 < keys.length ? b[0] : b[0] + periodMs;
  const k = tb > ta ? (t - ta) / (tb - ta) : 0;
  return { x: a[1] + (b[1] - a[1]) * k, y: a[2] + (b[2] - a[2]) * k };
}

// Se una piattaforma c'è all'istante timeMs: senza finestre sempre, altrimenti solo dentro una di loro (#423)
export function moverOn(m: MovingPlatform, timeMs: number): boolean {
  if (!m.on) return true;
  const t = mod(timeMs + (m.offsetMs ?? 0), m.periodMs);
  return m.on.some(([from, to]) => t >= from && t < to);
}

// Bottoni sonori (#423): cosa fanno adesso alla piattaforma m i bottoni del suo gruppo premuti da poco.
// on: accesa per forza; dy: spostamento in verticale, che entra ed esce in PAD.rampMs. Godot rifà lo stesso
// calcolo (pad_fx in stage_motion.gd) con i tempi delle pressioni che arrivano nello snapshot
export function padFx(m: MovingPlatform, timeMs: number, pads: SoundPad[] | undefined, pressedMs: (number | null)[] | undefined): { on: boolean; dy: number } {
  const fx = { on: false, dy: 0 };
  if (!m.group || !pads || !pressedMs) return fx;
  pads.forEach((p, i) => {
    const at = pressedMs[i];
    if (at == null || p.effect.group !== m.group) return;
    const since = timeMs - at;
    if (since < 0 || since >= p.effect.durationMs) return;
    if (p.effect.on) fx.on = true;
    const k = Math.min(1, since / PAD.rampMs, (p.effect.durationMs - since) / PAD.rampMs);
    fx.dy += (p.effect.dy ?? 0) * k;
  });
  return fx;
}

// Dove si trova e se c'è una piattaforma nella partita, con gli effetti dei bottoni (moverPosition e moverOn da soli no)
export function moverPlace(m: MovingPlatform, timeMs: number, ctx: PhysicsContext): { x: number; y: number } {
  const p = moverPosition(m, timeMs);
  const dy = padFx(m, timeMs, ctx.stage.pads, ctx.padsMs).dy;
  return dy ? { x: p.x, y: p.y + dy } : p;
}

export function moverHere(m: MovingPlatform, timeMs: number, ctx: PhysicsContext): boolean {
  return moverOn(m, timeMs) || padFx(m, timeMs, ctx.stage.pads, ctx.padsMs).on;
}

// Una trappola senza ciclo è sempre accesa; con il ciclo, lo è nei primi activeMs di ogni giro
export function hazardActive(h: Hazard, timeMs: number): boolean {
  if (!h.periodMs) return true;
  return mod(timeMs + (h.offsetMs ?? 0), h.periodMs) < (h.activeMs ?? h.periodMs / 2);
}

// Acqua alta (#228): in che fase del giro è l'acqua all'istante timeMs, e quanto è avanti in quella
// fase (k da 0 a 1). Calma all'inizio del giro, poi avviso, salita, alta e discesa fino alla fine.
// Godot rifà lo stesso calcolo (flood_phase in world_view.gd) per disegnare livello e pioggia.
export type FloodPhase = "calm" | "warn" | "rise" | "high" | "fall";

export function floodPhase(h: Hazard, timeMs: number): { phase: FloodPhase; k: number } {
  const f = h.flood;
  if (!f) return { phase: "calm", k: 0 };
  const fall = f.fallMs ?? f.riseMs;
  let t = mod(timeMs + (f.offsetMs ?? 0), f.periodMs) - (f.periodMs - (f.warnMs + f.riseMs + f.holdMs + fall));
  if (t < 0) return { phase: "calm", k: 0 };
  if (t < f.warnMs) return { phase: "warn", k: t / f.warnMs };
  t -= f.warnMs;
  if (t < f.riseMs) return { phase: "rise", k: t / f.riseMs };
  t -= f.riseMs;
  if (t < f.holdMs) return { phase: "high", k: t / f.holdMs };
  t -= f.holdMs;
  return { phase: "fall", k: fall > 0 ? Math.min(1, t / fall) : 1 };
}

// Trappola che viaggia (#229): fase del giro (calma, avviso, passaggio), quanto è avanti (k da 0 a 1)
// e se questo giro va al contrario. Godot rifà lo stesso calcolo (travel_phase in world_view.gd).
export type TravelPhase = "calm" | "warn" | "cross";

export function travelPhase(h: Hazard, timeMs: number): { phase: TravelPhase; k: number; reverse: boolean } {
  const tr = h.travel;
  if (!tr) return { phase: "calm", k: 0, reverse: false };
  const tt = timeMs + (tr.offsetMs ?? 0);
  const reverse = !!tr.alternate && mod(Math.floor(tt / tr.periodMs), 2) === 1;
  const t = mod(tt, tr.periodMs) - (tr.periodMs - tr.warnMs - tr.crossMs);
  if (t < 0) return { phase: "calm", k: 0, reverse };
  if (t < tr.warnMs) return { phase: "warn", k: t / tr.warnMs, reverse };
  return { phase: "cross", k: Math.min(1, (t - tr.warnMs) / tr.crossMs), reverse };
}

// Punto del percorso a una frazione k della sua lunghezza
function pathPoint(path: { x: number; y: number }[], k: number): { x: number; y: number } {
  const lengths = path.slice(1).map((p, i) => Math.hypot(p.x - path[i].x, p.y - path[i].y));
  let left = k * lengths.reduce((a, b) => a + b, 0);
  for (let i = 0; i < lengths.length; i++) {
    if (left <= lengths[i] || i === lengths.length - 1) {
      const f = lengths[i] > 0 ? Math.min(1, left / lengths[i]) : 0;
      return { x: path[i].x + (path[i + 1].x - path[i].x) * f, y: path[i].y + (path[i + 1].y - path[i].y) * f };
    }
    left -= lengths[i];
  }
  return path[0];
}

// Da che parte va la trappola che viaggia in questo giro: 1 verso destra, -1 verso sinistra
export function travelDirection(h: Hazard, timeMs: number): number {
  const path = h.travel?.path ?? [];
  const forward = path.length >= 2 && path[path.length - 1].x < path[0].x ? -1 : 1;
  return travelPhase(h, timeMs).reverse ? -forward : forward;
}

// Il rettangolo che fa male all'istante timeMs: quello scritto nell'arena, o con l'acqua alta
// la superficie al livello del momento e il fondo fermo, o lungo il percorso della trappola che viaggia
export function hazardRect(h: Hazard, timeMs: number): { x: number; y: number; width: number; height: number } {
  if (h.travel && h.travel.path.length >= 2) {
    const { phase, k, reverse } = travelPhase(h, timeMs);
    const along = phase === "cross" ? (reverse ? 1 - k : k) : reverse ? 1 : 0;
    const p = pathPoint(h.travel.path, along);
    return { x: p.x, y: p.y, width: h.width, height: h.height };
  }
  if (!h.flood) return h;
  const { phase, k } = floodPhase(h, timeMs);
  const up = phase === "rise" ? k : phase === "high" ? 1 : phase === "fall" ? 1 - k : 0;
  const top = h.y + (h.flood.highY - h.y) * up;
  return { x: h.x, y: top, width: h.width, height: h.y + h.height - top };
}

// Chi sta su una piattaforma mobile si sposta con lei (prima di muoversi da solo)
export function carryRider(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const m = f.riding >= 0 ? ctx.stage.movers?.[f.riding] : undefined;
  if (!m || !f.onGround) {
    f.riding = -1;
    return;
  }
  if (!moverHere(m, ctx.timeMs ?? 0, ctx)) {
    // La nota è finita (#423): la piattaforma sparisce e chi ci stava sopra cade
    f.riding = -1;
    f.onGround = false;
    return;
  }
  const t = ctx.timeMs ?? 0;
  const before = moverPlace(m, t - dtMs, ctx);
  const now = moverPlace(m, t, ctx);
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
    if (!moverHere(movers[i], t, ctx)) continue;
    const now = moverPlace(movers[i], t, ctx);
    const before = moverPlace(movers[i], t - dtMs, ctx);
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
    if (!pieceOn(h, t) || !hazardActive(h, t)) return; // fuori dalle sue finestre la trappola non c'è (#433)
    if (h.travel && travelPhase(h, t).phase !== "cross") return; // fuori scena o durante l'avviso non fa male (#229)
    if (h.flood?.lowSafe && ["calm", "warn"].includes(floodPhase(h, t).phase)) return; // l'acqua bassa non fa male (#253)
    const r = hazardRect(h, t); // con l'acqua alta la superficie cambia nel tempo (#228), il ciclista viaggia (#229)
    for (const f of fighters) {
      if (!canBeHurt(f)) continue;
      const touching = f.x + half > r.x && f.x - half < r.x + r.width && f.y > r.y && f.y - FIGHTER.height < r.y + r.height;
      if (!touching) continue;
      // La trappola che viaggia passa sul suo percorso: chi sta più in basso (sotto il ponte) è al riparo (#253)
      if (h.travel && f.y > r.y + r.height + HAZARD.travelFeetPx) continue;
      f.percent = Math.min(999, f.percent + h.damage);
      chargeFromHit(null, f, h.damage); // #101: la trappola carica solo chi la prende
      const knockback = h.knockback + h.knockbackGrowth * f.percent;
      const angle = (h.angleDeg * Math.PI) / 180;
      // La trappola che viaggia (#229) lancia nella direzione in cui va; le altre lontano dal loro centro
      const away = h.travel ? travelDirection(h, t) : f.x < r.x + r.width / 2 ? -1 : 1;
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

// Getto d'acqua (#253): calma, bolle (avviso) o getto, come le altre fasi a tempo. Godot rifà lo stesso calcolo (jet_phase).
export type JetPhase = "calm" | "warn" | "active";

export function jetPhase(j: Jet, timeMs: number): JetPhase {
  const t = mod(timeMs + (j.offsetMs ?? 0), j.periodMs) - (j.periodMs - j.warnMs - j.activeMs);
  if (t < 0) return "calm";
  return t < j.warnMs ? "warn" : "active";
}

// Chi sta nella colonna di un getto acceso viene spinto in alto, senza danno; può di nuovo usare il recupero.
// Con dir (#433) è una raffica: in aria vx accelera verso ±speed, a terra c'è solo uno spostamento (WIND.groundFactor);
// non restituisce il recupero. Il predittore Godot non la simula: dentro la zona torna allo stato del server.
export function applyJets(fighters: Fighter[], ctx: PhysicsContext, dtMs = 1000 / TICK_RATE): void {
  const jets = ctx.stage.jets ?? [];
  if (jets.length === 0) return;
  const t = ctx.timeMs ?? 0;
  const half = FIGHTER.width / 2;
  for (const j of jets) {
    if (!pieceOn(j, t) || jetPhase(j, t) !== "active") continue; // getto a tempo (#433)
    for (const f of fighters) {
      if (f.eliminated || f.respawning || f.ledgeIndex >= 0) continue;
      const inside = f.x + half > j.x && f.x - half < j.x + j.width && f.y > j.y - j.height && f.y - FIGHTER.height < j.y;
      if (!inside) continue;
      if (j.dir) {
        const sign = j.dir === "left" ? -1 : 1;
        const dt = dtMs / 1000;
        if (f.onGround) f.x += sign * j.speed * WIND.groundFactor * dt;
        else {
          const target = sign * j.speed;
          const step = WIND.accelPxPerS2 * dt;
          f.vx += Math.max(-step, Math.min(step, target - f.vx));
        }
        continue;
      }
      f.vy = Math.min(f.vy, -j.speed);
      f.onGround = false;
      f.riding = -1;
      f.recoveryUsed = false;
      f.helpless = false;
    }
  }
}
