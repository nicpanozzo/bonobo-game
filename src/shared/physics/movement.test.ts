// Test della sensazione del movimento: tempo di grazia sul bordo, salto corto, influenza in volo.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560

function setup() {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "a", name: "A", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  return { ctx, f };
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const run = (f: Fighter, ctx: PhysicsContext, ticks: number) => {
  for (let i = 0; i < ticks; i++) stepWorld([f], DT, ctx);
};
const jumps = (events: GameEvent[]) => events.filter((e): e is Extract<GameEvent, { type: "jump" }> => e.type === "jump");

// Cammina verso sinistra finché non lascia la piattaforma sottile di sinistra (x 340, y 420):
// dalle sottili non ci si aggrappa al bordo, quindi conta solo il salto
function walkOffLeft(f: Fighter, ctx: PhysicsContext): number {
  Object.assign(f, { x: 380, y: 420, vx: 0, vy: 0, onGround: true, facing: -1 });
  press(f, { left: true });
  for (let t = 1; t < 60; t++) {
    run(f, ctx, 1);
    if (!f.onGround) return t;
  }
  throw new Error("non è sceso dal palco");
}

describe("tempo di grazia sul bordo (coyote)", () => {
  it("saltando subito dopo essere scesi il salto vale da terra e resta il doppio salto", () => {
    const { ctx, f } = setup();
    walkOffLeft(f, ctx);
    run(f, ctx, 2); // 33 ms dopo, dentro FIGHTER.coyoteMs
    press(f, { left: true, jump: true });
    run(f, ctx, 1);
    const [jump] = jumps(ctx.events);
    assert.equal(jump?.air, false);
    assert.equal(f.vy < -FIGHTER.doubleJumpSpeed, true, "spinta del salto da terra");
    assert.equal(f.jumpsLeft, FIGHTER.maxJumps - 1);
  });

  it("scendendo dalla sottile con giù non c'è tempo di grazia", () => {
    const { ctx, f } = setup();
    Object.assign(f, { x: 440, y: 420, vx: 0, vy: 0, onGround: true });
    press(f, { down: true });
    run(f, ctx, 1);
    press(f, {});
    run(f, ctx, 2);
    assert.equal(f.onGround, false);
    press(f, { jump: true });
    run(f, ctx, 1);
    const [jump] = jumps(ctx.events);
    assert.equal(jump?.air, true);
    assert.equal(f.jumpsLeft, 0);
  });

  it("finito il tempo di grazia resta solo il salto in aria", () => {
    const { ctx, f } = setup();
    walkOffLeft(f, ctx);
    run(f, ctx, Math.ceil(FIGHTER.coyoteMs / DT) + 2);
    assert.equal(f.jumpsLeft, FIGHTER.maxJumps - 1);
    press(f, { left: true, jump: true });
    run(f, ctx, 1);
    const [jump] = jumps(ctx.events);
    assert.equal(jump?.air, true);
    assert.equal(f.jumpsLeft, 0);
  });
});

describe("salto corto", () => {
  // Altezza massima raggiunta tenendo il salto per holdTicks tick
  function peak(holdTicks: number, shortHop = true): number {
    const { ctx, f } = setup();
    f.shortHop = shortHop;
    const ground = f.y;
    let top = f.y;
    for (let t = 0; t < 90; t++) {
      press(f, { jump: t < holdTicks });
      run(f, ctx, 1);
      top = Math.min(top, f.y);
    }
    return ground - top;
  }

  it("lasciando presto il salto si sale molto meno che tenendolo", () => {
    const full = peak(60);
    const short = peak(3);
    assert.ok(short < full * 0.6, `corto ${Math.round(short)} px, pieno ${Math.round(full)} px`);
  });

  it("tenendo il salto l'altezza è quella di sempre", () => {
    const speed = FIGHTER.jumpSpeed;
    const expected = (speed * speed) / (2 * FIGHTER.gravity); // circa 160 px
    assert.ok(Math.abs(peak(60) - expected) < 20);
  });

  it("lasciare il salto durante il recupero non accorcia il recupero", () => {
    const { ctx, f } = setup();
    press(f, { jump: true });
    run(f, ctx, 3);
    press(f, { jump: true, up: true, heavy: true });
    run(f, ctx, 1);
    const recoveryVy = f.vy;
    press(f, { up: true });
    run(f, ctx, 1);
    assert.ok(f.vy < recoveryVy * FIGHTER.shortHopCut - 1, "nessun taglio della spinta del recupero");
  });

  it("chi non usa il salto corto (i bot) salta sempre pieno anche con un tocco", () => {
    assert.ok(Math.abs(peak(1, false) - peak(60)) < 1);
  });
});

describe("influenza in volo", () => {
  // Velocità orizzontale dopo mezzo secondo di volo stordito verso destra, tenendo i tasti dati
  function driftAfterHit(keys: Partial<InputState>): number {
    const { ctx, f } = setup();
    Object.assign(f, { x: 640, y: 200, vx: 600, vy: -400, onGround: false, hitstunTimer: 600 });
    press(f, keys);
    run(f, ctx, 30);
    return f.vx;
  }

  it("tenendo la direzione opposta si rallenta il volo, tenendo la stessa si va più lontano", () => {
    const none = driftAfterHit({});
    const back = driftAfterHit({ left: true });
    const forward = driftAfterHit({ right: true });
    assert.ok(back < none - 200, `indietro ${Math.round(back)}, senza ${Math.round(none)}`);
    assert.ok(forward > none + 200, `avanti ${Math.round(forward)}, senza ${Math.round(none)}`);
  });
});
