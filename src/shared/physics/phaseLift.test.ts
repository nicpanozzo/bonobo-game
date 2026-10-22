// Bologna (#433): all'inizio della zuffa il fondo della zona di espulsione sale da 2500 a 1650 e la piazza è a 2000.
// Chi è ancora a terra non perde una vita: viene riportato in cima. Logica pura, `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BOLOGNA, TICK_RATE } from "../constants";
import { STAGES } from "../stages";
import { createFighter, stepWorld, type PhysicsContext } from "./index";

const bologna = STAGES.bologna;
const DT = 1000 / TICK_RATE;

describe("Bologna: fase della zuffa (#433)", () => {
  it("chi è in piazza all'inizio della zuffa viene alzato, non è un KO", () => {
    const ctx: PhysicsContext = { stage: bologna, events: [], timeMs: BOLOGNA.brawlMs - DT * 2 };
    const fighters = [0, 1, 2].map((i) => createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: (i % 2) + 1, index: i, stocks: 3 }, bologna));
    fighters.forEach((f, i) => {
      f.x = 700 + i * 200;
      f.y = 2000; // sul suolo della piazza
      f.onGround = true;
    });
    for (let i = 0; i < 4; i++) stepWorld(fighters, DT, ctx);
    assert.ok(ctx.timeMs! >= BOLOGNA.brawlMs);
    assert.equal(ctx.events.filter((e) => e.type === "ko").length, 0, "nessun KO");
    for (const f of fighters) {
      assert.equal(f.stocks, 3);
      assert.ok(f.y <= ctx.stage.blastZone.bottom, `${f.id} è dentro la zona`);
      assert.ok(f.y < 1500, `${f.id} è stato riportato su`);
    }
    assert.equal(new Set(fighters.map((f) => Math.round(f.x))).size, 3, "in fila, non uno sull'altro");
  });

  it("durante la zuffa chi esce dai lati perde la vita lo stesso", () => {
    const ctx: PhysicsContext = { stage: bologna, events: [], timeMs: BOLOGNA.brawlMs + 5000 };
    const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 1, index: 0, stocks: 3 }, bologna);
    f.x = 2500; // oltre il bordo destro
    f.y = 1000;
    stepWorld([f], DT, ctx);
    assert.equal(ctx.events.filter((e) => e.type === "ko").length, 1);
  });
});
