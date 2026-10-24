// Bologna (#433): le bancarelle ai piedi di San Petronio. Il tendone fa da molla: chi ci arriva vola fino a metà torre.
// Logica pura, `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BOLOGNA, TICK_RATE } from "../constants";
import { STAGES } from "../stages";
import { createFighter, stepWorld, type PhysicsContext } from "./index";

const bologna = STAGES.bologna;
const DT = 1000 / TICK_RATE;
const awnings = bologna.jets!.filter((j) => j.kind === "tenda");

function bounceFrom(x: number, timeMs: number) {
  const ctx: PhysicsContext = { stage: bologna, events: [], timeMs };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 1, index: 0, stocks: 3 }, bologna);
  f.x = x;
  f.y = 2000; // sul selciato, dentro la bancarella
  f.onGround = true;
  let top = f.y;
  for (let i = 0; i < 90; i++) {
    stepWorld([f], DT, ctx);
    top = Math.min(top, f.y);
  }
  return top;
}

describe("Bologna: le bancarelle che fanno da molla", () => {
  it("due bancarelle in piazza, ai lati della statua, fino al crollo", () => {
    assert.equal(awnings.length, 2);
    for (const j of awnings) {
      assert.ok(j.x > 1000 && j.x + j.width < 1300, "tra le basi delle torri");
      assert.deepEqual(j.on, [[0, BOLOGNA.collapseMs]]);
    }
  });

  it("chi ci sale vola su di circa 480 px, in piazza e con le torri", () => {
    for (const t of [10000, BOLOGNA.towersMs + 10000]) {
      const top = bounceFrom(awnings[0].x + awnings[0].width / 2, t);
      assert.ok(top < 1560 && top > 1380, `arriva a metà torre (y ${Math.round(top)})`);
    }
  });

  it("dopo il crollo non ci sono più", () => {
    const top = bounceFrom(awnings[0].x + awnings[0].width / 2, BOLOGNA.collapseMs + 2000);
    assert.ok(top > 1900, "resta a terra");
  });
});
