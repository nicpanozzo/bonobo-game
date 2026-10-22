// Prova senza rete di Bologna (#433): bot contro bot per tutta la linea del tempo dell'arena, con un riepilogo per fase.
// Dice dove stanno i lottatori (terra, torri, cima), i KO e da cosa vengono, i bot fermi o rimasti in una postazione,
// e chi viene buttato fuori all'inizio di una fase. Non gira con `npm test`: serve a chi ritocca i tempi dell'arena.
// Uso: npm run bologna:bots (oppure npm run bologna:bots -- difficile 2 360 [vite] per livello, lottatori per squadra, secondi, vite vere)

import { BOLOGNA, TICK_RATE } from "../src/shared/constants";
import { Match } from "../src/shared/match";
import { phaseIndexAt } from "../src/shared/physics";
import { STAGES } from "../src/shared/stages";
import { Bots, parseBotKind, type BotKind } from "../src/server/bot";

const DT = 1000 / TICK_RATE;
const bologna = STAGES.bologna;
const STUCK_MS = 10000; // fermo per tanto = bloccato
const GROUND_Y = 1935; // piedi sotto questa y: in piazza o sulle basi
const TOP_Y = 1050; // piedi sopra questa y durante la zuffa: in cima all'Asinelli
// Fasce d'altezza dei piedi: piazza, primi pezzi, metà torre, alta, cima
const BANDS = [1935, 1700, 1400, 1100, -Infinity];
const ZONES = ["terra", "torre", "cima"] as const;
type Zone = (typeof ZONES)[number];

const level = parseBotKind(process.argv[2] ?? "semplice");
if (!level || level === "manichino" || level === "sparring") {
  console.error("Livello del bot: facile, semplice o difficile");
  process.exit(2);
}
const perTeam = Number(process.argv[3] ?? 0); // 0 = tutte le prove di default
const seconds = Number(process.argv[4] ?? 360);
const unlimited = process.argv[5] !== "vite"; // "vite" = vite vere (3 per ciascuno)

interface Report {
  label: string;
  ended: number | null; // stageMs in cui la partita è finita prima del tempo
  zones: number[][]; // fase -> zona -> tick
  kos: Record<string, number>[]; // fase -> causa -> conteggio
  hits: Record<string, number>[]; // fase -> trappola -> colpi presi
  minY: number[][]; // fase -> squadra (1, 2) -> la y più alta raggiunta senza essere appena rientrati
  bands: number[][]; // fase -> fascia d'altezza -> tick con i piedi su qualcosa (conta la salita vera, non i lanci)
  instantKos: number; // KO nei primi 250 ms della zuffa per la zona di espulsione di sotto
  stuck: string[];
  stationLong: string[];
  stationEnters: number;
  stationFires: number;
}

function play(label: string, perTeamCount: number, kinds: BotKind[]): Report {
  // Il "seme" è la combinazione di livelli e personaggi: i bot sono deterministici
  const match = new Match({ stageId: "bologna", rules: { mode: "teams", stocks: 9, timeLimitSec: 0, itemAmount: 0 }, items: false });
  // Vite infinite (ctx è privato): la partita non finisce prima della fine e si vedono anche le fasi dopo la zuffa
  if (unlimited) (match as unknown as { ctx: { unlimitedStocks: boolean } }).ctx.unlimitedStocks = true;
  const bots = new Bots();
  const chars = ["default", "orsoblu"];
  for (let i = 0; i < perTeamCount * 2; i++) bots.add(match, kinds[i % kinds.length], chars[(i >> 1) % 2]);
  const phases = bologna.phases!.length;
  const r: Report = {
    label,
    ended: null,
    zones: Array.from({ length: phases }, () => ZONES.map(() => 0)),
    kos: Array.from({ length: phases }, () => ({})),
    hits: Array.from({ length: phases }, () => ({})),
    minY: Array.from({ length: phases }, () => [Infinity, Infinity]),
    bands: Array.from({ length: phases }, () => BANDS.map(() => 0)),
    instantKos: 0,
    stuck: [],
    stationLong: [],
    stationEnters: 0,
    stationFires: 0,
  };
  const anchor = new Map<string, { x: number; y: number; ms: number; flagged: boolean }>();
  const stationSince = new Map<string, number>();
  const lastHazard = new Map<string, { kind: string; ms: number }>();
  for (let tick = 0; tick < seconds * TICK_RATE; tick++) {
    const ms = tick * DT;
    const ph = phaseIndexAt(bologna, ms);
    bots.tick(match);
    const events = match.step(DT);
    for (const f of match.players) {
      if (f.eliminated || f.respawning) {
        anchor.delete(f.id);
        stationSince.delete(f.id);
        continue;
      }
      const zone: Zone = f.y > GROUND_Y ? "terra" : ph === 3 && f.y <= TOP_Y && f.x > 1100 ? "cima" : "torre";
      r.zones[ph][ZONES.indexOf(zone)]++;
      if (f.onGround) r.bands[ph][BANDS.findIndex((b) => f.y >= b || b === -Infinity)]++;
      if (!f.invulnerable && f.team >= 1 && f.team <= 2) r.minY[ph][f.team - 1] = Math.min(r.minY[ph][f.team - 1], Math.round(f.y));
      const a = anchor.get(f.id);
      if (!a || Math.hypot(f.x - a.x, f.y - a.y) > 30) anchor.set(f.id, { x: f.x, y: f.y, ms, flagged: false });
      else if (!a.flagged && ms - a.ms >= STUCK_MS && f.station === undefined) {
        a.flagged = true;
        r.stuck.push(`${f.id} (squadra ${f.team}) fermo da ${(a.ms / 1000).toFixed(0)} s a (${Math.round(f.x)}, ${Math.round(f.y)}), fase ${ph + 1}`);
      }
      if (f.station !== undefined) {
        if (a) a.ms = ms; // chi sta alla bombarda non è bloccato
        const since = stationSince.get(f.id) ?? ms;
        stationSince.set(f.id, since);
        if (ms - since >= STUCK_MS && ms - since < STUCK_MS + DT) r.stationLong.push(`${f.id} in postazione ${f.station} da ${(since / 1000).toFixed(0)} s, fase ${ph + 1}`);
      } else stationSince.delete(f.id);
    }
    for (const e of events) {
      if (e.type === "hazard") {
        const kind = bologna.hazards![e.index]?.kind ?? `trappola${e.index}`;
        lastHazard.set(e.id, { kind, ms });
        r.hits[ph][kind] = (r.hits[ph][kind] ?? 0) + 1;
      } else if (e.type === "station") {
        if (e.phase === "enter") r.stationEnters++;
        if (e.phase === "fire") r.stationFires++;
      } else if (e.type === "ko") {
        const z = bologna.phases![ph].blastZone!;
        const h = lastHazard.get(e.id);
        const side = e.y > z.bottom ? "sotto" : e.y < z.top ? "sopra" : e.x < z.left ? "sinistra" : "destra";
        // Un KO per lo spazio: la trappola vale se l'ha colpito da poco
        const cause = h && ms - h.ms < 2500 ? `${h.kind}+${side}` : `zona ${side}`;
        r.kos[ph][cause] = (r.kos[ph][cause] ?? 0) + 1;
        if (ph === 3 && ms - BOLOGNA.brawlMs < 250 && side === "sotto") r.instantKos++;
      } else if (e.type === "matchEnd") r.ended ??= ms;
    }
    if (r.ended !== null) break;
  }
  return r;
}

function print(r: Report) {
  console.log(`\n=== ${r.label}${r.ended !== null ? ` (finita a ${(r.ended / 1000).toFixed(0)} s)` : ""}`);
  bologna.phases!.forEach((p, i) => {
    const tot = r.zones[i].reduce((a, b) => a + b, 0) || 1;
    const share = ZONES.map((z, k) => `${z} ${Math.round((100 * r.zones[i][k]) / tot)}%`).join(", ");
    console.log(`fase ${i + 1} ${p.id}: ${share}`);
    const bt = r.bands[i].reduce((a, b) => a + b, 0) || 1;
    console.log(`   a terra per fascia piazza/1700/1400/1100/cima: ${r.bands[i].map((b) => Math.round((100 * b) / bt) + "%").join(" ")}`);
    console.log(`   punto più alto (y) squadra 1 / 2: ${r.minY[i].join(" / ")}`);
    console.log(`   KO ${JSON.stringify(r.kos[i])}  colpi di trappola ${JSON.stringify(r.hits[i])}`);
  });
  console.log(`KO nei primi 250 ms della zuffa: ${r.instantKos}`);
  console.log(`postazioni: ${r.stationEnters} ingressi, ${r.stationFires} spari; troppo a lungo dentro: ${r.stationLong.length ? r.stationLong.join("; ") : "nessuno"}`);
  console.log(`bloccati: ${r.stuck.length ? "\n   " + r.stuck.join("\n   ") : "nessuno"}`);
}

const runs: [string, number, BotKind[]][] =
  perTeam > 0
    ? [[`${perTeam}v${perTeam} ${level}`, perTeam, [level]]]
    : [
        ["2v2 semplice", 2, ["semplice"]],
        ["2v2 difficile", 2, ["difficile"]],
        ["2v2 misto facile/difficile", 2, ["facile", "difficile"]],
        ["1v1 semplice", 1, ["semplice"]],
      ];
for (const [label, n, kinds] of runs) print(play(label, n, kinds));
