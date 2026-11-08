// Ieri Me (Idee pazze): si gioca un giro di 10 secondi, poi si riparte tutti dal via e il proprio fantasma rifà tasto
// per tasto il giro di prima, mentre si gioca di nuovo. A ogni giro un fantasma in più a testa: all'ultimo giro l'arena
// è piena di bonobi di ieri. I colpi e i KO dei fantasmi valgono per chi li ha giocati; il proprio fantasma non ti tocca.

import { MINIGAME } from "../../constants";
import { emptyInput, resetForMatch, type Fighter, type PhysicsContext } from "../../physics";
import type { GameEvent, InputState } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameApi, type MinigameDef } from "../minigame";

const C = MINIGAME.ierime;

interface Ghost {
  owner: string;
  inputs: InputState[];
}

class IeriMe extends TimedGame {
  private ghosts = new Map<string, Ghost>();
  private rec = new Map<string, InputState[]>();
  private round = 1;
  private tick = 0;
  private roundMs = 0;
  private home = new Map<string, { x: number; y: number; facing: 1 | -1 }>(); // dove parte ognuno: ci si torna a ogni giro

  constructor() {
    super(C.rounds * C.roundMs, "punti");
  }

  private owner(id: string): string {
    return this.ghosts.get(id)?.owner ?? id;
  }

  // Il proprio fantasma (e i fantasmi propri tra loro) non si colpiscono
  canHit(a: Fighter, t: Fighter) {
    return this.owner(a.id) !== this.owner(t.id);
  }

  protected onStart(fighters: Fighter[]) {
    for (const f of fighters) this.home.set(f.id, { x: f.x, y: f.y, facing: f.facing });
    this.text = `Giro 1 di ${C.rounds}`;
  }

  protected onStep(fighters: Fighter[], ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[], api: MinigameApi) {
    for (const e of events) {
      if (e.type === "hit") this.add(this.owner(e.attackerId), C.hitPoints);
      if (e.type === "ko" && e.byId) this.add(this.owner(e.byId), C.koPoints);
    }
    // Si registrano i tasti di chi gioca davvero; i fantasmi rifanno i loro, un passo alla volta
    for (const f of fighters) {
      const g = this.ghosts.get(f.id);
      if (g) f.input = g.inputs[this.tick] ?? emptyInput();
      else {
        const list = this.rec.get(f.id) ?? [];
        list.push({ ...f.input });
        this.rec.set(f.id, list);
      }
    }
    for (const id of this.ghosts.keys()) delete this.scores[id]; // i fantasmi non sono in classifica
    this.tick++;
    this.roundMs += dtMs;
    if (this.roundMs < C.roundMs || this.round >= C.rounds) return;
    // Fine del giro: ogni giocatore lascia un fantasma col giro appena fatto, e si riparte tutti dal via
    this.round++;
    this.roundMs = 0;
    this.tick = 0;
    for (const f of fighters) {
      if (this.ghosts.has(f.id)) continue;
      const ghost = api.addGhost(`${f.id}~${this.round - 1}`, f.id);
      if (ghost) this.ghosts.set(ghost.id, { owner: f.id, inputs: this.rec.get(f.id) ?? [] });
    }
    this.rec.clear();
    // I fantasmi nuovi nascono già al via del loro giocatore; tutti gli altri ci tornano
    for (const f of fighters) {
      const home = this.home.get(this.owner(f.id));
      resetForMatch(f, 0, f.stocks, ctx.stage);
      if (home) Object.assign(f, home);
      if (this.ghosts.has(f.id)) f.input = emptyInput();
    }
    this.text = `Giro ${this.round} di ${C.rounds}: arrivano quelli di ieri!`;
  }

  private add(id: string, n: number) {
    this.scores[id] = (this.scores[id] ?? 0) + n;
  }

  places(ids: string[]) {
    return super.places(ids.filter((id) => !this.ghosts.has(id)));
  }
}

export const ierime: MinigameDef = {
  info: {
    id: "ierime",
    title: "Ieri Me",
    category: "pazze",
    howTo: "Giochi 10 secondi, poi si riparte e il tuo fantasma rifà le tue mosse mentre giochi di nuovo. A ogni giro un fantasma in più! I colpi dei tuoi fantasmi valgono per te.",
    keys: "Le mosse di sempre: pensa a cosa farà il te di ieri",
    durationSec: (C.rounds * C.roundMs) / 1000,
  },
  build() {
    return {
      stage: arena({
        id: "ierime",
        name: "Ieri Me",
        solids: [{ x: 200, y: 570, width: 880, height: 90 }],
        platforms: [
          { x: 280, y: 440, width: 180 },
          { x: 820, y: 440, width: 180 },
          { x: 550, y: 330, width: 180 },
        ],
        sky: 0x3a2a4a,
        solid: 0x5a4a6a,
        edge: 0xff8ad8,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new IeriMe(),
    };
  },
};
