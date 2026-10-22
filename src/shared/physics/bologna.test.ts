// Bologna (#433): postazioni delle torri e premio dei ponteggi. Logica pura, si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BOLOGNA, STATION, TICK_RATE } from "../constants";
import { reachable, timedReachProblems } from "../stageCheck";
import { STAGES, type Station } from "../stages";
import { createFighter, emptyInput, pieceOn, stageAt, stepWorld, type PhysicsContext } from "./index";
import { barrel, freezePrize, prizeLeader, resetStations, stationSnapshot } from "./stations";

const bologna = STAGES.bologna;
const DT = 1000 / TICK_RATE;

// Pezzi di ogni torre (indici in platforms: Garisenda 4-11, Asinelli 12-19) e la sua base
const towers = {
  garisenda: { platforms: bologna.platforms.slice(4, 12), base: bologna.solids[1] },
  asinelli: { platforms: bologna.platforms.slice(12, 20), base: bologna.solids[2] },
};
const surfaceY = (p: { x: number; y: number; y2?: number; width: number }, x: number) => (p.y2 === undefined ? p.y : p.y + ((p.y2 - p.y) * (x - p.x)) / p.width);

// Dove arriva una palla sparata a `aim` gradi (stessa integrazione di stepBalls): la prima superficie della torre
// avversaria che attraversa scendendo o la sua base; hit = false se prima tocca la piazza
function landing(s: Station, aim: number, enemy: typeof towers.garisenda): { x: number; y: number; hit: boolean } {
  const b = barrel(s, aim);
  let x = b.x + b.dx * STATION.barrelPx;
  let y = b.y + b.dy * STATION.barrelPx;
  const vx = b.dx * s.ballSpeedPxS!;
  let vy = b.dy * s.ballSpeedPxS!;
  for (let i = 0; i < 20 * TICK_RATE; i++) {
    const prevY = y;
    vy += (STATION.ballGravityPxS2 * DT) / 1000;
    x += (vx * DT) / 1000;
    y += (vy * DT) / 1000;
    const r = enemy.base;
    if (x >= r.x && x <= r.x + r.width && y >= r.y) return { x, y, hit: true };
    if (vy > 0) {
      for (const p of enemy.platforms) {
        if (x >= p.x && x <= p.x + p.width && prevY <= surfaceY(p, x) && y >= surfaceY(p, x)) return { x, y, hit: true };
      }
    }
    if (y > bologna.solids[0].y) return { x, y, hit: false };
  }
  return { x, y, hit: false };
}

const [garisendaCannon, garisendaAmmo, asinelliCannon, asinelliAmmo] = bologna.stations!;
const ponteggi = bologna.platforms.filter((p) => p.forLeader !== undefined);
const inBrawl = BOLOGNA.brawlMs + 1000;
const newCtx = (timeMs: number): PhysicsContext => ({ stage: bologna, events: [], timeMs });
const prizePieces = (ctx: PhysicsContext) => ctx.stage.platforms.filter((p) => p.forLeader !== undefined).map((p) => p.forLeader);

describe("Bologna: postazioni (#433)", () => {
  it("una bombarda per torre sulla cima, munizioni alla base, alla squadra giusta", () => {
    assert.deepEqual(bologna.stations!.map((s) => [s.kind, s.team]), [["bombarda", 1], ["munizioni", 1], ["bombarda", 2], ["munizioni", 2]]);
    assert.equal(garisendaAmmo.feeds, 0);
    assert.equal(asinelliAmmo.feeds, 2);
    assert.equal(garisendaCannon.dir, 1);
    assert.equal(asinelliCannon.dir, -1);
    for (const s of [garisendaCannon, asinelliCannon]) assert.ok(s.autoAmmoMs, "senza casse l'1 contro 1 spara lo stesso");
  });

  it("le palle di ogni bombarda, a ogni mira possibile, cadono sulla torre avversaria", () => {
    for (const [cannon, enemy, range] of [[garisendaCannon, towers.asinelli, [1300, 1700]], [asinelliCannon, towers.garisenda, [400, 1000]]] as const) {
      for (let aim = cannon.aimMinDeg!; aim <= cannon.aimMaxDeg!; aim++) {
        const l = landing(cannon, aim, enemy);
        assert.ok(l.hit && l.x >= range[0] && l.x <= range[1], `mira ${aim}: cade a ${Math.round(l.x)},${Math.round(l.y)}`);
      }
    }
  });

  it("le postazioni ci sono solo nelle loro finestre", () => {
    for (const s of [garisendaCannon, garisendaAmmo]) {
      assert.ok(!pieceOn(s, BOLOGNA.towersMs - 1) && pieceOn(s, BOLOGNA.towersMs) && pieceOn(s, BOLOGNA.collapseMs - 1) && !pieceOn(s, BOLOGNA.collapseMs));
    }
    for (const s of [asinelliCannon, asinelliAmmo]) {
      assert.ok(!pieceOn(s, BOLOGNA.towersMs - 1) && pieceOn(s, BOLOGNA.towersMs) && pieceOn(s, BOLOGNA.brawlMs - 1) && !pieceOn(s, BOLOGNA.brawlMs));
    }
  });

  it("si entra nella bombarda in finestra, e al crollo si viene buttati fuori", () => {
    const ctx = newCtx(BOLOGNA.towersMs + 1000);
    const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 1, index: 0, stocks: 3 }, bologna);
    f.x = garisendaCannon.x + 40;
    f.y = garisendaCannon.y;
    f.onGround = true;
    stepWorld([f], DT, ctx);
    f.input = { ...emptyInput(), light: true };
    stepWorld([f], DT, ctx);
    f.input = emptyInput();
    assert.equal(f.station, 0, "entra");
    ctx.timeMs = BOLOGNA.collapseMs - 50;
    stepWorld([f], DT, ctx);
    assert.equal(f.station, 0, "ancora dentro");
    for (let i = 0; i < 6; i++) stepWorld([f], DT, ctx);
    assert.equal(f.station, undefined, "al crollo esce");
  });
});

describe("Bologna: il premio dei ponteggi (#433)", () => {
  it("due ponteggi per squadra, in fondo all'elenco, solo nella zuffa", () => {
    assert.deepEqual(ponteggi.map((p) => p.forLeader), [1, 1, 2, 2]);
    assert.ok(bologna.platforms.slice(-4).every((p) => p.forLeader !== undefined), "in fondo: gli indici di art.pieces non cambiano");
    assert.equal(bologna.prizeAtMs, BOLOGNA.collapseMs);
    for (const p of ponteggi) assert.deepEqual(p.on, [[BOLOGNA.brawlMs, BOLOGNA.horizonMs]]);
  });

  it("i pezzi ci sono solo per la squadra in testa", () => {
    const has = (t: number, leader: number) => stageAt(bologna, t, leader).platforms.filter((p) => p.forLeader !== undefined).map((p) => p.forLeader);
    assert.deepEqual(has(inBrawl, 0), [], "pareggio o niente: nessuno");
    assert.deepEqual(has(inBrawl, 1), [1, 1]);
    assert.deepEqual(has(inBrawl, 2), [2, 2]);
    assert.deepEqual(has(BOLOGNA.towersMs + 1000, 1), [], "prima della zuffa non ci sono");
    assert.notEqual(stageAt(bologna, inBrawl, 1), stageAt(bologna, inBrawl, 2), "la vista cambia con la squadra");
    assert.equal(stageAt(bologna, inBrawl, 1), stageAt(bologna, inBrawl + 100, 1), "stessa squadra: la stessa vista");
  });

  it("si congela a prizeAtMs: chi ha più punti vince, e dopo non cambia", () => {
    const ctx = newCtx(BOLOGNA.collapseMs - 100);
    assert.equal(freezePrize(ctx), 0, "prima non c'è");
    ctx.stations!.points = { 1: 3, 2: 1 };
    stepWorld([], DT, ctx);
    assert.equal(ctx.stations!.prize, undefined, "ancora prima del crollo");
    ctx.timeMs = BOLOGNA.collapseMs;
    stepWorld([], DT, ctx);
    assert.equal(ctx.stations!.prize, 1);
    ctx.stations!.points = { 1: 3, 2: 9 }; // dopo il crollo i punti non contano più
    ctx.timeMs = inBrawl;
    stepWorld([], DT, ctx);
    assert.equal(prizeLeader(ctx), 1);
    assert.deepEqual(prizePieces(ctx), [1, 1], "il mondo ha i ponteggi della squadra 1");
    assert.equal(stationSnapshot(ctx).prizeTeam, 1);
  });

  it("pareggio e zero punti non danno niente", () => {
    for (const points of [{ 1: 2, 2: 2 }, {}, { 1: 0, 2: 0 }] as Record<number, number>[]) {
      const ctx = newCtx(BOLOGNA.collapseMs - 100);
      freezePrize(ctx);
      ctx.stations!.points = points;
      ctx.timeMs = inBrawl;
      stepWorld([], DT, ctx);
      assert.equal(ctx.stations!.prize, 0);
      assert.equal(stationSnapshot(ctx).prizeTeam, undefined);
      assert.deepEqual(prizePieces(ctx), []);
    }
    const ctx = newCtx(BOLOGNA.collapseMs - 100);
    freezePrize(ctx);
    ctx.stations!.points = { 2: 1 };
    ctx.timeMs = BOLOGNA.collapseMs;
    freezePrize(ctx);
    assert.equal(ctx.stations!.prize, 2, "un punto contro zero basta");
  });

  it("la rivincita azzera il premio", () => {
    const ctx = newCtx(BOLOGNA.collapseMs - 100);
    freezePrize(ctx);
    ctx.stations!.points = { 1: 5 };
    ctx.timeMs = inBrawl;
    stepWorld([], DT, ctx);
    assert.equal(prizeLeader(ctx), 1);
    resetStations([], ctx);
    assert.equal(prizeLeader(ctx), 0);
    ctx.timeMs = 0;
    stepWorld([], DT, ctx);
    assert.deepEqual(prizePieces(ctx), []);
    assert.equal(stationSnapshot(ctx).prizeTeam, undefined);
  });

  it("i ponteggi si raggiungono con chiunque in testa, e i controlli delle arene reggono", () => {
    assert.deepEqual(timedReachProblems(bologna), []);
    for (const leader of [1, 2]) {
      const view = stageAt(bologna, inBrawl, leader);
      for (const p of view.platforms.filter((q) => q.forLeader === leader)) assert.ok(reachable(view, p), `ponteggio ${p.x},${p.y} (squadra ${leader})`);
    }
  });
});
