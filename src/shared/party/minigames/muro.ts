// Il Muro (Puzzle): arriva un muro che attraversa tutta l'arena, con un buco a un'altezza sola: in basso (resta a terra),
// in mezzo (sulle piattaforme di mezzo o in salto) o in alto (sulla piattaforma in cima). Chi non è all'altezza del buco
// quando il muro gli passa addosso vola via. Ogni muro superato vale un punto; i muri vanno sempre più veloci.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { bump, TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.muro;
const FLOOR = 580;
const MID = 420; // le piattaforme di mezzo
const TOP = 270; // la piattaforma in cima
const LEFT = 140;
const RIGHT = 1140;

type Hole = "basso" | "medio" | "alto";
// Il buco (dall'alto al basso) e dove devono stare i piedi per passarci
const HOLES: Record<Hole, { top: number; bottom: number; feetMin: number; feetMax: number; label: string }> = {
  basso: { top: FLOOR - 140, bottom: FLOOR, feetMin: FLOOR - 50, feetMax: FLOOR + 10, label: "Buco in basso: resta a terra!" },
  medio: { top: MID - 140, bottom: MID + 20, feetMin: MID - 50, feetMax: MID + 20, label: "Buco in mezzo: sulle piattaforme!" },
  alto: { top: TOP - 140, bottom: TOP + 20, feetMin: TOP - 50, feetMax: TOP + 20, label: "Buco in alto: sali in cima!" },
};

interface Wall {
  x: number;
  dir: -1 | 1;
  hole: Hole;
  speed: number;
}

class Muro extends TimedGame {
  private wall: Wall | null = null;
  private nextMs = C.firstMs;
  private count = 0;
  private struck = new Set<string>(); // chi questo muro l'ha già preso
  private random: () => number;

  constructor(seed: number) {
    super(C.durationMs, "muri");
    this.random = rng(seed).next;
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, _events: readonly GameEvent[]) {
    if (!this.wall) {
      this.nextMs -= dtMs;
      if (this.nextMs <= 0) {
        const holes: Hole[] = ["basso", "medio", "alto"];
        const hole = holes[Math.floor(this.random() * holes.length)];
        const dir = this.count % 2 === 0 ? -1 : 1;
        const speed = Math.min(C.maxSpeed, C.minSpeed + this.count * 30);
        this.wall = { x: dir < 0 ? RIGHT + 60 : LEFT - 60, dir, hole, speed };
        this.struck.clear();
        this.text = HOLES[hole].label;
      }
    }
    const w = this.wall;
    if (w) {
      const prev = w.x;
      w.x += w.dir * w.speed * (dtMs / 1000);
      const h = HOLES[w.hole];
      for (const f of fighters) {
        if (f.respawning || f.eliminated || this.struck.has(f.id)) continue;
        const crossed = w.dir < 0 ? prev >= f.x && w.x < f.x : prev <= f.x && w.x > f.x;
        if (!crossed) continue;
        if (f.y >= h.feetMin && f.y <= h.feetMax) continue;
        this.struck.add(f.id);
        bump(f, w.dir * C.bumpVx, C.bumpVy);
        f.percent = Math.min(999, f.percent + 15);
      }
      // Il muro è uscito dall'altra parte: un punto a chi è ancora in piedi e non l'ha preso
      if ((w.dir < 0 && w.x < LEFT - 80) || (w.dir > 0 && w.x > RIGHT + 80)) {
        for (const f of fighters) if (!f.respawning && !f.eliminated && !this.struck.has(f.id)) this.scores[f.id] = (this.scores[f.id] ?? 0) + 1;
        this.wall = null;
        this.count++;
        this.nextMs = Math.max(1500, C.everyMs - this.count * 150);
        this.text = null;
      }
    }
    this.props = [];
    if (w && this.wall) {
      const h = HOLES[w.hole];
      const x = Math.round(w.x);
      // Due blocchi: sopra e sotto il buco
      this.props.push({ kind: "wall", x, y: Math.round((40 + h.top) / 2), w: 36, h: Math.round(h.top - 40), color: 0xd86a4a });
      if (h.bottom < FLOOR) this.props.push({ kind: "wall", x, y: Math.round((h.bottom + FLOOR) / 2), w: 36, h: Math.round(FLOOR - h.bottom), color: 0xd86a4a });
    }
  }

  // Il bot va dove serve per il prossimo buco: a terra, sulla piattaforma di mezzo più vicina o in cima
  botGoal(f: Fighter) {
    const hole = this.wall?.hole ?? "basso";
    if (hole === "basso") return { x: f.x < 640 ? 400 : 880, y: FLOOR };
    if (hole === "medio") return { x: f.x < 640 ? 330 : 950, y: MID };
    return { x: 640, y: TOP };
  }
}

export const muro: MinigameDef = {
  info: {
    id: "muro",
    title: "Il Muro",
    category: "puzzle",
    howTo: "Arriva un muro con un buco: in basso resta a terra, in mezzo sali sulle piattaforme, in alto vai in cima. Chi non è all'altezza giusta vola via. Ogni muro superato vale un punto.",
    keys: "Muoviti e salta per metterti all'altezza del buco; spingi gli altri fuori posto",
    durationSec: C.durationMs / 1000,
  },
  build(seed) {
    return {
      stage: arena({
        id: "muro",
        name: "Il Muro",
        solids: [{ x: LEFT, y: FLOOR, width: RIGHT - LEFT, height: 80 }],
        platforms: [
          { x: 200, y: MID, width: 260 },
          { x: 820, y: MID, width: 260 },
          { x: 540, y: TOP, width: 200 },
        ],
        sky: 0x2a2440,
        solid: 0x4a3a5a,
        edge: 0xff8a5a,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Muro(seed),
    };
  },
};
