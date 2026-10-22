// I bot su Bologna (#433): il bombardiere sale alla bombarda della sua torre (uscire dalla postazione: vedi bot.ts di #445).
// La prova lunga per fase (5-6 minuti, più squadre) è `npm run bologna:bots`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BOLOGNA, TICK_RATE } from "../shared/constants";
import { Match } from "../shared/match";
import { Bots } from "./bot";

const DT = 1000 / TICK_RATE;

describe("bot su Bologna", () => {
  it("in 2 contro 2 qualcuno sale fino alla bombarda della sua torre e ci entra", () => {
    const match = new Match({ stageId: "bologna", rules: { mode: "teams", stocks: 9, timeLimitSec: 0, itemAmount: 0 }, items: false });
    const bots = new Bots();
    for (let i = 0; i < 4; i++) bots.add(match, "difficile");
    let enters = 0;
    for (let tick = 0; tick < (BOLOGNA.collapseMs / 1000) * TICK_RATE; tick++) {
      bots.tick(match);
      for (const e of match.step(DT)) if (e.type === "station" && e.phase === "enter" && e.y < 1500) enters++; // y < 1500: la bombarda, non le munizioni
    }
    assert.ok(enters >= 1, "nessuno è salito alla bombarda prima del crollo");
  });
});
