// Test della presa e dei lanci (#109, E8 passo 2): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, GRAB, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560

// a guarda a destra, b gli sta davanti girato verso di lui
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
const startupTicks = Math.ceil((ATTACKS.grab.startupMs + ATTACKS.grab.activeMs) / DT) + 1;

// a afferra b: scudo + leggero, poi lascia i tasti
function grab(fighters: Fighter[], ctx: PhysicsContext, a: Fighter) {
  press(a, { shield: true, light: true });
  run(fighters, ctx, 1);
  press(a, {});
  run(fighters, ctx, startupTicks);
}

// Tick finché b non si libera da solo (con o senza tasti premuti)
function ticksToEscape(mash: boolean): number {
  const { ctx, fighters, a, b } = setup();
  grab(fighters, ctx, a);
  assert.equal(b.grabbedBy, a.id);
  for (let t = 1; t < 1000; t++) {
    if (mash) press(b, t % 2 ? { left: true, light: true } : {});
    run(fighters, ctx, 1);
    if (b.grabbedBy === null) return t;
  }
  throw new Error("mai liberato");
}

describe("presa", () => {
  it("passa lo scudo", () => {
    const { ctx, fighters, a, b } = setup();
    press(b, { shield: true });
    run(fighters, ctx, 3);
    assert.equal(b.shielding, true);
    grab(fighters, ctx, a);
    const grabs = ofType(ctx.events, "grab");
    assert.equal(grabs.length, 1);
    assert.deepEqual(grabs[0], { ...grabs[0], id: "p0", targetId: "p1" });
    assert.equal(b.grabbedBy, "p0");
    assert.equal(a.holding, "p1");
    assert.equal(b.shielding, false);
    assert.equal(b.x, a.x + GRAB.holdDistance, "chi è tenuto sta davanti");
  });

  it("non prende chi sta schivando", () => {
    const { ctx, fighters, a, b } = setup();
    press(a, { shield: true, light: true });
    press(b, { dodge: true });
    run(fighters, ctx, 1);
    press(a, {});
    press(b, {});
    run(fighters, ctx, startupTicks);
    assert.equal(ofType(ctx.events, "grab").length, 0);
    assert.equal(b.grabbedBy, null);
  });

  it("a vuoto resta fermo per un po'", () => {
    const { ctx, fighters, a, b } = setup();
    b.x = a.x + 300; // troppo lontano
    grab(fighters, ctx, a);
    assert.equal(ofType(ctx.events, "grab").length, 0);
    const x = a.x;
    press(a, { right: true });
    run(fighters, ctx, Math.floor(GRAB.whiffLagMs / DT) - startupTicks);
    assert.equal(a.x, x, "fermo durante l'attesa");
    run(fighters, ctx, startupTicks + 10);
    assert.ok(a.x > x, "poi si muove");
  });

  it("a 0% chi preme tasti si libera prima", () => {
    const still = ticksToEscape(false);
    const mash = ticksToEscape(true);
    assert.ok(Math.abs(still * DT - GRAB.holdBaseMs) < 2 * DT, `fermo si libera in ~${GRAB.holdBaseMs} ms, non ${still * DT}`);
    assert.ok(mash < still * 0.7, `premendo ${mash} tick, fermo ${still}`);
  });

  it("il colpetto aggiunge percentuale senza lanciare", () => {
    const { ctx, fighters, a, b } = setup();
    grab(fighters, ctx, a);
    press(a, { light: true });
    run(fighters, ctx, 1);
    assert.equal(b.percent, GRAB.pummelDamage);
    assert.equal(b.grabbedBy, "p0");
    run(fighters, ctx, 2); // tenendo premuto non si ripete
    assert.equal(b.percent, GRAB.pummelDamage);
  });

  it("throwBack manda il bersaglio dalla parte opposta a facing", () => {
    const { ctx, fighters, a, b } = setup();
    grab(fighters, ctx, a);
    press(a, { left: true }); // a guarda a destra: sinistra è indietro
    run(fighters, ctx, 1);
    const hit = ofType(ctx.events, "hit").at(-1);
    assert.equal(hit?.kind, "throwBack");
    assert.equal(b.grabbedBy, null);
    assert.ok(b.vx < 0, `vx ${b.vx}`);
    assert.equal(b.percent, ATTACKS.throwBack.damage);
    run(fighters, ctx, 20);
    assert.ok(b.x < a.x, "finisce dietro a chi lancia");
  });

  it("i quattro lanci partono nella direzione tenuta", () => {
    const cases: [Partial<InputState>, string, (b: Fighter) => boolean][] = [
      [{ right: true }, "throwForward", (b) => b.vx > 0 && b.vy < 0],
      [{ left: true }, "throwBack", (b) => b.vx < 0],
      [{ up: true }, "throwUp", (b) => b.vy < 0 && Math.abs(b.vx) < -b.vy / 10],
      [{ down: true }, "throwDown", (b) => b.vy < 0],
    ];
    for (const [keys, kind, ok] of cases) {
      const { ctx, fighters, a, b } = setup();
      grab(fighters, ctx, a);
      press(a, keys);
      run(fighters, ctx, 1);
      assert.equal(ofType(ctx.events, "hit").at(-1)?.kind, kind);
      assert.ok(ok(b), `${kind}: vx ${b.vx} vy ${b.vy}`);
    }
  });

  it("un colpo e una presa nello stesso tick: vince il colpo", () => {
    const { ctx, fighters, a, b } = setup();
    // Le due mosse diventano attive nello stesso tick
    a.attack = "grab";
    a.attackTimer = ATTACKS.grab.startupMs - DT / 2;
    a.grabLagTimer = GRAB.whiffLagMs;
    b.attack = "light";
    b.attackTimer = ATTACKS.light.startupMs - DT / 2;
    run(fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "grab").length, 0);
    assert.equal(ofType(ctx.events, "hit")[0]?.targetId, "p0");
    assert.equal(b.grabbedBy, null);
  });

  it("un colpo di un terzo libera chi è tenuto", () => {
    const { ctx, fighters, a, b } = setup();
    const c = createFighter({ id: "p2", name: "P2", characterId: "default", color: 0, team: 0, index: 2, stocks: 3 }, stage);
    c.x = 1000; // lontano finché non serve
    fighters.push(c);
    run(fighters, ctx, 10);
    grab(fighters, ctx, a);
    assert.equal(b.grabbedBy, "p0");
    c.x = b.x + FIGHTER.width + 10;
    c.y = b.y;
    c.onGround = true;
    c.facing = -1;
    press(c, { light: true });
    run(fighters, ctx, 1);
    press(c, {});
    run(fighters, ctx, 10);
    assert.equal(b.grabbedBy, null);
    assert.equal(a.holding, null);
    assert.ok(b.percent > 0);
  });
});
