// Test delle combo per personaggio (#594): il formato, la fisica che lo applica e il laboratorio (scripts/combo-lab.ts).
// Si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { chain, chainCells, CORE, drawn, movesOf } from "../../../scripts/combo-lab";
import { CHARACTERS, getCharacter, type TweakableAttack } from "../characters";
import { ATTACKS, COMBO, TICK_RATE } from "../constants";
import { getStage } from "../stages";
import { launch } from "./attacks";
import { createFighter, emptyInput, stepWorld, type PhysicsContext } from "./index";

const stage = getStage("palestra");
const mk = (id: string, characterId: string) => createFighter({ id, name: id, characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);

describe("formato delle combo", () => {
  for (const ch of Object.values(CHARACTERS)) {
    if (!ch.combos) continue;
    it(`${ch.id}: passi, finestre e ritocchi dentro COMBO, solo mosse disegnate`, () => {
      assert.ok(ch.combos!.length <= 31, "al massimo 31 combo: stanno in una maschera di bit");
      const lab = movesOf(ch.id);
      for (const c of ch.combos!) {
        assert.ok(c.steps.length >= 2 && c.steps.length <= COMBO.maxSteps, `${c.name}: da 2 a ${COMBO.maxSteps} passi`);
        for (const s of c.steps) {
          const move = lab.find((m) => m.id === s.move);
          assert.ok(move && drawn(ch.id, move), `${c.name}: ${s.move} non ha un disegno suo`);
          assert.ok((s.windowMs ?? COMBO.windowMs) <= COMBO.maxWindowMs, `${c.name}: finestra di ${s.move} troppo lunga`);
          assert.ok((s.holdMs ?? 0) <= COMBO.maxHoldMs, `${c.name}: stordimento di ${s.move} troppo lungo`);
          const kb = s.knockbackMult ?? 1;
          assert.ok(kb >= COMBO.knockbackMult[0] && kb <= COMBO.knockbackMult[1], `${c.name}: knockbackMult di ${s.move} fuori dai limiti`);
          if (s.angleDeg === undefined) continue;
          assert.ok(s.move in ATTACKS, `${c.name}: l'angolo si ritocca solo sui colpi di ATTACKS`);
          const base = ch.attacks?.[s.move as TweakableAttack]?.angleDeg ?? ATTACKS[s.move as keyof typeof ATTACKS].angleDeg;
          assert.ok(Math.abs(s.angleDeg - base) <= COMBO.maxAngleShiftDeg, `${c.name}: angolo di ${s.move} troppo lontano da ${base}`);
        }
      }
    });
  }
});

describe("fisica delle combo", () => {
  it("il colpo di un passo apre la finestra: la mossa dopo parte senza aspettare l'attesa", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const run = (characterId: string) => {
      const b = mk("b", characterId);
      const t = mk("t", "default");
      t.x = b.x + 600; // lontano: conta solo se la mossa parte
      launch(t, b, "lightUp", 0, 0, ctx);
      b.cooldownTimer = 200;
      b.input = { ...emptyInput(), light: true, up: true };
      stepWorld([b, t], 1000 / TICK_RATE, ctx);
      return b;
    };
    const bradipo = run("bradipo"); // Giro di basso: lightUp, lightUp
    assert.equal(bradipo.attack, "lightUp");
    assert.equal(run("default").attack, null, "chi non ha la combo aspetta l'attesa");
  });

  it("fuori dalla finestra, o con un'altra mossa, vale l'attesa di sempre", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const b = mk("b", "bradipo");
    launch(mk("t", "default"), b, "lightUp", 0, 0, ctx);
    assert.ok(b.comboTimer > 0);
    b.cooldownTimer = 200;
    b.input = { ...emptyInput(), heavy: true };
    stepWorld([b], 1000 / TICK_RATE, ctx);
    assert.equal(b.attack, null, "il pesante non è il passo dopo");
    b.comboTimer = 0;
    b.prevInput = emptyInput();
    b.input = { ...emptyInput(), light: true, up: true };
    stepWorld([b], 1000 / TICK_RATE, ctx);
    assert.equal(b.attack, null, "finestra chiusa");
  });

  it("i ritocchi del passo cambiano angolo e knockback, e l'ultimo passo chiude la combo", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const step = getCharacter("elvedeo").combos!.find((c) => c.name === "Zoccolata")!.steps[0];
    assert.ok(step.angleDeg !== undefined && step.knockbackMult !== undefined);
    const e = mk("e", "elvedeo");
    const t = mk("t", "default");
    const plain = mk("p", "default");
    launch(plain, mk("d", "default"), "heavyAir", 0, 0, ctx);
    launch(t, e, "heavyAir", 0, 0, ctx);
    const speed = (f: typeof t) => Math.hypot(f.vx, f.vy);
    assert.ok(Math.abs(speed(t) / speed(plain) - step.knockbackMult!) < 0.01, "knockback moltiplicato");
    assert.ok(Math.abs((Math.atan2(-t.vy, Math.abs(t.vx)) * 180) / Math.PI - step.angleDeg!) < 0.01, "angolo del passo");
    assert.equal(e.comboStep, 1);
    launch(t, e, "light", 0, 0, ctx);
    assert.equal(e.comboTimer, 0, "dopo l'ultimo passo non c'è una mossa dopo");
  });
});

describe("laboratorio delle combo", () => {
  for (const id of CORE) {
    it(`${id}: almeno 2 combo vere, fatte solo di mosse disegnate`, () => {
      const real = (getCharacter(id).combos ?? []).filter((c) => chainCells(id, c.steps.map((s) => s.move)).includes("V"));
      assert.ok(real.length >= 2, `combo vere: ${real.map((c) => c.name).join(", ") || "nessuna"}`);
    });
  }

  it("ritrova le combo note: jab, Piano quinquennale, Arrembaggio", () => {
    assert.equal(chain("bradipo", ["light", "light", "light"], 40).hits, 3, "combo di leggeri");
    const piano = chain("marcomunista", ["throwDown", "lightAir", "lightAir", "heavyAir"], 80);
    assert.equal(piano.hits, 4, "Piano quinquennale: tre colpi in aria di fila dopo il lancio");
    assert.equal(chain("orsoblu", ["specialNeutral", "heavy"], 40).hits, 2, "Arrembaggio");
  });

  it("è deterministico: la stessa catena dà lo stesso risultato", () => {
    const a = chain("egiainuso", ["light", "dashAttack"], 90);
    const b = chain("egiainuso", ["light", "dashAttack"], 90);
    assert.deepEqual([a.hits, a.real, a.world?.t.x, a.world?.t.percent], [b.hits, b.real, b.world?.t.x, b.world?.t.percent]);
    assert.ok(a.real);
  });
});

// Jab, Arrembaggio e Piano quinquennale (#557) resi veri, e lo stordimento minimo dei passi (holdMs)
describe("combo vere", () => {
  it("il jab è vero a percentuali basse", () => {
    assert.equal(chainCells("bonobot", ["light", "light", "light"])[0], "V");
  });
  it("l'Arrembaggio col jab è vero", () => {
    assert.equal(chainCells("orsoblu", ["specialNeutral", "light"])[0], "V");
  });
  it("due colpi in aria del Piano quinquennale sono veri", () => {
    assert.ok(chainCells("marcomunista", ["lightAir", "lightAir"]).includes("V"));
  });
  it("ogni personaggio con le combo ne ha almeno due vere", () => {
    for (const ch of Object.values(CHARACTERS)) {
      if (!ch.combos) continue;
      const real = ch.combos.filter((c) => chainCells(ch.id, c.steps.map((s) => s.move)).includes("V"));
      assert.ok(real.length >= 2, `${ch.id}: ${real.length} combo vere`);
    }
  });
});
