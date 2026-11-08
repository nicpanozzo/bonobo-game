import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { GENRE, TICK_RATE } from "../constants";
import { STAGES } from "../stages";
import { autoGenre, genreAt, technoBeat } from "./genre";
import { createFighter, stepWorld, type PhysicsContext } from "./index";
import { stageAt } from "./timed";

const DT = 1000 / TICK_RATE;
const palco = STAGES.palco;
const g = palco.genres!;
const disco = (genre: string) => palco.pads!.findIndex((p) => p.effect.genre === genre);

describe("Il Palco: cambio di genere", () => {
  it("il DJ gira da solo dopo la prova del suono", () => {
    assert.equal(autoGenre(palco, g.startMs - 1), null);
    assert.equal(autoGenre(palco, g.startMs), "metal");
    assert.equal(autoGenre(palco, g.startMs + g.everyMs), "reggae");
    assert.equal(autoGenre(palco, g.startMs + 2 * g.everyMs), "techno");
    assert.equal(autoGenre(palco, g.startMs + 3 * g.everyMs), "metal");
  });

  it("un disco impone il suo genere finché dura, e vince l'ultimo", () => {
    const pressed: (number | null)[] = [null, null, null];
    pressed[disco("reggae")] = 1000;
    assert.equal(genreAt(palco, 2000, pressed), "reggae", "anche nella prova del suono");
    pressed[disco("techno")] = 3000;
    assert.equal(genreAt(palco, 4000, pressed), "techno");
    const fine = 3000 + palco.pads![disco("techno")].effect.durationMs;
    assert.equal(genreAt(palco, fine, pressed), autoGenre(palco, fine), "finito il disco torna il DJ");
  });

  it("le piattaforme della techno ci sono solo con la techno, a turno", () => {
    const techno = g.startMs + 2 * g.everyMs;
    const cycle = g.beatMs * GENRE.technoBlinkBeats;
    const count = (t: number) => stageAt(palco, t).platforms.length;
    const base = palco.platforms.filter((p) => !p.genre).length;
    assert.equal(count(g.startMs + 10), base, "col metal no");
    const t0 = Math.ceil(techno / cycle) * cycle + 10;
    assert.equal(technoBeat(palco, t0) !== technoBeat(palco, t0 + cycle), true);
    assert.equal(count(t0), base + 2);
    const a = stageAt(palco, t0).platforms.find((p) => p.genre);
    const b = stageAt(palco, t0 + cycle).platforms.find((p) => p.genre);
    assert.notEqual(a!.beat, b!.beat, "si scambiano");
  });

  it("col reggae si cade più piano", () => {
    const fall = (pressed: (number | null)[]) => {
      const ctx: PhysicsContext = { stage: palco, events: [], timeMs: 2000, padsMs: pressed };
      const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, palco);
      f.y = 100;
      f.onGround = false;
      for (let i = 0; i < 20; i++) stepWorld([f], DT, ctx);
      return f.vy;
    };
    const pressed: (number | null)[] = [null, null, null];
    pressed[disco("reggae")] = 1000;
    const moon = fall(pressed);
    const normal = fall([null, null, null]);
    assert.ok(moon < normal * 0.7, `reggae ${moon} contro ${normal}`);
  });

  it("le fiamme ci sono solo col metal", () => {
    const fire = palco.hazards!.findIndex((h) => h.genre === "metal" && !h.offsetMs);
    const h = palco.hazards![fire];
    const hit = (pressed: (number | null)[]) => {
      const ctx: PhysicsContext = { stage: palco, events: [], timeMs: 6400 - DT, padsMs: pressed }; // 6400: la fiamma è accesa
      const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, palco);
      f.x = h.x + h.width / 2;
      f.y = h.y + h.height;
      stepWorld([f], DT, ctx);
      return ctx.events.some((e) => e.type === "hazard");
    };
    const metal: (number | null)[] = [null, null, null];
    metal[disco("metal")] = 5000;
    assert.equal(hit(metal), true);
    assert.equal(hit([null, null, null]), false, "nella prova del suono niente fiamme");
  });
});
