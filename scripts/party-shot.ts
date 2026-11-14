// Bonobo Party (#579): gioca un minigioco vero con quattro bot per qualche secondo e salva arena, snapshot e scheda
// in un JSON, che godot/tools/screenshot.gd (--mini=<file>) fotografa come lo vedrebbe un giocatore.
// npx tsx scripts/party-shot.ts <id> <secondi> <file.json>
import { writeFileSync } from "node:fs";
import { TICK_RATE } from "../src/shared/constants";
import { Match } from "../src/shared/match";
import { getMinigame } from "../src/shared/party/minigames";
import { Bots } from "../src/server/bot";

const [id, secs = "8", out = "mini.json"] = process.argv.slice(2);
const def = getMinigame(id);
if (!def) throw new Error(`minigioco sconosciuto: ${id}`);
const chars = ["orsoblu", "marcomunista", "bradipo", "nonnagina"];
const ids = chars.map((_, i) => `p${i}`);
const setup = def.build(7, ids);
const match = new Match({ stage: setup.stage, rules: { mode: "ffa", stocks: 3, itemAmount: 0, timeLimitSec: 0, ...setup.rules }, items: false, autoRestart: false, minigame: { id, runtime: setup.runtime, unlimitedStocks: setup.unlimitedStocks ?? true } });
const bots = new Bots();
ids.forEach((pid, i) => {
  match.addPlayer(pid, ["Nicola", "Marco", "Riccardo", "Gina"][i], chars[i]);
  bots.adopt(match, pid, "semplice");
});
const dt = 1000 / TICK_RATE;
for (let t = 0; t < Number(secs) * 1000 && !match.ended; t += dt) {
  bots.tick(match);
  match.step(dt);
}
const info = { ...def.info, ...(setup.roles && { roles: setup.roles }) };
writeFileSync(out, JSON.stringify({ stage: match.currentStage, minigame: info, snapshot: match.snapshot([], 0) }));
console.log(`${id}: ${out}`);
