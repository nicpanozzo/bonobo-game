import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { MAX_TEAMS } from "./constants";
import { ITEM_AMOUNTS, ITEM_RULES } from "./constants";
import { canHitWithRules, DEFAULT_RULES, flagWinnerTeam, lastStanding, leaderOnTime, requestedTeam, RULE_LIMITS, sanitizeRules } from "./rules";

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
      teamCount: 2,
      supremeSpeed: 1,
      itemAmount: DEFAULT_RULES.itemAmount,
      itemKinds: DEFAULT_RULES.itemKinds,
    });
  });

  it("velocità della suprema e oggetti: solo valori previsti, default come prima", () => {
    assert.equal(DEFAULT_RULES.supremeSpeed, 1);
    assert.equal(ITEM_AMOUNTS[DEFAULT_RULES.itemAmount].everyMs, ITEM_RULES.spawnEveryMs);
    assert.equal(ITEM_AMOUNTS[DEFAULT_RULES.itemAmount].maxOnStage, ITEM_RULES.maxOnStage);
    assert.ok(DEFAULT_RULES.itemKinds.includes("banana") && !DEFAULT_RULES.itemKinds.includes("fungo"));
    const r = sanitizeRules({ supremeSpeed: 2, itemAmount: 99, itemKinds: ["bong", "fungo", "boh", "banana", "bong"] });
    assert.equal(r.supremeSpeed, 2);
    assert.equal(r.itemAmount, ITEM_AMOUNTS.length - 1);
    assert.deepEqual(r.itemKinds, ["banana", "bong"]);
    assert.equal(sanitizeRules({ supremeSpeed: 1000 }).supremeSpeed, 1);
    assert.deepEqual(sanitizeRules({ itemKinds: [] }).itemKinds, []);
  });

  it("a squadre si sceglie quante squadre, in Bandiera sono sempre due (#409)", () => {
    assert.equal(sanitizeRules({ mode: "teams", teamCount: 3 }).teamCount, 3);
    assert.equal(sanitizeRules({ mode: "teams", teamCount: 9 }).teamCount, MAX_TEAMS);
    assert.equal(sanitizeRules({ mode: "teams", teamCount: 1 }).teamCount, 2);
    assert.equal(sanitizeRules({ mode: "flag", teamCount: 4 }).teamCount, 2);
    const three = sanitizeRules({ mode: "teams", teamCount: 3 });
    assert.equal(requestedTeam(three, 3), 3);
    assert.equal(requestedTeam(three, 4), 0);
    assert.equal(requestedTeam(three, "2"), 0);
    assert.equal(requestedTeam(sanitizeRules({ mode: "ffa" }), 1), 0);
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
    // Con tre squadre vince quella con più vite sommate (#409)
    assert.equal(leaderOnTime({ ...teams, teamCount: 3 }, [p("a", 1, 1), p("b", 2, 1), p("c", 3, 2), p("d", 3, 1)])?.id, "c");
  });

  it("fuoco amico", () => {
    assert.equal(canHitWithRules(teams, 1, 1), false);
    assert.equal(canHitWithRules({ ...teams, friendlyFire: true }, 1, 1), true);
    assert.equal(canHitWithRules(teams, 1, 2), true);
    assert.equal(canHitWithRules(ffa, 0, 0), true);
  });
  it("Bandiera: punti, compagni e punto d'oro", () => {
    const flag = sanitizeRules({ mode: "flag", stocks: 3 });
    assert.equal(flag.mode, "flag");
    assert.equal(canHitWithRules(flag, 1, 1), false, "niente fuoco amico");
    assert.equal(flagWinnerTeam(flag, { 1: 3, 2: 1 }, false), 1);
    assert.equal(flagWinnerTeam(flag, { 1: 1, 2: 2 }, false), undefined);
    assert.equal(flagWinnerTeam(flag, { 1: 1, 2: 2 }, true), 2);
    assert.equal(flagWinnerTeam(flag, { 1: 2, 2: 2 }, true), undefined, "pari: si continua");
  });
});
