// Regole della partita: valori di default e controllo di quelle che arrivano dai client.

import { STOCKS } from "./constants";
import type { MatchRules } from "./types";

export const DEFAULT_RULES: MatchRules = {
  mode: "ffa",
  stocks: STOCKS,
  timeLimitSec: 0,
  friendlyFire: false,
};

export const RULE_LIMITS = {
  maxStocks: 9,
  maxTimeLimitSec: 15 * 60,
};

// Il server non si fida: tutto quello che arriva viene riportato in valori validi
export function sanitizeRules(raw: Partial<MatchRules> | undefined): MatchRules {
  const r = raw && typeof raw === "object" ? raw : {};
  const int = (v: unknown, min: number, max: number, fallback: number) =>
    typeof v === "number" && Number.isFinite(v) ? Math.max(min, Math.min(max, Math.round(v))) : fallback;
  return {
    mode: r.mode === "teams" || r.mode === "flag" || r.mode === "race" ? r.mode : "ffa",
    stocks: int(r.stocks, 1, RULE_LIMITS.maxStocks, DEFAULT_RULES.stocks),
    timeLimitSec: int(r.timeLimitSec, 0, RULE_LIMITS.maxTimeLimitSec, DEFAULT_RULES.timeLimitSec),
    friendlyFire: typeof r.friendlyFire === "boolean" ? r.friendlyFire : DEFAULT_RULES.friendlyFire,
  };
}

// Modalità in cui si gioca divisi in due squadre
export const isTeamMode = (rules: MatchRules) => rules.mode === "teams" || rules.mode === "flag";

// Chi può colpire chi: tra compagni di squadra solo con il fuoco amico
export function canHitWithRules(rules: MatchRules, attackerTeam: number, targetTeam: number): boolean {
  return !isTeamMode(rules) || rules.friendlyFire || attackerTeam !== targetTeam;
}

// Bandiera (#56): vince chi arriva ai punti, o chi è avanti allo scadere del tempo.
// A pari punti allo scadere si continua finché qualcuno segna (punto d'oro).
export function flagWinnerTeam(rules: MatchRules, scores: Record<1 | 2, number>, timeUp: boolean): 1 | 2 | undefined {
  for (const team of [1, 2] as const) if (scores[team] >= rules.stocks) return team;
  if (timeUp && scores[1] !== scores[2]) return scores[1] > scores[2] ? 1 : 2;
  return undefined;
}

export interface Standing {
  id: string;
  team: number;
  stocks: number;
  percent: number;
  eliminated: boolean;
}

// Chi vince allo scadere del tempo: più vite, poi meno percentuale.
// A squadre contano le vite sommate dei compagni.
export function leaderOnTime(rules: MatchRules, players: Standing[]): Standing | undefined {
  if (players.length === 0) return undefined;
  if (rules.mode === "teams") {
    const score = (team: number) => {
      const members = players.filter((p) => p.team === team);
      return { stocks: members.reduce((s, p) => s + Math.max(0, p.stocks), 0), percent: members.reduce((s, p) => s + p.percent, 0) };
    };
    const [a, b] = [score(1), score(2)];
    const winnerTeam = a.stocks !== b.stocks ? (a.stocks > b.stocks ? 1 : 2) : a.percent <= b.percent ? 1 : 2;
    return players.find((p) => p.team === winnerTeam && !p.eliminated) ?? players.find((p) => p.team === winnerTeam);
  }
  return [...players].sort((x, y) => y.stocks - x.stocks || x.percent - y.percent)[0];
}

// Chi vince quando restano in gioco solo lui (o solo la sua squadra); undefined se la partita continua
export function lastStanding(rules: MatchRules, players: Standing[]): Standing | undefined {
  const alive = players.filter((p) => !p.eliminated);
  if (players.length < 2 || alive.length === 0 || rules.mode === "flag" || rules.mode === "race") return undefined;
  if (rules.mode === "teams") {
    const teamsInGame = new Set(players.map((p) => p.team));
    const teamsAlive = new Set(alive.map((p) => p.team));
    return teamsInGame.size >= 2 && teamsAlive.size === 1 ? alive[0] : undefined;
  }
  return alive.length === 1 ? alive[0] : undefined;
}
