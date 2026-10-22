// La gru delle postazioni (#433): pezzi del Tetris appesi, spostati, girati e lasciati cadere; i blocchi della gru restano.
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { STATION, TETRIS, TICK_RATE, WORLD } from "../constants";
import type { StageSpec, Station } from "../stages";
import type { InputState } from "../types";
import { arcadeSolids, tetrisState } from "./arcade";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { resetStations, stationSnapshot } from "./stations";

const DT = 1000 / TICK_RATE;
const FLOOR = 650;
const C = TETRIS.cellPx;
// Gru della squadra 1: il pezzo va tra x 400 e 640 (6 colonne), pende col fondo a y 300 e si posa su y 600
const crane: Station = { kind: "gru", x: 100, y: FLOOR, width: 80, team: 1, fromX: 400, toX: 640, dropY: 300, landY: 600 };

function stage(): StageSpec {
  return {
    id: "prova-gru",
    name: "Prova",
    solids: [{ x: 0, y: FLOOR, width: WORLD.width, height: 50 }],
    platforms: [],
    stations: [crane],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: FLOOR }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number, keys: Partial<InputState> = {}, who: Fighter[] = fighters) {
  for (const f of who) f.input = { ...emptyInput(), ...keys };
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
  for (const f of who) f.input = emptyInput();
}

function tap(fighters: Fighter[], ctx: PhysicsContext, key: keyof InputState, who: Fighter[]) {
  run(fighters, ctx, 1, { [key]: true }, who);
  run(fighters, ctx, 1, {}, who);
}

// 0: chi usa la gru (squadra 1), già dentro; 1: un avversario sotto il ripiano; 2: un compagno
function setup() {
  const s = stage();
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 0, canHit: (a, t) => !a.team || a.team !== t.team };
  const fighters = [[140, 1], [500, 2], [620, 1]].map(([x, team], i) => {
    const f = createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team, index: i, stocks: 3 }, s);
    f.x = x;
    f.y = FLOOR;
    f.onGround = true;
    return f;
  });
  run(fighters, ctx, 5);
  const [op] = fighters;
  tap(fighters, ctx, "light", [op]);
  assert.equal(op.station, 0, "dentro la gru");
  return { ctx, fighters, op, slot: () => ctx.stations!.slots[0] };
}

// Pende una O (quadrata) alla colonna data; l'attesa è già passata
function hang(ctx: PhysicsContext, col: number) {
  const slot = ctx.stations!.slots[0];
  slot.held = { kind: "O", col, rot: 0, repeatMs: 0 };
  slot.nextAt = 0;
}

const kept = (ctx: PhysicsContext) => ctx.arcade?.blocks.filter((b) => b.keep !== undefined) ?? [];

describe("gru (#433)", () => {
  it("entrando pende un pezzo dentro il tratto, col fondo a dropY, anche nello snapshot", () => {
    const { ctx, slot } = setup();
    assert.ok(slot().held, "un pezzo appeso");
    const snap = stationSnapshot(ctx).stations![0];
    assert.equal(snap.user, "p0");
    assert.ok(snap.piece && snap.piece.cells.length === 4);
    assert.equal(Math.max(...snap.piece.cells.map(([, y]) => y + C)), crane.dropY);
    assert.ok(snap.piece.cells.every(([x]) => x >= crane.fromX! && x + C <= crane.toX!));
  });

  it("destra e sinistra spostano il pezzo di una colonna alla volta, fermandosi ai bordi del tratto", () => {
    const { ctx, fighters, op, slot } = setup();
    hang(ctx, 12); // O: colonne 12-13 (x 480-560)
    tap(fighters, ctx, "right", [op]);
    assert.equal(slot().held!.col, 13);
    run(fighters, ctx, 3, { left: true }, [op]);
    assert.equal(slot().held!.col, 12, "un solo passo finché non scade la ripetizione");
    run(fighters, ctx, 200, { right: true }, [op]);
    assert.equal(slot().held!.col, 14, "la O occupa 14-15 (x 560-640): oltre sforerebbe il tratto");
  });

  it("attacco leggero gira il pezzo, anche con su", () => {
    const { ctx, fighters, op, slot } = setup();
    slot().held = { kind: "I", col: 12, rot: 0, repeatMs: 0 };
    tap(fighters, ctx, "light", [op]);
    assert.equal(slot().held!.rot, 1);
    tap(fighters, ctx, "up", [op]);
    assert.equal(slot().held!.rot, 2);
    assert.ok(ctx.events.some((e) => e.type === "tetris" && e.phase === "rotate"));
  });

  it("attacco pesante lo lascia cadere: si posa su landY, i blocchi restano, poi un'attesa e ne pende un altro", () => {
    const { ctx, fighters, op, slot } = setup();
    hang(ctx, 10); // O: x 400-480
    tap(fighters, ctx, "heavy", [op]);
    assert.equal(slot().held, null, "non pende più");
    assert.equal(ctx.arcade!.pieces.length, 1);
    assert.ok(ctx.arcade!.pieces[0].crane);
    assert.equal(stationSnapshot(ctx).stations![0].piece, undefined);
    run(fighters, ctx, 30);
    assert.equal(ctx.arcade!.pieces.length, 0, "posato");
    const blocks = kept(ctx);
    assert.equal(blocks.length, 4);
    assert.deepEqual(blocks.map((b) => b.y).sort(), [520, 520, 560, 560], "il fondo sta su landY (600)");
    assert.ok(blocks.every((b) => b.x >= 400 && b.x + C <= 480));
    assert.equal(slot().held, null, "attesa tra un pezzo e l'altro");
    run(fighters, ctx, Math.ceil(STATION.gruCooldownMs / DT));
    assert.ok(slot().held, "dopo gruCooldownMs ne pende un altro");
  });

  it("senza pezzo appeso, attacco pesante non fa niente", () => {
    const { ctx, fighters, op, slot } = setup();
    slot().held = null;
    slot().nextAt = Infinity;
    tap(fighters, ctx, "heavy", [op]);
    assert.equal(ctx.arcade?.pieces.length ?? 0, 0);
  });

  it("il pezzo fa male all'avversario sotto, come un pezzo lasciato cadere del Tetris, e non al compagno", () => {
    const { ctx, fighters, op } = setup();
    hang(ctx, 12); // O: x 480-560, sopra l'avversario (x 500); il compagno sta a 620, fuori
    tap(fighters, ctx, "heavy", [op]);
    run(fighters, ctx, 20);
    assert.equal(fighters[1].percent, TETRIS.dropDamage);
    assert.equal(fighters[2].percent, 0);
    assert.equal(fighters[0].percent, 0);
    const hit = ctx.events.find((e) => e.type === "hit" && e.targetId === "p1");
    assert.ok(hit && hit.type === "hit" && hit.attackerId === "p0");
  });

  it("i blocchi della gru sono solidi e non invecchiano; quelli del Tetris normale spariscono", () => {
    const { ctx, fighters, op } = setup();
    hang(ctx, 10);
    tap(fighters, ctx, "heavy", [op]);
    run(fighters, ctx, 30);
    assert.equal(arcadeSolids(ctx).length, 4);
    ctx.arcade!.blocks.push({ x: 800, y: 560, kind: "T", lifeMs: TETRIS.blockMs }); // uno qualunque, non della gru
    run(fighters, ctx, Math.ceil((TETRIS.blockMs + 500) / DT));
    assert.equal(ctx.arcade!.blocks.length, 4, "resta solo la gru");
    assert.equal(kept(ctx).length, 4);
    assert.ok(tetrisState(ctx)!.blocks.every((b) => b.keep === true));
  });

  it("al massimo gruMaxBlocks blocchi restano per gru: gli altri si posano ma poi spariscono", () => {
    const { ctx, fighters, op } = setup();
    for (const col of [10, 12, 14, 10, 12]) {
      hang(ctx, col);
      tap(fighters, ctx, "heavy", [op]);
      run(fighters, ctx, 40);
    }
    assert.equal(ctx.arcade!.blocks.length, 20, "5 pezzi da 4");
    assert.equal(kept(ctx).length, STATION.gruMaxBlocks);
    run(fighters, ctx, Math.ceil((TETRIS.blockMs + 500) / DT));
    assert.equal(ctx.arcade!.blocks.length, STATION.gruMaxBlocks, "il pezzo di troppo è sparito");
  });

  it("chi esce lascia il pezzo appeso, che un altro può usare", () => {
    const { ctx, fighters, op, slot } = setup();
    const before = slot().held;
    tap(fighters, ctx, "jump", [op]);
    assert.equal(op.station, undefined);
    assert.equal(slot().held, before, "il pezzo resta lì");
  });

  it("la rivincita azzera la gru: pezzo, attesa e blocchi", () => {
    const { ctx, fighters, op } = setup();
    hang(ctx, 10);
    tap(fighters, ctx, "heavy", [op]);
    run(fighters, ctx, 30);
    assert.equal(kept(ctx).length, 4);
    resetStations(fighters, ctx);
    ctx.arcade = undefined; // lo fa Match.reset
    assert.equal(op.station, undefined);
    run(fighters, ctx, 2);
    assert.equal(kept(ctx).length, 0);
    assert.ok(ctx.stations!.slots[0].held, "la gru riparte da capo con un pezzo nuovo");
  });
});
