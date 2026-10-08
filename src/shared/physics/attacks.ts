// Attacchi: inizio, finestra attiva, hitbox e cosa succede a chi viene colpito.

import { characterStats, getCharacter, SPECIAL_KINDS, specialAttackSpec, specialsFor, supremeAttackSpec, type SpecialSlot } from "../characters";
import { ATTACKS, FIGHTER, HITSTOP, HITSTUN_PER_KNOCKBACK, type AttackSpec } from "../constants";
import type { AttackKind, SpecialKind } from "../types";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { clearStun, hitShield } from "./shield";
import { counterHit, isCountering, tryStartSpecial } from "./specials";
import { chargeFromHit, hitOrigin, tryStartSupreme } from "./supreme";

export function tryStartAttack(f: Fighter, ctx: PhysicsContext): void {
  if (f.hitstun || f.attack || f.cooldownTimer > 0 || f.helpless || f.dodgeTimer > 0) return;
  if (tryStartSupreme(f, ctx)) return; // #101: solo con la barra piena
  if (pressed(f, "special")) tryStartSpecial(f, ctx); // E10
  else if (pressed(f, "heavy")) startAttack(f, variant(f, "heavy"), ctx);
  else if (pressed(f, "light")) startAttack(f, variant(f, "light"), ctx);
}

// La variante viene dai tasti tenuti: su vince su tutto, poi l'aria, poi giù (a terra)
export function variant(f: Fighter, base: "light" | "heavy"): AttackKind {
  if (f.input.up) return `${base}Up`;
  if (!f.onGround) return `${base}Air`;
  if (f.input.down) return `${base}Down`;
  return base;
}

// I numeri di un attacco per questo lottatore (E10): quelli di ATTACKS, con i ritocchi del suo personaggio
// (per ora il recupero, characters.ts). Tutta la fisica degli attacchi li legge da qui
export function attackSpecFor(f: Fighter, kind: AttackKind | null = f.attack): AttackSpec {
  if (kind && isSpecialKind(kind)) {
    const spec = specialSpecFor(f.characterId, kind);
    return kind === f.attack && f.chargeMultiplier !== 1 ? charged(spec, f.chargeMultiplier) : spec;
  }
  if (kind === "supreme") return supremeAttackSpec(f.characterId) ?? ATTACKS.supreme; // #102: la sua, se ce l'ha
  const base = ATTACKS[kind ?? "light"];
  const recovery = kind === "recovery" ? getCharacter(f.characterId).recovery : undefined;
  return recovery ? { ...base, ...recovery } : base;
}

export const isSpecialKind = (kind: AttackKind): kind is SpecialKind => kind.startsWith("special");
const SLOT_OF = Object.fromEntries(Object.entries(SPECIAL_KINDS).map(([slot, kind]) => [kind, slot])) as Record<SpecialKind, SpecialSlot>;

// Le speciali si convertono una volta per personaggio: la fisica le legge a ogni tick
const specialCache = new Map<string, AttackSpec>();
// Il colpo caricato (E10): danno e knockback moltiplicati
function charged(spec: AttackSpec, m: number): AttackSpec {
  return { ...spec, damage: Math.round(spec.damage * m * 10) / 10, baseKnockback: spec.baseKnockback * m, knockbackGrowth: spec.knockbackGrowth * m };
}

function specialSpecFor(characterId: string, kind: SpecialKind): AttackSpec {
  const key = `${characterId}:${kind}`;
  let spec = specialCache.get(key);
  if (!spec) {
    spec = specialAttackSpec(specialsFor(characterId)[SLOT_OF[kind]]);
    specialCache.set(key, spec);
  }
  return spec;
}

export function startAttack(f: Fighter, kind: AttackKind, ctx: PhysicsContext) {
  f.attack = kind;
  f.attackTimer = 0;
  f.chargeMultiplier = 1; // solo il rilascio della carica lo cambia, dopo questa chiamata
  f.cooldownTimer = attackSpecFor(f, kind).cooldownMs;
  f.alreadyHit.clear();
  consume(f, "light", "heavy", "special"); // anche il recupero, l'attacco dal bordo e le speciali passano da qui
  ctx.events.push({ type: "attack", id: f.id, kind });
}

export function updateAttack(f: Fighter, dtMs: number): void {
  if (!f.attack) {
    f.attackActive = false;
    return;
  }
  const spec = attackSpecFor(f);
  f.attackTimer += dtMs;
  f.attackActive = f.attackTimer >= spec.startupMs && f.attackTimer < spec.startupMs + spec.activeMs;
  if (f.attackTimer >= spec.startupMs + spec.activeMs) {
    f.attack = null;
    f.attackActive = false;
  }
}

type Box = { x: number; y: number; w: number; h: number };

// Rettangolo del colpo, dalla parte in cui si guarda (boxX/boxY lo spostano per le varianti)
export function attackBox(f: Fighter): Box {
  const spec = attackSpecFor(f);
  const o = hitOrigin(f); // la suprema di Bonobot colpisce sulla liana, non dove sta lui (#102)
  const front = spec.boxX ?? FIGHTER.width / 2;
  const x = f.facing === 1 ? o.x + front : o.x - front - spec.range;
  const y = o.y + (spec.boxY ?? -FIGHTER.height * 0.7);
  return { x, y, w: spec.range, h: spec.height };
}

export function bodyBox(f: Fighter): Box {
  return { x: f.x - FIGHTER.width / 2, y: f.y - FIGHTER.height, w: FIGHTER.width, h: FIGHTER.height };
}

export function overlap(a: Box, b: Box): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

// La presa e i lanci (#109): niente hitbox, li gestisce grab.ts
export const isGrabKind = (kind: AttackKind) => kind === "grab" || kind.startsWith("throw");

export const canBeHit = (f: Fighter) => !f.eliminated && !f.respawning && !f.invulnerable;

export function resolveHits(fighters: Fighter[], ctx: PhysicsContext): void {
  for (const attacker of fighters) {
    if (!attacker.attackActive || !attacker.attack || attacker.eliminated || attacker.respawning) continue;
    if (isGrabKind(attacker.attack)) continue; // presa e lanci non colpiscono col rettangolo (grab.ts)
    if (isCountering(attacker)) continue; // il contrattacco para, non colpisce (specials.ts)
    const spec = attackSpecFor(attacker);
    const box = attackBox(attacker);
    for (const target of fighters) {
      if (target === attacker || !canBeHit(target) || attacker.alreadyHit.has(target.id)) continue;
      if (ctx.canHit && !ctx.canHit(attacker, target)) continue;
      const body = bodyBox(target);
      if (!overlap(box, body)) continue;

      attacker.alreadyHit.add(target.id);
      // Il fermo si somma a quello in corso solo fino al massimo (più colpi nello stesso tick)
      const stop = Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * spec.damage);
      attacker.hitstopTimer = Math.max(attacker.hitstopTimer, stop);
      target.hitstopTimer = Math.max(target.hitstopTimer, stop);
      // Punto d'impatto: il centro della parte di hitbox che tocca il bersaglio
      const ix = (Math.max(box.x, body.x) + Math.min(box.x + box.w, body.x + body.w)) / 2;
      const iy = (Math.max(box.y, body.y) + Math.min(box.y + box.h, body.y + body.h)) / 2;

      // Contrattacco (E10): chi lo fa non prende niente e risponde
      if (isCountering(target)) {
        counterHit(target, attacker, spec.damage, Math.round(ix), Math.round(iy), ctx);
        break; // l'attacco di attacker è finito lì
      }

      // Sullo scudo (#109): niente percentuale né knockback, solo punti di scudo
      if (target.shielding) {
        hitShield(target, attacker.id, spec.damage, attacker.facing, Math.round(ix), Math.round(iy), ctx);
        continue;
      }

      launch(target, attacker, attacker.attack, Math.round(ix), Math.round(iy), ctx);
    }
  }
}

// Il colpo vero: percentuale e volo nella direzione in cui guarda chi colpisce. Lo usano anche i lanci della presa
// damage cambia il danno della mossa (la risposta del contrattacco dipende dal colpo parato)
export function launch(target: Fighter, attacker: Fighter, kind: AttackKind, x: number, y: number, ctx: PhysicsContext, damage?: number): void {
  const spec = damage === undefined ? attackSpecFor(attacker, kind) : { ...attackSpecFor(attacker, kind), damage };
  // Stile Smash/Brawlhalla: il danno non toglie vita, fa volare più lontano
  target.percent = Math.min(999, target.percent + spec.damage);
  chargeFromHit(attacker, target, spec.damage); // #101
  // Colpo ad area (#102): si vola via dal centro di chi colpisce
  const dir = spec.outward ? ((Math.sign(target.x - hitOrigin(attacker).x) || attacker.facing) as 1 | -1) : attacker.facing;
  const knockback = (spec.baseKnockback + spec.knockbackGrowth * target.percent) / characterStats(target.characterId).weight; // E11
  const angle = (spec.angleDeg * Math.PI) / 180;
  target.vx = dir * Math.cos(angle) * knockback;
  target.vy = -Math.sin(angle) * knockback;
  target.onGround = false;
  target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
  target.attack = null;
  target.attackActive = false;
  target.facing = (-dir) as 1 | -1;
  target.lastHitById = attacker.id;
  // Chi viene colpito può di nuovo usare il recupero (#11)
  target.recoveryUsed = false;
  target.helpless = false;
  clearStun(target);
  ctx.events.push({
    type: "hit",
    attackerId: attacker.id,
    targetId: target.id,
    kind,
    damage: spec.damage,
    percent: target.percent,
    knockback: Math.round(knockback),
    x,
    y,
  });
}
