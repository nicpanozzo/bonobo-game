// Una stanza = una partita. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, calcola la fisica e manda a tutti lo stato.

import type { Server } from "socket.io";
import { COLORS, MATCH_RESTART_MS, MAX_PLAYERS_PER_ROOM, SEND_RATE, TICK_RATE } from "../shared/constants";
import { createFighter, isAlive, resetForMatch, resolveHits, stepFighter, type Fighter } from "../shared/physics";
import type { ClientToServer, GameSnapshot, InputState, PlayerState, ServerToClient } from "../shared/types";

export class Room {
  private fighters = new Map<string, Fighter>();
  private loop: NodeJS.Timeout;
  private ticks = 0;
  private winnerId: string | null = null;
  private restartTimer = 0;

  constructor(
    public readonly code: string,
    private io: Server<ClientToServer, ServerToClient>,
  ) {
    this.loop = setInterval(() => this.tick(), 1000 / TICK_RATE);
  }

  get isFull() {
    return this.fighters.size >= MAX_PLAYERS_PER_ROOM;
  }

  get isEmpty() {
    return this.fighters.size === 0;
  }

  addPlayer(id: string, name: string) {
    const index = this.freeIndex();
    this.fighters.set(id, createFighter(id, name.slice(0, 16) || "Bonobo", COLORS[index], index));
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
    };
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
    for (const f of list) stepFighter(f, dt);
    resolveHits(list);
    this.updateMatch(list, dt);

    this.ticks++;
    if (this.ticks % Math.round(TICK_RATE / SEND_RATE) === 0) {
      this.io.to(this.code).emit("snapshot", this.snapshot(list));
    }
  }

  // Vince l'ultimo con vite rimaste; dopo una pausa si ricomincia
  private updateMatch(list: Fighter[], dt: number) {
    if (this.winnerId) {
      this.restartTimer -= dt;
      if (this.restartTimer <= 0) this.restartMatch(list);
      return;
    }
    const alive = list.filter(isAlive);
    if (list.length >= 2 && alive.length === 1) {
      this.winnerId = alive[0].id;
      this.restartTimer = MATCH_RESTART_MS;
    } else if (list.length > 0 && alive.length === 0) {
      this.restartMatch(list); // chi gioca da solo e finisce le vite riparte subito
    }
  }

  private restartMatch(list: Fighter[]) {
    this.winnerId = null;
    for (const f of list) resetForMatch(f, COLORS.indexOf(f.color));
  }

  private snapshot(list: Fighter[]): GameSnapshot {
    const players: PlayerState[] = list.map((f) => ({
      id: f.id,
      name: f.name,
      color: f.color,
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
    return { t: Date.now(), players, winnerId: this.winnerId };
  }
}
