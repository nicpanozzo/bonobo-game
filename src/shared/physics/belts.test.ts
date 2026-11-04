import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BELT, PACK, TICK_RATE, WORLD } from "../constants";
import type { Belt, Hazard, SoundPad, StageSpec } from "../stages";
import { STAGES } from "../stages";
import { beltAutoDir, beltVelocity } from "./belts";
import { createFighter, emptyInput, stepWorld, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;

const belt: Belt = { x: 100, y: 650, width: 600, speed: 150, dir: 1, flipEveryMs: 10000, group: "nastri" };
const lever = (x: number): SoundPad => ({ x, y: 650, width: 50, sound: "leva", cooldownMs: 8000, effect: { group: "nastri", durationMs: 3000, flip: true } });

function stage(): StageSpec {
  return {
    id: "prova",
    name: "Prova",
    solids: [{ x: 0, y: 650, width: WORLD.width, height: 50 }],
    platforms: [],
    belts: [belt],
    pads: [lever(900), lever(1000)],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: 650 }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
}

function setup(x: number) {
  const s = stage();
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 1000 };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, s);
  f.x = x;
  f.y = 650;
  f.onGround = true;
  return { ctx, f };
}

describe("nastri trasportatori (La Fabbrica)", () => {
  it("il verso si inverte da solo a ogni giro", () => {
    assert.equal(beltAutoDir(belt, 0), 1);
    assert.equal(beltAutoDir(belt, 9999), 1);
    assert.equal(beltAutoDir(belt, 10000), -1);
    assert.equal(beltAutoDir(belt, 20000), 1);
    assert.equal(beltAutoDir({ ...belt, flipEveryMs: undefined }, 50000), 1, "senza giro non cambia mai");
  });

  it("una leva lo inverte per la sua durata, due lo mandano al turbo", () => {
    const pads = [lever(900), lever(1000)];
    assert.equal(beltVelocity(belt, 2000, pads, [null, null]), 150);
    assert.equal(beltVelocity(belt, 2000, pads, [1000, null]), -150, "tirata da 1 s");
    assert.equal(beltVelocity(belt, 4500, pads, [1000, null]), 150, "finita dopo 3 s");
    assert.equal(beltVelocity(belt, 2000, pads, [1000, 1500]), -150 * BELT.turboMult, "turbo");
    assert.equal(beltVelocity(belt, 12000, pads, [11000, null]), 150, "nel giro al contrario la leva lo rimette dritto");
  });

  it("chi sta fermo sul nastro viene portato, chi è in aria no", () => {
    const { ctx, f } = setup(400);
    for (let i = 0; i < TICK_RATE; i++) stepWorld([f], DT, ctx);
    assert.ok(Math.abs(f.x - 550) < 4, `dopo 1 s a 150 px/s: ${f.x}`);
    const air = setup(400);
    air.f.y = 400;
    air.f.onGround = false;
    for (let i = 0; i < 10; i++) stepWorld([air.f], DT, air.ctx);
    assert.equal(air.f.x, 400, "in aria il nastro non spinge");
  });

  it("chi cammina contro il nastro avanza più piano", () => {
    const { ctx, f } = setup(600);
    f.input = { ...emptyInput(), left: true };
    for (let i = 0; i < TICK_RATE / 2; i++) stepWorld([f], DT, ctx);
    const against = 600 - f.x;
    const free = setup(600);
    free.ctx.stage = { ...free.ctx.stage, belts: [] };
    free.f.input = { ...emptyInput(), left: true };
    for (let i = 0; i < TICK_RATE / 2; i++) stepWorld([free.f], DT, free.ctx);
    assert.ok(against > 0 && against < 600 - free.f.x - 50, `contro ${against}, libero ${600 - free.f.x}`);
  });

  it("La Fabbrica: due nastri verso la fossa, due leve sulle passerelle e due presse", () => {
    const s = STAGES.fabbrica;
    assert.equal(s.belts?.length, 2);
    assert.ok(s.belts![0].dir === 1 && s.belts![1].dir === -1, "all'inizio portano verso il centro");
    assert.equal(s.pads?.filter((p) => p.effect.flip).length, 2);
    assert.equal(s.hazards?.filter((h) => h.kind === "pressa").length, 2);
    for (const b of s.belts!) assert.ok(s.solids.some((r) => r.y === b.y && r.x <= b.x && r.x + r.width >= b.x + b.width), "il nastro sta su un blocco");
  });

  describe("impacchettatrice", () => {
    const packer: Hazard = { kind: "pressa", x: 350, y: 560, width: 100, height: 90, damage: 4, knockback: 0, knockbackGrowth: 0, angleDeg: 90, pack: { baseMs: 1000, perPercentMs: 10 } };

    it("chiude in una scatola senza lanciare, e il nastro se la porta via", () => {
      const { ctx, f } = setup(400);
      ctx.stage = { ...ctx.stage, hazards: [packer] };
      f.percent = 50;
      stepWorld([f], DT, ctx);
      assert.ok(f.packed && f.stunned, "impacchettato");
      assert.equal(f.percent, 54);
      assert.equal(f.vy, 0, "niente lancio");
      assert.ok(ctx.events.some((e) => e.type === "hazard" && e.knockback === 0));
      const x0 = f.x;
      f.input = { ...emptyInput(), left: true };
      for (let i = 0; i < TICK_RATE; i++) stepWorld([f], DT, ctx);
      assert.ok(f.packed, "1,5 s al 54%: dopo 1 s è ancora dentro");
      assert.ok(Math.abs(f.x - x0 - 150) < 4, `il nastro lo porta, i tasti no: ${f.x - x0}`);
      for (let i = 0; i < TICK_RATE; i++) stepWorld([f], DT, ctx);
      assert.ok(!f.packed && !f.stunned, "uscito da solo");
    });

    it("premendo i tasti si esce prima", () => {
      const { ctx, f } = setup(400);
      ctx.stage = { ...ctx.stage, hazards: [packer], belts: [] };
      stepWorld([f], DT, ctx);
      let ticks = 0;
      while (f.packed && ticks < 200) {
        f.input = { ...emptyInput(), jump: ticks % 2 === 0, light: ticks % 2 === 0 };
        stepWorld([f], DT, ctx);
        ticks++;
      }
      const alone = Math.ceil(1000 / DT);
      assert.ok(ticks < alone * 0.7, `${ticks} tick premendo, ${alone} da solo (${PACK.mashMs} ms a tasto)`);
    });
  });
});

