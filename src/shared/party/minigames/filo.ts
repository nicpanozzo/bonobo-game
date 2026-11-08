// Il Filo (Classici riadattati: le moto di luce, solo la meccanica). Ognuno si lascia dietro un filo di micelio, come
// quello di Dr. Micelium: il proprio non fa niente, quello degli altri butta fuori chi lo tocca. Il filo si allunga
// finché si corre e sparisce dalla coda dopo un po'. Una vita sola: vince l'ultimo che non l'ha toccato.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import type { StageSpec } from "../../stages";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.filo;

interface Knot {
  x: number;
  y: number;
  at: number; // ms dal VIA
}

// Distanza tra il punto p e il segmento ab
function segDist(px: number, py: number, a: Knot, b: Knot): number {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len = dx * dx + dy * dy;
  const t = len === 0 ? 0 : Math.max(0, Math.min(1, ((px - a.x) * dx + (py - a.y) * dy) / len));
  return Math.hypot(px - (a.x + t * dx), py - (a.y + t * dy));
}

class Filo extends TimedGame {
  private trails = new Map<string, Knot[]>();
  private fallen: string[] = [];
  private elapsed = 0;

  constructor(private stage: StageSpec) {
    super(C.durationMs, "posto");
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    this.elapsed += dtMs;
    for (const e of events) if (e.type === "ko" && e.stocksLeft <= 0 && !this.fallen.includes(e.id)) this.fallen.push(e.id);
    for (const f of fighters) {
      const trail = this.trails.get(f.id) ?? [];
      this.trails.set(f.id, trail);
      // La coda sparisce col tempo; chi è fuori perde tutto il filo
      while (trail.length > 0 && (this.elapsed - trail[0].at > C.lifeMs || trail.length > C.maxPoints)) trail.shift();
      if (f.eliminated) trail.length = 0;
      if (f.respawning || f.eliminated) continue;
      // Il filo esce dai fianchi (a mezza altezza): si scavalca saltando
      const knot = { x: Math.round(f.x), y: Math.round(f.y - 24), at: this.elapsed };
      const last = trail[trail.length - 1];
      if (!last || Math.hypot(knot.x - last.x, knot.y - last.y) >= C.stepPx) trail.push(knot);
    }
    // Chi tocca il filo di un altro (all'inizio c'è un attimo di tregua) va giù
    if (this.elapsed > C.graceMs) {
      for (const f of fighters) {
        if (f.respawning || f.eliminated) continue;
        const hit = [...this.trails].some(([id, trail]) => id !== f.id && trail.some((k, i) => i > 0 && segDist(f.x, f.y - 24, trail[i - 1], k) < C.hitPx));
        if (hit) {
          f.y = this.stage.blastZone.bottom + 50;
          f.vy = 0;
        }
      }
    }
    const alive = fighters.filter((f) => !f.eliminated);
    for (const f of fighters) this.scores[f.id] = f.eliminated ? this.fallen.indexOf(f.id) + 1 : fighters.length;
    this.out = new Set(this.fallen);
    if (fighters.length > 1 && alive.length <= 1) this.leftMs = 0;
    this.text = alive.length === 1 && fighters.length > 1 ? `${alive[0].name} resta in gara!` : this.elapsed < C.graceMs ? "Pronti... il filo parte!" : null;
    this.props = fighters
      .filter((f) => (this.trails.get(f.id)?.length ?? 0) > 1)
      .map((f) => ({ kind: "trail", x: 0, y: 0, color: f.color, owner: f.id, pts: this.trails.get(f.id)!.flatMap((k) => [k.x, k.y]) }));
  }

  // Il bot corre verso il lato dove ci sono meno fili degli altri, saltando quando ne ha uno davanti
  botGoal(f: Fighter) {
    const foreign = [...this.trails].filter(([id]) => id !== f.id).flatMap(([, t]) => t);
    const ahead = foreign.some((k) => Math.sign(k.x - f.x) === f.facing && Math.abs(k.x - f.x) < 90 && Math.abs(k.y - (f.y - 24)) < 40);
    const leftCount = foreign.filter((k) => k.x < f.x).length;
    const rightCount = foreign.length - leftCount;
    const x = leftCount < rightCount ? 200 : 1080;
    return { x, y: ahead ? f.y - 200 : f.y };
  }
}

export const filo: MinigameDef = {
  info: {
    id: "filo",
    title: "Il Filo",
    category: "classici",
    howTo: "Correndo lasci un filo di micelio: il tuo non ti fa niente, quello degli altri ti butta fuori. Saltalo, chiudi la strada agli altri. Vince l'ultimo in gara.",
    keys: "Muoviti e salta per scavalcare i fili; colpisci per spingere gli altri contro i fili",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build() {
    const stage = arena({
      id: "filo",
      name: "Il Filo",
      solids: [{ x: 140, y: 580, width: 1000, height: 80 }],
      platforms: [
        { x: 240, y: 450, width: 220 },
        { x: 820, y: 450, width: 220 },
        { x: 530, y: 330, width: 220 },
      ],
      sky: 0x1a1430,
      solid: 0x2c2440,
      edge: 0xb48cff,
      platform: 0x6a5a8a,
    });
    return { stage, rules: { mode: "ffa", stocks: 1 }, unlimitedStocks: false, runtime: new Filo(stage) };
  },
};
