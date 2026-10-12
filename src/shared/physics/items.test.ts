// Test degli oggetti (#17): comparsa, raccolta, lancio e colpo, senza server né client.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, ITEM_RULES, POWERUP, TICK_RATE } from "../constants";
import { ITEMS } from "../items";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { canBeHit, launch } from "./attacks";
import { createItemWorld, handleItemInput, pickKind, stepItems, type Item, type ItemWorld } from "./items";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

function setup() {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [0, 1].map((i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  const world = createItemWorld(42);
  return { ctx, fighters, world };
}

function run(world: ItemWorld, fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) {
    handleItemInput(world, fighters, ctx);
    stepWorld(fighters, DT, ctx);
    stepItems(world, fighters, DT, ctx);
  }
}

function press(f: Fighter, keys: Partial<InputState>) {
  f.input = { ...emptyInput(), ...keys };
}

const ofType = <T extends GameEvent["type"]>(events: GameEvent[], type: T) =>
  events.filter((e): e is Extract<GameEvent, { type: T }> => e.type === type);

function banana(x: number, y: number): Item {
  return { id: 99, kind: "banana", x, y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: true, riding: -1, thrownBy: null, lifeMs: ITEM_RULES.lifeMs };
}

describe("oggetti", () => {
  it("dopo l'attesa iniziale ne cade uno che si posa su una superficie", () => {
    const { ctx, fighters, world } = setup();
    run(world, fighters, ctx, Math.ceil(ITEM_RULES.firstSpawnMs / DT) + 90);
    assert.equal(ofType(ctx.events, "itemSpawn").length, 1);
    assert.equal(world.items.length, 1);
    const item = world.items[0];
    assert.equal(item.onGround, true);
    const surfaces = [...stage.solids, ...stage.platforms].map((s) => s.y);
    assert.ok(surfaces.includes(item.y), "è appoggiato su un blocco o una piattaforma");
  });

  it("stesso seme, stessa sequenza", () => {
    const a = setup();
    const b = setup();
    run(a.world, a.fighters, a.ctx, Math.ceil(ITEM_RULES.firstSpawnMs / DT) + 1);
    run(b.world, b.fighters, b.ctx, Math.ceil(ITEM_RULES.firstSpawnMs / DT) + 1);
    assert.deepEqual(ofType(a.ctx.events, "itemSpawn"), ofType(b.ctx.events, "itemSpawn"));
  });

  it("J vicino all'oggetto lo raccoglie senza attaccare, J di nuovo lo lancia e colpisce chi è davanti", () => {
    const { ctx, fighters, world } = setup();
    const [a, b] = fighters;
    a.x = 500;
    a.facing = 1;
    b.x = 800;
    world.items.push(banana(a.x + 10, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(world.items[0].heldBy, a.id);
    assert.equal(ofType(ctx.events, "itemPick").length, 1);
    assert.equal(ofType(ctx.events, "attack").length, 0, "il tasto non fa partire un attacco");
    press(a, {});
    run(world, fighters, ctx, 2);
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "itemThrow").length, 1);
    press(a, {});
    run(world, fighters, ctx, 40);
    const hits = ofType(ctx.events, "hit");
    assert.equal(hits.length, 1);
    assert.equal(hits[0].kind, "item");
    assert.equal(hits[0].targetId, b.id);
    assert.equal(b.percent, ITEMS.banana.damage);
    assert.equal(world.items.length, 0, "l'oggetto si consuma");
    assert.equal(a.percent, 0, "chi lancia non si colpisce da solo");
  });

  it("giù + J posa l'oggetto senza lanciarlo", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(banana(a.x, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    press(a, {});
    run(world, fighters, ctx, 2);
    press(a, { light: true, down: true });
    run(world, fighters, ctx, 1);
    press(a, {});
    run(world, fighters, ctx, 30);
    assert.equal(ofType(ctx.events, "itemThrow").length, 0);
    assert.equal(world.items[0].heldBy, null);
    assert.equal(world.items[0].onGround, true);
    assert.ok(Math.abs(world.items[0].x - a.x) < FIGHTER.width, "è caduto ai piedi");
  });

  it("si appoggia su un ascensore e sale con lui (#14)", () => {
    const { fighters, world } = setup();
    // Ascensore a sinistra del palco: fermo in basso per 1 s, poi sale di 200 pixel in 1 s
    const elevator = { width: 100, path: [{ x: 40, y: 500 }, { x: 40, y: 300 }], periodMs: 4000, pauseMs: 1000 };
    const ctx: PhysicsContext = { stage: { ...stage, movers: [elevator] }, events: [] };
    world.items.push({ ...banana(90, 420), onGround: false });
    run(world, fighters, ctx, 30);
    assert.equal(world.items[0].y, 500, "atterrato sull'ascensore");
    assert.equal(world.items[0].riding, 0);
    run(world, fighters, ctx, 120);
    assert.ok(Math.abs(world.items[0].y - 300) < 2, `in cima con l'ascensore (y = ${world.items[0].y})`);
  });

  it("chi viene colpito molla l'oggetto", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(banana(a.x, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    a.hitstunTimer = 300;
    a.hitstun = true;
    press(a, {});
    run(world, fighters, ctx, 1);
    assert.equal(world.items[0].heldBy, null);
  });
});

describe("zone degli oggetti (#253)", () => {
  it("con una zona pesante gli oggetti cadono quasi sempre lì", () => {
    const spotted = { ...stage, itemSpots: [{ x: 300, y: 560, width: 200, weight: 20 }] };
    let inSpot = 0;
    const total = 40;
    for (let seed = 1; seed <= total; seed++) {
      const ctx: PhysicsContext = { stage: spotted, events: [] };
      const world = createItemWorld(seed);
      run(world, [], ctx, Math.round(ITEM_RULES.firstSpawnMs / DT) + 1);
      const spawn = ofType(ctx.events, "itemSpawn")[0];
      assert.ok(spawn, `seme ${seed}: è caduto un oggetto`);
      if (spawn.x >= 300 && spawn.x <= 500) inSpot++;
    }
    assert.ok(inSpot >= total * 0.7, `nella zona ${inSpot} volte su ${total}`);
  });
});

describe("il fiore, oggetto da consumare (#231)", () => {
  const fiore = (x: number, y: number): Item => ({ ...banana(x, y), kind: "fiore" });

  it("compare una volta su quattro rispetto alla banana", () => {
    const kinds = Array.from({ length: 400 }, (_, i) => pickKind(i / 400));
    assert.equal(kinds.filter((k) => k === "fiore").length, 100);
    assert.equal(kinds.filter((k) => k === "banana").length, 300);
  });

  it("raccolto sparisce e potenzia subito, senza attaccare", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(fiore(a.x + 10, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(world.items.length, 0);
    assert.equal(a.powerup, "fiore");
    assert.ok(a.powerupMs > POWERUP.flowerMs - 2 * DT);
    assert.equal(a.invulnerable, true);
    assert.equal(canBeHit(a), false, "intoccabile");
    assert.equal(ofType(ctx.events, "powerUp").length, 1);
    assert.equal(ofType(ctx.events, "itemPick").length, 0);
    assert.equal(ofType(ctx.events, "attack").length, 0);
  });

  it("i colpi fanno ×1,3 di danno", () => {
    const { ctx, fighters } = setup();
    const [a, b] = fighters;
    launch(b, a, "light", 0, 0, ctx);
    const normal = b.percent;
    b.percent = 0;
    a.powerup = "fiore";
    a.powerupMs = POWERUP.flowerMs;
    launch(b, a, "light", 0, 0, ctx);
    assert.equal(b.percent, Math.round(normal * POWERUP.damageMult * 10) / 10);
  });

  it("ci si muove a ×0,75, il salto resta uguale", () => {
    const speeds = [false, true].map((powered) => {
      const { ctx, fighters, world } = setup();
      const [a] = fighters;
      if (powered) {
        a.powerup = "fiore";
        a.powerupMs = POWERUP.flowerMs;
      }
      press(a, { right: true });
      run(world, fighters, ctx, 3);
      const vx = a.vx;
      press(a, { jump: true });
      run(world, fighters, ctx, 1);
      return { vx, vy: a.vy };
    });
    assert.ok(speeds[0].vx > 0 && speeds[0].vy < 0, "si cammina e si salta");
    assert.ok(Math.abs(speeds[1].vx - speeds[0].vx * POWERUP.speedMult) < 1e-6);
    assert.equal(speeds[1].vy, speeds[0].vy);
  });

  it("finisce dopo il tempo, con l'evento, e si torna colpibili", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(fiore(a.x, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    press(a, {});
    run(world, fighters, ctx, Math.ceil(POWERUP.flowerMs / DT) + 1);
    assert.equal(a.powerup, null);
    assert.equal(a.powerupMs, 0);
    assert.equal(a.invulnerable, false);
    assert.equal(ofType(ctx.events, "powerEnd").length, 1);
  });

  it("uscire dall'arena toglie la vita e il fiore", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    a.powerup = "fiore";
    a.powerupMs = POWERUP.flowerMs;
    a.y = stage.blastZone.bottom + 50;
    run(world, fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "ko").length, 1);
    assert.equal(a.powerup, null);
  });
});
