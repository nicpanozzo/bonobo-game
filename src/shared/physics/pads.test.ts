import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { PAD, TICK_RATE, WORLD } from "../constants";
import type { MovingPlatform, SoundPad, StageSpec } from "../stages";
import { STAGES } from "../stages";
import { createFighter, moverHere, moverPlace, padFx, stepWorld, type PhysicsContext } from "./index";
import { pressPads } from "./pads";

const DT = 1000 / TICK_RATE;

const lift: MovingPlatform = { width: 200, path: [{ x: 700, y: 500 }, { x: 700, y: 500 }], periodMs: 4000, group: "basso" };
const key: MovingPlatform = { width: 100, path: [{ x: 300, y: 400 }, { x: 300, y: 400 }], periodMs: 4000, on: [[0, 100]], group: "melodia" };
const kick: SoundPad = { x: 100, y: 650, width: 60, sound: "cassa", cooldownMs: 5000, effect: { group: "basso", durationMs: 2000, dy: -100 } };
const chord: SoundPad = { x: 400, y: 650, width: 60, sound: "accordo", cooldownMs: 5000, effect: { group: "melodia", durationMs: 2000, on: true } };

function stage(): StageSpec {
  return {
    id: "prova",
    name: "Prova",
    solids: [{ x: 0, y: 650, width: WORLD.width, height: 50 }],
    platforms: [],
    movers: [lift, key],
    pads: [kick, chord],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: 650 }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
}

function setup(x: number, y: number) {
  const s = stage();
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 1000 };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, s);
  f.x = x;
  f.y = y;
  f.onGround = false;
  return { ctx, f };
}

const pressesOf = (ctx: PhysicsContext) => ctx.events.filter((e) => e.type === "pad");

describe("bottoni sonori (#423)", () => {
  it("chi ci salta sopra lo preme una volta, poi resta scarico per cooldownMs", () => {
    const { ctx, f } = setup(130, 560);
    for (let i = 0; i < 30; i++) stepWorld([f], DT, ctx);
    assert.equal(pressesOf(ctx).length, 1, "suona all'atterraggio");
    assert.deepEqual(pressesOf(ctx)[0], { type: "pad", index: 0, sound: "cassa", id: "p0", x: 130, y: 650 });
    const at = ctx.padsMs![0]!;
    // Risaltarci sopra subito non fa niente
    f.y = 560;
    f.onGround = false;
    for (let i = 0; i < 30; i++) stepWorld([f], DT, ctx);
    assert.equal(pressesOf(ctx).length, 1, "scarico");
    // Passata l'attesa sì
    ctx.timeMs = at + kick.cooldownMs;
    f.y = 560;
    f.onGround = false;
    for (let i = 0; i < 30; i++) stepWorld([f], DT, ctx);
    assert.equal(pressesOf(ctx).length, 2, "di nuovo carico");
  });

  it("restare fermi sopra o camminarci non lo preme", () => {
    const { ctx, f } = setup(30, 650);
    f.onGround = true;
    f.input = { ...f.input, right: true };
    for (let i = 0; i < 40; i++) stepWorld([f], DT, ctx);
    assert.ok(f.x > 160, `ci è passato sopra (x = ${f.x})`);
    assert.equal(pressesOf(ctx).length, 0);
  });

  it("si preme anche con un colpo", () => {
    const { ctx, f } = setup(370, 650);
    f.onGround = true;
    f.facing = 1;
    f.attack = "light";
    f.attackActive = true;
    pressPads([f], ctx, ctx.events.length);
    assert.equal(pressesOf(ctx).length, 1);
    assert.equal(pressesOf(ctx)[0].type === "pad" && pressesOf(ctx)[0].index, 1);
  });

  it("la cassa alza le piattaforme del suo gruppo, entrando e uscendo piano", () => {
    const s = stage();
    const pressed = [1000, null];
    assert.equal(padFx(lift, 900, s.pads, pressed).dy, 0, "prima niente");
    assert.equal(padFx(lift, 1000 + PAD.rampMs / 2, s.pads, pressed).dy, -50, "sta salendo");
    assert.equal(padFx(lift, 2000, s.pads, pressed).dy, -100, "in alto");
    assert.equal(padFx(lift, 3000, s.pads, pressed).dy, 0, "finito");
    assert.equal(padFx(key, 2000, s.pads, pressed).dy, 0, "le altre no");
  });

  it("l'accordo accende i tasti e chi è sull'ascensore sale con la cassa", () => {
    const { ctx, f } = setup(800, 498);
    for (let i = 0; i < 5; i++) stepWorld([f], DT, ctx);
    assert.equal(f.riding, 0, "sull'ascensore");
    assert.ok(!moverHere(key, ctx.timeMs!, ctx), "il tasto è spento fuori dalla nota");
    ctx.padsMs = [ctx.timeMs!, ctx.timeMs!];
    assert.ok(moverHere(key, ctx.timeMs! + 500, ctx), "con l'accordo è acceso");
    for (let i = 0; i < Math.round(1000 / DT); i++) stepWorld([f], DT, ctx);
    assert.equal(moverPlace(lift, ctx.timeMs!, ctx).y, 400);
    assert.ok(f.onGround && Math.abs(f.y - 400) < 1, `salito con l'ascensore (y = ${f.y})`);
  });

  it("Sala Prove ha tre bottoni, ognuno con un gruppo che esiste", () => {
    const { pads = [], movers = [] } = STAGES.musica;
    assert.equal(pads.length, 3);
    for (const p of pads) {
      assert.ok(movers.some((m) => m.group === p.effect.group), `${p.sound}: gruppo ${p.effect.group}`);
      assert.ok(p.cooldownMs > p.effect.durationMs, `${p.sound}: l'attesa è più lunga dell'effetto`);
      const { respawn } = STAGES.musica;
      assert.ok(respawn.x < p.x || respawn.x > p.x + p.width, `${p.sound}: chi ricompare non ci cade sopra`);
    }
  });
});
