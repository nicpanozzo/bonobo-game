import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BASSANESE, TICK_RATE, WORLD } from "../constants";
import { DROPPABLE_ITEMS, ITEMS } from "../items";
import { getStage, type StageSpec } from "../stages";
import { bassaneseState, callBassanese } from "./bassanese";
import { createFighter, stepWorld, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const FLOOR = 600;

function stage(width = WORLD.width): StageSpec {
  return {
    id: "prova",
    name: "Prova",
    solids: [{ x: 0, y: FLOOR, width, height: 100 }],
    platforms: [{ x: 300, y: 420, width: 200 }, { x: width - 500, y: 420, width: 200 }],
    blastZone: { left: -500, right: width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 200, y: FLOOR }, { x: 800, y: FLOOR }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
    ...(width !== WORLD.width && { width }),
  };
}

function setup(s = stage()) {
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 0 };
  const fighter = (i: number, team: number) => createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team, index: i, stocks: 3 }, s);
  const caller = fighter(0, 1);
  const mate = fighter(1, 1);
  const enemy = fighter(2, 2);
  ctx.canHit = (a, b) => a.team === 0 || a.team !== b.team;
  for (const f of [caller, mate, enemy]) f.invulnerableTimer = 0;
  return { ctx, caller, mate, enemy, list: [caller, mate, enemy] };
}

// Lascia girare il Bassanese finché se ne va (o fino a ms), segnando dove passa
function run(ctx: PhysicsContext, list: ReturnType<typeof setup>["list"], ms = BASSANESE.maxMs * 2) {
  const xs: number[] = [];
  for (let t = 0; t < ms && ctx.bassanese?.list.length !== 0; t += DT) {
    stepWorld(list, DT, ctx);
    const b = bassaneseState(ctx)?.[0];
    if (b) xs.push(b.x);
  }
  return xs;
}

describe("Chiama Bassanese", () => {
  it("il telefono cade dal cielo come gli altri oggetti", () => {
    assert.equal(ITEMS.bassanese.call, true);
    assert.ok(DROPPABLE_ITEMS.includes("bassanese"));
  });

  it("entra dal lato lontano da chi chiama, attraversa tutta l'arena e se ne va", () => {
    const { ctx, caller, list } = setup();
    caller.x = 100; // a sinistra: il Bassanese arriva da destra
    callBassanese(caller, ctx);
    assert.ok(ctx.events.some((e) => e.type === "bassanese" && e.phase === "call"));
    const start = bassaneseState(ctx)![0];
    assert.ok(start.x > WORLD.width, `entra da destra (x ${start.x})`);
    const xs = run(ctx, list);
    assert.equal(ctx.bassanese!.list.length, 0, "alla fine se ne va");
    assert.ok(Math.min(...xs) < 200 && Math.max(...xs) > WORLD.width - 100, "percorre tutta l'arena");
    assert.ok(ctx.events.some((e) => e.type === "bassanese" && e.phase === "leave"));
  });

  it("colpisce gli avversari di chi l'ha chiamato, non lui né i compagni", () => {
    const { ctx, caller, mate, enemy, list } = setup();
    for (const f of list) {
      f.x = 640;
      f.y = FLOOR;
    }
    caller.x = 100;
    callBassanese(caller, ctx);
    run(ctx, list);
    const hits = ctx.events.filter((e) => e.type === "hit" && e.kind === "item" && e.itemKind === "bassanese");
    assert.ok(hits.length > 0, "qualcuno viene colpito");
    assert.ok(hits.every((e) => e.type === "hit" && e.targetId === enemy.id));
    assert.equal(caller.percent, 0);
    assert.equal(mate.percent, 0);
    assert.ok(enemy.percent >= BASSANESE.damage);
  });

  it("nelle arene larghe come Padova arriva fino in fondo, entro il tempo massimo", () => {
    const wide = stage(1920);
    const { ctx, caller, list } = setup(wide);
    caller.x = 1800;
    callBassanese(caller, ctx);
    const total = ctx.bassanese!.list[0].legs.reduce((sum, l) => sum + l.ms, 0);
    assert.ok(total <= BASSANESE.maxMs + 1, `giro di ${Math.round(total)} ms`);
    const xs = run(ctx, list);
    assert.ok(Math.max(...xs) > 1700, "arriva in fondo a destra");
  });

  it("funziona su tutte le arene fisse senza restare fuori dal mondo", () => {
    for (const id of ["palco", "isole", "fabbrica", "padova"]) {
      const s = getStage(id);
      if (!s) continue;
      const { ctx, caller, list } = setup(s);
      callBassanese(caller, ctx);
      const ys = run(ctx, list).length;
      assert.ok(ys > 0, `${id}: il Bassanese si muove`);
      assert.equal(ctx.bassanese!.list.length, 0, `${id}: se ne va`);
    }
  });
});
