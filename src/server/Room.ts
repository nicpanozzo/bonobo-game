// Una stanza = una partita. Il server è l'arbitro: riceve solo i tasti
// premuti dai giocatori, calcola la fisica e manda a tutti lo stato.

import type { Server } from "socket.io";
import { COLORS, FIGHTER, MAX_PLAYERS_PER_ROOM, SEND_RATE, TICK_RATE, WORLD } from "../shared/constants";
import { emptyInput, resolveHits, respawn, spawnX, stepFighter, type Fighter } from "../shared/physics";
import type { ClientToServer, GameSnapshot, InputState, PlayerState, ServerToClient } from "../shared/types";

export class Room {
  private fighters = new Map<string, Fighter>();
  private loop: NodeJS.Timeout;
  private ticks = 0;

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
    this.fighters.set(id, {
      id,
      name: name.slice(0, 16) || "Bonobo",
      color: COLORS[index],
      x: spawnX(index),
      y: WORLD.floorY,
      vx: 0,
      vy: 0,
      facing: index % 2 === 0 ? 1 : -1,
      hp: FIGHTER.maxHp,
      onGround: true,
      attacking: false,
      hitstun: false,
      ko: false,
      kos: 0,
      input: emptyInput(),
      attackTimer: 0,
      cooldownTimer: 0,
      hitstunTimer: 0,
      respawnTimer: 0,
      alreadyHit: new Set(),
    });
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
      jump: !!input.jump,
      attack: !!input.attack,
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
    for (const f of list) {
      stepFighter(f, dt);
      if (f.ko && f.respawnTimer <= 0) respawn(f, COLORS.indexOf(f.color));
    }
    resolveHits(list);

    this.ticks++;
    if (this.ticks % Math.round(TICK_RATE / SEND_RATE) === 0) {
      this.io.to(this.code).emit("snapshot", this.snapshot(list));
    }
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
      hp: f.hp,
      onGround: f.onGround,
      attacking: f.attacking,
      hitstun: f.hitstun,
      ko: f.ko,
      kos: f.kos,
    }));
    return { t: Date.now(), players };
  }
}
