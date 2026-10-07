// attackSpecFor (E10 passo 1): i numeri degli attacchi letti per personaggio. Si lancia con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CHARACTERS } from "../characters";
import { ATTACKS } from "../constants";
import { getStage } from "../stages";
import { attackSpecFor } from "./attacks";
import { createFighter } from "./index";

const fighter = (characterId: string) =>
  createFighter({ id: "p0", name: "P0", characterId, color: 0, team: 0, index: 0, stocks: 3 }, getStage(undefined));

describe("attackSpecFor", () => {
  it("senza ritocchi è ATTACKS, anche senza attacco in corso", () => {
    const f = fighter("bonobot");
    assert.equal(attackSpecFor(f, "heavyUp"), ATTACKS.heavyUp);
    assert.equal(attackSpecFor(f), ATTACKS.light);
  });

  it("il recupero proprio del personaggio cambia solo il recupero", () => {
    const c = CHARACTERS.default;
    c.recovery = { damage: 9, range: 50 };
    try {
      const f = fighter("default");
      assert.deepEqual(attackSpecFor(f, "recovery"), { ...ATTACKS.recovery, damage: 9, range: 50 });
      assert.equal(attackSpecFor(f, "light"), ATTACKS.light);
      assert.equal(attackSpecFor(fighter("bonobot"), "recovery"), ATTACKS.recovery);
    } finally {
      delete c.recovery;
    }
  });
});
