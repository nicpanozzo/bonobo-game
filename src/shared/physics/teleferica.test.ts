// La teleferica (#433): un cestello (mover) che non va col tempo ma lo spingono gli argani (postazioni "teleferica").
// Logica pura, `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { STATION, TICK_RATE, WORLD } from "../constants";
import { STAGES, type StageSpec } from "../stages";
import type { InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { stationSnapshot } from "./stations";

const DT = 1000 / TICK_RATE;
const FLOOR = 650;
const CABLE_Y = 400;
const LEN = 500; // il cavo da x 200 a x 700

function stage(): StageSpec {
  return {
    id: "prova-teleferica",
    name: "Prova",
    solids: [{ x: 0, y: FLOOR, width: WORLD.width, height: 50 }],
    platforms: [],
    movers: [{ kind: "teleferica", width: 100, path: [{ x: 200, y: CABLE_Y }, { x: 200 + LEN, y: CABLE_Y }], periodMs: 1000 }],
    stations: [
      { kind: "teleferica", x: 50, y: FLOOR, width: 80, team: 1, cart: 0 },
      { kind: "teleferica", x: 900, y: FLOOR, width: 80, team: 2, cart: 0 },
    ],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: FLOOR }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
}

function fighter(s: StageSpec, i: number, x: number, y: number, team: number): Fighter {
  const f = createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team, index: i, stocks: 3 }, s);
  f.x = x;
  f.y = y;
  f.onGround = true;
  return f;
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number, keys: Map<Fighter, Partial<InputState>> = new Map()) {
  for (const f of fighters) f.input = { ...emptyInput(), ...keys.get(f) };
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
  for (const f of fighters) f.input = emptyInput();
}

// Il primo entra nel suo argano (una pressione di attacco), il secondo resta dove l'hanno messo
function setup(...who: [x: number, y: number, team: number][]) {
  const s = stage();
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 0 };
  const fighters = who.map(([x, y, team], i) => fighter(s, i, x, y, team));
  run(fighters, ctx, 5);
  return { ctx, fighters };
}

const cart = (ctx: PhysicsContext) => ctx.stations!.carts[0].k;
const enter = (fighters: Fighter[], ctx: PhysicsContext, f: Fighter) => {
  run(fighters, ctx, 1, new Map([[f, { light: true }]]));
  run(fighters, ctx, 1);
};

describe("la teleferica (#433)", () => {
  it("senza nessuno agli argani il cestello resta dove sta", () => {
    const { ctx, fighters } = setup([90, FLOOR, 1]);
    run(fighters, ctx, TICK_RATE);
    assert.equal(cart(ctx), STATION.cartStart);
  });

  it("chi usa l'argano spinge il cestello con destra e sinistra, e chi ci sta sopra va con lui", () => {
    const start = 200 + LEN * STATION.cartStart;
    const { ctx, fighters } = setup([90, FLOOR, 1], [start + 50, CABLE_Y, 1]);
    const [driver, rider] = fighters;
    enter(fighters, ctx, driver);
    assert.equal(driver.station, 0);
    const k0 = cart(ctx);
    const x0 = rider.x;
    run(fighters, ctx, TICK_RATE, new Map([[driver, { right: true }]]));
    const moved = (cart(ctx) - k0) * LEN;
    assert.ok(Math.abs(moved - STATION.cartSpeedPxS) < 10, `in 1 s va di circa cartSpeedPxS (${Math.round(moved)} px)`);
    assert.ok(rider.onGround && Math.abs(rider.x - x0 - moved) < 6, `chi sta sopra va con lui (${Math.round(rider.x - x0)} px)`);
    run(fighters, ctx, 10 * TICK_RATE, new Map([[driver, { right: true }]]));
    assert.equal(cart(ctx), 1, "si ferma al capo del cavo");
    run(fighters, ctx, TICK_RATE, new Map([[driver, { left: true }]]));
    assert.ok(cart(ctx) < 1, "e torna indietro");
  });

  it("due squadre che tirano in versi opposti si annullano", () => {
    const { ctx, fighters } = setup([90, FLOOR, 1], [940, FLOOR, 2]);
    const [a, b] = fighters;
    enter(fighters, ctx, a);
    enter(fighters, ctx, b);
    assert.equal(b.station, 1);
    run(fighters, ctx, TICK_RATE, new Map([[a, { left: true }], [b, { right: true }]]));
    assert.equal(cart(ctx), STATION.cartStart);
    assert.deepEqual(stationSnapshot(ctx).stations!.map((s) => s.cart), [STATION.cartStart, STATION.cartStart]);
  });

  it("a Bologna il cestello va dalla bombarda della Garisenda alla finestra della gru dell'Asinelli", () => {
    const b = STAGES.bologna;
    const winches = b.stations!.filter((s) => s.kind === "teleferica");
    assert.deepEqual(winches.map((s) => s.team), [1, 2]);
    const m = b.movers![winches[0].cart!];
    assert.equal(m.kind, "teleferica");
    assert.ok(winches.every((s) => s.cart === winches[0].cart && JSON.stringify(s.on) === JSON.stringify(m.on)));
    const garisendaCannon = b.stations!.find((s) => s.kind === "bombarda" && s.team === 1)!;
    const asinelliCrane = b.stations!.find((s) => s.kind === "gru" && s.team === 2)!;
    assert.ok(Math.abs(m.path[0].x - (garisendaCannon.x + garisendaCannon.width)) < 10 && m.path[0].y === garisendaCannon.y, "parte accanto alla bombarda");
    assert.ok(Math.abs(m.path[1].x + m.width - asinelliCrane.x) < 15 && asinelliCrane.y - m.path[1].y <= 60, "arriva sopra la finestra della gru");
  });
});
