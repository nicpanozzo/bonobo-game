// Pioggia di Banane (Arraffa): dal cielo piovono banane, ogni tanto una d'oro che ne vale di più. Si raccolgono
// passandoci sopra; chi viene colpito ne perde metà, che schizzano via e le prende chi è più svelto.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent } from "../../types";
import { arena, surfaceBelow } from "../arena";
import { TimedGame, touches, type MinigameDef } from "../minigame";

const C = MINIGAME.pioggia;

interface Banana {
  x: number;
  y: number;
  vx: number;
  vy: number;
  value: number;
  landed: boolean;
}

class Pioggia extends TimedGame {
  private bananas: Banana[] = [];
  private spawnMs = 0;
  private count = 0;
  private random: () => number;

  constructor(seed: number) {
    super(C.durationMs, "banane");
    this.random = rng(seed).next;
  }

  protected onStep(fighters: Fighter[], ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    const stage = ctx.stage;
    const ground = stage.solids[0];
    // Ne cade una ogni tanto, sopra il palco, finché non ce ne sono troppe
    this.spawnMs -= dtMs;
    if (this.spawnMs <= 0 && this.bananas.length < C.maxOnStage) {
      this.spawnMs = C.everyMs;
      this.count++;
      const gold = this.count % C.goldEvery === 0;
      this.bananas.push({ x: ground.x + 30 + this.random() * (ground.width - 60), y: -40, vx: 0, vy: 0, value: gold ? C.goldValue : 1, landed: false });
    }
    // Chi viene colpito perde metà delle banane: schizzano via dal punto del colpo
    for (const e of events) {
      if (e.type !== "hit") continue;
      const lost = Math.min(C.maxDrop, Math.floor((this.scores[e.targetId] ?? 0) * C.dropOnHit));
      if (lost <= 0) continue;
      this.scores[e.targetId] -= lost;
      for (let i = 0; i < lost; i++) this.bananas.push({ x: e.x, y: e.y - 20, vx: (this.random() - 0.5) * 520, vy: -420 - this.random() * 260, value: 1, landed: false });
    }
    // Cadono finché toccano qualcosa; se cadono nel vuoto si perdono
    const dt = dtMs / 1000;
    for (const b of this.bananas) {
      if (b.landed) continue;
      b.vy += MINIGAME.fallGravity * dt;
      const nx = b.x + b.vx * dt;
      const ny = b.y + b.vy * dt;
      const surface = b.vy > 0 ? surfaceBelow(stage, nx, b.y) : null;
      if (surface !== null && ny >= surface) {
        b.x = nx;
        b.y = surface;
        b.landed = true;
      } else {
        b.x = nx;
        b.y = ny;
      }
    }
    this.bananas = this.bananas.filter((b) => b.y < stage.blastZone.bottom);
    // Si raccolgono toccandole (anche in volo)
    for (const f of fighters) {
      this.bananas = this.bananas.filter((b) => {
        if (!touches(f, b.x, b.y - 12, C.pickRadius)) return true;
        this.scores[f.id] = (this.scores[f.id] ?? 0) + b.value;
        return false;
      });
    }
    this.props = this.bananas.map((b) => ({ kind: "banana", x: Math.round(b.x), y: Math.round(b.y), ...(b.value > 1 && { color: 0xffd700, w: b.value }) }));
  }

  // La banana a terra più vicina (le d'oro valgono il triplo, quindi contano come più vicine)
  botGoal(f: Fighter) {
    let best: Banana | null = null;
    let bestD = Infinity;
    for (const b of this.bananas) {
      const d = (Math.abs(b.x - f.x) + Math.abs(b.y - f.y)) / b.value;
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best ? { x: best.x, y: best.y } : null;
  }
}

export const pioggia: MinigameDef = {
  info: {
    id: "pioggia",
    title: "Pioggia di Banane",
    category: "arraffa",
    howTo: "Piovono banane: prendile passandoci sopra. Quelle d'oro valgono 3. Chi viene colpito ne perde metà!",
    keys: "Muoviti e salta per raccogliere, colpisci per farle cadere agli altri",
    durationSec: C.durationMs / 1000,
  },
  build(seed) {
    return {
      stage: arena({
        id: "pioggia",
        name: "Pioggia di Banane",
        solids: [{ x: 160, y: 580, width: 960, height: 80 }],
        platforms: [
          { x: 260, y: 440, width: 200 },
          { x: 820, y: 440, width: 200 },
          { x: 540, y: 320, width: 200 },
        ],
        sky: 0x3a6ea5,
        edge: 0xffd84a,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Pioggia(seed),
    };
  },
};
