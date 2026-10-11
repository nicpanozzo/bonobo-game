// Tracce per il port del movimento in GDScript (E17 passo 3): la fisica vera (src/shared/physics) gioca
// sequenze di tasti fisse, con seme, e si annota lo stato del lottatore a ogni tick. godot/tests/test_prediction.gd
// le rigioca con godot/scripts/predict/movement.gd e pretende le stesse posizioni. Le scrive npm run export:godot
// in godot/tests/data (fuori dal gioco esportato); predictionTraces.test.ts controlla che il file sia aggiornato,
// così chi cambia il movimento solo in TypeScript vede rossa prima una CI e poi l'altra.
//
// Solo il movimento che il client predice: corsa, aria, salti, salto corto, coyote, gravità, caduta veloce,
// piattaforme sottili, scatto con il doppio tocco, schivata, attacchi leggeri e pesanti (fermi a terra) e recupero.
// Una traccia si ferma prima del primo tick fuori da lì (bordo, KO, ascensori).

import { characterStats } from "./characters";
import { TICK_RATE } from "./constants";
import { bufferPresses, createFighter, emptyInput, stepWorld, type Fighter } from "./physics";
import { generateStage, rng } from "./stageGenerator";
import { getStage, type StageSpec } from "./stages";
import type { InputState } from "./types";

const DT = 1000 / TICK_RATE;
const MAX_TICKS = 480;
// Arena, personaggio (statistiche diverse) e seme dei tasti
const CASES: { stage: StageSpec; characterId: string; seed: number }[] = [
  { stage: getStage("palco"), characterId: "default", seed: 47 },
  { stage: getStage("isole"), characterId: "orsoblu", seed: 19 },
  { stage: getStage("palestra"), characterId: "elvedeo", seed: 48 },
  { stage: generateStage(7), characterId: "default", seed: 34 },
  // Il palco con un ponte ad arco (#244) al posto delle due piattaforme basse: si cammina sulla curva
  { stage: { ...getStage("palco"), id: "palco-arco", platforms: [{ x: 340, y: 420, width: 600, arch: 30 }, { x: 540, y: 290, width: 200 }] }, characterId: "bonobot", seed: 150 }, // seme scelto perché cammina a lungo sulla curva
  // Il canale di Padova (#246): ponte ad arco e due scale inclinate che scendono al fondo; seme che ci cammina sopra a lungo
  {
    stage: {
      ...getStage("palco"),
      id: "canale-scala",
      width: 1920,
      solids: [{ x: 100, y: 520, width: 620, height: 200 }, { x: 1200, y: 520, width: 620, height: 200 }, { x: 720, y: 690, width: 480, height: 30 }],
      platforms: [{ x: 720, y: 520, width: 480, arch: 25 }, { x: 742, y: 518, width: 180, y2: 690 }, { x: 998, y: 690, width: 180, y2: 518 }],
      blastZone: { left: -300, right: 2220, top: -420, bottom: 1000 },
    },
    characterId: "orsoblu",
    seed: 58,
  },
];

export interface TraceState {
  x: number;
  y: number;
  vx: number;
  vy: number;
  onGround: boolean;
  facing: number;
  jumps: number;
  coyote: number;
  rising: boolean;
  drop: number;
  jumpBuffer: number;
  dashing: boolean;
  dash: number;
  tapDir: number;
  tapTimer: number;
  tapHold: number;
  dodge: number;
  dodgeCooldown: number;
  airDodge: boolean;
  dodgeBuffer: number;
  attack: string | null;
  attackTimer: number;
  cooldown: number;
  recoveryUsed: boolean;
  helpless: boolean;
  lightBuffer: number;
  heavyBuffer: number;
}

export interface PredictionTrace {
  stage: string;
  solids: StageSpec["solids"];
  platforms: StageSpec["platforms"];
  characterId: string;
  stats: { speed: number; airSpeed: number; jump: number; gravity: number };
  start: TraceState;
  ticks: { input: string; state: TraceState }[]; // input: lettere dei tasti tenuti, l r j d, x per la schivata, a e h per leggero e pesante, u per su
}

const KEYS: Record<string, keyof InputState> = { l: "left", r: "right", j: "jump", d: "down", x: "dodge", a: "light", h: "heavy", u: "up" };
const round = (v: number) => Math.round(v * 1e6) / 1e6;

function stateOf(f: Fighter): TraceState {
  return {
    x: round(f.x),
    y: round(f.y),
    vx: round(f.vx),
    vy: round(f.vy),
    onGround: f.onGround,
    facing: f.facing,
    jumps: f.jumpsLeft,
    coyote: round(f.coyoteTimer),
    rising: f.jumpRising,
    drop: round(f.dropTimer),
    jumpBuffer: round(f.buffer.jump),
    dashing: f.dashing,
    dash: round(f.dashTimer),
    tapDir: f.dashTapDir,
    tapTimer: round(f.dashTapTimer),
    tapHold: round(f.dashHoldMs),
    dodge: round(f.dodgeTimer),
    dodgeCooldown: round(f.dodgeCooldown),
    airDodge: f.airDodgeUsed,
    dodgeBuffer: round(f.buffer.dodge),
    attack: f.attack,
    attackTimer: round(f.attackTimer),
    cooldown: round(f.cooldownTimer),
    recoveryUsed: f.recoveryUsed,
    helpless: f.helpless,
    lightBuffer: round(f.buffer.light),
    heavyBuffer: round(f.buffer.heavy),
  };
}

// Pezzi di tasti tenuti da 1 a 30 tick: direzioni, salti lunghi e corti, giù per cadere più in fretta,
// schivate, attacchi (con su o giù per le varianti, su + pesante in aria è il recupero); ogni tanto un doppio tocco veloce della stessa direzione, che fa scattare
function nextSegments(random: () => number): { keys: string; hold: number }[] {
  const r = random();
  const dir = r < 0.35 ? "l" : r < 0.7 ? "r" : "";
  if (dir && random() < 0.25) {
    const tap = 2 + Math.floor(random() * 4);
    return [{ keys: dir, hold: tap }, { keys: "", hold: 2 + Math.floor(random() * 4) }, { keys: dir, hold: 1 + Math.floor(random() * 40) }];
  }
  const jump = random() < 0.3 ? "j" : "";
  const down = random() < 0.12 ? "d" : "";
  const dodge = random() < 0.08 ? "x" : "";
  const a = random();
  const attack = a < 0.1 ? "a" : a < 0.18 ? "h" : "";
  const up = random() < 0.12 ? "u" : "";
  return [{ keys: dir + jump + down + dodge + attack + up, hold: 1 + Math.floor(random() * 30) }];
}

const outOfScope = (f: Fighter) => f.respawning || f.eliminated || f.hitstun || f.ledgeIndex >= 0 || f.riding >= 0;

export function predictionTraces(): PredictionTrace[] {
  return CASES.map(({ stage, characterId, seed }) => {
    const random = rng(seed).next;
    const f = createFighter({ id: "p", name: "P", characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);
    const ctx = { stage, events: [], timeMs: 0 };
    const stats = characterStats(characterId);
    const trace: PredictionTrace = {
      stage: stage.id,
      solids: stage.solids,
      platforms: stage.platforms,
      characterId,
      stats: { speed: stats.speed, airSpeed: stats.airSpeed, jump: stats.jump, gravity: stats.gravity },
      start: stateOf(f),
      ticks: [],
    };
    const queue: { keys: string; hold: number }[] = [];
    for (let i = 0; i < MAX_TICKS; i++) {
      if (queue.length === 0) queue.push(...nextSegments(random));
      const keys = queue[0].keys;
      if (--queue[0].hold === 0) queue.shift();
      const input = emptyInput();
      for (const k of keys) input[KEYS[k]] = true as never;
      if (JSON.stringify(input) !== JSON.stringify(f.input)) bufferPresses(f, input); // come Match.setInput
      f.input = input;
      stepWorld([f], DT, ctx);
      ctx.events.length = 0;
      if (outOfScope(f)) break;
      trace.ticks.push({ input: keys, state: stateOf(f) });
    }
    return trace;
  });
}

