// Oggetti (#17 passo 3): cadono dal cielo, si raccolgono e si lanciano. Logica pura come il resto
// di physics/: il caso viene da un generatore con seme, così la partita resta ripetibile.
//   handleItemInput() prima di stepWorld: J o K vicino a un oggetto lo raccoglie, con l'oggetto in mano lo lancia
//   stepItems() dopo stepWorld: comparsa, caduta, oggetti in mano e colpi di quelli lanciati

import { characterStats } from "../characters";
import { BONG, FIGHTER, FUNGHI, FUNGO, HITSTOP, HITSTUN_PER_KNOCKBACK, ITEM_RULES } from "../constants";
import { DROPPABLE_ITEMS, ITEMS, itemWeight } from "../items";
import type { ItemSpot } from "../stages";
import { rng } from "../stageGenerator";
import type { ItemState } from "../types";
import { endArcade, isArcade, startArcade } from "./arcade";
import { bodyBox } from "./attacks";
import { callBassanese } from "./bassanese";
import { moverHere, moverPlace } from "./elements";
import { chargeFromHit } from "./supreme";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { clearStun, hitShield } from "./shield";
import { platformSurfaceY } from "./stage";

export interface Item extends ItemState {
  onGround: boolean;
  riding: number; // indice della piattaforma mobile su cui è appoggiato, -1 se nessuna (#14)
  thrownBy: string | null;
  lifeMs: number; // ms che restano a terra prima di sparire
  ownerId?: string; // il funghetto piantato (#302): chi l'ha piantato, a lui non scatta
  uses?: number; // il sacchetto dei funghetti: quanti ne restano
  armMs?: number; // il funghetto piantato: ms prima che scatti
  loadMs?: number; // il bong (#302): ms di carica tenendo J, assente o -1 se non lo si carica
  plantBy?: string; // il fungo di Teemo lanciato o posato (#419): chi lo piazzerà quando tocca terra
  plantDir?: 1 | -1; // il fungo di Teemo lanciato: verso dove rimbalza se cade su un altro fungo
}

export interface ItemWorld {
  items: Item[];
  nextId: number;
  spawnTimer: number;
  random: () => number;
  everyMs: number; // ogni quanto ne cade uno (regole della stanza, ITEM_AMOUNTS)
  maxOnStage: number; // quanti al massimo in campo insieme
  kinds: readonly string[]; // quali possono cadere
}

export interface ItemOptions {
  everyMs?: number;
  maxOnStage?: number;
  kinds?: readonly string[];
}

// Senza opzioni cadono tutti, coi tempi di ITEM_RULES
export function createItemWorld(seed: number, options: ItemOptions = {}): ItemWorld {
  const everyMs = options.everyMs ?? ITEM_RULES.spawnEveryMs;
  return {
    items: [],
    nextId: 1,
    // Con tanti oggetti anche il primo arriva prima
    spawnTimer: Math.min(ITEM_RULES.firstSpawnMs, everyMs),
    random: rng(seed).next,
    everyMs,
    maxOnStage: options.maxOnStage ?? ITEM_RULES.maxOnStage,
    kinds: options.kinds ?? DROPPABLE_ITEMS,
  };
}

// Si ricomincia: via gli oggetti, il primo ricade dopo l'attesa iniziale
export function resetItems(world: ItemWorld): void {
  world.items = [];
  world.spawnTimer = Math.min(ITEM_RULES.firstSpawnMs, world.everyMs);
}

// Un funghetto piantato o un fungo di Teemo piazzato (ha un proprietario): non si raccoglie, scatta sugli avversari
// e non conta tra gli oggetti che cadono
const isPlanted = (i: Item) => !!ITEMS[i.kind].planted || (!!ITEMS[i.kind].shroom && i.ownerId !== undefined);

// Non si raccoglie né si lancia mentre si è occupati: colpiti, in attacco, in schivata o inermi dopo il recupero
const busy = (f: Fighter) =>
  f.eliminated || f.respawning || f.hitstun || f.hitstopTimer > 0 || f.attack !== null || f.helpless || f.dodgeTimer > 0 || isArcade(f);

// Il tasto usato per l'oggetto non deve far partire anche un attacco: lo si segna come già premuto
function consumeAttackKeys(f: Fighter) {
  f.prevInput = { ...f.prevInput, light: f.input.light, heavy: f.input.heavy };
  consume(f, "light", "heavy");
}

export function handleItemInput(world: ItemWorld, fighters: Fighter[], ctx: PhysicsContext): void {
  for (const f of fighters) {
    if (busy(f) || f.cooldownTimer > 0 || !(pressed(f, "light") || pressed(f, "heavy"))) continue;
    // Fatti col bong (#302): J o K soffia la nuvola, prima di tutto il resto
    if (f.powerup === "bong") {
      blowCloud(f, fighters, ctx);
      consumeAttackKeys(f);
      continue;
    }
    const held = world.items.find((i) => i.heldBy === f.id);
    // Il bong in mano: J comincia a caricarlo (lo si tiene premuto, stepItems conta), K lo lancia come gli altri
    if (held && ITEMS[held.kind].bong && pressed(f, "light") && !f.input.down && (held.loadMs ?? -1) < 0) {
      held.loadMs = 0;
      ctx.events.push({ type: "bong", phase: "load", id: f.id, x: Math.round(f.x), y: Math.round(f.y) });
      consumeAttackKeys(f);
      continue;
    }
    // Il sacchetto dei funghetti (#302, comandi di Nicola): J ne pianta uno ai piedi, J + direzione lo lancia e si pianta
    // dove cade, K molla il sacchetto lì. Finiti i funghetti il sacchetto sparisce
    if (held && ITEMS[held.kind].mushrooms) {
      if (pressed(f, "light")) plantMushroom(world, held, f, ctx);
      else dropItem(held);
      consumeAttackKeys(f);
      continue;
    }
    if (held) {
      throwItem(held, f, ctx);
      consumeAttackKeys(f);
      continue;
    }
    const near = world.items.find(
      (i) => !i.heldBy && !i.thrown && !isPlanted(i) && Math.abs(i.x - f.x) < ITEM_RULES.pickRange && i.y > f.y - FIGHTER.height && i.y < f.y + 12,
    );
    if (near && ITEMS[near.kind].call) {
      world.items = world.items.filter((i) => i !== near); // Chiama Bassanese: il telefono sparisce, arriva lui
      callBassanese(f, ctx);
      consumeAttackKeys(f);
    } else if (near && ITEMS[near.kind].consume) {
      powerUp(world, near, f, ctx);
      consumeAttackKeys(f);
    } else if (near) {
      near.heldBy = f.id;
      near.onGround = false;
      ctx.events.push({ type: "itemPick", itemId: near.id, id: f.id });
      consumeAttackKeys(f);
    }
  }
}

// Un oggetto da consumare (#231): sparisce subito e dà il potenziamento; un altro fiore ricarica il tempo
function powerUp(world: ItemWorld, item: Item, f: Fighter, ctx: PhysicsContext) {
  const use = ITEMS[item.kind].consume!;
  world.items = world.items.filter((i) => i !== item);
  f.powerup = use.powerup;
  f.powerupMs = use.ms;
  f.invulnerable = true;
  if (isArcade(f)) startArcade(f);
  ctx.events.push({ type: "powerUp", itemId: item.id, id: f.id, kind: use.powerup, x: Math.round(f.x), y: Math.round(f.y) });
}

// Senza direzione (o con giù) il funghetto resta ai piedi; con destra, sinistra o su vola via e si pianta dove cade.
// Non è un oggetto lanciato: scatta solo come un funghetto, anche se tocca qualcuno in volo una volta armato
function plantMushroom(world: ItemWorld, bag: Item, f: Fighter, ctx: PhysicsContext) {
  const side = f.input.right === f.input.left ? 0 : f.input.right ? 1 : -1;
  const up = f.input.up && !f.input.down;
  const vx = side * FUNGHI.throwSpeed + (up ? f.vx * 0.3 : 0);
  const vy = up ? -FUNGHI.throwUpSpeed : side !== 0 ? -FUNGHI.throwLift : 0;
  const x = Math.round(f.x);
  const y = Math.round(vy < 0 ? f.y - ITEM_RULES.holdOffsetY : f.y);
  const item: Item = { id: world.nextId++, kind: "fungo", x, y, vx, vy, heldBy: null, thrown: false, onGround: false, riding: -1, thrownBy: null, lifeMs: FUNGHI.lifeMs, ownerId: f.id, armMs: FUNGHI.armMs };
  world.items.push(item);
  ctx.events.push({ type: "itemSpawn", itemId: item.id, kind: "fungo", x, y });
  bag.uses = (bag.uses ?? FUNGHI.uses) - 1;
  if (bag.uses <= 0) bag.lifeMs = 0; // sacchetto vuoto: sparisce al filtro
}

// Chi calpesta un funghetto armato (#302): piccolo danno, saltello e destra/sinistra invertite per un po'
function triggerMushroom(item: Item, fighters: Fighter[], ctx: PhysicsContext) {
  if ((item.armMs ?? 0) > 0) return;
  const owner = fighters.find((f) => f.id === item.ownerId);
  for (const target of fighters) {
    if (target.id === item.ownerId || target.eliminated || target.respawning || target.invulnerable) continue;
    if (owner && ctx.canHit && !ctx.canHit(owner, target)) continue;
    const body = bodyBox(target);
    const half = ITEMS.fungo.width / 2;
    if (!(item.x + half > body.x && item.x - half < body.x + body.w && item.y > body.y && item.y - ITEMS.fungo.height < body.y + body.h)) continue;
    item.lifeMs = 0;
    target.percent = Math.min(999, target.percent + FUNGHI.damage);
    target.vy = -FUNGHI.popVy;
    target.onGround = false;
    target.lastHitById = item.ownerId ?? null;
    if (target.powerup !== "fiore") {
      // Il viaggio prende il posto del bong: chi era fatto ora è confuso
      target.powerup = "trip";
      target.powerupMs = FUNGHI.tripMs;
    }
    ctx.events.push({ type: "powerUp", itemId: item.id, id: target.id, kind: "trip", x: Math.round(item.x), y: Math.round(item.y) });
    return;
  }
}

// Il viaggio dei funghetti (#302): per chi ce l'ha destra e sinistra si scambiano, prima e dopo il passo di stepWorld
// Restituisce chi ha scambiato: si rimettono a posto proprio loro, anche se il viaggio finisce nel passo
export function swapTripInput(fighters: Fighter[]): Fighter[] {
  const tripping = fighters.filter((f) => f.powerup === "trip");
  for (const f of tripping) {
    f.input = { ...f.input, left: f.input.right, right: f.input.left };
    f.prevInput = { ...f.prevInput, left: f.prevInput.right, right: f.prevInput.left };
  }
  return tripping;
}

// Il fungo di Teemo (#419) lanciato o posato tocca terra: se c'è già un fungo piazzato lì sotto rimbalza in avanti
// (come in LoL), altrimenti si piazza e comincia ad armarsi
function settleShroom(world: ItemWorld, item: Item) {
  const half = ITEMS[item.kind].width / 2;
  const onShroom = world.items.some((o) => o !== item && isPlanted(o) && ITEMS[o.kind].shroom && Math.abs(o.x - item.x) < half * 2 && Math.abs(o.y - item.y) < 8);
  if (onShroom) {
    item.vx = (item.plantDir ?? 1) * FUNGO.bounceVx;
    item.vy = -FUNGO.bounceVy;
    item.onGround = false;
    return;
  }
  item.ownerId = item.plantBy;
  item.plantBy = undefined;
  item.plantDir = undefined;
  item.armMs = FUNGO.armMs;
  item.lifeMs = FUNGO.lifeMs;
  item.vx = 0;
}

// Un avversario tocca il fungo di Teemo armato: scoppia in una nube che avvelena tutti gli avversari dentro blastRadius
function triggerShroom(item: Item, fighters: Fighter[], ctx: PhysicsContext) {
  if ((item.armMs ?? 0) > 0) return;
  const owner = fighters.find((f) => f.id === item.ownerId);
  const foes = fighters.filter(
    (t) => t.id !== item.ownerId && !t.eliminated && !t.respawning && !t.invulnerable && !(owner && ctx.canHit && !ctx.canHit(owner, t)),
  );
  const spec = ITEMS[item.kind];
  const half = spec.width / 2;
  const stepped = foes.some((t) => {
    const body = bodyBox(t);
    return item.x + half > body.x && item.x - half < body.x + body.w && item.y > body.y && item.y - spec.height < body.y + body.h;
  });
  if (!stepped) return;
  item.lifeMs = 0;
  const cx = item.x;
  const cy = item.y - spec.height / 2;
  for (const target of foes) {
    const body = bodyBox(target);
    const nx = Math.max(body.x, Math.min(cx, body.x + body.w));
    const ny = Math.max(body.y, Math.min(cy, body.y + body.h));
    if ((nx - cx) ** 2 + (ny - cy) ** 2 > FUNGO.blastRadius ** 2) continue;
    target.percent = Math.min(999, target.percent + FUNGO.damage);
    target.lastHitById = item.ownerId ?? null;
    // Il veleno prende il posto di bong e viaggio; il fiore e gli arcade rendono intoccabili, quindi qui non arrivano
    target.powerup = "veleno";
    target.powerupMs = FUNGO.poisonMs;
    ctx.events.push({ type: "powerUp", itemId: item.id, id: target.id, kind: "veleno", x: Math.round(item.x), y: Math.round(item.y) });
  }
}

// Il veleno del fungo di Teemo: la percentuale sale a scatti di poisonTickMs mentre il tempo scorre (l'ultimo a tempo finito)
function poisonTick(f: Fighter, beforeMs: number, afterMs: number) {
  const ticks = Math.ceil(beforeMs / FUNGO.poisonTickMs) - Math.ceil(afterMs / FUNGO.poisonTickMs);
  if (ticks <= 0) return;
  f.percent = Math.min(999, f.percent + (ticks * FUNGO.poisonPerSec * FUNGO.poisonTickMs) / 1000);
}

// Da avvelenati si va più piano finché dura il veleno (movement.ts), come col fungo di Teemo
export const poisonSlowed = (f: Fighter) => f.powerup === "veleno" && f.powerupMs > 0;

// Il tempo del potenziamento scorre come gli altri timer del lottatore (fermo nell'hitstop)
export function tickPowerup(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  if (!f.powerup) return;
  const beforeMs = f.powerupMs;
  f.powerupMs = Math.max(0, f.powerupMs - dtMs);
  if (f.powerup === "veleno") poisonTick(f, beforeMs, f.powerupMs);
  if (f.powerupMs > 0) return;
  ctx.events.push({ type: "powerEnd", id: f.id, kind: f.powerup });
  if (isArcade(f)) endArcade(f); // si torna in partita (#427)
  // Troppo fatti (#302): non si è soffiato in tempo, si crolla tramortiti come con lo scudo rotto
  if (f.powerup === "bong") {
    f.stunTimer = BONG.stunMs;
    f.stunned = true;
    f.attack = null;
    f.attackActive = false;
    ctx.events.push({ type: "bong", phase: "stun", id: f.id, x: Math.round(f.x), y: Math.round(f.y) });
  }
  f.powerup = null;
}

// Il bong (#302) si carica tenendo J. Carico, lasciando J si è fatti e il bong è finito; lasciando prima si perde la carica
function loadBong(world: ItemWorld, item: Item, f: Fighter, dtMs: number, ctx: PhysicsContext) {
  if (item.loadMs === undefined || item.loadMs < 0) return;
  if (f.input.light) {
    item.loadMs = Math.min(BONG.loadMs, item.loadMs + dtMs);
    return;
  }
  if (item.loadMs < BONG.loadMs) {
    item.loadMs = -1;
    return;
  }
  item.loadMs = Infinity; // fumato: sparisce al filtro di stepItems
  f.powerup = "bong";
  f.powerupMs = BONG.highMs;
  ctx.events.push({ type: "powerUp", itemId: item.id, id: f.id, kind: "bong", x: Math.round(f.x), y: Math.round(f.y) });
}

// Da fatti l'effetto cresce col tempo (#302): da 0 appena fumato a 1 quando si sta per crollare
export const highLevel = (f: Fighter) => (f.powerup === "bong" ? 1 - f.powerupMs / BONG.highMs : 0);

// La nuvola di fumo (#302): colpisce tutti quelli dentro il cerchio davanti, più forte quanto più si è aspettato
function blowCloud(f: Fighter, fighters: Fighter[], ctx: PhysicsContext) {
  const level = highLevel(f);
  const damage = Math.round(BONG.minDamage + (BONG.maxDamage - BONG.minDamage) * level);
  const base = BONG.minKnockback + (BONG.maxKnockback - BONG.minKnockback) * level;
  const cx = f.x + f.facing * BONG.cloudOffsetX;
  const cy = f.y - FIGHTER.height / 2;
  f.powerup = null;
  f.powerupMs = 0;
  f.cooldownTimer = Math.max(f.cooldownTimer, BONG.cooldownMs);
  ctx.events.push({ type: "bong", phase: "smoke", id: f.id, x: Math.round(cx), y: Math.round(cy), dir: f.facing, damage });
  ctx.events.push({ type: "powerEnd", id: f.id, kind: "bong" });
  for (const target of fighters) {
    if (target === f || target.eliminated || target.respawning || target.invulnerable) continue;
    if (ctx.canHit && !ctx.canHit(f, target)) continue;
    const body = bodyBox(target);
    const nx = Math.max(body.x, Math.min(cx, body.x + body.w));
    const ny = Math.max(body.y, Math.min(cy, body.y + body.h));
    if ((nx - cx) ** 2 + (ny - cy) ** 2 > BONG.cloudRadius ** 2) continue;
    const dir = target.x >= f.x ? 1 : -1;
    if (target.shielding) {
      hitShield(target, f.id, damage, dir, Math.round(nx), Math.round(ny), ctx);
      continue;
    }
    target.percent = Math.min(999, target.percent + damage);
    chargeFromHit(f, target, damage);
    const knockback = (base + BONG.knockbackGrowth * target.percent) / characterStats(target.characterId).weight;
    const angle = (BONG.angleDeg * Math.PI) / 180;
    target.vx = dir * Math.cos(angle) * knockback;
    target.vy = -Math.sin(angle) * knockback;
    target.onGround = false;
    target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
    target.attack = null;
    target.attackActive = false;
    target.facing = (-dir) as 1 | -1;
    target.lastHitById = f.id;
    clearStun(target);
    target.hitstopTimer = Math.max(target.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * damage));
    ctx.events.push({
      type: "hit",
      attackerId: f.id,
      targetId: target.id,
      kind: "item",
      itemKind: "bong",
      damage,
      percent: target.percent,
      knockback: Math.round(knockback),
      x: Math.round(nx),
      y: Math.round(ny),
    });
  }
}

// Avanti con un arco, tenendo su verso l'alto, tenendo giù lo si posa e basta
// Posato dove si sta, senza lanciarlo
function dropItem(item: Item) {
  item.heldBy = null;
  item.loadMs = -1;
  item.vx = 0;
  item.vy = 0;
}

function throwItem(item: Item, f: Fighter, ctx: PhysicsContext) {
  const shroom = ITEMS[item.kind].shroom;
  if (shroom) {
    item.plantBy = f.id; // il fungo di Teemo, lanciato o posato ai piedi, si piazza dove tocca terra
    item.plantDir = f.facing;
  }
  if (f.input.down && !f.input.up) return dropItem(item);
  item.heldBy = null;
  item.loadMs = -1;
  item.thrown = true;
  item.thrownBy = f.id;
  const speeds = shroom ? FUNGO : ITEM_RULES; // il fungo vola a pallonetto, più lento e più alto
  if (f.input.up) {
    item.vx = f.vx * 0.3;
    item.vy = -speeds.throwUpSpeed;
  } else {
    item.vx = f.facing * speeds.throwSpeed;
    item.vy = -speeds.throwLift;
  }
  ctx.events.push({ type: "itemThrow", itemId: item.id, id: f.id, x: Math.round(item.x), y: Math.round(item.y) });
}

export function stepItems(world: ItemWorld, fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  const dt = dtMs / 1000;
  const byId = new Map(fighters.map((f) => [f.id, f]));

  world.spawnTimer -= dtMs;
  if (world.spawnTimer <= 0) {
    world.spawnTimer = world.everyMs;
    if (world.items.filter((i) => !isPlanted(i)).length < world.maxOnStage) spawn(world, ctx);
  }

  for (const item of world.items) {
    const spec = ITEMS[item.kind];
    if (item.heldBy) {
      const holder = byId.get(item.heldBy);
      if (holder && !holder.eliminated && !holder.respawning && !holder.hitstun) {
        item.x = holder.x + holder.facing * ITEM_RULES.holdOffsetX;
        item.y = holder.y - ITEM_RULES.holdOffsetY;
        item.vx = holder.vx;
        item.vy = holder.vy;
        if (spec.bong) loadBong(world, item, holder, dtMs, ctx);
        continue;
      }
      // Chi lo teneva è stato colpito o è uscito: l'oggetto cade dov'è
      item.heldBy = null;
      item.vx = 0;
      item.vy = 0;
      item.loadMs = -1; // la carica del bong va persa
    }

    carry(item, dtMs, ctx);
    item.vy = Math.min(FIGHTER.maxFallSpeed, item.vy + FIGHTER.gravity * dt * (spec.shroom ? FUNGO.gravityMult : 1)); // il fungo è pesante
    if (item.onGround) item.vx = Math.sign(item.vx) * Math.max(0, Math.abs(item.vx) - ITEM_RULES.groundFriction * dt);
    const prevY = item.y;
    item.x += item.vx * dt;
    item.y += item.vy * dt;
    land(item, prevY, spec.width / 2, dtMs, ctx);

    if (item.thrown) hitWithItem(item, fighters, ctx);
    if (spec.shroom && item.onGround && item.plantBy) settleShroom(world, item);
    if (spec.planted) {
      item.armMs = Math.max(0, (item.armMs ?? 0) - dtMs);
      triggerMushroom(item, fighters, ctx);
      if (!item.onGround) item.lifeMs -= dtMs; // anche se cade nel vuoto prima o poi sparisce
    } else if (spec.shroom && item.ownerId !== undefined) {
      item.armMs = Math.max(0, (item.armMs ?? 0) - dtMs);
      triggerShroom(item, fighters, ctx);
      if (!item.onGround) item.lifeMs -= dtMs;
    }
    if (item.onGround) item.lifeMs -= dtMs;
  }

  const z = ctx.stage.blastZone;
  world.items = world.items.filter((i) => i.lifeMs > 0 && !(ITEMS[i.kind].bong && i.loadMs === Infinity) && i.x > z.left && i.x < z.right && i.y < z.bottom);
}

function spawn(world: ItemWorld, ctx: PhysicsContext) {
  const surfaces = [...ctx.stage.solids, ...ctx.stage.platforms].filter((s) => s.width >= 80);
  if (surfaces.length === 0) return;
  const s = pickSurface(surfaces, ctx.stage.itemSpots ?? [], world.random());
  const kind = pickKind(world.random(), world.kinds);
  const x = Math.round(s.x + 30 + world.random() * (s.width - 60));
  const y = s.y - ITEM_RULES.dropHeight;
  const item: Item = { id: world.nextId++, kind, x, y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: false, riding: -1, thrownBy: null, lifeMs: ITEM_RULES.lifeMs, loadMs: -1 };
  world.items.push(item);
  ctx.events.push({ type: "itemSpawn", itemId: item.id, kind, x, y });
}

// Quale oggetto cade: a caso pesando la classe di frequenza di ognuno (#231, ITEM_RARITY), con un solo numero casuale
export function pickKind(r: number, kinds: readonly string[] = DROPPABLE_ITEMS): string {
  const weight = itemWeight;
  let left = r * kinds.reduce((sum, k) => sum + weight(k), 0);
  for (const k of kinds) {
    if (left < weight(k)) return k;
    left -= weight(k);
  }
  return kinds[kinds.length - 1];
}

// Dove cade il prossimo oggetto: un pezzo a caso, o con le zone dell'arena (#253) a caso pesando pezzi (1) e zone (il loro peso).
// Usa un solo numero casuale come prima, così le arene senza zone restano identiche con lo stesso seme.
function pickSurface(surfaces: { x: number; y: number; width: number }[], spots: ItemSpot[], r: number) {
  if (spots.length === 0) return surfaces[Math.floor(r * surfaces.length)];
  const all = [...surfaces.map((s) => ({ s, w: 1 })), ...spots.map((s) => ({ s, w: s.weight }))];
  let left = r * all.reduce((sum, c) => sum + c.w, 0);
  for (const c of all) {
    if (left < c.w) return c.s;
    left -= c.w;
  }
  return all[all.length - 1].s;
}

// Un oggetto appoggiato su una piattaforma mobile viaggia con lei (come carryRider in elements.ts)
function carry(item: Item, dtMs: number, ctx: PhysicsContext) {
  const m = item.riding >= 0 ? ctx.stage.movers?.[item.riding] : undefined;
  if (!m || !item.onGround) return;
  const t = ctx.timeMs ?? 0;
  if (!moverHere(m, t, ctx)) {
    item.onGround = false; // la nota è finita (#423): l'oggetto cade
    item.riding = -1;
    return;
  }
  const before = moverPlace(m, t - dtMs, ctx);
  const now = moverPlace(m, t, ctx);
  item.x += now.x - before.x;
  item.y += now.y - before.y;
}

// Come i lottatori: sopra i blocchi pieni, le piattaforme sottili e quelle mobili, solo scendendo
function land(item: Item, prevY: number, half: number, dtMs: number, ctx: PhysicsContext) {
  item.onGround = false;
  item.riding = -1;
  if (item.vy < 0) return;
  for (const s of [...ctx.stage.solids, ...ctx.stage.platforms]) {
    const over = item.x + half > s.x && item.x - half < s.x + s.width;
    const sy = "height" in s ? s.y : platformSurfaceY(s, item.x); // sulle piattaforme ad arco, la curva (#244)
    if (over && prevY <= sy && item.y >= sy) return settle(item, sy);
  }
  // Su un ascensore conta anche dov'era la superficie prima del passo (può venire incontro)
  const movers = ctx.stage.movers ?? [];
  const t = ctx.timeMs ?? 0;
  for (let i = 0; i < movers.length; i++) {
    if (!moverHere(movers[i], t, ctx)) continue;
    const now = moverPlace(movers[i], t, ctx);
    const before = moverPlace(movers[i], t - dtMs, ctx);
    const over = item.x + half > now.x && item.x - half < now.x + movers[i].width;
    if (over && prevY <= Math.max(before.y, now.y) && item.y >= now.y) {
      settle(item, now.y);
      item.riding = i;
      return;
    }
  }
}

function settle(item: Item, y: number) {
  item.y = y;
  item.vy = 0;
  item.onGround = true;
  // Un oggetto lanciato che tocca terra torna da raccogliere
  item.thrown = false;
  item.thrownBy = null;
}

// Il primo che l'oggetto lanciato tocca vola via come per un attacco, e l'oggetto si consuma
function hitWithItem(item: Item, fighters: Fighter[], ctx: PhysicsContext) {
  const spec = ITEMS[item.kind];
  const box = { x: item.x - spec.width / 2, y: item.y - spec.height, w: spec.width, h: spec.height };
  const thrower = fighters.find((f) => f.id === item.thrownBy);
  for (const target of fighters) {
    if (target.id === item.thrownBy || target.eliminated || target.respawning || target.invulnerable) continue;
    if (thrower && ctx.canHit && !ctx.canHit(thrower, target)) continue;
    const body = bodyBox(target);
    if (!(box.x < body.x + body.w && box.x + box.w > body.x && box.y < body.y + body.h && box.y + box.h > body.y)) continue;

    const dir = item.vx !== 0 ? (Math.sign(item.vx) as 1 | -1) : target.x >= item.x ? 1 : -1;
    // Sparisce al prossimo filtro; il fungo di Teemo invece cade dritto e si piazza lo stesso
    if (spec.shroom) item.vx = 0;
    else item.lifeMs = 0;
    // Lo scudo para anche gli oggetti lanciati (#109): l'oggetto si consuma lo stesso
    if (target.shielding) {
      hitShield(target, item.thrownBy ?? "", spec.damage, dir, Math.round(item.x), Math.round(item.y - spec.height / 2), ctx);
      item.thrownBy = null;
      item.thrown = false;
      return;
    }
    target.percent = Math.min(999, target.percent + spec.damage);
    chargeFromHit(thrower, target, spec.damage); // #101
    const knockback = (spec.knockback + ITEM_RULES.knockbackGrowth * target.percent) / characterStats(target.characterId).weight; // E11
    const angle = (ITEM_RULES.angleDeg * Math.PI) / 180;
    target.vx = dir * Math.cos(angle) * knockback;
    target.vy = -Math.sin(angle) * knockback;
    target.onGround = false;
    target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
    target.attack = null;
    target.attackActive = false;
    target.facing = (-dir) as 1 | -1;
    target.lastHitById = item.thrownBy;
    clearStun(target);
    target.hitstopTimer = Math.max(target.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * spec.damage));
    ctx.events.push({
      type: "hit",
      attackerId: item.thrownBy ?? "",
      targetId: target.id,
      kind: "item",
      itemKind: item.kind,
      damage: spec.damage,
      percent: target.percent,
      knockback: Math.round(knockback),
      x: Math.round(item.x),
      y: Math.round(item.y - spec.height / 2),
    });
    item.thrownBy = null;
    item.thrown = false;
    return;
  }
}

// Quello che va nello snapshot
export const itemStates = (world: ItemWorld): ItemState[] =>
  world.items.map((i) => ({
    id: i.id,
    kind: i.kind,
    x: Math.round(i.x),
    y: Math.round(i.y),
    vx: Math.round(i.vx),
    vy: Math.round(i.vy),
    heldBy: i.heldBy,
    thrown: i.thrown,
    ...(i.ownerId ? { owner: i.ownerId } : {}),
    ...(ITEMS[i.kind].bong && (i.loadMs ?? -1) >= 0 ? { load: Math.round((Math.min(i.loadMs!, BONG.loadMs) / BONG.loadMs) * 100) / 100 } : {}),
  }));
