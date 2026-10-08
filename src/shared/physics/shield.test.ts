// Test dello scudo (#109, E8 passo 1): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, SHIELD, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560

// a attacca verso destra, b gli sta davanti girato verso di lui
function setup() {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [0, 1].map((i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  const [a, b] = fighters;
  a.x = 600;
  a.facing = 1;
  b.x = 600 + FIGHTER.width + 10;
  b.facing = -1;
  run(fighters, ctx, 10); // a terra, fermi
  ctx.events.length = 0;
  return { ctx, fighters, a, b };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const ofType = <T extends GameEvent["type"]>(events: GameEvent[], type: T) =>
  events.filter((e): e is Extract<GameEvent, { type: T }> => e.type === type);

// a tira un leggero e aspetta che finisca, cooldown compreso
function lightAttack(fighters: Fighter[], ctx: PhysicsContext, a: Fighter) {
  press(a, { light: true });
  run(fighters, ctx, 1);
  press(a, {});
  run(fighters, ctx, Math.ceil((ATTACKS.light.cooldownMs + 50) / DT));
}

describe("scudo", () => {
  it("5 leggeri sullo scudo non cambiano la percentuale e consumano lo scudo", () => {
    const { ctx, fighters, a, b } = setup();
    press(b, { shield: true });
    run(fighters, ctx, 3);
    assert.equal(b.shielding, true);
    for (let n = 0; n < 5; n++) {
      b.x = a.x + FIGHTER.width + 10; // la scivolata lo allontana: lo si rimette a portata
      lightAttack(fighters, ctx, a);
    }
    const parried = ofType(ctx.events, "shield");
    assert.equal(parried.length, 5);
    assert.equal(ofType(ctx.events, "hit").length, 0);
    assert.equal(b.percent, 0);
    assert.equal(b.hitstun, false);
    assert.deepEqual(parried[0], { ...parried[0], id: "p1", attackerId: "p0", damage: ATTACKS.light.damage });
    assert.ok(b.shieldHp < SHIELD.maxHp - 5 * ATTACKS.light.damage, "colpi e tempo consumano lo scudo");
  });

  it("il colpo parato fa scivolare indietro", () => {
    const { ctx, fighters, a, b } = setup();
    press(b, { shield: true });
    run(fighters, ctx, 3);
    const x = b.x;
    lightAttack(fighters, ctx, a);
    assert.ok(b.x > x + 5, `scivolato da ${x} a ${b.x}`);
    assert.equal(b.vx, 0, "e si è fermato");
  });

  it("lo scudo tenuto si rompe da solo in circa 5,5 s", () => {
    const { ctx, fighters, b } = setup();
    press(b, { shield: true });
    let ticks = 0;
    while (ofType(ctx.events, "shieldBreak").length === 0 && ticks < 60 * 10) {
      run(fighters, ctx, 1);
      ticks++;
    }
    const seconds = (ticks * DT) / 1000;
    assert.ok(seconds > 5.4 && seconds < 5.8, `rotto dopo ${seconds} s`);
    assert.equal(b.stunned, true);
    assert.equal(b.shielding, false);
    assert.ok(b.vy < 0, "saltino in alto");
  });

  it("dopo la rottura si è fermi per 2,5 s e colpibili", () => {
    const { ctx, fighters, a, b } = setup();
    b.shieldHp = 1;
    press(b, { shield: true });
    run(fighters, ctx, 10);
    assert.equal(ofType(ctx.events, "shieldBreak").length, 1);
    // Tiene destra e salto: non si muove
    press(b, { right: true, jump: true, light: true });
    run(fighters, ctx, 60); // ricade a terra
    assert.equal(b.onGround, true);
    const x = b.x;
    run(fighters, ctx, Math.floor((SHIELD.breakStunMs - 60 * DT - 200) / DT));
    assert.equal(b.stunned, true);
    assert.equal(b.x, x);
    assert.equal(ofType(ctx.events, "jump").length, 0);
    assert.equal(ofType(ctx.events, "attack").length, 0);
    // a lo colpisce e il colpo entra
    b.x = a.x + FIGHTER.width + 10;
    press(b, {});
    lightAttack(fighters, ctx, a);
    assert.ok(b.percent > 0);
    assert.equal(b.stunned, false, "il colpo lo sveglia");
  });

  it("senza colpi lo stordimento finisce dopo 2,5 s e ci si muove di nuovo", () => {
    const { ctx, fighters, b } = setup();
    b.shieldHp = 1;
    press(b, { shield: true });
    run(fighters, ctx, 10);
    assert.equal(ofType(ctx.events, "shieldBreak").length, 1);
    press(b, {});
    run(fighters, ctx, Math.ceil(SHIELD.breakStunMs / DT));
    assert.equal(b.stunned, false);
    assert.ok(Math.abs(b.shieldHp - SHIELD.hpAfterBreak) < 1, `riparte con ${b.shieldHp} punti`);
    const x = b.x;
    press(b, { right: true });
    run(fighters, ctx, 10);
    assert.ok(b.x > x);
  });

  it("abbassato si ricarica, e dopo averlo abbassato si resta fermi un attimo", () => {
    const { ctx, fighters, b } = setup();
    press(b, { shield: true });
    run(fighters, ctx, 60);
    const low = b.shieldHp;
    assert.ok(low < SHIELD.maxHp - SHIELD.drainPerSec * 0.9);
    press(b, { right: true });
    run(fighters, ctx, 1);
    assert.equal(b.shielding, false);
    const x = b.x;
    run(fighters, ctx, Math.floor(SHIELD.dropMs / DT) - 1);
    assert.equal(b.x, x, "fermo per SHIELD.dropMs");
    run(fighters, ctx, 3);
    assert.ok(b.x > x, "poi cammina");
    run(fighters, ctx, 60);
    assert.ok(b.shieldHp > low + SHIELD.regenPerSec * 0.9);
  });

  it("col salto si salta fuori dallo scudo, con una direzione si rotola", () => {
    {
      const { ctx, fighters, b } = setup();
      press(b, { shield: true });
      run(fighters, ctx, 10);
      press(b, { shield: true, jump: true });
      run(fighters, ctx, 1);
      assert.equal(ofType(ctx.events, "jump").length, 1);
      assert.equal(b.shielding, false);
    }
    {
      const { ctx, fighters, b } = setup();
      press(b, { shield: true });
      run(fighters, ctx, 10);
      press(b, { shield: true, right: true });
      run(fighters, ctx, 2);
      assert.ok(b.dodgeTimer > 0, "schivata partita");
      assert.equal(b.invulnerable, true);
      assert.ok(b.vx > 0);
    }
  });

  it("in aria lo scudo non si alza", () => {
    const { ctx, fighters, b } = setup();
    b.y -= 200;
    b.onGround = false;
    press(b, { shield: true });
    run(fighters, ctx, 5);
    assert.equal(b.shielding, false);
  });
});
