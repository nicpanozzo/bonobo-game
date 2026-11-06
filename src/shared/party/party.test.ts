import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { PARTY } from "../constants";
import type { MinigameInfo, PartySnapshot } from "../types";
import { BOARD_LOOP, crownSpots, makeBoard } from "./board";
import { Party, type PartyMember } from "./party";
import { minigamesFor } from "./minigames";

const STEP = 1000 / 60;

const member = (id: string, bot = false): PartyMember => ({ id, name: id.toUpperCase(), characterId: "default", skinId: "", color: 0xffffff, bot });

function party(players: PartyMember[], o: { rounds?: number; pick?: "random" | "vote"; seed?: number; minigames?: MinigameInfo[] } = {}) {
  return new Party({ seed: o.seed ?? 7, rounds: o.rounds ?? 3, pick: o.pick ?? "random", players, minigames: o.minigames ?? minigamesFor(players.length) });
}

// Fa avanzare il tabellone finché vale until, al massimo per maxMs; i comandi degli umani li decide act
function run(p: Party, maxMs: number, until: (p: Party) => boolean, act?: (p: Party) => void): PartySnapshot[] {
  const snaps: PartySnapshot[] = [];
  for (let t = 0; t < maxMs && !until(p); t += STEP) {
    act?.(p);
    p.step(STEP);
    snaps.push(p.snapshot(t));
  }
  return snaps;
}

describe("Bonobo Party: tabellone", () => {
  it("il giro è chiuso, l'incrocio ha due strade e la scorciatoia rientra nel giro", () => {
    const sq = makeBoard(3);
    assert.equal(sq[0].kind, "start");
    const forks = sq.filter((s) => s.next.length === 2);
    assert.equal(forks.length, 1);
    // Partendo da ogni casella si torna alla partenza in meno di BOARD_LOOP passi seguendo la prima strada
    for (let i = 0; i < sq.length; i++) {
      let at = i;
      let steps = 0;
      while (at !== 0 && steps <= BOARD_LOOP) {
        at = sq[at].next[0];
        steps++;
      }
      assert.equal(at, 0, `dalla casella ${i} si torna alla partenza`);
    }
    for (const s of sq) {
      assert.ok(s.x >= 0 && s.x <= 1 && s.y >= 0 && s.y <= 1);
      for (const n of s.next) assert.ok(n >= 0 && n < sq.length);
    }
    assert.ok(sq.filter((s) => s.kind === "bottega").length >= 2);
    assert.ok(crownSpots(sq).length > 10);
  });

  it("stesso seme, stesso tabellone; semi diversi, caselle diverse", () => {
    assert.deepEqual(makeBoard(5), makeBoard(5));
    assert.notDeepEqual(
      makeBoard(5).map((s) => s.kind),
      makeBoard(6).map((s) => s.kind),
    );
  });
});

describe("Bonobo Party: la partita", () => {
  it("con soli bot si arriva da soli al minigioco, poi al feedback e al giro dopo", () => {
    const p = party([member("a", true), member("b", true), member("c", true)]);
    run(p, 120_000, (q) => q.phase === "minigame");
    assert.equal(p.phase, "minigame");
    assert.ok(p.minigame);
    run(p, 10_000, (q) => q.minigameReady);
    assert.ok(p.minigameReady);
    p.minigameDone({ a: 1, b: 2, c: 3 });
    const snap = p.snapshot(0);
    assert.equal(snap.phase, "feedback");
    assert.deepEqual(snap.lastResults?.bananas, { a: PARTY.placeBananas[0], b: PARTY.placeBananas[1], c: PARTY.placeBananas[2] });
    assert.equal(snap.players.find((x) => x.id === "a")?.wins, 1);
    // I bot non danno feedback: si va avanti subito
    run(p, 3000, (q) => q.phase !== "feedback");
    assert.equal(p.round, 2);
  });

  it("si arriva al podio dopo l'ultimo giro e il vincitore è il primo in classifica", () => {
    const p = party([member("a", true), member("b", true)], { rounds: PARTY.minRounds });
    for (let r = 0; r < PARTY.minRounds; r++) {
      run(p, 200_000, (q) => q.minigameReady);
      p.minigameDone({ a: 1, b: 2 });
    }
    run(p, 5000, (q) => q.phase === "podium");
    const snap = p.snapshot(0);
    assert.equal(snap.phase, "podium");
    assert.equal(snap.winnerId, p.standings()[0].id);
    assert.ok(snap.players.find((x) => x.id === "a")!.crowns >= PARTY.bonusCrowns, "il re dei minigiochi prende la Corona bonus");
    run(p, PARTY.podiumMs + 1000, (q) => q.finished);
    assert.ok(p.finished);
  });

  it("tocca a un umano: solo lui può tirare, e se non tira il server tira per lui", () => {
    const p = party([member("a"), member("b")], { seed: 11 });
    run(p, PARTY.introMs + 100, (q) => q.phase === "roll");
    const first = p.turnId!;
    const other = first === "a" ? "b" : "a";
    p.command(other, { kind: "roll" });
    assert.equal(p.phase, "roll", "chi non è di turno non tira");
    p.command(first, { kind: "roll" });
    assert.equal(p.phase, "move");
    // Il secondo non tira: dopo PARTY.rollMs tira il server
    run(p, 60_000, (q) => q.turnId === other && q.phase === "roll");
    run(p, PARTY.rollMs + 200, (q) => q.phase !== "roll");
    assert.notEqual(p.phase, "roll");
  });

  it("a voto: si vota tra PARTY.voteOptions minigiochi e vince il più votato", () => {
    const p = party([member("a"), member("b"), member("c", true)], { pick: "vote", seed: 3 });
    run(p, 200_000, (q) => q.phase === "vote", (q) => {
      if (q.turnId && q.phase === "roll") q.command(q.turnId, { kind: "roll" });
    });
    const snap = p.snapshot(0);
    assert.equal(snap.options.length, Math.min(PARTY.voteOptions, minigamesFor(3).length));
    const choice = snap.options[1].id;
    p.command("a", { kind: "vote", minigameId: choice });
    p.command("b", { kind: "vote", minigameId: choice });
    p.command("a", { kind: "vote", minigameId: "inesistente" });
    run(p, PARTY.voteMs, (q) => q.phase !== "vote");
    assert.equal(p.minigame?.id, choice);
  });

  it("il feedback si salva con stelle, testo e posto; chi salta non lascia niente", () => {
    const p = party([member("a"), member("b")], { seed: 5 });
    run(p, 200_000, (q) => q.minigameReady, (q) => {
      if (q.turnId && q.phase === "roll") q.command(q.turnId, { kind: "roll" });
    });
    p.minigameDone({ a: 2, b: 1 });
    p.command("a", { kind: "feedback", stars: 4, text: "  bello ma corto  " });
    p.command("a", { kind: "feedback", stars: 1, text: "doppio" }); // un parere solo a testa
    p.command("b", { kind: "feedback", stars: 0, text: "" });
    const fb = p.drainFeedback();
    assert.equal(fb.length, 1);
    assert.deepEqual({ ...fb[0] }, { minigameId: p.minigame!.id, id: "a", name: "A", characterId: "default", stars: 4, text: "bello ma corto", place: 2 });
    assert.equal(p.drainFeedback().length, 0);
    // Hanno risposto tutti: si riparte senza aspettare PARTY.feedbackMs
    run(p, 1500, (q) => q.phase !== "feedback");
    assert.notEqual(p.phase, "feedback");
  });

  it("la Corona si compra passandoci sopra con abbastanza banane e poi cambia casella", () => {
    const p = party([member("a", true), member("b", true)], { seed: 9 });
    let crowns = 0;
    for (let i = 0; i < 6 && crowns === 0; i++) {
      run(p, 300_000, (q) => q.minigameReady);
      p.minigameDone({ a: 1, b: 1 });
      crowns = p.standings().reduce((s, m) => s + m.crowns, 0);
    }
    assert.ok(crowns > 0, "in sei giri qualcuno compra la Corona");
  });

  it("chi esce mentre tocca a lui passa il turno al prossimo", () => {
    const p = party([member("a"), member("b"), member("c")], { seed: 2 });
    run(p, PARTY.introMs + 100, (q) => q.phase === "roll");
    const leaving = p.turnId!;
    p.removePlayer(leaving);
    assert.equal(p.phase, "roll");
    assert.notEqual(p.turnId, leaving);
    assert.equal(p.playerIds.length, 2);
  });
});
