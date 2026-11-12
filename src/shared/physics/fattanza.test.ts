// Test della Fattanza di Marcomunista (FATTANZA): barra, gravità, fluttuata col cappello, botta. `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FATTANZA, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { InputState } from "../types";
import { addFattanza, fattanzaLevel, hurtFattanza } from "./fattanza";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

function setup(characterId = "marcomunista") {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "m", name: "M", characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);
  run(f, ctx, 10);
  ctx.events.length = 0;
  return { ctx, f };
}
const run = (f: Fighter, ctx: PhysicsContext, ticks: number) => {
  for (let i = 0; i < ticks; i++) stepWorld([f], DT, ctx);
};
const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });

// In aria, ben sopra l'arena, fermo
function airborne(f: Fighter) {
  f.y -= 400;
  f.onGround = false;
  f.vy = 0;
  f.jumpsLeft = 0;
}

describe("Fattanza di Marcomunista", () => {
  it("sale stando in aria e scende a terra dopo la grazia", () => {
    const { ctx, f } = setup();
    airborne(f);
    run(f, ctx, TICK_RATE / 4); // un quarto di secondo, prima di toccare terra
    assert.ok(!f.onGround);
    assert.ok(f.fattanza > FATTANZA.airGain * 0.2, `in aria ${f.fattanza}`);
    run(f, ctx, TICK_RATE); // atterra
    assert.ok(f.onGround);
    f.fattanza = 50;
    run(f, ctx, Math.ceil((FATTANZA.groundGraceMs / 1000) * TICK_RATE) + TICK_RATE);
    assert.ok(f.fattanza < 50, `a terra ${f.fattanza}`);
  });

  it("gli altri personaggi non hanno la barra", () => {
    const { ctx, f } = setup("default");
    airborne(f);
    run(f, ctx, TICK_RATE);
    assert.equal(f.fattanza, 0);
  });

  it("più livelli, gravità più bassa: cade più piano", () => {
    const fall = (points: number) => {
      const { ctx, f } = setup();
      airborne(f);
      f.fattanza = points;
      run(f, ctx, 10);
      return f.vy;
    };
    assert.ok(fall(2 * FATTANZA.perLevel) < fall(0));
  });

  it("tenendo Salto mentre scende fluttua col cappello, poi la fluttuata finisce", () => {
    const { ctx, f } = setup();
    airborne(f);
    f.vy = 600;
    press(f, { jump: true });
    run(f, ctx, 3);
    assert.ok(f.floating);
    assert.ok(f.vy <= FATTANZA.floatFallSpeed + 1, `vy ${f.vy}`);
    run(f, ctx, Math.ceil((FATTANZA.floatMs[0] / 1000) * TICK_RATE) + 5);
    assert.equal(f.floating, false, "a Lucido la fluttuata dura poco");
  });

  it("a Strafatto fluttua finché dura, poi la botta lo azzera e lo stordisce", () => {
    const { ctx, f } = setup();
    airborne(f);
    addFattanza(f, FATTANZA.perLevel * FATTANZA.levels);
    assert.equal(fattanzaLevel(f), 3);
    assert.equal(f.strafattoMs, FATTANZA.strafattoMs);
    f.vy = 100;
    press(f, { jump: true });
    run(f, ctx, Math.ceil((FATTANZA.floatMs[3] / 1000) * TICK_RATE) + 10);
    assert.ok(f.floating, "a Strafatto la fluttuata non finisce");
    f.strafattoMs = DT;
    run(f, ctx, 2);
    assert.equal(f.fattanza, 0);
    assert.ok(f.stunTimer > 0);
    assert.ok(ctx.events.some((e) => e.type === "botta"));
  });

  it("un colpo forte fa perdere un livello, uno debole no", () => {
    const { f } = setup();
    f.fattanza = 150;
    hurtFattanza(f, FATTANZA.bigHit - 1);
    assert.equal(f.fattanza, 150);
    hurtFattanza(f, FATTANZA.bigHit);
    assert.equal(f.fattanza, 50);
  });
});
