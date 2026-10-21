import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { TETRIS, TICK_RATE, WORLD } from "../constants";
import { ITEMS, DROPPABLE_ITEMS } from "../items";
import type { StageSpec } from "../stages";
import { emptyInput, createFighter, stepWorld, type PhysicsContext } from "./index";
import { pieceCells, tetrisState } from "./arcade";
import { tickPowerup } from "./items";

const DT = 1000 / TICK_RATE;
const C = TETRIS.cellPx;
const FLOOR = 600;

function stage(): StageSpec {
  return {
    id: "prova",
    name: "Prova",
    solids: [{ x: 0, y: FLOOR, width: WORLD.width, height: 100 }],
    platforms: [],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 200, y: FLOOR }, { x: 800, y: FLOOR }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
}

function setup() {
  const s = stage();
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 0 };
  const player = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, s);
  const other = createFighter({ id: "p1", name: "P1", characterId: "default", color: 0, team: 1, index: 1, stocks: 3 }, s);
  player.powerup = "tetris";
  player.powerupMs = TETRIS.ms;
  return { ctx, player, other, list: [player, other] };
}

const steps = (n: number, list: ReturnType<typeof setup>["list"], ctx: PhysicsContext) => {
  for (let i = 0; i < n; i++) stepWorld(list, DT, ctx);
};
const piece = (ctx: PhysicsContext) => ctx.arcade!.pieces.find((p) => !p.drop)!;

describe("power-up Tetris (#427)", () => {
  it("è un oggetto da consumare che cade dal cielo", () => {
    assert.deepEqual(ITEMS.tetris.consume, { powerup: "tetris", ms: TETRIS.ms });
    assert.ok(DROPPABLE_ITEMS.includes("tetris"));
  });

  it("le forme girano attorno al quadretto centrale e la O non gira", () => {
    assert.deepEqual(pieceCells("I", 5, 0, 0), [[4 * C, 0], [5 * C, 0], [6 * C, 0], [7 * C, 0]]);
    assert.deepEqual(pieceCells("I", 5, 0, 1), [[5 * C, -C], [5 * C, 0], [5 * C, C], [5 * C, 2 * C]]);
    assert.deepEqual(pieceCells("O", 5, 0, 3), pieceCells("O", 5, 0, 0));
  });

  it("chi gioca resta fermo e intoccabile, e compare un pezzo sopra di lui", () => {
    const { ctx, player, list } = setup();
    const x = player.x;
    player.input = { ...emptyInput(), right: true };
    steps(10, list, ctx);
    assert.equal(player.x, x, "fermo");
    assert.ok(player.invulnerable);
    assert.equal(ctx.arcade!.pieces.length, 1);
    assert.equal(piece(ctx).ownerId, "p0");
    assert.ok(Math.abs(piece(ctx).col * C - player.x) < 4 * C, "sopra di lui");
  });

  it("destra sposta di una colonna, su ruota, la pressione vale una volta sola", () => {
    const { ctx, player, list } = setup();
    steps(1, list, ctx);
    const col = piece(ctx).col;
    player.input = { ...emptyInput(), right: true };
    steps(1, list, ctx);
    assert.equal(piece(ctx).col, col + 1);
    player.input = emptyInput();
    steps(1, list, ctx);
    player.input = { ...emptyInput(), up: true };
    steps(5, list, ctx);
    assert.equal(piece(ctx).rot, 1, "un quarto di giro solo");
    assert.ok(ctx.events.some((e) => e.type === "tetris" && e.phase === "rotate"));
  });

  it("il pezzo cade, si posa sul pavimento e diventa blocchi solidi; ne compare un altro", () => {
    const { ctx, player, list } = setup();
    player.input = { ...emptyInput(), down: true };
    steps(Math.ceil(((FLOOR + 200) / TETRIS.softPxS) * TICK_RATE) + 2, list, ctx);
    const blocks = ctx.arcade!.blocks;
    assert.equal(blocks.length, 4, "quattro quadretti posati");
    assert.equal(Math.max(...blocks.map((b) => b.y + C)), FLOOR, "appoggiati al pavimento");
    assert.ok(ctx.events.some((e) => e.type === "tetris" && e.phase === "land"));
    assert.equal(ctx.arcade!.pieces.length, 1, "il pezzo nuovo");
    assert.equal(tetrisState(ctx)!.blocks.length, 4, "nello snapshot");
  });

  it("su un blocco posato ci si sta sopra", () => {
    const { ctx, other, list } = setup();
    ctx.arcade = { pieces: [], blocks: [{ x: 760, y: FLOOR - C, kind: "O", lifeMs: 5000 }, { x: 800, y: FLOOR - C, kind: "O", lifeMs: 5000 }], nextId: 1, random: () => 0 };
    other.x = 800;
    other.y = FLOOR - 200;
    other.onGround = false;
    steps(60, list, ctx);
    assert.ok(other.onGround && other.y === FLOOR - C, `in piedi sul blocco (y = ${other.y})`);
  });

  it("K lo fa cadere di colpo e chi è sotto vola via", () => {
    const { ctx, player, other, list } = setup();
    steps(1, list, ctx);
    other.x = piece(ctx).col * C + C / 2;
    player.input = { ...emptyInput(), heavy: true };
    steps(Math.ceil(((FLOOR + 200) / TETRIS.dropPxS) * TICK_RATE) + 2, list, ctx);
    const hit = ctx.events.find((e) => e.type === "hit" && e.targetId === "p1");
    assert.ok(hit && hit.type === "hit" && hit.itemKind === "tetris" && hit.damage === TETRIS.damage, "colpito dal pezzo");
    assert.equal(ctx.events.filter((e) => e.type === "hit").length, 1, "una volta sola");
  });

  it("finito il tempo si torna in partita, un attimo intoccabili, e i blocchi poi spariscono", () => {
    const { ctx, player, list } = setup();
    player.powerupMs = 1;
    tickPowerup(player, DT, ctx);
    assert.equal(player.powerup, null);
    assert.ok(player.invulnerableTimer >= TETRIS.returnInvulnerableMs);
    ctx.arcade = { pieces: [], blocks: [{ x: 0, y: 0, kind: "I", lifeMs: 100 }], nextId: 1, random: () => 0 };
    steps(10, list, ctx);
    assert.equal(tetrisState(ctx), undefined);
  });
});
