// Test della fisica: logica pura, quindi si prova senza server né browser.
// Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, DODGE, FIGHTER, HITSTOP, RECOVERY, RESPAWN_MS, TICK_RATE } from "../constants";
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
    press(f, { jump: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, 5);
    press(f, { jump: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, 5);
    press(f, { jump: true });
    run(fighters, ctx, 1);
    const jumps = ofType(ctx.events, "jump");
    assert.equal(jumps.length, 2);
    assert.deepEqual(jumps.map((j) => j.air), [false, true]);
  });

  it("su da solo non fa saltare: salta solo il tasto salto (E10)", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    press(f, { up: true });
    run(fighters, ctx, 10);
    assert.equal(ofType(ctx.events, "jump").length, 0);
    assert.equal(f.onGround, true);
    press(f, { up: true, light: true });
    run(fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "attack")[0]?.kind, "lightUp", "l'attacco in su parte da terra");
    assert.equal(ofType(ctx.events, "jump").length, 0);
  });

  it("dopo il salto riatterra sul palco con l'evento land", () => {
    const { ctx, fighters } = setup();
    const [f] = fighters;
    f.x = stage.solids[0].x + 30; // lontano dalle piattaforme sottili
    const groundY = f.y;
    press(f, { jump: true });
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

  it("attacchi direzionali: la variante dipende dai tasti tenuti e da terra/aria (#2)", () => {
    const kinds: string[] = [];
    for (const keys of [{ light: true }, { light: true, down: true }, { heavy: true, up: true }] as Partial<InputState>[]) {
      const { ctx, fighters } = setup();
      press(fighters[0], keys);
      run(fighters, ctx, 1);
      kinds.push(ofType(ctx.events, "attack")[0].kind);
    }
    const { ctx, fighters } = setup();
    const [f] = fighters;
    press(f, { jump: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, 5);
    press(f, { heavy: true });
    run(fighters, ctx, 1);
    kinds.push(ofType(ctx.events, "attack")[0].kind);
    assert.deepEqual(kinds, ["light", "lightDown", "heavyUp", "heavyAir"]);
  });

  it("l'attacco in su lancia in verticale chi sta sopra la testa", () => {
    const { ctx, fighters, a, b } = facingPair();
    b.x = a.x + 10;
    press(a, { up: true, light: true });
    run(fighters, ctx, 10);
    const hits = ofType(ctx.events, "hit");
    assert.equal(hits.length, 1);
    assert.equal(hits[0].kind, "lightUp");
    run(fighters, ctx, 3);
    assert.ok(b.vy < 0 && Math.abs(b.vy) > Math.abs(b.vx) * 5, "vola in su, quasi dritto");
  });

  it("hitstop: dopo il colpo attaccante e bersaglio restano fermi, poi il bersaglio vola", () => {
    const { ctx, fighters, a, b } = facingPair();
    press(a, { heavy: true });
    let ticks = 0;
    while (ofType(ctx.events, "hit").length === 0 && ticks++ < 60) run(fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "hit").length, 1, "il pesante è entrato");
    const stopMs = HITSTOP.baseMs + HITSTOP.perDamageMs * ATTACKS.heavy.damage;
    assert.equal(b.hitstopTimer, stopMs);
    const frozen = { ax: a.x, bx: b.x, by: b.y, attackTimer: a.attackTimer };
    run(fighters, ctx, Math.floor(stopMs / DT) - 1);
    assert.deepEqual({ ax: a.x, bx: b.x, by: b.y, attackTimer: a.attackTimer }, frozen, "tutto fermo");
    run(fighters, ctx, 3);
    assert.ok(b.x > frozen.bx, "finito il fermo, vola");
    assert.equal(b.hitstopTimer, 0);
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

describe("recupero (#11)", () => {
  // In aria sotto il bordo del palco, già senza salti
  function falling() {
    const s = setup(1);
    const [f] = s.fighters;
    Object.assign(f, { x: stage.blastZone.left + 200, y: 800, onGround: false, jumpsLeft: 0, vy: 300 });
    return { ...s, f };
  }

  it("K + su in aria spinge in alto, una volta sola", () => {
    const { ctx, fighters, f } = falling();
    press(f, { up: true, heavy: true });
    run(fighters, ctx, 1);
    assert.ok(f.vy < -RECOVERY.speed + 100, "spinta verso l'alto");
    assert.equal(f.attack, "recovery");
    assert.equal(ofType(ctx.events, "attack")[0].kind, "recovery");
    press(f, { up: true });
    run(fighters, ctx, 30);
    press(f, { up: true, heavy: true });
    run(fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "attack").length, 1, "la seconda volta non parte");
  });

  it("dopo il recupero non si attacca fino all'atterraggio, poi torna disponibile", () => {
    const { ctx, fighters, f } = falling();
    f.x = stage.solids[0].x + 30; // sopra il palco: ricadendo ci atterra
    f.y = stage.solids[0].y - 200;
    press(f, { up: true, heavy: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, 20);
    press(f, { light: true });
    run(fighters, ctx, 1);
    assert.equal(f.attack, null, "niente attacchi in aria dopo il recupero");
    press(f, {});
    run(fighters, ctx, 120);
    assert.equal(f.onGround, true);
    assert.equal(f.recoveryUsed, false);
    assert.equal(f.helpless, false);
  });

  it("chi viene colpito può riusarlo", () => {
    const { ctx, fighters } = setup(2);
    const [a, b] = fighters;
    b.recoveryUsed = true;
    b.helpless = true;
    a.x = 600;
    b.x = 600 + FIGHTER.width + 20;
    a.facing = 1;
    press(a, { light: true });
    run(fighters, ctx, 15);
    assert.equal(ofType(ctx.events, "hit").length, 1);
    assert.equal(b.recoveryUsed, false);
    assert.equal(b.helpless, false);
  });
});

describe("schivata (#3)", () => {
  it("con L ci si sposta nella direzione tenuta e i colpi non entrano", () => {
    const s = setup(2);
    const [a, b] = s.fighters;
    a.x = 600;
    b.x = 600 + FIGHTER.width + 20;
    a.facing = 1;
    press(a, { heavy: true });
    run(s.fighters, s.ctx, 1);
    const startX = b.x;
    press(b, { dodge: true, right: true });
    run(s.fighters, s.ctx, Math.floor(DODGE.durationMs / DT) - 1);
    assert.equal(b.invulnerable, true);
    assert.ok(b.x > startX + 50, "si è spostato a destra");
    assert.equal(ofType(s.ctx.events, "hit").length, 0, "il pesante va a vuoto");
  });

  it("dopo la schivata c'è la ricarica", () => {
    const { ctx, fighters } = setup(1);
    const [f] = fighters;
    press(f, { dodge: true });
    run(fighters, ctx, 1);
    press(f, {});
    run(fighters, ctx, Math.ceil(DODGE.durationMs / DT) + 1);
    assert.equal(f.invulnerable, false);
    press(f, { dodge: true });
    run(fighters, ctx, 1);
    assert.equal(f.invulnerable, false, "ancora in ricarica");
    press(f, {});
    run(fighters, ctx, Math.ceil(DODGE.cooldownMs / DT));
    press(f, { dodge: true });
    run(fighters, ctx, 1);
    assert.equal(f.invulnerable, true, "ricarica finita");
  });

  it("in aria una volta sola fino all'atterraggio", () => {
    const { ctx, fighters } = setup(1);
    const [f] = fighters;
    Object.assign(f, { y: 200, onGround: false, vy: 0 });
    press(f, { dodge: true });
    run(fighters, ctx, 1);
    assert.equal(f.airDodgeUsed, true);
    press(f, {});
    run(fighters, ctx, Math.ceil(DODGE.durationMs / DT) + 1);
    f.dodgeCooldown = 0; // ricarica saltata: conta solo il limite in aria
    assert.equal(f.onGround, false);
    press(f, { dodge: true });
    run(fighters, ctx, 1);
    assert.equal(f.dodgeTimer, 0, "la seconda in aria non parte");
    press(f, {});
    run(fighters, ctx, 200);
    assert.equal(f.onGround, true);
    assert.equal(f.airDodgeUsed, false, "a terra torna disponibile");
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

describe("disconnesso con il posto tenuto (#107)", () => {
  // Come in "attacchi": a colpirebbe b con il leggero, ma b è away
  function awayPair() {
    const s = setup(2);
    const [a, b] = s.fighters;
    a.x = 600;
    b.x = 600 + FIGHTER.width + 20;
    a.facing = 1;
    b.away = true;
    return { ...s, a, b };
  }

  it("non prende colpi e non attacca", () => {
    const { ctx, fighters, a, b } = awayPair();
    press(a, { light: true });
    press(b, { heavy: true });
    run(fighters, ctx, 15);
    assert.equal(ofType(ctx.events, "hit").length, 0);
    assert.equal(b.percent, 0);
    assert.equal(b.invulnerable, true);
    assert.equal(ofType(ctx.events, "attack").filter((e) => e.id === b.id).length, 0);
  });

  it("resta fermo anche in aria e fuori dall'arena non perde vite", () => {
    const { ctx, fighters, b } = awayPair();
    b.y -= 200;
    b.vx = 300;
    press(b, { right: true });
    const start = { x: b.x, y: b.y };
    run(fighters, ctx, 30);
    assert.deepEqual({ x: b.x, y: b.y }, start);
    b.x = stage.blastZone.right + 100;
    run(fighters, ctx, 30);
    assert.equal(b.stocks, 3);
    assert.equal(ofType(ctx.events, "ko").length, 0);
  });
});
