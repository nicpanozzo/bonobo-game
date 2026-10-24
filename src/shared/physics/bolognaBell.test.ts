// Bologna (#433): la campana appesa al cavo tra le torri, un'altalena su cui si sta in piedi. Logica pura, `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { BOLOGNA, TICK_RATE } from "../constants";
import { STAGES } from "../stages";
import { createFighter, moverOn, moverPosition, stepWorld, swingAngle, type PhysicsContext } from "./index";

const bologna = STAGES.bologna;
const DT = 1000 / TICK_RATE;
const bell = bologna.movers!.find((m) => m.kind === "campana")!;
const swing = bell.swing!;
const at = (k: number) => swing.swingMs * (Math.ceil(BOLOGNA.towersMs / swing.swingMs) + k); // al giro k dopo l'inizio delle torri

describe("Bologna: la campana che dondola tra le torri", () => {
  it("c'è dalle torri al crollo", () => {
    assert.ok(bell);
    assert.equal(moverOn(bell, BOLOGNA.towersMs - 1000), false);
    assert.equal(moverOn(bell, BOLOGNA.towersMs + 1000), true);
    assert.equal(moverOn(bell, BOLOGNA.collapseMs + 1000), false);
  });

  it("dondola da una torre all'altra e agli estremi sfiora la postazione (A) di ognuna", () => {
    const garisendaA = bologna.platforms[8];
    const asinelliA = bologna.platforms[16];
    const left = moverPosition(bell, at(10.75)); // tre quarti di giro: l'estremo a sinistra
    const right = moverPosition(bell, at(10.25));
    assert.ok(Math.abs(swingAngle(swing, at(10.25)) - (BOLOGNA.bellAmplitudeDeg * Math.PI) / 180) < 1e-6, "all'estremo destro");
    assert.ok(left.x < garisendaA.x + garisendaA.width + 80, "a sinistra arriva vicino alla Garisenda");
    assert.ok(garisendaA.y - left.y > 0 && garisendaA.y - left.y < 140, "poco sopra la sua postazione: ci si salta");
    assert.ok(right.x + bell.width > asinelliA.x, "a destra arriva sopra l'Asinelli");
    assert.ok(Math.abs(right.y - asinelliA.y) < 40, "alla sua altezza");
    const bottom = moverPosition(bell, at(10));
    assert.equal(Math.round(bottom.y), swing.pivot.y + swing.length, "in mezzo è giù del tutto");
    // il riquadro di path (predizione) contiene tutto il percorso
    const xs = bell.path.map((p) => p.x);
    const ys = bell.path.map((p) => p.y);
    for (let k = 0; k < 1; k += 0.05) {
      const p = moverPosition(bell, at(10 + k));
      assert.ok(p.x >= Math.min(...xs) - 1 && p.x <= Math.max(...xs) + 1 && p.y >= Math.min(...ys) - 1 && p.y <= Math.max(...ys) + 1, "dentro il riquadro");
    }
  });

  it("porta chi ci sta sopra", () => {
    const ctx: PhysicsContext = { stage: bologna, events: [], timeMs: at(10.75) };
    const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 1, index: 0, stocks: 3 }, bologna);
    const p = moverPosition(bell, ctx.timeMs!);
    f.x = p.x + bell.width / 2;
    f.y = p.y - 2;
    f.vy = 0;
    f.onGround = false;
    for (let i = 0; i < 6; i++) stepWorld([f], DT, ctx);
    const startX = f.x;
    while (ctx.timeMs! < at(11.2)) stepWorld([f], DT, ctx);
    const now = moverPosition(bell, ctx.timeMs!);
    assert.ok(f.x - startX > 200, `portato verso l'Asinelli (da ${Math.round(startX)} a ${Math.round(f.x)})`);
    assert.ok(Math.abs(f.y - now.y) < 3, "ancora sul ceppo");
  });
});
