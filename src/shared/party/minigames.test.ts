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
      // C'è un primo, oppure (nei minigiochi di squadra) un posto solo per tutti
      assert.ok(Object.values(places).some((p) => p === 1) || new Set(Object.values(places)).size === 1, id);
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

describe("Bonobo Party: i minigiochi della seconda tornata", () => {
  it("Il Bancomat Rotto: un colpo pesante davanti alla macchina fa uscire monete", () => {
    const { match } = minigameMatch("bancomat", 4, ["a"]);
    const a = match.players[0];
    // Si va davanti alla macchina, girati verso di lei, e si colpisce col pesante
    run(match, 6000, () => a.x > 560);
    for (let t = 0; t < 6000 && a.x < 560; t += DT) {
      match.setInput("a", { ...emptyInput(), right: true });
      match.step(DT);
    }
    match.setInput("a", emptyInput());
    run(match, 300, () => false);
    match.setInput("a", { ...emptyInput(), heavy: true });
    match.step(DT);
    match.setInput("a", emptyInput());
    run(match, 200, () => false);
    const props = snap(match).party?.props ?? [];
    assert.ok(props.filter((p) => p.kind === "coin").length >= MINIGAME.bancomat.coinsPerHit, "le monete escono");
  });

  it("Il Colosso: uno è gigante per tutto il minigioco, anche dopo un KO", () => {
    const { match, setup } = minigameMatch("colosso", 3);
    const giant = Object.keys(setup.roles ?? {})[0];
    assert.ok(giant, "c'è un Colosso");
    run(match, 3000, () => false);
    assert.equal(match.players.find((f) => f.id === giant)?.powerup, "colosso");
    assert.ok(match.players.filter((f) => f.id !== giant).every((f) => f.powerup !== "colosso"));
  });

  it("Acqua Alta: chi resta in basso affoga e finisce fuori", () => {
    const { match } = minigameMatch("acqua", 2);
    run(match, MINIGAME.acqua.durationMs + 2000);
    assert.ok(match.ended);
    assert.ok(Object.values(match.minigamePlaces!).includes(1));
  });

  it("Attraversa la Strada: arrivare sul marciapiede opposto vale un punto, l'autobus rimanda indietro", () => {
    const { match } = minigameMatch("strada", 6, ["a"]);
    let got = false;
    for (let t = 0; t < MINIGAME.strada.durationMs && !got; t += DT) {
      match.setInput("a", { ...emptyInput(), right: true, jump: Math.floor(t / 400) % 2 === 0 });
      match.step(DT);
      got = (snap(match).party?.scores.a ?? 0) > 0;
    }
    assert.ok(got, "prima o poi dall'altra parte");
  });
});

describe("Bonobo Party: classici e puzzle", () => {
  it("Il Filo: chi resta fermo sul filo di un altro finisce fuori", () => {
    const { match } = minigameMatch("filo", 2, ["a", "b"]);
    const [a, b] = match.players;
    // a corre verso b e oltre, lasciando il filo; b resta fermo dove a è passato
    for (let t = 0; t < 8000 && !b.eliminated; t += DT) {
      match.setInput("a", { ...emptyInput(), right: a.x < 1000, left: a.x >= 1000 });
      match.step(DT);
    }
    assert.ok(match.players.some((f) => f.eliminated), "qualcuno ha toccato il filo dell'altro");
  });

  it("Mattoni a Mazzate: ci sono i mattoni di ognuno e le palle", () => {
    const { match } = minigameMatch("mattoni", 2);
    run(match, 6000, () => false);
    const props = snap(match).party?.props ?? [];
    assert.equal(props.filter((p) => p.kind === "brick").length + Object.values(snap(match).party?.scores ?? {}).reduce((s, n) => s + n, 0), IDS.length * MINIGAME.mattoni.bricksEach);
    assert.equal(props.filter((p) => p.kind === "ball").length, MINIGAME.mattoni.balls);
  });

  it("Casse al Posto Giusto: due squadre e le casse in mezzo", () => {
    const { match, setup } = minigameMatch("casse", 2, ["a", "b", "c", "d"]);
    assert.equal(new Set(Object.values(setup.roles ?? {})).size, 2);
    run(match, 6000, () => false);
    assert.equal((snap(match).party?.props ?? []).filter((p) => p.kind === "crate").length, MINIGAME.casse.crates);
  });

  it("Il Muro: chi è a terra quando passa un muro col buco in alto vola via", () => {
    const { match } = minigameMatch("muro", 1, ["a"]);
    const a = match.players[0];
    let flew = false;
    for (let t = 0; t < MINIGAME.muro.durationMs && !flew; t += DT) {
      match.step(DT);
      flew = a.hitstunTimer > 0 || a.respawning;
    }
    // In mezzo minuto qualche muro col buco non in basso passa per forza
    assert.ok(flew || (snap(match).party?.scores.a ?? 0) > 0);
  });
});

describe("Bonobo Party: idee pazze", () => {
  it("Ieri Me: a ogni giro un fantasma in più a testa, che non entra in classifica", () => {
    const { match } = minigameMatch("ierime", 1, ["a", "b"]);
    run(match, MINIGAME.ierime.roundMs * 2 + 500, () => false);
    const ghosts = snap(match).players.filter((p) => p.ghostOf);
    assert.equal(ghosts.length, 4, "due giri finiti, due fantasmi a testa");
    assert.ok(ghosts.every((g) => g.ghostOf === "a" || g.ghostOf === "b"));
    run(match, 200_000);
    assert.deepEqual(Object.keys(match.minigamePlaces!).sort(), ["a", "b"]);
  });

  it("Un Solo Tasto: i tasti tolti non arrivano al lottatore", () => {
    const { match, setup } = minigameMatch("untasto", 1, ["a", "b"]);
    const role = setup.roles!.a;
    run(match, 100, () => false);
    match.setInput("a", { ...emptyInput(), jump: true, light: true, heavy: true, special: true, shield: true, left: true });
    const a = match.players.find((f) => f.id === "a")!;
    const pressed = (["jump", "light", "heavy", "special", "shield"] as const).filter((k) => a.input[k]);
    assert.equal(pressed.length, 1, role);
    assert.ok(a.input.left, "il movimento resta");
  });

  it("Lo Specchio: dopo il cambio i miei tasti guidano un altro", () => {
    const { match } = minigameMatch("specchio", 1, ["a", "b"]);
    run(match, MINIGAME.specchio.swapMs + 200, () => false);
    match.setInput("a", { ...emptyInput(), right: true });
    match.setInput("b", emptyInput());
    match.step(DT);
    const [a, b] = ["a", "b"].map((id) => match.players.find((f) => f.id === id)!);
    assert.ok(b.input.right && !a.input.right, "a guida b");
  });

  it("Il Bonobo a Quattro: un bonobo gigante e il Rivale; i tasti di ognuno muovono solo la sua parte", () => {
    const { match, setup } = minigameMatch("quattro", 1, ["a", "b"]);
    assert.equal(setup.roles!.a, "Sinistra + Salto");
    run(match, 200, () => false);
    const bonobo = match.players.find((f) => f.id === "bonobo-a-quattro")!;
    assert.ok(bonobo && match.players.some((f) => f.id === "rivale"));
    assert.equal(bonobo.powerup, "colosso");
    match.setInput("a", { ...emptyInput(), right: true, left: true });
    match.step(DT);
    assert.ok(bonobo.input.left && !bonobo.input.right, "a ha solo la sinistra");
    run(match, 200_000);
    const places = Object.values(match.minigamePlaces!);
    assert.ok(places.every((p) => p === places[0]), "si vince o si perde insieme");
  });
});

describe("Bonobo Party: ritmo e Burattinaio", () => {
  it("Il Burattinaio: col Leggero cade un mattone, e lui resta sulla passerella", () => {
    const { match, setup } = minigameMatch("burattinaio", 1, ["a", "b"]);
    const master = Object.keys(setup.roles!)[0];
    run(match, 300, () => false);
    const m = match.players.find((f) => f.id === master)!;
    assert.ok(m.y < 200, `in alto: ${m.y}`);
    match.setInput(master, { ...emptyInput(), light: true });
    match.step(DT);
    match.setInput(master, emptyInput());
    match.step(DT);
    assert.ok((snap(match).party?.props ?? []).some((p) => p.kind === "brick"), "il mattone cade");
    assert.ok(!m.attack, "il Leggero del Burattinaio non è una mossa");
  });

  it("Sala Prove: un colpo sul battito vale punti, fuori tempo no", async () => {
    const { offBeat } = await import("./minigames/salaprove");
    const beat = 60000 / MINIGAME.salaProve.bpm;
    assert.equal(offBeat(beat * 3), 0);
    assert.equal(offBeat(beat * 3 + 40), 40);
    assert.equal(offBeat(beat * 3 - 40), 40);
    assert.equal(Math.round(offBeat(beat * 3.5)), Math.round(beat / 2));
  });

  it("Gara di Provocazioni: le mosse vengono dagli eventi di sempre", async () => {
    const { moveOf } = await import("./minigames/provocazioni");
    assert.deepEqual(moveOf({ type: "jump", id: "a", x: 0, y: 0, air: false }), { id: "a", move: "salto" });
    assert.deepEqual(moveOf({ type: "attack", id: "a", kind: "heavyUp" }), { id: "a", move: "pesante" });
    assert.deepEqual(moveOf({ type: "attack", id: "a", kind: "lightAir" }), { id: "a", move: "leggero" });
    assert.deepEqual(moveOf({ type: "taunt", id: "a" }), { id: "a", move: "provocazione" });
    assert.equal(moveOf({ type: "attack", id: "a", kind: "grab" }), null);
    // Chi non preme niente non fa punti (e il minigioco finisce da solo)
    const { match } = minigameMatch("provocazioni", 3, ["a", "b"]);
    run(match, 200_000);
    assert.ok(Object.values(snap(match).party?.scores ?? {}).every((n) => n === 0), "senza tasti nessuno fa punti");
  });
});
