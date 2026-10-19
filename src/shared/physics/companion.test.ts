// Test del compagno (#369), il beagle di Lampione. Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { COMPANION, TICK_RATE } from "../constants";
import { Match } from "../match";
import { getStage } from "../stages";
import { attackBox } from "./attacks";
import { biting, companionState } from "./companion";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

function setup(characterId = "lampione") {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p0", name: "P0", characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);
  run([f], ctx, 30);
  return { ctx, f };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
}

describe("il beagle di Lampione (#369)", () => {
  it("c'è solo per chi ha un compagno", () => {
    assert.ok(setup().f.pet);
    assert.equal(setup("default").f.pet, null);
  });

  it("aspetta accanto a Lampione, un po' dietro, a terra", () => {
    const { f } = setup();
    const c = f.pet!;
    assert.ok(c.onGround);
    assert.equal(c.y, f.y);
    assert.ok(Math.abs(c.x - (f.x - f.facing * COMPANION.gapPx)) <= COMPANION.slackPx + 1, `beagle a ${c.x}, Lampione a ${f.x}`);
  });

  it("lo segue quando corre", () => {
    const { ctx, f } = setup();
    f.input = { ...emptyInput(), right: true };
    run([f], ctx, 40);
    f.input = emptyInput();
    run([f], ctx, 60);
    const c = f.pet!;
    assert.ok(c.x < f.x && f.x - c.x < COMPANION.gapPx + COMPANION.slackPx + 5, `beagle a ${Math.round(c.x)}, Lampione a ${Math.round(f.x)}`);
    assert.equal(c.facing, 1);
  });

  it("se resta troppo lontano torna di colpo accanto a lui", () => {
    const { ctx, f } = setup();
    f.pet!.x = f.x + COMPANION.teleportPx * 2;
    run([f], ctx, 1);
    assert.ok(Math.abs(f.pet!.x - f.x) < COMPANION.gapPx + 1);
  });

  it("finisce nello snapshot", () => {
    const m = new Match();
    m.addPlayer("a", "A", "lampione");
    m.step(DT);
    const p = m.snapshot([], 0).players[0];
    assert.ok(p.companion && typeof p.companion.x === "number");
  });
});

describe("i morsi del beagle negli attacchi base (#369 passo 2)", () => {
  function duel(characterId: string, gap: number) {
    const ctx: PhysicsContext = { stage, events: [] };
    const [a, b] = [0, 1].map((i) => createFighter({ id: `p${i}`, name: `P${i}`, characterId: i === 0 ? characterId : "default", color: 0, team: 0, index: i, stocks: 3 }, stage));
    a.x = 500;
    a.facing = 1;
    b.x = 500 + gap;
    b.facing = -1;
    run([a, b], ctx, 30);
    ctx.events.length = 0;
    a.input = { ...emptyInput(), light: true };
    run([a, b], ctx, 1);
    a.input = emptyInput();
    return { ctx, a, b };
  }

  it("il colpo leggero parte dal beagle, che scatta in avanti", () => {
    const { ctx, a } = duel("lampione", 400);
    assert.equal(a.attack, "light");
    const x0 = a.pet!.x;
    run([a], ctx, 4);
    assert.ok(a.pet!.x > x0 + 20, `il beagle scatta: da ${Math.round(x0)} a ${Math.round(a.pet!.x)}`);
    const box = attackBox(a);
    assert.ok(box.y > a.y - 40, "basso, alla sua altezza");
    assert.ok(Math.abs(box.x - (a.pet!.x + 22)) < 1, "davanti al beagle");
  });

  it("morde chi gli sta davanti", () => {
    const { ctx, a, b } = duel("lampione", 80);
    run([a, b], ctx, 15);
    const hits = ctx.events.filter((e) => e.type === "hit" && e.targetId === b.id);
    assert.equal(hits.length, 1);
  });

  it("mentre carica il pesante il beagle aspetta, poi scatta", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const a = createFighter({ id: "p0", name: "P0", characterId: "lampione", color: 0, team: 0, index: 0, stocks: 3 }, stage);
    run([a], ctx, 30);
    const x0 = a.pet!.x;
    a.input = { ...emptyInput(), heavy: true };
    run([a], ctx, 30);
    assert.ok(Math.abs(a.pet!.x - x0) < 20, `fermo durante la carica: da ${Math.round(x0)} a ${Math.round(a.pet!.x)}`);
    a.input = emptyInput();
    run([a], ctx, 6);
    assert.ok(a.pet!.x - x0 > 20, "lasciato il tasto scatta");
  });

  it("nello snapshot il beagle dice che sta mordendo", () => {
    const { a } = duel("lampione", 400);
    assert.equal(companionState(a)!.bite, true);
  });

  it("se il beagle è rimasto lontano il leggero lo fa Lampione", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const a = createFighter({ id: "p0", name: "P0", characterId: "lampione", color: 0, team: 0, index: 0, stocks: 3 }, stage);
    a.x = 500;
    a.facing = 1;
    run([a], ctx, 30);
    a.pet!.x = a.x - 250; // è rimasto indietro, per esempio mentre Lampione correva
    a.input = { ...emptyInput(), light: true };
    run([a], ctx, 1);
    assert.equal(a.attack, "light");
    assert.equal(biting(a), false);
    assert.ok(Math.abs(attackBox(a).x - (a.x + 20)) < 30, "il colpo parte davanti a Lampione");
    assert.equal(companionState(a)!.bite, undefined);
  });

  it("se il beagle sta volando via colpito il leggero lo fa Lampione", () => {
    const { ctx, a } = duel("lampione", 400);
    run([a], ctx, 20);
    a.pet!.hurtMs = COMPANION.hurtMs;
    a.input = { ...emptyInput(), light: true };
    run([a], ctx, 1);
    assert.equal(a.attack, "light");
    assert.equal(biting(a), false);
  });

  it("gli altri attacchi restano di Lampione", () => {
    const { a } = duel("lampione", 400);
    a.attack = "lightAir";
    assert.ok(attackBox(a).y < a.y - 40);
  });
});

describe("il beagle si può colpire (#369 passo 3)", () => {
  // b (default) a destra del beagle, girato verso di lui; Lampione guarda a destra lontano
  function setupHit() {
    const ctx: PhysicsContext = { stage, events: [] };
    const [a, b] = [0, 1].map((i) => createFighter({ id: `p${i}`, name: `P${i}`, characterId: i === 0 ? "lampione" : "default", color: 0, team: 0, index: i, stocks: 3 }, stage));
    a.x = 700;
    a.facing = -1; // il beagle aspetta dietro, a destra
    b.x = 900;
    b.facing = -1;
    run([a, b], ctx, 40);
    b.x = a.pet!.x + 60;
    run([a, b], ctx, 1);
    return { ctx, a, b };
  }
  function jab(b: Fighter, a: Fighter, ctx: PhysicsContext) {
    b.input = { ...emptyInput(), light: true };
    run([a, b], ctx, 1);
    b.input = emptyInput();
    run([a, b], ctx, 30);
  }

  it("un colpo gli fa danni e lo fa volare via, Lampione no", () => {
    const { ctx, a, b } = setupHit();
    const x0 = a.pet!.x;
    b.input = { ...emptyInput(), light: true };
    run([a, b], ctx, 1);
    b.input = emptyInput();
    run([a, b], ctx, 10);
    assert.ok(a.pet!.percent > 0, "danni al beagle");
    assert.equal(a.percent, 0, "Lampione non è stato toccato");
    assert.ok(a.pet!.x < x0 - 10, `spinto via: da ${Math.round(x0)} a ${Math.round(a.pet!.x)}`);
  });

  it("con abbastanza danni va KO, sparisce dallo snapshot e torna dopo un po'", () => {
    const { ctx, a, b } = setupHit();
    a.pet!.percent = COMPANION.koPercent - 1;
    jab(b, a, ctx);
    assert.ok(a.pet!.koMs > 0, "KO");
    assert.equal(companionState(a), null, "non va nello snapshot");
    assert.equal(biting({ ...a, attack: "light" } as Fighter), false, "senza beagle niente morsi");
    run([a, b], ctx, Math.ceil(COMPANION.koMs / DT) + 1);
    assert.equal(a.pet!.koMs <= 0, true, "è tornato");
    assert.equal(a.pet!.percent, 0, "senza danni");
  });
});

describe("il beagle fa da trampolino (#369 passo 4)", () => {
  // Lampione sopra il beagle che aspetta a terra, poi si lascia cadere
  function dropOnDog(keys: Partial<ReturnType<typeof emptyInput>> = {}) {
    const { ctx, f } = setup();
    const c = f.pet!;
    f.x = c.x;
    f.y = c.y - 90; // sotto la piattaforma sopra il punto di partenza
    f.vy = 0;
    f.onGround = false;
    f.input = { ...emptyInput(), ...keys };
    let minVy = 0;
    for (let i = 0; i < 40; i++) {
      run([f], ctx, 1);
      minVy = Math.min(minVy, f.vy);
    }
    return { f, minVy };
  }

  it("Lampione che gli cade sopra rimbalza in alto", () => {
    const { minVy } = dropOnDog();
    assert.ok(minVy <= -COMPANION.bounceVy + 50, `velocità verso l'alto ${Math.round(minVy)}`);
  });

  it("tenendo giù non rimbalza", () => {
    const { minVy } = dropOnDog({ down: true });
    assert.ok(minVy > -100, `velocità verso l'alto ${Math.round(minVy)}`);
  });
});
