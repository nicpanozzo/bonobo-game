// L'ombrellone (#433): uno scudo sopra la torre che si sposta da una postazione e ferma le palle delle altre squadre.
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
const SHIELD_Y = 450; // la palla a 45 gradi ci passa salendo verso x 320 e scendendo verso x 890

// 0: la bombarda della squadra 1, che spara a destra; 1: l'ombrellone della squadra 2, con lo scudo tra x 300 e 1100
function stage(): StageSpec {
  return {
    id: "prova-ombrellone",
    name: "Prova",
    solids: [{ x: 0, y: FLOOR, width: WORLD.width, height: 50 }],
    platforms: [],
    stations: [
      { kind: "bombarda", x: 50, y: FLOOR, width: 80, team: 1, dir: 1, aimMinDeg: 45, aimMaxDeg: 45, ammoMax: 4 },
      { kind: "ombrellone", x: 1000, y: FLOOR, width: 80, team: 2, fromX: 300, toX: 1100, shieldY: SHIELD_Y },
    ],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: FLOOR }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
}

function setup(...who: [x: number, team: number][]) {
  const s = stage();
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 0, canHit: (a, t) => !a.team || a.team !== t.team };
  const fighters = who.map(([x, team], i) => {
    const f = createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team, index: i, stocks: 3 }, s);
    f.x = x;
    f.y = FLOOR;
    f.onGround = true;
    return f;
  });
  run(fighters, ctx, 5);
  return { ctx, fighters };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number, keys: Partial<InputState> = {}, who: Fighter[] = fighters) {
  for (const f of who) f.input = { ...emptyInput(), ...keys };
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
  for (const f of who) f.input = emptyInput();
}

const tap = (fighters: Fighter[], ctx: PhysicsContext, f: Fighter) => {
  run(fighters, ctx, 1, { light: true }, [f]);
  run(fighters, ctx, 1, {}, [f]);
};
const shield = (ctx: PhysicsContext) => ctx.stations!.slots[1].shield;

// Spara una palla dalla bombarda e torna il punto più alto e più a destra a cui è arrivata, e se si è fermata in aria
function fire(fighters: Fighter[], ctx: PhysicsContext, gunner: Fighter) {
  tap(fighters, ctx, gunner);
  let maxX = 0;
  let stoppedAt: { x: number; y: number } | null = null;
  for (let i = 0; i < 3 * TICK_RATE && ctx.stations!.balls.length + (maxX === 0 ? 1 : 0) > 0; i++) {
    const before = ctx.stations!.balls[0];
    stepWorld(fighters, DT, ctx);
    if (before) maxX = Math.max(maxX, before.x);
    if (before && ctx.stations!.balls.length === 0) stoppedAt = { x: before.x, y: before.y };
  }
  return { maxX, stoppedAt };
}

describe("l'ombrellone (#433)", () => {
  it("lo scudo parte in mezzo e si sposta con destra e sinistra, fino ai capi del tratto", () => {
    const { ctx, fighters } = setup([1040, 2]);
    const [f] = fighters;
    assert.equal(shield(ctx), (300 + 1100 - STATION.umbrellaWidthPx) / 2);
    tap(fighters, ctx, f);
    assert.equal(f.station, 1);
    const x0 = shield(ctx);
    run(fighters, ctx, TICK_RATE / 2, { left: true }, [f]);
    assert.ok(Math.abs(x0 - shield(ctx) - STATION.umbrellaSpeedPxS / 2) < 10, "in mezzo secondo va di metà velocità");
    run(fighters, ctx, 5 * TICK_RATE, { left: true }, [f]);
    assert.equal(shield(ctx), 300);
    run(fighters, ctx, 5 * TICK_RATE, { right: true }, [f]);
    assert.equal(shield(ctx), 1100 - STATION.umbrellaWidthPx);
    assert.equal(stationSnapshot(ctx).stations![1].shield, 1100 - STATION.umbrellaWidthPx);
  });

  it("ferma le palle delle altre squadre dove sta lo scudo, anche senza nessuno all'ombrellone", () => {
    const { ctx, fighters } = setup([90, 1]);
    const [gunner] = fighters;
    tap(fighters, ctx, gunner); // entra
    const free = fire(fighters, ctx, gunner);
    assert.equal(free.stoppedAt === null || free.stoppedAt.y >= FLOOR - 40, true, "lo scudo in mezzo non è sulla strada di questa palla");
    // lo scudo dove passa la palla: sposta il suo bordo sinistro sotto l'arco, all'altezza dello scudo
    ctx.stations!.slots[1].shield = 300;
    const blocked = fire(fighters, ctx, gunner);
    assert.ok(blocked.stoppedAt && Math.abs(blocked.stoppedAt.y - SHIELD_Y) < 60, `si ferma sullo scudo (${JSON.stringify(blocked.stoppedAt)})`);
  });

  it("a Bologna uno per torre, con lo scudo sopra la cima dove arrivano le palle nemiche", () => {
    const list = STAGES.bologna.stations!.filter((s) => s.kind === "ombrellone");
    assert.deepEqual(list.map((s) => s.team), [1, 2]);
    const [g, a] = list;
    assert.ok(g.fromX! <= 400 && g.toX! >= 1000 && g.shieldY! < 1180, "sopra la cima della Garisenda");
    assert.ok(a.fromX! <= 1300 && a.toX! >= 1700 && a.shieldY! < 980, "sopra la cima dell'Asinelli");
  });
});
