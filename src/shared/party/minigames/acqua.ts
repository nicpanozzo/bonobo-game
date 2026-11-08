// Acqua Alta (Platform): l'acqua sale piano piano e chi ci finisce dentro è fuori. Si sale sulle piattaforme, sempre
// più in alto e sempre più strette, spingendo giù gli altri. Una vita sola: vince l'ultimo all'asciutto, gli altri in
// ordine di caduta. Se a tempo scaduto sono ancora in tanti, è pari merito.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { StageSpec } from "../../stages";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.acqua;

// Dove arriva l'acqua dopo ms dal VIA
export function waterLevel(ms: number): number {
  const k = Math.max(0, Math.min(1, (ms - C.holdMs) / C.riseMs));
  return C.startY - (C.startY - C.topY) * k;
}

class Acqua extends TimedGame {
  private fallen: string[] = [];
  private elapsed = 0;

  constructor(private stage: StageSpec) {
    super(C.durationMs, "posto");
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    this.elapsed += dtMs;
    const water = waterLevel(this.elapsed);
    for (const e of events) if (e.type === "ko" && e.stocksLeft <= 0 && !this.fallen.includes(e.id)) this.fallen.push(e.id);
    // Chi tocca l'acqua affonda: lo si porta sotto il fondo e la partita lo conta fuori come una caduta
    for (const f of fighters) {
      if (f.respawning || f.eliminated || f.y < water + 6) continue;
      f.y = this.stage.blastZone.bottom + 50;
      f.vy = 0;
    }
    const alive = fighters.filter((f) => !f.eliminated);
    for (const f of fighters) this.scores[f.id] = f.eliminated ? this.fallen.indexOf(f.id) + 1 : fighters.length;
    this.out = new Set(this.fallen);
    if (fighters.length > 1 && alive.length <= 1) this.leftMs = 0;
    if (alive.length === 1 && fighters.length > 1) this.text = `${alive[0].name} resta all'asciutto!`;
    else if (this.elapsed < C.holdMs) this.text = "L'acqua sta salendo!";
    else this.text = null;
    this.props = [{ kind: "zone", x: 640, y: Math.round(this.stage.blastZone.bottom), w: 1800, h: Math.round(this.stage.blastZone.bottom - water), color: 0x3a8ad8 }];
  }

  // Il bot va sulla piattaforma più alta che l'acqua non ha ancora preso, la più vicina tra quelle alla stessa altezza
  botGoal(f: Fighter) {
    const water = waterLevel(this.elapsed);
    const dry = this.stage.platforms.filter((p) => p.y < water - 60);
    if (dry.length === 0) return null;
    // Una fila più su di dove si trova (o la più alta se è già in cima)
    const above = dry.filter((p) => p.y < f.y - 20).sort((a, b) => b.y - a.y || Math.abs(a.x + a.width / 2 - f.x) - Math.abs(b.x + b.width / 2 - f.x));
    const target = water < f.y + 160 && above.length > 0 ? above[0] : null;
    return target ? { x: target.x + target.width / 2, y: target.y } : null;
  }
}

function field(seed: number): StageSpec {
  const r = rng(seed);
  // File di piattaforme sempre più strette verso l'alto, spostate un po' a caso
  const rows = [
    { y: 560, n: 4, w: 190 },
    { y: 460, n: 3, w: 170 },
    { y: 360, n: 3, w: 150 },
    { y: 260, n: 2, w: 130 },
    { y: 170, n: 1, w: 140 },
  ];
  const platforms = rows.flatMap((row) =>
    Array.from({ length: row.n }, (_, i) => {
      const span = 900 / row.n;
      const x = Math.round(190 + span * i + (span - row.w) / 2 + (r.next() - 0.5) * 60);
      return { x, y: row.y, width: row.w };
    }),
  );
  return arena({
    id: "acqua",
    name: "Acqua Alta",
    // Il fondo è sotto il livello di partenza dell'acqua: ci si sta solo all'inizio
    solids: [{ x: 160, y: 650, width: 960, height: 60 }],
    platforms,
    spawns: [
      { x: 330, y: 650 },
      { x: 950, y: 650 },
      { x: 540, y: 650 },
      { x: 740, y: 650 },
      { x: 250, y: 650 },
      { x: 1030, y: 650 },
      { x: 450, y: 650 },
      { x: 830, y: 650 },
    ],
    respawn: { x: 640, y: 120 },
    sky: 0x2a3f5a,
    solid: 0x3f4a55,
    edge: 0x8ad0ff,
    platform: 0xb0c8d8,
  });
}

export const acqua: MinigameDef = {
  info: {
    id: "acqua",
    title: "Acqua Alta",
    category: "platform",
    howTo: "L'acqua sale e chi ci finisce dentro è fuori: arrampicati sulle piattaforme, sempre più su. Una vita sola, vince l'ultimo all'asciutto.",
    keys: "Muoviti e salta verso l'alto; colpisci per buttare giù gli altri",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(seed) {
    const stage = field(seed);
    return { stage, rules: { mode: "ffa", stocks: 1 }, unlimitedStocks: false, runtime: new Acqua(stage) };
  },
};
