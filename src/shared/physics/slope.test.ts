// Piattaforme inclinate (#246): le scale che scendono nel canale di Padova, sotto il ponte ad arco.
// Logica pura, si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { TICK_RATE } from "../constants";
import type { StageSpec, ThinPlatform } from "../stages";
import { createFighter, platformSurfaceY, stepWorld, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const bridge: ThinPlatform = { x: 720, y: 520, width: 480, arch: 25 };
const stairs: ThinPlatform = { x: 742, y: 518, width: 180, y2: 690 }; // da 2 px sopra la piazza al fondo del canale

const stage: StageSpec = {
  id: "canale",
  name: "Canale",
  width: 1920,
  solids: [
    { x: 100, y: 520, width: 620, height: 200 }, // piazza sinistra
    { x: 1200, y: 520, width: 620, height: 200 }, // piazza destra
    { x: 720, y: 690, width: 480, height: 30 }, // fondo del canale
  ],
  platforms: [bridge, stairs],
  blastZone: { left: -300, right: 2220, top: -420, bottom: 1000 },
  spawns: [{ x: 300, y: 520 }],
  respawn: { x: 960, y: 160 },
  colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
};

function setup(at: { x: number; y: number }) {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  f.x = at.x;
  f.y = at.y;
  stepWorld([f], DT, ctx);
  return { ctx, f };
}

const run = (f: ReturnType<typeof createFighter>, ctx: PhysicsContext, ms: number, until?: () => boolean) => {
  for (let i = 0; i < Math.round(ms / DT) && !(until && until()); i++) stepWorld([f], DT, ctx);
};

describe("piattaforme inclinate (#246)", () => {
  it("la superficie va dritta da y a sinistra a y2 a destra", () => {
    assert.equal(platformSurfaceY(stairs, 742), 518);
    assert.equal(platformSurfaceY(stairs, 922), 690);
    assert.equal(platformSurfaceY(stairs, 832), 604);
    assert.equal(platformSurfaceY(stairs, 2000), 690, "oltre l'estremità vale l'estremità");
  });

  it("dalla piazza si cammina sul ponte, non si scivola giù per la scala", () => {
    const { ctx, f } = setup({ x: 600, y: 520 });
    f.input = { ...f.input, right: true };
    run(f, ctx, 900, () => f.x > 900);
    assert.ok(f.onGround && Math.abs(f.y - platformSurfaceY(bridge, f.x)) < 1e-9, `sul ponte (x = ${f.x}, y = ${f.y})`);
  });

  it("tenendo giù sul ponte si scende sulla scala", () => {
    const { ctx, f } = setup({ x: 800, y: platformSurfaceY(bridge, 800) });
    assert.ok(f.onGround);
    f.input = { ...f.input, down: true };
    run(f, ctx, 600);
    assert.ok(f.onGround && Math.abs(f.y - platformSurfaceY(stairs, f.x)) < 1e-9, `sulla scala (x = ${f.x}, y = ${f.y})`);
  });

  it("la scala si scende camminando fino al fondo del canale, senza staccarsi", () => {
    const { ctx, f } = setup({ x: 790, y: platformSurfaceY(stairs, 790) });
    f.input = { ...f.input, right: true };
    for (let i = 0; i < 60 && f.x < 915; i++) {
      stepWorld([f], DT, ctx);
      assert.ok(f.onGround && Math.abs(f.y - platformSurfaceY(stairs, f.x)) < 1e-9, `sulla scala a x = ${f.x.toFixed(1)}`);
    }
    run(f, ctx, 300);
    assert.equal(f.y, 690, "in fondo al canale");
  });

  it("dal fondo del canale si risale camminando fino alla piazza", () => {
    const { ctx, f } = setup({ x: 1000, y: 690 });
    f.input = { ...f.input, left: true };
    let lowest = 0;
    run(f, ctx, 2000, () => {
      if (!f.onGround) lowest++;
      return f.x < 650;
    });
    assert.ok(f.x < 650 && f.onGround && f.y === 520, `arrivato sulla piazza (x = ${f.x}, y = ${f.y})`);
    assert.ok(lowest <= 2, `quasi sempre a terra lungo la salita (${lowest} tick in aria)`);
  });
});
