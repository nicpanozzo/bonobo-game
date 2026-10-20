// Test della sensazione del movimento: tempo di grazia sul bordo, salto corto, influenza in volo.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { bufferPresses, createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

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

describe("preparazione al salto e atterraggio, come Smash (#384 A3)", () => {
  const SQUAT = Math.round(FIGHTER.jumpSquatMs / DT); // 3 tick
  // Fermi a terra sul palco
  function standing() {
    const { ctx, f } = setup();
    run(f, ctx, 30);
    ctx.events.length = 0;
    f.landingTimer = 0;
    return { ctx, f };
  }
  // Un tasto nuovo come lo manda la rete: col buffer (Match.setInput)
  const send = (f: Fighter, keys: Partial<InputState>) => {
    const next = { ...emptyInput(), ...keys };
    bufferPresses(f, next);
    f.input = next;
  };

  it("da terra ci si stacca dopo 3 fotogrammi, e intanto si resta a terra", () => {
    const { ctx, f } = standing();
    send(f, { jump: true });
    for (let i = 0; i < SQUAT; i++) {
      run(f, ctx, 1);
      assert.equal(f.onGround, true, `tick ${i}: ancora a terra`);
      assert.ok(f.jumpSquatTimer > 0);
    }
    assert.equal(jumps(ctx.events).length, 0);
    run(f, ctx, 1);
    assert.equal(f.onGround, false);
    assert.ok(f.vy < 0);
    assert.equal(f.jumpSquatTimer, 0);
    assert.equal(jumps(ctx.events).length, 1);
    assert.equal(f.jumpsLeft, FIGHTER.maxJumps - 1);
  });

  it("lasciando il salto prima della fine si fa il salto corto", () => {
    const heights = [true, false].map((held) => {
      const { ctx, f } = standing();
      send(f, { jump: true });
      run(f, ctx, 1);
      if (!held) send(f, {});
      const y0 = f.y;
      let top = f.y;
      for (let i = 0; i < 60; i++) {
        run(f, ctx, 1);
        top = Math.min(top, f.y);
      }
      return y0 - top;
    });
    assert.ok(heights[1] < heights[0] * 0.5, `corto ${heights[1]}, pieno ${heights[0]}`);
  });

  it("un attacco premuto durante la preparazione parte in aria appena staccati", () => {
    const { ctx, f } = standing();
    send(f, { jump: true });
    run(f, ctx, 1);
    send(f, { jump: true, light: true });
    run(f, ctx, 1);
    assert.equal(f.attack, null, "a terra non parte niente");
    run(f, ctx, SQUAT);
    assert.equal(f.attack, "lightAir");
    assert.equal(f.attackAir, true);
  });

  it("atterrando ci si ferma per FIGHTER.landingLagMs, poi si cammina", () => {
    const { ctx, f } = standing();
    f.y -= 100;
    f.onGround = false;
    send(f, { right: true });
    for (let i = 0; i < 60 && !f.onGround; i++) run(f, ctx, 1);
    assert.equal(f.landingTimer, FIGHTER.landingLagMs);
    const x = f.x;
    run(f, ctx, Math.round(FIGHTER.landingLagMs / DT) - 1);
    assert.equal(f.x, x, "fermi durante la pausa");
    run(f, ctx, 2);
    assert.ok(f.x > x, "poi si cammina");
  });

  it("atterrando a metà di un attacco in aria il colpo si interrompe con la sua pausa", () => {
    const { ctx, f } = standing();
    f.y -= 40;
    f.onGround = false;
    send(f, { heavy: true });
    run(f, ctx, 1);
    assert.equal(f.attack, "heavyAir");
    for (let i = 0; i < 60 && !f.onGround; i++) run(f, ctx, 1);
    assert.equal(f.attack, null);
    const lag = ATTACKS.heavyAir.landingLagMs ?? 0;
    assert.equal(f.landingTimer, lag);
    assert.equal(f.cooldownTimer, 0, "la pausa prende il posto del resto del colpo");
    run(f, ctx, Math.round(lag / DT) - 2);
    send(f, { light: true });
    run(f, ctx, 1);
    assert.equal(f.attack, null, "durante la pausa niente attacchi");
    run(f, ctx, 2);
    assert.equal(f.attack, "light", "il tasto premuto alla fine della pausa parte subito dopo (buffer)");
  });
});
