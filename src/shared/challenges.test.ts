import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CHALLENGES, ChallengeRun, medalFor, type Challenge } from "./challenges";
import { getStage } from "./stages";
import type { GameEvent } from "./types";

const challenge = (id: string) => CHALLENGES.find((c) => c.id === id)!;
const hit = (attackerId: string, targetId: string, damage = 5): GameEvent => ({ type: "hit", attackerId, targetId, kind: "light", damage, percent: 0, knockback: 300, x: 0, y: 0 });
const ko = (id: string, byId: string | null): GameEvent => ({ type: "ko", id, byId, x: 0, y: 0, stocksLeft: 3 });

describe("sfide", () => {
  it("almeno 6 sfide, id unici, arene esistenti, soglie in ordine", () => {
    assert.ok(CHALLENGES.length >= 6);
    assert.equal(new Set(CHALLENGES.map((c) => c.id)).size, CHALLENGES.length);
    for (const c of CHALLENGES) {
      assert.equal(getStage(c.stage).id, c.stage, c.id);
      const [b, s, g] = c.medals;
      if (c.goal === "koTime") assert.ok(b > s && s > g && b <= c.limitSec, c.id);
      else assert.ok(b < s && s < g, c.id);
    }
  });

  it("medaglia: per il tempo del KO meno è meglio, per il resto più è meglio", () => {
    const ko: Challenge = { ...challenge("primo-ko"), medals: [12, 7, 5] };
    assert.deepEqual([null, 20, 12, 7.5, 7, 3].map((s) => medalFor(ko, s)), [0, 0, 1, 1, 2, 3]);
    const dmg: Challenge = { ...challenge("mitraglia"), medals: [60, 85, 100] };
    assert.deepEqual([0, 60, 99, 140].map((s) => medalFor(dmg, s)), [0, 1, 2, 3]);
  });

  it("tempo del KO: conta solo il proprio KO sul bot, letto da stageMs", () => {
    const run = new ChallengeRun(challenge("primo-ko"), "me");
    run.onTick(10_000, () => false);
    run.onEvent(ko("me", null), 13_000); // cadere da soli non chiude la sfida
    run.onEvent(ko("bot", null), 14_000); // il bot che cade da solo nemmeno
    assert.equal(run.done, false);
    run.onEvent(ko("bot", "me"), 16_040);
    assert.equal(run.done, true);
    assert.equal(run.score, 6);
    assert.equal(run.medal, 2);
  });

  it("tempo del KO: senza KO entro il limite niente medaglia", () => {
    const run = new ChallengeRun(challenge("colpo-di-grazia"), "me");
    run.onTick(0, () => false);
    run.onTick(20_000, () => false);
    assert.equal(run.done, true);
    assert.equal(run.score, null);
    assert.equal(run.medal, 0);
  });

  it("resistere: finisce al primo KO subito o al limite", () => {
    const run = new ChallengeRun(challenge("resisti"), "me");
    run.onTick(0, () => false);
    run.onEvent(ko("bot", "me"), 5_000); // buttare fuori il bot non conta
    run.onEvent(ko("me", "bot"), 25_000);
    assert.deepEqual([run.done, run.score, run.medal], [true, 25, 1]);
    const full = new ChallengeRun(challenge("resisti"), "me");
    full.onTick(0, () => false);
    full.onTick(60_000, () => false);
    assert.deepEqual([full.score, full.medal], [60, 3]);
  });

  it("danno: somma i propri colpi fino al limite", () => {
    const run = new ChallengeRun(challenge("mitraglia"), "me");
    run.onTick(0, () => false);
    for (let i = 0; i < 9; i++) run.onEvent(hit("me", "bot", 10), i * 1000);
    run.onEvent(hit("bot", "me", 50), 9_500);
    run.onTick(15_000, () => false);
    assert.deepEqual([run.done, run.score, run.medal], [true, 90, 2]);
  });

  it("palleggio: si azzera quando il bersaglio torna a terra, all'oro finisce subito", () => {
    const run = new ChallengeRun(challenge("palleggio"), "me");
    run.onTick(0, () => true);
    for (let i = 0; i < 4; i++) run.onEvent(hit("me", "bot"), i * 300);
    run.onTick(1_500, () => false); // a terra: il palleggio riparte
    assert.equal(run.score, 4);
    for (let i = 0; i < 6; i++) run.onEvent(hit("me", "bot"), 2_000 + i * 300);
    assert.equal(run.score, 6);
    assert.equal(run.done, false);
    run.onEvent(hit("me", "bot"), 4_000);
    assert.deepEqual([run.done, run.score, run.medal], [true, 7, 3]);
  });
});
