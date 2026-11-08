// Lo Specchio (Idee pazze): ogni 10 secondi i comandi girano di un posto: guidi il lottatore di un altro, con le sue
// mosse, e un altro guida il tuo. Colpi e KO valgono per chi è al comando in quel momento, non per il lottatore.
// Sopra ogni lottatore c'è il nome di chi lo guida.

import { MINIGAME } from "../../constants";
import { emptyInput, type Fighter, type PhysicsContext } from "../../physics";
import type { GameEvent, InputState } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.specchio;

class Specchio extends TimedGame {
  private raw = new Map<string, InputState>(); // i tasti che ognuno sta premendo davvero
  private shift = 0; // di quanti posti sono girati i comandi
  private swapMs = C.swapMs;

  constructor(private order: string[]) {
    super(C.durationMs, "punti");
  }

  // Chi guida il lottatore id adesso
  driverOf(id: string): string {
    const n = this.order.length;
    const i = this.order.indexOf(id);
    if (i < 0 || n < 2) return id;
    return this.order[(i - this.shift + n * 10) % n];
  }

  mapInput(id: string, input: InputState): InputState {
    this.raw.set(id, input);
    return this.raw.get(this.driverOf(id)) ?? emptyInput();
  }

  protected onStart() {
    this.text = "Per ora ognuno guida il suo...";
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    // I tasti arrivano solo quando cambiano: a ogni passo si rimettono quelli di chi guida
    for (const f of fighters) if (this.order.includes(f.id)) f.input = { ...(this.raw.get(this.driverOf(f.id)) ?? emptyInput()) };
    for (const e of events) {
      if (e.type === "hit") this.add(this.driverOf(e.attackerId), C.hitPoints);
      if (e.type === "ko" && e.byId && e.byId !== e.id) this.add(this.driverOf(e.byId), C.koPoints);
    }
    this.swapMs -= dtMs;
    if (this.swapMs <= 0 && this.order.length > 1) {
      this.swapMs = C.swapMs;
      this.shift = (this.shift + 1) % this.order.length || 1; // mai di nuovo tutti al proprio posto
      this.text = "Cambio! Cerca il tuo nome";
    }
    const byId = new Map(fighters.map((f) => [f.id, f]));
    this.props = fighters
      .filter((f) => !f.respawning && this.order.includes(f.id))
      .map((f) => {
        const driver = byId.get(this.driverOf(f.id));
        return { kind: "marker", x: Math.round(f.x), y: Math.round(f.y - 120), color: driver?.color ?? 0xffffff, text: driver?.name ?? "?" };
      });
  }

  private add(id: string, n: number) {
    this.scores[id] = (this.scores[id] ?? 0) + n;
  }
}

export const specchio: MinigameDef = {
  info: {
    id: "specchio",
    title: "Lo Specchio",
    category: "pazze",
    howTo: "Ogni 10 secondi i comandi girano: guidi il lottatore di un altro, con le sue mosse. Sopra ognuno c'è il nome di chi lo guida. I punti vanno a chi è al comando!",
    keys: "Le mosse di sempre, ma guarda chi stai guidando",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(_seed, ids) {
    return {
      stage: arena({
        id: "specchio",
        name: "Lo Specchio",
        solids: [{ x: 220, y: 560, width: 840, height: 90 }],
        platforms: [
          { x: 300, y: 430, width: 180 },
          { x: 800, y: 430, width: 180 },
          { x: 550, y: 320, width: 180 },
        ],
        sky: 0x2a4a5a,
        solid: 0x3a5a6a,
        edge: 0xbfe3ff,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Specchio([...ids]),
    };
  },
};
