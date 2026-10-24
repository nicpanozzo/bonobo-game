import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, PACMAN, TETRIS, TICK_RATE, WORLD } from "../constants";
import { ITEMS, DROPPABLE_ITEMS } from "../items";
import type { StageSpec } from "../stages";
import { emptyInput, createFighter, stepWorld, type PhysicsContext } from "./index";
import { pacmanSpeedMul, pelletsFor, pieceCells, startArcade, tetrisState } from "./arcade";
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
// Il caso che fa uscire la O, la forma quadrata: è la seconda delle sette
const KINDS_O = 1 / 7 + 0.01;
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

  it("chi gioca resta fermo e intoccabile, e compare un pezzo sopra l'avversario", () => {
    const { ctx, player, list } = setup();
    const x = player.x;
    player.input = { ...emptyInput(), right: true };
    steps(10, list, ctx);
    assert.equal(player.x, x, "fermo");
    assert.ok(player.invulnerable);
    assert.equal(ctx.arcade!.pieces.length, 1);
    assert.equal(piece(ctx).ownerId, "p0");
    const other = list[1];
    assert.ok(Math.abs(piece(ctx).col * C - other.x) < 4 * C, `sopra l'avversario (colonna ${piece(ctx).col}, x ${other.x})`);
    assert.equal(tetrisState(ctx)!.pieces[0].fall, FLOOR - (piece(ctx).y + C * (1 + Math.max(...pieceCells(piece(ctx).kind, 0, 0, 0).map(([, y]) => y / C)))), "quanto manca alla posa, per l'ombra");
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
    steps(Math.ceil((TETRIS.nextPieceMs / 1000) * TICK_RATE) + 1, list, ctx);
    assert.equal(ctx.arcade!.pieces.length, 1, "il pezzo nuovo, un attimo dopo");
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
    assert.ok(hit && hit.type === "hit" && hit.itemKind === "tetris" && hit.damage === TETRIS.dropDamage, "colpito dal pezzo, più forte perché fatto cadere");
    assert.equal(ctx.events.filter((e) => e.type === "hit").length, 1, "una volta sola");
  });

  it("senza K il pezzo fa il danno normale", () => {
    const { ctx, other, list } = setup();
    steps(1, list, ctx);
    other.x = piece(ctx).col * C + C / 2;
    steps(Math.ceil(((FLOOR + 200) / TETRIS.fallPxS) * TICK_RATE), list, ctx);
    const hit = ctx.events.find((e) => e.type === "hit" && e.targetId === "p1");
    assert.ok(hit && hit.type === "hit" && hit.damage === TETRIS.damage);
  });

  it("una fila di blocchi fa una riga: esplode e chi ci sta sopra vola in alto", () => {
    const { ctx, player, other, list } = setup();
    // Cinque blocchi già posati in fila; il pezzo O ne aggiunge due accanto e completa la riga
    const blocks = [0, 1, 2, 3, 4].map((i) => ({ x: 400 + i * C, y: FLOOR - C, kind: "I", lifeMs: 5000 }));
    ctx.arcade = { pieces: [], blocks, nextId: 1, random: () => KINDS_O };
    other.x = 460;
    other.y = FLOOR - C;
    steps(1, list, ctx);
    const p = piece(ctx);
    p.col = 600 / C;
    player.input = { ...emptyInput(), heavy: true };
    steps(Math.ceil(((FLOOR + 200) / TETRIS.dropPxS) * TICK_RATE) + 2, list, ctx);
    assert.ok(ctx.events.some((e) => e.type === "tetris" && e.phase === "line" && e.width === 7 * C), "la riga esplode");
    assert.ok(!ctx.arcade!.blocks.some((b) => b.y === FLOOR - C), "i blocchi della riga spariscono");
    const hit = ctx.events.find((e) => e.type === "hit" && e.targetId === "p1");
    assert.ok(hit && hit.type === "hit" && hit.damage === TETRIS.lineDamage, "chi ci stava sopra è preso");
    assert.ok(other.vy < 0, "vola in alto");
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

describe("power-up Pac-Man (#427)", () => {
  function pacSetup() {
    const t = setup();
    t.player.powerup = "pacman";
    t.player.powerupMs = PACMAN.ms;
    t.player.facing = 1;
    startArcade(t.player);
    t.player.y = 300;
    t.other.x = 1100;
    return t;
  }

  it("è un oggetto da consumare che cade dal cielo", () => {
    assert.deepEqual(ITEMS.pacman.consume, { powerup: "pacman", ms: PACMAN.ms });
    assert.ok(DROPPABLE_ITEMS.includes("pacman"));
  });

  it("va dritto senza gravità e intoccabile, cambia direzione con una freccia appena premuta", () => {
    const { ctx, player, list } = pacSetup();
    const x = player.x;
    steps(TICK_RATE / 2, list, ctx);
    assert.ok(Math.abs(player.x - (x + PACMAN.speedPxS / 2)) < 2, `dritto a destra (x = ${player.x})`);
    assert.equal(player.y, 300, "non cade");
    assert.ok(player.invulnerable);
    player.input = { ...emptyInput(), up: true };
    steps(TICK_RATE / 4, list, ctx);
    assert.ok(player.y < 300 - PACMAN.speedPxS / 4 + 10, "su");
    player.input = emptyInput();
    const y = player.y;
    steps(3, list, ctx);
    assert.ok(player.y < y, "lasciata la freccia continua per la sua strada");
  });

  it("passa attraverso il pavimento ed esce da un lato per rientrare dall'altro", () => {
    const { ctx, player, list } = pacSetup();
    player.pacDir = { x: 0, y: 1 };
    steps(Math.round(TICK_RATE * 1.5), list, ctx); // 570 pixel in giù: oltre il bordo basso
    assert.ok(player.y >= 0 && player.y < WORLD.height, `dentro lo schermo (y = ${player.y})`);
    assert.ok(player.y < 300, "è rientrato dall'alto dopo aver attraversato il pavimento");
    player.pacDir = { x: -1, y: 0 };
    player.x = 10;
    steps(3, list, ctx);
    assert.ok(player.x > WORLD.width - 30, `rientrato da destra (x = ${player.x})`);
    assert.ok(!ctx.events.some((e) => e.type === "ko"), "niente KO");
  });

  it("nelle arene più larghe dello schermo rientra dai bordi dell'arena, non dello schermo (Padova)", () => {
    const { ctx, player, list } = pacSetup();
    ctx.stage = { ...ctx.stage, width: 1920 };
    player.x = WORLD.width - 20;
    steps(6, list, ctx);
    assert.ok(player.x > WORLD.width, `continua oltre il primo schermo (x = ${player.x})`);
    player.x = 1910;
    steps(3, list, ctx);
    assert.ok(player.x < 30, `rientrato da sinistra dopo il bordo dell'arena (x = ${player.x})`);
  });

  it("ogni pallina mangiata lo fa andare più veloce, fino a un tetto, e riparte da zero alla forma dopo", () => {
    const { ctx, player, list } = pacSetup();
    const pellets = pelletsFor(ctx.stage);
    const first = pellets[0];
    player.pacDir = { x: 0, y: 0 };
    player.x = first.x;
    player.y = first.y + FIGHTER.height / 2;
    steps(1, list, ctx);
    assert.ok((player.pacPellets ?? 0) >= 1, "mangiata");
    assert.ok(!ctx.arcade?.pellets?.some((q) => q.x === first.x && q.y === first.y), "sparita");
    assert.ok(pacmanSpeedMul(player) > 1);
    player.pacPellets = 10_000;
    assert.equal(pacmanSpeedMul(player), PACMAN.maxSpeedMul);
    player.pacDir = { x: 1, y: 0 };
    const x = player.x;
    steps(1, list, ctx);
    assert.ok(player.x - x > (PACMAN.speedPxS / TICK_RATE) * 1.5, "va più veloce");
    startArcade(player);
    assert.equal(pacmanSpeedMul(player), 1);
  });

  it("mangia chi tocca, una volta ogni tanto", () => {
    const { ctx, player, other, list } = pacSetup();
    player.pacDir = { x: 0, y: 0 };
    player.x = 800;
    other.x = 800;
    other.y = 300 + FIGHTER.height / 2;
    steps(1, list, ctx);
    const hit = ctx.events.find((e) => e.type === "hit" && e.targetId === "p1");
    assert.ok(hit && hit.type === "hit" && hit.itemKind === "pacman" && hit.attackerId === "p0", "mangiato");
    assert.equal(other.percent, PACMAN.damage);
    other.x = 800;
    other.y = 300 + FIGHTER.height / 2;
    other.hitstunTimer = 0;
    steps(1, list, ctx);
    assert.equal(ctx.events.filter((e) => e.type === "hit").length, 1, "non subito di nuovo");
  });

  it("finito il tempo si torna normali, fermi e coi salti", () => {
    const { ctx, player } = pacSetup();
    player.powerupMs = 1;
    player.jumpsLeft = 0;
    tickPowerup(player, DT, ctx);
    assert.equal(player.powerup, null);
    assert.equal(player.vx, 0);
    assert.equal(player.jumpsLeft, FIGHTER.maxJumps);
  });
});
