// Una stanza = una partita in rete. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, fa avanzare la partita (src/shared/match.ts) a passo fisso
// e manda a tutti lo stato.

import type { Server } from "socket.io";
import { MAX_CATCHUP_TICKS, RECONNECT_HOLD_MS, ROOM_MAX_ERRORS, SEND_RATE, TICK_RATE } from "../shared/constants";
import { Match, type MatchEndEvent, type MatchOptions } from "../shared/match";
import type { Fighter } from "../shared/physics";
import type { ClientToServer, GameEvent, InputState, ServerToClient } from "../shared/types";
import { Seats } from "./seats";

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
  readonly seats: Seats; // token e posti tenuti per la riconnessione (#107)
  private errors = 0; // errori di fila nel passo: al terzo la stanza si chiude
  onClose?: () => void; // chi tiene l'elenco delle stanze (game.ts) la toglie quando si chiude da sola
  private speed = 1; // allenamento (#113): l'orologio corre più piano, il passo resta TICK_MS
  lastHumanInput = Date.now(); // ms dell'ultimo ingresso o tasto di un umano: senza, la stanza si chiude (ROOM_IDLE_MS)

  constructor(
    public readonly code: string,
    private io: Server<ClientToServer, ServerToClient>,
    options: RoomOptions = {},
    private hooks: RoomHooks = {},
    holdMs = RECONNECT_HOLD_MS,
  ) {
    this.match = new Match(options);
    this.seats = new Seats(holdMs);
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
    this.lastHumanInput = Date.now();
  }

  // Caduta di rete (#107): il lottatore resta fermo nel suo posto finché scade RECONNECT_HOLD_MS.
  // Intanto conta ancora tra gli umani, così la stanza non si chiude
  holdPlayer(id: string) {
    this.match.setAway(id, true);
    this.seats.hold(id, Date.now());
  }

  // Rientro con il token: lo stesso lottatore torna in gioco
  resumePlayer(id: string) {
    this.match.setAway(id, false);
    this.lastHumanInput = Date.now();
  }

  removePlayer(id: string) {
    this.match.removePlayer(id);
    this.humans.delete(id);
    this.seats.release(id);
  }

  setInput(id: string, input: InputState) {
    this.match.setInput(id, input);
    this.lastHumanInput = Date.now();
  }

  // Rallentatore: cambia solo quanti passi fissi si fanno al secondo, la fisica resta deterministica
  setSpeed(speed: number) {
    this.speed = speed;
  }

  requestRematch() {
    this.match.requestRematch();
  }

  destroy() {
    clearInterval(this.loop);
  }

  private pump() {
    if (this.seats.heldCount > 0 && this.expireSeats(Date.now())) return;
    const now = performance.now();
    this.advance(now - this.lastTime);
    this.lastTime = now;
  }

  // Fa i passi maturati in elapsedMs di orologio vero (pubblico per i test)
  advance(elapsedMs: number) {
    this.accumulator += elapsedMs * this.speed;
    // Dopo un blocco lungo (debugger, server sovraccarico) non si recupera tutto in un colpo
    this.accumulator = Math.min(this.accumulator, TICK_MS * MAX_CATCHUP_TICKS);
    while (this.accumulator >= TICK_MS) {
      this.accumulator -= TICK_MS;
      // Un errore nella partita o in un gancio (bot, Discord) ferma solo questa stanza, mai il server
      try {
        this.tick();
        this.errors = 0;
      } catch (err) {
        console.error(`[${this.code}] errore nel passo della partita:`, err);
        if (++this.errors >= ROOM_MAX_ERRORS) this.close();
        return;
      }
    }
  }

  // Posti scaduti: il lottatore esce come oggi; se non resta nessuno la stanza si chiude
  private expireSeats(now: number): boolean {
    for (const id of this.seats.expired(now)) {
      this.removePlayer(id);
      console.log(`[${this.code}] posto scaduto ${id}`);
    }
    if (!this.isEmpty) return false;
    this.destroy();
    this.onClose?.();
    return true;
  }

  // Chiusura per errori: la stanza sparisce dall'elenco e chi c'era dentro viene scollegato
  private close() {
    console.error(`[${this.code}] chiusa dopo ${ROOM_MAX_ERRORS} errori di fila`);
    this.destroy();
    this.onClose?.();
    this.io.in(this.code).disconnectSockets(true);
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
