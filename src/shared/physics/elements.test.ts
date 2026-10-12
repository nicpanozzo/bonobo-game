// Test di ascensori e trappole (#14): logica pura, si lanciano con `npm test`.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { HAZARD, TICK_RATE, WORLD } from "../constants";
import type { Hazard, MovingPlatform, StageSpec } from "../stages";
import { getStage } from "../stages";
import { createFighter, floodPhase, hazardActive, hazardRect, jetPhase, moverPosition, stepWorld, travelDirection, travelPhase, type PhysicsContext } from "./index";

const DT = 1000 / TICK_RATE;

const elevator: MovingPlatform = { width: 200, path: [{ x: 500, y: 600 }, { x: 500, y: 300 }], periodMs: 4000, pauseMs: 1000 };
const shuttle: MovingPlatform = { width: 200, path: [{ x: 300, y: 500 }, { x: 700, y: 500 }], periodMs: 4000 };
const spikes: Hazard = { kind: "spuntoni", x: 400, y: 580, width: 200, height: 20, damage: 10, knockback: 500, knockbackGrowth: 6, angleDeg: 80 };

function stageWith(extra: Partial<StageSpec>): StageSpec {
  return {
    id: "prova",
    name: "Prova",
    solids: [{ x: 0, y: 650, width: WORLD.width, height: 50 }],
    platforms: [],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: 600 }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
    ...extra,
  };
}

function setup(stage: StageSpec, at: { x: number; y: number }) {
  const ctx: PhysicsContext = { stage, events: [] };
  const f = createFighter({ id: "p0", name: "P0", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
  f.x = at.x;
  f.y = at.y;
  return { ctx, f };
}

const run = (f: ReturnType<typeof createFighter>, ctx: PhysicsContext, ticks: number) => {
  for (let i = 0; i < ticks; i++) stepWorld([f], DT, ctx);
};

describe("piattaforme mobili", () => {
  it("si ferma ai piani e torna indietro", () => {
    assert.deepEqual(moverPosition(elevator, 0), { x: 500, y: 600 });
    assert.deepEqual(moverPosition(elevator, 900), { x: 500, y: 600 }); // ancora in sosta
    assert.equal(moverPosition(elevator, 1500).y, 450); // a metà della salita (1 s di viaggio per tratto)
    assert.deepEqual(moverPosition(elevator, 2500), { x: 500, y: 300 }); // sosta in cima
    assert.equal(moverPosition(elevator, 3500).y, 450); // a metà della discesa
    assert.deepEqual(moverPosition(elevator, 4000), moverPosition(elevator, 0)); // il giro ricomincia
  });

  it("in giro torna dritto al primo punto", () => {
    const loop: MovingPlatform = { width: 50, path: [{ x: 0, y: 0 }, { x: 100, y: 0 }, { x: 100, y: 100 }], periodMs: 3000, loop: true };
    const p = moverPosition(loop, 2500); // sull'ultimo tratto, dalla terza al primo punto
    assert.ok(p.x > 0 && p.x < 100 && p.y > 0 && p.y < 100);
  });

  it("l'ascensore porta su chi ci sta sopra", () => {
    const { ctx, f } = setup(stageWith({ movers: [elevator] }), { x: 600, y: 600 });
    run(f, ctx, 3);
    assert.equal(f.riding, 0);
    run(f, ctx, Math.round(2000 / DT)); // fino alla sosta in cima
    assert.ok(f.onGround, "resta a terra sull'ascensore");
    assert.ok(Math.abs(f.y - 300) < 1, `arriva in cima (y = ${f.y})`);
  });

  it("la navetta porta di lato chi ci sta sopra", () => {
    const { ctx, f } = setup(stageWith({ movers: [shuttle] }), { x: 400, y: 500 });
    run(f, ctx, Math.round(1000 / DT));
    assert.ok(f.onGround);
    assert.ok(f.x > 550 && f.x < 650, `si è spostato con la navetta (x = ${f.x})`);
  });

  it("si atterra su un ascensore che sale incontro", () => {
    const fast: MovingPlatform = { width: 200, path: [{ x: 500, y: 600 }, { x: 500, y: 100 }], periodMs: 1000 };
    const { ctx, f } = setup(stageWith({ movers: [fast] }), { x: 600, y: 200 });
    f.onGround = false;
    run(f, ctx, Math.round(400 / DT));
    assert.equal(f.riding, 0, "è sopra l'ascensore, non caduto attraverso");
  });

  it("con giù si scende dall'ascensore", () => {
    const { ctx, f } = setup(stageWith({ movers: [elevator] }), { x: 600, y: 600 });
    run(f, ctx, Math.round(1500 / DT)); // a metà salita
    f.input = { ...f.input, down: true };
    run(f, ctx, Math.round(800 / DT));
    assert.equal(f.y, 650, "è sceso fino al pavimento");
  });
});

describe("trappole", () => {
  it("le trappole a ciclo si accendono e si spengono", () => {
    const fire = { ...spikes, periodMs: 4000, activeMs: 1000 };
    assert.equal(hazardActive(spikes, 123456), true);
    assert.equal(hazardActive(fire, 500), true);
    assert.equal(hazardActive(fire, 1500), false);
    assert.equal(hazardActive(fire, 4200), true);
  });

  it("gli spuntoni tolgono percentuale e lanciano via, una volta sola", () => {
    const { ctx, f } = setup(stageWith({ spawns: [{ x: 500, y: 650 }], hazards: [spikes] }), { x: 500, y: 650 });
    f.lastHitById = "spintone";
    run(f, ctx, 1);
    assert.equal(f.percent, 10);
    const ev = ctx.events.filter((e) => e.type === "hazard");
    assert.equal(ev.length, 1);
    run(f, ctx, 12);
    assert.ok(f.y < 620, `è stato lanciato in alto (y = ${f.y})`);
    run(f, ctx, Math.round(HAZARD.cooldownMs / DT) - 20);
    assert.equal(f.percent, 10, "niente colpi a raffica");
    assert.equal(f.lastHitById, "spintone", "il KO resta a chi l'ha spinto");
  });

  it("una trappola spenta non fa niente", () => {
    const off = { ...spikes, periodMs: 4000, activeMs: 1000, offsetMs: 2000 };
    const { ctx, f } = setup(stageWith({ hazards: [off] }), { x: 500, y: 650 });
    run(f, ctx, 30);
    assert.equal(f.percent, 0);
  });

  it("La Fabbrica ha ascensori e trappole", () => {
    const stage = getStage("fabbrica");
    assert.ok((stage.movers?.length ?? 0) > 0 && (stage.hazards?.length ?? 0) > 0);
  });
});

describe("acqua alta (#228)", () => {
  // Giro di 10 s: calma fino a 5 s, pioggia 1 s, sale in 1 s, alta 2 s, scende in 1 s
  const water: Hazard = {
    kind: "acqua", x: 300, y: 620, width: 400, height: 30, damage: 6, knockback: 550, knockbackGrowth: 3, angleDeg: 85,
    flood: { highY: 540, periodMs: 10000, warnMs: 1000, riseMs: 1000, holdMs: 2000, fallMs: 1000 },
  };
  const step: { x: number; y: number; width: number } = { x: 300, y: 580, width: 400 }; // gradino che va sott'acqua

  it("il livello sale, resta alto e torna giù a ogni giro", () => {
    assert.equal(hazardRect(water, 0).y, 620);
    assert.deepEqual(floodPhase(water, 5500), { phase: "warn", k: 0.5 });
    assert.equal(hazardRect(water, 5500).y, 620, "durante la pioggia è ancora bassa");
    assert.equal(hazardRect(water, 6500).y, 580, "a metà della salita");
    assert.equal(hazardRect(water, 7500).y, 540);
    assert.equal(hazardRect(water, 8900).y, 540);
    assert.equal(hazardRect(water, 9500).y, 580, "a metà della discesa");
    assert.equal(hazardRect(water, 10000).y, 620, "il giro ricomincia");
    const r = hazardRect(water, 7500);
    assert.equal(r.y + r.height, water.y + water.height, "il fondo resta fermo");
  });

  it("senza flood il rettangolo è quello dell'arena", () => {
    assert.deepEqual(hazardRect(spikes, 1234), spikes);
    assert.deepEqual(floodPhase(spikes, 1234), { phase: "calm", k: 0 });
  });

  it("chi sta sul gradino resta asciutto con l'acqua bassa", () => {
    const { ctx, f } = setup(stageWith({ platforms: [step], hazards: [water] }), { x: 500, y: 580 });
    run(f, ctx, Math.round(4000 / DT));
    assert.equal(f.percent, 0);
    assert.ok(f.onGround);
  });

  it("l'acqua alta colpisce chi sta sul gradino e lo lancia in alto", () => {
    const { ctx, f } = setup(stageWith({ platforms: [step], hazards: [water] }), { x: 500, y: 580 });
    ctx.timeMs = 7000; // appena salita
    run(f, ctx, 2);
    assert.equal(f.percent, 6);
    assert.equal(ctx.events.filter((e) => e.type === "hazard").length, 1, "evento hazard come le altre trappole");
    run(f, ctx, 10);
    assert.ok(f.y < 540, `è stato lanciato fuori dall'acqua (y = ${f.y})`);
  });

  it("chi cade nel canale prende l'acqua anche quando è bassa", () => {
    const { ctx, f } = setup(stageWith({ hazards: [water] }), { x: 500, y: 650 });
    run(f, ctx, 1);
    assert.equal(f.percent, 6);
  });

  it("chi sta più in alto dell'acqua alta resta asciutto", () => {
    const bank = { x: 300, y: 520, width: 400 };
    const { ctx, f } = setup(stageWith({ platforms: [bank], hazards: [water] }), { x: 500, y: 520 });
    ctx.timeMs = 7000;
    run(f, ctx, Math.round(2000 / DT));
    assert.equal(f.percent, 0);
  });
});

describe("trappola che viaggia (#229)", () => {
  // Giro di 10 s: calma fino a 7 s, campanello 1 s, passa in 2 s da x 0 a x 1000; un giro sì e uno no al contrario
  const bike: Hazard = {
    kind: "ciclista", x: 0, y: 0, width: 70, height: 60, damage: 10, knockback: 600, knockbackGrowth: 5, angleDeg: 35,
    travel: { path: [{ x: 0, y: 590 }, { x: 1000, y: 590 }], periodMs: 10000, warnMs: 1000, crossMs: 2000, alternate: true },
  };

  it("calma, campanello, passaggio, e il giro dopo al contrario", () => {
    assert.equal(travelPhase(bike, 6000).phase, "calm");
    assert.deepEqual(travelPhase(bike, 7500), { phase: "warn", k: 0.5, reverse: false });
    assert.equal(travelPhase(bike, 9000).phase, "cross");
    assert.equal(hazardRect(bike, 9000).x, 500, "a metà del passaggio è a metà strada");
    assert.equal(travelDirection(bike, 9000), 1);
    assert.equal(travelPhase(bike, 19000).reverse, true);
    assert.equal(hazardRect(bike, 19000).x, 500);
    assert.equal(hazardRect(bike, 18500).x, 750, "al ritorno va da destra a sinistra");
    assert.equal(travelDirection(bike, 19000), -1);
  });

  it("segue un percorso con più punti, come il ponte ad arco", () => {
    const arc: Hazard = { ...bike, travel: { ...bike.travel!, path: [{ x: 0, y: 500 }, { x: 100, y: 400 }, { x: 200, y: 500 }], alternate: false } };
    const top = hazardRect(arc, 9000); // a metà del percorso: in cima
    assert.ok(Math.abs(top.x - 100) < 1e-9 && Math.abs(top.y - 400) < 1e-9, `in cima (${top.x}, ${top.y})`);
  });

  it("chi sta sul percorso viene travolto nella direzione della bici, ma solo mentre passa", () => {
    const stage = stageWith({ hazards: [bike] });
    const calm = setup(stage, { x: 500, y: 650 });
    calm.ctx.timeMs = 7000; // durante il campanello la bici non è ancora entrata
    run(calm.f, calm.ctx, Math.round(900 / DT));
    assert.equal(calm.f.percent, 0);

    const { ctx, f } = setup(stage, { x: 500, y: 650 });
    ctx.timeMs = 8900; // la bici arriva a x 500 a 9 s
    run(f, ctx, Math.round(300 / DT));
    assert.equal(f.percent, 10);
    assert.ok(f.vx > 0, `lanciato verso destra, come va la bici (vx = ${f.vx})`);

    const back = setup(stage, { x: 500, y: 650 });
    back.ctx.timeMs = 18900; // il giro dopo torna indietro
    run(back.f, back.ctx, Math.round(300 / DT));
    assert.equal(back.f.percent, 10);
    assert.ok(back.f.vx < 0, `al ritorno lanciato verso sinistra (vx = ${back.f.vx})`);
  });
});

describe("canale di Padova (#253)", () => {
  it("con lowSafe l'acqua bassa non fa male, quella che sale sì", () => {
    const water: Hazard = {
      kind: "acqua", x: 300, y: 620, width: 400, height: 30, damage: 6, knockback: 550, knockbackGrowth: 3, angleDeg: 85,
      flood: { highY: 540, periodMs: 10000, warnMs: 1000, riseMs: 1000, holdMs: 2000, fallMs: 1000, lowSafe: true },
    };
    const low = setup(stageWith({ hazards: [water] }), { x: 500, y: 650 });
    run(low.f, low.ctx, Math.round(3000 / DT)); // calma: si sta nell'acqua bassa
    assert.equal(low.f.percent, 0);
    const high = setup(stageWith({ hazards: [water] }), { x: 500, y: 650 });
    high.ctx.timeMs = 6500; // l'acqua sale
    run(high.f, high.ctx, 3);
    assert.equal(high.f.percent, 6);
  });

  it("sotto il percorso del ciclista si è al riparo", () => {
    const bike: Hazard = {
      kind: "ciclista", x: 0, y: 0, width: 70, height: 60, damage: 10, knockback: 600, knockbackGrowth: 5, angleDeg: 35,
      travel: { path: [{ x: 0, y: 520 }, { x: 1000, y: 520 }], periodMs: 10000, warnMs: 1000, crossMs: 2000 },
    };
    // Il percorso ha i piedi della bici a 580; chi sta a 650 (70 più giù) ha la testa nel rettangolo ma è sotto il ponte
    const { ctx, f } = setup(stageWith({ hazards: [bike] }), { x: 500, y: 650 });
    ctx.timeMs = 8900;
    run(f, ctx, Math.round(300 / DT));
    assert.equal(f.percent, 0);
  });

  it("il getto spinge in alto chi c'è dentro, solo quando è acceso, senza danno", () => {
    const jet = { x: 450, y: 650, width: 100, height: 300, speed: 1300, periodMs: 6000, warnMs: 1000, activeMs: 1000 };
    assert.equal(jetPhase(jet, 1000), "calm");
    assert.equal(jetPhase(jet, 4500), "warn");
    assert.equal(jetPhase(jet, 5500), "active");
    const bubbles = setup(stageWith({ jets: [jet] }), { x: 500, y: 650 });
    bubbles.ctx.timeMs = 4200;
    run(bubbles.f, bubbles.ctx, 10);
    assert.ok(bubbles.f.onGround, "con le bolle si resta a terra");
    const up = setup(stageWith({ jets: [jet] }), { x: 500, y: 650 });
    up.ctx.timeMs = 5050;
    run(up.f, up.ctx, 20);
    assert.ok(up.f.y < 450, `spinto in alto (y = ${up.f.y})`);
    assert.equal(up.f.percent, 0);
  });
});

describe("Padova, canale esterno (#264)", () => {
  it("la barca accanto alla riva sinistra raccoglie chi cade quando l'acqua è bassa, e da lì si risale", () => {
    const stage = getStage("padova");
    const { ctx, f } = setup(stage, { x: -70, y: 700 });
    ctx.timeMs = 6000; // l'acqua è bassa e la barca è ferma accanto alla riva
    f.onGround = false;
    run(f, ctx, 30);
    assert.equal(f.riding, 0, "è sulla barca");
    assert.equal(f.y, 780);
    assert.equal(hazardRect(stage.hazards![0], 6000).y, 660, "intanto l'acqua alta è giù");
    // Dalla barca alla piazza ci sono 260 px: meno del doppio salto
    assert.ok(780 - 520 < 293, "la riva si raggiunge con il doppio salto");
  });

  it("quando l'acqua sale le barche sono fuori scena", () => {
    const stage = getStage("padova");
    for (const t of [30000, 34000]) {
      for (const m of stage.movers!) {
        const x = moverPosition(m, t).x;
        assert.ok(x < stage.blastZone.left || x > stage.blastZone.right, `a ${t} ms la barca è fuori (x = ${x})`);
      }
    }
  });
});
