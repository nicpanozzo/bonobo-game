import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { readMidi, writeMidi } from "../../scripts/midi";
import { MUSIC_STAGE, TICK_RATE, WORLD } from "./constants";
import { SALA_PROVE } from "./music/sala-prove";
import { songMovers, type Song } from "./musicStage";
import { createFighter, moverOn, moverPosition, stepWorld, type PhysicsContext } from "./physics";
import { STAGES, type MovingPlatform, type StageSpec } from "./stages";

const DT = 1000 / TICK_RATE;

const song: Song = {
  id: "prova",
  name: "Prova",
  bpm: 120,
  lengthMs: 4000,
  tracks: [
    { name: "Basso", drums: false, notes: [[0, 400, 40], [1000, 400, 52], [2000, 400, 46]] },
    { name: "Melodia", drums: false, notes: [[500, 200, 60], [1000, 1500, 64], [3000, 100, 60]] },
  ],
};

describe("arena musicale (#423)", () => {
  it("il MIDI scritto si rilegge con le stesse note in millisecondi", () => {
    const mid = writeMidi(120, 480, 4 * 480, [
      { name: "Basso", channel: 0, program: 38, notes: [{ tick: 0, dur: 480, pitch: 45, velocity: 100 }, { tick: 480, dur: 240, pitch: 45, velocity: 90 }] },
      { name: "Batteria", channel: 9, program: 0, notes: [{ tick: 960, dur: 120, pitch: 36, velocity: 110 }] },
    ]);
    const back = readMidi(mid);
    assert.equal(back.bpm, 120);
    assert.equal(back.lengthMs, 2000);
    assert.deepEqual(back.tracks.map((t) => [t.name, t.channel]), [["Basso", 0], ["Batteria", 9]]);
    assert.deepEqual(back.tracks[0].notes.map((n) => [n.startMs, n.durMs, n.pitch]), [[0, 500, 45], [500, 250, 45]]);
    assert.deepEqual(back.tracks[1].notes.map((n) => [n.startMs, n.pitch]), [[1000, 36]]);
  });

  it("l'ascensore va all'altezza di ogni nota del basso e ci resta", () => {
    const [lift] = songMovers(song, [{ role: "lift", track: "Basso", x: 100, width: 100, yLow: 500, yHigh: 300, tint: 0 }]);
    const glide = MUSIC_STAGE.liftGlideMs;
    assert.equal(moverPosition(lift, glide + 50).y, 500, "la nota più bassa in basso");
    assert.equal(moverPosition(lift, 1000 + glide + 50).y, 300, "la più alta in cima");
    assert.equal(moverPosition(lift, 1900).y, 300, "resta lì fino alla nota dopo");
    assert.equal(moverPosition(lift, 2000 + glide).y, 400, "quella di mezzo a metà");
    assert.equal(moverPosition(lift, 1000 + glide / 2).y, 400, "tra due note scivola");
    assert.deepEqual(moverPosition(lift, 4000 + glide + 50), moverPosition(lift, glide + 50), "il giro ricomincia con il brano");
    assert.ok(moverOn(lift, 1234), "un ascensore c'è sempre");
  });

  it("i tasti della melodia si accendono con le note, almeno per keyMinOnMs", () => {
    const keys = songMovers(song, [{ role: "keys", track: "Melodia", width: 80, slots: [{ x: 300, y: 300 }, { x: 400, y: 280 }], tint: 0 }]);
    assert.equal(keys.length, 2);
    const [low, high] = keys;
    assert.ok(!moverOn(low, 400) && moverOn(low, 600), "il Do si accende alla sua nota");
    assert.ok(moverOn(low, 500 + MUSIC_STAGE.keyMinOnMs - 1) && !moverOn(low, 500 + MUSIC_STAGE.keyMinOnMs + 1), "una nota breve tiene il tasto per keyMinOnMs");
    assert.ok(moverOn(high, 2400) && !moverOn(high, 2600), "una nota lunga per tutta la sua durata");
    assert.deepEqual(moverPosition(high, 2000), { x: 400, y: 280 });
  });

  it("chi sta su un tasto cade quando la nota finisce", () => {
    const [key] = songMovers(song, [{ role: "keys", track: "Melodia", width: 200, slots: [{ x: 500, y: 400 }], tint: 0 }]);
    const stage: StageSpec = {
      id: "prova",
      name: "Prova",
      solids: [{ x: 0, y: 650, width: WORLD.width, height: 50 }],
      platforms: [],
      movers: [key],
      blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
      spawns: [{ x: 600, y: 650 }],
      respawn: { x: 600, y: 100 },
      colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
    };
    const ctx: PhysicsContext = { stage, events: [], timeMs: 1100 };
    const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
    f.x = 600;
    f.y = 390;
    f.onGround = false;
    for (let i = 0; i < 6; i++) stepWorld([f], DT, ctx);
    assert.equal(f.riding, 0, "atterra sul tasto acceso");
    // Le note a 1000 e 3000 (stesso tasto) lo tengono acceso fino a 2500; poi sparisce
    while ((ctx.timeMs ?? 0) < 3000) stepWorld([f], DT, ctx);
    assert.equal(f.riding, -1);
    assert.ok(f.y > 400, `è caduto (y = ${f.y})`);
  });

  it("Sala Prove: le piattaforme seguono il brano di prova e il giro dura quanto la musica", () => {
    const stage = STAGES.musica;
    assert.equal(stage.song?.id, SALA_PROVE.id);
    assert.equal(stage.song?.lengthMs, SALA_PROVE.lengthMs);
    const movers: MovingPlatform[] = stage.movers ?? [];
    assert.ok(movers.length >= 5);
    for (const m of movers) {
      assert.equal(m.periodMs, SALA_PROVE.lengthMs);
      for (const k of m.keys ?? []) assert.ok(k[0] >= 0 && k[0] < m.periodMs, "chiavi dentro il giro");
      for (let t = 0; t < m.periodMs; t += 97) {
        const p = moverPosition(m, t);
        assert.ok(p.x >= 0 && p.x + m.width <= WORLD.width && p.y > 100 && p.y < 560, `dentro lo schermo a ${t} ms`);
      }
    }
    // In ogni momento c'è almeno un tasto della melodia acceso o in arrivo entro un battito
    const keys = movers.filter((m) => m.on);
    const beat = 60000 / SALA_PROVE.bpm;
    for (let t = 0; t < SALA_PROVE.lengthMs; t += 250) assert.ok(keys.some((m) => moverOn(m, t) || moverOn(m, t + beat)), `qualcosa a ${t} ms`);
  });
});
