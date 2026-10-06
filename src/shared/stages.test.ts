import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FIGHTER, MAX_PLAYERS_PER_ROOM, TICK_RATE, WORLD } from "./constants";
import { createFighter, stepWorld, type PhysicsContext } from "./physics";
import { courseSteps, generateCourse } from "./courseGenerator";
import { generateStage, seedFromStageId } from "./stageGenerator";
import { getStage, STAGES, stageWidth, type StageSpec } from "./stages";

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
    assert.ok(p.x >= 0 && p.x + p.width <= stageWidth(stage), `${stage.id}: dentro il mondo`);
    assert.ok(p.y > 0 && p.y < WORLD.height, `${stage.id}: altezza valida`);
  }
  if (!stage.goal) {
    for (const p of stage.platforms) assert.ok(reachable(stage, p), `${stage.id}: piattaforma a ${p.x},${p.y} irraggiungibile`);
  }
  assert.ok(stage.spawns.length >= MAX_PLAYERS_PER_ROOM, `${stage.id}: una partenza per giocatore`);

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

  it("i percorsi della Corsa si fanno tutti saltando da un appoggio al successivo", () => {
    for (let seed = 0; seed < 300; seed++) {
      const stage = generateCourse(seed);
      checkStage(stage);
      const steps = courseSteps(stage);
      for (let i = 1; i < steps.length; i++) {
        const [a, b] = [steps[i - 1], steps[i]];
        const gap = b.x - (a.x + a.width);
        assert.ok(gap > 0 && gap <= SIDE_REACH, `${stage.id}: salto ${i} lungo ${gap}`);
        assert.ok(a.y - b.y <= JUMP_HEIGHT * 0.8, `${stage.id}: salto ${i} alto ${a.y - b.y}`);
      }
      const goal = stage.goal!;
      const end = steps[steps.length - 1];
      assert.ok(end.solid && goal.x >= end.x && goal.x + goal.width <= end.x + end.width, `${stage.id}: traguardo sull'ultimo blocco`);
      assert.ok(stageWidth(stage) > WORLD.width * 4, `${stage.id}: lungo qualche schermo`);
      assert.ok(stage.checkpoints!.length >= 3, `${stage.id}: checkpoint`);
      assert.deepEqual(stage.checkpoints!.map((c) => c.x), [...stage.checkpoints!.map((c) => c.x)].sort((x, y) => x - y));
    }
    assert.deepEqual(generateCourse(7), generateCourse(7));
    assert.equal(getStage("corsa-7").id, "corsa-7");
  });

  // Un "giocatore" che va verso l'appoggio successivo e salta al bordo arriva in fondo:
  // la prova vera che i salti misurati sopra si fanno con la fisica del gioco
  it("un giocatore che corre e salta ai bordi arriva al traguardo", () => {
    for (let seed = 0; seed < 200; seed++) {
      const stage = generateCourse(seed);
      const steps = courseSteps(stage);
      const ctx: PhysicsContext = { stage, events: [], unlimitedStocks: true };
      const f = createFighter({ id: "a", name: "", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
      let on = 0; // appoggio su cui si trova (o da cui è saltato)
      let falls = 0;
      for (let t = 0; t < TICK_RATE * 90 && f.x < stage.goal!.x; t++) {
        if (f.onGround) on = Math.max(0, steps.findIndex((s) => f.x + 30 > s.x && f.x - 30 < s.x + s.width && s.y === f.y));
        const here = steps[on];
        const next = steps[on + 1] ?? here;
        let right = true;
        let left = false;
        let up = false;
        if (f.onGround) {
          up = here.x + here.width - f.x < 24 || (next.y < f.y && next.x - f.x < 50);
        } else {
          // In aria si punta il centro dell'appoggio dopo, con il doppio salto se si scende troppo presto
          const aim = next.x + Math.min(next.width / 2, 60);
          right = f.x < aim;
          left = f.x > aim + 40;
          up = f.vy > 0 && f.jumpsLeft > 0 && f.y > next.y - 20 && f.x < next.x;
        }
        f.input = { ...f.input, right, left, up: up && !f.prevInput.up };
        stepWorld([f], 1000 / TICK_RATE, ctx);
        if (ctx.events.some((e) => e.type === "ko")) falls++;
        ctx.events = [];
      }
      assert.ok(f.x >= stage.goal!.x, `corsa-${seed}: arrivato a ${Math.round(f.x)} di ${stage.goal!.x}, cadute ${falls}`);
    }
  });
});
