// Punti di partenza per squadra (#433): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getStage, type StageSpec } from "../stages";
import { createFighter, spawnFor, type FighterSetup } from "./fighter";

const base = getStage(undefined);

// Arena di prova: squadra 1 a sinistra, squadra 2 a destra, due posti ciascuna
const TEAM_SPAWNS = [
  { x: 200, y: 560, team: 1 },
  { x: 300, y: 560, team: 1 },
  { x: 1600, y: 560, team: 2 },
  { x: 1700, y: 560, team: 2 },
];
const teamStage: StageSpec = { ...base, spawns: TEAM_SPAWNS };
const plainStage: StageSpec = { ...base, spawns: [{ x: 100, y: 560 }, { x: 900, y: 560 }, { x: 500, y: 560 }] };

const setup = (over: Partial<FighterSetup>): FighterSetup => ({
  id: "p",
  name: "P",
  characterId: "default",
  color: 0,
  team: 0,
  index: 0,
  stocks: 3,
  ...over,
});

describe("partenze per squadra (#433)", () => {
  it("la squadra 1 e la squadra 2 partono ognuna sul suo lato", () => {
    const one = createFighter(setup({ team: 1, index: 0, teamRank: 0 }), teamStage);
    const two = createFighter(setup({ team: 2, index: 1, teamRank: 0 }), teamStage);
    assert.ok([200, 300].includes(one.x), `squadra 1 a ${one.x}`);
    assert.ok([1600, 1700].includes(two.x), `squadra 2 a ${two.x}`);
  });

  it("due compagni di squadra non partono sullo stesso posto", () => {
    const a = createFighter(setup({ id: "a", team: 1, index: 0, teamRank: 0 }), teamStage);
    const b = createFighter(setup({ id: "b", team: 1, index: 2, teamRank: 1 }), teamStage);
    assert.notEqual(a.x, b.x);
  });

  it("3 e 4 squadre su un'arena a 2 si alternano: la 3 parte con la 1, la 4 con la 2", () => {
    const three = spawnFor(setup({ team: 3, teamRank: 0 }), teamStage);
    assert.ok(three.x === 200 || three.x === 300, `squadra 3 a ${three.x}`);
    const four = spawnFor(setup({ team: 4, teamRank: 0 }), teamStage);
    assert.ok(four.x === 1600 || four.x === 1700, `squadra 4 a ${four.x}`);
  });

  it("FFA (team 0) resta com'era: partenza per indice", () => {
    for (let index = 0; index < 6; index++) {
      const f = createFighter(setup({ index }), teamStage);
      const want = teamStage.spawns[index % teamStage.spawns.length];
      assert.deepEqual({ x: f.x, y: f.y }, { x: want.x, y: want.y });
    }
  });

  it("un'arena senza partenze di squadra resta com'era anche in squadra", () => {
    for (const team of [0, 1, 2]) {
      for (let index = 0; index < 4; index++) {
        const f = createFighter(setup({ team, index, teamRank: 1 }), plainStage);
        const want = plainStage.spawns[index % plainStage.spawns.length];
        assert.deepEqual({ x: f.x, y: f.y }, { x: want.x, y: want.y }, `team ${team} indice ${index}`);
      }
    }
  });
});
