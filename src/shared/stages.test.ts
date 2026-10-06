import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, TICK_RATE, WORLD } from "./constants";
import { createFighter, stepWorld, type PhysicsContext } from "./physics";
import { generateStage, seedFromStageId } from "./stageGenerator";
import { getStage, STAGES, type StageSpec } from "./stages";

// Un salto sale di v²/2g pixel; con il doppio salto si arriva alla somma dei due
const JUMP_HEIGHT = (FIGHTER.jumpSpeed * FIGHTER.jumpSpeed) / (2 * FIGHTER.gravity);
const DOUBLE_JUMP_HEIGHT = JUMP_HEIGHT + (FIGHTER.doubleJumpSpeed * FIGHTER.doubleJumpSpeed) / (2 * FIGHTER.gravity);
const SIDE_REACH = 250; // pixel in orizzontale che si coprono comodamente durante un salto

// Una piattaforma si raggiunge da una superficie più bassa vicina con un salto,
// o da una superficie proprio sotto con il doppio salto
function reachable(stage: StageSpec, p: { x: number; y: number; width: number }): boolean {
  return [...stage.solids, ...stage.platforms].some((s) => {
    if (s.y <= p.y) return false;
    const gap = Math.max(0, s.x - (p.x + p.width), p.x - (s.x + s.width));
    const rise = s.y - p.y;
    return (gap <= SIDE_REACH && rise <= JUMP_HEIGHT) || (gap === 0 && rise <= DOUBLE_JUMP_HEIGHT * 0.9);
  });
}

function checkStage(stage: StageSpec) {
  for (const p of [...stage.solids, ...stage.platforms]) {
    assert.ok(p.x >= 0 && p.x + p.width <= WORLD.width, `${stage.id}: dentro lo schermo`);
    assert.ok(p.y > 0 && p.y < WORLD.height, `${stage.id}: altezza valida`);
  }
  for (const p of stage.platforms) {
    assert.ok(reachable(stage, p), `${stage.id}: piattaforma a ${p.x},${p.y} irraggiungibile`);
  }
  assert.ok(stage.spawns.length >= 4, `${stage.id}: quattro partenze`);

  // Chi parte da ogni punto di partenza resta fermo sul palco
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = stage.spawns.map((_, i) =>
    createFighter({ id: `p${i}`, name: "", characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  for (let t = 0; t < 30; t++) stepWorld(fighters, 1000 / TICK_RATE, ctx);
  for (const f of fighters) assert.ok(f.onGround && !f.respawning, `${stage.id}: partenza ${f.id} sul palco`);
}

describe("arene", () => {
  it("le arene fatte a mano sono valide", () => {
    for (const stage of Object.values(STAGES)) checkStage(stage);
  });

  it("un'arena generata è sempre la stessa per lo stesso seme", () => {
    assert.deepEqual(generateStage(1234), generateStage(1234));
    assert.notDeepEqual(generateStage(1), generateStage(2));
  });

  it("le arene generate sono giocabili", () => {
    for (let seed = 0; seed < 300; seed++) checkStage(generateStage(seed));
  });

  it("getStage riconosce gli id", () => {
    assert.equal(getStage(undefined).id, "palco");
    assert.equal(getStage("non-esiste").id, "palco");
    assert.equal(getStage("isole").id, "isole");
    assert.equal(getStage("casuale-42").id, "casuale-42");
    assert.equal(seedFromStageId("casuale-abc"), null);
  });
});
