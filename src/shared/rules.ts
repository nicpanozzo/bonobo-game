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
    mode: r.mode === "teams" ? "teams" : "ffa",
    stocks: int(r.stocks, 1, RULE_LIMITS.maxStocks, DEFAULT_RULES.stocks),
    timeLimitSec: int(r.timeLimitSec, 0, RULE_LIMITS.maxTimeLimitSec, DEFAULT_RULES.timeLimitSec),
    friendlyFire: typeof r.friendlyFire === "boolean" ? r.friendlyFire : DEFAULT_RULES.friendlyFire,
  };
}
