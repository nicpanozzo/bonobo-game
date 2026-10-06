import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { canHitWithRules, DEFAULT_RULES, lastStanding, leaderOnTime, RULE_LIMITS, sanitizeRules } from "./rules";

describe("regole della partita", () => {
  it("senza niente usa i default", () => {
    assert.deepEqual(sanitizeRules(undefined), DEFAULT_RULES);
  });

  it("riporta in valori validi quello che arriva dal client", () => {
    // Un client può mandare qualsiasi cosa: il cast simula dati non validi
    const r = sanitizeRules({ mode: "boh", stocks: 1000, timeLimitSec: -5, friendlyFire: "si" } as never);
    assert.equal(r.mode, "ffa");
    assert.equal(r.stocks, RULE_LIMITS.maxStocks);
    assert.equal(r.timeLimitSec, 0);
    assert.equal(r.friendlyFire, DEFAULT_RULES.friendlyFire);
  });

  it("tiene le scelte valide", () => {
    assert.deepEqual(sanitizeRules({ mode: "teams", stocks: 5, timeLimitSec: 180, friendlyFire: true }), {
      mode: "teams",
      stocks: 5,
      timeLimitSec: 180,
      friendlyFire: true,
    });
  });
});

describe("chi vince", () => {
  const p = (id: string, team: number, stocks: number, percent = 0) => ({ id, team, stocks, percent, eliminated: stocks <= 0 });
  const ffa = DEFAULT_RULES;
  const teams = { ...DEFAULT_RULES, mode: "teams" as const };

  it("tutti contro tutti: l'ultimo rimasto", () => {
    assert.equal(lastStanding(ffa, [p("a", 0, 1), p("b", 0, 0)])?.id, "a");
    assert.equal(lastStanding(ffa, [p("a", 0, 1), p("b", 0, 2)]), undefined);
    assert.equal(lastStanding(ffa, [p("a", 0, 1)]), undefined, "da soli non si vince");
  });

  it("a squadre: vince la squadra con qualcuno ancora in gioco", () => {
    const players = [p("a", 1, 0), p("b", 1, 2), p("c", 2, 0), p("d", 2, 0)];
    assert.equal(lastStanding(teams, players)?.id, "b");
    assert.equal(lastStanding(teams, [p("a", 1, 1), p("c", 2, 1)]), undefined);
  });

  it("allo scadere del tempo: più vite, poi meno percentuale", () => {
    assert.equal(leaderOnTime(ffa, [p("a", 0, 2, 80), p("b", 0, 3, 150)])?.id, "b");
    assert.equal(leaderOnTime(ffa, [p("a", 0, 2, 80), p("b", 0, 2, 20)])?.id, "b");
    assert.equal(leaderOnTime(teams, [p("a", 1, 1), p("b", 1, 1), p("c", 2, 3), p("d", 2, 0)])?.id, "c");
  });

  it("fuoco amico", () => {
    assert.equal(canHitWithRules(teams, 1, 1), false);
    assert.equal(canHitWithRules({ ...teams, friendlyFire: true }, 1, 1), true);
    assert.equal(canHitWithRules(teams, 1, 2), true);
    assert.equal(canHitWithRules(ffa, 0, 0), true);
  });
});
