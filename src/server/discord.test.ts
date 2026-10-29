// Test delle statistiche e del messaggio per Discord (#18): nessuna rete, solo eventi finti.
import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";
import { RATING } from "../shared/constants";
import { sanitizeRules } from "../shared/rules";
import type { GameEvent } from "../shared/types";
import { discordHooks, escapeMarkdown, formatResult, funTitles, ratingChanges } from "./discord";
import { Leaderboard } from "./leaderboard";
import { TokenBucket } from "./rateLimit";
import { MatchStats } from "./stats";

const hit = (attackerId: string, targetId: string, damage: number): GameEvent => ({
  type: "hit",
  attackerId,
  targetId,
  kind: "heavy",
  damage,
  percent: 0,
  knockback: 0,
  x: 0,
  y: 0,
});
const ko = (id: string, byId: string | null): GameEvent => ({ type: "ko", id, byId, x: 0, y: 0, stocksLeft: 0 });

describe("statistiche", () => {
  it("sommano danni, KO, cadute e autodistruzioni", () => {
    const s = new MatchStats();
    s.add([hit("a", "b", 13), hit("a", "b", 5), ko("b", "a"), ko("a", null)]);
    assert.deepEqual(s.get("a"), { kos: 1, falls: 1, selfDestructs: 1, damageDealt: 18, damageTaken: 0 });
    assert.deepEqual(s.get("b"), { kos: 0, falls: 1, selfDestructs: 0, damageDealt: 0, damageTaken: 18 });
  });

  it("la rivincita riparte da zero", () => {
    const s = new MatchStats();
    s.add([ko("b", "a"), { type: "matchStart" }]);
    assert.equal(s.get("a").kos, 0);
  });
});

describe("messaggio Discord", () => {
  const players = [
    { id: "a", name: "Luca", team: 0, stocks: 2 },
    { id: "b", name: "Marta", team: 0, stocks: 0 },
  ];
  it("dice chi ha vinto su chi, con una riga per giocatore", () => {
    const s = new MatchStats();
    s.add([hit("a", "b", 40), ko("b", "a"), ko("b", "a"), ko("b", null)]);
    const text = formatResult({ type: "matchEnd", winnerId: "a", winnerTeam: 0, durationMs: 95_000 }, players, (id) => s.get(id), sanitizeRules({}));
    const [head, first, second] = text.split("\n");
    assert.equal(head, "🦍 **Luca** vince su Marta (1:35)");
    assert.equal(first, "👑 Luca: 2 KO, 40% inflitti, 0 cadute");
    assert.equal(second, "• Marta: 0 KO, 0% inflitti, 3 cadute, 1 da solo");
    assert.equal(text.split("\n")[3], "🏅 Kamikaze: Marta · Martello: Luca · Muro: Luca");
  });

  it("i titoli non vanno a nessuno in caso di pari merito", () => {
    const s = new MatchStats();
    s.add([hit("a", "b", 10), hit("b", "a", 10)]);
    assert.deepEqual(funTitles(players, (id) => s.get(id)), []);
    assert.doesNotMatch(formatResult({ type: "matchEnd", winnerId: "a", winnerTeam: 0, durationMs: 0 }, players, (id) => s.get(id), sanitizeRules({})), /🏅/);
  });

  it("a squadre vince la squadra", () => {
    const s = new MatchStats();
    const text = formatResult({ type: "matchEnd", winnerId: "a", winnerTeam: 2, durationMs: 0 }, players, (id) => s.get(id), sanitizeRules({ mode: "teams" }));
    assert.match(text, /^🦍 Vince la squadra \*\*Blu\*\*/);
  });

  it("i nomi restano testo: niente grassetti, spoiler o link", () => {
    assert.equal(escapeMarkdown("**a**||b||"), "\\*\\*a\\*\\*\\|\\|b\\|\\|");
    assert.equal(escapeMarkdown("[x](https://y)"), "\\[x\\]\\(https\\://y\\)");
    assert.equal(escapeMarkdown("Nonna Gina 2"), "Nonna Gina 2");
    const s = new MatchStats();
    const text = formatResult({ type: "matchEnd", winnerId: "a", winnerTeam: 0, durationMs: 0 }, [{ id: "a", name: "_x_", team: 0, stocks: 1 }, players[1]], (id) => s.get(id), sanitizeRules({}));
    assert.match(text, /^🦍 \*\*\\_x\\_\*\* vince su Marta/);
  });
});

describe("limite dei post sul Discord", () => {
  it("oltre il limite i risultati non partono, la classifica sì", () => {
    const sent: string[] = [];
    const realFetch = globalThis.fetch;
    globalThis.fetch = (async (_url: unknown, init?: { body?: string }) => {
      sent.push(init?.body ?? "");
      return new Response(null, { status: 204 });
    }) as typeof fetch;
    try {
      const posts = new TokenBucket(0, 2, Date.now());
      const fighters = [{ id: "a", name: "A", team: 0 }, { id: "b", name: "B", team: 0 }] as never;
      const room = { rules: sanitizeRules({}) } as never;
      for (let i = 0; i < 5; i++) {
        const hooks = discordHooks("https://example.invalid/hook", () => false, undefined, posts);
        hooks.onMatchEnd?.(room, { type: "matchEnd", winnerId: "a", winnerTeam: 0, durationMs: 1000 }, fighters);
      }
      assert.equal(sent.length, 2);
      assert.equal(JSON.parse(sent[0]).flags, 4);
    } finally {
      globalThis.fetch = realFetch;
    }
  });
});

describe("punti in classifica a fine partita", () => {
  const end = (winnerId: string, winnerTeam = 0) => ({ type: "matchEnd" as const, winnerId, winnerTeam, durationMs: 1000 });
  const fakeRoom = (mode: "ffa" | "teams" = "ffa") => {
    const sent: { event: string; data: unknown }[] = [];
    const room = { rules: sanitizeRules({ mode }), broadcast: (event: string, data: unknown) => sent.push({ event, data }) };
    return { room: room as never, sent };
  };
  const withBoard = async (fn: (lb: Leaderboard) => Promise<void> | void) => {
    const dir = await mkdtemp(path.join(tmpdir(), "discord-"));
    try {
      const lb = new Leaderboard(path.join(dir, "classifica.json"));
      await lb.load();
      await fn(lb);
      await lb.flush();
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  };

  it("manda a tutta la stanza i punti di ogni umano, con l'id del suo lottatore", async () => {
    await withBoard((lb) => {
      const { room, sent } = fakeRoom();
      const fighters = [{ id: "s1", name: "Luca", team: 0 }, { id: "bot", name: "Bonobot", team: 0 }, { id: "s2", name: "Marta", team: 0 }] as never;
      discordHooks(undefined, (id) => id === "bot", lb).onMatchEnd?.(room, end("s1"), fighters);
      assert.deepEqual(sent, [
        {
          event: "ratings",
          data: {
            changes: [
              { id: "s1", name: "Luca", rating: RATING.start + RATING.k / 2, delta: RATING.k / 2, tier: lb.board(1)[0].tier, rank: 1 },
              { id: "s2", name: "Marta", rating: RATING.start - RATING.k / 2, delta: -RATING.k / 2, tier: lb.board(2)[1].tier, rank: 2 },
            ],
          },
        },
      ]);
    });
  });

  it("a squadre segna le squadre e la modalità: i compagni prendono gli stessi punti", async () => {
    await withBoard((lb) => {
      const { room, sent } = fakeRoom("teams");
      const fighters = [
        { id: "a", name: "A", team: 1 },
        { id: "b", name: "B", team: 1 },
        { id: "c", name: "C", team: 2 },
        { id: "d", name: "D", team: 2 },
      ] as never;
      discordHooks(undefined, () => false, lb).onMatchEnd?.(room, end("a", 1), fighters);
      const { changes } = sent[0].data as { changes: { id: string; delta: number }[] };
      assert.deepEqual(changes.map((c) => c.delta), [RATING.k / 2, RATING.k / 2, -RATING.k / 2, -RATING.k / 2]);
    });
  });

  it("con meno di due umani la partita non conta e non arrivano punti", async () => {
    await withBoard((lb) => {
      const { room, sent } = fakeRoom();
      const fighters = [{ id: "s1", name: "Luca", team: 0 }, { id: "bot", name: "Bonobot", team: 0 }] as never;
      discordHooks(undefined, (id) => id === "bot", lb).onMatchEnd?.(room, end("s1"), fighters);
      assert.deepEqual(sent, []);
      assert.deepEqual(lb.board(10), []);
    });
  });

  it("due umani con lo stesso nome: i punti vanno solo al primo", () => {
    const changes = ratingChanges([{ id: "x", name: "Luca" }, { id: "y", name: "luca" }], [{ name: "Luca", rating: 1016, delta: 16, tier: "t", rank: 1 }]);
    assert.deepEqual(changes.map((c) => c.id), ["x"]);
  });

  it("il messaggio sul Discord aggiunge i punti a ogni riga", () => {
    const s = new MatchStats();
    const players = [{ id: "a", name: "Luca", team: 0, stocks: 1 }, { id: "b", name: "Marta", team: 0, stocks: 0 }];
    const points = new Map([["a", 16], ["b", -16]]);
    const lines = formatResult(end("a"), players, (id) => s.get(id), sanitizeRules({}), (id) => points.get(id)).split("\n");
    assert.match(lines[1], /^👑 Luca: .*, \+16 punti$/);
    assert.match(lines[2], /^• Marta: .*, -16 punti$/);
  });
});
