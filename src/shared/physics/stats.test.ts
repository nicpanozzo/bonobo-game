// Statistiche per personaggio (E11 passo B, #13): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { after, describe, it } from "node:test";
import { CHARACTERS, characterStats } from "../characters";
import { ATTACKS, CHARACTER_STATS, FIGHTER, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

// Personaggi finti solo per i test, tolti alla fine
const TEST_CHARACTERS = {
  "test-pesante": { weight: 1.2 },
  "test-leggero": { weight: 0.8 },
  "test-saltatore": { jump: 1.2 },
  "test-veloce": { speed: 1.2 },
  "test-esagerato": { jump: 5, weight: 0 },
};
for (const [id, stats] of Object.entries(TEST_CHARACTERS)) CHARACTERS[id] = { id, name: id, stats };
after(() => {
  for (const id of Object.keys(TEST_CHARACTERS)) delete CHARACTERS[id];
});

function fighter(characterId: string, index = 0): Fighter {
  return createFighter({ id: `p${index}`, name: "", characterId, color: 0, team: 0, index, stocks: 3 }, stage);
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

// a colpisce b (del personaggio dato, a 80%) con un pesante: quanto lontano vola b in 20 tick
function launch(characterId: string): number {
  const ctx: PhysicsContext = { stage, events: [] };
  const a = fighter("default", 0);
  const b = fighter(characterId, 1);
  a.x = 600;
  a.facing = 1;
  b.x = 600 + FIGHTER.width + 10;
  b.percent = 80;
  const fighters = [a, b];
  run(fighters, ctx, 5);
  a.input = { ...emptyInput(), heavy: true };
  const start = b.x;
  for (let i = 0; i < 60 && ctx.events.every((e) => e.type !== "hit"); i++) run(fighters, ctx, 1);
  assert.ok(ctx.events.some((e) => e.type === "hit"), "il colpo è entrato");
  run(fighters, ctx, 20);
  return b.x - start;
}

// Altezza massima di un salto da terra
function jumpHeight(characterId: string): number {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = fighter(characterId);
  run([f], ctx, 5);
  const ground = f.y;
  f.input = { ...emptyInput(), up: true };
  let top = f.y;
  for (let i = 0; i < 90; i++) {
    run([f], ctx, 1);
    f.input = emptyInput();
    top = Math.min(top, f.y);
  }
  return ground - top;
}

describe("statistiche dei personaggi", () => {
  it("Bonobot e il personaggio base sono il metro: tutto a 1", () => {
    for (const id of ["default", "bonobot"]) {
      assert.deepEqual(characterStats(id), { speed: 1, airSpeed: 1, jump: 1, weight: 1, gravity: 1 });
    }
  });

  it("i valori fuori dai limiti si fermano ai limiti", () => {
    const s = characterStats("test-esagerato");
    assert.equal(s.jump, CHARACTER_STATS.max);
    assert.equal(s.weight, CHARACTER_STATS.min);
  });

  it("a parità di percentuale il pesante vola meno del leggero", () => {
    const heavy = launch("test-pesante");
    const base = launch("default");
    const light = launch("test-leggero");
    assert.ok(heavy < base && base < light, `pesante ${heavy}, base ${base}, leggero ${light}`);
    assert.ok(ATTACKS.heavy.damage > 0);
  });

  it("il saltatore sale di più", () => {
    const high = jumpHeight("test-saltatore");
    const base = jumpHeight("default");
    assert.ok(high > base * 1.3, `saltatore ${high}, base ${base}`); // (1,2)² = 1,44 volte
  });

  it("il veloce corre di più", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const [fast, base] = [fighter("test-veloce", 0), fighter("default", 1)];
    fast.x = base.x = 500;
    run([fast, base], ctx, 5);
    fast.input = base.input = { ...emptyInput(), right: true };
    run([fast, base], ctx, 20);
    assert.ok(fast.x - 500 > (base.x - 500) * 1.15, `veloce ${fast.x}, base ${base.x}`);
  });
});
