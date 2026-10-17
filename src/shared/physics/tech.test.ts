// Test della rialzata al volo (TECH). Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { TECH, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560

// Un lottatore stordito che cade sul palco da 60 pixel
function falling() {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  run([f], ctx, 10);
  f.x = 290; // fuori dalle piattaforme sottili: si cade sul blocco
  f.y = 500;
  f.vy = 300;
  f.onGround = false;
  f.hitstunTimer = 1000;
  f.hitstun = true;
  ctx.events.length = 0;
  return { ctx, f };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

function untilLanded(f: Fighter, ctx: PhysicsContext) {
  for (let i = 0; i < 60 && !f.onGround; i++) run([f], ctx, 1);
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });

describe("rialzata al volo", () => {
  it("scudo poco prima di toccare terra: niente più stordimento e intoccabili", () => {
    const { ctx, f } = falling();
    press(f, { shield: true });
    untilLanded(f, ctx);
    assert.equal(f.hitstun, false);
    assert.equal(f.hitstunTimer, 0);
    assert.equal(f.invulnerable, true);
    assert.ok(ctx.events.some((e) => e.type === "dodge" && !e.air), "si vede come una schivata a terra");
  });

  it("con una direzione si rotola", () => {
    const { ctx, f } = falling();
    press(f, { shield: true, right: true });
    untilLanded(f, ctx);
    const x = f.x;
    run([f], ctx, 10);
    assert.ok(f.x > x + 60, `rotola a destra: da ${x} a ${f.x}`);
  });

  it("senza scudo si resta storditi", () => {
    const { ctx, f } = falling();
    untilLanded(f, ctx);
    assert.equal(f.hitstun, true);
  });

  it("premuto troppo presto non vale", () => {
    const { ctx, f } = falling();
    f.y = 100; // molto più in alto: tocca terra dopo la finestra
    press(f, { shield: true });
    run([f], ctx, 1);
    press(f, {});
    untilLanded(f, ctx);
    assert.ok(ctx.events.some((e) => e.type === "land"));
    assert.equal(f.hitstun, true, "la finestra era già chiusa");
  });

  it("premere a raffica non basta: dopo una pressione serve aspettare", () => {
    const { ctx, f } = falling();
    f.y = 100;
    for (let i = 0; i < 60 && !f.onGround; i++) {
      press(f, { shield: i % 2 === 0 });
      run([f], ctx, 1);
    }
    assert.ok(Math.ceil(TECH.lockoutMs / DT) > Math.ceil(TECH.windowMs / DT));
    assert.equal(f.hitstun, true, "le pressioni dopo la prima non riaprono la finestra");
  });
});
