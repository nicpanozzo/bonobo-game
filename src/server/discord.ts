// Risultati delle partite nel canale Discord (#18). Il webhook arriva solo dalla variabile
// d'ambiente DISCORD_WEBHOOK_URL (mai nel codice né nei log): senza, non succede niente.

import { TEAM_NAMES } from "../shared/constants";
import type { MatchEndEvent } from "../shared/match";
import type { Fighter } from "../shared/physics";
import type { MatchRules } from "../shared/types";
import type { Leaderboard } from "./leaderboard";
import type { RoomHooks } from "./Room";
import { MatchStats, type PlayerStats } from "./stats";

export interface Player {
  id: string;
  name: string;
  team: number;
  stocks: number;
}

// Il messaggio per il canale: chi ha vinto e una riga per giocatore
export function formatResult(result: MatchEndEvent, players: readonly Player[], stats: (id: string) => PlayerStats, rules: MatchRules): string {
  const winner = players.find((p) => p.id === result.winnerId);
  const minutes = Math.floor(result.durationMs / 60000);
  const seconds = Math.round((result.durationMs % 60000) / 1000);
  const time = `${minutes}:${String(seconds).padStart(2, "0")}`;
  let head: string;
  if (rules.mode === "race") head = `🏁 **${winner?.name ?? "Qualcuno"}** arriva primo al traguardo`;
  else if (result.winnerTeam === 1 || result.winnerTeam === 2) head = `🦍 Vince la squadra **${TEAM_NAMES[result.winnerTeam]}**`;
  else {
    const losers = players.filter((p) => p !== winner).map((p) => p.name);
    head = `🦍 **${winner?.name ?? "Qualcuno"}** vince${losers.length ? ` su ${losers.join(", ")}` : ""}`;
  }
  // Prima chi ha fatto più KO, poi chi ha fatto più danni
  const lines = [...players]
    .sort((a, b) => stats(b.id).kos - stats(a.id).kos || stats(b.id).damageDealt - stats(a.id).damageDealt)
    .map((p) => {
      const s = stats(p.id);
      const parts = [`${s.kos} KO`, `${Math.round(s.damageDealt)}% inflitti`, s.falls === 1 ? "1 caduta" : `${s.falls} cadute`];
      if (s.selfDestructs) parts.push(`${s.selfDestructs} da solo`);
      return `${p.id === result.winnerId ? "👑" : "•"} ${p.name}: ${parts.join(", ")}`;
    });
  const titles = funTitles(players, stats);
  return [`${head} (${time})`, ...lines, ...(titles.length ? [`🏅 ${titles.join(" · ")}`] : [])].join("\n");
}

// TODO community: nomi e titoli nostri, magari dai tormentoni del canale
const TITLES: { name: string; score: (s: PlayerStats) => number; min: number }[] = [
  { name: "Kamikaze", score: (s) => s.selfDestructs, min: 1 }, // più cadute da solo
  { name: "Martello", score: (s) => s.damageDealt, min: 1 }, // più danni inflitti
  { name: "Muro", score: (s) => -s.damageTaken, min: -Infinity }, // meno danni subiti
];

// I titoli della partita: vanno a uno solo, quindi niente titolo se c'è un pari merito
export function funTitles(players: readonly Player[], stats: (id: string) => PlayerStats): string[] {
  if (players.length < 2) return [];
  const out: string[] = [];
  for (const t of TITLES) {
    const scores = players.map((p) => ({ p, v: t.score(stats(p.id)) })).sort((a, b) => b.v - a.v);
    const [best, next] = scores;
    if (best.v >= t.min && best.v > next.v) out.push(`${t.name}: ${best.p.name}`);
  }
  return out;
}

// Invio al webhook con fetch, senza librerie. Un errore di rete non deve mai fermare la partita.
export async function postToDiscord(url: string, content: string): Promise<void> {
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content, allowed_mentions: { parse: [] } }), // i nomi non taggano nessuno
    });
    if (!res.ok) console.warn(`[discord] il webhook ha risposto ${res.status}`);
  } catch (err) {
    console.warn(`[discord] invio non riuscito: ${(err as Error).message}`);
  }
}

// I ganci per una stanza: contano le statistiche e a fine partita postano il risultato
// e lo segnano in classifica. Le partite con meno di due umani (es. da soli contro un bot) non contano.
export function discordHooks(webhookUrl: string | undefined, isBot: (id: string) => boolean, leaderboard?: Leaderboard): RoomHooks {
  const stats = new MatchStats();
  return {
    onEvents: (_room, events) => stats.add(events),
    onMatchEnd: (room, result, fighters: readonly Fighter[]) => {
      const humans = fighters.filter((f) => !isBot(f.id));
      if (humans.length < 2) return;
      leaderboard?.record({
        t: Date.now(),
        players: humans.map((f) => {
          const s = stats.get(f.id);
          const won = result.winnerTeam === 1 || result.winnerTeam === 2 ? f.team === result.winnerTeam : f.id === result.winnerId;
          return { name: f.name, won, kos: s.kos, falls: s.falls, damageDealt: s.damageDealt };
        }),
      });
      if (webhookUrl) void postToDiscord(webhookUrl, formatResult(result, fighters, (id) => stats.get(id), room.rules));
    },
  };
}
