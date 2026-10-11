// Piattaforme ad arco (#244): logica pura, si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { TICK_RATE, WORLD } from "../constants";
import type { StageSpec, ThinPlatform } from "../stages";
import { createFighter, platformSurfaceY, stepWorld, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;
const bridge: ThinPlatform = { x: 300, y: 500, width: 400, arch: 30 }; // il centro è a x 500, y 470

function setup(at: { x: number; y: number }) {
  const stage: StageSpec = {
    id: "ponte",
    name: "Ponte",
    solids: [{ x: 0, y: 620, width: WORLD.width, height: 80 }], // abbastanza vicino da arrivare in cima al ponte con un salto
    platforms: [bridge],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 100, y: 620 }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  f.x = at.x;
  f.y = at.y;
  return { ctx, f };
}

const step = (f: ReturnType<typeof createFighter>, ctx: PhysicsContext) => stepWorld([f], DT, ctx);

describe("piattaforme ad arco (#244)", () => {
  it("la superficie è alta y alle estremità e sale di arch al centro", () => {
    assert.equal(platformSurfaceY(bridge, 300), 500);
    assert.equal(platformSurfaceY(bridge, 700), 500);
    assert.equal(platformSurfaceY(bridge, 500), 470);
    assert.equal(platformSurfaceY(bridge, 400), 477.5); // a metà strada: 30 · (1 − 0,5²)
    assert.equal(platformSurfaceY(bridge, 100), 500, "fuori dal ponte vale l'estremità");
    assert.equal(platformSurfaceY({ x: 0, y: 300, width: 100 }, 50), 300, "le piattaforme dritte restano dritte");
  });

  it("camminando si segue la curva, in salita e in discesa, senza staccarsi", () => {
    const { ctx, f } = setup({ x: 320, y: 500 });
    step(f, ctx);
    f.input = { ...f.input, right: true };
    let top = Infinity;
    for (let i = 0; i < Math.round(1000 / DT) && f.x < 680; i++) {
      step(f, ctx);
      assert.ok(f.onGround, `resta a terra (x = ${f.x.toFixed(1)}, y = ${f.y.toFixed(1)})`);
      assert.ok(Math.abs(f.y - platformSurfaceY(bridge, f.x)) < 1e-9, `sulla curva a x = ${f.x.toFixed(1)}`);
      top = Math.min(top, f.y);
    }
    assert.ok(f.x >= 680, `ha attraversato il ponte (x = ${f.x})`);
    assert.ok(top < 471, `è passato dal punto più alto (y = ${top})`);
  });

  it("con giù si scende dal ponte", () => {
    const { ctx, f } = setup({ x: 500, y: 470 });
    step(f, ctx);
    assert.ok(f.onGround);
    f.input = { ...f.input, down: true };
    for (let i = 0; i < 40; i++) step(f, ctx);
    assert.equal(f.y, 620, "è caduto fino al pavimento");
  });

  it("da sotto si attraversa e si atterra sulla curva", () => {
    const { ctx, f } = setup({ x: 500, y: 620 });
    step(f, ctx);
    f.input = { ...f.input, jump: true };
    for (let i = 0; i < 90; i++) {
      step(f, ctx);
      if (i === 30) f.input = { ...f.input, jump: false }; // tenuto fino in cima: salto pieno, non corto
      if (f.onGround && f.y < 600) break; // di nuovo a terra, ma sul ponte
    }
    assert.ok(f.onGround && Math.abs(f.y - 470) < 1e-9, `atterrato in cima al ponte (y = ${f.y})`);
  });
});
