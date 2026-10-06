// Test della classifica (#18 passo 3): somma per nome, ordine, finestra di tempo, HTML sicuro.
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { leaderboardPage, standings, type MatchRecord } from "./leaderboard";

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
