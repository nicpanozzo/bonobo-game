// Test dello scatto con doppio tocco (#199). Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, DASH, FIGHTER, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const SQUAT = Math.round(FIGHTER.jumpSquatMs / DT); // tick di preparazione al salto (#384 A3)
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040

function setup(x = 400) {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "a", name: "A", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  f.x = x;
  f.dashByTap = true; // il meccanismo si prova anche finché DASH.byTap è spento
  run([f], ctx, 20); // a terra
  ctx.events.length = 0;
  return { ctx, f };
}

function run(fs: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fs, DT, ctx);
}

const hold = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const dashes = (events: GameEvent[]) => events.filter((e) => e.type === "dash").length;

// Tocca la direzione per `ticks` tick, poi la lascia per `gap` tick
function tap(f: Fighter, ctx: PhysicsContext, key: "left" | "right", ticks = 3, gap = 4) {
  hold(f, { [key]: true });
  run([f], ctx, ticks);
  hold(f, {});
  run([f], ctx, gap);
}

describe("scatto con doppio tocco", () => {
  it("due tocchi in fretta fanno scattare per circa 270 pixel, anche lasciando il tasto", () => {
    const { ctx, f } = setup();
    tap(f, ctx, "right");
    hold(f, { right: true });
    run([f], ctx, 1);
    assert.equal(dashes(ctx.events), 1);
    assert.equal(f.dashing, true);
    const x = f.x;
    hold(f, {});
    run([f], ctx, Math.ceil(DASH.durationMs / DT) + 5);
    const expected = DASH.speed * (DASH.durationMs / 1000);
    assert.ok(Math.abs(f.x - x - expected) < 40, `percorsi ${Math.round(f.x - x)} px, attesi circa ${expected}`);
    assert.equal(f.dashing, false, "lasciato il tasto, finito lo scatto si cammina di nuovo");
  });

  it("due tocchi troppo lenti non scattano", () => {
    const { ctx, f } = setup();
    tap(f, ctx, "right", 3, Math.ceil(DASH.doubleTapMs / DT) + 4);
    tap(f, ctx, "right");
    assert.equal(dashes(ctx.events), 0);
  });

  it("un primo tocco tenuto a lungo è una camminata e non conta", () => {
    const { ctx, f } = setup();
    tap(f, ctx, "right", Math.ceil(DASH.tapMaxMs / DT) + 3, 3);
    tap(f, ctx, "right");
    assert.equal(dashes(ctx.events), 0);
  });

  it("chi ha il doppio tocco spento (i bot) non scatta", () => {
    const { ctx, f } = setup();
    f.dashByTap = false;
    tap(f, ctx, "right");
    tap(f, ctx, "right");
    assert.equal(dashes(ctx.events), 0);
  });

  it("tocchi in direzioni diverse non scattano", () => {
    const { ctx, f } = setup(600);
    tap(f, ctx, "right");
    tap(f, ctx, "left");
    assert.equal(dashes(ctx.events), 0);
  });

  it("tenendo premuto dopo lo scatto si corre più veloce della camminata", () => {
    const { ctx, f } = setup(300);
    tap(f, ctx, "right");
    hold(f, { right: true });
    run([f], ctx, Math.ceil(DASH.durationMs / DT) + 10);
    assert.equal(f.dashing, true);
    assert.equal(f.vx, DASH.runSpeed);
    assert.ok(DASH.runSpeed > FIGHTER.groundSpeed);
  });

  it("girarsi ferma lo scatto", () => {
    const { ctx, f } = setup(600);
    tap(f, ctx, "right");
    hold(f, { right: true });
    run([f], ctx, 3);
    hold(f, { left: true });
    run([f], ctx, 1);
    assert.equal(f.dashing, false);
    assert.equal(f.vx, -FIGHTER.groundSpeed);
  });

  it("in aria non si scatta, e saltando lo scatto finisce", () => {
    const { ctx, f } = setup();
    tap(f, ctx, "right");
    hold(f, { right: true, jump: true });
    run([f], ctx, 3 + SQUAT);
    assert.equal(f.onGround, false);
    assert.equal(f.dashing, false);
  });
});

describe("tasto corsa", () => {
  function setupRun(x = 300) {
    const { ctx, f } = setup(x);
    f.dashByTap = false; // come i giocatori oggi: niente doppio tocco
    return { ctx, f };
  }

  it("corsa con una direzione scatta subito e poi corre", () => {
    const { ctx, f } = setupRun();
    hold(f, { right: true, run: true });
    run([f], ctx, 1);
    assert.equal(dashes(ctx.events), 1);
    assert.equal(f.vx, DASH.speed);
    run([f], ctx, Math.ceil(DASH.durationMs / DT) + 5);
    assert.equal(f.vx, DASH.runSpeed);
  });

  it("lasciata la corsa si torna a camminare", () => {
    const { ctx, f } = setupRun();
    hold(f, { right: true, run: true });
    run([f], ctx, Math.ceil(DASH.durationMs / DT) + 5);
    hold(f, { right: true });
    run([f], ctx, 1);
    assert.equal(f.dashing, false);
    assert.equal(f.vx, FIGHTER.groundSpeed);
  });

  it("corsa da sola, senza direzione, non muove", () => {
    const { ctx, f } = setupRun();
    hold(f, { run: true });
    run([f], ctx, 5);
    assert.equal(dashes(ctx.events), 0);
    assert.equal(f.vx, 0);
  });

  it("il pesante correndo è l'attacco in corsa e scivola in avanti", () => {
    const { ctx, f } = setupRun();
    hold(f, { right: true, run: true });
    run([f], ctx, 10);
    hold(f, { right: true, run: true, heavy: true });
    run([f], ctx, 1);
    assert.equal(f.attack, "dashAttack");
    assert.equal(f.smashChargeMs, -1, "l'attacco in corsa non si carica");
    const x = f.x;
    run([f], ctx, 3);
    assert.equal(f.vx, DASH.attackSlide);
    assert.ok(f.x > x + 20);
    hold(f, {});
    run([f], ctx, Math.ceil((ATTACKS.dashAttack.startupMs + ATTACKS.dashAttack.activeMs) / DT));
    assert.equal(f.vx, 0, "finito il colpo ci si ferma");
  });

  it("il pesante camminando resta il pesante", () => {
    const { ctx, f } = setupRun();
    hold(f, { right: true });
    run([f], ctx, 10);
    hold(f, { right: true, heavy: true });
    run([f], ctx, 1);
    assert.equal(f.attack, "heavy");
  });
});
