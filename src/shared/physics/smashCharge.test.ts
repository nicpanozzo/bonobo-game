// Test dei colpi caricati (SMASH_CHARGE): il pesante a terra tenuto premuto si carica e al rilascio picchia più forte.
// Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, SMASH_CHARGE, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

function setup() {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [0, 1].map((i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  const [a, b] = fighters;
  a.x = 500;
  a.facing = 1;
  b.x = 500 + FIGHTER.width + 10;
  b.facing = -1;
  run(fighters, ctx, 10);
  ctx.events.length = 0;
  return { ctx, fighters, a, b };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const hits = (events: GameEvent[]) => events.filter((e): e is Extract<GameEvent, { type: "hit" }> => e.type === "hit");

// Tiene il pesante per holdTicks, lo lascia e aspetta il colpo
function smash(holdTicks: number, keys: Partial<InputState> = {}) {
  const s = setup();
  press(s.a, { heavy: true, ...keys });
  run(s.fighters, s.ctx, holdTicks);
  press(s.a, keys);
  for (let i = 0; i < 60 && hits(s.ctx.events).length === 0; i++) run(s.fighters, s.ctx, 1);
  return { ...s, hit: hits(s.ctx.events)[0] };
}

describe("colpi caricati", () => {
  it("tenendo premuto il colpo non parte e la carica cresce", () => {
    const { ctx, fighters, a } = setup();
    press(a, { heavy: true });
    run(fighters, ctx, 30);
    assert.equal(a.attack, "heavy");
    assert.equal(a.attackActive, false);
    assert.equal(hits(ctx.events).length, 0, "ancora niente colpo");
    assert.ok(a.charge > 0.4 && a.charge < 0.6, `carica a metà, è ${a.charge}`);
  });

  it("al rilascio il colpo caricato fa più danno e spinge di più", () => {
    const quick = smash(1).hit;
    const full = smash(Math.ceil(SMASH_CHARGE.maxMs / DT) + 5).hit;
    assert.equal(quick.damage, ATTACKS.heavy.damage);
    assert.equal(full.damage, Math.round(ATTACKS.heavy.damage * SMASH_CHARGE.maxMultiplier * 10) / 10);
    assert.ok(full.knockback > quick.knockback * 1.3, `${full.knockback} contro ${quick.knockback}`);
  });

  it("a carica piena parte da solo anche tenendo il tasto", () => {
    const { ctx, fighters, a } = setup();
    press(a, { heavy: true });
    run(fighters, ctx, Math.ceil((SMASH_CHARGE.maxMs + ATTACKS.heavy.startupMs) / DT) + 3);
    assert.equal(hits(ctx.events).length, 1);
    assert.equal(a.charge, 0, "finita la carica l'alone si spegne");
  });

  it("si caricano anche il pesante in su e in giù", () => {
    assert.equal(smash(40, { down: true }).hit.kind, "heavyDown");
    assert.ok(smash(40, { down: true }).hit.damage > ATTACKS.heavyDown.damage);
  });

  it("in aria il pesante non si carica", () => {
    const { ctx, fighters, a } = setup();
    a.y -= 300;
    a.onGround = false;
    press(a, { heavy: true });
    run(fighters, ctx, 3);
    assert.equal(a.attack, "heavyAir");
    assert.equal(a.charge, 0);
  });

  it("colpiti mentre si carica, la carica si perde", () => {
    const { ctx, fighters, a, b } = setup();
    press(a, { heavy: true });
    run(fighters, ctx, 10);
    press(b, { light: true });
    for (let i = 0; i < 30 && hits(ctx.events).length === 0; i++) run(fighters, ctx, 1);
    run(fighters, ctx, 10);
    assert.equal(a.attack, null);
    assert.equal(a.charge, 0);
    assert.equal(a.smashChargeMs, -1);
  });
});
