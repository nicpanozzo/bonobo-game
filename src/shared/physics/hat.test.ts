// Test del Cappello boomerang di Marcomunista (HAT): andata, sosta, ritorno, rimbalzo alla Mario. `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { specialsFor, type ProjectileSpecial } from "../characters";
import { FATTANZA, HAT, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import { hatAway } from "./hat";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { createProjectileWorld, fire } from "./projectiles";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);
const ticks = (ms: number) => Math.ceil((ms / 1000) * TICK_RATE);

function setup() {
  const ctx: PhysicsContext = { stage, events: [], projectiles: createProjectileWorld() };
  const m = createFighter({ id: "m", name: "M", characterId: "marcomunista", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  const fighters = [m];
  run(fighters, ctx, 10);
  m.input = emptyInput();
  ctx.events.length = 0;
  return { ctx, m, fighters };
}
const run = (fighters: Fighter[], ctx: PhysicsContext, n: number) => {
  for (let i = 0; i < n; i++) stepWorld(fighters, DT, ctx);
};
const hat = (ctx: PhysicsContext) => ctx.projectiles!.list[0];
const spec = specialsFor("marcomunista").neutral as ProjectileSpecial;

describe("Cappello boomerang di Marcomunista", () => {
  it("è la sua speciale neutra", () => {
    assert.equal(spec.type, "projectile");
    assert.ok(spec.boomerang);
  });

  it("va avanti, si ferma a mezz'aria e torna da lui", () => {
    const { ctx, m, fighters } = setup();
    m.facing = 1;
    fire(m, "specialNeutral", spec, ctx);
    assert.ok(hatAway(m, ctx));
    run(fighters, ctx, ticks(HAT.outMs) + 2);
    const out = hat(ctx);
    assert.ok(out.x > m.x + 80, `è andato avanti (${out.x - m.x} px)`);
    const stopX = out.x;
    run(fighters, ctx, ticks(HAT.hoverMs[0] / 2));
    assert.equal(hat(ctx).x, stopX, "fermo a mezz'aria");
    run(fighters, ctx, ticks(HAT.hoverMs[0] / 2) + ticks(1500));
    assert.equal(ctx.projectiles!.list.length, 0, "ripreso al volo");
    assert.ok(!hatAway(m, ctx));
  });

  it("senza cappello non fluttua", () => {
    const { ctx, m, fighters } = setup();
    fire(m, "specialNeutral", spec, ctx);
    m.y -= 300;
    m.onGround = false;
    m.vy = 400;
    m.jumpsLeft = 0;
    m.input = { ...emptyInput(), jump: true };
    run(fighters, ctx, 2);
    assert.equal(m.floating, false);
  });

  it("scendendo sul cappello fermo ci rimbalza sopra, una volta per volo", () => {
    const { ctx, m, fighters } = setup();
    fire(m, "specialNeutral", spec, ctx);
    run(fighters, ctx, ticks(HAT.outMs) + 2);
    const h = hat(ctx);
    const drop = () => {
      m.x = h.x;
      m.y = h.y - HAT.bounceAbovePx + 2;
      m.onGround = false;
      m.vy = 300;
      run(fighters, ctx, 1);
    };
    drop();
    assert.ok(m.vy < 0, `rimbalzato (vy ${m.vy})`);
    assert.ok(ctx.events.some((e) => e.type === "hatBounce"));
    drop();
    assert.ok(m.vy > 0, "il secondo no: un rimbalzo per volo a Lucido");
  });

  it("a Strafatto i rimbalzi sono due", () => {
    assert.equal(HAT.maxBounces[FATTANZA.levels], 2);
    assert.ok(HAT.hoverMs[FATTANZA.levels] > HAT.hoverMs[0]);
  });
});
