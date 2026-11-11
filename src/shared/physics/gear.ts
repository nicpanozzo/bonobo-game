// Oggetti per categoria (Nicola, 5 novembre 2026): quello che fanno gli oggetti nuovi oltre a cadere, farsi raccogliere
// e farsi lanciare (items.ts). Ogni oggetto ha la sua versione rara con una cosa particolare, come in The Binding of Isaac.
//   lancio: la ciabatta (quella della mamma insegue), il petardo che si attacca e scoppia (a grappolo: sparge petardini)
//   consumo: il caffè (la moka a razzo fa volare), il brownie spaziale con l'effetto a sorpresa (della nonna: gigante)
// Numeri in GEAR (constants.ts), catalogo in ITEMS (items.ts).

import { characterStats } from "../characters";
import { FIGHTER, GEAR, HITSTOP, HITSTUN_PER_KNOCKBACK, ITEM_RULES } from "../constants";
import { ITEMS } from "../items";
import { bodyBox } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";
import type { Item, ItemWorld } from "./items";
import { clearStun, hitShield } from "./shield";
import { chargeFromHit } from "./supreme";

// Gli effetti del brownie spaziale, buoni e cattivi: si sceglie a caso quando lo si mangia e si scopre dopo
export const BROWNIE_EFFECTS = ["gigante", "mini", "caffe", "trip", "sonno"] as const;

// Quanto si va veloci con i potenziamenti degli oggetti per categoria (movement.ts)
export function gearSpeedMult(f: Fighter): number {
  switch (f.powerup) {
    case "caffe":
      return GEAR.caffe.speedMult;
    case "razzo":
      return GEAR.moka.speedMult;
    case "gigante":
    case "colosso":
      return GEAR.size.giantSpeedMult;
    case "mini":
      return GEAR.size.miniSpeedMult;
  }
  return 1;
}

// Gli attacchi col caffè vanno più svelti (attacks.ts, come il micelio)
export const gearAttackSpeed = (f: Fighter) => (f.powerup === "caffe" ? GEAR.caffe.attackSpeedMult : 1);

// Il danno dei colpi dati da giganti e mini (attacks.ts)
export function gearDamageMult(f: Fighter): number {
  if (f.powerup === "gigante" || f.powerup === "colosso") return GEAR.size.giantDamageMult;
  if (f.powerup === "mini") return GEAR.size.miniDamageMult;
  return 1;
}

// Quanto vola via chi viene colpito: i giganti pesano, i mini volano (attacks.ts)
export function gearKnockbackMult(f: Fighter): number {
  if (f.powerup === "gigante" || f.powerup === "colosso") return GEAR.size.giantKnockbackMult;
  if (f.powerup === "mini") return GEAR.size.miniKnockbackMult;
  return 1;
}

// La moka a razzo: tenendo il salto si sale, dopo la gravità (index.ts). Non si è inermi dopo il recupero
export function fly(f: Fighter, dt: number): void {
  if (f.powerup !== "razzo" || f.powerupMs <= 0 || !f.input.jump || f.hitstun || f.onGround) return;
  f.vy = Math.max(-GEAR.moka.maxRise, f.vy - GEAR.moka.thrust * dt);
  f.helpless = false;
}

// Mangiato il brownie: l'effetto si sceglie subito (col caso della partita), ma si scopre solo finita l'attesa
export function eatBrownie(f: Fighter, r: number): void {
  f.brownieNext = BROWNIE_EFFECTS[Math.min(BROWNIE_EFFECTS.length - 1, Math.floor(r * BROWNIE_EFFECTS.length))];
}

// Finita l'attesa del brownie sale l'effetto (tickPowerup in items.ts). Restituisce false se non è un brownie
export function brownieKicksIn(f: Fighter, ctx: PhysicsContext): boolean {
  if (f.powerup !== "brownie") return false;
  const kind = f.brownieNext ?? "gigante";
  f.brownieNext = undefined;
  f.powerup = kind;
  f.powerupMs = kind === "sonno" ? GEAR.brownie.sleepMs : GEAR.brownie.effectMs;
  if (kind === "sonno") {
    // addormentati: fermi e colpibili come con lo scudo rotto
    f.stunTimer = GEAR.brownie.sleepMs;
    f.stunned = true;
    f.attack = null;
    f.attackActive = false;
  }
  ctx.events.push({ type: "powerUp", itemId: -1, id: f.id, kind, x: Math.round(f.x), y: Math.round(f.y) });
  return true;
}

// Il brownie della nonna: da giganti ogni atterraggio fa tremare la terra, e chi è a terra vicino salta via (index.ts)
export function quakes(fighters: Fighter[], ctx: PhysicsContext, firstEvent: number): void {
  for (let i = firstEvent; i < ctx.events.length; i++) {
    const e = ctx.events[i];
    if (e.type !== "land") continue;
    const giant = fighters.find((f) => f.id === e.id && f.powerup === "colosso");
    if (!giant) continue;
    ctx.events.push({ type: "gear", phase: "quake", kind: "brownieNonna", id: giant.id, x: Math.round(giant.x), y: Math.round(giant.y), r: GEAR.size.quakeRadius });
    for (const t of fighters) {
      if (t === giant || !t.onGround || t.eliminated || t.respawning || t.invulnerable) continue;
      if (ctx.canHit && !ctx.canHit(giant, t)) continue;
      if (Math.abs(t.x - giant.x) > GEAR.size.quakeRadius || Math.abs(t.y - giant.y) > FIGHTER.height) continue;
      t.percent = Math.min(999, t.percent + GEAR.size.quakeDamage);
      t.vy = -GEAR.size.quakeVy;
      t.onGround = false;
      t.lastHitById = giant.id;
    }
  }
}

// Un oggetto lanciato: come vola (items.ts). La ciabatta tesa, quella della mamma senza gravità mentre insegue
export function itemGravityMult(item: Item): number {
  const spec = ITEMS[item.kind];
  if (spec.homing && item.thrown && (item.homeMs ?? 0) > 0) return 0;
  return item.thrown && spec.throwSpec ? spec.throwSpec.gravityMult : 1;
}

// Lanciato o posato: la ciabatta della mamma comincia a inseguire, il petardo si accende
export function onThrow(item: Item, f: Fighter, ctx: PhysicsContext): void {
  const spec = ITEMS[item.kind];
  if (spec.homing && item.thrown) item.homeMs = GEAR.ciabattaMamma.homingMs;
  if (spec.petardo) light(item, f.id, GEAR.petardo.fuseMs, ctx);
}

function light(item: Item, by: string, ms: number, ctx: PhysicsContext) {
  item.fuseMs = ms;
  item.fuseTotal = ms;
  item.lighter = by;
  ctx.events.push({ type: "gear", phase: "fuse", kind: item.kind, id: by, x: Math.round(item.x), y: Math.round(item.y) });
}

// Un petardo acceso non si raccoglie più
export const lit = (item: Item) => item.fuseMs !== undefined;

// Quanto è bruciata la miccia, da 0 a 1 (snapshot: load)
export const fuseLoad = (item: Item) => (item.fuseTotal ? Math.round((1 - (item.fuseMs ?? 0) / item.fuseTotal) * 100) / 100 : undefined);

// Il petardo lanciato tocca qualcuno: gli si attacca addosso, niente colpo (hitWithItem in items.ts)
export function stickTo(item: Item, target: Fighter, ctx: PhysicsContext): void {
  item.stuckTo = target.id;
  item.thrown = false;
  item.thrownBy = null;
  item.vx = 0;
  item.vy = 0;
  ctx.events.push({ type: "gear", phase: "stick", kind: item.kind, id: target.id, x: Math.round(item.x), y: Math.round(item.y) });
}

// Un passo di un oggetto per categoria (stepItems in items.ts): la ciabatta che insegue, il petardo attaccato che segue
// chi ce l'ha addosso e la miccia che brucia. Restituisce true se l'oggetto ha già la sua posizione per questo passo
export function stepGearItem(world: ItemWorld, item: Item, fighters: Fighter[], dtMs: number, ctx: PhysicsContext): boolean {
  const spec = ITEMS[item.kind];
  if (spec.homing && item.thrown && (item.homeMs ?? 0) > 0) home(item, fighters, dtMs, ctx);
  if (!spec.petardo || item.fuseMs === undefined) return false;
  let placed = false;
  if (item.stuckTo) {
    const host = fighters.find((f) => f.id === item.stuckTo);
    if (host && !host.eliminated && !host.respawning) {
      item.x = host.x;
      item.y = host.y - FIGHTER.height * 0.45;
      item.vx = host.vx;
      item.vy = host.vy;
      placed = true;
    } else item.stuckTo = undefined; // chi l'aveva addosso è uscito: cade lì
  }
  item.fuseMs -= dtMs;
  if (item.fuseMs <= 0) explode(world, item, fighters, ctx);
  return placed;
}

// La ciabatta della mamma vira verso l'avversario più vicino di chi l'ha lanciata, a velocità costante
function home(item: Item, fighters: Fighter[], dtMs: number, ctx: PhysicsContext) {
  item.homeMs = (item.homeMs ?? 0) - dtMs;
  const thrower = fighters.find((f) => f.id === item.thrownBy);
  let best: Fighter | null = null;
  let bestD = Infinity;
  for (const t of fighters) {
    if (t.id === item.thrownBy || t.eliminated || t.respawning) continue;
    if (thrower && ctx.canHit && !ctx.canHit(thrower, t)) continue;
    const d = (t.x - item.x) ** 2 + (t.y - FIGHTER.height / 2 - item.y) ** 2;
    if (d < bestD) {
      bestD = d;
      best = t;
    }
  }
  const sp = GEAR.ciabattaMamma;
  const heading = Math.atan2(item.vy, item.vx);
  let turn = 0;
  if (best) {
    const want = Math.atan2(best.y - FIGHTER.height / 2 - item.y, best.x - item.x);
    turn = Math.atan2(Math.sin(want - heading), Math.cos(want - heading));
    const max = ((sp.turnDegPerSec * Math.PI) / 180) * (dtMs / 1000);
    turn = Math.max(-max, Math.min(max, turn));
  }
  item.vx = Math.cos(heading + turn) * sp.speed;
  item.vy = Math.sin(heading + turn) * sp.speed;
}

// Lo scoppio: chi è nel raggio vola via dal centro, anche chi l'ha acceso. Il petardo a grappolo sparge petardini
function explode(world: ItemWorld, item: Item, fighters: Fighter[], ctx: PhysicsContext) {
  const sp = GEAR.petardo;
  const mini = ITEMS[item.kind].petardo === "mini";
  const radius = mini ? sp.clusterRadius : sp.radius;
  const damage = mini ? sp.clusterDamage : sp.damage;
  const knockback = mini ? sp.clusterKnockback : sp.knockback;
  const cx = item.x;
  const cy = item.y - ITEMS[item.kind].height / 2;
  item.lifeMs = 0;
  item.fuseMs = undefined;
  ctx.events.push({ type: "gear", phase: "boom", kind: item.kind, id: item.lighter ?? "", x: Math.round(cx), y: Math.round(cy), r: radius });
  blast(cx, cy, radius, damage, knockback, item.lighter ?? null, item.kind, fighters, ctx);
  if (ITEMS[item.kind].petardo !== "grappolo") return;
  for (let k = 0; k < sp.clusterCount; k++) {
    const side = k % 2 === 0 ? 1 : -1;
    const spread = 0.45 + 0.55 * Math.floor(k / 2); // due vicini, due lontani
    const p: Item = {
      id: world.nextId++,
      kind: "petardino",
      x: Math.round(cx),
      y: Math.round(cy),
      vx: side * sp.clusterSpeed * spread,
      vy: -sp.clusterLift,
      heldBy: null,
      thrown: false,
      onGround: false,
      riding: -1,
      thrownBy: null,
      lifeMs: ITEM_RULES.lifeMs,
    };
    world.items.push(p);
    ctx.events.push({ type: "itemSpawn", itemId: p.id, kind: "petardino", x: p.x, y: p.y });
    p.fuseMs = p.fuseTotal = sp.clusterFuseMs + k * sp.clusterStepMs;
    p.lighter = item.lighter;
  }
}

// Un'esplosione rotonda: percentuale e volo dal centro verso fuori, lo scudo para. byId prende il KO (non di sé stesso).
// spareBy: non prende byId (la bomba di …COSA?, supreme.ts)
export function blast(cx: number, cy: number, radius: number, damage: number, base: number, byId: string | null, itemKind: string, fighters: Fighter[], ctx: PhysicsContext, spareBy = false) {
  const by = fighters.find((f) => f.id === byId);
  for (const target of fighters) {
    if (target.eliminated || target.respawning || target.invulnerable) continue;
    if (spareBy && target === by) continue;
    if (by && target !== by && ctx.canHit && !ctx.canHit(by, target)) continue;
    const body = bodyBox(target);
    const nx = Math.max(body.x, Math.min(cx, body.x + body.w));
    const ny = Math.max(body.y, Math.min(cy, body.y + body.h));
    if ((nx - cx) ** 2 + (ny - cy) ** 2 > radius ** 2) continue;
    const dir = (Math.sign(target.x - cx) || 1) as 1 | -1;
    if (target.shielding) {
      hitShield(target, byId ?? "", damage, dir, Math.round(nx), Math.round(ny), ctx);
      continue;
    }
    target.percent = Math.min(999, target.percent + damage);
    if (by && by !== target) chargeFromHit(by, target, damage);
    const knockback = ((base + GEAR.petardo.knockbackGrowth * target.percent) / characterStats(target.characterId).weight) * gearKnockbackMult(target);
    const angle = (GEAR.petardo.angleDeg * Math.PI) / 180;
    target.vx = dir * Math.cos(angle) * knockback;
    target.vy = -Math.sin(angle) * knockback;
    target.onGround = false;
    target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
    target.attack = null;
    target.attackActive = false;
    target.facing = (-dir) as 1 | -1;
    if (by && by !== target) target.lastHitById = by.id;
    target.recoveryUsed = false;
    target.helpless = false;
    clearStun(target);
    target.hitstopTimer = Math.max(target.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * damage));
    ctx.events.push({
      type: "hit",
      attackerId: byId ?? "",
      targetId: target.id,
      kind: "item",
      itemKind,
      damage,
      percent: target.percent,
      knockback: Math.round(knockback),
      x: Math.round(nx),
      y: Math.round(ny),
    });
  }
}
