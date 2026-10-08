// Test delle mosse speciali (E10 passo 2): scatto e contrattacco. Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { specialsFor } from "../characters";
import { ATTACKS, FIGHTER, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560
const dash = specialsFor("default").side;
const counter = specialsFor("default").down;
if (dash.type !== "dash" || counter.type !== "counter") throw new Error("il personaggio base deve avere scatto e contrattacco");

// a guarda a destra, b gli sta davanti girato verso di lui
function setup(gap = 10) {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [0, 1].map((i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  const [a, b] = fighters;
  a.x = 500;
  a.facing = 1;
  b.x = 500 + FIGHTER.width + gap;
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
const ticks = (ms: number) => Math.ceil(ms / DT);

describe("scatto", () => {
  it("percorre circa 225 pixel e colpisce chi incontra", () => {
    const { ctx, fighters, a, b } = setup();
    b.x = 1000; // lontano: lo scatto va a vuoto
    const x = a.x;
    press(a, { right: true, special: true });
    run(fighters, ctx, 1);
    press(a, {});
    run(fighters, ctx, ticks(dash.startupMs + dash.durationMs + dash.endLagMs) + 5);
    assert.ok(Math.abs(a.x - x - dash.speed * (dash.durationMs / 1000)) <= 10, `percorsi ${a.x - x} px`);
    assert.equal(ofType(ctx.events, "attack")[0]?.kind, "specialSide");
  });

  it("colpisce chi sta sulla strada", () => {
    const { ctx, fighters, a, b } = setup(80);
    press(a, { right: true, special: true });
    run(fighters, ctx, 1);
    press(a, {});
    run(fighters, ctx, ticks(dash.startupMs + dash.durationMs));
    const hit = ofType(ctx.events, "hit")[0];
    assert.equal(hit?.kind, "specialSide");
    assert.equal(b.percent, dash.damage);
  });

  it("si gira verso la direzione tenuta e in aria si fa una volta sola", () => {
    const { ctx, fighters, a } = setup();
    a.x = 900; // verso sinistra c'è tutto il palco sotto
    a.y = 40; // in alto: lo scatto e l'attesa finiscono prima di atterrare
    a.onGround = false;
    press(a, { left: true, special: true });
    run(fighters, ctx, 1);
    assert.equal(a.facing, -1);
    assert.equal(a.attack, "specialSide");
    press(a, {});
    run(fighters, ctx, ticks(dash.startupMs + dash.durationMs + dash.endLagMs) + 2);
    assert.equal(a.onGround, false, "ancora in aria");
    press(a, { left: true, special: true });
    run(fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "attack").length, 1, "il secondo scatto in aria non parte");
    press(a, {});
    run(fighters, ctx, 120); // atterra
    assert.equal(a.onGround, true);
    press(a, { left: true, special: true });
    run(fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "attack").length, 2, "dopo l'atterraggio si può di nuovo");
  });
});

describe("contrattacco", () => {
  // b alza il contrattacco, a tira un pesante che arriva nella finestra
  function counterVsHeavy() {
    const s = setup();
    press(s.b, { down: true, special: true });
    run(s.fighters, s.ctx, 1);
    press(s.b, {});
    press(s.a, { heavy: true });
    run(s.fighters, s.ctx, 1);
    press(s.a, {});
    run(s.fighters, s.ctx, ticks(ATTACKS.heavy.startupMs) + 5);
    return s;
  }

  it("rimanda indietro il colpo e lascia la percentuale com'era", () => {
    assert.ok(ATTACKS.heavy.startupMs < counter.startupMs + counter.windowMs, "il pesante arriva nella finestra");
    const { ctx, a, b } = counterVsHeavy();
    assert.equal(b.percent, 0, "chi contrattacca non prende niente");
    const ev = ofType(ctx.events, "counter");
    assert.equal(ev.length, 1);
    assert.deepEqual(ev[0], { ...ev[0], id: "p1", attackerId: "p0" });
    const hit = ofType(ctx.events, "hit")[0];
    assert.equal(hit?.targetId, "p0");
    assert.equal(hit?.kind, "specialDown");
    const answer = Math.max(counter.minDamage, ATTACKS.heavy.damage * counter.multiplier);
    assert.ok(Math.abs(a.percent - answer) < 0.05, `${a.percent} invece di ${answer}`);
    assert.ok(a.vx < 0, "a vola via all'indietro");
  });

  it("a vuoto lascia fermi per l'attesa finale", () => {
    const { ctx, fighters, b } = setup();
    fighters[0].x = 300; // a lontano: niente da parare
    press(b, { down: true, special: true });
    run(fighters, ctx, 1);
    press(b, { right: true });
    const x = b.x;
    run(fighters, ctx, ticks(counter.startupMs + counter.windowMs + counter.endLagMs) - 2);
    assert.equal(b.x, x, `fermo per ${counter.startupMs + counter.windowMs + counter.endLagMs} ms`);
    run(fighters, ctx, 10);
    assert.ok(b.x > x, "poi si muove");
  });

  it("la presa lo batte", () => {
    const { ctx, fighters, a, b } = setup();
    press(b, { down: true, special: true });
    run(fighters, ctx, 1);
    press(b, {});
    press(a, { shield: true, light: true });
    run(fighters, ctx, 1);
    press(a, {});
    run(fighters, ctx, ticks(ATTACKS.grab.startupMs + ATTACKS.grab.activeMs) + 1);
    assert.equal(b.grabbedBy, "p0");
    assert.equal(ofType(ctx.events, "counter").length, 0);
  });
});
