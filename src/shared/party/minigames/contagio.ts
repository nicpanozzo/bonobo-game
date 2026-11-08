// Contagio (Uno contro tutti): uno parte coi funghetti e chi colpisce si contagia e passa con lui. I sani si
// possono solo difendere (colpiscono gli infetti per allontanarli). I sani fanno un punto al secondo, gli infetti
// due punti a contagio. Finisce a tempo, o quando sono tutti infetti.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.contagio;

class Contagio extends TimedGame {
  private infected = new Set<string>();
  private aliveMs = new Map<string, number>();

  constructor(private first: string) {
    super(C.durationMs, "punti");
  }

  protected onStart(fighters: Fighter[]) {
    const first = fighters.find((f) => f.id === this.first) ?? fighters[0];
    if (first) this.infect(first);
  }

  private infect(f: Fighter) {
    this.infected.add(f.id);
    f.color = C.infectedColor; // l'anello e il nome diventano verdi: si vede chi è infetto senza disegni nuovi
  }

  // Solo tra sani e infetti: i sani non si picchiano tra loro, gli infetti nemmeno
  canHit(a: Fighter, t: Fighter) {
    return this.infected.has(a.id) !== this.infected.has(t.id);
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    for (const e of events) {
      if (e.type !== "hit" || !this.infected.has(e.attackerId) || this.infected.has(e.targetId)) continue;
      const t = fighters.find((f) => f.id === e.targetId);
      if (!t) continue;
      this.infect(t);
      this.scores[e.attackerId] = (this.scores[e.attackerId] ?? 0) + C.infectPoints;
      this.text = `${t.name} è contagiato!`;
    }
    // Un punto per ogni secondo da sano
    for (const f of fighters) {
      if (this.infected.has(f.id)) continue;
      const ms = (this.aliveMs.get(f.id) ?? 0) + dtMs;
      this.aliveMs.set(f.id, ms % 1000);
      if (ms >= 1000) this.scores[f.id] = (this.scores[f.id] ?? 0) + Math.floor(ms / 1000);
    }
    this.out = new Set(this.infected);
    this.props = fighters.filter((f) => this.infected.has(f.id) && !f.respawning).map((f) => ({ kind: "marker", x: Math.round(f.x), y: Math.round(f.y - 120), color: C.infectedColor, text: "INFETTO" }));
  }

  done() {
    return super.done() || (this.started && this.scoresIds().length > 1 && this.scoresIds().every((id) => this.infected.has(id)));
  }

  private scoresIds() {
    return Object.keys(this.scores);
  }

  // I sani scappano dall'infetto più vicino; gli infetti inseguono (il bot normale lo fa già)
  botGoal(f: Fighter, fighters: readonly Fighter[]) {
    if (this.infected.has(f.id)) return null;
    const hunters = fighters.filter((o) => this.infected.has(o.id) && !o.respawning);
    if (hunters.length === 0) return null;
    const h = hunters.reduce((a, b) => (Math.abs(a.x - f.x) < Math.abs(b.x - f.x) ? a : b));
    const away = f.x >= h.x ? 1 : -1;
    return { x: Math.max(220, Math.min(1060, f.x + away * 300)), y: f.y - (Math.abs(h.x - f.x) < 120 ? 200 : 0) };
  }
}

export const contagio: MinigameDef = {
  info: {
    id: "contagio",
    title: "Contagio",
    category: "unoContro",
    howTo: "Uno ha mangiato i funghetti: chi viene colpito da lui si contagia e passa con gli infetti. I sani fanno un punto al secondo, gli infetti due a contagio.",
    keys: "Muoviti e salta per scappare, colpisci per contagiare o difenderti",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(seed, ids) {
    const first = ids[Math.floor(rng(seed).next() * ids.length)] ?? "";
    return {
      stage: arena({
        id: "contagio",
        name: "Contagio",
        solids: [{ x: 180, y: 570, width: 920, height: 80 }],
        platforms: [
          { x: 240, y: 440, width: 180 },
          { x: 860, y: 440, width: 180 },
          { x: 520, y: 400, width: 240 },
          { x: 380, y: 280, width: 160 },
          { x: 740, y: 280, width: 160 },
        ],
        sky: 0x2e3b2a,
        solid: 0x4b5a3a,
        edge: 0x9fd16a,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      roles: { [first]: "Infetto" },
      runtime: new Contagio(first),
    };
  },
};
