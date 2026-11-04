// Test di Tempesta!, la suprema "storm" di Capt. OrsoBlu (#547): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getCharacter, type StormSupreme } from "../characters";
import { SUPREME, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { stormRoll } from "./supreme";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560
const sp = getCharacter("orsoblu").supreme as StormSupreme;

function setup() {
  const ctx: PhysicsContext = { stage, events: [] };
  const mk = (id: string, characterId: string, index: number) => createFighter({ id, name: id, characterId, color: 0, team: 0, index, stocks: 3 }, stage);
  const bear = mk("orso", "orsoblu", 0);
  const other = mk("altro", "default", 1);
  bear.x = 400;
  other.x = 640;
  for (const f of [bear, other]) {
    f.y = 560;
    f.onGround = true;
  }
  return { ctx, bear, other };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) {
    stepWorld(fighters, DT, ctx);
    for (const f of fighters) f.input = emptyInput();
  }
}

function storm(bear: Fighter) {
  bear.supreme = SUPREME.max;
  bear.input = { ...emptyInput(), supreme: true };
}

describe("Tempesta! di Capt. OrsoBlu", () => {
  it("è la sua suprema, con il rollio avanti e indietro", () => {
    assert.equal(sp.type, "storm");
    assert.ok(stormRoll(sp, sp.rollPeriodMs / 4) > 0.99);
    assert.ok(stormRoll(sp, (sp.rollPeriodMs * 3) / 4) < -0.99);
  });

  it("gli altri scivolano col rollio, lui resta fermo al timone", () => {
    const { ctx, bear, other } = setup();
    storm(bear);
    run([bear, other], ctx, 1);
    assert.equal(bear.attack, "supreme");
    const x0 = bear.x;
    run([bear, other], ctx, Math.round((sp.windupMs + sp.rollPeriodMs / 4) / DT) - 2);
    assert.ok(other.x > 640 + 40, `scivola verso destra (${other.x.toFixed(0)})`);
    assert.ok(Math.abs(bear.x - x0) < 1, "lui non si muove");
  });

  it("le onde colpiscono chi è a terra e lo spingono dalla parte del rollio", () => {
    const { ctx, bear, other } = setup();
    storm(bear);
    run([bear, other], ctx, Math.round((sp.windupMs + sp.rollPeriodMs / 4) / DT) + 3);
    assert.ok(other.percent >= sp.damage, `preso dall'onda (${other.percent}%)`);
    assert.ok(other.vx > 0, "spinto verso destra, dove rolla");
  });

  it("chi cammina contro il rollio resiste", () => {
    const { ctx, bear, other } = setup();
    storm(bear);
    run([bear, other], ctx, Math.round(sp.windupMs / DT));
    const x0 = other.x;
    for (let i = 0; i < Math.round(sp.rollPeriodMs / 4 / DT) - 3; i++) {
      other.input = { ...emptyInput(), left: true };
      stepWorld([bear, other], DT, ctx);
    }
    assert.ok(other.x < x0, "tenendo sinistra va comunque a sinistra");
  });
});
