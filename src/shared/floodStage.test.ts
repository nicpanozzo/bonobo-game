import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, FLOOD, TICK_RATE } from "./constants";
import { FLOOD_LAYOUT, FLOOD_RISE } from "./floodStage";
import { createFighter, stepWorld, type PhysicsContext } from "./physics/index";
import { riseOffset, riseTimeMs, stageAt, waterAt } from "./physics/timed";
import { STAGES } from "./stages";

const DT = 1000 / TICK_RATE;
const stage = STAGES.isole;

describe("Il Diluvio", () => {
  it("il mare sale sempre più in fretta e si ferma sotto l'Arca", () => {
    assert.equal(riseOffset(FLOOD_RISE, FLOOD.startMs), 0);
    const a = riseOffset(FLOOD_RISE, FLOOD.startMs + 10000);
    const b = riseOffset(FLOOD_RISE, FLOOD.startMs + 20000) - a;
    assert.ok(a > 200 && b > a, `primi 10 s ${a}, secondi ${b}`);
    assert.equal(riseOffset(FLOOD_RISE, 3_600_000), FLOOD_RISE.maxPx);
    assert.ok(FLOOD_RISE.waterY - FLOOD_RISE.maxPx > FLOOD_LAYOUT.arkY, "l'Arca resta asciutta");
    for (const px of [10, 500, 4000]) assert.ok(Math.abs(riseOffset(FLOOD_RISE, riseTimeMs(FLOOD_RISE, px)) - px) < 0.01);
    const top = riseTimeMs(FLOOD_RISE, FLOOD_RISE.maxPx);
    assert.ok(top > 180_000 && top < 300_000, `in cima dopo ${Math.round(top / 1000)} s`);
  });

  it("zona di espulsione e punto di ritorno salgono col mare, a scalini", () => {
    const t = FLOOD.startMs + 60000;
    const view = stageAt(stage, t);
    const water = waterAt(stage, t)!;
    assert.ok(water < FLOOD_RISE.waterY - 1000);
    assert.equal(view.blastZone.bottom, water + 40);
    assert.equal(view.blastZone.top, water - FLOOD.skyPx);
    assert.equal(view.respawn.y, water - FLOOD.respawnPx);
    assert.equal(stageAt(stage, t + 1), view, "dentro lo stesso scalino la vista non cambia");
  });

  it("vicino alla superficie c'è sempre qualcosa su cui salire, e sott'acqua i pezzi spariscono", () => {
    for (let t = FLOOD.startMs; t < riseTimeMs(FLOOD_RISE, FLOOD_RISE.maxPx); t += 5000) {
      const view = stageAt(stage, t);
      const water = waterAt(stage, t)!;
      const fixed = [...view.solids.map((s) => s.y), ...view.platforms.map((p) => p.y)];
      assert.ok(fixed.every((y) => y < water + FLOOD.drownPx + 40), "niente pezzi sommersi");
      const ys = [...fixed, ...(view.movers ?? []).map((m) => m.path[0].y)].sort((a, b) => b - a); // le zattere fanno da fila
      // Sopra la superficie i pezzi si susseguono a meno di un salto l'uno dall'altro
      const above = ys.filter((y) => y < water && y > water - 1200);
      for (let i = 1; i < above.length; i++) assert.ok(above[i - 1] - above[i] <= 130, `buco tra ${above[i - 1]} e ${above[i]} a ${t} ms`);
      assert.ok(above.length > 0 && water - above[0] < 260, `il primo pezzo sopra il mare a ${t} ms`);
    }
  });

  it("chi resta sull'isola finisce in mare e perde una vita, senza essere ripescato", () => {
    const ctx: PhysicsContext = { stage, events: [], timeMs: 0 };
    const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
    let ko = -1;
    for (let i = 0; i < 40 * TICK_RATE && ko < 0; i++) {
      stepWorld([f], DT, ctx);
      if (ctx.events.some((e) => e.type === "ko")) ko = ctx.timeMs!;
    }
    assert.ok(ko > FLOOD.startMs, `KO a ${ko} ms`);
    assert.ok(f.y - FIGHTER.height < ctx.stage.blastZone.bottom + 2000);
  });
});
