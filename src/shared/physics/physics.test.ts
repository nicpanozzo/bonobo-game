// Test della fisica: logica pura, quindi si prova senza server né browser.
// Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, RESPAWN_MS, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

function setup(count = 1, canHit?: PhysicsContext["canHit"]) {
  const ctx: PhysicsContext = { stage, events: [], canHit };
  const fighters = Array.from({ length: count }, (_, i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  return { ctx, fighters };
}

function press(f: Fighter, keys: Partial<InputState>) {
  f.input = { ...emptyInput(), ...keys };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

const ofType = <T extends GameEvent["type"]>(events: GameEvent[], type: T) =>
  events.filter((e): e is Extract<GameEvent, { type: T }> => e.type === type);

describe("movimento", () => {
  it("resta fermo sul palco senza tasti", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    const start = { x: f.x, y: f.y };
    run(fighters, ctx, 60);
    assert.deepEqual({ x: f.x, y: f.y }, start);
    assert.equal(f.onGround, true);
    assert.equal(ctx.events.length, 0);
  });

  it("salto e doppio salto, non un terzo", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    press(f, { up: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, 5);
    press(f, { up: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, 5);
    press(f, { up: true });
    run(fighters, ctx, 1);
    const jumps = ofType(ctx.events, "jump");
    assert.equal(jumps.length, 2);
    assert.deepEqual(jumps.map((j) => j.air), [false, true]);
  });

  it("dopo il salto riatterra sul palco con l'evento land", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    f.x = stage.solids[0].x + 30; // lontano dalle piattaforme sottili
    const groundY = f.y;
    press(f, { up: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, 120);
    assert.equal(f.onGround, true);
    assert.equal(f.y, groundY);
    assert.equal(ofType(ctx.events, "land").length, 1);
  });

  it("con giù si scende dalla piattaforma sottile", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    const p = stage.platforms[0];
    Object.assign(f, { x: p.x + p.width / 2, y: p.y, onGround: true });
    run(fighters, ctx, 10);
    assert.equal(f.y, p.y, "ci sta sopra");
    press(f, { down: true });
    run(fighters, ctx, 10);
    assert.ok(f.y > p.y, "l'ha attraversata");
  });
});

describe("attacchi", () => {
  function facingPair() {
    const s = setup(2);
    const [a, b] = s.fighters;
    a.x = 600;
    b.x = 600 + FIGHTER.width + 20;
    a.facing = 1;
    return { ...s, a, b };
  }

  it("il leggero colpisce chi è davanti e lo manda via", () => {
    const { ctx, fighters, a, b } = facingPair();
    const startX = b.x;
    press(a, { light: true });
    run(fighters, ctx, 15);
    const hits = ofType(ctx.events, "hit");
    assert.equal(hits.length, 1, "un colpo solo per attacco");
    assert.equal(hits[0].attackerId, a.id);
    assert.equal(b.percent, ATTACKS.light.damage);
    assert.ok(b.x > startX, "vola nella direzione del colpo");
    assert.equal(ofType(ctx.events, "attack").length, 1);
  });

  it("canHit può impedire il colpo (fuoco amico)", () => {
    const { ctx, fighters, a, b } = facingPair();
    ctx.canHit = () => false;
    press(a, { light: true });
    run(fighters, ctx, 15);
    assert.equal(b.percent, 0);
    assert.equal(ofType(ctx.events, "hit").length, 0);
  });
});

describe("KO e respawn", () => {
  it("chi esce dalla zona di espulsione perde una vita e il KO va a chi l'ha colpito", () => {
    const { ctx, fighters } = setup(2);
    const [f] = fighters;
    f.lastHitById = "p1";
    f.x = stage.blastZone.right + 10;
    run(fighters, ctx, 1);
    const [ko] = ofType(ctx.events, "ko");
    assert.equal(ko.id, f.id);
    assert.equal(ko.byId, "p1");
    assert.equal(f.stocks, 2);
    assert.equal(f.respawning, true);

    run(fighters, ctx, Math.ceil(RESPAWN_MS / DT) + 1);
    assert.equal(f.respawning, false);
    assert.equal(f.invulnerable, true);
    assert.equal(ofType(ctx.events, "respawn").length, 1);
  });

  it("all'ultima vita si è eliminati", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    f.stocks = 1;
    f.y = stage.blastZone.bottom + 10;
    run(fighters, ctx, 1);
    assert.equal(f.eliminated, true);
    assert.equal(ofType(ctx.events, "ko")[0].stocksLeft, 0);
  });
});
