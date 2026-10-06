// Una stanza = una partita. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, calcola la fisica e manda a tutti lo stato.

import type { Server } from "socket.io";
import { getCharacter } from "../shared/characters";
import { COLORS, MATCH_RESTART_MS, MAX_PLAYERS_PER_ROOM, SEND_RATE, TICK_RATE } from "../shared/constants";
import { createFighter, isAlive, resetForMatch, stepWorld, type Fighter, type PhysicsContext } from "../shared/physics";
import { sanitizeRules } from "../shared/rules";
import { getStage, type StageSpec } from "../shared/stages";
import type { ClientToServer, GameEvent, GameSnapshot, InputState, MatchRules, PlayerState, ServerToClient } from "../shared/types";

export interface RoomOptions {
  stageId?: string;
  rules?: Partial<MatchRules>;
}

// Punti di aggancio per chi estende la stanza senza toccarne il cuore:
// bot.ts (#20) si iscrive a onTick, discord.ts e stats.ts (#18) a onMatchEnd.
export interface RoomHooks {
  onTick?: (room: Room, fighters: Fighter[]) => void;
  onEvents?: (room: Room, events: GameEvent[]) => void;
  onMatchEnd?: (room: Room, result: Extract<GameEvent, { type: "matchEnd" }>, fighters: Fighter[]) => void;
}

export class Room {
  readonly stage: StageSpec;
  readonly rules: MatchRules;
  private fighters = new Map<string, Fighter>();
  private loop: NodeJS.Timeout;
  private ticks = 0;
  private winnerId: string | null = null;
  private restartTimer = 0;
  private matchTimeMs = 0;
  private pendingEvents: GameEvent[] = []; // eventi accumulati fino al prossimo snapshot
  private ctx: PhysicsContext;

  constructor(
    public readonly code: string,
    private io: Server<ClientToServer, ServerToClient>,
    options: RoomOptions = {},
    private hooks: RoomHooks = {},
  ) {
    this.stage = getStage(options.stageId);
    this.rules = sanitizeRules(options.rules);
    this.ctx = { stage: this.stage, events: [] };
    this.loop = setInterval(() => this.tick(), 1000 / TICK_RATE);
  }

  get isFull() {
    return this.fighters.size >= MAX_PLAYERS_PER_ROOM;
  }

  get isEmpty() {
    return this.fighters.size === 0;
  }

  addPlayer(id: string, name: string, characterId?: string) {
    const index = this.freeIndex();
    const character = getCharacter(characterId);
    const fighter = createFighter(
      {
        id,
        name: name.slice(0, 16) || "Bonobo",
        characterId: character.id,
        color: COLORS[index],
        team: 0, // le squadre le assegna #17
        index,
        stocks: this.rules.stocks,
      },
      this.stage,
    );
    this.fighters.set(id, fighter);
  }

  removePlayer(id: string) {
    this.fighters.delete(id);
  }

  setInput(id: string, input: InputState) {
    const f = this.fighters.get(id);
    if (!f) return;
    f.input = {
      left: !!input.left,
      right: !!input.right,
      up: !!input.up,
      down: !!input.down,
      light: !!input.light,
      heavy: !!input.heavy,
      taunt: !!input.taunt,
    };
  }

  // A fine partita chiunque può ricominciare subito, senza aspettare il conto alla rovescia
  requestRematch() {
    if (this.winnerId) this.restartMatch([...this.fighters.values()]);
  }

  destroy() {
    clearInterval(this.loop);
  }

  private freeIndex(): number {
    const used = new Set([...this.fighters.values()].map((f) => COLORS.indexOf(f.color)));
    for (let i = 0; i < MAX_PLAYERS_PER_ROOM; i++) if (!used.has(i)) return i;
    return 0;
  }

  private tick() {
    const dt = 1000 / TICK_RATE;
    const list = [...this.fighters.values()];
    this.hooks.onTick?.(this, list);
    stepWorld(list, dt, this.ctx);
    this.updateMatch(list, dt);
    // ctx.events raccoglie anche quelli nati fuori dal tick (es. la rivincita)
    if (this.ctx.events.length) {
      this.hooks.onEvents?.(this, this.ctx.events);
      this.pendingEvents.push(...this.ctx.events);
      this.ctx.events = [];
    }

    this.ticks++;
    if (this.ticks % Math.round(TICK_RATE / SEND_RATE) === 0) {
      this.io.to(this.code).emit("snapshot", this.snapshot(list));
      this.pendingEvents = [];
    }
  }

  // Vince l'ultimo con vite rimaste; dopo una pausa si ricomincia
  private updateMatch(list: Fighter[], dt: number) {
    if (this.winnerId) {
      this.restartTimer -= dt;
      if (this.restartTimer <= 0) this.restartMatch(list);
      return;
    }
    this.matchTimeMs += dt;
    const alive = list.filter(isAlive);
    if (list.length >= 2 && alive.length === 1) {
      this.winnerId = alive[0].id;
      this.restartTimer = MATCH_RESTART_MS;
      const result = { type: "matchEnd" as const, winnerId: this.winnerId, winnerTeam: alive[0].team, durationMs: Math.round(this.matchTimeMs) };
      this.ctx.events.push(result);
      this.hooks.onMatchEnd?.(this, result, list);
    } else if (list.length > 0 && alive.length === 0) {
      this.restartMatch(list); // chi gioca da solo e finisce le vite riparte subito
    }
  }

  private restartMatch(list: Fighter[]) {
    this.winnerId = null;
    this.matchTimeMs = 0;
    for (const f of list) resetForMatch(f, COLORS.indexOf(f.color), this.rules.stocks, this.stage);
    this.ctx.events.push({ type: "matchStart" });
  }

  private snapshot(list: Fighter[]): GameSnapshot {
    const players: PlayerState[] = list.map((f) => ({
      id: f.id,
      name: f.name,
      characterId: f.characterId,
      color: f.color,
      team: f.team,
      x: Math.round(f.x),
      y: Math.round(f.y),
      vx: Math.round(f.vx),
      vy: Math.round(f.vy),
      facing: f.facing,
      percent: f.percent,
      stocks: f.stocks,
      onGround: f.onGround,
      attack: f.attack,
      attackActive: f.attackActive,
      hitstun: f.hitstun,
      respawning: f.respawning,
      invulnerable: f.invulnerable,
      eliminated: f.eliminated,
    }));
    return { t: Date.now(), players, winnerId: this.winnerId, timeLeftMs: null, events: this.pendingEvents };
  }
}
