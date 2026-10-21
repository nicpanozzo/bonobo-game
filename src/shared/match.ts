// Una partita intera, senza rete e senza orologio: giocatori, regole, vittoria, eventi.
// Il server la fa avanzare a passo fisso e manda gli snapshot; un client potrebbe farla
// girare in locale (allenamento, predizione) e un porting su un altro motore parte da qui.

import { getCharacter, skinFor } from "./characters";
import { COLORS, FIGHTER, ITEM_AMOUNTS, MATCH_RESTART_MS, MAX_PLAYERS_PER_ROOM, RECONNECT_RESUME_INVULNERABLE_MS, TEAM_COLORS, TRAINING } from "./constants";
import { bufferPresses, createFighter, emptyInput, resetForMatch, stepWorld, type Fighter, type PhysicsContext } from "./physics";
import { createItemWorld, handleItemInput, itemStates, resetItems, stepItems, type ItemWorld } from "./physics/items";
import { companionState } from "./physics/companion";
import { tetrisState } from "./physics/arcade";
import { createProjectileWorld, projectileStates, puddleStates, type ProjectileWorld } from "./physics/projectiles";
import { canHitWithRules, flagWinnerTeam, isTeamMode, lastStanding, leaderOnTime, requestedTeam, sanitizeRules } from "./rules";
import { COURSE_PREFIX, seedFromCourseId } from "./courseGenerator";
import { seedFromStageId } from "./stageGenerator";
import { getStage, type StageSpec } from "./stages";
import type { GameEvent, GameSnapshot, InputState, MatchRules, PlayerState, PredictionState } from "./types";

export interface MatchOptions {
  stageId?: string;
  rules?: Partial<MatchRules>;
  items?: boolean; // false = niente oggetti anche dove ci sarebbero (es. i test di bilanciamento dei personaggi, #302)
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
  private pendingTeams = new Map<string, number>(); // cambi di squadra chiesti a partita in corso (#409)
  private items: ItemWorld | null; // oggetti (#17): solo in Tutti contro tutti e Squadre
  private projectiles: ProjectileWorld = createProjectileWorld(); // proiettili delle speciali (E10)

  constructor(options: MatchOptions = {}) {
    this.rules = sanitizeRules(options.rules);
    this.stage = stageFor(this.rules, options.stageId);
    const rules = this.rules;
    this.ctx = {
      stage: this.stage,
      events: [],
      canHit: (a, t) => canHitWithRules(rules, a.team, t.team),
      unlimitedStocks: rules.mode === "flag" || rules.mode === "race" || rules.mode === "training",
      projectiles: this.projectiles,
    };
    const amount = ITEM_AMOUNTS[rules.itemAmount];
    const withItems = options.items !== false && (rules.mode === "ffa" || rules.mode === "teams") && amount.maxOnStage > 0 && rules.itemKinds.length > 0;
    this.items = withItems ? createItemWorld(seedOf(this.stage.id), { everyMs: amount.everyMs, maxOnStage: amount.maxOnStage, kinds: rules.itemKinds }) : null;
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

  // team: la squadra chiesta (#409); se non c'è in queste regole si entra in quella con meno giocatori
  addPlayer(id: string, name: string, characterId?: string, skinId?: string, wantedTeam?: number) {
    const index = this.freeIndex();
    const team = isTeamMode(this.rules) ? requestedTeam(this.rules, wantedTeam) || this.smallerTeam() : 0;
    const fighter = createFighter(
      {
        id,
        name: shortName(name) || "Bonobo",
        characterId: getCharacter(characterId).id,
        skinId: skinFor(characterId, skinId),
        color: team ? this.teamColor(team) : COLORS[index],
        team,
        index,
        stocks: this.rules.stocks,
        supremeRate: this.rules.supremeSpeed,
      },
      this.stage,
    );
    this.slots.set(id, index);
    this.fighters.set(id, fighter);
    this.assignFlags();
  }

  // Cambio di squadra (#409): a partita ferma (da soli o a fine partita) subito, altrimenti dalla prossima,
  // così nessuno passa alla squadra che sta vincendo a metà partita
  setTeam(id: string, wanted: unknown) {
    const f = this.fighters.get(id);
    const team = requestedTeam(this.rules, wanted);
    if (!f || !team) return;
    if (team === f.team) {
      this.pendingTeams.delete(id);
      return;
    }
    if (this.winnerId || this.matchTimeMs === 0) this.moveToTeam(f, team);
    else this.pendingTeams.set(id, team);
  }

  // La squadra in cui passerà alla prossima partita, se l'ha chiesto
  pendingTeam(id: string): number | undefined {
    return this.pendingTeams.get(id);
  }

  private moveToTeam(f: Fighter, team: number) {
    this.pendingTeams.delete(f.id);
    f.carrier = false;
    f.team = team;
    f.color = this.teamColor(team, f);
    this.assignFlags();
  }

  removePlayer(id: string) {
    this.pendingTeams.delete(id);
    this.fighters.delete(id);
    this.slots.delete(id);
    this.assignFlags(); // se se ne va il portabandiera, la bandiera passa a un compagno
  }

  // I dati arrivano dalla rete: si tengono solo booleani
  setInput(id: string, input: InputState) {
    const f = this.fighters.get(id);
    if (!f || f.away) return;
    const next: InputState = {
      left: !!input.left,
      right: !!input.right,
      up: !!input.up,
      jump: !!input.jump,
      down: !!input.down,
      light: !!input.light,
      heavy: !!input.heavy,
      taunt: !!input.taunt,
      dodge: !!input.dodge,
      shield: !!input.shield,
      special: !!input.special,
      supreme: !!input.supreme,
      run: !!input.run,
    };
    bufferPresses(f, next); // una pressione più corta di un tick non si perde (E6)
    f.input = next;
    if (input.seq !== undefined) {
      f.inputSeq = input.seq;
      f.inputTicks = 0;
    }
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

  // Allenamento (#113): la percentuale di un lottatore, scelta dal pannello (fuori dalla fisica)
  setPercent(id: string, value: number) {
    const f = this.fighters.get(id);
    if (f && Number.isFinite(value)) f.percent = Math.max(0, Math.min(TRAINING.maxPercent, Math.round(value)));
  }

  // Allenamento: tutti tornano al loro posto come a inizio partita
  reset() {
    this.restartMatch();
  }

  // Un passo di simulazione; restituisce gli eventi nati da allora (anche fuori dal passo, es. la rivincita)
  step(dtMs: number): GameEvent[] {
    const list = this.players as Fighter[];
    // Gli oggetti cadono solo quando c'è qualcuno con cui litigarseli e la partita non è finita
    const items = this.items && list.length >= 2 && !this.winnerId ? this.items : null;
    if (items) handleItemInput(items, list, this.ctx);
    stepWorld(list, dtMs, this.ctx);
    for (const f of list) f.inputTicks++; // E17: il client rigioca da qui il proprio movimento
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
        skinId: f.skinId,
        color: f.color,
        team: f.team,
        ...(this.pendingTeams.has(f.id) ? { nextTeam: this.pendingTeams.get(f.id) } : {}),
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
        shielding: f.shielding,
        shieldHp: Math.round(f.shieldHp),
        stunned: f.stunned,
        grabbedBy: f.grabbedBy,
        dashing: f.dashing,
        ...(f.jumpSquatTimer > 0 && { jumpSquat: Math.round(f.jumpSquatTimer) }),
        ...(f.landingTimer > 0 && { landing: Math.round(f.landingTimer) }),
        charge: f.charge,
        supreme: Math.floor(f.supreme), // per difetto: 100 solo quando è davvero piena
        powerup: f.powerup,
        powerupMs: Math.ceil(f.powerupMs),
        ...(f.inputSeq >= 0 && { predict: predictionState(f) }),
        ...(f.pet && f.pet.koMs <= 0 && { companion: companionState(f)! }),
      });
    }
    const teamScores = this.rules.mode === "flag" ? { ...this.scores } : null;
    const stageMs = Math.round(this.ctx.timeMs ?? 0);
    const items = this.items ? itemStates(this.items) : [];
    const projectiles = projectileStates(this.projectiles);
    const puddles = puddleStates(this.projectiles);
    const pads = this.ctx.padsMs ? [...this.ctx.padsMs] : undefined; // bottoni sonori (#423)
    const tetris = tetrisState(this.ctx); // #427
    return { t, players, winnerId: this.winnerId, timeLeftMs: this.timeLeftMs(), teamScores, items, projectiles, puddles, events, stageMs, ...(pads && { pads }), ...(tetris && { tetris }) };
  }

  // Si entra nella squadra con meno giocatori (a parità, quella col numero più basso: prima la Rossa)
  private smallerTeam(): number {
    const count = new Array<number>(this.rules.teamCount + 1).fill(0);
    for (const f of this.fighters.values()) if (f.team >= 1 && f.team <= this.rules.teamCount) count[f.team]++;
    let best = 1;
    for (let t = 2; t <= this.rules.teamCount; t++) if (count[t] < count[best]) best = t;
    return best;
  }

  // Una tonalità della squadra che nessun altro ha ancora (self: chi cambia squadra non conta il suo colore)
  private teamColor(team: number, self?: Fighter): number {
    const used = new Set([...this.fighters.values()].filter((f) => f !== self).map((f) => f.color));
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
    for (const [id, team] of this.pendingTeams) {
      const f = this.fighters.get(id);
      if (f) this.moveToTeam(f, team);
    }
    this.pendingTeams.clear();
    this.winnerId = null;
    this.matchTimeMs = 0;
    this.scores = { 1: 0, 2: 0 };
    if (this.items) resetItems(this.items);
    this.projectiles.puddles = [];
    this.ctx.arcade = undefined; // via pezzi e blocchi del Tetris (#427)
    this.projectiles.list = []; // gli id continuano: un client non confonde un proiettile vecchio con uno nuovo
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

// E17: il necessario per rigiocare il movimento sul client. I timer in ms interi, come x e y in pixel interi
function predictionState(f: Fighter): PredictionState {
  return {
    seq: f.inputSeq,
    ticks: f.inputTicks,
    jumps: f.jumpsLeft,
    coyote: Math.round(f.coyoteTimer),
    rising: f.jumpRising,
    drop: Math.round(f.dropTimer),
    jumpBuffer: Math.round(f.buffer.jump),
    dash: Math.round(f.dashTimer),
    tapDir: f.dashTapDir,
    tapTimer: Math.round(f.dashTapTimer),
    tapHold: Math.round(f.dashHoldMs),
    dodge: Math.round(f.dodgeTimer),
    dodgeCooldown: Math.round(f.dodgeCooldown),
    airDodge: f.airDodgeUsed,
    dodgeBuffer: Math.round(f.buffer.dodge),
    attackTimer: Math.round(f.attackTimer),
    cooldown: Math.round(f.cooldownTimer),
    hitstop: Math.round(f.hitstopTimer),
    recoveryUsed: f.recoveryUsed,
    helpless: f.helpless,
    lightBuffer: Math.round(f.buffer.light),
    heavyBuffer: Math.round(f.buffer.heavy),
    attackAir: f.attackAir,
  };
}
