// Bologna (#433): il bus della piazza è una piattaforma mobile. Corre solo in piazza, si ferma in mezzo e porta chi ci sale.
// Logica pura, `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BOLOGNA, TICK_RATE } from "../constants";
import { busRuns, STAGES } from "../stages";
import { createFighter, moverOn, moverPosition, stepWorld, type PhysicsContext } from "./index";

const bologna = STAGES.bologna;
const DT = 1000 / TICK_RATE;
const bus = bologna.movers!.find((m) => m.kind === "bus")!;

describe("Bologna: il bus della piazza", () => {
  it("corre solo in piazza, alternando il verso, e si ferma col centro in mezzo", () => {
    assert.ok(bus, "c'è il bus");
    assert.ok(bus.on!.length >= 2, "più corse");
    for (const [from, to] of bus.on!) {
      assert.ok(from >= 0 && to <= BOLOGNA.towersMs, "dentro la fase della piazza");
    }
    assert.equal(moverOn(bus, BOLOGNA.towersMs + 1000), false, "con le torri non c'è");
    const first = moverPosition(bus, bus.on![0][0] + 1);
    const second = moverPosition(bus, bus.on![1][0] + 1);
    assert.ok(first.x < 0 && second.x > bologna.width! - bus.width, "una corsa da sinistra, la seguente da destra");
    // a metà della sosta il centro è in mezzo alla piazza
    const [t0, , t2] = bus.keys!.map(([t]) => t);
    const stop = moverPosition(bus, (t0 + t2) / 2 + (t2 - t0) / 4);
    assert.equal(Math.round(stop.x + bus.width / 2), 1100);
  });

  it("le corse non si sovrappongono e restano fuori dalla piazza a ogni capo", () => {
    const { keys, on } = busRuns(100, 200, 600, [-300, 1500], 0, 60000, 10000, 2000, 400);
    for (let i = 1; i < on.length; i++) assert.ok(on[i][0] >= on[i - 1][1], "una corsa dopo l'altra");
    for (let i = 1; i < keys.length; i++) assert.ok(keys[i][0] >= keys[i - 1][0], "chiavi in ordine di tempo");
    assert.ok(on[on.length - 1][1] <= 60000, "l'ultima finisce in tempo");
  });

  it("chi sale sul tetto alla fermata viene portato via", () => {
    const [t0, t1] = bus.keys!.map(([t]) => t); // partenza e arrivo alla fermata della prima corsa
    const ctx: PhysicsContext = { stage: bologna, events: [], timeMs: t1 + 200 };
    const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 1, index: 0, stocks: 3 }, bologna);
    const at = moverPosition(bus, ctx.timeMs!);
    f.x = at.x + bus.width / 2;
    f.y = at.y - 2;
    f.vy = 0;
    f.onGround = false;
    for (let i = 0; i < 30; i++) stepWorld([f], DT, ctx);
    assert.ok(Math.abs(f.y - bus.path[0].y) < 2, "sta sul tetto");
    const startX = f.x;
    // fino alla fine della sosta e un secondo di corsa
    const leave = bus.keys![2][0];
    while (ctx.timeMs! < leave + 1000) stepWorld([f], DT, ctx);
    assert.ok(f.x - startX > BOLOGNA.busSpeedPxS * 0.8, `portato a destra (da ${Math.round(startX)} a ${Math.round(f.x)})`);
    assert.ok(t0 < t1);
  });
});
