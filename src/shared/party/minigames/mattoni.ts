// Mattoni a Mazzate (Classici riadattati: la pallina e i mattoncini, solo la meccanica). In alto c'è un muro di mattoni,
// un po' per colore. Le palle rimbalzano per l'arena e prendono il colore di chi le ha colpite per ultimo: rompono solo i
// mattoni di quel colore. Si colpiscono con le mosse di sempre (in su per mandarle in alto). Chi finisce i suoi vince.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.mattoni;
const BOX = { left: 150, right: 1130, top: 40, floor: 580 };
const BRICK = { w: 58, h: 24, top: 70 };

interface Ball {
  x: number;
  y: number;
  vx: number;
  vy: number;
  owner: string | null;
  color: number;
  hitMs: number; // ms prima di poterla ricolpire
}

interface Brick {
  x: number;
  y: number;
  owner: string;
  color: number;
}

class Mattoni extends TimedGame {
  private balls: Ball[] = [];
  private bricks: Brick[] = [];
  private random: () => number;

  constructor(seed: number) {
    super(C.durationMs, "mattoni");
    this.random = rng(seed).next;
  }

  protected onStart(fighters: Fighter[]) {
    // Due file di mattoni, i colori mescolati: ognuno ha i suoi sparsi per il muro
    const ids = fighters.map((f) => f.id);
    const owners = ids.flatMap((id) => Array.from({ length: C.bricksEach }, () => id)).sort(() => this.random() - 0.5);
    const perRow = Math.ceil(owners.length / 2);
    const span = BOX.right - BOX.left - 40;
    owners.forEach((id, i) => {
      const row = Math.floor(i / perRow);
      const col = i % perRow;
      const color = fighters.find((f) => f.id === id)!.color;
      this.bricks.push({ x: Math.round(BOX.left + 20 + (span / perRow) * (col + 0.5)), y: BRICK.top + row * (BRICK.h + 10), owner: id, color });
    });
    for (let i = 0; i < C.balls; i++) this.balls.push({ x: 640 + (i - (C.balls - 1) / 2) * 220, y: 300, vx: (i % 2 ? 1 : -1) * C.speed * 0.4, vy: C.speed * 0.3, owner: null, color: 0xffffff, hitMs: 0 });
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number) {
    const dt = dtMs / 1000;
    for (const b of this.balls) {
      b.hitMs = Math.max(0, b.hitMs - dtMs);
      // Una mossa che colpisce mentre la palla è davanti la rilancia: in su con le mosse in su, in giù con quelle in giù
      for (const f of fighters) {
        if (!f.attackActive || !f.attack || b.hitMs > 0 || f.respawning) continue;
        const dx = b.x - f.x;
        const dy = b.y - (f.y - 45);
        if (Math.abs(dy) > C.reachPx || Math.abs(dx) > C.reachPx || (Math.abs(dx) > 30 && Math.sign(dx) !== f.facing)) continue;
        const up = f.attack.includes("Up") || f.attack.startsWith("throwUp");
        const down = f.attack.includes("Down");
        const strong = f.attack.startsWith("heavy") || f.attack === "dashAttack";
        const speed = strong ? C.maxSpeed : C.speed;
        const angle = up ? -75 : down ? 35 : -30;
        const rad = (angle * Math.PI) / 180;
        b.vx = f.facing * Math.cos(rad) * speed * (up ? 0.5 : 1);
        b.vy = Math.sin(rad) * speed;
        b.owner = f.id;
        b.color = f.color;
        b.hitMs = 220;
      }
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      // Le pareti della scatola rimbalzano; il pavimento la fa rimbalzare un po' più piano
      if (b.x < BOX.left + C.ballR) [b.x, b.vx] = [BOX.left + C.ballR, Math.abs(b.vx)];
      if (b.x > BOX.right - C.ballR) [b.x, b.vx] = [BOX.right - C.ballR, -Math.abs(b.vx)];
      if (b.y < BOX.top + C.ballR) [b.y, b.vy] = [BOX.top + C.ballR, Math.abs(b.vy)];
      if (b.y > BOX.floor - C.ballR) {
        b.y = BOX.floor - C.ballR;
        b.vy = -Math.max(C.speed * 0.6, Math.abs(b.vy) * 0.8);
      }
      // I mattoni: si rimbalza su tutti, si rompono solo quelli del colore della palla
      for (const k of this.bricks) {
        if (Math.abs(b.x - k.x) > BRICK.w / 2 + C.ballR || Math.abs(b.y - k.y) > BRICK.h / 2 + C.ballR) continue;
        const fromSide = Math.abs(b.x - k.x) / BRICK.w > Math.abs(b.y - k.y) / BRICK.h;
        if (fromSide) b.vx = Math.sign(b.x - k.x) * Math.abs(b.vx);
        else b.vy = Math.sign(b.y - k.y) * Math.abs(b.vy);
        if (b.owner === k.owner) {
          this.scores[k.owner] = (this.scores[k.owner] ?? 0) + 1;
          k.owner = ""; // rotto: si toglie qui sotto
        }
        break;
      }
      this.bricks = this.bricks.filter((k) => k.owner !== "");
    }
    // Chi ha rotto tutti i suoi vince subito
    const done = fighters.find((f) => (this.scores[f.id] ?? 0) >= C.bricksEach);
    if (done) {
      this.text = `${done.name} ha finito i suoi mattoni!`;
      this.leftMs = 0;
    }
    this.props = [
      ...this.bricks.map((k) => ({ kind: "brick", x: k.x, y: k.y, w: BRICK.w, h: BRICK.h, color: k.color })),
      ...this.balls.map((b) => ({ kind: "ball", x: Math.round(b.x), y: Math.round(b.y), w: C.ballR, color: b.color })),
    ];
  }

  // Il bot va sotto la palla più vicina che non è già sua, e la colpisce in su (lo fa da solo il bot quando è a tiro)
  botGoal(f: Fighter) {
    const target = this.balls.reduce<Ball | null>((best, b) => (!best || Math.abs(b.x - f.x) + (b.owner === f.id ? 400 : 0) < Math.abs(best.x - f.x) + (best.owner === f.id ? 400 : 0) ? b : best), null);
    return target ? { x: target.x - f.facing * 30, y: target.y > 380 ? target.y + 45 : f.y } : null;
  }

  botInput(f: Fighter) {
    const b = this.balls.find((x) => Math.abs(x.x - f.x) < C.reachPx && Math.abs(x.y - (f.y - 45)) < C.reachPx && x.owner !== f.id);
    if (!b || f.attack || b.hitMs > 0) return null;
    return { left: b.x < f.x, right: b.x > f.x, up: true, jump: false, down: false, light: true, heavy: false, taunt: false, dodge: false, shield: false, special: false, supreme: false };
  }
}

export const mattoni: MinigameDef = {
  info: {
    id: "mattoni",
    title: "Mattoni a Mazzate",
    category: "classici",
    howTo: "Colpisci le palle con le tue mosse: prendono il tuo colore e rompono solo i tuoi mattoni. In su le mandi in alto. Chi finisce i suoi mattoni vince!",
    keys: "Leggero e pesante sulla palla, con su per tirarla in alto",
    durationSec: C.durationMs / 1000,
  },
  build(seed) {
    return {
      stage: arena({
        id: "mattoni",
        name: "Mattoni a Mazzate",
        solids: [{ x: BOX.left, y: BOX.floor, width: BOX.right - BOX.left, height: 80 }],
        platforms: [
          { x: 300, y: 430, width: 180 },
          { x: 800, y: 430, width: 180 },
        ],
        sky: 0x14213d,
        solid: 0x2a3550,
        edge: 0x5ec8ff,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Mattoni(seed),
    };
  },
};
