import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getStage } from "./stages";
import { LESSONS, lessonDone, TUTORIAL_STAGE_ID } from "./tutorial";
import type { GameEvent } from "./types";

const lesson = (id: string) => LESSONS.find((l) => l.id === id)!;

describe("tutorial", () => {
  it("ogni tappa si completa solo con il suo evento, fatto da chi gioca", () => {
    const jump: GameEvent = { type: "jump", id: "me", x: 0, y: 0, air: false };
    assert.equal(lessonDone(lesson("salto"), jump, "me"), true);
    assert.equal(lessonDone(lesson("salto"), jump, "altro"), false);
    assert.equal(lessonDone(lesson("doppio"), jump, "me"), false, "il salto da terra non è il doppio salto");
    assert.equal(lessonDone(lesson("doppio"), { ...jump, air: true }, "me"), true);
    assert.equal(lessonDone(lesson("leggero"), { type: "attack", id: "me", kind: "heavy" }, "me"), false);
    assert.equal(lessonDone(lesson("pesante"), { type: "attack", id: "me", kind: "heavy" }, "me"), true);
  });

  it("colpire e buttare fuori contano per chi colpisce, non per chi le prende", () => {
    const hit: GameEvent = { type: "hit", attackerId: "me", targetId: "bot", kind: "light", damage: 5, percent: 5, knockback: 300, x: 0, y: 0 };
    assert.equal(lessonDone(lesson("colpo"), hit, "me"), true);
    assert.equal(lessonDone(lesson("colpo"), { ...hit, attackerId: "bot", targetId: "me" }, "me"), false);
    const ko: GameEvent = { type: "ko", id: "bot", byId: "me", x: 0, y: 0, stocksLeft: 3 };
    assert.equal(lessonDone(lesson("fuori"), ko, "me"), true);
    assert.equal(lessonDone(lesson("fuori"), { ...ko, id: "me", byId: null }, "me"), false);
  });

  it("id unici e la palestra esiste", () => {
    assert.equal(new Set(LESSONS.map((l) => l.id)).size, LESSONS.length);
    assert.equal(getStage(TUTORIAL_STAGE_ID).id, TUTORIAL_STAGE_ID);
  });
});
