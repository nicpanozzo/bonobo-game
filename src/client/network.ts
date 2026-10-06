import { io, type Socket } from "socket.io-client";
import type { ClientToServer, MatchRules, ServerToClient } from "../shared/types";

export type GameSocket = Socket<ServerToClient, ClientToServer>;

// Quello che serve per entrare in partita: lo sceglie la lobby, o arriva dal link.
export interface JoinChoice {
  room: string;
  name: string;
  characterId?: string;
  stageId?: string; // conta solo se la stanza è nuova
  rules?: Partial<MatchRules>; // idem
}

const PROFILE_KEY = "bonobo.profile";

// Stanza, nome e personaggio dall'indirizzo: ?room=amici&name=Nico&char=egiainuso
// (i link vecchi continuano a funzionare), altrimenti dall'ultima visita.
export function readJoinDefaults(): Partial<JoinChoice> {
  const params = new URLSearchParams(location.search);
  const saved = loadProfile();
  return {
    room: params.get("room") || undefined,
    name: params.get("name") || saved.name,
    characterId: params.get("char") || saved.characterId,
    stageId: params.get("stage") || saved.stageId,
    rules: saved.rules,
  };
}

// Con stanza e nome nell'URL si entra subito, come prima della lobby
export function hasDirectJoin(d: Partial<JoinChoice>): d is JoinChoice {
  return new URLSearchParams(location.search).has("name") && !!d.room && !!d.name;
}

export function randomRoom(): string {
  return Math.random().toString(36).slice(2, 7);
}

// Il link da mandare agli amici porta solo la stanza: nome e personaggio li sceglie ognuno
export function roomLink(room: string): string {
  return `${location.origin}${location.pathname}?room=${encodeURIComponent(room)}`;
}

export function saveProfile(choice: JoinChoice) {
  // La stanza va nell'URL, così ricaricare la pagina riporta nella stessa stanza
  history.replaceState(null, "", `?room=${encodeURIComponent(choice.room)}`);
  try {
    localStorage.setItem(PROFILE_KEY, JSON.stringify({ name: choice.name, characterId: choice.characterId, stageId: choice.stageId, rules: choice.rules }));
  } catch {
    // Navigazione privata o archiviazione bloccata: pazienza, si riscrive il nome la prossima volta
  }
}

function loadProfile(): { name?: string; characterId?: string; stageId?: string; rules?: Partial<MatchRules> } {
  try {
    const p = JSON.parse(localStorage.getItem(PROFILE_KEY) ?? "{}");
    const str = (v: unknown) => (typeof v === "string" ? v : undefined);
    // Le regole salvate passano comunque da sanitizeRules sul server
    const rules = p.rules && typeof p.rules === "object" ? (p.rules as Partial<MatchRules>) : undefined;
    return { name: str(p.name), characterId: str(p.characterId), stageId: str(p.stageId), rules };
  } catch {
    return {};
  }
}

export function connect(): GameSocket {
  // Stesso indirizzo della pagina: in sviluppo ci pensa il proxy di Vite.
  // Se il server sta altrove, imposta VITE_SERVER_URL.
  const url = import.meta.env.VITE_SERVER_URL as string | undefined;
  return url ? io(url) : io();
}
