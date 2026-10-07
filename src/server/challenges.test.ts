// Le soglie delle sfide (E15) si raggiungono davvero: le gioca il bot difficile al posto di chi gioca,
// e il palleggio un giocatore scritto a mano. Tutto deterministico: stessa fisica del server, niente rete.
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CHALLENGES, ChallengeRun, type Challenge } from "../shared/challenges";
import { TICK_RATE } from "../shared/constants";
import { Match } from "../shared/match";
import { emptyInput, type Fighter } from "../shared/physics";
import { Bots } from "./bot";

const DT = 1000 / TICK_RATE;

// Un tentativo: player è un bot o una funzione che sceglie i tasti
function play(c: Challenge, player: "difficile" | ((me: Fighter, target: Fighter, tick: number) => ReturnType<typeof emptyInput>)): ChallengeRun {
  const match = new Match({ stageId: c.stage, rules: { mode: "training" } });
  const bots = new Bots();
  const me = typeof player === "string" ? bots.add(match, player)! : (match.addPlayer("me", "Me"), "me");
  const target = bots.add(match, c.bot)!;
  match.reset();
  match.setPercent(target, c.botPercent);
  const run = new ChallengeRun(c, me);
  const find = (id: string) => match.players.find((f) => f.id === id)!;
  for (let tick = 0, t = 0; !run.done; tick++) {
    bots.tick(match);
    if (typeof player !== "string") match.setInput(me, player(find(me), find(target), tick));
    for (const e of match.step(DT)) run.onEvent(e, t);
    t += DT;
    run.onTick(t, (id) => find(id).hitstunTimer > 0 || !find(id).onGround);
  }
  return run;
}

// Pesante in su da sotto, poi in aria leggeri finché è lì sopra
function juggler(me: Fighter, target: Fighter, tick: number) {
  const input = emptyInput();
  const dx = target.x - me.x;
  const dy = target.y - me.y;
  if (Math.abs(dx) > 20) input[dx > 0 ? "right" : "left"] = true;
  if (target.onGround) {
    input.up = Math.abs(dx) < 70;
    input.heavy = tick % 2 === 0 && Math.abs(dx) < 70;
  } else {
    input.up = dy < -90 && tick % 6 === 0;
    input.light = tick % 2 === 0 && Math.abs(dy) < 120;
  }
  return input;
}

describe("soglie delle sfide", () => {
  for (const c of CHALLENGES.filter((c) => c.goal !== "juggle")) {
    it(`${c.id}: il bot difficile arriva almeno all'argento`, () => {
      const run = play(c, "difficile");
      assert.ok(run.medal >= 2, `punteggio ${run.score}, medaglia ${run.medal}`);
    });
  }

  it("palleggio: con i tempi giusti si arriva all'oro", () => {
    const run = play(CHALLENGES.find((c) => c.goal === "juggle")!, juggler);
    assert.equal(run.medal, 3, `palleggio da ${run.score}`);
  });
});
