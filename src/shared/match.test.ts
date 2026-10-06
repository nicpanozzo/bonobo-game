import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { MAX_PLAYERS_PER_ROOM, TICK_RATE } from "./constants";
import { Match } from "./match";
import type { GameEvent } from "./types";

const DT = 1000 / TICK_RATE;

function run(match: Match, ticks: number): GameEvent[] {
  const events: GameEvent[] = [];
  for (let i = 0; i < ticks; i++) events.push(...match.step(DT));
  return events;
}

// Butta fuori un giocatore fino a finirgli le vite (a mano: non serve combattere)
function knockOut(match: Match, id: string): GameEvent[] {
  const f = match.players.find((p) => p.id === id)!;
  const events: GameEvent[] = [];
  while (!f.eliminated) {
    if (!f.respawning) f.x = match.stage.blastZone.right + 100;
    events.push(...run(match, 1));
  }
  return events;
}

describe("partita", () => {
  it("vince l'ultimo rimasto, poi la rivincita rimette tutti in gioco", () => {
    const m = new Match({ rules: { stocks: 2 } });
    m.addPlayer("a", "A");
    m.addPlayer("b", "B");
    const events = knockOut(m, "b");
    assert.equal(events.filter((e) => e.type === "ko").length, 2);
    const end = events.find((e) => e.type === "matchEnd");
    assert.ok(end && end.type === "matchEnd" && end.winnerId === "a");
    assert.equal(m.snapshot([], 0).winnerId, "a");

    m.requestRematch();
    const after = run(m, 1);
    assert.ok(after.some((e) => e.type === "matchStart"));
    assert.equal(m.snapshot([], 0).winnerId, null);
    assert.ok(m.players.every((p) => p.stocks === 2 && !p.eliminated));
  });

  it("allo scadere del tempo vince chi ha più vite", () => {
    const m = new Match({ rules: { timeLimitSec: 1 } });
    m.addPlayer("a", "A");
    m.addPlayer("b", "B");
    m.players.find((p) => p.id === "a")!.stocks -= 1;
    const events = run(m, TICK_RATE + 2);
    const end = events.find((e) => e.type === "matchEnd");
    assert.ok(end && end.type === "matchEnd" && end.winnerId === "b");
  });

  it("a squadre i giocatori si dividono e i compagni non si colpiscono", () => {
    const m = new Match({ rules: { mode: "teams" } });
    for (const id of ["a", "b", "c", "d"]) m.addPlayer(id, id.toUpperCase());
    assert.deepEqual(m.players.map((p) => p.team), [1, 2, 1, 2]);
    assert.equal(new Set(m.players.map((p) => p.color)).size, 4, "colori tutti diversi");
  });

  it("in otto: posti, partenze e colori tutti diversi, poi la stanza è piena", () => {
    for (const mode of ["ffa", "teams"] as const) {
      const m = new Match({ rules: { mode } });
      for (let i = 0; i < MAX_PLAYERS_PER_ROOM; i++) m.addPlayer(`p${i}`, `P${i}`);
      assert.equal(m.isFull, true);
      const ps = m.players;
      assert.equal(new Set(ps.map((p) => p.color)).size, 8, `${mode}: colori diversi`);
      assert.equal(new Set(ps.map((p) => p.x)).size, 8, `${mode}: partenze diverse`);
      if (mode === "teams") assert.equal(ps.filter((p) => p.team === 1).length, 4);
      run(m, 30);
      assert.ok(ps.every((p) => p.onGround && !p.respawning), `${mode}: tutti fermi sul palco`);
    }
  });

  it("Bandiera: un portabandiera per squadra, punto a chi lo butta fuori, la bandiera gira", () => {
    const m = new Match({ rules: { mode: "flag", stocks: 2 } });
    for (const id of ["a", "b", "c", "d"]) m.addPlayer(id, id.toUpperCase());
    const carriers = () => m.players.filter((p) => p.carrier).map((p) => p.id);
    assert.deepEqual(carriers(), ["a", "b"], "il primo di ogni squadra");

    // Un giocatore senza bandiera che cade non perde vite e non dà punti
    const c = m.players.find((p) => p.id === "c")!;
    c.x = m.stage.blastZone.right + 100;
    let events = run(m, 2);
    assert.equal(c.stocks, 2);
    assert.equal(events.some((e) => e.type === "flag"), false);

    // Il portabandiera rosso cade: punto alla Blu, la bandiera passa a "c"
    const a = m.players.find((p) => p.id === "a")!;
    a.x = m.stage.blastZone.right + 100;
    events = run(m, 1);
    const flag = events.find((e) => e.type === "flag");
    assert.ok(flag && flag.type === "flag" && flag.scoringTeam === 2 && flag.carrierId === "c");
    assert.deepEqual(m.snapshot([], 0).teamScores, { 1: 0, 2: 1 });
    assert.deepEqual(carriers().sort(), ["b", "c"]);

    // Secondo punto: la Blu vince
    c.respawning = false;
    c.x = m.stage.blastZone.right + 100;
    events = run(m, 1);
    const end = events.find((e) => e.type === "matchEnd");
    assert.ok(end && end.type === "matchEnd" && end.winnerTeam === 2);

    // Rivincita: punti a zero, bandiere al primo di ogni squadra
    m.requestRematch();
    run(m, 1);
    assert.deepEqual(m.snapshot([], 0).teamScores, { 1: 0, 2: 0 });
    assert.deepEqual(carriers().sort(), ["a", "b"]);
  });

  it("Bandiera: se il portabandiera esce dalla stanza la bandiera passa a un compagno", () => {
    const m = new Match({ rules: { mode: "flag" } });
    for (const id of ["a", "b", "c"]) m.addPlayer(id, id.toUpperCase());
    m.removePlayer("a");
    assert.equal(m.players.find((p) => p.id === "c")!.carrier, true);
  });

  it("Bandiera: a pari punti allo scadere si va al punto d'oro", () => {
    const m = new Match({ rules: { mode: "flag", timeLimitSec: 1 } });
    m.addPlayer("a", "A");
    m.addPlayer("b", "B");
    let events = run(m, TICK_RATE + 2);
    assert.equal(events.some((e) => e.type === "matchEnd"), false);
    assert.equal(m.snapshot([], 0).timeLeftMs, 0);
    m.players.find((p) => p.id === "b")!.x = m.stage.blastZone.left - 100;
    events = run(m, 1);
    const end = events.find((e) => e.type === "matchEnd");
    assert.ok(end && end.type === "matchEnd" && end.winnerId === "a");
  });

  it("i dati strani dalla rete diventano booleani e i nomi si accorciano", () => {
    const m = new Match();
    m.addPlayer("a", "un nome davvero troppo lungo");
    m.setInput("a", { left: 1, right: "x" } as never);
    const [p] = m.players;
    assert.equal(p.name.length, 16);
    assert.equal(p.input.left, true);
    assert.equal(p.input.up, false);
  });

  it("lo snapshot non porta i campi interni della fisica", () => {
    const m = new Match();
    m.addPlayer("a", "A");
    const [p] = m.snapshot([], 0).players;
    assert.equal("input" in p, false);
    assert.equal("alreadyHit" in p, false);
  });
});
