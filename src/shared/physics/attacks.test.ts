// attackSpecFor (E10 passo 1): i numeri degli attacchi letti per personaggio. Si lancia con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CHARACTERS, hurtboxOf } from "../characters";
import { ATTACKS, FIGHTER } from "../constants";
import { getStage } from "../stages";
import { attackSpecFor, bodyBox } from "./attacks";
import { createFighter } from "./index";

const fighter = (characterId: string) =>
  createFighter({ id: "p0", name: "P0", characterId, color: 0, team: 0, index: 0, stocks: 3 }, getStage(undefined));

describe("attackSpecFor", () => {
  it("senza ritocchi è ATTACKS, anche senza attacco in corso", () => {
    const f = fighter("orsoblu");
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

describe("corpo che si può colpire (#243)", () => {
  it("segue la sagoma del personaggio, o resta FIGHTER", () => {
    const slim = fighter("lampione");
    const box = bodyBox(slim);
    assert.equal(box.w, CHARACTERS.lampione.hurtbox!.width);
    assert.equal(box.y + box.h, slim.y); // poggia sui piedi
    assert.ok(box.w < FIGHTER.width);
    assert.deepEqual(hurtboxOf("orsoblu"), FIGHTER);
  });

  it("resta di misure da lottatore", () => {
    for (const c of Object.values(CHARACTERS)) {
      if (!c.hurtbox) continue;
      assert.ok(c.hurtbox.width >= 24 && c.hurtbox.width <= 64, `${c.id}: larghezza ${c.hurtbox.width}`);
      assert.ok(c.hurtbox.height >= 70 && c.hurtbox.height <= 130, `${c.id}: altezza ${c.hurtbox.height}`);
    }
  });
});
