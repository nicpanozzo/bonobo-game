// Test degli oggetti (#17): comparsa, raccolta, lancio e colpo, senza server né client.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, ITEM_RULES, TICK_RATE } from "../constants";
import { ITEMS } from "../items";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { createItemWorld, handleItemInput, stepItems, type Item, type ItemWorld } from "./items";

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
  return { id: 99, kind: "banana", x, y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: true, thrownBy: null, lifeMs: ITEM_RULES.lifeMs };
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
