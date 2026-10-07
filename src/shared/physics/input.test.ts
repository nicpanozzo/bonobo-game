// Buffer degli input (E6 passo 4): si lanciano con `npm test`.
// Gli input arrivano da Match.setInput come dalla rete, anche più di uno tra due passi.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { INPUT, TICK_RATE } from "../constants";
import { Match } from "../match";
import type { GameEvent, InputState } from "../types";
import { emptyInput, type Fighter } from "./index";

const DT = 1000 / TICK_RATE;

function setup() {
  const m = new Match({});
  m.addPlayer("a", "A");
  run(m, 60); // atterra e la partita parte
  return { m };
}

const getFighter = (m: Match) => m.players[0] as Fighter;

function run(m: Match, ticks: number): GameEvent[] {
  const events: GameEvent[] = [];
  for (let i = 0; i < ticks; i++) events.push(...m.step(DT));
  return events;
}

// Premuto e lasciato prima del passo successivo: un tocco più corto di un tick
function tap(m: Match, keys: Partial<InputState>) {
  m.setInput("a", { ...emptyInput(), ...keys });
  m.setInput("a", emptyInput());
}

const attacks = (events: GameEvent[]) => events.filter((e) => e.type === "attack");
const jumps = (events: GameEvent[]) => events.filter((e) => e.type === "jump");

// Va avanti finché il cooldown dell'attacco scende a ms o meno
function untilCooldown(m: Match, ms: number) {
  const f = getFighter(m);
  while (f.cooldownTimer > ms) run(m, 1);
  assert.equal(f.attack, null, "l'attacco è finito, resta solo il cooldown");
}

describe("buffer degli input", () => {
  it("un tocco più corto di un tick fa partire l'attacco", () => {
    const { m } = setup();
    tap(m, { light: true });
    assert.equal(attacks(run(m, 1)).length, 1);
  });

  it(`leggero premuto 80 ms prima della fine del cooldown parte appena finisce (buffer ${INPUT.bufferMs} ms)`, () => {
    const { m } = setup();
    tap(m, { light: true });
    run(m, 1);
    untilCooldown(m, 80);
    tap(m, { light: true });
    const f = getFighter(m);
    let ticks = 0;
    let started: GameEvent[] = [];
    while (started.length === 0 && ticks < 20) {
      const wasCooling = f.cooldownTimer > 0;
      started = attacks(run(m, 1));
      ticks++;
      if (started.length) assert.ok(wasCooling, "parte nel passo in cui il cooldown finisce");
    }
    assert.equal(started.length, 1);
    assert.ok(ticks * DT <= 80 + DT, `partito dopo ${ticks} passi`);
  });

  it("leggero premuto 150 ms prima della fine del cooldown non parte", () => {
    const { m } = setup();
    tap(m, { heavy: true }); // il pesante finisce prima, così a 150 ms resta solo il cooldown
    run(m, 1);
    untilCooldown(m, 150);
    tap(m, { light: true });
    assert.equal(attacks(run(m, 30)).length, 0);
  });

  it("una pressione fa un solo salto, anche tenendo premuto", () => {
    const { m } = setup();
    m.setInput("a", { ...emptyInput(), up: true });
    assert.equal(jumps(run(m, 40)).length, 1);
    m.setInput("a", emptyInput());
    tap(m, { up: true });
    assert.equal(jumps(run(m, 10)).length, 1, "il tocco in aria fa il doppio salto, uno solo");
  });

  it("una pressione fa un solo attacco: il buffer si consuma quando l'attacco parte", () => {
    const { m } = setup();
    tap(m, { heavy: true });
    const events = run(m, 120);
    assert.equal(attacks(events).length, 1);
  });

  it("il buffer scade da solo dopo INPUT.bufferMs", () => {
    const { m } = setup();
    const f = getFighter(m);
    f.dodgeCooldown = 1000; // la schivata non può partire
    tap(m, { dodge: true });
    run(m, Math.ceil(INPUT.bufferMs / DT));
    assert.equal(f.buffer.dodge, 0);
  });
});
