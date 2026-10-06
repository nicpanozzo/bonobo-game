// Misura quanto costa una stanza al server: tempo per passo di simulazione e peso degli snapshot.
// Uso: npm run bench (oppure npm run bench -- 8 per scegliere il numero di giocatori)

import { deflateRawSync } from "node:zlib";
import { MAX_PLAYERS_PER_ROOM, SEND_RATE, TICK_RATE } from "../src/shared/constants";
import { Match } from "../src/shared/match";
import type { GameEvent, InputState } from "../src/shared/types";

const players = Number(process.argv[2]) || MAX_PLAYERS_PER_ROOM;
const seconds = 60;
const DT = 1000 / TICK_RATE;
const TICKS_PER_SNAPSHOT = Math.round(TICK_RATE / SEND_RATE);

// Generatore con seme: ogni giro di misura gioca la stessa partita
let seed = 1;
const rand = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);

const match = new Match({ rules: { stocks: 99 } });
for (let i = 0; i < players; i++) match.addPlayer(`p${i}`, `Bonobo ${i}`);

// Tasti a caso che cambiano ogni tanto, come giocatori veri che si picchiano
const randomInput = (): InputState => ({
  left: rand() < 0.3,
  right: rand() < 0.3,
  up: rand() < 0.1,
  down: rand() < 0.05,
  light: rand() < 0.2,
  heavy: rand() < 0.1,
  taunt: false,
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
const avgUs = Number(stepNs / BigInt(ticks)) / 1000;
const budgetPct = (avgUs / 1000 / DT) * 100;
console.log(`${players} giocatori, ${seconds} s di partita simulata`);
console.log(`passo medio ${avgUs.toFixed(1)} µs (peggiore ${(Number(worstStepNs) / 1e6).toFixed(2)} ms), ${budgetPct.toFixed(2)}% del tempo di un tick`);
console.log(`snapshot medio ${Math.round(rawBytes / snapshots)} B, compresso ${Math.round(deflatedBytes / snapshots)} B`);
console.log(`banda per giocatore ${((deflatedBytes / snapshots) * SEND_RATE / 1024).toFixed(1)} KB/s compressa`);
