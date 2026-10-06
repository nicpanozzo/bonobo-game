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

// Caratteri invisibili o che girano il testo (controllo, larghezza zero, RTL, mezze emoji tagliate dal limite
// di maxStringLength): in un nome servono solo a ingannare. Lo ZWJ si tiene solo dentro le emoji composte
const INVISIBLE = /[\p{Cc}\p{Cf}\p{Cs}]/gu;
const ZWJ = "\u200D";
const LONE_ZWJ = /(?<!\p{Extended_Pictographic}\uFE0F?)\u200D|\u200D(?!\p{Extended_Pictographic})/gu;
const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const cut = (text: string, max: number) =>
  Array.from(graphemes.segment(text), (s) => s.segment)
    .slice(0, max)
    .join("");

// Nome pulito, lungo al massimo NET_LIMITS.maxNameLength caratteri veri (un'emoji non si spezza),
// "Bonobo" se vuoto e "Nome 2", "Nome 3"... se qualcuno nella stanza si chiama già così
export function sanitizeName(raw: string, taken: readonly string[] = []): string {
  const max = NET_LIMITS.maxNameLength;
  const clean = raw
    .replace(LONE_ZWJ, "")
    .replace(/\s+/gu, " ")
    .replace(INVISIBLE, (c) => (c === ZWJ ? c : ""))
    .replace(/ +/g, " ")
    .trim();
  const name = cut(clean, max).trim() || "Bonobo";
  const used = new Set(taken.map((n) => n.toLowerCase()));
  if (!used.has(name.toLowerCase())) return name;
  for (let n = 2; ; n++) {
    const suffix = ` ${n}`;
    const candidate = `${cut(name, max - suffix.length).trim()}${suffix}`;
    if (!used.has(candidate.toLowerCase())) return candidate;
  }
}
