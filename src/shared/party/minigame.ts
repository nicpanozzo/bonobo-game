// Bonobo Party (#579): cosa è un minigioco. Ognuno è una partita normale (match.ts, stessi lottatori, stesse mosse)
// più una regola: questo file dice cosa la regola può fare. La partita la chiama a ogni passo dopo la fisica.
// Niente animazioni nuove: un minigioco cambia arena, obiettivo e punti, e disegna solo oggetti di scena (PartyProp).

import { HITSTUN_PER_KNOCKBACK } from "../constants";
import type { Fighter, PhysicsContext } from "../physics";
import type { StageSpec } from "../stages";
import type { GameEvent, InputState, MatchRules, MinigameHud, MinigameInfo, PartyProp } from "../types";

// Quello che il minigioco può chiedere alla partita, oltre ai lottatori che gli passa a ogni passo
export interface MinigameApi {
  // Un lottatore in più guidato dal minigioco (es. i fantasmi di Ieri Me): ghostOf = di chi è, per i punti e il disegno
  addGhost(id: string, ghostOf: string): Fighter | null;
  removeGhost(id: string): void;
}

export interface MinigameRuntime {
  // Al VIA (fine del conto alla rovescia): da qui il tempo del minigioco corre
  start?(fighters: Fighter[], ctx: PhysicsContext, api: MinigameApi): void;
  // Un passo dopo la fisica. events = quelli di questo passo (colpi, KO, attacchi...)
  step(fighters: Fighter[], ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[], api: MinigameApi): void;
  // Chi può colpire chi, oltre alle regole della partita (es. a Mezzogiorno di Fuoco nessuno)
  canHit?(attacker: Fighter, target: Fighter): boolean;
  // I tasti di id prima di arrivare al suo lottatore (es. Un Solo Tasto ne lascia uno). Resta lo stesso lottatore
  mapInput?(id: string, input: InputState): InputState;
  // Per i bot: dove andare (es. la banana più vicina), o i tasti da premere; null = gioca come in una partita
  botGoal?(f: Fighter, fighters: readonly Fighter[]): { x: number; y: number } | null;
  botInput?(f: Fighter, fighters: readonly Fighter[]): InputState | null;
  hud(): Omit<MinigameHud, "id" | "places">;
  done(): boolean;
  // A fine minigioco: posto di ognuno (1 = primo, a pari merito stesso posto)
  places(ids: string[]): Record<string, number>;
}

export interface MinigameSetup {
  stage: StageSpec;
  rules: Partial<MatchRules>; // modalità, vite e tempo della partita sotto il minigioco
  unlimitedStocks?: boolean; // chi esce torna e basta (di solito sì: si gioca a punti)
  roles?: Record<string, string>;
  runtime: MinigameRuntime;
}

export interface MinigameDef {
  info: Omit<MinigameInfo, "roles">;
  minPlayers?: number; // sotto non si pesca (es. 1 contro tutti vuole almeno 2 giocatori)
  build(seed: number, playerIds: string[]): MinigameSetup;
}

// Posti dai punti: più punti = meglio (o meno, con lowerIsBetter). A pari punti stesso posto, il prossimo salta
export function placesFromScores(ids: string[], scores: Record<string, number>, lowerIsBetter = false): Record<string, number> {
  const val = (id: string) => scores[id] ?? (lowerIsBetter ? Infinity : -Infinity);
  const sorted = [...ids].sort((a, b) => (lowerIsBetter ? val(a) - val(b) : val(b) - val(a)));
  const places: Record<string, number> = {};
  sorted.forEach((id, i) => {
    const prev = sorted[i - 1];
    places[id] = i > 0 && val(prev) === val(id) ? places[prev] : i + 1;
  });
  return places;
}

// Il centro del corpo di un lottatore (y sono i piedi): per raccogliere e toccare le cose
export const bodyCenter = (f: Fighter) => ({ x: f.x, y: f.y - 40 });

// Un oggetto di scena tondo a (x, y) di raggio r tocca il lottatore?
export function touches(f: Fighter, x: number, y: number, r: number): boolean {
  if (f.respawning || f.eliminated) return false;
  return Math.abs(f.x - x) < 26 + r && y > f.y - 90 - r && y < f.y + r;
}

// Un colpo dato dall'arena (un autobus, un muro): fa volare come un colpo vero, con la stessa sospensione dei comandi,
// senza percentuale e senza un autore (nessuno prende il KO)
export function bump(f: Fighter, vx: number, vy: number) {
  if (f.respawning || f.eliminated) return;
  f.vx = vx;
  f.vy = vy;
  f.onGround = false;
  f.hitstunTimer = Math.hypot(vx, vy) * HITSTUN_PER_KNOCKBACK;
  f.attack = null;
  f.attackActive = false;
}

// Base per i minigiochi a tempo con i punti: conta il tempo, tiene punti e chi è fuori, e fa l'HUD
export abstract class TimedGame implements MinigameRuntime {
  protected scores: Record<string, number> = {};
  protected out = new Set<string>();
  protected leftMs: number;
  protected started = false;
  protected text: string | null = null;
  protected props: PartyProp[] = [];

  constructor(
    protected durationMs: number,
    protected unit: string,
  ) {
    this.leftMs = durationMs;
  }

  start(fighters: Fighter[], ctx: PhysicsContext, api: MinigameApi) {
    this.started = true;
    for (const f of fighters) this.scores[f.id] ??= 0;
    this.onStart(fighters, ctx, api);
  }

  step(fighters: Fighter[], ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[], api: MinigameApi) {
    if (!this.started || this.done()) return;
    for (const f of fighters) this.scores[f.id] ??= 0; // chi entra a metà parte da zero
    this.leftMs = Math.max(0, this.leftMs - dtMs);
    this.onStep(fighters, ctx, dtMs, events, api);
  }

  protected onStart(_fighters: Fighter[], _ctx: PhysicsContext, _api: MinigameApi): void {}
  protected abstract onStep(fighters: Fighter[], ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[], api: MinigameApi): void;

  done(): boolean {
    return this.started && this.leftMs <= 0;
  }

  places(ids: string[]): Record<string, number> {
    return placesFromScores(ids, this.scores);
  }

  hud(): Omit<MinigameHud, "id" | "places"> {
    return { scores: { ...this.scores }, unit: this.unit, text: this.text, leftMs: Math.round(this.leftMs), out: [...this.out], props: this.props };
  }
}
