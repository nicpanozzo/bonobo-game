// Casse al Posto Giusto (Puzzle): due squadre, ognuna con la sua porta a un capo del magazzino. Le casse stanno in mezzo:
// si spingono a colpi verso la propria porta (il pesante le manda più lontano). Ogni cassa portata vale un punto a tutta
// la squadra, e ne cade una nuova in mezzo. Ci si può picchiare per difendere la porta.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.casse;
const FLOOR = 580;
const LEFT = 120;
const RIGHT = 1160;
const TEAM_COLORS = [0xff4560, 0x5ec8ff];

interface Crate {
  x: number;
  y: number;
  vx: number;
  vy: number;
  hitMs: number;
}

class Casse extends TimedGame {
  private crates: Crate[] = [];

  constructor(private team: Record<string, 0 | 1>) {
    super(C.durationMs, "casse");
  }

  protected onStart() {
    for (let i = 0; i < C.crates; i++) this.crates.push(this.fresh((i - (C.crates - 1) / 2) * 90));
  }

  private fresh(dx = 0): Crate {
    return { x: 640 + dx, y: 120, vx: 0, vy: 0, hitMs: 0 };
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, _events: readonly GameEvent[]) {
    const dt = dtMs / 1000;
    const half = C.size / 2;
    for (const c of this.crates) {
      c.hitMs = Math.max(0, c.hitMs - dtMs);
      for (const f of fighters) {
        if (!f.attackActive || !f.attack || c.hitMs > 0 || f.respawning) continue;
        const dx = c.x - f.x;
        if (Math.abs(dx) > C.reachPx + half || Math.abs(c.y - half - (f.y - 40)) > 70 || (Math.abs(dx) > 20 && Math.sign(dx) !== f.facing)) continue;
        const strong = f.attack.startsWith("heavy") || f.attack === "dashAttack";
        c.vx = f.facing * C.pushVx * (strong ? 1.5 : 1);
        c.vy = C.pushVy;
        c.hitMs = 200;
      }
      c.vy += MINIGAME.fallGravity * dt;
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      if (c.y >= FLOOR) {
        c.y = FLOOR;
        c.vy = 0;
        c.vx *= Math.max(0, 1 - C.friction * dt); // sul pavimento si frena
        if (Math.abs(c.vx) < 8) c.vx = 0;
      }
      // I muri del magazzino fermano le casse
      if (c.x < LEFT + half) [c.x, c.vx] = [LEFT + half, 0];
      if (c.x > RIGHT - half) [c.x, c.vx] = [RIGHT - half, 0];
    }
    // Una cassa ferma dentro una porta: punto a quella squadra, e ne cade una nuova in mezzo
    this.crates = this.crates.map((c) => {
      const side = c.y >= FLOOR && Math.abs(c.vx) < 40 ? (c.x < LEFT + C.goalW ? 0 : c.x > RIGHT - C.goalW ? 1 : -1) : -1;
      if (side < 0) return c;
      const members = fighters.filter((f) => this.team[f.id] === side);
      for (const f of members) this.scores[f.id] = (this.scores[f.id] ?? 0) + 1;
      this.text = `Cassa alla squadra ${side === 0 ? "rossa" : "blu"}!`;
      return this.fresh();
    });
    this.props = [
      { kind: "zone", x: LEFT + C.goalW / 2, y: FLOOR, w: C.goalW, h: 18, color: TEAM_COLORS[0] },
      { kind: "zone", x: RIGHT - C.goalW / 2, y: FLOOR, w: C.goalW, h: 18, color: TEAM_COLORS[1] },
      ...this.crates.map((c) => ({ kind: "crate", x: Math.round(c.x), y: Math.round(c.y - half), w: C.size, h: C.size, color: 0xc08a4a })),
    ];
  }

  // Il bot va dietro la cassa più vicina (dalla parte opposta alla sua porta) e la colpisce verso casa
  botGoal(f: Fighter) {
    const side = this.team[f.id] ?? 0;
    const home = side === 0 ? -1 : 1;
    const c = this.crates.reduce<Crate | null>((best, x) => (!best || Math.abs(x.x - f.x) < Math.abs(best.x - f.x) ? x : best), null);
    if (!c) return null;
    return { x: c.x - home * (C.size / 2 + 30), y: FLOOR };
  }

  botInput(f: Fighter) {
    const side = this.team[f.id] ?? 0;
    const home = side === 0 ? -1 : 1;
    const c = this.crates.find((x) => Math.abs(x.x - f.x) < C.reachPx + C.size / 2 && Math.sign(x.x - f.x) === home && x.hitMs <= 0);
    if (!c || f.attack || !f.onGround) return null;
    if (f.facing !== home) return { left: home < 0, right: home > 0, up: false, jump: false, down: false, light: false, heavy: false, taunt: false, dodge: false, shield: false, special: false, supreme: false };
    return { left: false, right: false, up: false, jump: false, down: false, light: false, heavy: true, taunt: false, dodge: false, shield: false, special: false, supreme: false };
  }
}

export const casse: MinigameDef = {
  info: {
    id: "casse",
    title: "Casse al Posto Giusto",
    category: "puzzle",
    howTo: "Due squadre: spingi le casse a colpi nella porta della tua squadra, dal tuo lato. Il pesante le manda più lontano. Ogni cassa portata vale un punto a tutta la squadra.",
    keys: "Colpisci le casse verso la tua porta; picchia gli altri per difenderla",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(_seed, ids) {
    const team: Record<string, 0 | 1> = Object.fromEntries(ids.map((id, i) => [id, (i % 2) as 0 | 1]));
    const roles = Object.fromEntries(ids.map((id) => [id, team[id] === 0 ? "Squadra rossa, porta a sinistra" : "Squadra blu, porta a destra"]));
    return {
      stage: arena({
        id: "casse",
        name: "Il Magazzino",
        solids: [{ x: LEFT, y: FLOOR, width: RIGHT - LEFT, height: 90 }],
        platforms: [
          { x: 420, y: 440, width: 160 },
          { x: 700, y: 440, width: 160 },
        ],
        spawns: Array.from({ length: Math.max(8, ids.length) }, (_, i) => ({ x: i % 2 === 0 ? 420 - Math.floor(i / 2) * 60 : 860 + Math.floor(i / 2) * 60, y: FLOOR })),
        sky: 0x3a3028,
        solid: 0x5a4a3a,
        edge: 0xd8a860,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      roles,
      runtime: new Casse(team),
    };
  },
};
