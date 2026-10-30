// Classifica a punti: Elo rigiocato in ordine sulle partite salvate (leaderboard.ts).
// Puro e deterministico: le stesse partite danno sempre gli stessi punti, così al riavvio
// del server la classifica si ricostruisce dal file senza salvare i punti a parte.

import { RATING } from "../shared/constants";
import type { MatchRecord } from "./leaderboard";

export interface PlayerRating {
  name: string; // come l'ha scritto l'ultima volta
  rating: number; // punti Elo, con i decimali: si arrotondano solo per mostrarli
  wins: number;
  matches: number;
  streak: number; // vittorie di fila, 0 dopo una sconfitta
  best: number; // punti più alti mai raggiunti
  lastDelta: number; // punti presi o persi nell'ultima partita
}

export type Ratings = Map<string, PlayerRating>;

// Lo stesso amico può cambiare stanza o lottatore e scrivere il nome con maiuscole diverse (come standings())
export const nameKey = (name: string) => name.trim().toLowerCase();

export const newRating = (name: string): PlayerRating => ({
  name,
  rating: RATING.start,
  wins: 0,
  matches: 0,
  streak: 0,
  best: RATING.start,
  lastDelta: 0,
});

// Il grado: l'ultimo dei RATING.tiers (dal più basso) di cui si hanno i punti minimi
export function tierOf(rating: number): string {
  let name = RATING.tiers[0].name;
  for (const t of RATING.tiers) if (Math.round(rating) >= t.min) name = t.name;
  return name;
}

// Probabilità che a batta b secondo Elo (400 punti di differenza = 10 a 1)
export const expectedScore = (a: number, b: number) => 1 / (1 + 10 ** ((b - a) / 400));

type RecordPlayer = MatchRecord["players"][number];

// Chi conta in una partita: un nome solo una volta (due "Luca" nella stessa stanza valgono come il primo)
function uniquePlayers(record: MatchRecord): RecordPlayer[] {
  const seen = new Set<string>();
  return record.players.filter((p) => {
    const key = nameKey(p.name);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// Posizione di ognuno (1 = primo, pari merito = stessa posizione): place salvato se c'è, altrimenti
// chi ha vinto davanti (a squadre tutta la squadra è prima), poi più KO, meno cadute, più danni
export function placements(players: readonly RecordPlayer[]): number[] {
  if (players.every((p) => typeof p.place === "number")) return players.map((p) => p.place as number);
  const cmp = (a: RecordPlayer, b: RecordPlayer) =>
    Number(b.won) - Number(a.won) || (b.won ? 0 : b.kos - a.kos || a.falls - b.falls || b.damageDealt - a.damageDealt);
  const order = players.map((p, i) => i).sort((i, j) => cmp(players[i], players[j]));
  const place = new Array<number>(players.length);
  order.forEach((idx, pos) => {
    const prev = order[pos - 1];
    place[idx] = pos > 0 && cmp(players[prev], players[idx]) === 0 ? place[prev] : pos + 1;
  });
  return place;
}

// Squadra 0 o assente = ognuno per sé (tutti contro tutti, Corsa)
const teamOf = (p: RecordPlayer, i: number) => (p.team && p.team > 0 ? `t${p.team}` : `p${i}`);

// Quanto cambia ognuno in questa partita, per nome normalizzato. Non tocca ratings.
// Ogni coppia di avversari è una mini partita Elo; il K di coppia si divide per il numero massimo
// di avversari di un giocatore (n - 1 tutti contro tutti), così in otto non si vincono 7 volte i punti
// e la somma dei cambi resta zero. I compagni di squadra non si confrontano tra loro.
export function rateMatch(ratings: ReadonlyMap<string, PlayerRating>, record: MatchRecord): Map<string, number> {
  const players = uniquePlayers(record);
  const deltas = new Map<string, number>();
  if (players.length < 2) return deltas;
  const teams = players.map(teamOf);
  const teamSize = new Map<string, number>();
  for (const t of teams) teamSize.set(t, (teamSize.get(t) ?? 0) + 1);
  const maxOpponents = players.length - Math.min(...teamSize.values());
  if (maxOpponents < 1) return deltas; // tutti nella stessa squadra: nessun avversario
  const k = RATING.k / maxOpponents;
  const place = placements(players);
  const before = players.map((p) => ratings.get(nameKey(p.name))?.rating ?? RATING.start);
  for (let i = 0; i < players.length; i++) {
    let delta = 0;
    for (let j = 0; j < players.length; j++) {
      if (i === j || teams[i] === teams[j]) continue;
      const actual = place[i] < place[j] ? 1 : place[i] > place[j] ? 0 : 0.5;
      delta += k * (actual - expectedScore(before[i], before[j]));
    }
    deltas.set(nameKey(players[i].name), delta);
  }
  return deltas;
}

export interface AppliedChange {
  key: string;
  name: string;
  rating: number; // arrotondati, come si mostrano
  delta: number; // differenza tra i punti arrotondati, così "prima + delta = dopo" torna sempre
}

// Applica la partita a ratings (lo cambia) e dice cosa è cambiato per ognuno
export function applyMatch(ratings: Ratings, record: MatchRecord): AppliedChange[] {
  const deltas = rateMatch(ratings, record);
  const out: AppliedChange[] = [];
  for (const p of uniquePlayers(record)) {
    const key = nameKey(p.name);
    const r = ratings.get(key) ?? newRating(p.name);
    const before = Math.round(r.rating);
    r.name = p.name.trim() || r.name;
    r.rating += deltas.get(key) ?? 0;
    r.matches++;
    if (p.won) r.wins++;
    r.streak = p.won ? r.streak + 1 : 0;
    r.best = Math.max(r.best, r.rating);
    r.lastDelta = Math.round(r.rating) - before;
    ratings.set(key, r);
    out.push({ key, name: r.name, rating: Math.round(r.rating), delta: r.lastDelta });
  }
  return out;
}

// Tutte le partite in ordine, da zero o da una base (le partite più vecchie già tolte dal file)
export function computeRatings(records: readonly MatchRecord[], base?: Iterable<[string, PlayerRating]>): Ratings {
  const ratings: Ratings = new Map();
  if (base) for (const [key, r] of base) ratings.set(key, { ...r });
  for (const r of records) applyMatch(ratings, r);
  return ratings;
}

// Il tabellone: solo chi ha almeno RATING.minMatches partite, dal più forte.
// A pari punti più vittorie, più partite, poi il nome, così l'ordine non dipende dall'arrivo
export function rankRatings(ratings: Iterable<PlayerRating>): PlayerRating[] {
  return [...ratings]
    .filter((r) => r.matches >= RATING.minMatches)
    .sort(
      (a, b) =>
        Math.round(b.rating) - Math.round(a.rating) ||
        b.wins - a.wins ||
        b.matches - a.matches ||
        (a.name < b.name ? -1 : a.name > b.name ? 1 : 0),
    );
}
