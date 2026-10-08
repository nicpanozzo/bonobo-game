// Test di proiettili e carica (E10 passo 3). Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CHARACTERS, specialsFor } from "../characters";
import { CHARGE_EXAMPLE, FIGHTER, TICK_RATE } from "../constants";
import { Match } from "../match";
import { getStage } from "../stages";
import type { GameEvent, InputState, ProjectileState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560
const shot = specialsFor("default").neutral;
const counter = specialsFor("default").down;
if (shot.type !== "projectile" || counter.type !== "counter") throw new Error("il personaggio base deve avere tiro e contrattacco");
// Un personaggio solo per i test, con la carica di esempio sotto giù
CHARACTERS["prova-carica"] = { id: "prova-carica", name: "Prova carica", specials: { down: CHARGE_EXAMPLE } };

// a guarda a destra, b gli sta davanti girato verso di lui, a gap pixel
function setup(gap: number, characterId = "default") {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [0, 1].map((i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: i === 0 ? characterId : "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  const [a, b] = fighters;
  a.x = 400;
  a.facing = 1;
  b.x = 400 + FIGHTER.width + gap;
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

// f preme speciale per un tick
function tap(fighters: Fighter[], ctx: PhysicsContext, f: Fighter, keys: Partial<InputState> = {}) {
  press(f, { ...keys, special: true });
  run(fighters, ctx, 1);
  press(f, {});
}

describe("proiettili", () => {
  it("partono alla fine dell'avvio, volano e colpiscono chi trovano", () => {
    const { ctx, fighters, a, b } = setup(300);
    const bx = b.x;
    tap(fighters, ctx, a);
    run(fighters, ctx, ticks(shot.startupMs) - 2);
    assert.equal(ofType(ctx.events, "projectile").length, 0, "non prima dell'avvio");
    run(fighters, ctx, 3);
    assert.equal(ofType(ctx.events, "projectile").length, 1);
    assert.equal(ctx.projectiles?.list.length, 1);
    run(fighters, ctx, 60);
    const hit = ofType(ctx.events, "hit")[0];
    assert.equal(hit?.kind, "specialNeutral");
    assert.equal(b.percent, shot.damage);
    assert.ok(b.x > bx + 5, `vola nella direzione del proiettile (${b.x - bx} px)`);
    assert.deepEqual(ofType(ctx.events, "projectileEnd").map((e) => e.reason), ["hit"]);
    assert.equal(ctx.projectiles?.list.length, 0);
  });

  it("sullo scudo danno l'evento shield e spariscono", () => {
    const { ctx, fighters, a, b } = setup(300);
    press(b, { shield: true });
    tap(fighters, ctx, a);
    press(b, { shield: true });
    run(fighters, ctx, 60);
    assert.equal(ofType(ctx.events, "shield").length, 1);
    assert.equal(ofType(ctx.events, "projectileEnd")[0]?.reason, "blocked");
    assert.equal(b.percent, 0);
    assert.equal(ctx.projectiles?.list.length, 0);
  });

  it("maxAlive: con uno in volo il secondo non parte, quando sparisce sì", () => {
    const { ctx, fighters, a, b } = setup(0);
    b.x = 1000;
    a.x = 300; // verso destra c'è tutto il palco: il primo vola fino a sparire da solo
    tap(fighters, ctx, a);
    run(fighters, ctx, ticks(shot.cooldownMs) + 2);
    tap(fighters, ctx, a);
    run(fighters, ctx, ticks(shot.startupMs) + 2);
    assert.equal(ofType(ctx.events, "projectile").length, shot.maxAlive);
    run(fighters, ctx, ticks(shot.lifeMs));
    assert.equal(ctx.projectiles?.list.length, 0);
    tap(fighters, ctx, a);
    run(fighters, ctx, ticks(shot.startupMs) + 2);
    assert.equal(ofType(ctx.events, "projectile").length, shot.maxAlive + 1);
  });

  it("due proiettili di giocatori diversi si annullano", () => {
    const { ctx, fighters, a, b } = setup(400);
    press(a, { special: true });
    press(b, { special: true });
    run(fighters, ctx, 1);
    press(a, {});
    press(b, {});
    run(fighters, ctx, 60);
    assert.deepEqual(ofType(ctx.events, "projectileEnd").map((e) => e.reason), ["hit", "hit"]);
    assert.equal(ofType(ctx.events, "hit").length, 0);
  });

  it("il contrattacco lo rimanda indietro a chi l'ha tirato", () => {
    const { ctx, fighters, a, b } = setup(300);
    tap(fighters, ctx, a);
    run(fighters, ctx, ticks(shot.startupMs));
    tap(fighters, ctx, b, { down: true });
    run(fighters, ctx, 90);
    assert.equal(ofType(ctx.events, "counter").length, 1);
    assert.equal(b.percent, 0);
    assert.equal(a.percent, shot.damage);
    assert.equal(ofType(ctx.events, "hit")[0]?.attackerId, b.id);
  });

  it("lo stesso input dà le stesse posizioni in due partite", () => {
    const play = () => {
      const m = new Match();
      m.addPlayer("a", "A");
      m.addPlayer("b", "B");
      const seen: ProjectileState[][] = [];
      for (let i = 0; i < 240; i++) {
        const special = i % 50 === 0;
        m.setInput("a", { ...emptyInput(), special, right: i % 100 < 50 });
        m.setInput("b", { ...emptyInput(), special: i % 70 === 0, left: i % 90 < 30 });
        m.step(DT);
        seen.push(m.snapshot([], i).projectiles);
      }
      return seen;
    };
    const first = play();
    assert.ok(first.some((list) => list.length > 0), "qualche proiettile è partito");
    assert.deepEqual(play(), first);
  });
});

describe("carica", () => {
  it("piena fa 18% (10% per 1,8)", () => {
    const { ctx, fighters, a, b } = setup(10, "prova-carica");
    press(a, { down: true, special: true });
    run(fighters, ctx, ticks(CHARGE_EXAMPLE.maxMs) - 5);
    assert.ok(a.charge > 0.9, `carica ${a.charge}`);
    assert.equal(ofType(ctx.events, "hit").length, 0, "mentre si carica non colpisce");
    run(fighters, ctx, 20); // tenendo premuto parte da sola a maxMs
    const hit = ofType(ctx.events, "hit")[0];
    assert.ok(hit && Math.abs(hit.damage - 18) <= 0.5, `danno ${hit?.damage}`);
    assert.equal(a.charge, 0);
  });

  it("rilasciata subito fa circa il danno base, dopo minMs", () => {
    const { ctx, fighters, a, b } = setup(10, "prova-carica");
    tap(fighters, ctx, a, { down: true });
    run(fighters, ctx, ticks(CHARGE_EXAMPLE.minMs) - 2);
    assert.equal(ofType(ctx.events, "hit").length, 0, "non prima di minMs");
    run(fighters, ctx, 10);
    const damage = ofType(ctx.events, "hit")[0]?.damage ?? 0;
    assert.ok(Math.abs(damage - CHARGE_EXAMPLE.damage) <= 0.2, `danno ${damage}`); // il tick dopo minMs carica un filo
  });

  it("lo scudo la annulla", () => {
    const { ctx, fighters, a } = setup(10, "prova-carica");
    press(a, { down: true, special: true });
    run(fighters, ctx, 10);
    assert.ok(a.charge > 0);
    press(a, { shield: true });
    run(fighters, ctx, 60);
    assert.equal(a.charge, 0);
    assert.equal(ofType(ctx.events, "attack").length, 0);
    assert.equal(ofType(ctx.events, "hit").length, 0);
  });
});
