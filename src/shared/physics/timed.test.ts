// Test dei pezzi a tempo e delle fasi dell'arena (#433): logica pura, si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { TICK_RATE, WORLD } from "../constants";
import { STAGES, type Hazard, type Rect, type StageSpec } from "../stages";
import { baseStage, createFighter, ledgesOf, phaseAt, phaseIndexAt, pieceOn, stageAt, stageIsTimed, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const ticksFor = (ms: number) => Math.ceil(ms / DT);
const ground: Rect = { x: 0, y: 650, width: WORLD.width, height: 50 };
const spikes: Hazard = { kind: "spuntoni", x: 400, y: 580, width: 200, height: 20, damage: 10, knockback: 500, knockbackGrowth: 6, angleDeg: 80 };

function stageWith(extra: Partial<StageSpec>): StageSpec {
  return {
    id: "prova",
    name: "Prova",
    solids: [ground],
    platforms: [],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: 600 }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
    ...extra,
  };
}

const fighter = (stage: StageSpec, id = "p0") => createFighter({ id, name: id, characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);

function setup(stage: StageSpec, at: { x: number; y: number }) {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = fighter(stage);
  f.x = at.x;
  f.y = at.y;
  return { ctx, f };
}

const run = (fs: Fighter[], ctx: PhysicsContext, ticks: number) => {
  for (let i = 0; i < ticks; i++) stepWorld(fs, DT, ctx);
};

describe("pezzi a tempo e fasi (#433)", () => {
  it("un blocco c'è solo dentro le sue finestre, e la vista si rifà solo quando cambia", () => {
    const stage = stageWith({ solids: [ground, { x: 100, y: 400, width: 200, height: 40, on: [[0, 1000], [3000, 4000]] }] });
    const timed = stage.solids[1];
    assert.ok(pieceOn(timed, 0) && pieceOn(timed, 999) && !pieceOn(timed, 1000));
    assert.ok(pieceOn(timed, 3500) && !pieceOn(timed, 5000) && pieceOn(ground, 1e9));
    const early = stageAt(stage, 500);
    assert.equal(early.solids.length, 2);
    assert.equal(stageAt(stage, 900), early, "niente è cambiato: la stessa vista");
    const later = stageAt(stage, 1500);
    assert.deepEqual(later.solids, [ground]);
    assert.equal(stageAt(later, 3200).solids.length, 2, "anche da una vista si torna all'arena di partenza");
    assert.equal(baseStage(later), stage);
  });

  it("chi sta su una piattaforma che sparisce cade", () => {
    const stage = stageWith({ platforms: [{ x: 400, y: 450, width: 300, on: [[0, 500]] }] });
    const { ctx, f } = setup(stage, { x: 550, y: 450 });
    run([f], ctx, ticksFor(300));
    assert.ok(f.onGround && f.y === 450, "ci sta sopra finché c'è");
    run([f], ctx, ticksFor(400));
    assert.ok(f.y > 450 && ctx.stage.platforms.length === 0, "sparita: si cade");
  });

  it("un blocco che sparisce lascia andare chi è appeso al suo spigolo, gli altri restano al loro", () => {
    const block = { x: 500, y: 400, width: 200, height: 40, on: [[0, 500]] as [number, number][] };
    const stage = stageWith({ solids: [block, ground] }); // il blocco a tempo prima: sparendo cambia gli indici
    const ctx: PhysicsContext = { stage: stageAt(stage, 0), events: [], timeMs: 480 };
    const f = fighter(stage);
    const other = fighter(stage, "p1");
    for (const [who, l] of [[f, { x: block.x, y: block.y }], [other, { x: ground.x + ground.width, y: ground.y }]] as const) {
      who.ledge = "hang";
      who.ledgeIndex = ledgesOf(ctx.stage).findIndex((e) => e.x === l.x && e.y === l.y);
      who.x = l.x;
      who.y = l.y + 40;
    }
    run([f, other], ctx, 2);
    assert.equal(f.ledge, null, "il blocco non c'è più");
    assert.ok(other.ledge, "chi è appeso al pavimento resta");
    assert.deepEqual(ledgesOf(ctx.stage)[other.ledgeIndex], { x: ground.x + ground.width, y: ground.y, side: 1 }, "allo stesso spigolo anche con gli indici cambiati");
  });

  it("una trappola o un getto fuori dalle finestre non fanno niente", () => {
    const stage = stageWith({ hazards: [{ ...spikes, on: [[1000, 2000]] }] });
    const { ctx, f } = setup(stage, { x: 500, y: 650 });
    run([f], ctx, ticksFor(400));
    assert.equal(f.percent, 0, "spenta prima della sua finestra");
    ctx.timeMs = 1000;
    run([f], ctx, 2);
    assert.equal(f.percent, spikes.damage, "accesa dentro");
    const jet = { x: 400, y: 650, width: 200, height: 300, speed: 900, periodMs: 1000, warnMs: 0, activeMs: 1000 };
    const wet = setup(stageWith({ jets: [{ ...jet, on: [[5000, 6000]] }] }), { x: 500, y: 650 });
    run([wet.f], wet.ctx, 5);
    assert.ok(wet.f.vy >= 0 && wet.f.onGround, "il getto a tempo non spinge fuori dalla finestra");
    const always = setup(stageWith({ jets: [jet] }), { x: 500, y: 650 });
    run([always.f], always.ctx, 2);
    assert.ok(always.f.vy < 0, "senza finestre spinge come sempre");
  });

  it("la fase attiva cambia zone di espulsione e punto di ritorno", () => {
    const phases = [
      { id: "piazza", name: "Piazza", startMs: 0 },
      { id: "torre", name: "Torre", startMs: 1000, blastZone: { left: 0, right: 1000, top: -500, bottom: 1200 }, respawn: { x: 300, y: 50 } },
    ];
    const stage = stageWith({ phases });
    assert.equal(phaseIndexAt(stage, 999), 0);
    assert.equal(phaseAt(stage, 1000)?.id, "torre");
    assert.equal(phaseIndexAt(stageWith({}), 5000), -1);
    const { ctx, f } = setup(stage, { x: 1100, y: 650 }); // fuori dalla zona della torre, dentro quella dell'arena
    run([f], ctx, ticksFor(900));
    assert.ok(!ctx.events.some((e) => e.type === "ko"), "nella prima fase vale la zona dell'arena");
    run([f], ctx, ticksFor(200));
    assert.ok(ctx.events.some((e) => e.type === "ko"), "nella torre si esce prima");
    assert.deepEqual(ctx.stage.blastZone, phases[1].blastZone);
    while (f.respawning) stepWorld([f], DT, ctx);
    assert.equal(f.x, 300, "si ricompare dove dice la fase");
  });

  it("le arene che non cambiano restano le stesse, oggetto per oggetto", () => {
    for (const stage of Object.values(STAGES)) {
      if (stageIsTimed(stage)) continue;
      for (const t of [0, 1234, 60000]) assert.equal(stageAt(stage, t), stage, stage.id);
      const { ctx, f } = setup(stage, stage.spawns[0]);
      run([f], ctx, 3);
      assert.equal(ctx.stage, stage, stage.id);
    }
  });
});
