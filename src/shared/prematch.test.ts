import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { PREMATCH, TICK_RATE } from "./constants";
import { Match } from "./match";
import { emptyInput } from "./physics";
import type { GameEvent } from "./types";

const DT = 1000 / TICK_RATE;

function run(match: Match, ms: number): GameEvent[] {
  const events: GameEvent[] = [];
  for (let t = 0; t < ms; t += DT) events.push(...match.step(DT));
  return events;
}

function twoPlayers(rules = {}) {
  const m = new Match({ prematch: true, rules });
  m.addPlayer("a", "Anna");
  m.addPlayer("b", "Bruno");
  return m;
}

describe("pre-partita", () => {
  it("si aspetta finché non sono pronti tutti, poi presentazione, 3, 2, 1 e matchStart al VIA", () => {
    const m = twoPlayers();
    run(m, 2000);
    assert.equal(m.snapshot([], 0).prematch?.phase, "waiting");
    m.setReady("a", true);
    run(m, 500);
    assert.deepEqual(m.snapshot([], 0).prematch?.ready, ["a"]);
    assert.equal(m.snapshot([], 0).prematch?.phase, "waiting", "manca Bruno");
    m.setReady("b", true);
    assert.ok(!run(m, DT).some((e) => e.type === "matchStart"));
    const pre = m.snapshot([], 0).prematch!;
    assert.equal(pre.phase, "starting");
    assert.ok(pre.leftMs > PREMATCH.countdownMs, "prima la presentazione");
    const events = run(m, PREMATCH.introMs + PREMATCH.countdownMs);
    assert.equal(events.filter((e) => e.type === "matchStart").length, 1);
    assert.equal(m.snapshot([], 0).prematch, undefined);
    assert.ok(m.started);
  });

  it("al 3, 2, 1 i lottatori stanno fermi, e il tasto tenuto vale dal VIA", () => {
    const m = twoPlayers();
    m.setReady("a", true);
    m.setReady("b", true);
    run(m, DT);
    const a = m.players.find((p) => p.id === "a")!;
    run(m, 500); // a terra al suo posto
    const x = a.x;
    m.setInput("a", { ...emptyInput(), right: true });
    run(m, 1000);
    assert.equal(a.x, x, "fermo");
    run(m, PREMATCH.introMs + PREMATCH.countdownMs);
    assert.ok(a.x > x, "al VIA corre a destra senza ripremere");
  });

  it("nell'attesa ci si scalda senza perdere vite", () => {
    const m = twoPlayers();
    const a = m.players.find((p) => p.id === "a")!;
    const stocks = a.stocks;
    for (let i = 0; i < 3; i++) {
      a.x = m.stage.blastZone.right + 100;
      run(m, 3000);
    }
    assert.equal(a.stocks, stocks);
    assert.equal(a.eliminated, false);
    assert.equal(m.snapshot([], 0).winnerId, null);
  });

  it("da soli si gira per l'arena; con due lottatori si parte comunque dopo autoStartMs", () => {
    const m = new Match({ prematch: true });
    m.addPlayer("a", "Anna");
    m.setReady("a", true);
    run(m, 1000);
    assert.equal(m.snapshot([], 0).prematch?.phase, "waiting");
    assert.equal(m.snapshot([], 0).prematch?.autoStartMs, null);
    m.addPlayer("b", "Bruno"); // un client vecchio: non dirà mai Pronto
    run(m, PREMATCH.autoStartMs + DT);
    assert.equal(m.snapshot([], 0).prematch?.phase, "starting");
  });

  it("chi è caduto dalla rete non fa aspettare", () => {
    const m = twoPlayers();
    m.addPlayer("c", "Carla");
    m.setAway("c", true);
    m.setReady("a", true);
    m.setReady("b", true);
    run(m, DT);
    assert.equal(m.snapshot([], 0).prematch?.phase, "starting");
  });

  it("la rivincita passa dal 3, 2, 1 senza presentazione", () => {
    const m = twoPlayers({ stocks: 1 });
    m.setReady("a", true);
    m.setReady("b", true);
    run(m, PREMATCH.introMs + PREMATCH.countdownMs + DT);
    const b = m.players.find((p) => p.id === "b")!;
    while (!b.eliminated) {
      if (!b.respawning) b.x = m.stage.blastZone.right + 100;
      run(m, DT);
    }
    assert.ok(m.snapshot([], 0).winnerId);
    m.requestRematch();
    const pre = m.snapshot([], 0).prematch!;
    assert.equal(pre.phase, "starting");
    assert.ok(pre.leftMs <= PREMATCH.countdownMs);
    assert.equal(m.snapshot([], 0).winnerId, null);
    assert.ok(run(m, PREMATCH.countdownMs).some((e) => e.type === "matchStart"));
  });

  it("senza pre-partita (test, Allenamento) si comincia subito come prima", () => {
    assert.equal(new Match({}).started, true);
    const t = new Match({ prematch: true, rules: { mode: "training" } });
    t.addPlayer("a", "Anna");
    assert.equal(t.snapshot([], 0).prematch, undefined);
  });
});
