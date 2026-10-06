// Avversari del server (#20). Un bot è un giocatore come gli altri: a ogni tick scrive
// il suo InputState e passa dalla stessa fisica, non sposta mai il personaggio da sé.

import type { Match } from "../shared/match";
import { emptyInput, type Fighter } from "../shared/physics";
import type { InputState } from "../shared/types";
import type { RoomHooks } from "./Room";

// manichino: sta fermo e incassa, per provare colpi e combo (passo 1)
export type BotKind = "manichino";

// TODO community: un nome nostro per il manichino (es. un membro che si offre volontario)
const BOT_NAMES: Record<BotKind, string> = {
  manichino: "Manichino",
};

// Il parametro arriva dalla rete: si accettano solo i tipi conosciuti
export function parseBotKind(value: unknown): BotKind | null {
  return typeof value === "string" && Object.hasOwn(BOT_NAMES, value) ? (value as BotKind) : null;
}

// I bot di una stanza. hooks va passato alla Room, add() li fa entrare in partita.
export class Bots {
  private bots = new Map<string, BotKind>();
  private count = 0;

  readonly hooks: RoomHooks = {
    onTick: (room) => this.tick(room.match),
  };

  add(match: Match, kind: BotKind): string | null {
    if (match.isFull) return null;
    const id = `bot-${kind}-${++this.count}`;
    match.addPlayer(id, BOT_NAMES[kind]);
    this.bots.set(id, kind);
    return id;
  }

  // Prima di ogni passo di fisica: ogni bot decide i suoi tasti
  tick(match: Match): void {
    for (const f of match.players) {
      const kind = this.bots.get(f.id);
      if (kind) match.setInput(f.id, decide(kind, f));
    }
  }
}

function decide(kind: BotKind, _self: Fighter): InputState {
  switch (kind) {
    case "manichino":
      return emptyInput();
  }
}
