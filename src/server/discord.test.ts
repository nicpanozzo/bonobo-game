// Test delle statistiche e del messaggio per Discord (#18): nessuna rete, solo eventi finti.
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { sanitizeRules } from "../shared/rules";
import type { GameEvent } from "../shared/types";
import { formatResult } from "./discord";
import { MatchStats } from "./stats";

const hit = (attackerId: string, targetId: string, damage: number): GameEvent => ({
  type: "hit",
  attackerId,
  targetId,
  kind: "heavy",
  damage,
  percent: 0,
  knockback: 0,
  x: 0,
  y: 0,
});
const ko = (id: string, byId: string | null): GameEvent => ({ type: "ko", id, byId, x: 0, y: 0, stocksLeft: 0 });

describe("statistiche", () => {
  it("sommano danni, KO, cadute e autodistruzioni", () => {
    const s = new MatchStats();
    s.add([hit("a", "b", 13), hit("a", "b", 5), ko("b", "a"), ko("a", null)]);
    assert.deepEqual(s.get("a"), { kos: 1, falls: 1, selfDestructs: 1, damageDealt: 18, damageTaken: 0 });
    assert.deepEqual(s.get("b"), { kos: 0, falls: 1, selfDestructs: 0, damageDealt: 0, damageTaken: 18 });
  });

  it("la rivincita riparte da zero", () => {
    const s = new MatchStats();
    s.add([ko("b", "a"), { type: "matchStart" }]);
    assert.equal(s.get("a").kos, 0);
  });
});

describe("messaggio Discord", () => {
  const players = [
    { id: "a", name: "Luca", team: 0, stocks: 2 },
    { id: "b", name: "Marta", team: 0, stocks: 0 },
  ];
  it("dice chi ha vinto su chi, con una riga per giocatore", () => {
    const s = new MatchStats();
    s.add([hit("a", "b", 40), ko("b", "a"), ko("b", "a"), ko("b", null)]);
    const text = formatResult({ type: "matchEnd", winnerId: "a", winnerTeam: 0, durationMs: 95_000 }, players, (id) => s.get(id), sanitizeRules({}));
    const [head, first, second] = text.split("\n");
    assert.equal(head, "🦍 **Luca** vince su Marta (1:35)");
    assert.equal(first, "👑 Luca: 2 KO, 40% inflitti, 0 cadute");
    assert.equal(second, "• Marta: 0 KO, 0% inflitti, 3 cadute, 1 da solo");
  });

  it("a squadre vince la squadra", () => {
    const s = new MatchStats();
    const text = formatResult({ type: "matchEnd", winnerId: "a", winnerTeam: 2, durationMs: 0 }, players, (id) => s.get(id), sanitizeRules({ mode: "teams" }));
    assert.match(text, /^🦍 Vince la squadra \*\*Blu\*\*/);
  });
});
