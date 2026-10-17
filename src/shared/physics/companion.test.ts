// Test del compagno (#369), il beagle di Lampione. Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { COMPANION, TICK_RATE } from "../constants";
import { Match } from "../match";
import { getStage } from "../stages";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

function setup(characterId = "lampione") {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p0", name: "P0", characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);
  run([f], ctx, 30);
  return { ctx, f };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

describe("il beagle di Lampione (#369)", () => {
  it("c'è solo per chi ha un compagno", () => {
    assert.ok(setup().f.pet);
    assert.equal(setup("default").f.pet, null);
  });

  it("aspetta accanto a Lampione, un po' dietro, a terra", () => {
    const { f } = setup();
    const c = f.pet!;
    assert.ok(c.onGround);
    assert.equal(c.y, f.y);
    assert.ok(Math.abs(c.x - (f.x - f.facing * COMPANION.gapPx)) <= COMPANION.slackPx + 1, `beagle a ${c.x}, Lampione a ${f.x}`);
  });

  it("lo segue quando corre", () => {
    const { ctx, f } = setup();
    f.input = { ...emptyInput(), right: true };
    run([f], ctx, 40);
    f.input = emptyInput();
    run([f], ctx, 60);
    const c = f.pet!;
    assert.ok(c.x < f.x && f.x - c.x < COMPANION.gapPx + COMPANION.slackPx + 5, `beagle a ${Math.round(c.x)}, Lampione a ${Math.round(f.x)}`);
    assert.equal(c.facing, 1);
  });

  it("se resta troppo lontano torna di colpo accanto a lui", () => {
    const { ctx, f } = setup();
    f.pet!.x = f.x + COMPANION.teleportPx * 2;
    run([f], ctx, 1);
    assert.ok(Math.abs(f.pet!.x - f.x) < COMPANION.gapPx + 1);
  });

  it("finisce nello snapshot", () => {
    const m = new Match();
    m.addPlayer("a", "A", "lampione");
    m.step(DT);
    const p = m.snapshot([], 0).players[0];
    assert.ok(p.companion && typeof p.companion.x === "number");
  });
});
