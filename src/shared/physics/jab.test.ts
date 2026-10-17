// Test della combo di leggeri (JAB): leggero, leggero, finale. Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, JAB, TICK_RATE } from "../constants";
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

// Un leggero premuto e lasciato, poi si aspetta waitTicks
function tap(s: ReturnType<typeof setup>, waitTicks: number) {
  press(s.a, { light: true });
  run(s.fighters, s.ctx, 1);
  press(s.a, {});
  run(s.fighters, s.ctx, waitTicks);
}

describe("combo di leggeri", () => {
  it("tre leggeri di fila: due colpi e il finale che lancia", () => {
    const s = setup();
    for (let n = 0; n < 3; n++) tap(s, 14);
    const h = hits(s.ctx.events);
    assert.deepEqual(h.map((e) => e.damage), [ATTACKS.light.damage, JAB.steps[0].damage, JAB.steps[1].damage]);
    assert.ok(h[2].knockback > h[1].knockback * 2, `il finale lancia: ${h.map((e) => e.knockback)}`);
  });

  it("la combo non aspetta l'attesa del leggero", () => {
    const s = setup();
    tap(s, 14); // meno dell'attesa di un leggero (ATTACKS.light.cooldownMs = 280 ms, circa 17 tick)
    assert.ok(s.a.cooldownTimer > 0, "il primo leggero ha ancora l'attesa");
    tap(s, 2);
    assert.equal(s.a.attack, "light");
    assert.equal(s.a.jabStep, 1);
  });

  it("troppo tardi o a vuoto si ricomincia dal primo", () => {
    const late = setup();
    tap(late, 14 + Math.ceil(JAB.windowMs / DT) + 20);
    tap(late, 14);
    assert.deepEqual(hits(late.ctx.events).map((e) => e.damage), [ATTACKS.light.damage, ATTACKS.light.damage]);
    const miss = setup();
    miss.fighters[1].x = 900; // nessuno a portata
    tap(miss, 14);
    tap(miss, 2);
    assert.equal(miss.a.attack, null, "a vuoto il secondo leggero aspetta l'attesa");
  });

  it("dopo il finale si riparte dal primo", () => {
    const s = setup();
    for (let n = 0; n < 3; n++) tap(s, 14);
    assert.equal(s.a.jabTimer, 0);
  });
});
