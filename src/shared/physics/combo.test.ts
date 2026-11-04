// Test delle combo su misura dei personaggi (#557): si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { AUDIO, GROOVE, PIANO_QUINQUENNALE, SCIVOLONE } from "../constants";
import { getStage } from "../stages";
import { launch } from "./attacks";
import { wetted } from "./grab";
import { createFighter, type PhysicsContext } from "./index";

const stage = getStage(undefined);
const mk = (id: string, characterId: string) => createFighter({ id, name: id, characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);

describe("Piano quinquennale di Marcomunista", () => {
  it("ogni colpo in aria che prende lo rialza, fino a maxPops prima di toccare terra", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const m = mk("m", "marcomunista");
    m.onGround = false;
    for (let i = 0; i < PIANO_QUINQUENNALE.maxPops; i++) {
      m.vy = 400; // sta cadendo
      launch(mk("t" + i, "default"), m, "lightAir", 0, 0, ctx);
      assert.ok(m.vy <= PIANO_QUINQUENNALE.popVy, `colpo ${i + 1}: risale (${m.vy})`);
    }
    m.vy = 400;
    launch(mk("ultimo", "default"), m, "heavyAir", 0, 0, ctx);
    assert.equal(m.vy, 400, "dopo maxPops cade come sempre");
  });

  it("a terra, con colpi da terra o per chi non ha la regola non cambia niente", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const m = mk("m", "marcomunista");
    m.onGround = true;
    m.vy = 0;
    launch(mk("a", "default"), m, "lightAir", 0, 0, ctx);
    assert.equal(m.vy, 0);
    m.onGround = false;
    m.vy = 400;
    launch(mk("b", "default"), m, "light", 0, 0, ctx);
    assert.equal(m.vy, 400);
    const other = mk("o", "bonobot");
    other.onGround = false;
    other.vy = 400;
    launch(mk("c", "default"), other, "lightAir", 0, 0, ctx);
    assert.equal(other.vy, 400);
  });
});

describe("Groove di Bradipo Giallo", () => {
  const beatMs = 60000 / (stage.music?.bpm ?? AUDIO.musicBpm);
  const hitAt = (characterId: string, timeMs: number) => {
    const ctx: PhysicsContext = { stage, events: [], timeMs };
    const t = mk("t", "default");
    launch(t, mk("b", characterId), "light", 0, 0, ctx);
    return t.percent;
  };

  it("a tempo col battito il colpo fa più danno, fuori tempo no", () => {
    const offBeat = hitAt("bradipo", beatMs * 3 + beatMs / 2);
    const onBeat = hitAt("bradipo", beatMs * 3 + GROOVE.windowMs / 2);
    const justBefore = hitAt("bradipo", beatMs * 4 - GROOVE.windowMs / 2);
    assert.ok(onBeat > offBeat, `a tempo ${onBeat}, fuori ${offBeat}`);
    assert.equal(justBefore, onBeat, "vale anche un attimo prima del battito");
    assert.equal(Math.round((onBeat / offBeat) * 10) / 10, GROOVE.damageMult);
  });

  it("chi non è Bradipo non ha il Groove", () => {
    assert.equal(hitAt("bonobot", beatMs * 3), hitAt("bonobot", beatMs * 3 + beatMs / 2));
  });
});

describe("Scivolone di Egiainuso", () => {
  it("chi è bagnato dal suo Sputo si lancia più lontano, solo da lui e solo coi lanci", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const e = mk("e", "egiainuso");
    const dry = mk("d", "default");
    const wet = mk("w", "default");
    wet.wetBy = "e";
    wet.wetMs = SCIVOLONE.wetMs;
    launch(dry, e, "throwForward", 0, 0, ctx);
    launch(wet, e, "throwForward", 0, 0, ctx);
    assert.ok(Math.abs(wet.vx) > Math.abs(dry.vx) * 1.2, `bagnato ${wet.vx}, asciutto ${dry.vx}`);
    const other = mk("o", "default");
    other.wetBy = "qualcun-altro";
    other.wetMs = SCIVOLONE.wetMs;
    const dry2 = mk("d2", "default");
    launch(other, e, "throwForward", 0, 0, ctx);
    launch(dry2, e, "throwForward", 0, 0, ctx);
    assert.equal(Math.round(other.vx), Math.round(dry2.vx), "bagnato da un altro non vale");
  });

  it("la presa arriva più lontano su chi è bagnato", () => {
    const e = mk("e", "egiainuso");
    const t = mk("t", "default");
    assert.equal(wetted(e, t), false);
    t.wetBy = "e";
    t.wetMs = 10;
    assert.equal(wetted(e, t), true);
  });
});

describe("Capra e cavaliere di Elvedeo", () => {
  it("l'Incornata che prende fa partire il Piccione verso chi vola via, uno alla volta", () => {
    const ctx: PhysicsContext = { stage, events: [] };
    const e = mk("e", "elvedeo");
    const t = mk("t", "default");
    t.x = e.x + 60;
    launch(t, e, "specialSide", 0, 0, ctx);
    const birds = ctx.projectiles?.list.filter((p) => p.ownerId === "e") ?? [];
    assert.equal(birds.length, 1);
    assert.ok(birds[0].vx > 0, "vola verso il bersaglio");
    launch(t, e, "specialSide", 0, 0, ctx);
    assert.equal(ctx.projectiles?.list.length, 1, "non oltre maxAlive");
    launch(mk("u", "default"), e, "light", 0, 0, ctx);
    assert.equal(ctx.projectiles?.list.length, 1, "solo l'Incornata");
  });
});
