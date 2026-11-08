// La Sfida (Uno contro uno): non si pesca, la lancia una carta Evento del tabellone. Due giocatori, una vita sola,
// tutti e due già un po' ammaccati così si chiude in fretta. Chi resta in piedi vince e prende banane all'altro;
// allo scadere vince chi ha meno danni.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, placesFromScores, type MinigameDef } from "../minigame";

const C = MINIGAME.sfida;

class Sfida extends TimedGame {
  private fallen: string[] = [];
  private percent: Record<string, number> = {};

  constructor() {
    super(C.durationMs, "%");
  }

  protected onStart(fighters: Fighter[]) {
    for (const f of fighters) f.percent = C.startPercent;
    this.text = "Sfida!";
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, _dtMs: number, events: readonly GameEvent[]) {
    for (const e of events) if (e.type === "ko" && e.stocksLeft <= 0 && !this.fallen.includes(e.id)) this.fallen.push(e.id);
    const alive = fighters.filter((f) => !f.eliminated);
    for (const f of fighters) {
      if (!f.eliminated) this.percent[f.id] = Math.round(f.percent);
      this.scores[f.id] = this.percent[f.id] ?? 0;
    }
    this.out = new Set(this.fallen);
    // Senza avversario (l'altro è uscito) o con uno solo in piedi è finita
    if (alive.length <= 1) this.leftMs = 0;
    if (alive.length === 1 && fighters.length > 1) this.text = `${alive[0].name} vince la sfida!`;
    else if (this.leftMs < C.durationMs - 1500) this.text = null;
  }

  // Chi è in piedi davanti a chi è caduto; tra chi è in piedi (tempo scaduto) meno danni è meglio
  places(ids: string[]): Record<string, number> {
    const standing = ids.filter((id) => !this.fallen.includes(id));
    const places = placesFromScores(standing, this.percent, true);
    // I caduti dopo, l'ultimo a cadere prima dei precedenti
    [...this.fallen].reverse().forEach((id, i) => {
      if (ids.includes(id)) places[id] = standing.length + i + 1;
    });
    return places;
  }
}

export const sfida: MinigameDef = {
  info: {
    id: "sfida",
    title: "La Sfida",
    category: "unoContro",
    howTo: "Una carta vi ha messo uno contro l'altro: una vita sola e si parte già ammaccati. Chi resta sul palco prende banane all'altro!",
    keys: "Le mosse di sempre",
    durationSec: C.durationMs / 1000,
  },
  duelOnly: true,
  build() {
    return {
      stage: arena({
        id: "sfida",
        name: "La Sfida",
        solids: [{ x: 300, y: 560, width: 680, height: 90 }],
        platforms: [
          { x: 380, y: 420, width: 160 },
          { x: 740, y: 420, width: 160 },
        ],
        spawns: [
          { x: 460, y: 560 },
          { x: 820, y: 560 },
          { x: 360, y: 560 },
          { x: 920, y: 560 },
        ],
        sky: 0x2a1a3a,
        solid: 0x5a4a5a,
        edge: 0xff4560,
      }),
      rules: { mode: "ffa", stocks: 1 },
      unlimitedStocks: false,
      runtime: new Sfida(),
    };
  },
};
