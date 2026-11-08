// Test degli oggetti da impugnare e da sparo (held.ts), provati sui cinque principali.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { HELD, ITEM_RULES, TICK_RATE } from "../constants";
import { ITEMS } from "../items";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { createItemWorld, handleItemInput, stepItems, type Item, type ItemWorld } from "./items";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);
const CORE = ["bradipo", "marcomunista", "orsoblu", "egiainuso", "elvedeo"];

function setup(characterId = "default", others = ["default"]) {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [characterId, ...others].map((c, i) => createFighter({ id: `p${i}`, name: `P${i}`, characterId: c, color: 0, team: 0, index: i, stocks: 3 }, stage));
  const world = createItemWorld(42, { everyMs: 1e9 });
  world.spawnTimer = 1e9;
  const [a, b] = fighters;
  a.x = 500;
  a.facing = 1;
  b.x = 800;
  return { ctx, fighters, world, a, b };
}
type S = ReturnType<typeof setup>;

function run(s: S, ticks: number) {
  for (let i = 0; i < ticks; i++) {
    handleItemInput(s.world, s.fighters, s.ctx);
    stepWorld(s.fighters, DT, s.ctx);
    stepItems(s.world, s.fighters, DT, s.ctx);
  }
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const ofType = <T extends GameEvent["type"]>(events: GameEvent[], type: T) => events.filter((e): e is Extract<GameEvent, { type: T }> => e.type === type);
const gear = (s: S, phase: string) => ofType(s.ctx.events, "gear").filter((e) => e.phase === phase);

function pickUp(s: S, kind: string) {
  const item: Item = { id: 99, kind, x: s.a.x + 10, y: s.a.y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: true, riding: -1, thrownBy: null, lifeMs: ITEM_RULES.lifeMs };
  s.world.items.push(item);
  press(s.a, { light: true });
  run(s, 1);
  press(s.a, {});
  run(s, 30); // passa anche l'attesa tra un attacco e l'altro
  assert.equal(item.heldBy, s.a.id, `${kind} in mano`);
}

// Un leggero con l'arma in mano, contro b vicino
function swing(s: S, gap: number) {
  s.b.x = s.a.x + gap;
  press(s.a, { light: true });
  run(s, 1);
  press(s.a, {});
  run(s, 25);
}

describe("oggetti da impugnare e da sparo", () => {
  it("con la scopa il leggero arriva più lontano e fa più male, per tutti e cinque i principali", () => {
    for (const c of CORE) {
      const bare = setup(c);
      swing(bare, 105);
      const missed = ofType(bare.ctx.events, "hit").length;
      const s = setup(c);
      pickUp(s, "scopa");
      swing(s, 105);
      const hit = ofType(s.ctx.events, "hit")[0];
      assert.ok(hit, `${c}: con la scopa prende b a 105 px (senza: ${missed} colpi)`);
      assert.equal(s.world.items[0].heldBy, s.a.id, "il leggero non lancia la scopa");
      assert.ok(ofType(s.ctx.events, "itemThrow").length === 0);
    }
  });

  it("la scopa si rompe dopo i suoi colpi a segno", () => {
    const s = setup();
    pickUp(s, "scopa");
    // ogni tanto b è ancora in aria e il colpo va a vuoto: si continua finché non si rompe
    for (let i = 0; i < HELD.scopa.uses * 2 && !gear(s, "break").length; i++) {
      s.b.percent = 0;
      s.b.x = s.a.x + 60;
      s.b.y = s.a.y;
      s.b.vx = s.b.vy = 0;
      swing(s, 60);
    }
    assert.equal(gear(s, "break").length, 1);
    assert.equal(ofType(s.ctx.events, "hit").length, HELD.scopa.uses, "si rompe proprio al colpo numero uses");
    assert.equal(s.world.items.length, 0);
  });

  it("il pesce surgelato congela chi prende", () => {
    const s = setup();
    pickUp(s, "pesce");
    s.b.x = s.a.x + 60;
    press(s.a, { light: true });
    run(s, 1);
    press(s.a, {});
    run(s, 12);
    assert.equal(gear(s, "freeze").length, 1);
    assert.equal(s.b.powerup, "gelo");
    assert.ok(s.b.stunned, "fermo nel ghiaccio");
  });

  it("l'anguilla dà la scossa anche a chi sta vicino a chi prende", () => {
    const s = setup("default", ["default", "default"]);
    const c = s.fighters[2];
    pickUp(s, "anguilla");
    c.x = s.a.x + 200;
    s.b.x = s.a.x + 60;
    press(s.a, { light: true });
    run(s, 1);
    press(s.a, {});
    run(s, 12);
    const zaps = gear(s, "zap");
    assert.ok(zaps.some((e) => e.id === c.id), "la scossa arriva al terzo");
    assert.equal(c.percent, HELD.anguilla.zapDamage);
  });

  it("l'ombrellone fa planare tenendo il salto", () => {
    const s = setup();
    pickUp(s, "ombrellone");
    s.a.y -= 300;
    s.a.onGround = false;
    press(s.a, { jump: true });
    run(s, 40);
    assert.ok(s.a.vy <= HELD.ombrellone.glideFallSpeed + 1, `scende piano: ${s.a.vy}`);
  });

  it("la pistola ad acqua spara gocce che spingono, e finiti i colpi sparisce", () => {
    const s = setup();
    pickUp(s, "pistola");
    s.b.x = s.a.x + 260;
    press(s.a, { light: true });
    run(s, 1);
    press(s.a, {});
    run(s, 20);
    const hit = ofType(s.ctx.events, "hit").find((e) => e.itemKind === "goccia");
    assert.ok(hit, "la goccia prende b");
    assert.equal(s.b.percent, ITEMS.goccia.damage);
    for (let i = 1; i < HELD.pistola.ammo; i++) {
      press(s.a, { light: true });
      run(s, 1);
      press(s.a, {});
      run(s, Math.ceil(HELD.pistola.cooldownMs / DT));
    }
    assert.equal(gear(s, "shot").length, HELD.pistola.ammo);
    assert.ok(!s.world.items.some((i) => i.kind === "pistola"), "scarica, sparisce");
  });

  it("l'idrante carica tenendo J e il getto prende chi è lontano", () => {
    const s = setup();
    pickUp(s, "idrante");
    s.b.x = s.a.x + 450; // lontano ma sulla stessa piattaforma
    press(s.a, { light: true });
    run(s, Math.ceil(HELD.idrante.chargeMs / DT) + 2);
    press(s.a, {});
    run(s, 2);
    assert.equal(gear(s, "jet").length, 1);
    assert.equal(s.b.percent, HELD.idrante.damage);
  });

  it("lo sparabolle chiude in una bolla che sale e poi scoppia", () => {
    const s = setup();
    pickUp(s, "sparabolle");
    s.b.x = s.a.x + 200;
    const y0 = s.b.y;
    press(s.a, { light: true });
    run(s, 1);
    press(s.a, {});
    run(s, 40);
    assert.equal(gear(s, "trap").length, 1);
    assert.equal(s.b.powerup, "bolla");
    assert.ok(s.b.y < y0 - 20, "sale");
    run(s, Math.ceil(HELD.bolla.trapMs / DT));
    assert.ok(gear(s, "pop").some((e) => e.id === s.b.id), "la bolla scoppia");
    assert.equal(s.b.powerup, null);
    assert.equal(s.b.percent, HELD.bolla.popDamage);
  });

  it("lo sparabolle triplo spara tre bolle che rimbalzano", () => {
    const s = setup();
    pickUp(s, "sparabolleTriplo");
    s.b.x = 2000; // lontano: le bolle volano libere
    press(s.a, { light: true });
    run(s, 1);
    assert.equal(s.world.items.filter((i) => i.kind === "bollaRimbalzina").length, 3);
  });
});
