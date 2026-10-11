// Tracce per il port del movimento in GDScript (E17 passo 3): la fisica vera (src/shared/physics) gioca
// sequenze di tasti fisse, con seme, e si annota lo stato del lottatore a ogni tick. godot/tests/test_prediction.gd
// le rigioca con godot/scripts/predict/movement.gd e pretende le stesse posizioni. Le scrive npm run export:godot
// in godot/tests/data (fuori dal gioco esportato); predictionTraces.test.ts controlla che il file sia aggiornato,
// così chi cambia il movimento solo in TypeScript vede rossa prima una CI e poi l'altra.
//
// Solo il movimento che il client predice: corsa, aria, salti, salto corto, coyote, gravità, caduta veloce,
// piattaforme sottili. Una traccia si ferma prima del primo tick fuori da lì (bordo, KO, ascensori).

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
  { stage: getStage("palco"), characterId: "default", seed: 1 },
  { stage: getStage("isole"), characterId: "orsoblu", seed: 2 },
  { stage: getStage("palestra"), characterId: "elvedeo", seed: 3 },
  { stage: generateStage(7), characterId: "default", seed: 4 },
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
}

export interface PredictionTrace {
  stage: string;
  solids: StageSpec["solids"];
  platforms: StageSpec["platforms"];
  characterId: string;
  stats: { speed: number; airSpeed: number; jump: number; gravity: number };
  start: TraceState;
  ticks: { input: string; state: TraceState }[]; // input: lettere dei tasti tenuti, l r j d
}

const KEYS: Record<string, keyof InputState> = { l: "left", r: "right", j: "jump", d: "down" };
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
  };
}

// Un tasto per volta tenuto da 1 a 30 tick: direzioni, salti lunghi e corti, giù per cadere più in fretta
function nextKeys(random: () => number): { keys: string; hold: number } {
  const r = random();
  const dir = r < 0.35 ? "l" : r < 0.7 ? "r" : "";
  const jump = random() < 0.3 ? "j" : "";
  const down = random() < 0.12 ? "d" : "";
  return { keys: dir + jump + down, hold: 1 + Math.floor(random() * 30) };
}

const outOfScope = (f: Fighter) => f.respawning || f.eliminated || f.hitstun || f.ledgeIndex >= 0 || f.riding >= 0 || f.dashing;

export function predictionTraces(): PredictionTrace[] {
  return CASES.map(({ stage, characterId, seed }) => {
    const random = rng(seed).next;
    const f = createFighter({ id: "p", name: "P", characterId, color: 0, team: 0, index: 0, stocks: 3 }, stage);
    f.dashByTap = false; // lo scatto non è ancora nel port (passo 5)
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
    let keys = "";
    let hold = 0;
    for (let i = 0; i < MAX_TICKS; i++) {
      if (hold === 0) ({ keys, hold } = nextKeys(random));
      hold--;
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

