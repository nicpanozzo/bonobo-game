// Il Bancomat Rotto (Arraffa): in mezzo al palco c'è un bancomat guasto che sputa monete solo se lo prendi a colpi
// pesanti. Le monete volano lontano, a destra e a sinistra, e le prende chiunque ci passa sopra: chi picchia la
// macchina rischia di lavorare per gli altri. Ogni tanto il jackpot. Chi esce dal palco perde qualche moneta.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent, InputState } from "../../types";
import { emptyInput } from "../../physics";
import { arena, surfaceBelow } from "../arena";
import { TimedGame, touches, type MinigameDef } from "../minigame";

const C = MINIGAME.bancomat;
const MACHINE = { x: 640, y: 580, w: 76, h: 120 }; // x al centro, y = la base sul pavimento

interface Coin {
  x: number;
  y: number;
  vx: number;
  vy: number;
  landed: boolean;
}

class Bancomat extends TimedGame {
  private coins: Coin[] = [];
  private cooldownMs = 0;
  private hits = 0;
  private textMs = 0;
  private random: () => number;

  constructor(seed: number) {
    super(C.durationMs, "monete");
    this.random = rng(seed).next;
  }

  // Abbastanza vicino alla macchina e girato verso di lei
  private atMachine(f: Fighter) {
    const dx = MACHINE.x - f.x;
    return Math.abs(dx) < C.range && Math.abs(f.y - MACHINE.y) < MACHINE.h && (Math.abs(dx) < 40 || Math.sign(dx) === f.facing);
  }

  protected onStep(fighters: Fighter[], ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    const stage = ctx.stage;
    this.cooldownMs = Math.max(0, this.cooldownMs - dtMs);
    this.textMs = Math.max(0, this.textMs - dtMs);
    if (this.textMs <= 0) this.text = null;
    for (const e of events) {
      if (e.type === "attack" && e.kind.startsWith("heavy") && this.cooldownMs <= 0) {
        const f = fighters.find((x) => x.id === e.id);
        if (!f || !this.atMachine(f)) continue;
        this.cooldownMs = C.cooldownMs;
        this.hits++;
        const jackpot = this.hits % C.jackpotEvery === 0;
        this.spit(jackpot ? C.jackpotCoins : C.coinsPerHit);
        if (jackpot) {
          this.text = "JACKPOT!";
          this.textMs = 1500;
        }
      }
      // Chi esce dal palco perde qualche moneta (e qualcosa da raccogliere torna alla macchina)
      if (e.type === "ko") {
        const lost = Math.min(C.lostOnKo, this.scores[e.id] ?? 0);
        if (lost > 0) {
          this.scores[e.id] -= lost;
          this.spit(lost);
        }
      }
    }
    const dt = dtMs / 1000;
    for (const c of this.coins) {
      if (c.landed) continue;
      c.vy += MINIGAME.fallGravity * dt;
      const nx = c.x + c.vx * dt;
      const ny = c.y + c.vy * dt;
      const surface = c.vy > 0 ? surfaceBelow(stage, nx, c.y) : null;
      if (surface !== null && ny >= surface) {
        c.x = nx;
        c.y = surface;
        c.landed = true;
      } else {
        c.x = nx;
        c.y = ny;
      }
    }
    this.coins = this.coins.filter((c) => c.y < stage.blastZone.bottom);
    for (const f of fighters) {
      this.coins = this.coins.filter((c) => {
        if (!touches(f, c.x, c.y - 10, C.pickRadius)) return true;
        this.scores[f.id] = (this.scores[f.id] ?? 0) + 1;
        return false;
      });
    }
    // La macchina: una cassa scura con lo schermo che si accende quando è pronta
    this.props = [
      { kind: "crate", x: MACHINE.x, y: MACHINE.y - MACHINE.h / 2, w: MACHINE.w, h: MACHINE.h, color: 0x4a5a6a },
      { kind: "crate", x: MACHINE.x, y: MACHINE.y - MACHINE.h + 30, w: 50, h: 26, color: this.cooldownMs > 0 ? 0x2a2f3a : 0x5ef0a0 },
      ...this.coins.map((c) => ({ kind: "coin", x: Math.round(c.x), y: Math.round(c.y - 10), color: 0xffd700 })),
    ];
  }

  // Le monete escono dalla fessura e volano lontano, metà a destra e metà a sinistra
  private spit(n: number) {
    for (let i = 0; i < n && this.coins.length < C.maxCoins; i++) {
      const dir = i % 2 === 0 ? 1 : -1;
      this.coins.push({ x: MACHINE.x + dir * 20, y: MACHINE.y - MACHINE.h + 40, vx: dir * (C.coinSpeed * (0.35 + 0.65 * this.random())), vy: -480 - this.random() * 380, landed: false });
    }
  }

  // Il bot picchia la macchina quando ci è davanti e pronta; altrimenti va verso la moneta più vicina o la macchina
  botInput(f: Fighter): InputState | null {
    if (this.cooldownMs > 0 || !this.atMachine(f) || !f.onGround || f.attack) return null;
    const near = this.coins.some((c) => c.landed && Math.abs(c.x - f.x) < 200);
    if (near) return null;
    return { ...emptyInput(), heavy: true };
  }

  botGoal(f: Fighter) {
    let best: Coin | null = null;
    let bestD = Infinity;
    for (const c of this.coins) {
      const d = Math.abs(c.x - f.x) + Math.abs(c.y - f.y);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    if (best && bestD < 500) return { x: best.x, y: best.y };
    // Davanti alla macchina, dalla parte dove già si trova
    return { x: MACHINE.x + (f.x < MACHINE.x ? -70 : 70), y: MACHINE.y };
  }
}

export const bancomat: MinigameDef = {
  info: {
    id: "bancomat",
    title: "Il Bancomat Rotto",
    category: "arraffa",
    howTo: "Il bancomat è guasto: prendilo a colpi pesanti e sputa monete lontano. Le prende chiunque ci passi sopra! Ogni tanto il jackpot.",
    keys: "Pesante davanti alla macchina; corri a raccogliere le monete",
    durationSec: C.durationMs / 1000,
  },
  build(seed) {
    return {
      stage: arena({
        id: "bancomat",
        name: "Il Bancomat Rotto",
        solids: [{ x: 120, y: MACHINE.y, width: 1040, height: 80 }],
        platforms: [
          { x: 200, y: 450, width: 200 },
          { x: 880, y: 450, width: 200 },
        ],
        spawns: [
          { x: 420, y: MACHINE.y },
          { x: 860, y: MACHINE.y },
          { x: 280, y: MACHINE.y },
          { x: 1000, y: MACHINE.y },
          { x: 500, y: MACHINE.y },
          { x: 780, y: MACHINE.y },
          { x: 200, y: MACHINE.y },
          { x: 1080, y: MACHINE.y },
        ],
        sky: 0x23324a,
        solid: 0x55504a,
        edge: 0xffd84a,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Bancomat(seed),
    };
  },
};
