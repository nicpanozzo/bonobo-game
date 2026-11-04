// Test dell'ancora-ragnatela di Capt. OrsoBlu (#547): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ANCHOR, TICK_RATE } from "../constants";
import { getStage, type StageSpec } from "../stages";
import type { InputState } from "../types";
import { hookable } from "./anchor";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
// Un soffitto pieno sopra il vuoto e un pavimento lontano sotto: c'è spazio per dondolare
const base = getStage(undefined);
const stage: StageSpec = {
  ...base,
  id: "soffitto",
  solids: [
    { x: 300, y: 100, width: 700, height: 40 },
    { x: 0, y: 1200, width: 1400, height: 100 },
  ],
  platforms: [],
  blastZone: { left: -1000, right: 2400, top: -1000, bottom: 2000 },
};

function setup(characterId = "orsoblu") {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p", name: "P", characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);
  f.x = 640;
  f.y = 420; // le mani a 340, 200 pixel sotto il soffitto
  f.onGround = false;
  f.jumpsLeft = 1;
  return { ctx, f };
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
function run(f: Fighter, ctx: PhysicsContext, ticks: number, keys: Partial<InputState> = {}) {
  for (let i = 0; i < ticks; i++) {
    press(f, keys);
    stepWorld([f], DT, ctx);
  }
}
const ropeLen = (f: Fighter) => Math.hypot(f.x - f.anchor!.x, f.y - ANCHOR.gripY - f.anchor!.y);

// Lancia l'ancora (Pesante + su in aria) e aspetta che si pianti
function hook(f: Fighter, ctx: PhysicsContext, keys: Partial<InputState> = {}) {
  run(f, ctx, 1, { up: true, heavy: true, ...keys });
  for (let i = 0; i < 30 && f.anchor?.phase === "fly"; i++) run(f, ctx, 1, keys);
}

describe("ancora di Capt. OrsoBlu", () => {
  it("si pianta solo in blocchi e piattaforme", () => {
    const ctx: PhysicsContext = { stage: { ...stage, platforms: [{ x: 0, y: 600, width: 100 }] }, events: [] };
    assert.equal(hookable(500, 120, ctx), true);
    assert.equal(hookable(500, 300, ctx), false);
    assert.equal(hookable(50, 603, ctx), true);
    assert.equal(hookable(50, 640, ctx), false);
  });

  it("su + pesante in aria spara l'ancora invece di spingere in alto, e frena la caduta", () => {
    const { ctx, f } = setup();
    f.vy = 600;
    run(f, ctx, 1, { up: true, heavy: true });
    assert.equal(f.anchor?.phase, "fly");
    assert.equal(f.attack, "recovery");
    assert.equal(f.helpless, false);
    assert.ok(f.vy < 0 && f.vy > -ANCHOR.throwLift * 1.01, "frena senza la spinta del recupero comune");
  });

  it("piantata nel soffitto resta appeso, con la catena mai più lunga del lancio", () => {
    const { ctx, f } = setup();
    hook(f, ctx);
    assert.equal(f.anchor?.phase, "hold");
    assert.ok(f.anchor!.y >= 100 && f.anchor!.y <= 140);
    assert.equal(f.attack, null, "da appeso si può già attaccare");
    run(f, ctx, 60);
    assert.ok(ropeLen(f) <= f.anchorLen + 0.01);
    assert.ok(f.y < 600, "non cade");
  });

  it("tenendo avanti dondola sempre più in là: è un pendolo", () => {
    const { ctx, f } = setup();
    hook(f, ctx);
    const x0 = f.anchor!.x;
    let far = 0;
    for (let i = 0; i < 120; i++) {
      run(f, ctx, 1, { right: f.vx >= 0, left: f.vx < 0 });
      far = Math.max(far, Math.abs(f.x - x0));
    }
    assert.ok(far > 120, `oscilla lontano dal punto sotto l'ancora (${far.toFixed(0)} px)`);
    assert.ok(onRopePhase(f));
  });

  it("su si arrampica e giù si cala, entro i limiti della catena", () => {
    const { ctx, f } = setup();
    hook(f, ctx);
    const len = f.anchorLen;
    run(f, ctx, 20, { up: true });
    assert.equal(f.anchor?.phase, "climb");
    assert.ok(f.anchorLen < len - 80);
    run(f, ctx, 120, { up: true });
    assert.equal(f.anchorLen, ANCHOR.minLength);
    f.anchorMs = 0; // il tempo appesi qui non conta
    run(f, ctx, 90, { down: true });
    assert.equal(f.anchorLen, ANCHOR.maxLength);
  });

  it("col salto si stacca tenendo lo slancio, con una spinta in alto, e il doppio salto resta", () => {
    const { ctx, f } = setup();
    hook(f, ctx);
    for (let i = 0; i < 60; i++) run(f, ctx, 1, { right: true });
    const vx = f.vx;
    run(f, ctx, 1, { right: true, jump: true });
    assert.equal(f.anchor, undefined);
    assert.ok(f.vy <= -ANCHOR.releaseBoost);
    assert.ok(Math.abs(f.vx - vx) < 80, "tiene lo slancio orizzontale");
    assert.equal(f.jumpsLeft, 1);
  });

  it("lo scudo lascia andare senza schivare", () => {
    const { ctx, f } = setup();
    hook(f, ctx);
    run(f, ctx, 5);
    run(f, ctx, 1, { shield: true });
    assert.equal(f.anchor, undefined);
    assert.equal(f.airDodgeUsed, false);
  });

  it("leggero e pesante da appeso fanno l'attacco in aria, restando appeso", () => {
    const { ctx, f } = setup();
    hook(f, ctx);
    run(f, ctx, 5);
    run(f, ctx, 1, { light: true });
    assert.equal(f.attack, "lightAir");
    assert.ok(f.anchor);
  });

  it("nel vuoto l'ancora torna in mano; due lanci, poi basta fino a terra", () => {
    const { ctx, f } = setup();
    f.y = 1000;
    f.x = 1200; // sotto non c'è soffitto: a destra del blocco
    run(f, ctx, 1, { up: true, heavy: true, right: true });
    for (let i = 0; i < 60 && f.anchor; i++) run(f, ctx, 1);
    assert.equal(f.anchor, undefined);
    run(f, ctx, 1, { up: true, heavy: true });
    assert.ok(f.anchor);
    for (let i = 0; i < 60 && f.anchor; i++) run(f, ctx, 1);
    run(f, ctx, 1, { up: true, heavy: true });
    assert.equal(f.anchor, undefined, "il terzo lancio non parte");
  });

  it("dopo maxHangMs lascia la catena da solo", () => {
    const { ctx, f } = setup();
    hook(f, ctx);
    run(f, ctx, Math.ceil(ANCHOR.maxHangMs / DT) + 2);
    assert.equal(f.anchor, undefined);
  });

  it("Avanti tutta!: da appeso la speciale sfreccia verso l'ancora, già attiva, e poi resta appeso in cima", () => {
    const { ctx, f } = setup();
    f.x = 400; // in diagonale sotto il soffitto: la catena è lunga
    f.y = 480;
    hook(f, ctx, { right: true });
    assert.equal(f.anchor?.phase, "hold");
    const before = ropeLen(f);
    run(f, ctx, 1, { special: true });
    assert.equal(f.attack, "specialSide");
    assert.equal(f.attackActive, true, "travolge subito chi c'è in mezzo");
    assert.ok(f.anchorZip);
    for (let i = 0; i < 40 && f.anchorZip; i++) run(f, ctx, 1);
    assert.equal(f.anchorZip, false);
    assert.ok(before - ANCHOR.minLength > 150, "è partito lontano");
    assert.ok(Math.abs(ropeLen(f) - ANCHOR.minLength) < 30, `arrivato in cima (${ropeLen(f).toFixed(0)} px)`);
    assert.equal(f.attack, null);
    assert.ok(f.anchor, "resta appeso");
  });

  it("Avanti tutta! colpisce chi sta lungo la catena", () => {
    const { ctx, f } = setup();
    f.x = 400;
    f.y = 480;
    hook(f, ctx, { right: true });
    const o = createFighter({ id: "o", name: "O", characterId: "default", color: 0, team: 0, index: 1, stocks: 3 }, stage);
    const t = 0.5; // a metà strada tra le mani e l'ancora
    o.x = f.x + (f.anchor!.x - f.x) * t;
    o.y = f.y + (f.anchor!.y + ANCHOR.gripY - f.y) * t;
    o.onGround = false;
    press(f, { special: true });
    for (let i = 0; i < 30; i++) {
      o.vx = o.vy = 0; // fermo a mezz'aria
      stepWorld([f, o], DT, ctx);
      press(f, {});
    }
    assert.ok(o.percent > 0, "preso dalla teleferica");
  });

  it("chi non ha l'ancora fa il recupero di sempre", () => {
    const { ctx, f } = setup("default");
    run(f, ctx, 1, { up: true, heavy: true });
    assert.equal(f.anchor, undefined);
    assert.ok(f.vy < -800);
    assert.equal(f.helpless, true);
  });
});

const onRopePhase = (f: Fighter) => f.anchor?.phase === "hold" || f.anchor?.phase === "climb";
