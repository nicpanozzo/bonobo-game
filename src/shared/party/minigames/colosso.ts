// Il Colosso (Uno contro tutti): uno mangia il brownie della nonna e diventa gigante, pesante e lento, con le sue mosse
// di sempre (e la terra che trema quando atterra). Gli altri fanno squadra per buttarlo fuori. Il Colosso fa punti a
// ogni KO, chi butta fuori il Colosso ne fa di più e anche gli altri cacciatori prendono qualcosa.

import { MINIGAME } from "../../constants";
import type { Fighter, PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.colosso;

class Colosso extends TimedGame {
  constructor(private giant: string) {
    super(C.durationMs, "punti");
  }

  protected onStart(fighters: Fighter[]) {
    this.keepGiant(fighters);
  }

  // Il brownie non finisce mai: anche dopo un KO si torna giganti
  private keepGiant(fighters: Fighter[]) {
    const g = fighters.find((f) => f.id === this.giant);
    if (!g) return;
    g.powerup = "colosso";
    g.powerupMs = 10000;
  }

  // Solo tra il Colosso e gli altri: i cacciatori non si picchiano tra loro
  canHit(a: Fighter, t: Fighter) {
    return (a.id === this.giant) !== (t.id === this.giant);
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, _dtMs: number, events: readonly GameEvent[]) {
    this.keepGiant(fighters);
    for (const e of events) {
      if (e.type !== "ko") continue;
      if (e.id === this.giant) {
        // Il Colosso è fuori: punti pieni a chi l'ha buttato, qualcosa a tutti gli altri cacciatori
        for (const f of fighters) if (f.id !== this.giant) this.scores[f.id] = (this.scores[f.id] ?? 0) + (f.id === e.byId ? C.koPoints : C.helpPoints);
        const by = fighters.find((f) => f.id === e.byId);
        this.text = by ? `${by.name} butta giù il Colosso!` : "Il Colosso cade!";
      } else if (e.byId === this.giant) {
        this.scores[this.giant] = (this.scores[this.giant] ?? 0) + C.giantPoints;
      }
    }
    const g = fighters.find((f) => f.id === this.giant);
    this.props = g && !g.respawning ? [{ kind: "marker", x: Math.round(g.x), y: Math.round(g.y - 190), color: 0xff4560, text: "COLOSSO" }] : [];
  }
}

export const colosso: MinigameDef = {
  info: {
    id: "colosso",
    title: "Il Colosso",
    category: "unoContro",
    howTo: "Uno è diventato un Colosso: pesa tanto e picchia forte. Gli altri fanno squadra per buttarlo fuori! Il Colosso fa punti a ogni KO.",
    keys: "Le mosse di sempre: attacca il Colosso, oppure (se sei lui) schiaccia tutti",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(seed, ids) {
    const giant = ids[Math.floor(rng(seed).next() * ids.length)] ?? "";
    return {
      stage: arena({
        id: "colosso",
        name: "Il Colosso",
        solids: [{ x: 220, y: 560, width: 840, height: 90 }],
        platforms: [
          { x: 300, y: 420, width: 180 },
          { x: 800, y: 420, width: 180 },
          { x: 550, y: 300, width: 180 },
        ],
        sky: 0x4a2a2a,
        solid: 0x6a4a3a,
        edge: 0xff8a5a,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      roles: { [giant]: "Il Colosso" },
      runtime: new Colosso(giant),
    };
  },
};
