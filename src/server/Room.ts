// Una stanza = una partita in rete. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, fa avanzare la partita (src/shared/match.ts) a passo fisso
// e manda a tutti lo stato.

import type { Server } from "socket.io";
import { HALL, MAX_CATCHUP_TICKS, PARTY, RECONNECT_HOLD_MS, SNAPSHOT_CLOCK_RESYNC_MS, ROOM_MAX_ERRORS, SEND_RATE, TICK_RATE } from "../shared/constants";
import { Hall, type HallChoice } from "../shared/hall";
import { Match, type MatchEndEvent, type MatchOptions } from "../shared/match";
import type { Fighter } from "../shared/physics";
import { getMinigame, minigamesFor } from "../shared/party/minigames";
import { Party, type PartyFeedback } from "../shared/party/party";
import { sanitizeRules } from "../shared/rules";
import type { BoardRow, ClientToServer, GameEvent, HallBotLevel, HallEvent, HallMode, InputState, MatchRules, PartyCommand, ServerToClient } from "../shared/types";
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
  // Bonobo Party (#579): i pareri sul minigioco appena giocato, da salvare (feedback.ts)
  onFeedback?: (room: Room, entries: PartyFeedback[]) => void;
}

// Più estensioni sulla stessa stanza (bot e Discord): ogni gancio le chiama tutte, in ordine
export function combineHooks(...list: RoomHooks[]): RoomHooks {
  return {
    onTick: (room, fighters) => list.forEach((h) => h.onTick?.(room, fighters)),
    onEvents: (room, events) => list.forEach((h) => h.onEvents?.(room, events)),
    onMatchEnd: (room, result, fighters) => list.forEach((h) => h.onMatchEnd?.(room, result, fighters)),
    onMatchBuilt: (room, match, botIds) => list.forEach((h) => h.onMatchBuilt?.(room, match, botIds)),
    onFeedback: (room, entries) => list.forEach((h) => h.onFeedback?.(room, entries)),
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
  private creatorRules: MatchRules; // le regole della prossima partita dalla sala (all'inizio di chi l'ha creata, poi dal computer): la modalità la decide il voto
  hallBotLevel: HallBotLevel = "semplice"; // come giocano i bot della sala (game.ts lo legge a ogni partita nuova)
  private boardRows: BoardRow[] = [];
  private boardAt = -Infinity; // clock dell'ultima lettura della classifica
  private board?: () => BoardRow[];
  private endedMs = 0; // ms da quando la partita è finita: dopo HALL.returnAfterMs si torna nella sala
  // Bonobo Party (#579): il tabellone, quando dalla sala si è scelto Party. partyMatch = si sta giocando il minigioco
  party: Party | null = null;
  private partyMatch = false;
  private partySeed = 1;
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
    // In sala la modalità si vota: il numero di squadre scelto in lobby vale anche se chi crea non ha scelto Squadre
    if (hall && mode !== "training") this.creatorRules = hallRules(matchOptions.rules, mode);
    // Bonobo Party (#579) non è una modalità di partita: chi crea la stanza può però volerla come scelta della sala
    const wanted = (matchOptions.rules as { mode?: unknown } | undefined)?.mode === "party" ? "party" : (mode as HallMode);
    this.hall = hall && mode !== "training" ? new Hall({ seed: code, defaultMode: wanted, defaultStageId: options.stageId }) : null;
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

  // "hall" = nella sala d'attesa (arrivano i messaggi hall), "party" = sul tabellone di Bonobo Party, "match" = partita
  get phase(): "hall" | "match" | "party" {
    return this.inHall ? "hall" : this.party && !this.partyMatch ? "party" : "match";
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
    if (this.party) {
      // A Bonobo Party in corso si entra sul tabellone, e se c'è un minigioco anche lì (parte da zero punti)
      const p = this.hall?.roster().find((r) => r.id === id);
      this.party.addPlayer({ id, name: p?.name ?? name, characterId: p?.characterId ?? characterId ?? "", skinId: p?.skinId ?? "", color: p?.color ?? 0xffffff, bot: false });
      if (this.partyMatch) this.match.addPlayer(id, p?.name ?? name, characterId, skinId);
    } else if (!this.inHall) this.match.addPlayer(id, name, characterId, skinId, team);
    this.humans.add(id);
    this.lastHumanInput = Date.now();
  }

  // Caduta di rete (#107): il lottatore resta fermo nel suo posto finché scade RECONNECT_HOLD_MS.
  // Intanto conta ancora tra gli umani, così la stanza non si chiude
  holdPlayer(id: string) {
    this.party?.setAway(id, true);
    this.match.setAway(id, true);
    this.hall?.setAway(id, true);
    this.seats.hold(id, Date.now());
  }

  // Rientro con il token: lo stesso lottatore torna in gioco
  resumePlayer(id: string) {
    this.party?.setAway(id, false);
    this.match.setAway(id, false);
    this.hall?.setAway(id, false);
    this.lastHumanInput = Date.now();
  }

  removePlayer(id: string) {
    this.party?.removePlayer(id);
    this.match.removePlayer(id);
    this.hall?.removePlayer(id);
    this.humans.delete(id);
    this.seats.release(id);
  }

  setInput(id: string, input: InputState) {
    if (this.inHall) this.hall!.setInput(id, input);
    else if (!this.party || this.partyMatch) this.match.setInput(id, input);
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
    if (!this.inHall && !this.party) this.match.requestRematch();
  }

  // Bonobo Party (#579): un comando sul tabellone (dado, strada, bottega, voto, feedback). Party decide se vale
  partyCommand(id: string, cmd: PartyCommand) {
    if (this.party && !this.partyMatch) this.party.command(id, cmd);
  }

  // Dal computer della sala (#567): regole e livello dei bot della prossima partita. Solo nella sala, solo chi c'è dentro
  setHallRules(id: string, rules: Partial<MatchRules> | undefined, botLevel: unknown) {
    if (!this.hall || !this.inHall || !this.hall.roster().some((p) => p.id === id && !p.bot)) return;
    if (rules) this.creatorRules = hallRules(rules, this.creatorRules.mode);
    if (botLevel === "manichino" || botLevel === "facile" || botLevel === "semplice" || botLevel === "difficile") this.hallBotLevel = botLevel;
    this.hall.rulesChanged(id);
  }

  // A partita finita, tutti tornano nella sala d'attesa (solo nelle stanze con la sala)
  requestHall() {
    if (this.party) {
      if (!this.partyMatch && this.party.phase === "podium") this.endParty();
      return;
    }
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
    if (this.party && !this.partyMatch) return this.tickParty();
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
    // Bonobo Party: a minigioco finito, dopo il GAME! si torna al tabellone con i posti d'arrivo
    if (this.party) {
      this.endedMs = this.match.ended ? this.endedMs + TICK_MS : 0;
      if (this.endedMs >= PARTY.resultsMs) this.endMinigame();
      return;
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
    this.io.to(this.code).emit("hall", this.hall!.snapshot(this.clock, this.hallEvents, this.boardRows, this.creatorRules, this.hallBotLevel));
    this.hallEvents = [];
  }

  // Un passo del tabellone di Bonobo Party: niente fisica, solo la macchina a stati e i messaggi party
  private tickParty() {
    const party = this.party!;
    party.step(TICK_MS);
    this.ticks++;
    this.clock += TICK_MS / this.speed;
    const feedback = party.drainFeedback();
    if (feedback.length > 0) this.hooks.onFeedback?.(this, feedback);
    if (party.finished) return this.endParty();
    if (party.minigameReady) {
      this.sendParty();
      return this.startMinigame();
    }
    if (this.ticks % PARTY.sendEveryTicks === 0) this.sendParty();
  }

  private sendParty() {
    if (this.party) this.io.to(this.code).emit("party", this.party.snapshot(this.clock));
  }

  // Dalla sala al tabellone: tutti quelli della sala, bot compresi
  private startParty() {
    const hall = this.hall!;
    const roster = hall.roster();
    this.partySeed = seedOf(`${this.code}:${this.ticks}`);
    this.party = new Party({
      seed: this.partySeed,
      rounds: this.creatorRules.partyRounds ?? PARTY.defaultRounds,
      pick: this.creatorRules.partyPick ?? "random",
      players: roster.map((p) => ({ id: p.id, name: p.name, characterId: p.characterId, skinId: p.skinId, color: p.color, bot: p.bot })),
      minigames: minigamesFor(roster.length),
    });
    for (const p of roster) if (p.away) this.party.setAway(p.id, true);
    this.inHall = false;
    this.partyMatch = false;
    this.pendingEvents = [];
    this.endedMs = 0;
    this.sendParty();
  }

  // Il tabellone ha scelto il minigioco: una Match nuova con la sua arena e la sua regola. Prima la prova libera
  // (il pre-partita: i bot sono già pronti, chi gioca dice Pronto o aspetta PARTY.practiceMs), poi presentazione e 3, 2, 1
  private startMinigame() {
    const party = this.party!;
    const info = party.minigame!;
    const def = getMinigame(info.id);
    if (!def) return party.minigameDone({});
    const roster = (this.hall?.roster() ?? []).filter((p) => (party.duel ?? party.playerIds).includes(p.id));
    this.partySeed = (this.partySeed * 1103515245 + 12345) >>> 0;
    const setup = def.build(this.partySeed, roster.map((p) => p.id));
    const match = new Match({
      stage: setup.stage,
      rules: { ...this.creatorRules, itemAmount: 0, timeLimitSec: 0, ...setup.rules },
      items: false,
      prematch: true,
      autoRestart: false,
      minigame: { id: info.id, runtime: setup.runtime, unlimitedStocks: setup.unlimitedStocks ?? true, practiceMs: PARTY.practiceMs },
    });
    for (const p of roster) {
      match.addPlayer(p.id, p.name, p.characterId, p.skinId || undefined);
      if (p.away) match.setAway(p.id, true);
    }
    this.current = match;
    this.partyMatch = true;
    this.pendingEvents = [];
    this.endedMs = 0;
    this.hooks.onMatchBuilt?.(this, match, this.hall?.botIds() ?? []);
    this.io.to(this.code).emit("stage", { stageId: match.stage.id, rules: match.rules, stage: match.stage, minigame: { ...info, ...(setup.roles && { roles: setup.roles }) } });
  }

  // Il minigioco è finito: i posti tornano al tabellone (chi è entrato a metà non ha un posto)
  private endMinigame() {
    const party = this.party!;
    const places = this.match.minigamePlaces ?? {};
    party.minigameDone(Object.fromEntries(Object.entries(places).filter(([id]) => party.playerIds.includes(id))));
    this.partyMatch = false;
    this.endedMs = 0;
    this.pendingEvents = [];
    this.sendParty();
  }

  // Fine del party (podio finito o tutti d'accordo): si torna nella sala
  private endParty() {
    this.party = null;
    this.partyMatch = false;
    this.returnToHall();
  }

  // Dalla sala alla partita: una Match nuova con tutti quelli della sala, già pronti (presentazione e 3, 2, 1)
  private startMatch(choice: HallChoice) {
    if (choice.mode === "party") return this.startParty();
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

// Un seme da una scritta (codice della stanza e passo): ogni party ha il suo tabellone e i suoi minigiochi
function seedOf(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
  return h >>> 0 || 1;
}

// Le regole per la sala: ripulite come in Squadre (così il numero di squadre resta), poi la modalità di prima
function hallRules(raw: Partial<MatchRules> | undefined, mode: MatchRules["mode"]): MatchRules {
  return { ...sanitizeRules({ ...raw, mode: "teams" }), mode };
}
