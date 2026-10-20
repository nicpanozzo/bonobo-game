// Test degli oggetti (#17): comparsa, raccolta, lancio e colpo, senza server né client.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BIRRA, BONG, FIGHTER, FUNGO, ITEM_RULES, POWERUP, TICK_RATE } from "../constants";
import { ITEMS } from "../items";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { canBeHit, launch } from "./attacks";
import { createItemWorld, handleItemInput, itemStates, pickKind, poisonSlowed, stepItems, type Item, type ItemWorld } from "./items";

const DT = 1000 / TICK_RATE;
const SQUAT = Math.round(FIGHTER.jumpSquatMs / DT); // tick di preparazione al salto (#384 A3)
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

  it("compare una volta ogni tre banane (e due bong, due funghi di Teemo e due birre, #302)", () => {
    const kinds = Array.from({ length: 1000 }, (_, i) => pickKind(i / 1000));
    assert.equal(kinds.filter((k) => k === "birra").length, 200);
    assert.equal(kinds.filter((k) => k === "fiore").length, 100);
    assert.equal(kinds.filter((k) => k === "banana").length, 300);
    assert.equal(kinds.filter((k) => k === "bong").length, 200);
    assert.equal(kinds.filter((k) => k === "fungo").length, 200);
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
      run(world, fighters, ctx, 1 + SQUAT);
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

describe("il fungo di Teemo", () => {
  type Setup = ReturnType<typeof setup>;

  // a sta a x 400 guardando a destra, b dietro di lui (il palco va da 240 a 1040)
  function ready(): Setup {
    const s = setup();
    const [a, b] = s.fighters;
    a.x = 400;
    a.facing = 1;
    b.x = 290;
    run(s.world, s.fighters, s.ctx, 2);
    return s;
  }

  // a raccoglie un fungo che ha davanti e lo lancia con K (con giù lo posa ai piedi), poi aspetta che atterri
  function throwShroom(s: Setup, keys: Partial<InputState> = {}): Item {
    const [a] = s.fighters;
    const item: Item = { ...banana(a.x + 10, a.y), id: s.world.nextId++, kind: "fungo" };
    s.world.items.push(item);
    for (const k of [{ light: true }, {}, { heavy: true, ...keys }, {}]) {
      press(a, k);
      run(s.world, s.fighters, s.ctx, 1);
    }
    run(s.world, s.fighters, s.ctx, 90);
    return item;
  }

  const arm = (s: Setup) => run(s.world, s.fighters, s.ctx, Math.ceil(FUNGO.armMs / DT) + 1);

  function addFighter(s: Setup, x: number): Fighter {
    const f = createFighter({ id: `p${s.fighters.length}`, name: "C", characterId: "default", color: 0, team: 0, index: s.fighters.length, stocks: 3 }, stage);
    f.x = x;
    f.y = s.fighters[0].y;
    s.fighters.push(f);
    return f;
  }

  it("lanciato si piazza dove atterra: non si raccoglie più e nello snapshot dice di chi è", () => {
    const s = ready();
    const [a] = s.fighters;
    const fungo = throwShroom(s);
    assert.equal(ofType(s.ctx.events, "attack").length, 0, "raccogliere e lanciare non attacca");
    assert.ok(fungo.onGround);
    assert.ok(fungo.x > a.x + 60, "è volato avanti");
    assert.equal(fungo.ownerId, a.id);
    assert.equal(fungo.vx, 0);
    assert.equal(itemStates(s.world).find((i) => i.id === fungo.id)!.owner, a.id);
    a.x = fungo.x;
    for (const k of [{ light: true }, {}]) {
      press(a, k);
      run(s.world, s.fighters, s.ctx, 1);
    }
    assert.equal(fungo.heldBy, null, "un fungo piazzato non si raccoglie");
  });

  it("con giù si posa ai piedi", () => {
    const s = ready();
    const [a] = s.fighters;
    const fungo = throwShroom(s, { down: true });
    assert.ok(Math.abs(fungo.x - a.x) < 40);
    assert.equal(fungo.ownerId, a.id);
  });

  it("chi l'ha lanciato non lo fa scattare; un avversario sì: scoppio e veleno", () => {
    const s = ready();
    const [a, b] = s.fighters;
    const fungo = throwShroom(s, { down: true });
    arm(s);
    assert.ok(s.world.items.includes(fungo), "il proprietario ci sta sopra e non scatta");
    a.x = 1000;
    b.x = fungo.x;
    run(s.world, s.fighters, s.ctx, 1);
    assert.ok(!s.world.items.includes(fungo), "è scoppiato");
    assert.equal(b.percent, FUNGO.damage);
    assert.equal(b.powerup, "veleno");
    assert.equal(b.lastHitById, a.id, "il KO conta per chi l'ha lanciato");
    const blast = ofType(s.ctx.events, "powerUp").filter((e) => e.kind === "veleno");
    assert.equal(blast.length, 1);
    assert.equal(blast[0].itemId, fungo.id);
  });

  it("non scatta prima di essersi armato", () => {
    const s = ready();
    const [a, b] = s.fighters;
    const fungo = throwShroom(s, { down: true });
    fungo.armMs = FUNGO.armMs; // appena piazzato
    a.x = 1000;
    b.x = fungo.x;
    run(s.world, s.fighters, s.ctx, 1);
    assert.ok(s.world.items.includes(fungo));
    assert.equal(b.percent, 0);
  });

  it("la nube avvelena tutti gli avversari vicini, non quelli lontani", () => {
    const s = ready();
    const [a, b] = s.fighters;
    const fungo = throwShroom(s, { down: true });
    arm(s);
    a.x = 1000;
    const near = addFighter(s, fungo.x + 45);
    const far = addFighter(s, fungo.x + 300);
    b.x = fungo.x;
    run(s.world, s.fighters, s.ctx, 1);
    assert.equal(near.powerup, "veleno");
    assert.equal(near.percent, FUNGO.damage);
    assert.equal(far.powerup, null);
    assert.equal(far.percent, 0);
  });

  it("il veleno fa salire la percentuale a scatti per poisonMs, poi finisce", () => {
    const s = ready();
    const [a, b] = s.fighters;
    const fungo = throwShroom(s, { down: true });
    arm(s);
    a.x = 1000;
    b.x = fungo.x;
    run(s.world, s.fighters, s.ctx, 1);
    run(s.world, s.fighters, s.ctx, Math.round(FUNGO.poisonTickMs / DT) + 1);
    assert.equal(b.percent, FUNGO.damage + (FUNGO.poisonPerSec * FUNGO.poisonTickMs) / 1000, "il primo scatto");
    run(s.world, s.fighters, s.ctx, Math.ceil(FUNGO.poisonMs / DT) + 2);
    assert.equal(b.percent, FUNGO.damage + (FUNGO.poisonPerSec * FUNGO.poisonMs) / 1000);
    assert.equal(b.powerup, null);
  });

  it("all'inizio del veleno si va più piano, dopo slowMs no", () => {
    const walk = (poisoned: boolean) => {
      const s = ready();
      const [, b] = s.fighters;
      if (poisoned) {
        b.powerup = "veleno";
        b.powerupMs = FUNGO.poisonMs;
      }
      press(b, { right: true });
      run(s.world, s.fighters, s.ctx, 30);
      return { vx: Math.abs(b.vx), slowed: poisonSlowed(b), b, s };
    };
    const normal = walk(false);
    const slow = walk(true);
    assert.ok(slow.slowed);
    assert.ok(slow.vx < normal.vx, `${slow.vx} < ${normal.vx}`);
    run(slow.s.world, slow.s.fighters, slow.s.ctx, Math.ceil(FUNGO.slowMs / DT));
    assert.equal(poisonSlowed(slow.b), false);
    assert.equal(slow.b.powerup, "veleno", "il veleno continua");
  });

  it("un fungo che cade su un altro rimbalza avanti e si piazza più in là", () => {
    const s = ready();
    const [a] = s.fighters;
    const first = throwShroom(s, { down: true });
    arm(s);
    const second = throwShroom(s, { down: true });
    run(s.world, s.fighters, s.ctx, 60);
    assert.equal(second.ownerId, a.id);
    assert.ok(second.onGround);
    assert.ok(second.x - first.x >= 36, `rimbalzato in avanti: ${first.x} → ${second.x}`);
    assert.equal(s.world.items.filter((i) => i.kind === "fungo").length, 2);
  });

  it("chi è della squadra di chi l'ha lanciato non lo fa scattare", () => {
    const s = ready();
    const [a, b] = s.fighters;
    s.ctx.canHit = () => false;
    const fungo = throwShroom(s, { down: true });
    arm(s);
    a.x = 1000;
    b.x = fungo.x;
    run(s.world, s.fighters, s.ctx, 1);
    assert.ok(s.world.items.includes(fungo));
    assert.equal(b.percent, 0);
  });

  it("in volo colpisce come una banana, poi cade e si piazza lo stesso", () => {
    const s = ready();
    const [a, b] = s.fighters;
    b.x = a.x + 90;
    run(s.world, s.fighters, s.ctx, 2);
    const fungo = throwShroom(s);
    assert.ok(b.percent >= FUNGO.thrownDamage, `b preso in volo: ${b.percent}`);
    assert.ok(s.world.items.includes(fungo) || b.powerup === "veleno", "il fungo non si consuma nel colpo");
    assert.ok(ofType(s.ctx.events, "hit").some((e) => e.itemKind === "fungo"));
  });

  it("i funghi piazzati non tolgono posto agli oggetti che cadono", () => {
    const s = ready();
    throwShroom(s, { down: true });
    s.ctx.events.length = 0;
    s.world.spawnTimer = 0;
    run(s.world, s.fighters, s.ctx, 1);
    assert.equal(ofType(s.ctx.events, "itemSpawn").length, 1);
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
