// Misura quanto costa una stanza al server: tempo per passo di simulazione e peso degli snapshot.
// Uso: npm run bench (oppure npm run bench -- 8 per scegliere il numero di giocatori)
// Con --check (E3 passo 4) fa 3 giri, tiene il migliore di ogni numero e esce con 1 se supera PERF_BUDGET

import { appendFileSync } from "node:fs";
import { deflateRawSync } from "node:zlib";
import { MAX_PLAYERS_PER_ROOM, PERF_BUDGET, SEND_RATE, TICK_RATE } from "../src/shared/constants";
import { Match } from "../src/shared/match";
import type { GameEvent, InputState } from "../src/shared/types";

const args = process.argv.slice(2);
const check = args.includes("--check");
const players = Number(args.find((a) => !a.startsWith("--"))) || MAX_PLAYERS_PER_ROOM;
const seconds = 60;
const DT = 1000 / TICK_RATE;
const TICKS_PER_SNAPSHOT = Math.round(TICK_RATE / SEND_RATE);

interface Result {
  avgUs: number;
  worstMs: number;
  rawBytes: number;
  deflatedBytes: number;
}

// Una partita di prova: sempre la stessa, grazie al seme
function run(): Result {
  // Generatore con seme: ogni giro di misura gioca la stessa partita
  let seed = 1;
  const rand = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;

  const match = new Match({ rules: { stocks: 99 } });
  for (let i = 0; i < players; i++) match.addPlayer(`p${i}`, `Bonobo ${i}`);

  // Tasti a caso che cambiano ogni tanto, come giocatori veri che si picchiano
  const randomInput = (): InputState => ({
    left: rand() < 0.3,
    right: rand() < 0.3,
    up: rand() < 0.1,
    jump: rand() < 0.1,
    down: rand() < 0.05,
    light: rand() < 0.2,
    heavy: rand() < 0.1,
    dodge: rand() < 0.05,
    taunt: false,
    shield: rand() < 0.05,
    special: rand() < 0.05,
  });

  let stepNs = 0n;
  let worstStepNs = 0n;
  let rawBytes = 0;
  let deflatedBytes = 0;
  let snapshots = 0;
  let pending: GameEvent[] = [];

  for (let tick = 0; tick < seconds * TICK_RATE; tick++) {
    if (tick % 6 === 0) for (const p of match.players) match.setInput(p.id, randomInput());
    const t0 = process.hrtime.bigint();
    pending.push(...match.step(DT));
    const dt = process.hrtime.bigint() - t0;
    stepNs += dt;
    if (dt > worstStepNs) worstStepNs = dt;
    if (tick % TICKS_PER_SNAPSHOT === 0) {
      const json = JSON.stringify(match.snapshot(pending, tick));
      pending = [];
      rawBytes += Buffer.byteLength(json);
      deflatedBytes += deflateRawSync(json).length;
      snapshots++;
    }
  }
  const ticks = seconds * TICK_RATE;
  return {
    avgUs: Number(stepNs / BigInt(ticks)) / 1000,
    worstMs: Number(worstStepNs) / 1e6,
    rawBytes: Math.round(rawBytes / snapshots),
    deflatedBytes: Math.round(deflatedBytes / snapshots),
  };
}

// Il migliore di ogni numero tra i giri: un picco della macchina non fa fallire il controllo
const runs = Array.from({ length: check ? 3 : 1 }, run);
const best: Result = {
  avgUs: Math.min(...runs.map((r) => r.avgUs)),
  worstMs: Math.min(...runs.map((r) => r.worstMs)),
  rawBytes: Math.min(...runs.map((r) => r.rawBytes)),
  deflatedBytes: Math.min(...runs.map((r) => r.deflatedBytes)),
};

const budgetPct = (best.avgUs / 1000 / DT) * 100;
console.log(`${players} giocatori, ${seconds} s di partita simulata${check ? ", migliore di 3 giri" : ""}`);
console.log(`passo medio ${best.avgUs.toFixed(1)} µs (peggiore ${best.worstMs.toFixed(2)} ms), ${budgetPct.toFixed(2)}% del tempo di un tick`);
console.log(`snapshot medio ${best.rawBytes} B, compresso ${best.deflatedBytes} B`);
console.log(`banda per giocatore ${((best.deflatedBytes * SEND_RATE) / 1024).toFixed(1)} KB/s compressa`);

if (check) {
  const rows: [string, number, number, string][] = [
    ["Server, passo medio", best.avgUs / 1000, PERF_BUDGET.serverStepAvgMs, "ms"],
    ["Server, passo peggiore", best.worstMs, PERF_BUDGET.serverStepWorstMs, "ms"],
    ["Snapshot compresso", best.deflatedBytes, PERF_BUDGET.snapshotDeflatedBytes, "B"],
  ];
  const over = rows.filter(([, value, limit]) => value > limit);
  const table = ["| Misura | Valore | Budget |", "|---|---|---|", ...rows.map(([name, value, limit, unit]) => `| ${name} | ${value.toFixed(unit === "B" ? 0 : 3)} ${unit} | ${limit} ${unit}${value > limit ? " ❌" : ""} |`)];
  // Nella CI la tabella finisce nel riassunto del job
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `### Prestazioni del server (${players} giocatori)\n\n${table.join("\n")}\n\n`);
  if (over.length) {
    console.error(`Budget superato: ${over.map(([name]) => name).join(", ")} (PERF_BUDGET in constants.ts)`);
    process.exit(1);
  }
  console.log("Dentro il budget");
}
