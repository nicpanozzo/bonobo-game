// Test di ascensori e trappole (#14): logica pura, si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { HAZARD, TICK_RATE, WORLD } from "../constants";
import type { Hazard, MovingPlatform, StageSpec } from "../stages";
import { getStage } from "../stages";
import { createFighter, hazardActive, moverPosition, stepWorld, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;

const elevator: MovingPlatform = { width: 200, path: [{ x: 500, y: 600 }, { x: 500, y: 300 }], periodMs: 4000, pauseMs: 1000 };
const shuttle: MovingPlatform = { width: 200, path: [{ x: 300, y: 500 }, { x: 700, y: 500 }], periodMs: 4000 };
const spikes: Hazard = { kind: "spuntoni", x: 400, y: 580, width: 200, height: 20, damage: 10, knockback: 500, knockbackGrowth: 6, angleDeg: 80 };

function stageWith(extra: Partial<StageSpec>): StageSpec {
  return {
    id: "prova",
    name: "Prova",
    solids: [{ x: 0, y: 650, width: WORLD.width, height: 50 }],
    platforms: [],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: 600 }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
    ...extra,
  };
}

function setup(stage: StageSpec, at: { x: number; y: number }) {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  f.x = at.x;
  f.y = at.y;
  return { ctx, f };
}

const run = (f: ReturnType<typeof createFighter>, ctx: PhysicsContext, ticks: number) => {
  for (let i = 0; i < ticks; i++) stepWorld([f], DT, ctx);
};

describe("piattaforme mobili", () => {
  it("si ferma ai piani e torna indietro", () => {
    assert.deepEqual(moverPosition(elevator, 0), { x: 500, y: 600 });
    assert.deepEqual(moverPosition(elevator, 900), { x: 500, y: 600 }); // ancora in sosta
    assert.equal(moverPosition(elevator, 1500).y, 450); // a metà della salita (1 s di viaggio per tratto)
    assert.deepEqual(moverPosition(elevator, 2500), { x: 500, y: 300 }); // sosta in cima
    assert.equal(moverPosition(elevator, 3500).y, 450); // a metà della discesa
    assert.deepEqual(moverPosition(elevator, 4000), moverPosition(elevator, 0)); // il giro ricomincia
  });

  it("in giro torna dritto al primo punto", () => {
    const loop: MovingPlatform = { width: 50, path: [{ x: 0, y: 0 }, { x: 100, y: 0 }, { x: 100, y: 100 }], periodMs: 3000, loop: true };
    const p = moverPosition(loop, 2500); // sull'ultimo tratto, dalla terza al primo punto
    assert.ok(p.x > 0 && p.x < 100 && p.y > 0 && p.y < 100);
  });

  it("l'ascensore porta su chi ci sta sopra", () => {
    const { ctx, f } = setup(stageWith({ movers: [elevator] }), { x: 600, y: 600 });
    run(f, ctx, 3);
    assert.equal(f.riding, 0);
    run(f, ctx, Math.round(2000 / DT)); // fino alla sosta in cima
    assert.ok(f.onGround, "resta a terra sull'ascensore");
    assert.ok(Math.abs(f.y - 300) < 1, `arriva in cima (y = ${f.y})`);
  });

  it("la navetta porta di lato chi ci sta sopra", () => {
    const { ctx, f } = setup(stageWith({ movers: [shuttle] }), { x: 400, y: 500 });
    run(f, ctx, Math.round(1000 / DT));
    assert.ok(f.onGround);
    assert.ok(f.x > 550 && f.x < 650, `si è spostato con la navetta (x = ${f.x})`);
  });

  it("si atterra su un ascensore che sale incontro", () => {
    const fast: MovingPlatform = { width: 200, path: [{ x: 500, y: 600 }, { x: 500, y: 100 }], periodMs: 1000 };
    const { ctx, f } = setup(stageWith({ movers: [fast] }), { x: 600, y: 200 });
    f.onGround = false;
    run(f, ctx, Math.round(400 / DT));
    assert.equal(f.riding, 0, "è sopra l'ascensore, non caduto attraverso");
  });

  it("con giù si scende dall'ascensore", () => {
    const { ctx, f } = setup(stageWith({ movers: [elevator] }), { x: 600, y: 600 });
    run(f, ctx, Math.round(1500 / DT)); // a metà salita
    f.input = { ...f.input, down: true };
    run(f, ctx, Math.round(800 / DT));
    assert.equal(f.y, 650, "è sceso fino al pavimento");
  });
});

describe("trappole", () => {
  it("le trappole a ciclo si accendono e si spengono", () => {
    const fire = { ...spikes, periodMs: 4000, activeMs: 1000 };
    assert.equal(hazardActive(spikes, 123456), true);
    assert.equal(hazardActive(fire, 500), true);
    assert.equal(hazardActive(fire, 1500), false);
    assert.equal(hazardActive(fire, 4200), true);
  });

  it("gli spuntoni tolgono percentuale e lanciano via, una volta sola", () => {
    const { ctx, f } = setup(stageWith({ spawns: [{ x: 500, y: 650 }], hazards: [spikes] }), { x: 500, y: 650 });
    f.lastHitById = "spintone";
    run(f, ctx, 1);
    assert.equal(f.percent, 10);
    const ev = ctx.events.filter((e) => e.type === "hazard");
    assert.equal(ev.length, 1);
    run(f, ctx, 12);
    assert.ok(f.y < 620, `è stato lanciato in alto (y = ${f.y})`);
    run(f, ctx, Math.round(HAZARD.cooldownMs / DT) - 20);
    assert.equal(f.percent, 10, "niente colpi a raffica");
    assert.equal(f.lastHitById, "spintone", "il KO resta a chi l'ha spinto");
  });

  it("una trappola spenta non fa niente", () => {
    const off = { ...spikes, periodMs: 4000, activeMs: 1000, offsetMs: 2000 };
    const { ctx, f } = setup(stageWith({ hazards: [off] }), { x: 500, y: 650 });
    run(f, ctx, 30);
    assert.equal(f.percent, 0);
  });

  it("La Fabbrica ha ascensori e trappole", () => {
    const stage = getStage("fabbrica");
    assert.ok((stage.movers?.length ?? 0) > 0 && (stage.hazards?.length ?? 0) > 0);
  });
});
