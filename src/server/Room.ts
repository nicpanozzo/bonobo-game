// Una stanza = una partita in rete. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, fa avanzare la partita (src/shared/match.ts) a passo fisso
// e manda a tutti lo stato.

import type { Server } from "socket.io";
import { HALL, MAX_CATCHUP_TICKS, RECONNECT_HOLD_MS, SNAPSHOT_CLOCK_RESYNC_MS, ROOM_MAX_ERRORS, SEND_RATE, TICK_RATE } from "../shared/constants";
import { Hall, type HallChoice } from "../shared/hall";
import { Match, type MatchEndEvent, type MatchOptions } from "../shared/match";
import type { Fighter } from "../shared/physics";
import type { BoardRow, ClientToServer, GameEvent, HallEvent, HallMode, InputState, MatchRules, ServerToClient } from "../shared/types";
import { Seats } from "./seats";

export interface RoomOptions extends MatchOptions {
  hall?: boolean; // la stanza comincia nella sala d'attesa 3D (mai in Allenamento)
  board?: () => BoardRow[]; // i primi della classifica per il tabellone della sala (game.ts la prende dal Leaderboard)
}

// Punti di aggancio per chi estende la stanza senza toccarne il cuore:
// bot.ts (#20) si iscrive a onTick, discord.ts e stats.ts (#18) a onMatchEnd.
export interface RoomHooks {
  onTick?: (room: Room, fighters: readonly Fighter[]) => void;
  onEvents?: (room: Room, events: GameEvent[]) => void;
  onMatchEnd?: (room: Room, result: MatchEndEvent, fighters: readonly Fighter[]) => void;
  // Dalla sala d'attesa parte una partita nuova (Match nuova): botIds sono i bot della sala, già dentro come lottatori
  onMatchBuilt?: (room: Room, match: Match, botIds: string[]) => void;
}

// Più estensioni sulla stessa stanza (bot e Discord): ogni gancio le chiama tutte, in ordine
export function combineHooks(...list: RoomHooks[]): RoomHooks {
  return {
    onTick: (room, fighters) => list.forEach((h) => h.onTick?.(room, fighters)),
    onEvents: (room, events) => list.forEach((h) => h.onEvents?.(room, events)),
    onMatchEnd: (room, result, fighters) => list.forEach((h) => h.onMatchEnd?.(room, result, fighters)),
    onMatchBuilt: (room, match, botIds) => list.forEach((h) => h.onMatchBuilt?.(room, match, botIds)),
  };
}

const TICK_MS = 1000 / TICK_RATE;
const TICKS_PER_SNAPSHOT = Math.round(TICK_RATE / SEND_RATE);

export class Room {
  private current: Match; // si cambia quando dalla sala parte una partita nuova
  // Sala d'attesa (null nelle stanze di prima, in palestra e nel tutorial): tiene sempre tutti, anche durante la partita
  readonly hall: Hall | null;
  private inHall: boolean;
  private hallEvents: HallEvent[] = [];
  private creatorRules: MatchRules; // le regole di chi ha creato la stanza: la modalità la decide il voto
  private boardRows: BoardRow[] = [];
  private boardAt = -Infinity; // clock dell'ultima lettura della classifica
  private board?: () => BoardRow[];
  private endedMs = 0; // ms da quando la partita è finita: dopo HALL.returnAfterMs si torna nella sala
  private loop: NodeJS.Timeout;
  private ticks = 0;
  private lastTime = performance.now();
  private accumulator = 0;
  // Ora (ms) del prossimo snapshot: avanza di un passo per tick, non è Date.now() (#320).
  // Quando l'orologio sbanda si fanno due passi in un giro solo: con Date.now() i due snapshot avrebbero
  // la stessa ora e il client li vedrebbe come doppi o con velocità assurde, il movimento a scatti
  private clock = Date.now();
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
    const { hall, board, ...matchOptions } = options;
    this.current = new Match(matchOptions);
    this.creatorRules = this.current.rules;
    const mode = this.creatorRules.mode;
    this.hall = hall && mode !== "training" ? new Hall({ seed: code, defaultMode: mode as HallMode, defaultStageId: options.stageId }) : null;
    this.inHall = !!this.hall;
    this.board = board;
    this.seats = new Seats(holdMs);
    // setInterval da solo sbanda di qualche ms a ogni giro: controlliamo l'orologio
    // più spesso e facciamo tanti passi fissi quanti ne sono maturati (fixed timestep)
    this.loop = setInterval(() => this.pump(), TICK_MS / 2);
  }

  get match(): Match {
    return this.current;
  }

  // "hall" = nella sala d'attesa (arrivano i messaggi hall), "match" = partita
  get phase(): "hall" | "match" {
    return this.inHall ? "hall" : "match";
  }

  get stage() {
    return this.match.stage;
  }

  get rules() {
    return this.match.rules;
  }

  get isFull() {
    return this.hall ? this.hall.isFull : this.match.isFull;
  }

  // I nomi già presi nella stanza (per "Nome 2"): con la sala anche chi non è nella partita in corso
  get playerNames(): string[] {
    return this.hall ? this.hall.names() : this.match.players.map((p) => p.name);
  }

  get isEmpty() {
    return this.humans.size === 0;
  }

  /** Giocatori umani collegati, per /health (i bot non contano) */
  get humanCount() {
    return this.humans.size;
  }

  addPlayer(id: string, name: string, characterId?: string, skinId?: string, team?: number) {
    // Con la sala si entra nella sala; a partita in corso anche nella partita, come nelle stanze di prima
    this.hall?.addPlayer(id, name, characterId, skinId);
    if (!this.inHall) this.match.addPlayer(id, name, characterId, skinId, team);
    this.humans.add(id);
    this.lastHumanInput = Date.now();
  }

  // Caduta di rete (#107): il lottatore resta fermo nel suo posto finché scade RECONNECT_HOLD_MS.
  // Intanto conta ancora tra gli umani, così la stanza non si chiude
  holdPlayer(id: string) {
    this.match.setAway(id, true);
    this.hall?.setAway(id, true);
    this.seats.hold(id, Date.now());
  }

  // Rientro con il token: lo stesso lottatore torna in gioco
  resumePlayer(id: string) {
    this.match.setAway(id, false);
    this.hall?.setAway(id, false);
    this.lastHumanInput = Date.now();
  }

  removePlayer(id: string) {
    this.match.removePlayer(id);
    this.hall?.removePlayer(id);
    this.humans.delete(id);
    this.seats.release(id);
  }

  setInput(id: string, input: InputState) {
    if (this.inHall) this.hall!.setInput(id, input);
    else this.match.setInput(id, input);
    this.lastHumanInput = Date.now();
  }

  // Rallentatore: cambia solo quanti passi fissi si fanno al secondo, la fisica resta deterministica
  setSpeed(speed: number) {
    this.speed = speed;
  }

  // Un messaggio a tutti quelli nella stanza (es. i punti della classifica a fine partita, da discord.ts)
  broadcast<E extends keyof ServerToClient>(event: E, ...args: Parameters<ServerToClient[E]>) {
    this.io.to(this.code).emit(event, ...args);
  }

  requestRematch() {
    if (!this.inHall) this.match.requestRematch();
  }

  // A partita finita, tutti tornano nella sala d'attesa (solo nelle stanze con la sala)
  requestHall() {
    if (this.hall && !this.inHall && this.match.ended) this.returnToHall();
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
    // L'ora degli snapshot resta vicina a quella vera: dopo un blocco (o un cambio di velocità) si riallinea
    const late = Date.now() - this.accumulator / this.speed - this.clock;
    if (Math.abs(late) > SNAPSHOT_CLOCK_RESYNC_MS) this.clock += late;
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
    if (this.inHall) return this.tickHall();
    this.hooks.onTick?.(this, this.match.players);
    const events = this.match.step(TICK_MS);
    if (events.length) {
      this.hooks.onEvents?.(this, events);
      for (const e of events) if (e.type === "matchEnd") this.hooks.onMatchEnd?.(this, e, this.match.players);
      this.pendingEvents.push(...events);
    }

    this.ticks++;
    this.clock += TICK_MS / this.speed;
    if (this.ticks % TICKS_PER_SNAPSHOT === 0) {
      this.io.to(this.code).emit("snapshot", this.match.snapshot(this.pendingEvents, this.clock));
      this.pendingEvents = [];
    }
    // Con la sala la partita finita non ricomincia da sola: rivincita, oppure dopo un po' tutti nella sala
    if (this.hall) {
      this.endedMs = this.match.ended ? this.endedMs + TICK_MS : 0;
      if (this.endedMs >= HALL.returnAfterMs) this.returnToHall();
    }
  }

  // Un passo della sala: niente snapshot della partita, solo messaggi hall
  private tickHall() {
    const hall = this.hall!;
    this.hallEvents.push(...hall.step(TICK_MS));
    this.ticks++;
    this.clock += TICK_MS / this.speed;
    const choice = hall.result();
    if (choice) {
      this.sendHall(); // con l'evento go, poi stage e la partita
      this.startMatch(choice);
    } else if (this.ticks % HALL.sendEveryTicks === 0) this.sendHall();
  }

  private sendHall() {
    // La classifica non cambia a ogni passo: si rilegge ogni tanto
    if (this.board && this.clock - this.boardAt >= HALL.boardRefreshMs) {
      this.boardRows = this.board();
      this.boardAt = this.clock;
    }
    this.io.to(this.code).emit("hall", this.hall!.snapshot(this.clock, this.hallEvents, this.boardRows, this.creatorRules));
    this.hallEvents = [];
  }

  // Dalla sala alla partita: una Match nuova con tutti quelli della sala, già pronti (presentazione e 3, 2, 1)
  private startMatch(choice: HallChoice) {
    const hall = this.hall!;
    const match = new Match({ stageId: choice.stageId, rules: { ...this.creatorRules, mode: choice.mode }, prematch: true, autoRestart: false });
    for (const p of hall.roster()) {
      match.addPlayer(p.id, p.name, p.characterId, p.skinId || undefined);
      match.setReady(p.id, true);
      if (p.away) match.setAway(p.id, true);
    }
    this.current = match;
    this.inHall = false;
    this.pendingEvents = [];
    this.endedMs = 0;
    this.hooks.onMatchBuilt?.(this, match, hall.botIds());
    this.io.to(this.code).emit("stage", { stageId: match.stage.id, rules: match.rules, stage: match.stage });
  }

  // Dalla partita alla sala: stessi lottatori, voti da capo
  private returnToHall() {
    this.hall!.regroup();
    this.inHall = true;
    this.endedMs = 0;
    this.hallEvents = [];
    this.pendingEvents = [];
    this.sendHall();
  }
}
