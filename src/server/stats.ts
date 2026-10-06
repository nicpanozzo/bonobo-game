// Statistiche di una partita (#18), calcolate ascoltando gli eventi della fisica:
// non leggono né cambiano lo stato dei lottatori, così restano giuste anche per chi esce prima.

import type { GameEvent } from "../shared/types";

export interface PlayerStats {
  kos: number; // avversari buttati fuori
  falls: number; // volte in cui è uscito dall'arena
  selfDestructs: number; // cadute senza che nessuno l'abbia colpito
  damageDealt: number; // percentuale inflitta
  damageTaken: number;
}

const empty = (): PlayerStats => ({ kos: 0, falls: 0, selfDestructs: 0, damageDealt: 0, damageTaken: 0 });

export class MatchStats {
  private byId = new Map<string, PlayerStats>();

  get(id: string): PlayerStats {
    let s = this.byId.get(id);
    if (!s) {
      s = empty();
      this.byId.set(id, s);
    }
    return s;
  }

  add(events: readonly GameEvent[]): void {
    for (const e of events) {
      switch (e.type) {
        case "matchStart":
          this.byId.clear(); // rivincita: si riparte da zero
          break;
        case "hit":
          this.get(e.attackerId).damageDealt += e.damage;
          this.get(e.targetId).damageTaken += e.damage;
          break;
        case "ko":
          this.get(e.id).falls++;
          if (e.byId && e.byId !== e.id) this.get(e.byId).kos++;
          else this.get(e.id).selfDestructs++;
          break;
      }
    }
  }
}
