// La fisica è deterministica (E3 passo 3, #83): stessi input, stessa partita, tick per tick.
// Serve alla predizione nel client e a rigiocare una partita; la regola è in AGENTS.md, qui diventa automatica.

import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { describe, it } from "node:test";
import { TICK_RATE } from "./constants";
import { Match } from "./match";
import type { GameEvent, InputState, MatchRules } from "./types";

const DT = 1000 / TICK_RATE;
const TICKS = 3600; // un minuto di partita
const CHARACTERS = ["default", "egiainuso", "bonobot", "default"]; // speciali diverse: proiettili, scatto, carica, contrattacco

// Generatore con seme, come scripts/bench.ts: le due partite ricevono gli stessi tasti
function inputs(seed: number) {
  let s = seed;
  const rand = () => (s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  return (): InputState => ({
    left: rand() < 0.3,
    right: rand() < 0.3,
    up: rand() < 0.1,
    jump: rand() < 0.1,
    down: rand() < 0.08,
    light: rand() < 0.2,
    heavy: rand() < 0.1,
    taunt: rand() < 0.01,
    dodge: rand() < 0.04,
    shield: rand() < 0.06,
    special: rand() < 0.06,
  });
}

// Una partita intera: lo snapshot di ogni tick, in JSON
function play(rules: Partial<MatchRules>, stageId: string | undefined, seed: number): string[] {
  const match = new Match({ stageId, rules });
  CHARACTERS.forEach((c, i) => match.addPlayer(`p${i}`, `P${i}`, c));
  const next = inputs(seed);
  const seen: string[] = [];
  for (let tick = 0; tick < TICKS; tick++) {
    if (tick % 6 === 0) for (const p of match.players) match.setInput(p.id, next());
    const events: GameEvent[] = match.step(DT);
    seen.push(JSON.stringify(match.snapshot(events, tick)));
  }
  return seen;
}

const CASES: { name: string; rules: Partial<MatchRules>; stageId?: string }[] = [
  { name: "tutti contro tutti, con gli oggetti", rules: { mode: "ffa", stocks: 99 } },
  { name: "tutti contro tutti su un'arena casuale", rules: { mode: "ffa", stocks: 99 }, stageId: "casuale-4242" },
  { name: "squadre", rules: { mode: "teams", stocks: 99, friendlyFire: true } },
  { name: "bandiera", rules: { mode: "flag", stocks: 5 } },
  { name: "corsa con un percorso fisso", rules: { mode: "race" }, stageId: "corsa-77" },
];

describe("determinismo", () => {
  for (const c of CASES) {
    it(`${c.name}: due partite uguali tick per tick`, () => {
      const a = play(c.rules, c.stageId, 7);
      const b = play(c.rules, c.stageId, 7);
      for (let i = 0; i < TICKS; i++) {
        if (a[i] !== b[i]) assert.fail(`al tick ${i} le due partite si separano:\n${a[i]}\n${b[i]}`);
      }
      // Che sia successo qualcosa: altrimenti il test non prova niente
      const events = a.join("\n");
      assert.ok(events.includes('"type":"hit"'), "nessun colpo in un minuto di partita");
    });
  }

  it("con tasti diversi le partite sono diverse (il confronto funziona)", () => {
    const a = play({ mode: "ffa", stocks: 99 }, undefined, 7);
    const b = play({ mode: "ffa", stocks: 99 }, undefined, 8);
    assert.notDeepEqual(a, b);
  });
});

// Quello che la fisica non deve usare (AGENTS.md: "physics/ resta puro e deterministico")
const FORBIDDEN: [RegExp, string][] = [
  [/\bMath\.random\b/, "Math.random"],
  [/\bDate\.now\b|\bnew Date\b/, "l'orologio (Date)"],
  [/\bperformance\./, "l'orologio (performance)"],
  [/from\s+["'](socket\.io|socket\.io-client|express|phaser)["']/, "un import di rete o di grafica"],
  [/\b(window|document)\./, "il DOM"],
];

// Le righe di un sorgente che usano qualcosa di vietato, commenti esclusi
function impurities(source: string): string[] {
  const found: string[] = [];
  source.split("\n").forEach((line, i) => {
    const code = line.replace(/\/\/.*$/, "");
    for (const [re, what] of FORBIDDEN) if (re.test(code)) found.push(`riga ${i + 1}: ${what}`);
  });
  return found;
}

describe("purezza di physics/", () => {
  it("nessun sorgente usa caso, orologi, rete o DOM", () => {
    const dir = new URL("./physics/", import.meta.url);
    const files = readdirSync(dir).filter((f) => f.endsWith(".ts") && !f.endsWith(".test.ts"));
    assert.ok(files.length > 5, "physics/ trovata");
    const problems = files.flatMap((f) => impurities(readFileSync(new URL(f, dir), "utf8")).map((p) => `${f}, ${p}`));
    assert.deepEqual(problems, [], `physics/ deve restare pura:\n${problems.join("\n")}`);
  });

  it("il controllo se ne accorge davvero", () => {
    assert.equal(impurities("const r = Math.random();").length, 1);
    assert.equal(impurities("const t = Date.now();").length, 1);
    assert.equal(impurities('import { io } from "socket.io-client";').length, 1);
    assert.equal(impurities("// niente Math.random qui").length, 0, "nei commenti va bene");
    assert.equal(impurities("const x = f.random + 1;").length, 0);
  });
});
