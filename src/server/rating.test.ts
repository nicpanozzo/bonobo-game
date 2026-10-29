// Test della classifica a punti: conti Elo, squadre, tanti giocatori, gradi e ripetibilità.
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { RATING } from "../shared/constants";
import type { MatchRecord } from "./leaderboard";
import { applyMatch, computeRatings, newRating, placements, rankRatings, rateMatch, tierOf, type Ratings } from "./rating";

type P = MatchRecord["players"][number];
const p = (name: string, won: boolean, extra: Partial<P> = {}): P => ({ name, won, kos: 0, falls: 0, damageDealt: 0, ...extra });
const at = (entries: [string, number][]): Ratings => new Map(entries.map(([n, r]) => [n, { ...newRating(n), rating: r }]));
const sum = (m: Map<string, number>) => [...m.values()].reduce((a, b) => a + b, 0);
const close = (a: number, b: number) => assert.ok(Math.abs(a - b) < 1e-9, `${a} != ${b}`);

describe("Elo", () => {
  it("in due a pari punti chi vince prende k/2 e la somma è zero", () => {
    const d = rateMatch(new Map(), { t: 0, players: [p("Luca", true), p("Marta", false)] });
    close(d.get("luca")!, RATING.k / 2);
    close(d.get("marta")!, -RATING.k / 2);
    close(sum(d), 0);
  });

  it("è simmetrico: scambiando l'ordine dei giocatori non cambia niente", () => {
    const r = at([["luca", 1100], ["marta", 950]]);
    const a = rateMatch(r, { t: 0, players: [p("Luca", false), p("Marta", true)] });
    const b = rateMatch(r, { t: 0, players: [p("Marta", true), p("Luca", false)] });
    assert.deepEqual(a, new Map([...b].reverse()));
  });

  it("la sorpresa vale di più: battere uno più forte dà più punti", () => {
    const r = at([["forte", 1300], ["debole", 900]]);
    const upset = rateMatch(r, { t: 0, players: [p("Forte", false), p("Debole", true)] }).get("debole")!;
    const expected = rateMatch(r, { t: 0, players: [p("Forte", true), p("Debole", false)] }).get("forte")!;
    assert.ok(upset > expected && upset > RATING.k / 2 && expected < RATING.k / 2);
  });

  it("a squadre i compagni non si confrontano e tutta la squadra vincente prende uguale", () => {
    const d = rateMatch(new Map(), {
      t: 0,
      players: [p("A", true, { team: 1, kos: 0 }), p("B", true, { team: 1, kos: 5 }), p("C", false, { team: 2, kos: 9 }), p("D", false, { team: 2 })],
    });
    close(d.get("a")!, d.get("b")!);
    close(d.get("c")!, d.get("d")!);
    // Due avversari a testa, k diviso per due: in totale come una partita a due
    close(d.get("a")!, RATING.k / 2);
    close(sum(d), 0);
  });

  it("in tanti tutti contro tutti il primo non prende 7 volte i punti", () => {
    const names = ["a", "b", "c", "d", "e", "f", "g", "h"];
    const d = rateMatch(new Map(), { t: 0, players: names.map((n, i) => p(n, i === 0, { kos: 10 - i })) });
    close(d.get("a")!, RATING.k / 2); // batte tutti e 7, ma con k / 7 per coppia
    close(d.get("h")!, -RATING.k / 2);
    close(sum(d), 0);
    assert.ok(d.get("b")! > d.get("c")! && d.get("c")! > 0 && d.get("g")! < 0);
  });

  it("le posizioni: vincitore, poi più KO, meno cadute, più danni; pari merito = stessa posizione", () => {
    assert.deepEqual(
      placements([p("x", false, { kos: 1 }), p("w", true), p("y", false, { kos: 1, falls: 2 }), p("z", false, { kos: 1 })]),
      [2, 1, 4, 2],
    );
    assert.deepEqual(placements([p("x", false, { place: 2 }), p("y", true, { place: 1 })]), [2, 1]);
  });

  it("un nome ripetuto nella stessa partita conta una volta sola", () => {
    const d = rateMatch(new Map(), { t: 0, players: [p("Luca", true), p("luca ", false), p("Marta", false)] });
    assert.deepEqual([...d.keys()], ["luca", "marta"]);
  });
});

describe("rigiocare le partite", () => {
  const records: MatchRecord[] = [
    { t: 1, players: [p("Luca", true), p("Marta", false)] },
    { t: 2, players: [p("marta", true), p("Luca", false), p("Gianni", false)] },
    { t: 3, players: [p("Luca", true), p("Gianni", false)] },
    { t: 4, players: [p("Luca", true), p("Gianni", false)] },
  ];

  it("dà sempre gli stessi punti", () => {
    assert.deepEqual(computeRatings(records), computeRatings(records.map((r) => structuredClone(r))));
  });

  it("conta vittorie, partite, vittorie di fila, record e ultimo cambio", () => {
    const luca = computeRatings(records).get("luca")!;
    assert.deepEqual([luca.wins, luca.matches, luca.streak], [3, 4, 2]);
    assert.ok(luca.best >= luca.rating && luca.lastDelta > 0);
    assert.equal(computeRatings(records).get("marta")!.streak, 1);
  });

  it("partire da una base è come rigiocare anche le partite vecchie", () => {
    const base: Ratings = new Map();
    for (const r of records.slice(0, 2)) applyMatch(base, r);
    assert.deepEqual(computeRatings(records.slice(2), base), computeRatings(records));
  });

  it("il delta mostrato torna con i punti arrotondati", () => {
    const ratings: Ratings = new Map();
    for (const r of records) {
      const before = new Map([...ratings].map(([k, v]) => [k, Math.round(v.rating)]));
      for (const c of applyMatch(ratings, r)) assert.equal((before.get(c.key) ?? RATING.start) + c.delta, c.rating);
    }
  });

  it("il tabellone esclude chi ha poche partite e ordina per punti", () => {
    const ranked = rankRatings(computeRatings(records).values());
    assert.deepEqual(ranked.map((r) => r.name), ["Luca", "marta", "Gianni"]);
    assert.ok(ranked.every((r) => r.matches >= RATING.minMatches));
    assert.deepEqual(rankRatings([{ ...newRating("nuovo"), matches: RATING.minMatches - 1 }]), []);
  });
});

describe("gradi", () => {
  it("si ha il grado più alto di cui si hanno i punti minimi", () => {
    const tiers = RATING.tiers;
    assert.equal(tierOf(0), tiers[0].name);
    assert.equal(tierOf(-50), tiers[0].name);
    for (const t of tiers) assert.equal(tierOf(t.min), t.name);
    assert.equal(tierOf(tiers[1].min - 1), tiers[0].name);
    assert.equal(tierOf(99999), tiers[tiers.length - 1].name);
  });
});
