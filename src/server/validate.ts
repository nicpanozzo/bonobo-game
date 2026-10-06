// Tutto quello che arriva dalla rete è sconosciuto (#105): un client vecchio, buggato o malevolo
// può mandare null, numeri, array o stringhe enormi. Queste funzioni restituiscono dati puliti
// o null, così i gestori di index.ts non si fidano mai di quello che ricevono.
import { NET_LIMITS } from "../shared/constants";
import type { InputState, MatchRules } from "../shared/types";

export interface JoinData {
  room: string;
  name: string;
  characterId?: string;
  stageId?: string;
  rules?: Partial<MatchRules>;
  bot?: string;
}

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);
const shortString = (v: unknown): string | undefined =>
  typeof v === "string" ? v.slice(0, NET_LIMITS.maxStringLength) : undefined;

// Codice stanza: minuscole, cifre e trattini, 24 caratteri, "lobby" se non resta niente
export function parseRoomCode(raw: unknown): string {
  return String(shortString(raw) || "lobby").toLowerCase().replace(/[^a-z0-9-]/g, "").slice(0, 24) || "lobby";
}

export function parseJoin(raw: unknown): JoinData | null {
  if (!isObject(raw)) return null;
  // Le regole le ripulisce sanitizeRules nella Match: qui si tengono solo i campi semplici di un oggetto
  let rules: Partial<MatchRules> | undefined;
  if (isObject(raw.rules)) {
    rules = {};
    for (const [key, value] of Object.entries(raw.rules)) {
      if (key === "__proto__") continue;
      if (typeof value === "number" || typeof value === "boolean" || typeof value === "string") {
        (rules as Record<string, unknown>)[key] = typeof value === "string" ? value.slice(0, NET_LIMITS.maxStringLength) : value;
      }
    }
  }
  return {
    room: parseRoomCode(raw.room),
    name: shortString(raw.name) ?? "",
    characterId: shortString(raw.characterId),
    stageId: shortString(raw.stageId),
    rules,
    bot: shortString(raw.bot),
  };
}

// Solo booleani: qualunque altra cosa vale "non premuto"
export function parseInput(raw: unknown): InputState | null {
  if (!isObject(raw)) return null;
  return {
    left: raw.left === true,
    right: raw.right === true,
    up: raw.up === true,
    down: raw.down === true,
    light: raw.light === true,
    heavy: raw.heavy === true,
    taunt: raw.taunt === true,
    dodge: raw.dodge === true,
  };
}
