// Attraversa la Strada (Classici riadattati: la rana che attraversa la strada, solo la meccanica). Tra i due marciapiedi
// ci sono le corsie di via Rizzoli: in ognuna passa un autobus ogni tanto, con un preavviso giallo. Chi è in corsia al
// passaggio viene sbalzato indietro. Ogni attraversamento completo vale un punto; poi si torna dall'altra parte.
// Si può saltare sopra l'autobus, e si possono spingere gli altri sotto.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { bump, TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.strada;
const GROUND = 580;
const LEFT = 280; // fine del marciapiede di sinistra
const RIGHT = 1000; // inizio del marciapiede di destra
const LANE_W = (RIGHT - LEFT) / C.lanes;
const BUS_H = 120; // chi è più in alto di così sopra la strada (in salto) passa sopra l'autobus

interface Lane {
  period: number;
  offset: number;
}

type LaneState = "free" | "warn" | "bus";

class Strada extends TimedGame {
  private elapsed = 0;
  private side = new Map<string, -1 | 1>(); // da che marciapiede è partito l'attraversamento in corso

  constructor(private lanes: Lane[]) {
    super(C.durationMs, "attraversamenti");
  }

  // Lo stato di una corsia fra ms
  state(i: number, ahead = 0): LaneState {
    const l = this.lanes[i];
    const t = (this.elapsed + ahead + l.offset) % l.period;
    if (t >= l.period - C.passMs) return "bus";
    if (t >= l.period - C.passMs - C.warnMs) return "warn";
    return "free";
  }

  private laneOf(x: number): number {
    return x <= LEFT || x >= RIGHT ? -1 : Math.min(C.lanes - 1, Math.floor((x - LEFT) / LANE_W));
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    this.elapsed += dtMs;
    // Chi cade riparte dal marciapiede di sinistra: l'attraversamento ricomincia da lì
    for (const e of events) if (e.type === "respawn") this.side.set(e.id, -1);
    for (const f of fighters) {
      if (f.respawning || f.eliminated) continue;
      if (!this.side.has(f.id)) this.side.set(f.id, f.x < 640 ? -1 : 1);
      const from = this.side.get(f.id)!;
      // Arrivato sul marciapiede opposto: un punto, e si riparte da lì
      if ((from === -1 && f.x >= RIGHT) || (from === 1 && f.x <= LEFT)) {
        this.scores[f.id] = (this.scores[f.id] ?? 0) + 1;
        this.side.set(f.id, (from * -1) as -1 | 1);
        this.text = `${f.name} è dall'altra parte!`;
      }
      // L'autobus: chi è in corsia e non sopra di lui torna indietro di volo, verso il marciapiede da cui è partito
      const lane = this.laneOf(f.x);
      if (lane >= 0 && this.state(lane) === "bus" && f.y > GROUND - BUS_H && f.hitstunTimer <= 0) bump(f, from * C.bumpVx, C.bumpVy);
    }
    this.props = [];
    for (let i = 0; i < C.lanes; i++) {
      const s = this.state(i);
      const cx = Math.round(LEFT + LANE_W * (i + 0.5));
      if (s === "warn") this.props.push({ kind: "zone", x: cx, y: GROUND, w: Math.round(LANE_W - 8), h: 14, color: 0xffc928 });
      else if (s === "bus") this.props.push({ kind: "bus", x: cx, y: GROUND - BUS_H / 2, w: Math.round(LANE_W - 10), h: BUS_H, color: 0xe4572e });
    }
  }

  // Il bot va verso il marciapiede opposto, ma si ferma prima di una corsia dove sta per passare l'autobus
  botGoal(f: Fighter) {
    const from = this.side.get(f.id) ?? -1;
    const target = from === -1 ? RIGHT + 60 : LEFT - 60;
    const lane = this.laneOf(f.x);
    const next = lane < 0 ? (from === -1 ? 0 : C.lanes - 1) : lane - from;
    if (next >= 0 && next < C.lanes && next !== lane) {
      const edge = from === -1 ? LEFT + LANE_W * next : LEFT + LANE_W * (next + 1);
      const close = Math.abs(edge - f.x) < 50;
      const danger = this.state(next) !== "free" || this.state(next, 600) !== "free";
      if (close && danger && (lane < 0 || this.state(lane) === "free")) return { x: f.x + from * 10, y: f.y };
    }
    return { x: target, y: GROUND };
  }
}

export const strada: MinigameDef = {
  info: {
    id: "strada",
    title: "Attraversa la Strada",
    category: "classici",
    howTo: "Attraversa via Rizzoli tra gli autobus: quando la corsia diventa gialla sta per passarne uno. Ogni attraversamento vale un punto, poi si torna indietro.",
    keys: "Muoviti (e corri); salta sopra gli autobus se sei svelto, colpisci per spingere gli altri",
    durationSec: C.durationMs / 1000,
  },
  build(seed) {
    const r = rng(seed);
    const lanes = Array.from({ length: C.lanes }, () => ({ period: Math.round(C.periodMinMs + r.next() * (C.periodMaxMs - C.periodMinMs)), offset: Math.round(r.next() * 4000) }));
    return {
      stage: arena({
        id: "strada",
        name: "Via Rizzoli",
        solids: [{ x: 80, y: GROUND, width: 1120, height: 100 }],
        spawns: [
          { x: 140, y: GROUND },
          { x: 200, y: GROUND },
          { x: 170, y: GROUND },
          { x: 230, y: GROUND },
          { x: 120, y: GROUND },
          { x: 250, y: GROUND },
          { x: 150, y: GROUND },
          { x: 215, y: GROUND },
        ],
        respawn: { x: 180, y: 300 },
        sky: 0x7aa6c9,
        solid: 0x3a3a40,
        edge: 0xd8d0c0,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Strada(lanes),
    };
  },
};
