// Bologna (#433): la corrente calda che sale dalle macerie della Garisenda. Riporta su chi cade e gli ridà il recupero.
// Logica pura, `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BOLOGNA, TICK_RATE } from "../constants";
import { STAGES } from "../stages";
import { createFighter, stepWorld, type PhysicsContext } from "./index";

const bologna = STAGES.bologna;
const DT = 1000 / TICK_RATE;
const updrafts = bologna.jets!.filter((j) => j.kind === "corrente");

// Un lottatore che cade nella corrente dall'alto, già senza recupero: dove arriva in 2 s
function fallInto(timeMs: number) {
  const ctx: PhysicsContext = { stage: bologna, events: [], timeMs };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 1, index: 0, stocks: 3 }, bologna);
  const j = updrafts[0];
  f.x = j.x + j.width / 2;
  f.y = 1600;
  f.vy = 600;
  f.onGround = false;
  f.recoveryUsed = true;
  let top = f.y;
  for (let i = 0; i < 2 * TICK_RATE; i++) {
    ctx.timeMs = timeMs + i * DT;
    stepWorld([f], DT, ctx);
    top = Math.min(top, f.y);
  }
  return { top, recoveryUsed: f.recoveryUsed };
}

describe("Bologna: la corrente calda delle macerie", () => {
  it("una sola, sopra la rampa, accesa con la rampa", () => {
    assert.equal(updrafts.length, 1);
    assert.deepEqual(updrafts[0].on, [[BOLOGNA.rampMs, BOLOGNA.horizonMs]]);
  });

  it("chi ci cade torna su fino ai detriti in cima, col recupero pronto", () => {
    const r = fallInto(BOLOGNA.brawlMs + 10000);
    assert.ok(r.top < 1200, `risale (y ${Math.round(r.top)})`);
    assert.equal(r.recoveryUsed, false);
  });

  it("prima della rampa non c'è", () => {
    const r = fallInto(BOLOGNA.collapseMs + 1000);
    assert.ok(r.top >= 1600, `continua a cadere (y ${Math.round(r.top)})`);
  });
});
