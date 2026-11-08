// Un Solo Tasto (Idee pazze): a ognuno resta, a sorte, un solo tasto d'azione oltre al movimento: solo Salto, solo
// Leggero, solo Pesante, solo Speciale o solo Scudo. Il resto non risponde. Una zuffa normale: un punto a KO.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent, InputState } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.unTasto;
const ACTIONS = ["jump", "light", "heavy", "special", "shield"] as const;
type Action = (typeof ACTIONS)[number];
const NAMES: Record<Action, string> = { jump: "Solo Salto", light: "Solo Leggero", heavy: "Solo Pesante", special: "Solo Speciale", shield: "Solo Scudo" };

// I tasti d'azione che si possono togliere; il movimento resta a tutti
const ACTION_KEYS = ["jump", "light", "heavy", "special", "shield", "dodge", "supreme", "taunt"] as const;

export function keepOnly(input: InputState, action: Action): InputState {
  const out = { ...input };
  for (const k of ACTION_KEYS) if (k !== action) out[k] = false;
  // Senza salto si sale lo stesso con su? No: su resta per le direzioni degli attacchi, il salto è solo il tasto salto
  return out;
}

class UnTasto extends TimedGame {
  constructor(private keys: Record<string, Action>) {
    super(C.durationMs, "KO");
  }

  mapInput(id: string, input: InputState): InputState {
    const action = this.keys[id];
    return action ? keepOnly(input, action) : input;
  }

  protected onStep(_fighters: Fighter[], _ctx: PhysicsContext, _dtMs: number, events: readonly GameEvent[]) {
    for (const e of events) if (e.type === "ko" && e.byId && e.byId !== e.id) this.scores[e.byId] = (this.scores[e.byId] ?? 0) + C.koPoints;
  }
}

export const untasto: MinigameDef = {
  info: {
    id: "untasto",
    title: "Un Solo Tasto",
    category: "pazze",
    howTo: "A ognuno resta un solo tasto a sorte (solo Salto, solo Pesante, solo Speciale...), più il movimento. Arrangiati e butta fuori gli altri: un punto a KO.",
    keys: "Il movimento e il tuo unico tasto (lo vedi sotto)",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(seed, ids) {
    const r = rng(seed);
    // Tasti diversi finché ce ne sono, poi a caso
    const pool = [...ACTIONS].sort(() => r.next() - 0.5);
    const keys: Record<string, Action> = Object.fromEntries(ids.map((id, i) => [id, pool[i % pool.length]]));
    return {
      stage: arena({
        id: "untasto",
        name: "Un Solo Tasto",
        solids: [{ x: 240, y: 560, width: 800, height: 90 }],
        platforms: [
          { x: 320, y: 430, width: 170 },
          { x: 790, y: 430, width: 170 },
        ],
        sky: 0x2a3a2a,
        solid: 0x4a5a3a,
        edge: 0xffc928,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      roles: Object.fromEntries(ids.map((id) => [id, NAMES[keys[id]]])),
      runtime: new UnTasto(keys),
    };
  },
};
