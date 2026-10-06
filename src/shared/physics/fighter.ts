// Lo stato completo di un lottatore sul server: quello che vedono i client (PlayerState)
// più i timer interni che non viaggiano in rete.

import { FIGHTER } from "../constants";
import type { StageSpec } from "../stages";
import type { GameEvent, InputState, PlayerState } from "../types";

export interface Fighter extends PlayerState {
  input: InputState;
  prevInput: InputState; // per riconoscere quando un tasto viene appena premuto
  jumpsLeft: number;
  dropTimer: number; // ms in cui si ignorano le piattaforme sottili
  attackTimer: number; // ms dall'inizio dell'attacco in corso
  cooldownTimer: number; // ms prima di poter attaccare ancora
  hitstunTimer: number;
  respawnTimer: number;
  invulnerableTimer: number;
  alreadyHit: Set<string>; // chi ha già preso questo colpo
  lastHitById: string | null; // chi l'ha colpito per ultimo: a lui va il KO
}

// Quello che serve alla fisica oltre ai lottatori: l'arena e dove scrivere gli eventi
export interface PhysicsContext {
  stage: StageSpec;
  events: GameEvent[];
  canHit?: (attacker: Fighter, target: Fighter) => boolean; // es. niente fuoco amico (#17)
  unlimitedStocks?: boolean; // chi esce non perde vite (es. Bandiera, #56): torna e basta
}

export const emptyInput = (): InputState => ({
  left: false,
  right: false,
  up: false,
  down: false,
  light: false,
  heavy: false,
  taunt: false,
});

export interface FighterSetup {
  id: string;
  name: string;
  characterId: string;
  color: number;
  team: number;
  index: number; // posto nella stanza: decide punto di partenza e verso
  stocks: number;
}

export function createFighter(s: FighterSetup, stage: StageSpec): Fighter {
  const spawn = stage.spawns[s.index % stage.spawns.length];
  return {
    id: s.id,
    name: s.name,
    characterId: s.characterId,
    color: s.color,
    team: s.team,
    x: spawn.x,
    y: spawn.y,
    vx: 0,
    vy: 0,
    facing: s.index % 2 === 0 ? 1 : -1,
    percent: 0,
    stocks: s.stocks,
    onGround: true,
    attack: null,
    attackActive: false,
    hitstun: false,
    respawning: false,
    invulnerable: false,
    eliminated: false,
    carrier: false,
    input: emptyInput(),
    prevInput: emptyInput(),
    jumpsLeft: FIGHTER.maxJumps,
    dropTimer: 0,
    attackTimer: 0,
    cooldownTimer: 0,
    hitstunTimer: 0,
    respawnTimer: 0,
    invulnerableTimer: 0,
    alreadyHit: new Set(),
    lastHitById: null,
  };
}

// Riporta un lottatore all'inizio partita, tenendo i tasti che sta premendo
export function resetForMatch(f: Fighter, index: number, stocks: number, stage: StageSpec): void {
  const fresh = createFighter({ ...f, index, stocks }, stage);
  Object.assign(f, fresh, { input: f.input, prevInput: f.prevInput });
}

export const isAlive = (f: Fighter) => !f.eliminated;

export const pressed = (f: Fighter, key: keyof InputState) => f.input[key] && !f.prevInput[key];
