// Classifica (#18 passo 3): ogni partita finita con almeno due persone finisce in un file JSON
// e la pagina /classifica mostra chi ha vinto di più negli ultimi 7 giorni.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { LEADERBOARD } from "../shared/constants";

export interface MatchRecord {
  t: number; // quando è finita, ms dal 1970
  players: { name: string; won: boolean; kos: number; falls: number; damageDealt: number }[];
}

export interface Standing {
  name: string;
  matches: number;
  wins: number;
  kos: number;
  falls: number;
  damageDealt: number;
}

// Somma le partite dal momento "since" in poi, per nome (lo stesso amico può cambiare stanza o lottatore)
export function standings(records: readonly MatchRecord[], since: number): Standing[] {
  const byName = new Map<string, Standing>();
  for (const r of records) {
    if (r.t < since) continue;
    for (const p of r.players) {
      const key = p.name.trim().toLowerCase();
      const s = byName.get(key) ?? { name: p.name, matches: 0, wins: 0, kos: 0, falls: 0, damageDealt: 0 };
      s.matches++;
      if (p.won) s.wins++;
      s.kos += p.kos;
      s.falls += p.falls;
      s.damageDealt += p.damageDealt;
      byName.set(key, s);
    }
  }
  return [...byName.values()].sort((a, b) => b.wins - a.wins || b.kos - a.kos || a.falls - b.falls);
}

export class Leaderboard {
  private records: MatchRecord[] = [];
  private saving = Promise.resolve();

  constructor(private file: string) {}

  async load(): Promise<void> {
    try {
      const data = JSON.parse(await readFile(this.file, "utf8"));
      if (Array.isArray(data)) this.records = data;
    } catch {
      // Primo avvio o file rovinato: si riparte da una classifica vuota
    }
  }

  record(r: MatchRecord): void {
    this.records.push(r);
    if (this.records.length > LEADERBOARD.maxMatches) this.records.splice(0, this.records.length - LEADERBOARD.maxMatches);
    // Un salvataggio alla volta, così due partite finite insieme non si sovrascrivono a metà
    const snapshot = JSON.stringify(this.records);
    this.saving = this.saving
      .then(async () => {
        await mkdir(path.dirname(this.file), { recursive: true });
        await writeFile(this.file, snapshot);
      })
      .catch((err) => console.warn(`[classifica] salvataggio non riuscito: ${(err as Error).message}`));
  }

  week(now = Date.now()): Standing[] {
    return standings(this.records, now - LEADERBOARD.windowDays * 24 * 60 * 60 * 1000);
  }
}

const escapeHtml = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

// La pagina /classifica: niente client, solo HTML servito dal server di gioco
export function leaderboardPage(rows: readonly Standing[]): string {
  const best = rows[0];
  const body = rows.length
    ? `<p class="best">🦍 Bonobo della settimana: <b>${escapeHtml(best.name)}</b> (${best.wins === 1 ? "1 vittoria" : `${best.wins} vittorie`})</p>
<table><tr><th></th><th>Nome</th><th>Vittorie</th><th>Partite</th><th>KO</th><th>Cadute</th><th>Danni</th></tr>
${rows
  .map(
    (r, i) =>
      `<tr><td>${i + 1}</td><td>${escapeHtml(r.name)}</td><td>${r.wins}</td><td>${r.matches}</td><td>${r.kos}</td><td>${r.falls}</td><td>${Math.round(r.damageDealt)}%</td></tr>`,
  )
  .join("\n")}
</table>`
    : "<p>Nessuna partita negli ultimi 7 giorni: andate a giocare!</p>";
  return `<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Classifica · Bonobo Game</title>
<style>body{font-family:system-ui,sans-serif;background:#0d1520;color:#e8eef5;max-width:720px;margin:2rem auto;padding:0 16px}
table{width:100%;border-collapse:collapse}th,td{padding:6px 8px;text-align:left;border-bottom:1px solid #26364a}th{color:#9fb3c8;font-weight:600}
.best{font-size:1.2rem}</style></head>
<body><h1>Classifica degli ultimi 7 giorni</h1>${body}</body></html>`;
}
