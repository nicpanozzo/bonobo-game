// Scalata (Platform): una torre di piattaforme, primo in cima vince. Ci si può spingere giù a colpi.
// Chi cade riparte dall'ultimo pianerottolo toccato. A tempo scaduto conta chi è arrivato più in alto.

import { MINIGAME, WORLD } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { StageSpec } from "../../stages";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { placesFromScores, TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.scalata;

class Scalata extends TimedGame {
  private best = new Map<string, number>(); // il punto più alto toccato, in pixel dal fondo
  private arrived: string[] = []; // chi ha toccato la cima, in ordine
  private sinceFirstMs = 0;

  constructor(private stage: StageSpec) {
    super(C.durationMs, "metri");
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, _events: readonly GameEvent[]) {
    const bottom = this.stage.solids[0].y;
    const goal = this.stage.goal!;
    const cps = this.stage.checkpoints ?? [];
    if (this.arrived.length > 0) this.sinceFirstMs += dtMs;
    for (const f of fighters) {
      if (f.respawning || f.eliminated) continue;
      const height = Math.max(0, bottom - f.y);
      if (f.onGround && height > (this.best.get(f.id) ?? 0)) this.best.set(f.id, height);
      // Il pianerottolo più alto toccato da terra: da lì si riparte dopo una caduta
      if (f.onGround) {
        let i = f.checkpoint;
        while (i + 1 < cps.length && f.y <= cps[i + 1].y + 4) i++;
        f.checkpoint = i;
      }
      const inGoal = f.x > goal.x && f.x < goal.x + goal.width && f.y <= goal.y + 4 && f.y > goal.y - goal.height;
      if (inGoal && !this.arrived.includes(f.id)) {
        this.arrived.push(f.id);
        this.text = this.arrived.length === 1 ? `${f.name} arriva in cima per primo!` : `${f.name} arriva in cima`;
      }
      // Punti: metri saliti; chi è arrivato ha i metri della cima più un bonus per l'ordine d'arrivo
      const idx = this.arrived.indexOf(f.id);
      this.scores[f.id] = idx >= 0 ? Math.round((bottom - goal.y) / 100) + (10 - idx) : Math.round((this.best.get(f.id) ?? 0) / 100);
    }
    if (this.arrived.length > 0 && (this.sinceFirstMs >= C.afterFirstMs || this.arrived.length >= fighters.length)) this.leftMs = 0;
    this.props = [{ kind: "goal", x: goal.x + goal.width / 2, y: goal.y, w: goal.width, h: goal.height, text: "CIMA" }];
  }

  places(ids: string[]) {
    return placesFromScores(ids, this.scores);
  }

  botGoal() {
    const g = this.stage.goal!;
    return { x: g.x + g.width / 2, y: g.y };
  }
}

// La torre: il pavimento in fondo, poi file di piattaforme a zig-zag fino alla cima, con muretti ai lati
function tower(seed: number): StageSpec {
  const r = rng(seed);
  const height = C.height;
  const groundY = height - 120;
  const platforms: StageSpec["platforms"] = [];
  const checkpoints: { x: number; y: number }[] = [{ x: WORLD.width / 2, y: groundY }];
  let side = 0;
  for (let y = groundY - C.rowGap, row = 0; y > 360; y -= C.rowGap, row++) {
    // Due piattaforme per fila, una a sinistra e una a destra, che si spostano un po' a ogni fila
    side = (side + 1) % 2;
    const shift = Math.round((r.next() - 0.5) * 160);
    platforms.push({ x: 200 + shift + side * 80, y, width: 230 }, { x: 850 + shift - side * 80, y, width: 230 });
    if (row % Math.round(C.checkpointEvery / C.rowGap) === Math.round(C.checkpointEvery / C.rowGap) - 1) checkpoints.push({ x: 315 + shift + side * 80, y });
  }
  const topY = 300;
  const stage = arena({
    id: "scalata",
    name: "Scalata",
    width: WORLD.width,
    height,
    solids: [
      { x: 80, y: groundY, width: WORLD.width - 160, height: 120 },
      { x: 500, y: topY, width: 280, height: 40 }, // la cima
    ],
    platforms,
    spawns: [0.3, 0.7, 0.45, 0.55, 0.2, 0.8, 0.37, 0.63].map((f) => ({ x: Math.round(80 + (WORLD.width - 160) * f), y: groundY })),
    respawn: { x: WORLD.width / 2, y: groundY - 200 },
    camera: { minZoom: 0.55 },
    checkpoints,
    sky: 0x1f2b44,
    solid: 0x6c5b4b,
    edge: 0xd9b26a,
  });
  stage.goal = { x: 500, y: topY, width: 280, height: 80 };
  return stage;
}

export const scalata: MinigameDef = {
  info: {
    id: "scalata",
    title: "Scalata",
    category: "platform",
    howTo: "Sali di piattaforma in piattaforma fino alla CIMA: il primo che ci arriva vince. Puoi spingere giù gli altri. Chi cade riparte dall'ultimo pianerottolo.",
    keys: "Muoviti, salta e doppio salto; colpisci chi ti sta sopra",
    durationSec: C.durationMs / 1000,
  },
  build(seed) {
    const stage = tower(seed);
    return { stage, rules: { mode: "ffa", stocks: 3 }, unlimitedStocks: true, runtime: new Scalata(stage) };
  },
};
