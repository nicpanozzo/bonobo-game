// Mezzogiorno di Fuoco (Ritmo e riflessi): tutti in fila, l'annunciatore dice "Pronti..." e dopo un'attesa a caso
// grida VAI!: il primo che fa un attacco leggero vince il round. Chi attacca prima del VIA è fuori per quel round.
// Nessuno si fa male: i colpi non toccano. Cinque round, vince chi ne prende di più.

import { MINIGAME } from "../../constants";
import { emptyInput, type Fighter, type PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.mezzogiorno;
const LIGHT = new Set(["light", "lightUp", "lightDown", "lightAir"]);

type Stage = "ready" | "wait" | "go" | "show";

class Mezzogiorno extends TimedGame {
  private stageName: Stage = "ready";
  private stageMs: number = C.readyMs;
  private round = 1;
  private sinceGoMs = 0;
  private random: () => number;
  private reactMs = new Map<string, number>(); // il tempo di reazione di ogni bot in questo round
  private names = new Map<string, string>();

  constructor(seed: number) {
    super(60 * 60 * 1000, "round"); // finisce dopo i round, non a tempo
    this.random = rng(seed).next;
    this.text = "Pronti...";
  }

  canHit() {
    return false;
  }

  done() {
    return this.started && this.round > C.rounds;
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    for (const f of fighters) this.names.set(f.id, f.name);
    this.stageMs -= dtMs;
    const shots = events.filter((e): e is Extract<GameEvent, { type: "attack" }> => e.type === "attack" && LIGHT.has(e.kind));
    // Chi spara prima del VIA (al "Pronti..." o nell'attesa) è fuori dal round
    if (this.stageName === "ready" || this.stageName === "wait") {
      for (const s of shots) {
        if (this.out.has(s.id)) continue;
        this.out.add(s.id);
        this.text = `${this.names.get(s.id) ?? "Qualcuno"} spara troppo presto!`;
      }
    }
    switch (this.stageName) {
      case "ready":
        if (this.stageMs <= 0) this.toWait();
        break;
      case "wait":
        if (this.stageMs <= 0) {
          this.stageName = "go";
          this.stageMs = C.goMs;
          this.sinceGoMs = 0;
          this.text = "VAI!";
          for (const f of fighters) this.reactMs.set(f.id, C.botReactMinMs + this.random() * (C.botReactMaxMs - C.botReactMinMs));
        }
        break;
      case "go": {
        this.sinceGoMs += dtMs;
        const winner = shots.find((s) => !this.out.has(s.id));
        if (winner) {
          this.scores[winner.id] = (this.scores[winner.id] ?? 0) + 1;
          this.text = `${this.names.get(winner.id) ?? "Qualcuno"} è il più veloce! (${Math.round(this.sinceGoMs)} ms)`;
          this.toShow();
        } else if (this.stageMs <= 0) {
          this.text = "Nessuno ha sparato!";
          this.toShow();
        }
        break;
      }
      case "show":
        if (this.stageMs <= 0) {
          this.round++;
          this.out.clear();
          if (this.round <= C.rounds) {
            this.text = `Round ${this.round}: pronti...`;
            this.stageName = "ready";
            this.stageMs = C.readyMs;
          }
        }
        break;
    }
    this.props = this.stageName === "go" ? [{ kind: "sign", x: 640, y: 260, text: "VAI!", color: 0xff4d3a }] : [];
  }

  private toWait() {
    this.stageName = "wait";
    this.stageMs = C.waitMinMs + this.random() * (C.waitMaxMs - C.waitMinMs);
  }

  private toShow() {
    this.stageName = "show";
    this.stageMs = C.showMs;
  }

  // I bot aspettano il VIA e poi sparano col loro tempo di reazione; prima stanno fermi
  botInput(f: Fighter) {
    const input = emptyInput();
    if (this.stageName === "go" && !this.out.has(f.id)) {
      const react = this.reactMs.get(f.id) ?? C.botReactMaxMs;
      input.light = this.sinceGoMs >= react && this.sinceGoMs < react + 60;
    }
    return input;
  }

  hud() {
    return { ...super.hud(), text: this.text, leftMs: null };
  }
}

export const mezzogiorno: MinigameDef = {
  info: {
    id: "mezzogiorno",
    title: "Mezzogiorno di Fuoco",
    category: "ritmo",
    howTo: "Aspetta il VIA! e poi attacca col Leggero prima di tutti. Chi attacca prima del VIA è fuori dal round. Cinque round.",
    keys: "Solo Leggero",
    durationSec: 40,
  },
  build(seed) {
    return {
      stage: arena({
        id: "mezzogiorno",
        name: "Mezzogiorno di Fuoco",
        solids: [{ x: 200, y: 560, width: 880, height: 90 }],
        spawns: [300, 980, 520, 760, 410, 870, 630, 690].map((x) => ({ x, y: 560 })),
        sky: 0xe39a4b,
        solid: 0x9a6a3c,
        edge: 0xe8c07a,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Mezzogiorno(seed),
    };
  },
};
