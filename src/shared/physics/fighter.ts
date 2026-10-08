// Lo stato completo di un lottatore sul server: quello che vedono i client (PlayerState)
// più i timer interni che non viaggiano in rete.

import { FIGHTER, INPUT, SHIELD } from "../constants";
import type { StageSpec } from "../stages";
import type { GameEvent, InputState, PlayerState, SpecialKind } from "../types";
import type { ProjectileWorld } from "./projectiles";

export interface Fighter extends PlayerState {
  input: InputState;
  prevInput: InputState; // per riconoscere quando un tasto viene appena premuto
  buffer: Record<BufferedKey, number>; // ms in cui una pressione vale ancora (E6): si consuma quando l'azione parte
  jumpsLeft: number;
  dropTimer: number; // ms in cui si ignorano le piattaforme sottili
  attackTimer: number; // ms dall'inizio dell'attacco in corso
  cooldownTimer: number; // ms prima di poter attaccare ancora
  hitstunTimer: number;
  hitstopTimer: number; // ms di fermo dopo un colpo dato o preso (#15)
  recoveryUsed: boolean; // la mossa di recupero è già stata usata in questo salto (#11)
  helpless: boolean; // dopo il recupero non si attacca fino all'atterraggio
  dodgeTimer: number; // ms di schivata ancora in corso (#3)
  dodgeCooldown: number; // ms prima di poter schivare di nuovo
  airDodgeUsed: boolean; // in aria si schiva una volta sola fino all'atterraggio
  respawnTimer: number;
  invulnerableTimer: number;
  alreadyHit: Set<string>; // chi ha già preso questo colpo
  lastHitById: string | null; // chi l'ha colpito per ultimo: a lui va il KO
  checkpoint: number; // in Corsa (#57): indice dell'ultimo checkpoint toccato, da lì si riparte
  riding: number; // indice della piattaforma mobile su cui si sta (#14), -1 se nessuna
  hazardTimer: number; // ms prima di poter prendere un'altra trappola (#14)
  ledgeIndex: number; // spigolo a cui si è appesi, indice in ledgesOf(stage) (#110), -1 se nessuno
  ledgeTimer: number; // ms passati appesi
  ledgeGrabs: number; // prese del bordo da quando si è toccato terra o si è stati colpiti
  regrabTimer: number; // ms prima di potersi aggrappare di nuovo
  shieldTimer: number; // ms da quando si tiene lo scudo (#109): para da SHIELD.raiseMs
  shieldDropTimer: number; // ms fermi dopo averlo abbassato
  shieldStunTimer: number; // ms fermi sullo scudo dopo un colpo parato
  stunTimer: number; // ms storditi dopo la rottura dello scudo
  holding: string | null; // id di chi si tiene con la presa (#109)
  grabLagTimer: number; // ms fermi per la presa: avvio, finestra attiva e attesa se va a vuoto
  grabTimer: number; // per chi è tenuto: ms prima di liberarsi da solo (i tasti premuti lo accorciano)
  pummelTimer: number; // per chi tiene: ms prima del prossimo colpetto
  specialTimer: number; // ms fermi per la speciale in corso (E10): avvio, scatto o finestra, attesa finale
  airDashUsed: boolean; // lo scatto in aria si fa una volta sola fino all'atterraggio
  projectileTimer: number; // ms all'uscita del proiettile della speciale in corso (E10), 0 se nessuno
  chargeMs: number; // ms di carica della speciale tenuta premuta (E10), -1 se non si carica
  chargeMultiplier: number; // moltiplicatore del colpo caricato in corso (1 per tutti gli altri)
  pendingSpecial: SpecialKind | null; // la speciale che aspetta: proiettile in uscita o carica tenuta
}

// Quello che serve alla fisica oltre ai lottatori: l'arena e dove scrivere gli eventi
export interface PhysicsContext {
  stage: StageSpec;
  events: GameEvent[];
  canHit?: (attacker: Fighter, target: Fighter) => boolean; // es. niente fuoco amico (#17)
  unlimitedStocks?: boolean; // chi esce non perde vite (es. Bandiera, #56): torna e basta
  timeMs?: number; // tempo dell'arena in ms: muove ascensori e trappole (#14). Lo fa avanzare stepWorld
  projectiles?: ProjectileWorld; // proiettili in volo (E10): li crea match.ts, o il primo tiro
}

export const emptyInput = (): InputState => ({
  left: false,
  right: false,
  up: false,
  jump: false,
  down: false,
  light: false,
  heavy: false,
  taunt: false,
  dodge: false,
  shield: false,
  special: false,
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
    ledge: null,
    away: false,
    shielding: false,
    shieldHp: SHIELD.maxHp,
    stunned: false,
    grabbedBy: null,
    input: emptyInput(),
    prevInput: emptyInput(),
    buffer: emptyBuffer(),
    jumpsLeft: FIGHTER.maxJumps,
    dropTimer: 0,
    attackTimer: 0,
    cooldownTimer: 0,
    hitstunTimer: 0,
    hitstopTimer: 0,
    recoveryUsed: false,
    helpless: false,
    dodgeTimer: 0,
    dodgeCooldown: 0,
    airDodgeUsed: false,
    respawnTimer: 0,
    invulnerableTimer: 0,
    alreadyHit: new Set(),
    lastHitById: null,
    checkpoint: 0,
    riding: -1,
    hazardTimer: 0,
    ledgeIndex: -1,
    ledgeTimer: 0,
    ledgeGrabs: 0,
    regrabTimer: 0,
    shieldTimer: 0,
    shieldDropTimer: 0,
    shieldStunTimer: 0,
    stunTimer: 0,
    holding: null,
    grabLagTimer: 0,
    grabTimer: 0,
    pummelTimer: 0,
    specialTimer: 0,
    airDashUsed: false,
    charge: 0,
    projectileTimer: 0,
    chargeMs: -1,
    chargeMultiplier: 1,
    pendingSpecial: null,
  };
}

// Riporta un lottatore all'inizio partita, tenendo i tasti che sta premendo
export function resetForMatch(f: Fighter, index: number, stocks: number, stage: StageSpec): void {
  const fresh = createFighter({ ...f, index, stocks }, stage);
  Object.assign(f, fresh, { input: f.input, prevInput: f.prevInput, away: f.away }); // chi è disconnesso resta tale nella rivincita
}

export const isAlive = (f: Fighter) => !f.eliminated;

// Tasti col buffer (E6): una pressione più corta di un tick, o arrivata un attimo prima che l'azione
// possa partire (fine del colpo, atterraggio), conta lo stesso per INPUT.bufferMs
export const BUFFERED_KEYS = ["light", "heavy", "up", "jump", "dodge", "special"] as const;
export type BufferedKey = (typeof BUFFERED_KEYS)[number];
const isBuffered = (key: keyof InputState): key is BufferedKey => (BUFFERED_KEYS as readonly string[]).includes(key);
export const emptyBuffer = (): Record<BufferedKey, number> => ({ light: 0, heavy: 0, up: 0, jump: 0, dodge: 0, special: 0 });

export const pressed = (f: Fighter, key: keyof InputState) =>
  (f.input[key] && !f.prevInput[key]) || (isBuffered(key) && f.buffer[key] > 0);

// Un tasto nuovo arrivato dalla rete (Match.setInput): i fronti di salita finiscono nel buffer
export function bufferPresses(f: Fighter, next: InputState): void {
  for (const key of BUFFERED_KEYS) if (next[key] && !f.input[key]) f.buffer[key] = INPUT.bufferMs;
}

// L'azione è partita: la pressione è usata e non fa partire niente altro
export function consume(f: Fighter, ...keys: BufferedKey[]): void {
  for (const key of keys) f.buffer[key] = 0;
}

export function tickBuffer(f: Fighter, dtMs: number): void {
  for (const key of BUFFERED_KEYS) f.buffer[key] = Math.max(0, f.buffer[key] - dtMs);
}
