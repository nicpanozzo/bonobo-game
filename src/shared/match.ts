// Una partita intera, senza rete e senza orologio: giocatori, regole, vittoria, eventi.
// Il server la fa avanzare a passo fisso e manda gli snapshot; un client potrebbe farla
// girare in locale (allenamento, predizione) e un porting su un altro motore parte da qui.

import { getCharacter } from "./characters";
import { COLORS, FIGHTER, MATCH_RESTART_MS, MAX_PLAYERS_PER_ROOM, RECONNECT_RESUME_INVULNERABLE_MS, TEAM_COLORS } from "./constants";
import { createFighter, emptyInput, resetForMatch, stepWorld, type Fighter, type PhysicsContext } from "./physics";
import { createItemWorld, handleItemInput, itemStates, resetItems, stepItems, type ItemWorld } from "./physics/items";
import { canHitWithRules, flagWinnerTeam, isTeamMode, lastStanding, leaderOnTime, sanitizeRules } from "./rules";
import { COURSE_PREFIX, seedFromCourseId } from "./courseGenerator";
import { seedFromStageId } from "./stageGenerator";
import { getStage, type StageSpec } from "./stages";
import type { GameEvent, GameSnapshot, InputState, MatchRules, PlayerState } from "./types";

export interface MatchOptions {
  stageId?: string;
  rules?: Partial<MatchRules>;
}

export type MatchEndEvent = Extract<GameEvent, { type: "matchEnd" }>;

// 16 caratteri veri: slice() spezzerebbe un'emoji a metà (il server ripulisce già i nomi con sanitizeName)
const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const shortName = (name: string) =>
  Array.from(graphemes.segment(name), (s) => s.segment)
    .slice(0, 16)
    .join("");

export class Match {
  readonly stage: StageSpec;
  readonly rules: MatchRules;
  private fighters = new Map<string, Fighter>();
  private slots = new Map<string, number>(); // posto di ognuno (0-7): decide partenza e colore
  private winnerId: string | null = null;
  private restartTimer = 0;
  private matchTimeMs = 0;
  private ctx: PhysicsContext;
  private scores: Record<1 | 2, number> = { 1: 0, 2: 0 }; // solo in Bandiera
  private items: ItemWorld | null; // oggetti (#17): solo in Tutti contro tutti e Squadre

  constructor(options: MatchOptions = {}) {
    this.rules = sanitizeRules(options.rules);
    this.stage = stageFor(this.rules, options.stageId);
    const rules = this.rules;
    this.ctx = {
      stage: this.stage,
      events: [],
      canHit: (a, t) => canHitWithRules(rules, a.team, t.team),
      unlimitedStocks: rules.mode === "flag" || rules.mode === "race",
    };
    this.items = rules.mode === "ffa" || rules.mode === "teams" ? createItemWorld(seedOf(this.stage.id)) : null;
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
    const team = isTeamMode(this.rules) ? this.smallerTeam() : 0;
    const fighter = createFighter(
      {
        id,
        name: shortName(name) || "Bonobo",
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
    this.assignFlags();
  }

  removePlayer(id: string) {
    this.fighters.delete(id);
    this.slots.delete(id);
    this.assignFlags(); // se se ne va il portabandiera, la bandiera passa a un compagno
  }

  // I dati arrivano dalla rete: si tengono solo booleani
  setInput(id: string, input: InputState) {
    const f = this.fighters.get(id);
    if (!f || f.away) return;
    f.input = {
      left: !!input.left,
      right: !!input.right,
      up: !!input.up,
      down: !!input.down,
      light: !!input.light,
      heavy: !!input.heavy,
      taunt: !!input.taunt,
      dodge: !!input.dodge,
    };
  }

  // Caduta di rete (#107): il lottatore resta fermo e intoccabile finché il giocatore rientra o il posto scade.
  // Al rientro è invulnerabile ancora un attimo, per riprendere la mano
  setAway(id: string, away: boolean) {
    const f = this.fighters.get(id);
    if (!f || f.away === away) return;
    f.away = away;
    f.input = emptyInput();
    f.prevInput = emptyInput();
    if (away) {
      f.vx = f.vy = 0;
      f.attackActive = false;
      f.invulnerable = true;
    } else {
      f.invulnerableTimer = Math.max(f.invulnerableTimer, RECONNECT_RESUME_INVULNERABLE_MS);
      f.invulnerable = true;
    }
    this.ctx.events.push({ type: away ? "away" : "back", id });
  }

  // A fine partita chiunque può ricominciare subito, senza aspettare il conto alla rovescia
  requestRematch() {
    if (this.winnerId) this.restartMatch();
  }

  // Un passo di simulazione; restituisce gli eventi nati da allora (anche fuori dal passo, es. la rivincita)
  step(dtMs: number): GameEvent[] {
    const list = this.players as Fighter[];
    // Gli oggetti cadono solo quando c'è qualcuno con cui litigarseli e la partita non è finita
    const items = this.items && list.length >= 2 && !this.winnerId ? this.items : null;
    if (items) handleItemInput(items, list, this.ctx);
    stepWorld(list, dtMs, this.ctx);
    if (items) stepItems(items, list, dtMs, this.ctx);
    if (this.rules.mode === "flag" && !this.winnerId) this.scoreFlags();
    if (this.rules.mode === "race" && !this.winnerId) this.updateCheckpoints(list);
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
        carrier: f.carrier,
        ledge: f.ledge,
        away: f.away,
      });
    }
    const teamScores = this.rules.mode === "flag" ? { ...this.scores } : null;
    const stageMs = Math.round(this.ctx.timeMs ?? 0);
    const items = this.items ? itemStates(this.items) : [];
    return { t, players, winnerId: this.winnerId, timeLeftMs: this.timeLeftMs(), teamScores, items, events, stageMs };
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

  // Bandiera (#56): ogni squadra con almeno un giocatore ha un portabandiera
  private assignFlags(except?: Fighter) {
    if (this.rules.mode !== "flag") return;
    for (const team of [1, 2]) {
      const members = this.teamBySlot(team);
      if (members.length === 0 || members.some((f) => f.carrier)) continue;
      // Il prossimo dopo chi l'ha appena persa, così la portano tutti a turno
      const from = except ? members.indexOf(except) : -1;
      members[(from + 1) % members.length].carrier = true;
    }
  }

  private teamBySlot(team: number): Fighter[] {
    return this.players.filter((f) => f.team === team).sort((a, b) => (this.slots.get(a.id) ?? 0) - (this.slots.get(b.id) ?? 0));
  }

  // Un portabandiera buttato fuori dà un punto all'altra squadra e passa la bandiera
  private scoreFlags() {
    for (const e of [...this.ctx.events]) {
      if (e.type !== "ko") continue;
      const f = this.fighters.get(e.id);
      if (!f?.carrier) continue;
      const scoringTeam = f.team === 1 ? 2 : 1;
      this.scores[scoringTeam] += 1;
      f.carrier = false;
      this.assignFlags(f);
      const next = this.teamBySlot(f.team).find((m) => m.carrier);
      this.ctx.events.push({ type: "flag", scoringTeam, byId: e.byId, team: f.team, carrierId: next?.id ?? null });
    }
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
    const winner =
      this.rules.mode === "flag"
        ? this.flagWinner(timeUp)
        : this.rules.mode === "race"
          ? this.raceWinner(list, timeUp)
          : (lastStanding(this.rules, list) ?? (timeUp ? leaderOnTime(this.rules, list) : undefined));
    if (winner) {
      this.winnerId = winner.id;
      this.restartTimer = MATCH_RESTART_MS;
      this.ctx.events.push({ type: "matchEnd", winnerId: winner.id, winnerTeam: winner.team, durationMs: Math.round(this.matchTimeMs) });
    } else if (list.length > 0 && list.every((f) => f.eliminated)) {
      this.restartMatch(); // chi gioca da solo e finisce le vite riparte subito
    }
  }

  // Corsa (#57): toccando un checkpoint più avanti lo si fa proprio
  private updateCheckpoints(list: Fighter[]) {
    const cps = this.stage.checkpoints ?? [];
    for (const f of list) {
      if (f.respawning || !f.onGround) continue;
      let i = f.checkpoint;
      while (i + 1 < cps.length && f.x >= cps[i + 1].x) i++;
      if (i === f.checkpoint) continue;
      f.checkpoint = i;
      this.ctx.events.push({ type: "checkpoint", id: f.id, index: i });
    }
  }

  // Vince chi tocca il traguardo; allo scadere del tempo chi è arrivato più avanti
  private raceWinner(list: Fighter[], timeUp: boolean): Fighter | undefined {
    const g = this.stage.goal;
    const half = FIGHTER.width / 2;
    const touching = g && list.find((f) => !f.respawning && f.x + half > g.x && f.x - half < g.x + g.width && f.y > g.y && f.y - FIGHTER.height < g.y + g.height);
    if (touching) return touching;
    if (!timeUp || list.length === 0) return undefined;
    return [...list].sort((a, b) => (b.respawning ? -Infinity : b.x) - (a.respawning ? -Infinity : a.x))[0];
  }

  private flagWinner(timeUp: boolean): Fighter | undefined {
    const team = flagWinnerTeam(this.rules, this.scores, timeUp);
    if (!team) return undefined;
    const members = this.teamBySlot(team);
    return members.find((f) => f.carrier) ?? members[0];
  }

  private restartMatch() {
    this.winnerId = null;
    this.matchTimeMs = 0;
    this.scores = { 1: 0, 2: 0 };
    if (this.items) resetItems(this.items);
    for (const f of this.fighters.values()) resetForMatch(f, this.slots.get(f.id) ?? 0, this.rules.stocks, this.stage);
    this.assignFlags(); // si riparte dal primo di ogni squadra
    this.ctx.events.push({ type: "matchStart" });
  }

  private timeLeftMs(): number | null {
    if (this.rules.timeLimitSec <= 0) return null;
    return Math.max(0, Math.round(this.rules.timeLimitSec * 1000 - this.matchTimeMs));
  }
}

// Seme degli oggetti dall'id dell'arena: stessa arena, stessa sequenza
function seedOf(id: string): number {
  let h = 2166136261;
  for (let i = 0; i < id.length; i++) h = Math.imul(h ^ id.charCodeAt(i), 16777619);
  return h >>> 0;
}

// In Corsa serve un percorso: se l'arena scelta non lo è, se ne genera uno dal suo seme
function stageFor(rules: MatchRules, stageId: string | undefined): StageSpec {
  const stage = getStage(stageId);
  if (rules.mode !== "race") return stage.goal ? getStage(undefined) : stage; // un percorso fuori dalla Corsa non ha senso
  if (stage.goal) return stage;
  const seed = (stageId && (seedFromCourseId(stageId) ?? seedFromStageId(stageId))) || 1;
  return getStage(`${COURSE_PREFIX}${seed}`);
}
