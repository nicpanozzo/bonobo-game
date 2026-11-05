// Test degli oggetti pesanti e da cavalcare (ride.ts): casse, lavatrici, monopattini e carrelli, provati sui cinque principali.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, ITEM_RULES, RIDE, TICK_RATE } from "../constants";
import { ITEMS } from "../items";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { createItemWorld, handleItemInput, stepItems, type Item, type ItemWorld } from "./items";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);
const CORE = ["bradipo", "marcomunista", "orsoblu", "egiainuso", "elvedeo"];

function setup(characterId = "default", other = "default") {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [characterId, other].map((c, i) => createFighter({ id: `p${i}`, name: `P${i}`, characterId: c, color: 0, team: 0, index: i, stocks: 3 }, stage));
  const world = createItemWorld(42, { everyMs: 1e9 });
  world.spawnTimer = 1e9;
  const [a, b] = fighters;
  a.x = 500;
  a.facing = 1;
  b.x = 800;
  run(world, fighters, ctx, 30); // tutti a terra
  return { ctx, fighters, world, a, b };
}

function run(world: ItemWorld, fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) {
    handleItemInput(world, fighters, ctx);
    stepWorld(fighters, DT, ctx);
    stepItems(world, fighters, DT, ctx);
  }
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const gear = (events: GameEvent[], phase: string) => events.filter((e) => e.type === "gear" && e.phase === phase);

function item(kind: string, x: number, y: number): Item {
  return { id: 99, kind, x, y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: true, riding: -1, thrownBy: null, lifeMs: ITEM_RULES.lifeMs, loadMs: -1 };
}

function pickUp(s: ReturnType<typeof setup>, kind: string) {
  s.world.items.push(item(kind, s.a.x + 10, s.a.y));
  press(s.a, { light: true });
  run(s.world, s.fighters, s.ctx, 1);
  press(s.a, {});
  run(s.world, s.fighters, s.ctx, 2);
  return s.world.items.find((i) => i.kind === kind)!;
}

function tap(s: ReturnType<typeof setup>, keys: Partial<InputState>) {
  press(s.a, keys);
  run(s.world, s.fighters, s.ctx, 1);
  press(s.a, {});
}

// Quanta strada fa a camminare per un po' tenendo destra
function walk(s: ReturnType<typeof setup>, ticks: number) {
  const x0 = s.a.x;
  press(s.a, { right: true });
  run(s.world, s.fighters, s.ctx, ticks);
  press(s.a, {});
  return s.a.x - x0;
}

describe("oggetti pesanti e da cavalcare", () => {
  it("le versioni rare sono di classe rara e ogni oggetto ha la sua categoria", () => {
    for (const k of ["cassa", "lavatrice"]) assert.equal(ITEMS[k].category, "peso");
    for (const k of ["monopattino", "carrello"]) assert.equal(ITEMS[k].category, "cavalcatura");
    for (const k of ["cassaOro", "lavatriceMatta", "monopattinoRazzo", "carrelloTurbo"]) assert.equal(ITEMS[k].rarity, "raro");
  });

  it("con la cassa sopra la testa si va più piano e si salta meno, sui cinque principali", () => {
    for (const c of CORE) {
      const free = walk(setup(c), 20);
      const s = setup(c);
      const box = pickUp(s, "cassa");
      assert.equal(box.heldBy, "p0");
      assert.ok(box.y < s.a.y - FIGHTER.height * 0.8, `${c}: la cassa sta sopra la testa`);
      const loaded = walk(s, 20);
      assert.ok(loaded < free * 0.8, `${c}: ${loaded} < ${free}`);
    }
  });

  it("la cassa scagliata si rompe e lascia un oggetto; quella d'oro tre, mai casse", () => {
    for (const [kind, n] of [["cassa", 1], ["cassaOro", 3]] as const) {
      const s = setup();
      s.world.kinds = ["banana", "cassa", "cassaOro"];
      pickUp(s, kind);
      tap(s, { heavy: true });
      run(s.world, s.fighters, s.ctx, 90);
      assert.equal(gear(s.ctx.events, "break").length, 1, `${kind} si rompe`);
      assert.ok(!s.world.items.some((i) => i.kind === kind), `${kind} sparisce`);
      const out = s.world.items.filter((i) => i.kind === "banana");
      assert.equal(out.length, n, `${kind}: ${n} oggetti`);
    }
  });

  it("la cassa colpisce chi trova e poi si rompe", () => {
    const s = setup();
    s.b.x = s.a.x + 120;
    pickUp(s, "cassa");
    tap(s, {});
    press(s.a, { heavy: true });
    run(s.world, s.fighters, s.ctx, 1);
    press(s.a, {});
    run(s.world, s.fighters, s.ctx, 40);
    assert.ok(s.b.percent >= ITEMS.cassa.damage, `percentuale ${s.b.percent}`);
    assert.equal(gear(s.ctx.events, "break").length, 1);
  });

  it("la lavatrice scagliata va in centrifuga e picchia a ripetizione chi la tocca, ma non chi l'ha scagliata", () => {
    const s = setup();
    pickUp(s, "lavatrice");
    tap(s, { heavy: true });
    run(s.world, s.fighters, s.ctx, 60);
    const w = s.world.items.find((i) => i.kind === "lavatrice")!;
    assert.equal(gear(s.ctx.events, "spin").length, 1);
    // non si raccoglie mentre gira
    s.a.x = w.x;
    s.b.x = 2000;
    tap(s, { light: true });
    assert.equal(w.heldBy, null);
    s.a.percent = 0;
    s.b.x = w.x;
    s.b.y = w.y;
    s.b.vx = 0;
    run(s.world, s.fighters, s.ctx, 40);
    assert.ok(s.ctx.events.some((e) => e.type === "hit" && e.targetId === "p1" && e.itemKind === "lavatrice"), "la centrifuga colpisce");
    assert.equal(s.a.percent, 0, "chi l'ha scagliata non si fa male");
  });

  it("la lavatrice impazzita salta verso l'avversario", () => {
    const s = setup();
    s.b.x = s.a.x + 500;
    pickUp(s, "lavatriceMatta");
    tap(s, { heavy: true });
    run(s.world, s.fighters, s.ctx, 50);
    const w = s.world.items.find((i) => i.kind === "lavatriceMatta")!;
    const x0 = w.x;
    run(s.world, s.fighters, s.ctx, 120);
    assert.ok(gear(s.ctx.events, "hop").length >= 1, "salta");
    assert.ok(Math.abs(s.b.x - w.x) < Math.abs(s.b.x - x0) || s.b.percent > 0, "si avvicina o colpisce");
  });

  it("in monopattino si va più svelti, sui cinque principali; K fa scendere e il monopattino va avanti da solo", () => {
    for (const c of CORE) {
      const free = walk(setup(c), 20);
      const s = setup(c);
      const sc = pickUp(s, "monopattino");
      assert.equal(sc.heldBy, "p0");
      const fast = walk(s, 20);
      assert.ok(fast > free * 1.3, `${c}: ${fast} > ${free}`);
      tap(s, { heavy: true });
      assert.equal(sc.heldBy, null);
      assert.ok(sc.thrown && sc.vx > 0, `${c}: va avanti da solo`);
      assert.equal(s.a.carrying, undefined);
    }
  });

  it("in monopattino si investe chi si incontra", () => {
    const s = setup();
    s.b.x = s.a.x + 200;
    pickUp(s, "monopattino");
    tap(s, { light: true }); // scatto
    run(s.world, s.fighters, s.ctx, 25);
    assert.ok(gear(s.ctx.events, "charge").length === 1);
    assert.ok(gear(s.ctx.events, "ram").length >= 1, "investito");
    assert.ok(s.b.percent >= ITEMS.monopattino.damage);
  });

  it("il monopattino a razzo va da solo e finito il razzo scoppia", () => {
    const s = setup();
    s.b.x = 3000;
    const sc = pickUp(s, "monopattinoRazzo");
    const x0 = s.a.x;
    run(s.world, s.fighters, s.ctx, 10);
    assert.ok(s.a.x > x0 + 50, "va avanti senza tasti");
    // avanti e indietro sull'arena finché dura il razzo, senza cadere giù
    for (let t = 0; t < RIDE.rocket.fuelMs / DT; t += 20) {
      s.a.x = 500;
      run(s.world, s.fighters, s.ctx, 20);
    }
    assert.ok(gear(s.ctx.events, "boom").length === 1, "scoppia");
    assert.ok(!s.world.items.includes(sc));
    assert.equal(s.a.carrying, undefined);
  });

  it("il carrello raccoglie chi investe e J lo catapulta; quello da tre ne tiene tre", () => {
    const s = setup();
    s.b.x = s.a.x + 160;
    pickUp(s, "carrello");
    tap(s, { light: true });
    run(s.world, s.fighters, s.ctx, 20);
    assert.equal(gear(s.ctx.events, "scoop").length, 1, "dentro");
    assert.ok(s.b.stunned);
    assert.ok(Math.abs(s.b.x - s.a.x) < 30, "viaggia col carrello");
    run(s.world, s.fighters, s.ctx, 70); // lo scatto si ricarica
    tap(s, { light: true });
    assert.equal(gear(s.ctx.events, "launch").length, 1);
    assert.ok(!s.b.stunned && s.b.vy < 0 && s.b.percent >= RIDE.cart.catapultDamage);
  });

  it("dal carrello si esce da soli dopo un po'", () => {
    const s = setup();
    s.b.x = s.a.x + 160;
    pickUp(s, "carrello");
    tap(s, { light: true });
    run(s.world, s.fighters, s.ctx, 20);
    assert.equal(gear(s.ctx.events, "scoop").length, 1);
    run(s.world, s.fighters, s.ctx, Math.ceil(RIDE.cart.holdMs / DT) + 5);
    assert.equal(gear(s.ctx.events, "launch").length, 1);
  });
});
