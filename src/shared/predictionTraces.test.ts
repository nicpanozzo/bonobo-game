import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";
import { predictionTraces } from "./predictionTraces";

describe("tracce della predizione (E17)", () => {
  const traces = predictionTraces();

  it("il file per il test di Godot è aggiornato: dopo un cambio al movimento, npm run export:godot", () => {
    const saved = JSON.parse(readFileSync(new URL("../../godot/tests/data/prediction-traces.json", import.meta.url), "utf8"));
    assert.deepEqual(saved, JSON.parse(JSON.stringify(traces)));
  });

  it("coprono quello che il port deve fare: salti doppi, coyote, piattaforme attraversate, caduta veloce", () => {
    const ticks = traces.flatMap((t) => t.ticks.map((k) => k.state));
    assert.ok(traces.every((t) => t.ticks.length >= 120), "ogni traccia ha almeno 2 s di gioco");
    assert.ok(ticks.some((s) => s.jumps === 0), "doppio salto");
    assert.ok(ticks.some((s) => s.coyote > 0), "tempo di grazia dal bordo");
    assert.ok(ticks.some((s) => s.drop > 0), "giù attraverso le piattaforme");
    assert.ok(ticks.some((s) => s.vy > 1000), "caduta veloce");
    assert.ok(ticks.some((s) => s.rising) && ticks.some((s) => !s.onGround && !s.rising && s.vy < 0), "salto corto");
  });
});
