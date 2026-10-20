// Test degli oggetti (#17): comparsa, raccolta, lancio e colpo, senza server né client.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BIRRA, BONG, FIGHTER, FUNGHI, ITEM_RULES, POWERUP, TICK_RATE } from "../constants";
import { ITEMS } from "../items";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { canBeHit, launch } from "./attacks";
import { createItemWorld, handleItemInput, itemStates, pickKind, stepItems, type Item, type ItemWorld } from "./items";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);

function setup() {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [0, 1].map((i) =>
    createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  const world = createItemWorld(42);
  return { ctx, fighters, world };
}

function run(world: ItemWorld, fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) {
    handleItemInput(world, fighters, ctx);
    stepWorld(fighters, DT, ctx);
    stepItems(world, fighters, DT, ctx);
  }
}

function press(f: Fighter, keys: Partial<InputState>) {
  f.input = { ...emptyInput(), ...keys };
}

const ofType = <T extends GameEvent["type"]>(events: GameEvent[], type: T) =>
  events.filter((e): e is Extract<GameEvent, { type: T }> => e.type === type);

function banana(x: number, y: number): Item {
  return { id: 99, kind: "banana", x, y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: true, riding: -1, thrownBy: null, lifeMs: ITEM_RULES.lifeMs };
}

describe("oggetti", () => {
  it("dopo l'attesa iniziale ne cade uno che si posa su una superficie", () => {
    const { ctx, fighters, world } = setup();
    run(world, fighters, ctx, Math.ceil(ITEM_RULES.firstSpawnMs / DT) + 90);
    assert.equal(ofType(ctx.events, "itemSpawn").length, 1);
    assert.equal(world.items.length, 1);
    const item = world.items[0];
    assert.equal(item.onGround, true);
    const surfaces = [...stage.solids, ...stage.platforms].map((s) => s.y);
    assert.ok(surfaces.includes(item.y), "è appoggiato su un blocco o una piattaforma");
  });

  it("stesso seme, stessa sequenza", () => {
    const a = setup();
    const b = setup();
    run(a.world, a.fighters, a.ctx, Math.ceil(ITEM_RULES.firstSpawnMs / DT) + 1);
    run(b.world, b.fighters, b.ctx, Math.ceil(ITEM_RULES.firstSpawnMs / DT) + 1);
    assert.deepEqual(ofType(a.ctx.events, "itemSpawn"), ofType(b.ctx.events, "itemSpawn"));
  });

  it("J vicino all'oggetto lo raccoglie senza attaccare, J di nuovo lo lancia e colpisce chi è davanti", () => {
    const { ctx, fighters, world } = setup();
    const [a, b] = fighters;
    a.x = 500;
    a.facing = 1;
    b.x = 800;
    world.items.push(banana(a.x + 10, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(world.items[0].heldBy, a.id);
    assert.equal(ofType(ctx.events, "itemPick").length, 1);
    assert.equal(ofType(ctx.events, "attack").length, 0, "il tasto non fa partire un attacco");
    press(a, {});
    run(world, fighters, ctx, 2);
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "itemThrow").length, 1);
    press(a, {});
    run(world, fighters, ctx, 40);
    const hits = ofType(ctx.events, "hit");
    assert.equal(hits.length, 1);
    assert.equal(hits[0].kind, "item");
    assert.equal(hits[0].targetId, b.id);
    assert.equal(b.percent, ITEMS.banana.damage);
    assert.equal(world.items.length, 0, "l'oggetto si consuma");
    assert.equal(a.percent, 0, "chi lancia non si colpisce da solo");
  });

  it("giù + J posa l'oggetto senza lanciarlo", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(banana(a.x, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    press(a, {});
    run(world, fighters, ctx, 2);
    press(a, { light: true, down: true });
    run(world, fighters, ctx, 1);
    press(a, {});
    run(world, fighters, ctx, 30);
    assert.equal(ofType(ctx.events, "itemThrow").length, 0);
    assert.equal(world.items[0].heldBy, null);
    assert.equal(world.items[0].onGround, true);
    assert.ok(Math.abs(world.items[0].x - a.x) < FIGHTER.width, "è caduto ai piedi");
  });

  it("si appoggia su un ascensore e sale con lui (#14)", () => {
    const { fighters, world } = setup();
    // Ascensore a sinistra del palco: fermo in basso per 1 s, poi sale di 200 pixel in 1 s
    const elevator = { width: 100, path: [{ x: 40, y: 500 }, { x: 40, y: 300 }], periodMs: 4000, pauseMs: 1000 };
    const ctx: PhysicsContext = { stage: { ...stage, movers: [elevator] }, events: [] };
    world.items.push({ ...banana(90, 420), onGround: false });
    run(world, fighters, ctx, 30);
    assert.equal(world.items[0].y, 500, "atterrato sull'ascensore");
    assert.equal(world.items[0].riding, 0);
    run(world, fighters, ctx, 120);
    assert.ok(Math.abs(world.items[0].y - 300) < 2, `in cima con l'ascensore (y = ${world.items[0].y})`);
  });

  it("chi viene colpito molla l'oggetto", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(banana(a.x, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    a.hitstunTimer = 300;
    a.hitstun = true;
    press(a, {});
    run(world, fighters, ctx, 1);
    assert.equal(world.items[0].heldBy, null);
  });
});

describe("zone degli oggetti (#253)", () => {
  it("con una zona pesante gli oggetti cadono quasi sempre lì", () => {
    const spotted = { ...stage, itemSpots: [{ x: 300, y: 560, width: 200, weight: 20 }] };
    let inSpot = 0;
    const total = 40;
    for (let seed = 1; seed <= total; seed++) {
      const ctx: PhysicsContext = { stage: spotted, events: [] };
      const world = createItemWorld(seed);
      run(world, [], ctx, Math.round(ITEM_RULES.firstSpawnMs / DT) + 1);
      const spawn = ofType(ctx.events, "itemSpawn")[0];
      assert.ok(spawn, `seme ${seed}: è caduto un oggetto`);
      if (spawn.x >= 300 && spawn.x <= 500) inSpot++;
    }
    assert.ok(inSpot >= total * 0.7, `nella zona ${inSpot} volte su ${total}`);
  });
});

describe("oggetti scelti nelle regole della stanza", () => {
  it("cadono solo i tipi scelti, e quanti se ne scelgono", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const world = createItemWorld(7, { everyMs: 500, maxOnStage: 3, kinds: ["birra"] });
    run(world, [], ctx, Math.round(10000 / DT));
    const spawns = ofType(ctx.events, "itemSpawn");
    assert.ok(spawns.length >= 3, `ne sono caduti ${spawns.length}`);
    assert.ok(spawns.every((e) => e.kind === "birra"));
    assert.ok(world.items.length <= 3);
  });

  it("pickKind sceglie solo tra quelli dati", () => {
    for (let i = 0; i < 100; i++) assert.ok(["fiore", "bong"].includes(pickKind(i / 100, ["bong", "fiore"])));
  });
});

describe("il fiore, oggetto da consumare (#231)", () => {
  const fiore = (x: number, y: number): Item => ({ ...banana(x, y), kind: "fiore" });

  it("compare una volta ogni tre banane (e due bong, due sacchetti di funghetti e due birre, #302)", () => {
    const kinds = Array.from({ length: 1000 }, (_, i) => pickKind(i / 1000));
    assert.equal(kinds.filter((k) => k === "birra").length, 200);
    assert.equal(kinds.filter((k) => k === "fiore").length, 100);
    assert.equal(kinds.filter((k) => k === "banana").length, 300);
    assert.equal(kinds.filter((k) => k === "bong").length, 200);
    assert.equal(kinds.filter((k) => k === "funghetti").length, 200);
    assert.equal(kinds.filter((k) => k === "fungo").length, 0, "i funghetti piantati non cadono dal cielo");
  });

  it("raccolto sparisce e potenzia subito, senza attaccare", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(fiore(a.x + 10, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(world.items.length, 0);
    assert.equal(a.powerup, "fiore");
    assert.ok(a.powerupMs > POWERUP.flowerMs - 2 * DT);
    assert.equal(a.invulnerable, true);
    assert.equal(canBeHit(a), false, "intoccabile");
    assert.equal(ofType(ctx.events, "powerUp").length, 1);
    assert.equal(ofType(ctx.events, "itemPick").length, 0);
    assert.equal(ofType(ctx.events, "attack").length, 0);
  });

  it("i colpi fanno ×1,3 di danno", () => {
    const { ctx, fighters } = setup();
    const [a, b] = fighters;
    launch(b, a, "light", 0, 0, ctx);
    const normal = b.percent;
    b.percent = 0;
    a.powerup = "fiore";
    a.powerupMs = POWERUP.flowerMs;
    launch(b, a, "light", 0, 0, ctx);
    assert.equal(b.percent, Math.round(normal * POWERUP.damageMult * 10) / 10);
  });

  it("ci si muove a ×0,75, il salto resta uguale", () => {
    const speeds = [false, true].map((powered) => {
      const { ctx, fighters, world } = setup();
      const [a] = fighters;
      if (powered) {
        a.powerup = "fiore";
        a.powerupMs = POWERUP.flowerMs;
      }
      press(a, { right: true });
      run(world, fighters, ctx, 3);
      const vx = a.vx;
      press(a, { jump: true });
      run(world, fighters, ctx, 1);
      return { vx, vy: a.vy };
    });
    assert.ok(speeds[0].vx > 0 && speeds[0].vy < 0, "si cammina e si salta");
    assert.ok(Math.abs(speeds[1].vx - speeds[0].vx * POWERUP.speedMult) < 1e-6);
    assert.equal(speeds[1].vy, speeds[0].vy);
  });

  it("finisce dopo il tempo, con l'evento, e si torna colpibili", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    world.items.push(fiore(a.x, a.y));
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    press(a, {});
    run(world, fighters, ctx, Math.ceil(POWERUP.flowerMs / DT) + 1);
    assert.equal(a.powerup, null);
    assert.equal(a.powerupMs, 0);
    assert.equal(a.invulnerable, false);
    assert.equal(ofType(ctx.events, "powerEnd").length, 1);
  });

  it("uscire dall'arena toglie la vita e il fiore", () => {
    const { ctx, fighters, world } = setup();
    const [a] = fighters;
    a.powerup = "fiore";
    a.powerupMs = POWERUP.flowerMs;
    a.y = stage.blastZone.bottom + 50;
    run(world, fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "ko").length, 1);
    assert.equal(a.powerup, null);
  });
});

describe("il bong, in tre fasi (#302)", () => {
  const bong = (x: number, y: number): Item => ({ ...banana(x, y), kind: "bong", loadMs: -1 });
  const loadTicks = Math.ceil(BONG.loadMs / DT) + 1;

  // a raccoglie il bong con J e lo carica tenendo J per ticks tick
  function pickAndLoad(ticks: number) {
    const s = setup();
    const [a, b] = s.fighters;
    a.x = 500;
    a.facing = 1;
    b.x = 900;
    s.world.items.push(bong(a.x + 10, a.y));
    press(a, { light: true });
    run(s.world, s.fighters, s.ctx, 1);
    press(a, {});
    run(s.world, s.fighters, s.ctx, 1);
    press(a, { light: true });
    run(s.world, s.fighters, s.ctx, ticks);
    return s;
  }

  it("raccolto si tiene in mano; tenendo J si carica senza attaccare", () => {
    const { ctx, world, fighters } = pickAndLoad(10);
    assert.equal(world.items[0].heldBy, fighters[0].id);
    assert.ok(world.items[0].loadMs! > 0);
    assert.ok(itemStates(world)[0].load! > 0 && itemStates(world)[0].load! < 1, "la carica va nello snapshot");
    assert.equal(ofType(ctx.events, "bong").filter((e) => e.phase === "load").length, 1);
    assert.equal(ofType(ctx.events, "attack").length, 0);
    assert.equal(ofType(ctx.events, "itemThrow").length, 0);
  });

  it("lasciando J prima della carica piena la carica si perde", () => {
    const { ctx, world, fighters } = pickAndLoad(10);
    press(fighters[0], {});
    run(world, fighters, ctx, 1);
    assert.equal(world.items[0].loadMs, -1);
    assert.equal(fighters[0].powerup, null);
  });

  it("carico, lasciando J si è fatti: il bong sparisce, si è più leggeri ma colpibili", () => {
    const { ctx, world, fighters } = pickAndLoad(loadTicks);
    const [a] = fighters;
    press(a, {});
    run(world, fighters, ctx, 1);
    assert.equal(world.items.length, 0);
    assert.equal(a.powerup, "bong");
    assert.equal(a.invulnerable, false);
    assert.equal(canBeHit(a), true);
    const powerUp = ofType(ctx.events, "powerUp");
    assert.equal(powerUp.length, 1);
    assert.equal(powerUp[0].kind, "bong");
    // Più leggeri: la stessa caduta accelera meno
    const vy = (high: boolean) => {
      const s = setup();
      const [f] = s.fighters;
      if (high) {
        f.powerup = "bong";
        f.powerupMs = BONG.highMs;
      }
      f.y -= 300;
      f.onGround = false;
      f.vy = 0;
      run(s.world, s.fighters, s.ctx, 3);
      return f.vy;
    };
    assert.ok(Math.abs(vy(true) - vy(false) * BONG.gravityMult) < 1);
  });

  it("J soffia la nuvola: colpisce chi è vicino, più forte se si aspetta", () => {
    const damage = (waitMs: number) => {
      const { ctx, world, fighters } = pickAndLoad(loadTicks);
      const [a, b] = fighters;
      press(a, {});
      run(world, fighters, ctx, 1);
      run(world, fighters, ctx, Math.round(waitMs / DT));
      b.x = a.x + 60;
      b.y = a.y;
      b.vx = b.vy = 0;
      press(a, { light: true });
      run(world, fighters, ctx, 1);
      assert.equal(a.powerup, null);
      assert.equal(ofType(ctx.events, "bong").filter((e) => e.phase === "smoke").length, 1);
      assert.equal(ofType(ctx.events, "attack").length, 0, "la nuvola non fa partire un attacco");
      const hits = ofType(ctx.events, "hit");
      assert.equal(hits.length, 1);
      assert.equal(hits[0].itemKind, "bong");
      assert.ok(b.vx > 0, "vola via");
      return b.percent;
    };
    const soon = damage(0);
    const late = damage(BONG.highMs - 500);
    assert.ok(soon >= BONG.minDamage && soon < BONG.minDamage + 2);
    assert.ok(late > soon + 10 && late <= BONG.maxDamage);
  });

  it("lontano dalla nuvola non si prende niente", () => {
    const { ctx, world, fighters } = pickAndLoad(loadTicks);
    const [a, b] = fighters;
    press(a, {});
    run(world, fighters, ctx, 1);
    b.x = a.x + BONG.cloudOffsetX + BONG.cloudRadius + 60;
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(b.percent, 0);
  });

  it("se non si soffia in tempo si crolla tramortiti", () => {
    const { ctx, world, fighters } = pickAndLoad(loadTicks);
    const [a] = fighters;
    press(a, {});
    run(world, fighters, ctx, Math.ceil(BONG.highMs / DT) + 2);
    assert.equal(a.powerup, null);
    assert.equal(a.stunned, true);
    assert.equal(ofType(ctx.events, "bong").filter((e) => e.phase === "stun").length, 1);
    run(world, fighters, ctx, Math.ceil(BONG.stunMs / DT) + 1);
    assert.equal(a.stunned, false);
  });

  it("colpiti mentre lo si carica, cade di mano e la carica si perde", () => {
    const { ctx, world, fighters } = pickAndLoad(10);
    const [a, b] = fighters;
    launch(a, b, "heavy", 0, 0, ctx);
    run(world, fighters, ctx, 1);
    assert.equal(world.items[0].heldBy, null);
    assert.equal(world.items[0].loadMs, -1);
  });

  it("con K si lancia come gli altri oggetti", () => {
    const s = setup();
    const [a] = s.fighters;
    s.world.items.push(bong(a.x + 10, a.y));
    press(a, { heavy: true });
    run(s.world, s.fighters, s.ctx, 1);
    press(a, {});
    run(s.world, s.fighters, s.ctx, 1);
    press(a, { heavy: true });
    run(s.world, s.fighters, s.ctx, 1);
    assert.equal(ofType(s.ctx.events, "itemThrow").length, 1);
    assert.equal(s.world.items[0].thrown, true);
  });
});

describe("i funghetti di Teemo (#302)", () => {
  const bag = (x: number, y: number): Item => ({ ...banana(x, y), kind: "funghetti" });

  // a raccoglie il sacchetto e pianta un funghetto dove sta
  function plant() {
    const s = setup();
    const [a, b] = s.fighters;
    a.x = 500;
    b.x = 900;
    s.world.items.push(bag(a.x + 10, a.y));
    for (const keys of [{ light: true }, {}, { light: true, down: true }, {}]) {
      press(a, keys);
      run(s.world, s.fighters, s.ctx, 1);
    }
    return s;
  }

  it("giù + J pianta un funghetto ai piedi, senza attaccare; tre e il sacchetto è finito", () => {
    const { ctx, world, fighters } = plant();
    const [a] = fighters;
    const planted = world.items.filter((i) => i.kind === "fungo");
    assert.equal(planted.length, 1);
    assert.equal(planted[0].ownerId, a.id);
    assert.equal(itemStates(world).find((i) => i.kind === "fungo")!.owner, a.id);
    assert.equal(ofType(ctx.events, "attack").length, 0);
    for (let k = 0; k < 2; k++) {
      a.x += 60;
      for (const keys of [{ light: true, down: true }, {}]) {
        press(a, keys);
        run(world, fighters, ctx, 1);
      }
    }
    assert.equal(world.items.filter((i) => i.kind === "fungo").length, FUNGHI.uses);
    assert.equal(world.items.filter((i) => i.kind === "funghetti").length, 0, "sacchetto vuoto, sparito");
  });

  it("chi lo pianta non lo fa scattare; chi lo calpesta prende danno e ha destra e sinistra invertite", () => {
    const { ctx, world, fighters } = plant();
    const [a, b] = fighters;
    const fungo = world.items.find((i) => i.kind === "fungo")!;
    run(world, fighters, ctx, Math.ceil(FUNGHI.armMs / DT) + 1);
    assert.ok(world.items.includes(fungo), "il proprietario ci sta sopra e non scatta");
    a.x = 200;
    b.x = fungo.x;
    b.y = fungo.y;
    run(world, fighters, ctx, 1);
    assert.ok(!world.items.includes(fungo));
    assert.equal(b.percent, FUNGHI.damage);
    assert.equal(b.powerup, "trip");
    run(world, fighters, ctx, 30); // a terra
    press(b, { right: true });
    run(world, fighters, ctx, 3);
    assert.ok(b.vx < 0, "destra porta a sinistra");
    assert.equal(b.input.right, true, "l'input vero resta quello premuto");
    run(world, fighters, ctx, Math.ceil(FUNGHI.tripMs / DT));
    assert.equal(b.powerup, null);
    press(b, { right: true });
    run(world, fighters, ctx, 3);
    assert.ok(b.vx > 0, "finito il viaggio si torna normali");
  });

  it("i funghetti piantati non tolgono posto agli oggetti che cadono", () => {
    const { ctx, world, fighters } = plant();
    world.spawnTimer = 0;
    run(world, fighters, ctx, 1);
    assert.equal(ofType(ctx.events, "itemSpawn").filter((e) => e.kind !== "fungo").length, 1);
  });
});

describe("la birra (#302)", () => {
  it("raccolta dà il cappello: colpi ×1,4, si barcolla ma si resta colpibili", () => {
    const { ctx, fighters, world } = setup();
    const [a, b] = fighters;
    world.items.push({ ...banana(a.x + 10, a.y), kind: "birra" });
    press(a, { light: true });
    run(world, fighters, ctx, 1);
    assert.equal(a.powerup, "birra");
    assert.equal(a.invulnerable, false);
    launch(b, a, "light", 0, 0, ctx);
    const drunk = b.percent;
    b.percent = 0;
    a.powerup = null;
    launch(b, a, "light", 0, 0, ctx);
    assert.equal(drunk, Math.round(b.percent * BIRRA.damageMult * 10) / 10);
    a.powerup = "birra";
    press(a, {});
    const xs: number[] = [];
    for (let i = 0; i < 40; i++) {
      run(world, fighters, ctx, 1);
      xs.push(a.vx);
    }
    assert.ok(Math.max(...xs) > 20 && Math.min(...xs) < -20, "da fermi si barcolla avanti e indietro");
  });
});
