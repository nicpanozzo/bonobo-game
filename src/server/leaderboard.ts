// Classifica (#18 passo 3): ogni partita finita con almeno due persone finisce in un file JSON.
// La pagina /classifica mostra i punti di sempre (Elo, rating.ts) e chi ha vinto di più negli ultimi 7 giorni.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { LEADERBOARD } from "../shared/constants";
import type { BoardRow, MatchRules } from "../shared/types";
import { applyMatch, computeRatings, nameKey, rankRatings, tierOf, type PlayerRating, type Ratings } from "./rating";

export interface MatchRecord {
  t: number; // quando è finita, ms dal 1970
  mode?: MatchRules["mode"]; // manca nelle partite salvate prima della classifica a punti
  players: {
    name: string;
    won: boolean;
    kos: number;
    falls: number;
    damageDealt: number;
    team?: number; // squadra (> 0) nelle partite a squadre: i compagni non si tolgono punti tra loro
    place?: number; // posizione d'arrivo (1 = primo), se la partita la conosce; altrimenti si ricava (rating.ts)
  }[];
}

export interface Standing {
  name: string;
  matches: number;
  wins: number;
  kos: number;
  falls: number;
  damageDealt: number;
  // Punti di sempre (rating.ts): li aggiunge Leaderboard.week(), standings() da sola non li conosce
  rating?: number;
  tier?: string;
  streak?: number;
}

// I punti cambiati da una partita, per nome: discord.ts li rimappa sugli id dei lottatori
export interface RatingResult {
  name: string;
  rating: number;
  delta: number;
  tier: string;
  rank: number | null; // posizione nel tabellone dopo la partita, null se non ha ancora RATING.minMatches partite
}

// Somma le partite dal momento "since" in poi, per nome (lo stesso amico può cambiare stanza o lottatore)
export function standings(records: readonly MatchRecord[], since: number): Standing[] {
  const byName = new Map<string, Standing>();
  for (const r of records) {
    if (r.t < since) continue;
    for (const p of r.players) {
      const key = nameKey(p.name);
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

const toRow = (r: PlayerRating): BoardRow => ({
  name: r.name,
  rating: Math.round(r.rating),
  tier: tierOf(r.rating),
  wins: r.wins,
  matches: r.matches,
  streak: r.streak,
});

// File salvato: { base, records }. base = punti delle partite più vecchie già tolte da records,
// così i punti non cambiano al riavvio quando si supera LEADERBOARD.maxMatches.
// I file di prima (solo l'elenco delle partite) si leggono ancora
interface SavedFile {
  base: [string, PlayerRating][];
  records: MatchRecord[];
}

export class Leaderboard {
  private records: MatchRecord[] = [];
  private base: Ratings = new Map();
  private ratings: Ratings = new Map(); // aggiornati a ogni partita, ricostruiti solo al load()
  private ranked: PlayerRating[] | null = null; // ordine del tabellone, rifatto solo dopo una partita
  private saving = Promise.resolve();

  constructor(private file: string) {}

  async load(): Promise<void> {
    try {
      const data = JSON.parse(await readFile(this.file, "utf8")) as unknown;
      if (Array.isArray(data)) this.records = data as MatchRecord[];
      else if (data && typeof data === "object" && Array.isArray((data as SavedFile).records)) {
        const saved = data as SavedFile;
        this.records = saved.records;
        this.base = new Map(Array.isArray(saved.base) ? saved.base : []);
      }
    } catch {
      // Primo avvio o file rovinato: si riparte da una classifica vuota
    }
    this.ratings = computeRatings(this.records, this.base);
    this.ranked = null;
  }

  // Segna la partita e dice quanti punti ha preso o perso ognuno
  record(r: MatchRecord): RatingResult[] {
    this.records.push(r);
    const changes = applyMatch(this.ratings, r);
    this.ranked = null;
    if (this.records.length > LEADERBOARD.maxMatches) {
      // Le partite tolte dal file passano nella base: i punti restano quelli
      for (const old of this.records.splice(0, this.records.length - LEADERBOARD.maxMatches)) applyMatch(this.base, old);
    }
    const rank = new Map(this.rankedRatings().map((p, i) => [nameKey(p.name), i + 1]));
    // Un salvataggio alla volta, così due partite finite insieme non si sovrascrivono a metà
    const saved: SavedFile = { base: [...this.base], records: this.records };
    const snapshot = JSON.stringify(saved);
    this.saving = this.saving
      .then(async () => {
        await mkdir(path.dirname(this.file), { recursive: true });
        await writeFile(this.file, snapshot);
      })
      .catch((err) => console.warn(`[classifica] salvataggio non riuscito: ${(err as Error).message}`));
    return changes.map((c) => ({ name: c.name, rating: c.rating, delta: c.delta, tier: tierOf(c.rating), rank: rank.get(c.key) ?? null }));
  }

  // Il tabellone della classifica a punti: i primi limit con almeno RATING.minMatches partite
  board(limit: number): BoardRow[] {
    return this.rankedRatings().slice(0, Math.max(0, limit)).map(toRow);
  }

  week(now = Date.now()): Standing[] {
    return standings(this.records, now - LEADERBOARD.windowDays * 24 * 60 * 60 * 1000).map((s) => {
      const r = this.ratings.get(nameKey(s.name));
      return r ? { ...s, rating: Math.round(r.rating), tier: tierOf(r.rating), streak: r.streak } : s;
    });
  }

  // Per i test: aspetta che il file sia scritto
  flush(): Promise<void> {
    return this.saving;
  }

  private rankedRatings(): PlayerRating[] {
    this.ranked ??= rankRatings(this.ratings.values());
    return this.ranked;
  }
}

const escapeHtml = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

// I punti di sempre: posizione, nome, grado, punti, vittorie su partite, vittorie di fila
function boardTable(board: readonly BoardRow[]): string {
  if (!board.length) return "<p>Ancora nessun punto: la prima partita tra amici apre la classifica.</p>";
  return `<table><tr><th></th><th>Nome</th><th>Grado</th><th>Punti</th><th>Vittorie</th><th>Di fila</th></tr>
${board
  .map(
    (r, i) =>
      `<tr><td>${i + 1}</td><td>${escapeHtml(r.name)}</td><td>${escapeHtml(r.tier)}</td><td><b>${r.rating}</b></td><td>${r.wins}/${r.matches}</td><td>${r.streak ? `🔥 ${r.streak}` : ""}</td></tr>`,
  )
  .join("\n")}
</table>`;
}

// La pagina /classifica: niente client, solo HTML servito dal server di gioco
export function leaderboardPage(rows: readonly Standing[], board: readonly BoardRow[] = []): string {
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
h2{margin-top:2.5rem}.best{font-size:1.2rem}</style></head>
<body><h1>Classifica a punti</h1>${boardTable(board)}
<h2>Ultimi 7 giorni</h2>${body}</body></html>`;
}
