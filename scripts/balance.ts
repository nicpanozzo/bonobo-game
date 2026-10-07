// Bilanciamento senza rete (E11 passo E): ogni personaggio gioca contro ogni altro, bot contro bot,
// su tutte le arene fisse e su alcune casuali, partendo da entrambi i lati. Stampa vittorie, KO e durata
// ed esce con errore se un personaggio vince più di BALANCE.maxWinRate delle sue partite.
// Uso: npm run balance (oppure npm run balance -- difficile per il livello del bot)

import { BALANCE, TICK_RATE } from "../src/shared/constants";
import { CHARACTERS } from "../src/shared/characters";
import { Match } from "../src/shared/match";
import { STAGES } from "../src/shared/stages";
import { Bots, parseBotKind } from "../src/server/bot";

const DT = 1000 / TICK_RATE;
const level = parseBotKind(process.argv[2] ?? "semplice");
if (!level || level === "manichino") {
  console.error("Livello del bot: facile, semplice o difficile");
  process.exit(2);
}

// Le arene da combattimento: niente percorsi con il traguardo
const stageIds = [
  ...Object.values(STAGES)
    .filter((s) => !s.goal)
    .map((s) => s.id),
  ...Array.from({ length: BALANCE.generatedStages }, (_, i) => `casuale-${i + 1}`),
];
const characters = Object.keys(CHARACTERS);

interface Tally {
  games: number;
  wins: number;
  draws: number;
  kosGiven: number;
  kosTaken: number;
  durationMs: number;
}
const tally = new Map(characters.map((c) => [c, { games: 0, wins: 0, draws: 0, kosGiven: 0, kosTaken: 0, durationMs: 0 } as Tally]));

// Una partita tra due bot fino al primo matchEnd: chi ha vinto (null se pari) e i KO
function play(stageId: string, first: string, second: string) {
  const match = new Match({ stageId });
  const bots = new Bots();
  const ids = [bots.add(match, level!), bots.add(match, level!)] as string[];
  const chars = [first, second];
  match.players.forEach((f) => (f.characterId = chars[ids.indexOf(f.id)]));
  const kos = new Map(ids.map((id) => [id, 0]));
  for (let tick = 0; tick < BALANCE.maxMatchSec * TICK_RATE; tick++) {
    bots.tick(match);
    for (const e of match.step(DT)) {
      if (e.type === "ko") kos.set(e.id, (kos.get(e.id) ?? 0) + 1);
      if (e.type === "matchEnd") return { ids, chars, kos, winnerId: e.winnerId, durationMs: e.durationMs };
    }
  }
  return { ids, chars, kos, winnerId: null, durationMs: BALANCE.maxMatchSec * 1000 };
}

const started = Date.now();
for (const stageId of stageIds) {
  for (const a of characters) {
    for (const b of characters) {
      if (a === b) continue; // lo specchio non dice niente sul bilanciamento
      const r = play(stageId, a, b);
      r.ids.forEach((id, i) => {
        const t = tally.get(r.chars[i])!;
        const other = r.ids[1 - i];
        t.games++;
        t.durationMs += r.durationMs;
        t.kosTaken += r.kos.get(id) ?? 0;
        t.kosGiven += r.kos.get(other) ?? 0;
        if (r.winnerId === id) t.wins++;
        else if (r.winnerId === null) t.draws++;
      });
    }
  }
}

const pct = (n: number) => `${Math.round(n * 100)}%`.padStart(5);
console.log(`Bot ${level}, ${stageIds.length} arene (${stageIds.join(", ")}), ${((Date.now() - started) / 1000).toFixed(1)} s\n`);
console.log("personaggio      partite  vittorie  pari  KO fatti  KO subiti  durata media");
let failed = false;
for (const [id, t] of tally) {
  const rate = t.games ? t.wins / t.games : 0;
  const tooStrong = rate > BALANCE.maxWinRate;
  failed ||= tooStrong;
  console.log(
    `${id.padEnd(16)} ${String(t.games).padStart(7)}  ${pct(rate).padStart(8)}  ${String(t.draws).padStart(4)}  ${String(t.kosGiven).padStart(8)}  ${String(t.kosTaken).padStart(9)}  ${`${(t.durationMs / Math.max(1, t.games) / 1000).toFixed(0)} s`.padStart(12)}${tooStrong ? "  TROPPO FORTE" : ""}`,
  );
}
if (failed) {
  console.error(`\nUn personaggio vince più del ${pct(BALANCE.maxWinRate).trim()} delle partite: da ribilanciare.`);
  process.exit(1);
}
