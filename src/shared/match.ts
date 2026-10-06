// Una partita intera, senza rete e senza orologio: giocatori, regole, vittoria, eventi.
// Il server la fa avanzare a passo fisso e manda gli snapshot; un client potrebbe farla
// girare in locale (allenamento, predizione) e un porting su un altro motore parte da qui.

import { getCharacter } from "./characters";
import { COLORS, MATCH_RESTART_MS, MAX_PLAYERS_PER_ROOM, TEAM_COLORS } from "./constants";
import { createFighter, resetForMatch, stepWorld, type Fighter, type PhysicsContext } from "./physics";
import { canHitWithRules, lastStanding, leaderOnTime, sanitizeRules } from "./rules";
import { getStage, type StageSpec } from "./stages";
import type { GameEvent, GameSnapshot, InputState, MatchRules, PlayerState } from "./types";

export interface MatchOptions {
  stageId?: string;
  rules?: Partial<MatchRules>;
}

export type MatchEndEvent = Extract<GameEvent, { type: "matchEnd" }>;

export class Match {
  readonly stage: StageSpec;
  readonly rules: MatchRules;
  private fighters = new Map<string, Fighter>();
  private slots = new Map<string, number>(); // posto di ognuno (0-7): decide partenza e colore
  private winnerId: string | null = null;
  private restartTimer = 0;
  private matchTimeMs = 0;
  private ctx: PhysicsContext;

  constructor(options: MatchOptions = {}) {
    this.stage = getStage(options.stageId);
    this.rules = sanitizeRules(options.rules);
    const rules = this.rules;
    this.ctx = { stage: this.stage, events: [], canHit: (a, t) => canHitWithRules(rules, a.team, t.team) };
  }

  get size() {
    return this.fighters.size;
  }

  get isFull() {
    return this.fighters.size >= MAX_PLAYERS_PER_ROOM;
  }

  get players(): readonly Fighter[] {
    return [...this.fighters.values()];
  }

  addPlayer(id: string, name: string, characterId?: string) {
    const index = this.freeIndex();
    const team = this.rules.mode === "teams" ? this.smallerTeam() : 0;
    const fighter = createFighter(
      {
        id,
        name: name.slice(0, 16) || "Bonobo",
        characterId: getCharacter(characterId).id,
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

  removePlayer(id: string) {
    this.fighters.delete(id);
    this.slots.delete(id);
  }

  // I dati arrivano dalla rete: si tengono solo booleani
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
    if (this.winnerId) this.restartMatch();
  }

  // Un passo di simulazione; restituisce gli eventi nati da allora (anche fuori dal passo, es. la rivincita)
  step(dtMs: number): GameEvent[] {
    const list = this.players as Fighter[];
    stepWorld(list, dtMs, this.ctx);
    this.updateMatch(list, dtMs);
    const events = this.ctx.events;
    this.ctx.events = [];
    return events;
  }

  snapshot(events: GameEvent[], t: number): GameSnapshot {
    const players: PlayerState[] = [];
    for (const f of this.fighters.values()) {
      players.push({
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
      });
    }
    return { t, players, winnerId: this.winnerId, timeLeftMs: this.timeLeftMs(), events };
  }

  // Si entra nella squadra con meno giocatori (a parità, la Rossa)
  private smallerTeam(): 1 | 2 {
    let one = 0;
    let two = 0;
    for (const f of this.fighters.values()) {
      if (f.team === 1) one++;
      if (f.team === 2) two++;
    }
    return two < one ? 2 : 1;
  }

  private teamColor(team: 1 | 2): number {
    const used = new Set([...this.fighters.values()].map((f) => f.color));
    return TEAM_COLORS[team].find((c) => !used.has(c)) ?? TEAM_COLORS[team][0];
  }

  private freeIndex(): number {
    const used = new Set(this.slots.values());
    for (let i = 0; i < MAX_PLAYERS_PER_ROOM; i++) if (!used.has(i)) return i;
    return 0;
  }

  // Vince l'ultimo (o l'ultima squadra) con vite rimaste, o chi è avanti allo scadere del tempo.
  // Dopo una pausa, o se qualcuno chiede la rivincita, si ricomincia.
  private updateMatch(list: Fighter[], dt: number) {
    if (this.winnerId) {
      this.restartTimer -= dt;
      if (this.restartTimer <= 0) this.restartMatch();
      return;
    }
    if (list.length >= 2) this.matchTimeMs += dt; // il tempo corre solo quando c'è qualcuno contro cui giocare
    const timeUp = this.rules.timeLimitSec > 0 && this.matchTimeMs >= this.rules.timeLimitSec * 1000;
    const winner = lastStanding(this.rules, list) ?? (timeUp ? leaderOnTime(this.rules, list) : undefined);
    if (winner) {
      this.winnerId = winner.id;
      this.restartTimer = MATCH_RESTART_MS;
      this.ctx.events.push({ type: "matchEnd", winnerId: winner.id, winnerTeam: winner.team, durationMs: Math.round(this.matchTimeMs) });
    } else if (list.length > 0 && list.every((f) => f.eliminated)) {
      this.restartMatch(); // chi gioca da solo e finisce le vite riparte subito
    }
  }

  private restartMatch() {
    this.winnerId = null;
    this.matchTimeMs = 0;
    for (const f of this.fighters.values()) resetForMatch(f, this.slots.get(f.id) ?? 0, this.rules.stocks, this.stage);
    this.ctx.events.push({ type: "matchStart" });
  }

  private timeLeftMs(): number | null {
    if (this.rules.timeLimitSec <= 0) return null;
    return Math.max(0, Math.round(this.rules.timeLimitSec * 1000 - this.matchTimeMs));
  }
}
