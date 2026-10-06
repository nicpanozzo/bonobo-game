import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { TICK_RATE } from "./constants";
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
