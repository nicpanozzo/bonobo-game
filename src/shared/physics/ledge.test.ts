// Test del bordo del palco (#110): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, LEDGE, TICK_RATE } from "../constants";
import { getStage, type StageSpec } from "../stages";
import type { InputState } from "../types";
import { createFighter, emptyInput, ledgesOf, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined); // il palco di base: un blocco da x 240 a 1040, in alto a y 560
const [left] = ledgesOf(stage);

function setup(count = 1) {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = Array.from({ length: count }, (_, i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  return { ctx, fighters };
}

// Mette il lottatore in aria appena fuori dal bordo sinistro, sopra lo spigolo, senza velocità
function besideLedge(f: Fighter) {
  f.ledge = null;
  f.ledgeIndex = -1;
  f.regrabTimer = 0;
  f.x = left.x - FIGHTER.width / 2;
  f.y = left.y - 120;
  f.vx = 0;
  f.vy = 0;
  f.onGround = false;
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const grabs = (ctx: PhysicsContext) => ctx.events.filter((e) => e.type === "ledgeGrab");

describe("ledgesOf", () => {
  it("il palco di base ha due spigoli, uno per lato", () => {
    assert.deepEqual(ledgesOf(stage), [
      { x: 240, y: 560, side: -1 },
      { x: 1040, y: 560, side: 1 },
    ]);
  });

  it("due blocchi attaccati alla stessa altezza hanno bordo solo ai lati esterni", () => {
    const two: StageSpec = {
      ...stage,
      solids: [
        { x: 100, y: 500, width: 200, height: 50 },
        { x: 300, y: 500, width: 200, height: 50 },
      ],
    };
    assert.deepEqual(
      ledgesOf(two).map((l) => l.x),
      [100, 500],
    );
  });

  it("uno spigolo con un muro sopra non è un bordo", () => {
    const wall: StageSpec = {
      ...stage,
      solids: [
        { x: 100, y: 500, width: 200, height: 50 },
        { x: 0, y: 300, width: 100, height: 250 }, // muro a sinistra, più alto del blocco
      ],
    };
    assert.ok(!ledgesOf(wall).some((l) => l.x === 100 && l.y === 500));
  });
});

describe("presa del bordo", () => {
  it("chi cade accanto al palco si aggrappa, girato verso il palco e invulnerabile", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    besideLedge(f);
    run(fighters, ctx, 30);
    assert.equal(f.ledge, "hang");
    assert.equal(f.x, left.x - FIGHTER.width / 2);
    assert.equal(f.y, left.y + LEDGE.hangOffsetY);
    assert.equal(f.facing, 1);
    assert.equal(f.invulnerable, true);
    assert.equal(f.jumpsLeft, FIGHTER.maxJumps - 1);
    const [e] = grabs(ctx);
    assert.deepEqual(e, { type: "ledgeGrab", id: "p0", x: 240, y: 560, invulnerable: true });
    // Resta fermo lì
    run(fighters, ctx, 60);
    assert.equal(f.ledge, "hang");
    assert.equal(f.y, left.y + LEDGE.hangOffsetY);
  });

  it("tenendo giù non ci si aggrappa", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    besideLedge(f);
    press(f, { down: true });
    run(fighters, ctx, 30);
    assert.equal(f.ledge, null);
    assert.ok(f.y > left.y + LEDGE.hangOffsetY + LEDGE.grabBoxY);
  });

  it("la seconda presa senza toccare terra non è invulnerabile, alla quarta non ci si aggrappa", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    for (let n = 1; n <= LEDGE.maxGrabs; n++) {
      besideLedge(f);
      run(fighters, ctx, 30);
      assert.equal(f.ledge, "hang", `presa ${n}`);
      run(fighters, ctx, Math.ceil(LEDGE.invulnMs / DT)); // l'eventuale invulnerabilità finisce
    }
    assert.deepEqual(
      grabs(ctx).map((e) => e.type === "ledgeGrab" && e.invulnerable),
      [true, false, false],
    );
    besideLedge(f);
    run(fighters, ctx, 30);
    assert.equal(f.ledge, null);
  });

  it("dopo aver toccato terra la presa è di nuovo invulnerabile", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    besideLedge(f);
    run(fighters, ctx, 30);
    // Torna sul palco e ci atterra
    f.ledge = null;
    f.x = 600;
    f.y = 500;
    run(fighters, ctx, 30);
    assert.equal(f.onGround, true);
    run(fighters, ctx, Math.ceil(LEDGE.invulnMs / DT));
    besideLedge(f);
    run(fighters, ctx, 30);
    assert.equal(f.invulnerable, true);
    assert.equal(grabs(ctx).length, 2);
  });

  it("due lottatori non tengono lo stesso bordo", () => {
    const { ctx, fighters } = setup(2);
    const [a, b] = fighters;
    besideLedge(a);
    run(fighters, ctx, 30);
    assert.equal(a.ledge, "hang");
    besideLedge(b);
    run(fighters, ctx, 30);
    assert.equal(b.ledge, null);
    assert.equal(grabs(ctx).length, 1);
  });

  it("dopo 5 secondi appesi si cade, e per un attimo non ci si riaggrappa", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    besideLedge(f);
    run(fighters, ctx, 30);
    assert.equal(f.ledge, "hang");
    run(fighters, ctx, Math.ceil(LEDGE.maxHangMs / DT));
    assert.equal(f.ledge, null);
    const y = f.y;
    run(fighters, ctx, 10);
    assert.ok(f.y > y, "cade");
    assert.equal(f.ledge, null);
  });

  it("su fa saltare dal bordo e si atterra sul palco tenendo verso il palco", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    besideLedge(f);
    run(fighters, ctx, 30);
    press(f, { up: true, right: true });
    run(fighters, ctx, 60);
    assert.equal(f.ledge, null);
    assert.equal(f.onGround, true);
    assert.equal(f.y, left.y);
    assert.ok(f.x > left.x);
  });

  it("giù o lontano dal palco fanno lasciare il bordo", () => {
    for (const keys of [{ down: true }, { left: true }]) {
      const { ctx, fighters } = setup();
      const [f] = fighters;
      besideLedge(f);
      run(fighters, ctx, 30);
      press(f, keys);
      run(fighters, ctx, 20);
      assert.equal(f.ledge, null, JSON.stringify(keys));
      assert.ok(f.y > left.y + LEDGE.hangOffsetY);
    }
  });

  it("un colpo stacca dal bordo", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    besideLedge(f);
    run(fighters, ctx, 30);
    // Come dopo resolveHits: stordito e spinto via
    f.hitstunTimer = 200;
    f.vx = -400;
    f.vy = -300;
    run(fighters, ctx, 1);
    assert.equal(f.ledge, null);
    assert.equal(f.ledgeGrabs, 0);
    assert.ok(f.x < left.x - FIGHTER.width / 2);
  });
});

describe("risalite dal bordo", () => {
  // Appeso al bordo sinistro da abbastanza tempo per poter agire
  function hanging(count = 1) {
    const { ctx, fighters } = setup(count);
    besideLedge(fighters[0]);
    run(fighters, ctx, 30);
    assert.equal(fighters[0].ledge, "hang");
    run(fighters, ctx, Math.ceil(LEDGE.invulnMs / DT)); // finisce l'invulnerabilità della presa
    assert.equal(fighters[0].invulnerable, false);
    ctx.events = [];
    return { ctx, fighters, f: fighters[0] };
  }
  const ticks = (ms: number) => Math.ceil(ms / DT);
  const near = (a: number, b: number) => assert.ok(Math.abs(a - b) <= 4, `${a} non è vicino a ${b}`);
  const getups = (ctx: PhysicsContext) => ctx.events.flatMap((e) => (e.type === "ledgeGetup" ? [e.option] : []));

  it("verso il palco: risalita normale, in piedi appena dentro il bordo, invulnerabile all'inizio", () => {
    const { ctx, fighters, f } = hanging();
    press(f, { right: true });
    run(fighters, ctx, 1);
    assert.equal(f.ledge, "climb");
    run(fighters, ctx, ticks(LEDGE.climbInvulnMs) - 2);
    assert.equal(f.invulnerable, true);
    run(fighters, ctx, 3);
    assert.equal(f.invulnerable, false);
    press(f, {});
    run(fighters, ctx, ticks(LEDGE.climbMs - LEDGE.climbInvulnMs) + 2);
    assert.equal(f.ledge, null);
    assert.equal(f.onGround, true);
    assert.equal(f.y, left.y);
    near(f.x, left.x + FIGHTER.width / 2);
    assert.deepEqual(getups(ctx), ["climb"]);
  });

  it("schivata: rotolata sul palco di rollDistance pixel, invulnerabile per rollInvulnMs", () => {
    const { ctx, fighters, f } = hanging();
    press(f, { dodge: true });
    run(fighters, ctx, ticks(LEDGE.rollInvulnMs) - 1);
    assert.equal(f.ledge, "roll");
    assert.equal(f.invulnerable, true);
    run(fighters, ctx, 2);
    assert.equal(f.invulnerable, false);
    run(fighters, ctx, ticks(LEDGE.rollMs - LEDGE.rollInvulnMs) + 2);
    assert.equal(f.ledge, null);
    assert.equal(f.onGround, true);
    near(f.x, left.x + FIGHTER.width / 2 + LEDGE.rollDistance);
    // La schivata vera non parte: si resta fermi dove finisce la rotolata
    const x = f.x;
    press(f, {});
    run(fighters, ctx, 20);
    near(f.x, x);
    assert.deepEqual(getups(ctx), ["roll"]);
  });

  it("attacco: si sale invulnerabili fino all'uscita del colpo, che prende chi sta sul bordo", () => {
    const { ctx, fighters, f } = hanging(2);
    const b = fighters[1];
    b.x = left.x + FIGHTER.width / 2 + 50;
    b.y = left.y;
    b.vx = 0;
    run(fighters, ctx, 5); // b si ferma sul palco
    ctx.events = [];
    press(f, { light: true });
    run(fighters, ctx, ticks(ATTACKS.ledgeAttack.startupMs) - 2);
    assert.equal(f.ledge, "climb");
    assert.equal(f.invulnerable, true);
    run(fighters, ctx, 4);
    assert.equal(f.ledge, null);
    assert.equal(f.onGround, true);
    const hit = ctx.events.find((e) => e.type === "hit");
    assert.ok(hit && hit.type === "hit" && hit.kind === "ledgeAttack" && hit.targetId === "p1");
    assert.deepEqual(getups(ctx), ["attack"]);
  });

  it("su: salto dal bordo invulnerabile per jumpInvulnMs, con il salto in aria ancora a disposizione", () => {
    const { ctx, fighters, f } = hanging();
    press(f, { up: true });
    run(fighters, ctx, 1);
    assert.equal(f.ledge, null);
    assert.equal(f.invulnerable, true);
    assert.ok(f.vy < 0);
    assert.equal(f.jumpsLeft, FIGHTER.maxJumps - 1);
    run(fighters, ctx, ticks(LEDGE.jumpInvulnMs) + 1);
    assert.equal(f.invulnerable, false);
    assert.deepEqual(getups(ctx), ["jump"]);
  });

  it("i tasti premuti appena aggrappati non contano", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    besideLedge(f);
    for (let i = 0; i < 40 && !f.ledge; i++) run(fighters, ctx, 1);
    assert.equal(f.ledge, "hang");
    press(f, { right: true });
    run(fighters, ctx, 1);
    assert.equal(f.ledge, "hang");
  });

  it("chi risale tiene il bordo: un altro non lo prende finché non è finita", () => {
    const { ctx, fighters, f } = hanging(2);
    press(f, { right: true });
    run(fighters, ctx, 1);
    const b = fighters[1];
    besideLedge(b);
    run(fighters, ctx, 10);
    assert.equal(b.ledge, null);
    assert.equal(f.ledge, "climb");
  });
});
