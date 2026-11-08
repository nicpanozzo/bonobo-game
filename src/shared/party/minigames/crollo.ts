// Le Torri Crollano (Platform): niente pavimento, solo piattaforme sospese che cadono una alla volta in un ordine a
// caso (prima traballano, con la crepa disegnata). Una vita sola: vince l'ultimo in piedi, gli altri in ordine di caduta.
// Le piattaforme sono pezzi a tempo (#433): la fisica e il client le tolgono da sole allo stesso istante.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { StageSpec } from "../../stages";
import type { GameEvent } from "../../types";
import { arena, GO_STAGE_MS } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.crollo;

class Crollo extends TimedGame {
  private fallen: string[] = []; // chi è caduto, in ordine

  constructor(private stage: StageSpec) {
    super(C.durationMs, "posto");
  }

  protected onStep(fighters: Fighter[], ctx: PhysicsContext, _dtMs: number, events: readonly GameEvent[]) {
    for (const e of events) if (e.type === "ko" && e.stocksLeft <= 0 && !this.fallen.includes(e.id)) this.fallen.push(e.id);
    const alive = fighters.filter((f) => !f.eliminated);
    for (const f of fighters) this.scores[f.id] = f.eliminated ? this.fallen.indexOf(f.id) + 1 : fighters.length;
    this.out = new Set(this.fallen);
    if (fighters.length > 1 && alive.length <= 1) this.leftMs = 0;
    // Le crepe sulle piattaforme che stanno per cadere
    const now = ctx.timeMs ?? 0;
    this.props = this.stage.platforms
      .filter((p) => p.on && p.on[0][1] > now && p.on[0][1] - now < C.warnMs)
      .map((p) => ({ kind: "crack", x: p.x + p.width / 2, y: p.y, w: p.width }));
    if (alive.length === 1 && fighters.length > 1) this.text = `${alive[0].name} resta in piedi!`;
  }

  // Più a lungo si è rimasti, meglio è: i punti sono già il posto rovesciato
  botGoal(f: Fighter, _fighters: readonly Fighter[]) {
    // Il bot va sulla piattaforma più lontana dal crollo: quella che cade per ultima
    const safe = [...this.stage.platforms].sort((a, b) => (b.on?.[0][1] ?? Infinity) - (a.on?.[0][1] ?? Infinity))[0];
    return safe ? { x: safe.x + safe.width / 2, y: safe.y } : { x: f.x, y: f.y };
  }
}

function field(seed: number): StageSpec {
  const r = rng(seed);
  // Tre file di quattro piattaforme
  const rows = [560, 430, 300];
  const cols = [190, 420, 650, 880];
  const pieces = rows.flatMap((y, row) => cols.map((x) => ({ x: x + (row % 2) * 40, y, width: 170 })));
  // L'ordine del crollo: a caso, tranne le ultime C.keep che restano fino alla fine
  const order = pieces.map((_, i) => i).sort(() => r.next() - 0.5);
  order.forEach((idx, k) => {
    if (k >= pieces.length - C.keep) return;
    const at = GO_STAGE_MS + C.firstFallMs + k * C.everyMs;
    (pieces[idx] as { on?: [number, number][] }).on = [[0, at]];
  });
  const stage = arena({
    id: "crollo",
    name: "Le Torri Crollano",
    // Un blocco piccolo e alto in mezzo da cui si parte, che cade per primo
    solids: [{ x: 560, y: 560, width: 160, height: 40, on: [[0, GO_STAGE_MS + C.firstFallMs - C.everyMs]] }],
    platforms: pieces,
    spawns: [
      { x: 275, y: 560 },
      { x: 1005, y: 560 },
      { x: 505, y: 430 },
      { x: 775, y: 430 },
      { x: 300, y: 300 },
      { x: 960, y: 300 },
      { x: 600, y: 560 },
      { x: 680, y: 560 },
    ],
    respawn: { x: 640, y: 200 },
    sky: 0x3b2f4a,
    solid: 0x6f6a78,
    edge: 0xc7b9d6,
    platform: 0xb7a9c9,
  });
  return stage;
}

export const crollo: MinigameDef = {
  info: {
    id: "crollo",
    title: "Le Torri Crollano",
    category: "platform",
    howTo: "Le piattaforme cadono una alla volta: quando vedi la crepa, salta via! Una vita sola, vince l'ultimo in piedi.",
    keys: "Muoviti e salta; colpisci per buttare giù gli altri",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(seed) {
    const stage = field(seed);
    return { stage, rules: { mode: "ffa", stocks: 1 }, unlimitedStocks: false, runtime: new Crollo(stage) };
  },
};
