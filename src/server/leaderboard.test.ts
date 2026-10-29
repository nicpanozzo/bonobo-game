// Test della classifica (#18 passo 3): somma per nome, ordine, finestra di tempo, HTML sicuro, punti e file.
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";
import { LEADERBOARD, RATING } from "../shared/constants";
import { Leaderboard, leaderboardPage, standings, type MatchRecord } from "./leaderboard";

const p = (name: string, won: boolean, kos = 0, falls = 0) => ({ name, won, kos, falls, damageDealt: 10 });

describe("classifica", () => {
  const records: MatchRecord[] = [
    { t: 100, players: [p("Luca", true, 3), p("Marta", false, 1, 3)] },
    { t: 200, players: [p("marta ", true, 2), p("Luca", false, 0, 2)] },
    { t: 300, players: [p("Luca", true, 1), p("Gianni", false)] },
  ];

  it("somma le partite per nome, senza badare a maiuscole e spazi", () => {
    const rows = standings(records, 0);
    assert.deepEqual(
      rows.map((r) => [r.name, r.wins, r.matches, r.kos]),
      [
        ["Luca", 2, 3, 4],
        ["Marta", 1, 2, 3],
        ["Gianni", 0, 1, 0],
      ],
    );
  });

  it("conta solo le partite dopo since", () => {
    assert.deepEqual(
      standings(records, 150).map((r) => r.name),
      ["marta ", "Luca", "Gianni"], // a pari vittorie conta chi ha fatto più KO
    );
  });

  it("la pagina mostra il bonobo della settimana e non esegue i nomi come HTML", () => {
    const html = leaderboardPage(standings([{ t: 0, players: [p("<b>x</b>", true)] }], 0));
    assert.match(html, /Bonobo della settimana: <b>&#60;b&#62;x&#60;\/b&#62;<\/b>/);
    assert.ok(!html.includes("<b>x</b>"));
  });
});

describe("classifica a punti", () => {
  const withFile = async (fn: (file: string) => Promise<void>) => {
    const dir = await mkdtemp(path.join(tmpdir(), "classifica-"));
    try {
      await fn(path.join(dir, "classifica.json"));
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  };

  it("record() dice i punti presi e persi, board() ordina per punti", async () => {
    await withFile(async (file) => {
      const lb = new Leaderboard(file);
      await lb.load();
      const changes = lb.record({ t: 1, players: [p("Luca", true), p("Marta", false)] });
      assert.deepEqual(
        changes.map((c) => [c.name, c.rating, c.delta, c.rank]),
        [
          ["Luca", RATING.start + RATING.k / 2, RATING.k / 2, 1],
          ["Marta", RATING.start - RATING.k / 2, -RATING.k / 2, 2],
        ],
      );
      lb.record({ t: 2, players: [p("Gianni", true), p("marta", false)] });
      assert.deepEqual(lb.board(10).map((r) => r.name), ["Luca", "Gianni", "marta"]);
      assert.deepEqual(lb.board(1).map((r) => [r.wins, r.matches, r.streak]), [[1, 1, 1]]);
      assert.equal(lb.board(10)[2].streak, 0);
      assert.deepEqual(lb.board(0), []);
    });
  });

  it("al riavvio i punti si ricostruiscono uguali dal file", async () => {
    await withFile(async (file) => {
      const lb = new Leaderboard(file);
      await lb.load();
      lb.record({ t: 1, players: [p("Luca", true, 2), p("Marta", false)] });
      lb.record({ t: 2, players: [p("Marta", true), p("Luca", false), p("Gianni", false)] });
      await lb.flush();
      const again = new Leaderboard(file);
      await again.load();
      assert.deepEqual(again.board(10), lb.board(10));
      assert.deepEqual(again.week(10), lb.week(10));
    });
  });

  it("legge il file di prima (solo l'elenco delle partite, senza squadra né modalità)", async () => {
    await withFile(async (file) => {
      await writeFile(file, JSON.stringify([{ t: 5, players: [p("Luca", true), p("Marta", false)] }]));
      const lb = new Leaderboard(file);
      await lb.load();
      assert.deepEqual(lb.board(10).map((r) => r.name), ["Luca", "Marta"]);
      const [luca] = lb.week(10);
      assert.equal(luca.rating, RATING.start + RATING.k / 2);
      assert.equal(typeof luca.tier, "string");
    });
  });

  it("le partite tolte dal file oltre maxMatches non cambiano i punti", async () => {
    await withFile(async (file) => {
      const lb = new Leaderboard(file);
      await lb.load();
      for (let i = 0; i < LEADERBOARD.maxMatches + 3; i++) lb.record({ t: i, players: [p("Luca", i % 3 > 0), p("Marta", i % 3 === 0)] });
      await lb.flush();
      const saved = JSON.parse(await readFile(file, "utf8"));
      assert.equal(saved.records.length, LEADERBOARD.maxMatches);
      const again = new Leaderboard(file);
      await again.load();
      assert.deepEqual(again.board(10), lb.board(10));
      assert.equal(lb.board(10)[0].matches, LEADERBOARD.maxMatches + 3);
    });
  });

  it("la pagina mostra i punti sopra e la settimana sotto, con i nomi come testo", () => {
    const html = leaderboardPage(standings([{ t: 0, players: [p("Luca", true)] }], 0), [{ name: "<i>x</i>", rating: 1016, tier: "Babbuino", wins: 1, matches: 2, streak: 1 }]);
    assert.ok(html.indexOf("Classifica a punti") < html.indexOf("Ultimi 7 giorni"));
    assert.match(html, /&#60;i&#62;x&#60;\/i&#62;/);
    assert.ok(!html.includes("<i>x</i>"));
    assert.match(html, /<b>1016<\/b><\/td><td>1\/2<\/td>/);
  });
});
