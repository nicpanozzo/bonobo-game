// Sala Prove (Ritmo): la musica va a tempo e le piattaforme si accendono a ogni battito. Un colpo dato a tempo vale
// punti, fuori tempo niente; un KO a tempo vale di più. Picchiare a caso non serve: bisogna ascoltare.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.salaProve;
const BEAT = 60000 / C.bpm;
const PADS = [
  { x: 260, y: 440, width: 200 },
  { x: 820, y: 440, width: 200 },
  { x: 540, y: 320, width: 200 },
];

// Quanto manca o è passato dal battito più vicino, in ms (il tempo è quello dell'arena, come la musica del client)
export function offBeat(timeMs: number): number {
  const phase = ((timeMs % BEAT) + BEAT) % BEAT;
  return Math.min(phase, BEAT - phase);
}

class SalaProve extends TimedGame {
  private now = 0;
  constructor() {
    super(C.durationMs, "punti");
  }

  protected onStep(_fighters: Fighter[], ctx: PhysicsContext, _dtMs: number, events: readonly GameEvent[]) {
    const now = ctx.timeMs ?? 0;
    this.now = now;
    const onBeat = offBeat(now) <= C.windowMs;
    for (const e of events) {
      if (e.type === "hit" && e.attackerId !== e.targetId) this.scores[e.attackerId] = (this.scores[e.attackerId] ?? 0) + (onBeat ? C.beatPoints : C.offPoints);
      if (e.type === "ko" && e.byId && e.byId !== e.id && onBeat) this.scores[e.byId] = (this.scores[e.byId] ?? 0) + C.koPoints;
    }
    // Le piattaforme si accendono sul battito: il metronomo che si vede
    this.props = onBeat ? PADS.map((p) => ({ kind: "zone", x: p.x + p.width / 2, y: p.y, w: p.width, h: 16, color: 0xff8ad8 })) : [];
    this.text = onBeat ? "♪" : null;
  }

  // Il bot colpisce solo vicino al battito: aspetta col colpo fino al prossimo
  botInput(f: Fighter, fighters: readonly Fighter[]) {
    const foe = fighters.find((o) => o !== f && !o.respawning && Math.abs(o.x - f.x) < 110 && Math.abs(o.y - f.y) < 80);
    if (!foe || f.attack) return null;
    const strike = offBeat(this.now + 60) <= C.windowMs / 2; // un attimo prima: il colpo parte e arriva sul battito
    return { left: foe.x < f.x, right: foe.x > f.x, up: false, jump: false, down: false, light: strike, heavy: false, taunt: false, dodge: false, shield: false, special: false, supreme: false };
  }
}

export const salaprove: MinigameDef = {
  info: {
    id: "salaprove",
    title: "Sala Prove",
    category: "ritmo",
    howTo: "Le piattaforme si accendono a tempo con la musica: i colpi dati sul battito valgono 2 punti, quelli fuori tempo niente. Un KO a tempo ne vale 3.",
    keys: "Le mosse di sempre, ma a tempo",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build() {
    return {
      stage: arena({
        id: "salaprove",
        name: "Sala Prove",
        solids: [{ x: 200, y: 570, width: 880, height: 90 }],
        platforms: PADS,
        sky: 0x2a1a3a,
        solid: 0x3a2a4a,
        edge: 0xff8ad8,
        music: { bpm: C.bpm, chords: ["Am", "F", "C", "G"], lead: "square" },
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new SalaProve(),
    };
  },
};
