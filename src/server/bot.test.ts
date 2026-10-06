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
    match.setInput("a", { left: false, right: false, up: false, down: false, light: true, heavy: false, taunt: false, dodge: false });
    for (let i = 0; i < 15; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.ok(dummy.percent > 0, "il colpo è entrato");
  });

  it("il bot semplice va verso il giocatore e lo colpisce", () => {
    const match = new Match();
    const bots = new Bots();
    match.addPlayer("a", "A");
    bots.add(match, "semplice");
    const a = match.players.find((p) => p.id === "a")!;
    for (let i = 0; i < 60 * 5 && a.percent === 0; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.ok(a.percent > 0, "in 5 secondi ha colpito almeno una volta");
  });

  it("il bot semplice lanciato fuori torna sul palco", () => {
    const match = new Match();
    const bots = new Bots();
    match.addPlayer("a", "A");
    const id = bots.add(match, "semplice")!;
    const bot = match.players.find((p) => p.id === id)!;
    const ground = match.stage.solids[0];
    // Fuori dal bordo destro, un po' sotto la superficie, già senza doppio salto
    Object.assign(bot, { x: ground.x + ground.width + 120, y: ground.y + 60, vx: 0, vy: 200, onGround: false, jumpsLeft: 1 });
    const stocks = bot.stocks;
    for (let i = 0; i < 60 * 3 && !bot.onGround; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.equal(bot.stocks, stocks, "non è caduto");
    assert.equal(bot.onGround, true, "è di nuovo a terra");
  });
});
