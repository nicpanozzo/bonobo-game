// Test dei bot (#20): girano su una Match senza rete, come nel server.
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, TICK_RATE } from "../shared/constants";
import { Match } from "../shared/match";
import { Bots, parseBotKind } from "./bot";

const DT = 1000 / TICK_RATE;

describe("bot", () => {
  it("accetta solo i tipi conosciuti", () => {
    assert.equal(parseBotKind("manichino"), "manichino");
    assert.equal(parseBotKind("boh"), null);
    assert.equal(parseBotKind("toString"), null);
    assert.equal(parseBotKind(42), null);
  });

  it("il manichino resta fermo e incassa i colpi", () => {
    const match = new Match();
    const bots = new Bots();
    match.addPlayer("a", "A");
    const botId = bots.add(match, "manichino")!;
    const [a, dummy] = match.players;
    assert.equal(dummy.id, botId);
    // Il manichino davanti al giocatore, che lo guarda
    a.x = 600;
    a.facing = 1;
    dummy.x = 600 + FIGHTER.width + 20;
    const start = { x: dummy.x, y: dummy.y };
    for (let i = 0; i < 30; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.deepEqual({ x: dummy.x, y: dummy.y }, start, "da solo non si muove");
    match.setInput("a", { left: false, right: false, up: false, down: false, light: true, heavy: false, taunt: false });
    for (let i = 0; i < 15; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.ok(dummy.percent > 0, "il colpo è entrato");
  });
});
