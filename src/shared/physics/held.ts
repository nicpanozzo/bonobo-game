// Oggetti da impugnare e da sparo (Nicola, 5 novembre 2026), ognuno con la sua versione rara alla The Binding of Isaac:
//   impugnatura: J fa le mosse normali del personaggio più lunghe e forti, K lancia l'arma. La scopa (rara: l'ombrellone,
//     colpi verso l'alto e si plana), il pesce surgelato che congela (raro: l'anguilla, scossa a catena)
//   sparo: J spara, K lancia. La pistola ad acqua (rara: l'idrante, J tenuto carica un getto), lo sparabolle che chiude
//     in una bolla che sale (raro: tre bolle a ventaglio che rimbalzano)
// I colpi sparati sono oggetti (shot in items.ts) che volano dritti. Numeri in HELD (constants.ts).

import { characterStats } from "../characters";
import { FIGHTER, HELD, HITSTOP, HITSTUN_PER_KNOCKBACK, ITEM_RULES } from "../constants";
import { ITEMS } from "../items";
import type { AttackKind } from "../types";
import { bodyBox, overlap } from "./attacks";
import { pressed, type Fighter, type PhysicsContext } from "./fighter";
import { gearKnockbackMult } from "./gear";
import type { Item, ItemWorld } from "./items";
import { clearStun, hitShield } from "./shield";
import { chargeFromHit } from "./supreme";

type Melee = NonNullable<(typeof ITEMS)[string]["melee"]>;
const meleeOf = (f: Fighter): Melee | undefined => (f.heldKind ? ITEMS[f.heldKind]?.melee : undefined);

// Le mosse che l'arma rinforza: quelle normali, non speciali, prese o suprema
const armed = (kind: AttackKind | null) => !!kind && (kind.startsWith("light") || kind.startsWith("heavy") || kind.startsWith("air") || kind === "dashAttack");

// Pixel di portata in più dell'arma in mano (attackBox in attacks.ts)
export function meleeReach(f: Fighter): number {
  const m = meleeOf(f);
  return m && armed(f.attack) ? HELD[m].reach : 0;
}

// Percentuale in più dei colpi con l'arma in mano (launch in attacks.ts)
export function meleeDamage(f: Fighter, kind: AttackKind): number {
  const m = meleeOf(f);
  return m && armed(kind) ? HELD[m].damage : 0;
}

// Un colpo con l'arma è andato a segno (resolveHits in attacks.ts): conta l'uso e fa l'effetto dell'arma
export function meleeHit(attacker: Fighter, target: Fighter, fighters: Fighter[], ctx: PhysicsContext): void {
  const m = meleeOf(attacker);
  if (!m || !armed(attacker.attack)) return;
  attacker.meleeHits = (attacker.meleeHits ?? 0) + 1;
  if (m === "ombrellone") {
    // il colpo lancia in alto, con la stessa forza
    const speed = Math.hypot(target.vx, target.vy);
    const a = (HELD.ombrellone.launchDeg * Math.PI) / 180;
    target.vx = Math.sign(target.vx || attacker.facing) * Math.cos(a) * speed;
    target.vy = -Math.sin(a) * speed;
  } else if (m === "pesce") {
    freeze(target, HELD.pesce.freezeMs, attacker.heldKind!, ctx);
  } else if (m === "anguilla") {
    stun(target, HELD.anguilla.zapStunMs);
    for (const t of fighters) {
      if (t === target || t === attacker || t.eliminated || t.respawning || t.invulnerable) continue;
      if (ctx.canHit && !ctx.canHit(attacker, t)) continue;
      if (Math.hypot(t.x - target.x, t.y - target.y) > HELD.anguilla.zapRadius) continue;
      t.percent = Math.min(999, t.percent + HELD.anguilla.zapDamage);
      t.lastHitById = attacker.id;
      stun(t, HELD.anguilla.zapStunMs);
      t.hitstopTimer = Math.max(t.hitstopTimer, HITSTOP.baseMs);
      // x, y: da dove parte la scossa (chi è stato colpito); id: chi la prende
      ctx.events.push({ type: "gear", phase: "zap", kind: "anguilla", id: t.id, x: Math.round(target.x), y: Math.round(target.y - FIGHTER.height / 2) });
    }
  }
}

// Fermi e colpibili come con lo scudo rotto, finché dura
function stun(f: Fighter, ms: number) {
  f.stunTimer = Math.max(f.stunTimer, ms);
  f.stunned = true;
}

// Congelati dal pesce: fermi in un blocco di ghiaccio (powerup "gelo" per il disegno)
function freeze(f: Fighter, ms: number, kind: string, ctx: PhysicsContext) {
  stun(f, ms);
  f.powerup = "gelo";
  f.powerupMs = ms;
  ctx.events.push({ type: "gear", phase: "freeze", kind, id: f.id, x: Math.round(f.x), y: Math.round(f.y) });
}

// L'ombrellone in mano: tenendo il salto si scende piano (index.ts, dopo la gravità)
export function glide(f: Fighter): void {
  if (meleeOf(f) !== "ombrellone" || f.onGround || !f.input.jump || f.hitstun) return;
  if (f.vy > HELD.ombrellone.glideFallSpeed) f.vy = HELD.ombrellone.glideFallSpeed;
}

// J con un oggetto in mano (handleItemInput in items.ts). Restituisce true se J l'ha usato lui: le armi da impugnare
// lasciano il tasto all'attacco, quelle da sparo sparano (l'idrante comincia a caricare)
export function useHeld(world: ItemWorld, item: Item, f: Fighter, ctx: PhysicsContext): "attack" | "used" | null {
  const spec = ITEMS[item.kind];
  if (!pressed(f, "light") || f.input.down) return null; // giù + J lo posa come sempre
  if (spec.melee) return "attack";
  if (!spec.gun) return null;
  if ((item.cooldownMs ?? 0) > 0) return "used";
  if (spec.gun === "idrante") {
    item.loadMs = 0; // tenendo J si carica (stepHeld)
    return "used";
  }
  fire(world, item, f, ctx);
  return "used";
}

const ammoOf = (item: Item) => item.uses ?? HELD[ITEMS[item.kind].gun === "triplo" ? "sparabolle" : (ITEMS[item.kind].gun as "pistola" | "idrante" | "sparabolle")].ammo;

// Un colpo della pistola o dello sparabolle: un oggetto che vola dritto da davanti a chi spara
// droplet: la goccia dell'idrante lasciato presto, che non consuma getti
function fire(world: ItemWorld, item: Item, f: Fighter, ctx: PhysicsContext, droplet = false) {
  const gun = droplet ? "pistola" : ITEMS[item.kind].gun!;
  const bubbles = gun === "sparabolle" || gun === "triplo";
  const sp = bubbles ? HELD.sparabolle : HELD.pistola;
  const angles = gun === "triplo" ? [-HELD.sparabolle.spreadDeg, 0, HELD.sparabolle.spreadDeg] : [0];
  for (const deg of angles) {
    const a = (deg * Math.PI) / 180;
    const shot: Item = {
      id: world.nextId++,
      kind: gun === "triplo" ? "bollaRimbalzina" : bubbles ? "bolla" : "goccia",
      x: Math.round(f.x + f.facing * (ITEM_RULES.holdOffsetX + 14)),
      y: Math.round(f.y - ITEM_RULES.holdOffsetY + 8),
      vx: f.facing * sp.speed * Math.cos(a),
      vy: -sp.speed * Math.sin(a) - (bubbles ? 0 : HELD.pistola.lift),
      heldBy: null,
      thrown: true,
      onGround: false,
      riding: -1,
      thrownBy: f.id,
      lifeMs: ITEM_RULES.lifeMs,
      flyMs: sp.flyMs,
    };
    world.items.push(shot);
  }
  item.cooldownMs = sp.cooldownMs;
  ctx.events.push({ type: "gear", phase: "shot", kind: droplet ? "pistola" : item.kind, id: f.id, x: Math.round(f.x + f.facing * ITEM_RULES.holdOffsetX), y: Math.round(f.y - ITEM_RULES.holdOffsetY) });
  if (droplet) return;
  item.uses = ammoOf(item) - 1;
  if (item.uses <= 0) empty(item, f, ctx);
}

// Senza colpi l'arma sparisce di mano
function empty(item: Item, f: Fighter, ctx: PhysicsContext) {
  item.lifeMs = 0;
  item.heldBy = null;
  f.heldKind = undefined;
  ctx.events.push({ type: "gear", phase: "break", kind: item.kind, id: f.id, x: Math.round(item.x), y: Math.round(item.y) });
}

// L'arma in mano, a ogni passo (stepItems in items.ts): ricarica, getto dell'idrante, arma rotta dopo i suoi colpi
export function stepHeld(world: ItemWorld, item: Item, f: Fighter, fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  const spec = ITEMS[item.kind];
  f.heldKind = item.kind;
  item.cooldownMs = Math.max(0, (item.cooldownMs ?? 0) - dtMs);
  if (spec.melee && (f.meleeHits ?? 0) >= HELD[spec.melee].uses) {
    f.meleeHits = 0;
    empty(item, f, ctx);
    return;
  }
  if (spec.gun !== "idrante" || (item.loadMs ?? -1) < 0) return;
  if (f.input.light) {
    item.loadMs = Math.min(HELD.idrante.chargeMs, item.loadMs! + dtMs);
    return;
  }
  const full = item.loadMs! >= HELD.idrante.chargeMs;
  item.loadMs = -1;
  if (full) jet(item, f, fighters, ctx);
  else fire(world, item, f, ctx, true); // lasciato presto: una goccia, senza consumare getti
  item.cooldownMs = HELD.pistola.cooldownMs;
  if (full) {
    item.uses = ammoOf(item) - 1;
    if (item.uses <= 0) empty(item, f, ctx);
  }
}

// Il getto dell'idrante: un rettangolo lungo davanti a chi spara, prende tutti quelli dentro
function jet(item: Item, f: Fighter, fighters: Fighter[], ctx: PhysicsContext) {
  const sp = HELD.idrante;
  const y = f.y - ITEM_RULES.holdOffsetY;
  const box = { x: f.facing === 1 ? f.x : f.x - sp.length, y: y - sp.height / 2, w: sp.length, h: sp.height };
  ctx.events.push({ type: "gear", phase: "jet", kind: item.kind, id: f.id, x: Math.round(f.x + f.facing * ITEM_RULES.holdOffsetX), y: Math.round(y), r: f.facing * sp.length });
  for (const t of fighters) {
    if (t === f || t.eliminated || t.respawning || t.invulnerable) continue;
    if (ctx.canHit && !ctx.canHit(f, t)) continue;
    const body = bodyBox(t);
    if (!overlap(box, body)) continue;
    strike(t, f, sp.damage, sp.knockback, sp.knockbackGrowth, sp.angleDeg, f.facing, item.kind, Math.round(t.x), Math.round(y), ctx);
  }
}

// Un colpo d'oggetto: percentuale e volo nella direzione dir, lo scudo para
function strike(target: Fighter, by: Fighter, damage: number, base: number, growth: number, angleDeg: number, dir: 1 | -1, itemKind: string, x: number, y: number, ctx: PhysicsContext) {
  if (target.shielding) {
    hitShield(target, by.id, damage, dir, x, y, ctx);
    return;
  }
  target.percent = Math.min(999, target.percent + damage);
  chargeFromHit(by, target, damage);
  const knockback = ((base + growth * target.percent) / characterStats(target.characterId).weight) * gearKnockbackMult(target);
  const a = (angleDeg * Math.PI) / 180;
  target.vx = dir * Math.cos(a) * knockback;
  target.vy = -Math.sin(a) * knockback;
  target.onGround = false;
  target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
  target.attack = null;
  target.attackActive = false;
  target.facing = (-dir) as 1 | -1;
  target.lastHitById = by.id;
  target.recoveryUsed = false;
  target.helpless = false;
  clearStun(target);
  popBubble(target, ctx, false);
  target.hitstopTimer = Math.max(target.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * damage));
  ctx.events.push({ type: "hit", attackerId: by.id, targetId: target.id, kind: "item", itemKind, damage, percent: target.percent, knockback: Math.round(knockback), x, y });
}

// Un colpo sparato in volo (stepItems): dura flyMs, poi sparisce (la bolla scoppia)
export function stepShot(item: Item, dtMs: number, ctx: PhysicsContext): void {
  if (!ITEMS[item.kind].shot) return;
  item.flyMs = (item.flyMs ?? 0) - dtMs;
  if (item.flyMs <= 0 && item.lifeMs > 0) {
    item.lifeMs = 0;
    ctx.events.push({ type: "gear", phase: "pop", kind: item.kind, id: item.thrownBy ?? "", x: Math.round(item.x), y: Math.round(item.y) });
  }
}

// Gravità di un colpo sparato: la goccia scende un po', le bolle galleggiano
export const shotGravityMult = (item: Item) => (ITEMS[item.kind].shot === "goccia" ? 0.25 : ITEMS[item.kind].shot ? 0 : 1);

// Un colpo sparato tocca terra: la goccia si spiaccica, la bolla rimbalzina rimbalza, la bolla scoppia
export function shotLands(item: Item, ctx: PhysicsContext): void {
  const shot = ITEMS[item.kind].shot;
  if (!shot || !item.onGround) return;
  if (shot === "rimbalzina") {
    item.vy = -HELD.bolla.bounceVy;
    item.onGround = false;
    item.thrown = true; // settle l'aveva fermato: rimbalzando colpisce ancora
    return;
  }
  item.lifeMs = 0;
  ctx.events.push({ type: "gear", phase: "pop", kind: item.kind, id: "", x: Math.round(item.x), y: Math.round(item.y) });
}

// Una bolla tocca qualcuno (hitWithItem in items.ts): ci resta chiuso e sale
export function trapInBubble(item: Item, target: Fighter, ctx: PhysicsContext): void {
  item.lifeMs = 0;
  if (target.shielding) {
    ctx.events.push({ type: "gear", phase: "pop", kind: item.kind, id: target.id, x: Math.round(item.x), y: Math.round(item.y) });
    return;
  }
  target.powerup = "bolla";
  target.powerupMs = HELD.bolla.trapMs;
  target.trappedBy = item.thrownBy ?? undefined;
  target.lastHitById = item.thrownBy;
  target.attack = null;
  target.attackActive = false;
  target.onGround = false;
  ctx.events.push({ type: "gear", phase: "trap", kind: item.kind, id: target.id, x: Math.round(target.x), y: Math.round(target.y) });
}

// Chiusi nella bolla (stepFighter in index.ts): niente tasti né gravità, si sale piano. True se si è dentro
export function floatInBubble(f: Fighter, dtMs: number): boolean {
  if (f.powerup !== "bolla" || f.powerupMs <= 0) return false;
  const dt = dtMs / 1000;
  f.vx *= 0.9;
  f.vy = -HELD.bolla.riseSpeed;
  f.x += f.vx * dt;
  f.y += f.vy * dt;
  return true;
}

// La bolla scoppia: da sola (finito il tempo, un po' di danno e un saltello) o per un colpo (niente)
export function popBubble(f: Fighter, ctx: PhysicsContext, timeUp: boolean): boolean {
  if (f.powerup !== "bolla") return false;
  f.powerup = null;
  f.powerupMs = 0;
  if (timeUp) {
    f.percent = Math.min(999, f.percent + HELD.bolla.popDamage);
    f.vy = -HELD.bolla.popVy;
  }
  ctx.events.push({ type: "gear", phase: "pop", kind: "bolla", id: f.id, x: Math.round(f.x), y: Math.round(f.y - FIGHTER.height / 2) });
  ctx.events.push({ type: "powerEnd", id: f.id, kind: "bolla" });
  return true;
}
