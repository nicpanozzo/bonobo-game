// Una stanza = una partita in rete. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, fa avanzare la partita (src/shared/match.ts) a passo fisso
// e manda a tutti lo stato.

import type { Server } from "socket.io";
import { MAX_CATCHUP_TICKS, SEND_RATE, TICK_RATE } from "../shared/constants";
import { Match, type MatchEndEvent, type MatchOptions } from "../shared/match";
import type { Fighter } from "../shared/physics";
import type { ClientToServer, GameEvent, InputState, ServerToClient } from "../shared/types";

export type RoomOptions = MatchOptions;

// Punti di aggancio per chi estende la stanza senza toccarne il cuore:
// bot.ts (#20) si iscrive a onTick, discord.ts e stats.ts (#18) a onMatchEnd.
export interface RoomHooks {
  onTick?: (room: Room, fighters: readonly Fighter[]) => void;
  onEvents?: (room: Room, events: GameEvent[]) => void;
  onMatchEnd?: (room: Room, result: MatchEndEvent, fighters: readonly Fighter[]) => void;
}

// Più estensioni sulla stessa stanza (bot e Discord): ogni gancio le chiama tutte, in ordine
export function combineHooks(...list: RoomHooks[]): RoomHooks {
  return {
    onTick: (room, fighters) => list.forEach((h) => h.onTick?.(room, fighters)),
    onEvents: (room, events) => list.forEach((h) => h.onEvents?.(room, events)),
    onMatchEnd: (room, result, fighters) => list.forEach((h) => h.onMatchEnd?.(room, result, fighters)),
  };
}

const TICK_MS = 1000 / TICK_RATE;
const TICKS_PER_SNAPSHOT = Math.round(TICK_RATE / SEND_RATE);

export class Room {
  readonly match: Match;
  private loop: NodeJS.Timeout;
  private ticks = 0;
  private lastTime = performance.now();
  private accumulator = 0;
  private pendingEvents: GameEvent[] = []; // eventi accumulati fino al prossimo snapshot
  private humans = new Set<string>(); // i bot (#20) non tengono aperta la stanza

  constructor(
    public readonly code: string,
    private io: Server<ClientToServer, ServerToClient>,
    options: RoomOptions = {},
    private hooks: RoomHooks = {},
  ) {
    this.match = new Match(options);
    // setInterval da solo sbanda di qualche ms a ogni giro: controlliamo l'orologio
    // più spesso e facciamo tanti passi fissi quanti ne sono maturati (fixed timestep)
    this.loop = setInterval(() => this.pump(), TICK_MS / 2);
  }

  get stage() {
    return this.match.stage;
  }

  get rules() {
    return this.match.rules;
  }

  get isFull() {
    return this.match.isFull;
  }

  get isEmpty() {
    return this.humans.size === 0;
  }

  /** Giocatori umani collegati, per /health (i bot non contano) */
  get humanCount() {
    return this.humans.size;
  }

  addPlayer(id: string, name: string, characterId?: string) {
    this.match.addPlayer(id, name, characterId);
    this.humans.add(id);
  }

  removePlayer(id: string) {
    this.match.removePlayer(id);
    this.humans.delete(id);
  }

  setInput(id: string, input: InputState) {
    this.match.setInput(id, input);
  }

  requestRematch() {
    this.match.requestRematch();
  }

  destroy() {
    clearInterval(this.loop);
  }

  private pump() {
    const now = performance.now();
    this.accumulator += now - this.lastTime;
    this.lastTime = now;
    // Dopo un blocco lungo (debugger, server sovraccarico) non si recupera tutto in un colpo
    this.accumulator = Math.min(this.accumulator, TICK_MS * MAX_CATCHUP_TICKS);
    while (this.accumulator >= TICK_MS) {
      this.accumulator -= TICK_MS;
      this.tick();
    }
  }

  private tick() {
    this.hooks.onTick?.(this, this.match.players);
    const events = this.match.step(TICK_MS);
    if (events.length) {
      this.hooks.onEvents?.(this, events);
      for (const e of events) if (e.type === "matchEnd") this.hooks.onMatchEnd?.(this, e, this.match.players);
      this.pendingEvents.push(...events);
    }

    this.ticks++;
    if (this.ticks % TICKS_PER_SNAPSHOT === 0) {
      this.io.to(this.code).emit("snapshot", this.match.snapshot(this.pendingEvents, Date.now()));
      this.pendingEvents = [];
    }
  }
}
