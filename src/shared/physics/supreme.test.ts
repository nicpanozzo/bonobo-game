// Test della barra della suprema (#101) e della suprema di Bonobot (#102). Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getCharacter, supremeAttackSpec, type BurstSupreme, type DropSupreme, type GrabSupreme, type SpinSupreme } from "../characters";
import { ATTACKS, FIGHTER, SUPREME, TICK_RATE } from "../constants";
import { Match } from "../match";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { loseStock } from "./stage";
import { snatch } from "./supreme";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

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
  run(fighters, ctx, 10);
  ctx.events.length = 0;
  a.supreme = b.supreme = 0;
  return { ctx, fighters, a, b };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const ofType = <T extends GameEvent["type"]>(events: GameEvent[], type: T) =>
  events.filter((e): e is Extract<GameEvent, { type: T }> => e.type === type);
const ticks = (ms: number) => Math.ceil(ms / DT);

describe("barra della suprema", () => {
  it("parte vuota", () => {
    const { a } = setup();
    assert.equal(createFighter({ id: "x", name: "X", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage).supreme, 0);
    assert.equal(a.supreme, 0);
  });

  it("si carica col tempo, piano", () => {
    const { ctx, fighters, a } = setup(400);
    run(fighters, ctx, TICK_RATE * 10); // 10 secondi fermi
    assert.ok(Math.abs(a.supreme - 10 * SUPREME.perSecond) < 0.01, `barra ${a.supreme}`);
  });

  it("si carica con i danni dati e presi, di più per chi colpisce", () => {
    const { ctx, fighters, a, b } = setup();
    press(a, { light: true });
    run(fighters, ctx, 1);
    press(a, {});
    run(fighters, ctx, ticks(ATTACKS.light.startupMs + ATTACKS.light.activeMs) + 2);
    const hit = ofType(ctx.events, "hit")[0];
    assert.ok(hit, "il leggero deve colpire");
    assert.ok(a.supreme >= hit.damage * SUPREME.perDamageDealt, `chi colpisce ${a.supreme}`);
    assert.ok(b.supreme >= hit.damage * SUPREME.perDamageTaken, `chi è colpito ${b.supreme}`);
    assert.ok(a.supreme > b.supreme);
  });

  it("non passa il massimo", () => {
    const { ctx, fighters, a } = setup(400);
    a.supreme = SUPREME.max - 0.01;
    run(fighters, ctx, TICK_RATE);
    assert.equal(a.supreme, SUPREME.max);
  });

  it("resta quando si perde una vita (SUPREME.keepOnKo)", () => {
    const { ctx, a } = setup();
    a.supreme = 70;
    loseStock(a, ctx);
    assert.equal(a.supreme, SUPREME.keepOnKo ? 70 : 0);
  });

  it("nello snapshot va arrotondata per difetto: 100 solo quando è piena", () => {
    const match = new Match();
    match.addPlayer("a", "A");
    match.players[0].supreme = SUPREME.max - 0.2;
    assert.equal(match.snapshot([], 0).players[0].supreme, SUPREME.max - 1);
  });
});

describe("tasto della suprema", () => {
  it("con la barra non piena non fa niente", () => {
    const { ctx, fighters, a } = setup();
    a.supreme = SUPREME.max - 1;
    press(a, { supreme: true });
    run(fighters, ctx, 1);
    assert.equal(a.attack, null);
    assert.equal(ofType(ctx.events, "attack").length, 0);
  });

  it("con la barra piena lancia la suprema, svuota la barra e colpisce forte", () => {
    const { ctx, fighters, a, b } = setup(60);
    a.supreme = SUPREME.max;
    press(a, { supreme: true });
    run(fighters, ctx, 1);
    assert.equal(a.attack, "supreme");
    assert.equal(ofType(ctx.events, "attack")[0]?.kind, "supreme");
    assert.ok(a.supreme < 1, `barra ${a.supreme}`);
    press(a, {});
    run(fighters, ctx, ticks(ATTACKS.supreme.startupMs + ATTACKS.supreme.activeMs) + 2);
    const hit = ofType(ctx.events, "hit")[0];
    assert.equal(hit?.kind, "supreme");
    assert.equal(hit?.targetId, b.id);
    assert.ok(a.supreme < 1, "la suprema non ricarica chi la fa");
    assert.ok(b.supreme >= ATTACKS.supreme.damage * SUPREME.perDamageTaken, "chi la prende si carica");
  });

  it("durante l'avvio non si può interrompere", () => {
    const { ctx, fighters, a, b } = setup();
    a.supreme = SUPREME.max;
    press(a, { supreme: true });
    run(fighters, ctx, 1);
    press(a, {});
    // b colpisce col leggero, che è molto più rapido dell'avvio della suprema
    press(b, { light: true });
    run(fighters, ctx, 1);
    press(b, {});
    run(fighters, ctx, ticks(ATTACKS.light.startupMs + ATTACKS.light.activeMs) + 1);
    assert.ok(ATTACKS.light.startupMs + ATTACKS.light.activeMs < SUPREME.invulnerableMs);
    assert.equal(ofType(ctx.events, "hit").filter((e) => e.targetId === a.id).length, 0);
    assert.equal(a.attack, "supreme");
  });
});

describe("suprema di Bonobot, Omar (#102)", () => {
  const omar = getCharacter("bonobot").supreme as DropSupreme;
  const impactAt = omar.leapMs + omar.pullMs + omar.warnMs;
  const total = impactAt + omar.impactMs + omar.recoverMs;
  const vineX = 640 + omar.leapDx; // Bonobot parte da 640 guardando a destra

  // Bonobot guarda a destra; uno a destra e uno a sinistra della liana dentro l'area, uno fuori
  function omarSetup() {
    const ctx: PhysicsContext = { stage, events: [] };
    const fighters = ["bonobot", "default", "default", "default"].map((characterId, i) =>
      createFighter({ id: `p${i}`, name: `P${i}`, characterId, color: 0, team: 0, index: i, stocks: 3 }, stage),
    );
    const [bono, right, left, far] = fighters;
    bono.x = 640;
    bono.facing = 1;
    right.x = vineX + omar.width / 2 - 10;
    left.x = vineX - omar.width / 2 + 10;
    far.x = vineX + omar.width + 60;
    run(fighters, ctx, 10);
    ctx.events.length = 0;
    bono.supreme = SUPREME.max;
    return { ctx, fighters, bono, right, left, far };
  }

  it("l'orsogufo cade sulla liana: colpisce chi sta lì e non chi è lontano, lanciandoli via dal centro", () => {
    const { ctx, fighters, bono, right, left, far } = omarSetup();
    press(bono, { supreme: true });
    run(fighters, ctx, 1);
    press(bono, {});
    assert.equal(bono.attack, "supreme");
    run(fighters, ctx, ticks(impactAt) - 3);
    assert.equal(ofType(ctx.events, "hit").length, 0, "niente colpi prima dell'impatto");
    run(fighters, ctx, ticks(omar.impactMs) + 4);
    const hits = ofType(ctx.events, "hit");
    assert.deepEqual(hits.map((h) => h.targetId).sort(), [right.id, left.id].sort());
    assert.ok(hits.every((h) => h.kind === "supreme" && h.damage === omar.damage));
    assert.ok(right.vx > 0 && left.vx < 0, "volano via dalla liana");
    assert.ok(right.vy < 0 && left.vy < 0, "e verso l'alto");
    assert.equal(far.percent, 0);
  });

  it("Bonobot salta in avanti alla liana, poi fa la capriola indietro e all'impatto non è sotto l'orsogufo", () => {
    const { ctx, fighters, bono } = omarSetup();
    const y0 = bono.y;
    press(bono, { supreme: true });
    run(fighters, ctx, 1);
    press(bono, {});
    run(fighters, ctx, ticks(omar.leapMs + omar.pullMs / 2));
    assert.ok(Math.abs(bono.x - vineX) < 1, `appeso alla liana (x ${bono.x})`);
    assert.ok(Math.abs(bono.y - (y0 - omar.leapDy)) < 1, `in alto (y ${bono.y})`);
    run(fighters, ctx, ticks(impactAt) - ticks(omar.leapMs + omar.pullMs / 2));
    assert.ok(Math.abs(bono.x - vineX) > omar.width / 2 + FIGHTER.width / 2, `fuori dall'area all'impatto (x ${bono.x})`);
    assert.ok(bono.x < vineX, "dietro, dalla parte da cui era partito");
    assert.ok(bono.onGround, "è già atterrato");
  });

  it("Bonobot non si può colpire per tutta la suprema e Omar non ricarica la barra", () => {
    const { ctx, fighters, bono, left } = omarSetup();
    press(bono, { supreme: true });
    run(fighters, ctx, 1);
    press(bono, {});
    // left gli sta addosso e prova a colpirlo di continuo
    let hitBono = 0;
    for (let i = 0; i < ticks(total) - 2; i++) {
      left.x = bono.x + FIGHTER.width;
      left.facing = -1;
      press(left, { light: i % 2 === 0 });
      run(fighters, ctx, 1);
      assert.ok(bono.invulnerable, `invulnerabile a ${i} tick`);
    }
    hitBono = ofType(ctx.events, "hit").filter((h) => h.targetId === bono.id).length;
    assert.equal(hitBono, 0);
    assert.equal(bono.supreme, 0, "la barra resta vuota: Omar non la ricarica");
  });

  it("lanciata in aria, l'orsogufo cade comunque a terra sotto la liana", () => {
    const { ctx, fighters, bono } = omarSetup();
    const ground = bono.y;
    bono.y = ground - 150;
    bono.onGround = false;
    press(bono, { supreme: true });
    run(fighters, ctx, 1);
    assert.equal(bono.attack, "supreme");
    assert.equal(bono.supremeY, ground);
    assert.ok(bono.y < ground - 140, "il salto parte da dove si era");
  });

  it("chi non ha una suprema propria usa quella di base", () => {
    assert.equal(getCharacter("default").supreme, undefined);
    assert.equal(supremeAttackSpec("default"), null);
    assert.equal(supremeAttackSpec("bonobot")?.outward, true);
    assert.ok(omar.flipMs <= omar.warnMs, "la capriola finisce prima dell'impatto");
  });
});

describe("suprema che gira, DEMACIAAA di Bradipo Giallo (#358)", () => {
  const spin = getCharacter("bradipo").supreme as SpinSupreme;

  function spinSetup() {
    const { ctx, fighters, a, b } = setup(10);
    a.characterId = "bradipo";
    a.supreme = SUPREME.max;
    b.characterId = "egiainuso"; // uno qualunque senza contrattacco in corso
    return { ctx, fighters, bradipo: a, b };
  }

  it("colpisce più volte chi gli sta vicino, un colpo a giro", () => {
    const { ctx, fighters, bradipo, b } = spinSetup();
    b.percent = 0;
    press(bradipo, { supreme: true });
    run(fighters, ctx, 1);
    press(bradipo, {});
    assert.equal(bradipo.attack, "supreme");
    // b resta vicino: lo si rimette accanto a ogni passo, come se tornasse dentro
    for (let i = 0; i < ticks(spin.windupMs + spin.durationMs); i++) {
      b.x = bradipo.x + FIGHTER.width;
      b.y = bradipo.y;
      b.vx = b.vy = 0;
      run(fighters, ctx, 1);
    }
    const hits = ofType(ctx.events, "hit").filter((h) => h.targetId === b.id);
    const turns = Math.floor(spin.durationMs / spin.hitEveryMs);
    assert.ok(hits.length >= turns - 1 && hits.length <= turns + 1, `${hits.length} colpi su ${turns} giri`);
    assert.ok(hits.every((h) => h.kind === "supreme" && h.damage === spin.damage));
  });

  it("mentre gira si muove piano, poi torna fermo come negli altri attacchi", () => {
    const { ctx, fighters, bradipo } = spinSetup();
    press(bradipo, { supreme: true });
    run(fighters, ctx, 1);
    press(bradipo, { right: true });
    run(fighters, ctx, ticks(spin.windupMs) + 2);
    const x0 = bradipo.x;
    run(fighters, ctx, ticks(500));
    const moved = bradipo.x - x0;
    assert.ok(moved > 0, "si sposta");
    assert.ok(moved < FIGHTER.groundSpeed * 0.5 * 0.9, `più piano della corsa (${moved} px in 0,5 s)`);
  });

  it("l'area è tutto intorno e i bot sanno fin dove arriva", () => {
    const sp = supremeAttackSpec("bradipo")!;
    assert.equal(sp.boxX, -spin.width / 2);
    assert.equal(sp.outward, true);
    assert.equal(sp.cooldownMs, spin.windupMs + spin.durationMs + spin.endLagMs);
  });
});

describe("suprema che afferra, snaack di Lampione (#358)", () => {
  const grab = getCharacter("lampione").supreme as GrabSupreme;

  function grabSetup(gap: number) {
    const { ctx, fighters, a, b } = setup(gap);
    a.characterId = "lampione";
    a.supreme = SUPREME.max;
    b.characterId = "egiainuso";
    press(a, { supreme: true });
    run(fighters, ctx, 1);
    press(a, {});
    return { ctx, fighters, lampione: a, b };
  }

  it("prende da lontano, tira davanti a sé e a terra fa rimbalzare in alto", () => {
    const { ctx, fighters, lampione, b } = grabSetup(200);
    let hit = false;
    for (let i = 0; i < ticks(grab.windupMs + grab.reachMs) + 2 && !hit; i++) {
      run(fighters, ctx, 1);
      hit = ofType(ctx.events, "hit").some((h) => h.targetId === b.id && h.kind === "supreme");
    }
    assert.ok(hit, "lo prende a 200 pixel");
    assert.ok(Math.abs(b.x - lampione.x) < 120, `tirato vicino (${Math.round(b.x - lampione.x)} px)`);
    assert.ok(b.vy < 0, "rimbalza in alto");
    assert.equal(b.percent, grab.damage);
  });

  it("oltre il braccio non prende nessuno", () => {
    const { ctx, fighters, b } = grabSetup(grab.reach + 40);
    run(fighters, ctx, ticks(grab.windupMs + grab.reachMs + grab.endLagMs));
    assert.equal(ofType(ctx.events, "hit").filter((h) => h.targetId === b.id).length, 0);
  });

  it("in aria schiaccia verso il basso; le altre supreme non tirano", () => {
    const { lampione, b } = grabSetup(200);
    lampione.attack = "supreme";
    lampione.onGround = false;
    assert.equal(snatch(lampione, b, grab.angleDeg), grab.angleDeg);
    assert.ok(grab.angleDeg < 0);
    lampione.characterId = "bradipo";
    const x = b.x;
    assert.equal(snatch(lampione, b, 60), 60);
    assert.equal(b.x, x);
  });
});

describe("suprema a raffiche, IRA di Lendmar (#358)", () => {
  const ira = getCharacter("lendmar").supreme as BurstSupreme;

  function burstSetup(gap: number) {
    const { ctx, fighters, a, b } = setup(gap);
    a.characterId = "lendmar";
    a.supreme = SUPREME.max;
    b.characterId = "egiainuso";
    press(a, { supreme: true });
    run(fighters, ctx, 1);
    press(a, {});
    return { ctx, fighters, lendmar: a, b };
  }

  it("tira tutte le raffiche, da tutte e due le parti", () => {
    const { ctx, fighters } = burstSetup(400);
    run(fighters, ctx, ticks(ira.windupMs + ira.waves * ira.waveEveryMs));
    const shots = ofType(ctx.events, "projectile");
    assert.equal(shots.length, ira.waves * ira.count);
    const vx = (ctx.projectiles?.list ?? []).map((p) => p.vx);
    assert.ok(vx.some((v) => v < 0) && vx.some((v) => v > 0), "a sinistra e a destra");
  });

  it("colpisce coi proiettili, non col corpo", () => {
    const { ctx, fighters, b } = burstSetup(10);
    run(fighters, ctx, ticks(ira.windupMs) + 1);
    assert.equal(ofType(ctx.events, "hit").length, 0, "appena attaccato non colpisce col corpo");
    run(fighters, ctx, ticks(ira.waves * ira.waveEveryMs + 1500));
    const hits = ofType(ctx.events, "hit").filter((h) => h.targetId === b.id);
    assert.ok(hits.length > 0 && hits.every((h) => h.kind === "specialNeutral"), `${hits.length} colpi di merda`);
  });
});
