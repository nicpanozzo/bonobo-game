import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { MINIGAME, TICK_RATE } from "../constants";
import { Match } from "../match";
import { emptyInput } from "../physics";
import type { GameEvent, GameSnapshot } from "../types";
import { placesFromScores } from "./minigame";
import { getMinigame, MINIGAMES, minigamesFor } from "./minigames";

const DT = 1000 / TICK_RATE;
const IDS = ["a", "b", "c"];

// Una partita-minigioco senza pre-partita: il minigioco parte al primo passo
function minigameMatch(id: string, seed = 1, ids = IDS) {
  const def = getMinigame(id)!;
  const setup = def.build(seed, ids);
  const match = new Match({ stage: setup.stage, rules: setup.rules, items: false, autoRestart: false, minigame: { id, runtime: setup.runtime, unlimitedStocks: setup.unlimitedStocks } });
  ids.forEach((pid) => match.addPlayer(pid, pid.toUpperCase(), "default"));
  return { match, setup };
}

function run(match: Match, ms: number, until: () => boolean = () => match.ended): GameEvent[] {
  const events: GameEvent[] = [];
  for (let t = 0; t < ms && !until(); t += DT) events.push(...match.step(DT));
  return events;
}

const snap = (match: Match): GameSnapshot => match.snapshot([], 0);

describe("Bonobo Party: i minigiochi", () => {
  it("ognuno ha id, titolo, categoria, come si gioca e tasti, e un'arena valida", () => {
    for (const def of Object.values(MINIGAMES)) {
      const { info } = def;
      assert.ok(info.id && info.title && info.howTo && info.keys, info.id);
      const setup = def.build(4, IDS);
      assert.ok(setup.stage.id.startsWith("party-"), info.id);
      assert.ok(setup.stage.spawns.length >= IDS.length, info.id);
    }
    assert.ok(minigamesFor(1).length < minigamesFor(4).length, "da soli niente 1 contro tutti");
  });

  it("finiscono tutti da soli, entro la loro durata, con un posto per ognuno e l'HUD nello snapshot", () => {
    for (const id of Object.keys(MINIGAMES)) {
      const { match } = minigameMatch(id);
      assert.equal(snap(match).party?.id, id);
      const events = run(match, 200_000);
      assert.ok(match.ended, `${id} finisce`);
      const places = match.minigamePlaces!;
      assert.deepEqual(Object.keys(places).sort(), [...IDS].sort(), id);
      assert.ok(Object.values(places).some((p) => p === 1), id);
      const end = events.find((e) => e.type === "matchEnd");
      assert.ok(end, `${id}: matchEnd`);
      assert.deepEqual(snap(match).party?.places, places);
    }
  });

  it("sono deterministici: stesso seme, stessi posti e stessi punti", () => {
    for (const id of Object.keys(MINIGAMES)) {
      const results = [1, 2].map(() => {
        const { match } = minigameMatch(id, 9);
        run(match, 200_000);
        return { places: match.minigamePlaces, scores: snap(match).party?.scores };
      });
      assert.deepEqual(results[0], results[1], id);
    }
  });

  it("posti dai punti: a pari punti stesso posto, poi si salta", () => {
    assert.deepEqual(placesFromScores(["a", "b", "c", "d"], { a: 5, b: 9, c: 5, d: 1 }), { b: 1, a: 2, c: 2, d: 4 });
    assert.deepEqual(placesFromScores(["a", "b"], { a: 3, b: 1 }, true), { b: 1, a: 2 });
  });

  it("Pioggia di Banane: chi sta fermo sotto la pioggia raccoglie qualcosa", () => {
    const { match } = minigameMatch("pioggia", 3, ["a"]);
    // Da solo e fermo: le banane che gli cadono addosso o accanto le prende camminando avanti e indietro
    const a = match.players[0];
    for (let t = 0; t < MINIGAME.pioggia.durationMs; t += DT) {
      match.setInput("a", { ...emptyInput(), left: Math.floor(t / 1500) % 2 === 0, right: Math.floor(t / 1500) % 2 === 1 });
      match.step(DT);
    }
    assert.ok((snap(match).party?.scores.a ?? 0) > 0, "qualche banana presa");
    assert.ok(a.x > 0);
    const props = snap(match).party?.props ?? [];
    assert.ok(props.every((p) => p.kind === "banana"));
  });

  it("Mezzogiorno di Fuoco: chi spara prima del VIA è fuori, il primo dopo il VIA fa il punto", () => {
    const { match } = minigameMatch("mezzogiorno", 5, ["a", "b"]);
    run(match, 200, () => false);
    // a spara subito (prima del VIA)
    match.setInput("a", { ...emptyInput(), light: true });
    match.step(DT);
    match.setInput("a", emptyInput());
    run(match, 200, () => false);
    assert.ok(snap(match).party?.out.includes("a"), "a è fuori dal round");
    // b aspetta il VIA e spara
    run(match, MINIGAME.mezzogiorno.readyMs + MINIGAME.mezzogiorno.waitMaxMs, () => snap(match).party?.text === "VAI!");
    assert.equal(snap(match).party?.text, "VAI!");
    match.setInput("b", { ...emptyInput(), light: true });
    run(match, 300, () => (snap(match).party?.scores.b ?? 0) > 0);
    assert.equal(snap(match).party?.scores.b, 1);
    assert.equal(snap(match).party?.scores.a, 0);
  });

  it("Le Torri Crollano: senza muoversi si cade tutti e il minigioco finisce", () => {
    const { match } = minigameMatch("crollo", 2);
    run(match, MINIGAME.crollo.durationMs + 1000);
    assert.ok(match.ended);
    const places = match.minigamePlaces!;
    // Chi è caduto per ultimo (o è rimasto) è davanti a chi è caduto prima
    assert.ok(Object.values(places).includes(1));
  });
});
