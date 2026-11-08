// Test degli oggetti per categoria (gear.ts): ciabatte, petardi, caffè e brownie, provati sui cinque principali.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, GEAR, ITEM_RULES, TICK_RATE } from "../constants";
import { DROPPABLE_ITEMS, ITEM_CATEGORIES, ITEMS } from "../items";
import { getStage } from "../stages";
import type { GameEvent, InputState } from "../types";
import { bodyBox } from "./attacks";
import { BROWNIE_EFFECTS } from "./gear";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { createItemWorld, handleItemInput, itemStates, stepItems, type Item, type ItemWorld } from "./items";

const DT = 1000 / TICK_RATE;
const stage = getStage(undefined);
const CORE = ["bradipo", "marcomunista", "orsoblu", "egiainuso", "elvedeo"];

function setup(characterId = "default", other = "default") {
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = [characterId, other].map((c, i) => createFighter({ id: `p${i}`, name: `P${i}`, characterId: c, color: 0, team: 0, index: i, stocks: 3 }, stage));
  const world = createItemWorld(42, { everyMs: 1e9 });
  world.spawnTimer = 1e9; // niente oggetti dal cielo: li mettiamo noi
  const [a, b] = fighters;
  a.x = 500;
  a.facing = 1;
  b.x = 800;
  return { ctx, fighters, world, a, b };
}

function run(world: ItemWorld, fighters: Fighter[], ctx: PhysicsContext, ticks: number) {
  for (let i = 0; i < ticks; i++) {
    handleItemInput(world, fighters, ctx);
    stepWorld(fighters, DT, ctx);
    stepItems(world, fighters, DT, ctx);
  }
}

const press = (f: Fighter, keys: Partial<InputState>) => (f.input = { ...emptyInput(), ...keys });
const ofType = <T extends GameEvent["type"]>(events: GameEvent[], type: T) => events.filter((e): e is Extract<GameEvent, { type: T }> => e.type === type);

function item(kind: string, x: number, y: number): Item {
  return { id: 99, kind, x, y, vx: 0, vy: 0, heldBy: null, thrown: false, onGround: true, riding: -1, thrownBy: null, lifeMs: ITEM_RULES.lifeMs };
}

// Raccoglie l'oggetto ai piedi e lo usa subito (consumo) o lo tiene in mano
function pickUp(s: ReturnType<typeof setup>, kind: string) {
  s.world.items.push(item(kind, s.a.x + 10, s.a.y));
  press(s.a, { light: true });
  run(s.world, s.fighters, s.ctx, 1);
  press(s.a, {});
  run(s.world, s.fighters, s.ctx, 2);
}

function throwHeld(s: ReturnType<typeof setup>, keys: Partial<InputState> = {}) {
  press(s.a, { light: true, ...keys });
  run(s.world, s.fighters, s.ctx, 1);
  press(s.a, {});
}

describe("oggetti per categoria", () => {
  it("ogni oggetto che cade ha una categoria, e ogni versione rara è più rara del suo oggetto", () => {
    const ids = ITEM_CATEGORIES.map((c) => c.id);
    for (const k of DROPPABLE_ITEMS) assert.ok(ITEMS[k].category && ids.includes(ITEMS[k].category!), `${k} ha una categoria`);
    const order = ["mai", "rarissimo", "raro", "normale", "comune"];
    for (const spec of Object.values(ITEMS)) {
      if (!spec.rareOf) continue;
      const base = ITEMS[spec.rareOf];
      assert.ok(base, `${spec.id}: ${spec.rareOf} esiste`);
      assert.equal(spec.category, base.category, `${spec.id} è della stessa categoria`);
      assert.ok(order.indexOf(spec.rarity) < order.indexOf(base.rarity), `${spec.id} cade più di rado di ${base.id}`);
    }
  });

  it("la ciabatta vola tesa e colpisce chi è davanti, per tutti e cinque i principali", () => {
    for (const c of CORE) {
      const s = setup(c, "default");
      s.b.x = 760;
      pickUp(s, "ciabatta");
      assert.equal(s.world.items[0].heldBy, s.a.id, `${c} la tiene in mano`);
      throwHeld(s);
      run(s.world, s.fighters, s.ctx, 30);
      const hit = ofType(s.ctx.events, "hit").find((e) => e.itemKind === "ciabatta");
      assert.ok(hit, `${c}: la ciabatta colpisce`);
      assert.equal(hit!.damage, ITEMS.ciabatta.damage);
    }
  });

  it("la ciabatta della mamma insegue: lanciata dalla parte sbagliata torna indietro e colpisce", () => {
    const s = setup();
    s.b.x = 300; // dietro ad a
    pickUp(s, "ciabattaMamma");
    s.a.facing = 1;
    throwHeld(s);
    run(s.world, s.fighters, s.ctx, Math.ceil(GEAR.ciabattaMamma.homingMs / DT));
    const hit = ofType(s.ctx.events, "hit").find((e) => e.itemKind === "ciabattaMamma");
    assert.ok(hit, "la ciabatta fa inversione e prende b");
    assert.equal(hit!.targetId, s.b.id);
  });

  it("il petardo si attacca a chi colpisce e dopo la miccia scoppia, facendolo volare", () => {
    const s = setup();
    s.b.x = 700;
    pickUp(s, "petardo");
    throwHeld(s);
    run(s.world, s.fighters, s.ctx, 20);
    assert.equal(ofType(s.ctx.events, "gear").filter((e) => e.phase === "stick").length, 1, "si attacca a b");
    assert.equal(s.b.percent, 0, "attaccarsi non fa danno");
    const state = itemStates(s.world)[0];
    assert.ok(state.load !== undefined && state.load > 0, "la miccia brucia (load)");
    run(s.world, s.fighters, s.ctx, Math.ceil(GEAR.petardo.fuseMs / DT));
    assert.equal(ofType(s.ctx.events, "gear").filter((e) => e.phase === "boom").length, 1);
    assert.equal(s.b.percent, GEAR.petardo.damage);
    assert.ok(s.b.vy < 0, "vola in alto");
    assert.equal(s.b.lastHitById, s.a.id, "il KO va a chi l'ha acceso");
    assert.equal(s.world.items.length, 0);
  });

  it("un petardo acceso non si raccoglie, e scoppia anche addosso a chi l'ha posato", () => {
    const s = setup();
    pickUp(s, "petardo");
    throwHeld(s, { down: true }); // posato ai piedi
    press(s.a, { light: true });
    run(s.world, s.fighters, s.ctx, 1);
    assert.equal(s.world.items[0].heldBy, null, "acceso, non si riprende");
    press(s.a, {});
    run(s.world, s.fighters, s.ctx, Math.ceil(GEAR.petardo.fuseMs / DT) + 2);
    assert.equal(s.a.percent, GEAR.petardo.damage, "come le bombe di Isaac");
    assert.equal(s.a.lastHitById, null, "nessuno prende il KO di chi si fa saltare da solo");
  });

  it("il petardo a grappolo sparge petardini che scoppiano a loro volta", () => {
    const s = setup();
    pickUp(s, "petardoGrappolo");
    throwHeld(s, { down: true });
    s.a.x = 200; // si allontana
    run(s.world, s.fighters, s.ctx, Math.ceil(GEAR.petardo.fuseMs / DT) + 2);
    assert.equal(s.world.items.filter((i) => i.kind === "petardino").length, GEAR.petardo.clusterCount);
    run(s.world, s.fighters, s.ctx, Math.ceil((GEAR.petardo.clusterFuseMs + GEAR.petardo.clusterCount * GEAR.petardo.clusterStepMs) / DT) + 2);
    assert.equal(ofType(s.ctx.events, "gear").filter((e) => e.phase === "boom").length, 1 + GEAR.petardo.clusterCount);
    assert.equal(s.world.items.length, 0);
  });

  it("il caffè fa correre più veloce", () => {
    const slow = setup();
    const fast = setup();
    pickUp(fast, "caffe");
    assert.equal(fast.a.powerup, "caffe");
    for (const s of [slow, fast]) {
      s.a.x = 500;
      press(s.a, { right: true });
      run(s.world, s.fighters, s.ctx, 20);
    }
    assert.ok(fast.a.x > slow.a.x + 20, `col caffè più lontano: ${fast.a.x} contro ${slow.a.x}`);
  });

  it("con la moka a razzo tenendo il salto si vola in alto", () => {
    const s = setup();
    pickUp(s, "moka");
    assert.equal(s.a.powerup, "razzo");
    const groundY = s.a.y;
    press(s.a, { jump: true });
    run(s.world, s.fighters, s.ctx, 90);
    assert.ok(s.a.y < groundY - FIGHTER.height * 3, `sale ben oltre un salto: ${groundY - s.a.y}`);
  });

  it("il brownie spaziale non fa niente per un po', poi sale l'effetto scelto quando lo si è mangiato", () => {
    const s = setup();
    pickUp(s, "brownie");
    assert.equal(s.a.powerup, "brownie");
    const next = s.a.brownieNext;
    assert.ok(next && (BROWNIE_EFFECTS as readonly string[]).includes(next));
    run(s.world, s.fighters, s.ctx, Math.ceil(GEAR.brownie.delayMs / DT) + 1);
    assert.equal(s.a.powerup, next);
    assert.ok(ofType(s.ctx.events, "powerUp").some((e) => e.kind === next && e.itemId === -1));
  });

  it("gigante: corpo più grande, colpi più forti; il brownie della nonna fa tremare la terra atterrando", () => {
    const s = setup();
    const before = bodyBox(s.a);
    pickUp(s, "brownieNonna");
    assert.equal(s.a.powerup, "colosso");
    const big = bodyBox(s.a);
    assert.ok(Math.abs(big.h - before.h * GEAR.size.giant) < 0.01);
    s.b.x = s.a.x + 120;
    press(s.a, { jump: true });
    run(s.world, s.fighters, s.ctx, 3);
    press(s.a, {});
    run(s.world, s.fighters, s.ctx, 80);
    assert.ok(ofType(s.ctx.events, "gear").some((e) => e.phase === "quake"), "atterrando trema");
    assert.equal(s.b.percent, GEAR.size.quakeDamage, "chi è vicino a terra salta via");
  });
});
