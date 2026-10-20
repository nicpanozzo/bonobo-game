// Attacchi: inizio, finestra attiva, hitbox e cosa succede a chi viene colpito.

import { characterStats, getCharacter, SPECIAL_KINDS, specialAttackSpec, specialsFor, supremeAttackSpec, type SpecialSlot, type TweakableAttack } from "../characters";
import { ATTACKS, BIRRA, FIGHTER, HITSTOP, HITSTUN_PER_KNOCKBACK, JAB, MICELIO, POWERUP, SMASH_CHARGE, type AttackSpec } from "../constants";
import type { AttackKind, SpecialKind } from "../types";
import { biteBox, biting, chooseBiter, hitPets } from "./companion";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { clearStun, hitShield } from "./shield";
import { counterHit, isCountering, tryStartSpecial } from "./specials";
import { chargeFromHit, hitOrigin, infect, snatch, spinRehit, supremeMelee, tryStartSupreme } from "./supreme";

export function tryStartAttack(f: Fighter, ctx: PhysicsContext): void {
  if (f.hitstun || f.attack || f.helpless || f.dodgeTimer > 0) return;
  if (f.jumpSquatTimer > 0 || f.landingTimer > 0) return; // #384 A3: il tasto resta nel buffer, l'aereo parte staccandosi
  if (canChainJab(f) && pressed(f, "light")) return startJab(f, f.jabStep + 1, ctx); // la combo non aspetta l'attesa
  if (f.cooldownTimer > 0) return;
  if (tryStartSupreme(f, ctx)) return; // #101: solo con la barra piena
  if (pressed(f, "special")) tryStartSpecial(f, ctx); // E10
  else if (pressed(f, "heavy")) {
    const kind = f.dashing && f.onGround && !f.input.up && !f.input.down ? "dashAttack" : variant(f, "heavy"); // correndo, l'attacco in corsa
    startAttack(f, kind, ctx);
    if (f.onGround && SMASH_CHARGE.kinds.includes(kind)) f.smashChargeMs = 0; // tenendo premuto si carica
  }
  else if (pressed(f, "light")) {
    const kind = variant(f, "light");
    if (kind === "light" && f.onGround) startJab(f, 0, ctx);
    else startAttack(f, kind, ctx);
  }
}

// La combo di leggeri (JAB): il leggero neutro a terra andato a segno, premuto di nuovo entro windowMs dalla fine del colpo
const canChainJab = (f: Fighter) =>
  f.jabTimer > 0 && f.onGround && !f.input.up && !f.input.down && f.jabStep < JAB.steps.length;

function startJab(f: Fighter, step: number, ctx: PhysicsContext): void {
  startAttack(f, "light", ctx);
  f.jabStep = step;
  f.cooldownTimer = attackSpecFor(f).cooldownMs;
}

// Il leggero della combo è entrato: per un attimo dopo la sua fine il leggero fa il colpo dopo (dopo il finale si ricomincia)
function armJab(f: Fighter): void {
  if (f.attack !== "light" || !f.onGround || f.jabStep >= JAB.steps.length) return;
  const spec = attackSpecFor(f);
  f.jabTimer = Math.max(0, spec.startupMs + spec.activeMs - f.attackTimer) + JAB.windowMs;
}

// La variante viene dai tasti tenuti: su vince su tutto, poi l'aria, poi giù (a terra)
export function variant(f: Fighter, base: "light" | "heavy"): AttackKind {
  if (f.input.up) return `${base}Up`;
  if (!f.onGround) return `${base}Air`;
  if (f.input.down) return `${base}Down`;
  return base;
}

// I numeri di un attacco per questo lottatore (E10): quelli di ATTACKS, con i ritocchi del suo personaggio
// (il recupero e i colpi normali, characters.ts). Tutta la fisica degli attacchi li legge da qui
export function attackSpecFor(f: Fighter, kind: AttackKind | null = f.attack): AttackSpec {
  if (kind && isSpecialKind(kind)) {
    const spec = specialSpecFor(f.characterId, kind);
    return kind === f.attack && f.chargeMultiplier !== 1 ? charged(spec, f.chargeMultiplier) : spec;
  }
  if (kind === "supreme") return supremeAttackSpec(f.characterId) ?? ATTACKS.supreme; // #102: la sua, se ce l'ha
  const base = kind === "light" && kind === f.attack && f.jabStep > 0 ? JAB.steps[f.jabStep - 1] : ATTACKS[kind ?? "light"];
  const character = getCharacter(f.characterId);
  // il recupero ha i suoi numeri; gli altri colpi i ritocchi del personaggio (#384 D2), non nei colpi della combo
  const own = kind === "recovery" ? character.recovery : base === ATTACKS[kind ?? "light"] ? character.attacks?.[kind as TweakableAttack] : undefined;
  const spec = own ? { ...base, ...own } : base;
  return kind === f.attack && f.chargeMultiplier !== 1 ? charged(spec, f.chargeMultiplier) : spec; // colpo caricato
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
  f.attackAir = !f.onGround; // atterrando a colpo in corso si ferma con la sua pausa (#384 A3)
  f.chargeMultiplier = 1; // solo il rilascio della carica lo cambia, dopo questa chiamata
  if (f.smashChargeMs >= 0) endSmashCharge(f);
  f.jabStep = 0; // la combo la riprende startJab
  f.jabTimer = 0;
  f.cooldownTimer = attackSpecFor(f, kind).cooldownMs;
  f.alreadyHit.clear();
  chooseBiter(f); // il beagle di Lampione morde solo se è lì (#369)
  consume(f, "light", "heavy", "special"); // anche il recupero, l'attacco dal bordo e le speciali passano da qui
  ctx.events.push({ type: "attack", id: f.id, kind });
}

export function updateAttack(f: Fighter, dtMs: number): void {
  f.jabTimer = Math.max(0, f.jabTimer - dtMs);
  if (!f.attack) {
    f.attackActive = false;
    if (f.smashChargeMs >= 0) endSmashCharge(f); // colpiti, presi o finiti fuori mentre si caricava
    return;
  }
  if (f.smashChargeMs >= 0 && smashCharging(f, dtMs)) return;
  const spec = attackSpecFor(f);
  // il micelio rende più veloci gli attacchi normali di Dr. Micelium, non speciali e suprema
  f.attackTimer += f.powerup === "micelio" && f.attack !== "supreme" && !isSpecialKind(f.attack) ? dtMs * MICELIO.attackSpeedMult : dtMs;
  spinRehit(f, f.attackTimer, dtMs); // la suprema che gira colpisce a ogni giro (#358)
  f.attackActive = f.attackTimer >= spec.startupMs && f.attackTimer < spec.startupMs + spec.activeMs;
  if (f.attackTimer >= spec.startupMs + spec.activeMs) {
    f.attack = null;
    f.attackActive = false;
  }
}

// Il pesante tenuto premuto (SMASH_CHARGE): il colpo resta fermo prima dell'avvio finché si tiene il tasto,
// fino a maxMs. true se si sta ancora caricando. Al rilascio danno e knockback crescono con la carica
function smashCharging(f: Fighter, dtMs: number): boolean {
  if (f.input.heavy && f.smashChargeMs < SMASH_CHARGE.maxMs) {
    f.smashChargeMs = Math.min(SMASH_CHARGE.maxMs, f.smashChargeMs + dtMs);
    f.charge = Math.round((f.smashChargeMs / SMASH_CHARGE.maxMs) * 100) / 100;
    f.cooldownTimer += dtMs; // l'attesa dopo il colpo conta dal rilascio
    f.attackActive = false;
    return true;
  }
  f.chargeMultiplier = 1 + (SMASH_CHARGE.maxMultiplier - 1) * (f.smashChargeMs / SMASH_CHARGE.maxMs);
  endSmashCharge(f);
  return false;
}

function endSmashCharge(f: Fighter): void {
  f.smashChargeMs = -1;
  f.charge = 0;
}

type Box = { x: number; y: number; w: number; h: number };

// Rettangolo del colpo, dalla parte in cui si guarda (boxX/boxY lo spostano per le varianti)
export function attackBox(f: Fighter): Box {
  const spec = attackSpecFor(f);
  if (biting(f)) return biteBox(f, spec.range, spec.height); // morde il beagle di Lampione (#369)
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
    if (attacker.attack === "supreme" && !supremeMelee(attacker.characterId)) continue; // IRA colpisce coi proiettili (#358)
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
      armJab(attacker);
    }
    hitPets(attacker, box, spec.damage, fighters, attacker.alreadyHit, ctx); // anche il beagle di Lampione si colpisce (#369)
  }
}

// Il colpo vero: percentuale e volo nella direzione in cui guarda chi colpisce. Lo usano anche i lanci della presa
// damage cambia il danno della mossa (la risposta del contrattacco dipende dal colpo parato)
export function launch(target: Fighter, attacker: Fighter, kind: AttackKind, x: number, y: number, ctx: PhysicsContext, damage?: number): void {
  const base = damage === undefined ? attackSpecFor(attacker, kind) : { ...attackSpecFor(attacker, kind), damage };
  // Potenziati dal fiore (#231) i colpi fanno più danno; il volo cresce già con la percentuale
  // La birra (#302) picchia ancora più forte
  const mult = attacker.powerup === "fiore" ? POWERUP.damageMult : attacker.powerup === "birra" ? BIRRA.damageMult : attacker.powerup === "micelio" ? MICELIO.damageMult : 1; // il micelio di Dr. Micelium (#358)
  const spec = mult !== 1 ? { ...base, damage: Math.round(base.damage * mult * 10) / 10 } : base;
  // Stile Smash/Brawlhalla: il danno non toglie vita, fa volare più lontano
  target.percent = Math.min(999, target.percent + spec.damage);
  chargeFromHit(attacker, target, spec.damage); // #101
  // Colpo ad area (#102): si vola via dal centro di chi colpisce
  const dir = spec.outward ? ((Math.sign(target.x - hitOrigin(attacker).x) || attacker.facing) as 1 | -1) : attacker.facing;
  const knockback = (spec.baseKnockback + spec.knockbackGrowth * target.percent) / characterStats(target.characterId).weight; // E11
  const angle = ((kind === "supreme" ? snatch(attacker, target, spec.angleDeg) : spec.angleDeg) * Math.PI) / 180; // snaack di Lampione (#358) tira e schiaccia
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
  if (kind === "supreme") infect(attacker, target, ctx); // il filo di Kirschner di Dr. Micelium (#358)
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
