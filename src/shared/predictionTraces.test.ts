import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";
import { DASH, FIGHTER } from "./constants";
import { predictionTraces } from "./predictionTraces";

describe("tracce della predizione (E17)", () => {
  const traces = predictionTraces();

  it("il file per il test di Godot è aggiornato: dopo un cambio al movimento, npm run export:godot", () => {
    const saved = JSON.parse(readFileSync(new URL("../../godot/tests/data/prediction-traces.json", import.meta.url), "utf8"));
    assert.deepEqual(saved, JSON.parse(JSON.stringify(traces)));
  });

  it("coprono quello che il port deve fare: salti doppi, coyote, piattaforme, caduta veloce, scatto, schivata, attacchi, recupero, preparazione e atterraggi", () => {
    const ticks = traces.flatMap((t) => t.ticks.map((k) => k.state));
    assert.ok(traces.every((t) => t.ticks.length >= 120), "ogni traccia ha almeno 2 s di gioco");
    assert.ok(ticks.some((s) => s.jumps === 0), "doppio salto");
    assert.ok(ticks.some((s) => s.coyote > 0), "tempo di grazia dal bordo");
    assert.ok(ticks.some((s) => s.drop > 0), "giù attraverso le piattaforme");
    assert.ok(ticks.some((s) => s.vy > 1000), "caduta veloce");
    assert.ok(ticks.some((s) => s.rising) && ticks.some((s) => !s.onGround && !s.rising && s.vy < 0), "salto corto");
    assert.ok(!DASH.byTap || ticks.some((s) => s.dashing && s.dash > 0) && ticks.some((s) => s.dashing && s.dash === 0), "scatto e corsa");
    assert.ok(ticks.some((s) => s.dashing && s.dash === 0) && ticks.some((s) => s.attack === "dashAttack"), "corsa col tasto e attacco in corsa");
    assert.ok(ticks.some((s) => s.dodge > 0 && s.onGround) && ticks.some((s) => s.dodge > 0 && s.airDodge), "schivata a terra e in aria");
    assert.ok(ticks.some((s) => s.attack === "light" && s.onGround) && ticks.some((s) => s.attack === "heavyDown"), "attacchi da terra");
    assert.ok(ticks.some((s) => s.attack?.endsWith("Air")) && ticks.some((s) => s.attack?.endsWith("Up")), "attacchi in aria e in su");
    assert.ok(ticks.some((s) => s.attack === "recovery") && ticks.some((s) => s.helpless && !s.attack), "recupero");
    // prima della fine del colpo precedente, o durante la preparazione al salto o l'atterraggio (#384 A3)
    const waiting = (s: (typeof ticks)[number]) => !!s.attack || s.jumpSquat > 0 || s.landing > 0;
    assert.ok(ticks.some((s) => (s.lightBuffer > 0 || s.heavyBuffer > 0) && waiting(s)), "attacco premuto quando non può ancora partire");
    assert.ok(ticks.some((s) => s.jumpSquat > 0) && ticks.some((s) => s.landing > 0 && s.landing <= FIGHTER.landingLagMs), "preparazione al salto e atterraggio");
    assert.ok(ticks.some((s) => s.landing > FIGHTER.landingLagMs), "atterraggio durante un attacco in aria");
  });
});
