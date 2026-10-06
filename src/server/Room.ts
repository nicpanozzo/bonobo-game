// Una stanza = una partita. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, calcola la fisica e manda a tutti lo stato.

import type { Server } from "socket.io";
import { getCharacter } from "../shared/characters";
import { COLORS, MATCH_RESTART_MS, MAX_PLAYERS_PER_ROOM, SEND_RATE, TEAM_COLORS, TICK_RATE } from "../shared/constants";
import { createFighter, resetForMatch, stepWorld, type Fighter, type PhysicsContext } from "../shared/physics";
import { canHitWithRules, lastStanding, leaderOnTime, sanitizeRules } from "../shared/rules";
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
  private slots = new Map<string, number>(); // posto di ognuno nella stanza (0-3): decide partenza e colore
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
    const rules = this.rules;
    this.ctx = { stage: this.stage, events: [], canHit: (a, t) => canHitWithRules(rules, a.team, t.team) };
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
    const team = this.rules.mode === "teams" ? this.smallerTeam() : 0;
    const fighter = createFighter(
      {
        id,
        name: name.slice(0, 16) || "Bonobo",
        characterId: character.id,
        color: team ? this.teamColor(team as 1 | 2) : COLORS[index],
        team,
        index,
        stocks: this.rules.stocks,
      },
      this.stage,
    );
    this.slots.set(id, index);
    this.fighters.set(id, fighter);
  }

  // Si entra nella squadra con meno giocatori (a parità, la Rossa)
  private smallerTeam(): 1 | 2 {
    const count = (t: number) => [...this.fighters.values()].filter((f) => f.team === t).length;
    return count(2) < count(1) ? 2 : 1;
  }

  private teamColor(team: 1 | 2): number {
    const used = new Set([...this.fighters.values()].map((f) => f.color));
    return TEAM_COLORS[team].find((c) => !used.has(c)) ?? TEAM_COLORS[team][0];
  }

  removePlayer(id: string) {
    this.fighters.delete(id);
    this.slots.delete(id);
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
    const used = new Set(this.slots.values());
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

  // Vince l'ultimo (o l'ultima squadra) con vite rimaste, o chi è avanti allo scadere del tempo.
  // Dopo una pausa, o se qualcuno chiede la rivincita, si ricomincia.
  private updateMatch(list: Fighter[], dt: number) {
    if (this.winnerId) {
      this.restartTimer -= dt;
      if (this.restartTimer <= 0) this.restartMatch(list);
      return;
    }
    if (list.length >= 2) this.matchTimeMs += dt; // il tempo corre solo quando c'è qualcuno contro cui giocare
    const timeUp = this.rules.timeLimitSec > 0 && this.matchTimeMs >= this.rules.timeLimitSec * 1000;
    const winner = lastStanding(this.rules, list) ?? (timeUp ? leaderOnTime(this.rules, list) : undefined);
    if (winner) {
      this.winnerId = winner.id;
      this.restartTimer = MATCH_RESTART_MS;
      const result = { type: "matchEnd" as const, winnerId: winner.id, winnerTeam: winner.team, durationMs: Math.round(this.matchTimeMs) };
      this.ctx.events.push(result);
      this.hooks.onMatchEnd?.(this, result, list);
    } else if (list.length > 0 && list.every((f) => f.eliminated)) {
      this.restartMatch(list); // chi gioca da solo e finisce le vite riparte subito
    }
  }

  private restartMatch(list: Fighter[]) {
    this.winnerId = null;
    this.matchTimeMs = 0;
    for (const f of list) resetForMatch(f, this.slots.get(f.id) ?? 0, this.rules.stocks, this.stage);
    this.ctx.events.push({ type: "matchStart" });
  }

  private timeLeftMs(): number | null {
    if (this.rules.timeLimitSec <= 0) return null;
    return Math.max(0, Math.round(this.rules.timeLimitSec * 1000 - this.matchTimeMs));
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
    return { t: Date.now(), players, winnerId: this.winnerId, timeLeftMs: this.timeLeftMs(), events: this.pendingEvents };
  }
}
