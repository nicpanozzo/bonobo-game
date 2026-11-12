// Test della Nuvola di Marcomunista (NUVOLA): sballa chi ci entra, lui ci si posa sopra una volta. `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { specialsFor, type ProjectileSpecial } from "../characters";
import { NUVOLA, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { boxOf, createProjectileWorld, fire } from "./projectiles";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);
const spec = specialsFor("marcomunista").side as ProjectileSpecial;

function setup() {
  const ctx: PhysicsContext = { stage, events: [], projectiles: createProjectileWorld() };
  const make = (id: string, characterId: string, index: number) =>
    createFighter({ id, name: id, characterId, color: 0, team: 0, index, stocks: 3 }, stage);
  const m = make("m", "marcomunista", 0);
  const t = make("t", "default", 1);
  const fighters = [m, t];
  run(fighters, ctx, 10);
  m.input = emptyInput();
  t.input = emptyInput();
  ctx.events.length = 0;
  return { ctx, m, t, fighters };
}
const run = (fighters: Fighter[], ctx: PhysicsContext, n: number) => {
  for (let i = 0; i < n; i++) stepWorld(fighters, DT, ctx);
};

describe("Nuvola di Marcomunista", () => {
  it("è la sua speciale laterale e non fa danno", () => {
    assert.ok(spec.cloud);
    assert.equal(spec.damage, 0);
  });

  it("chi ci entra resta sballato e cade più piano", () => {
    const { ctx, m, t, fighters } = setup();
    m.facing = 1;
    fire(m, "specialSide", spec, ctx);
    const cloud = ctx.projectiles!.list[0];
    t.x = cloud.x;
    t.y = cloud.y + spec.height / 2 - 2;
    const before = t.percent;
    run(fighters, ctx, 2);
    assert.ok(t.sballoMs > 0, "sballato");
    assert.equal(t.percent, before, "niente danno");
    assert.equal(ctx.projectiles!.list.length, 1, "la nuvola resta");
    // In aria cade più piano di uno lucido
    t.x = cloud.x + 600;
    t.y -= 300;
    t.onGround = false;
    t.vy = 0;
    run(fighters, ctx, 6);
    const slow = t.vy;
    t.sballoMs = 0;
    t.vy = 0;
    t.y -= 50;
    run(fighters, ctx, 6);
    assert.ok(slow < t.vy, `sballato ${slow} contro lucido ${t.vy}`);
    assert.equal(NUVOLA.gravityMult < 1, true);
  });

  it("lui ci si posa sopra una volta e riprende il doppio salto", () => {
    const { ctx, m, fighters } = setup();
    fire(m, "specialSide", spec, ctx);
    const cloud = ctx.projectiles!.list[0];
    const land = () => {
      const box = boxOf(cloud, spec);
      m.x = cloud.x;
      m.y = box.y + 4;
      m.onGround = false;
      m.vy = 300;
      m.jumpsLeft = 0;
      run(fighters, ctx, 1);
    };
    land();
    assert.ok(m.vy < 0, `saltello (vy ${m.vy})`);
    assert.ok(m.jumpsLeft >= 1);
    land();
    assert.ok(m.vy > 0, "la seconda volta ci passa attraverso");
  });
});
