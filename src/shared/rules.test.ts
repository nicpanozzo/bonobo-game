import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { DEFAULT_RULES, RULE_LIMITS, sanitizeRules } from "./rules";

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
