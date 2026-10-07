// Oggetti (#17 passo 3): cadono dal cielo, si raccolgono e si lanciano. Logica pura come il resto
// di physics/: il caso viene da un generatore con seme, così la partita resta ripetibile.
//   handleItemInput() prima di stepWorld: J o K vicino a un oggetto lo raccoglie, con l'oggetto in mano lo lancia
//   stepItems() dopo stepWorld: comparsa, caduta, oggetti in mano e colpi di quelli lanciati

import { FIGHTER, HITSTOP, HITSTUN_PER_KNOCKBACK, ITEM_RULES } from "../constants";
import { ITEMS } from "../items";
import { rng } from "../stageGenerator";
import type { ItemState } from "../types";
import { bodyBox } from "./attacks";
import { moverPosition } from "./elements";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";

export interface Item extends ItemState {
  onGround: boolean;
  riding: number; // indice della piattaforma mobile su cui è appoggiato, -1 se nessuna (#14)
  thrownBy: string | null;
  lifeMs: number; // ms che restano a terra prima di sparire
}

export interface ItemWorld {
  items: Item[];
  nextId: number;
  spawnTimer: number;
  random: () => number;
}

export function createItemWorld(seed: number): ItemWorld {
  return { items: [], nextId: 1, spawnTimer: ITEM_RULES.firstSpawnMs, random: rng(seed).next };
}

// Si ricomincia: via gli oggetti, il primo ricade dopo l'attesa iniziale
export function resetItems(world: ItemWorld): void {
  world.items = [];
  world.spawnTimer = ITEM_RULES.firstSpawnMs;
}

// Non si raccoglie né si lancia mentre si è occupati: colpiti, in attacco, in schivata o inermi dopo il recupero
const busy = (f: Fighter) =>
  f.eliminated || f.respawning || f.hitstun || f.hitstopTimer > 0 || f.attack !== null || f.helpless || f.dodgeTimer > 0;

// Il tasto usato per l'oggetto non deve far partire anche un attacco: lo si segna come già premuto
function consumeAttackKeys(f: Fighter) {
  f.prevInput = { ...f.prevInput, light: f.input.light, heavy: f.input.heavy };
  consume(f, "light", "heavy");
}

export function handleItemInput(world: ItemWorld, fighters: Fighter[], ctx: PhysicsContext): void {
  for (const f of fighters) {
    if (busy(f) || f.cooldownTimer > 0 || !(pressed(f, "light") || pressed(f, "heavy"))) continue;
    const held = world.items.find((i) => i.heldBy === f.id);
    if (held) {
      throwItem(held, f, ctx);
      consumeAttackKeys(f);
      continue;
    }
    const near = world.items.find(
      (i) => !i.heldBy && !i.thrown && Math.abs(i.x - f.x) < ITEM_RULES.pickRange && i.y > f.y - FIGHTER.height && i.y < f.y + 12,
    );
    if (near) {
      near.heldBy = f.id;
      near.onGround = false;
      ctx.events.push({ type: "itemPick", itemId: near.id, id: f.id });
      consumeAttackKeys(f);
    }
  }
}

// Avanti con un arco, tenendo su verso l'alto, tenendo giù lo si posa e basta
function throwItem(item: Item, f: Fighter, ctx: PhysicsContext) {
  item.heldBy = null;
  if (f.input.down && !f.input.up) {
    item.vx = 0;
    item.vy = 0;
    return;
  }
  item.thrown = true;
  item.thrownBy = f.id;
  if (f.input.up) {
    item.vx = f.vx * 0.3;
    item.vy = -ITEM_RULES.throwUpSpeed;
  } else {
    item.vx = f.facing * ITEM_RULES.throwSpeed;
    item.vy = -ITEM_RULES.throwLift;
  }
  ctx.events.push({ type: "itemThrow", itemId: item.id, id: f.id, x: Math.round(item.x), y: Math.round(item.y) });
}

export function stepItems(world: ItemWorld, fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  const dt = dtMs / 1000;
  const byId = new Map(fighters.map((f) => [f.id, f]));

  world.spawnTimer -= dtMs;
  if (world.spawnTimer <= 0) {
    world.spawnTimer = ITEM_RULES.spawnEveryMs;
    if (world.items.length < ITEM_RULES.maxOnStage) spawn(world, ctx);
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
        continue;
      }
      // Chi lo teneva è stato colpito o è uscito: l'oggetto cade dov'è
      item.heldBy = null;
      item.vx = 0;
      item.vy = 0;
    }

    carry(item, dtMs, ctx);
    item.vy = Math.min(FIGHTER.maxFallSpeed, item.vy + FIGHTER.gravity * dt);
    if (item.onGround) item.vx = Math.sign(item.vx) * Math.max(0, Math.abs(item.vx) - ITEM_RULES.groundFriction * dt);
    const prevY = item.y;
    item.x += item.vx * dt;
    item.y += item.vy * dt;
    land(item, prevY, spec.width / 2, dtMs, ctx);

    if (item.thrown) hitWithItem(item, fighters, ctx);
    if (item.onGround) item.lifeMs -= dtMs;
  }

  const z = ctx.stage.blastZone;
  world.items = world.items.filter((i) => i.lifeMs > 0 && i.x > z.left && i.x < z.right && i.y < z.bottom);
}

function spawn(world: ItemWorld, ctx: PhysicsContext) {
  const surfaces = [...ctx.stage.solids, ...ctx.stage.platforms].filter((s) => s.width >= 80);
  if (surfaces.length === 0) return;
  const kinds = Object.keys(ITEMS).sort();
  const s = surfaces[Math.floor(world.random() * surfaces.length)];
  const kind = kinds[Math.floor(world.random() * kinds.length)];
  const x = Math.round(s.x + 30 + world.random() * (s.width - 60));
  const y = s.y - ITEM_RULES.dropHeight;
  const item: Item = { id: world.nextId++, kind, x, y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: false, riding: -1, thrownBy: null, lifeMs: ITEM_RULES.lifeMs };
  world.items.push(item);
  ctx.events.push({ type: "itemSpawn", itemId: item.id, kind, x, y });
}

// Un oggetto appoggiato su una piattaforma mobile viaggia con lei (come carryRider in elements.ts)
function carry(item: Item, dtMs: number, ctx: PhysicsContext) {
  const m = item.riding >= 0 ? ctx.stage.movers?.[item.riding] : undefined;
  if (!m || !item.onGround) return;
  const t = ctx.timeMs ?? 0;
  const before = moverPosition(m, t - dtMs);
  const now = moverPosition(m, t);
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
    if (over && prevY <= s.y && item.y >= s.y) return settle(item, s.y);
  }
  // Su un ascensore conta anche dov'era la superficie prima del passo (può venire incontro)
  const movers = ctx.stage.movers ?? [];
  const t = ctx.timeMs ?? 0;
  for (let i = 0; i < movers.length; i++) {
    const now = moverPosition(movers[i], t);
    const before = moverPosition(movers[i], t - dtMs);
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
    target.percent = Math.min(999, target.percent + spec.damage);
    const knockback = spec.knockback + ITEM_RULES.knockbackGrowth * target.percent;
    const angle = (ITEM_RULES.angleDeg * Math.PI) / 180;
    target.vx = dir * Math.cos(angle) * knockback;
    target.vy = -Math.sin(angle) * knockback;
    target.onGround = false;
    target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
    target.attack = null;
    target.attackActive = false;
    target.facing = (-dir) as 1 | -1;
    target.lastHitById = item.thrownBy;
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
    item.lifeMs = 0; // sparisce al prossimo filtro
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
  }));
