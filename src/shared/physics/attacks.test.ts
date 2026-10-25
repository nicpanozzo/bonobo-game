// attackSpecFor (E10 passo 1): i numeri degli attacchi letti per personaggio. Si lancia con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CHARACTERS, hurtboxOf } from "../characters";
import { ATTACKS, FIGHTER } from "../constants";
import { getStage } from "../stages";
import { attackBox, attackSpecFor, bodyBox, resolveHits } from "./attacks";
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

describe("pesante in giù dai due lati, come lo smash in giù di Smash", () => {
  it("colpisce anche chi sta dietro e lo lancia all'indietro", () => {
    for (const characterId of ["default", "orsoblu", "nonnagina"]) {
      const a = fighter(characterId);
      const b = createFighter({ id: "p1", name: "P1", characterId: "default", color: 0, team: 1, index: 1, stocks: 3 }, getStage(undefined));
      Object.assign(a, { x: 600, facing: 1, attack: "heavyDown", attackActive: true });
      Object.assign(b, { x: 600 - 50, y: a.y, onGround: true });
      const box = attackBox(a);
      assert.ok(Math.abs(box.x + box.w / 2 - a.x) < 1e-9, `${characterId}: centrata sul personaggio`);
      resolveHits([a, b], { stage: getStage(undefined), events: [] });
      assert.ok(b.percent > 0, `${characterId}: colpito dietro`);
      assert.ok(b.vx < 0, `${characterId}: vola dalla parte opposta a dove guarda chi colpisce`);
    }
  });
});
