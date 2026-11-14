// Dojo: la dimostrazione registrata dal laboratorio, rifatta in una Match vera, fa entrare tutti i colpi in fila.
// Si lancia con `npm test`.

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";
import { CHARACTERS } from "./characters";
import { movesOf } from "./comboLab";
import { TICK_RATE } from "./constants";
import { DEMO_KEYS, dojoDemo, dojoMoves, keysMask, maskKeys } from "./dojo";
import { Match } from "./match";
import type { GameEvent } from "./types";

const DT = 1000 / TICK_RATE;

// La dimostrazione in una stanza d'allenamento sull'arena del Dojo: i colpi di chi impara, in ordine
function play(characterId: string, moves: string[]) {
  const demo = dojoDemo(characterId, moves);
  const match = new Match({ stageId: "dojo", rules: { mode: "training" } });
  match.addPlayer("bot", "Manichino", "lampione"); // il bot entra per primo (e diventa Bonobot), come nella stanza vera
  match.addPlayer("me", "Io", characterId);
  for (let i = 0; i < 30; i++) match.step(DT);
  match.startDojo("me", demo, true);
  const events: GameEvent[] = [];
  for (let i = 0; i < (demo.keys?.length ?? 0) + 3; i++) {
    match.setInput("me", { ...maskKeys(0b1111111111), seq: i } as never); // i tasti veri non contano durante la dimostrazione
    events.push(...match.step(DT));
  }
  const hits = events.flatMap((e) => (e.type === "hit" && e.attackerId === "me" && e.targetId === "bot" ? [e.kind as string] : []));
  return { demo, hits, events };
}

describe("Dojo", () => {
  it("i tasti passano da numero a tasti e ritorno", () => {
    const keys = { light: true, down: true, run: true };
    assert.deepEqual(Object.entries(maskKeys(keysMask(keys))).filter(([, v]) => v).map(([k]) => k).sort(), Object.keys(keys).sort());
  });

  it("il client Godot legge i tasti nello stesso ordine", () => {
    const gd = readFileSync(new URL("../../godot/scripts/dojo.gd", import.meta.url), "utf8");
    assert.ok(gd.includes(`const DEMO_KEYS := [${DEMO_KEYS.map((k) => `"${k}"`).join(", ")}]`), "DEMO_KEYS diversi in godot/scripts/dojo.gd");
  });

  it("chiede solo combo e mosse che il personaggio ha", () => {
    assert.deepEqual(dojoMoves("orsoblu", { move: "lightUp" }), ["lightUp"]);
    assert.equal(dojoMoves("orsoblu", { move: "volare" }), null);
    assert.equal(dojoMoves("orsoblu", { combo: 99 }), null);
    assert.equal(dojoMoves("orsoblu", { move: "grab" }), null);
  });

  for (const ch of Object.values(CHARACTERS)) {
    if (!ch.combos?.length) continue;
    it(`${ch.id}: ogni combo dimostrata entra tutta, colpo dopo colpo`, () => {
      ch.combos!.forEach((c, i) => {
        const moves = dojoMoves(ch.id, { combo: i })!;
        const { demo, hits } = play(ch.id, moves);
        assert.ok(demo.keys, `${c.name}: il laboratorio non sa farla`);
        let at = 0;
        for (const h of hits) if (h === moves[at]) at++;
        assert.equal(at, moves.length, `${c.name} (${moves.join(" → ")} a ${demo.percent}%): entrano ${hits.join(", ")}`);
      });
    });
  }

  it("le mosse da sole di Bonobot: tutte hanno i tasti, quelle che entrano entrano anche nella stanza", () => {
    for (const m of movesOf("bonobot").filter((x) => x.id !== "grab")) {
      const { demo, hits } = play("bonobot", [m.id]);
      assert.ok(demo.keys, `${m.id}: almeno a vuoto si fa`);
      if (!demo.lands) continue;
      assert.ok(hits.includes(m.kind), `${m.id}: entrano ${hits.join(", ")}`);
    }
  });

  it("annuncia la prova con i tasti, e senza dimostrazione non li manda", () => {
    const match = new Match({ stageId: "dojo", rules: { mode: "training" } });
    match.addPlayer("me", "Io", "orsoblu");
    match.addPlayer("bot", "Manichino", "elvedeo");
    const demo = dojoDemo("orsoblu", ["light"]);
    match.startDojo("me", demo, false);
    const e = match.step(DT).find((x) => x.type === "dojo");
    assert.ok(e && e.type === "dojo" && !e.keys && e.percent === demo.percent);
    assert.equal(match.players.find((p) => p.id === "bot")!.characterId, "bonobot", "il manichino diventa Bonobot");
  });
});
