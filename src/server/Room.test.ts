// Una stanza rotta non ferma le altre (#105 passo 4): errori nel passo o nei ganci restano nella stanza
import assert from "node:assert/strict";
import { test } from "node:test";
import type { Server } from "socket.io";
import { HALL, MATCH_RESTART_MS, PREMATCH, ROOM_MAX_ERRORS, TICK_RATE } from "../shared/constants";
import type { Match } from "../shared/match";
import { emptyInput } from "../shared/physics";
import type { ClientToServer, GameSnapshot, HallSnapshot, HallZone, ServerToClient } from "../shared/types";
import { Room, type RoomHooks, type RoomOptions } from "./Room";

// Finto io: conta gli snapshot mandati e le stanze scollegate
function fakeIo() {
  const sent = new Map<string, number>();
  const kicked: string[] = [];
  const io = {
    to: (code: string) => ({ emit: () => sent.set(code, (sent.get(code) ?? 0) + 1) }),
    in: (code: string) => ({ disconnectSockets: () => kicked.push(code) }),
  } as unknown as Server<ClientToServer, ServerToClient>;
  return { io, sent, kicked };
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

test("un gancio che lancia errori chiude la sua stanza al terzo errore, le altre continuano", async () => {
  const { io, sent, kicked } = fakeIo();
  let calls = 0;
  let closed = false;
  const broken = new Room("rotta", io, {}, {
    onTick: () => {
      calls++;
      throw new Error("gancio rotto");
    },
  });
  broken.onClose = () => (closed = true);
  const healthy = new Room("sana", io);
  const quiet = console.error;
  console.error = () => {}; // gli errori voluti non sporcano l'uscita dei test
  try {
    await sleep(300);
  } finally {
    console.error = quiet;
    broken.destroy();
    healthy.destroy();
  }
  assert.equal(calls, ROOM_MAX_ERRORS);
  assert.ok(closed);
  assert.deepEqual(kicked, ["rotta"]);
  assert.ok((sent.get("sana") ?? 0) > 3, "la stanza sana manda ancora snapshot");
});

test("un errore isolato non chiude la stanza", async () => {
  const { io, sent, kicked } = fakeIo();
  let calls = 0;
  const room = new Room("inciampo", io, {}, {
    onTick: () => {
      if (++calls % ROOM_MAX_ERRORS === 0) throw new Error("ogni tanto");
    },
  });
  const quiet = console.error;
  console.error = () => {};
  try {
    await sleep(300);
  } finally {
    console.error = quiet;
    room.destroy();
  }
  assert.deepEqual(kicked, []);
  assert.ok((sent.get("inciampo") ?? 0) > 3);
});

// Orologio della stanza (#113): il rallentatore fa meno passi fissi al secondo

function ticksIn(ms: number, speed: number): number {
  let ticks = 0;
  const room = new Room("orologio", fakeIo().io, { rules: { mode: "training" } }, { onTick: () => ticks++ });
  room.destroy(); // niente timer veri: l'orologio lo muove la prova
  room.setSpeed(speed);
  for (let t = 0; t < ms; t += 10) room.advance(10);
  room.advance(0.5); // le somme di 16,67 ms perdono qualche decimale: mezzo ms in più per arrivare al passo esatto
  return ticks;
}

test("a velocità 1 si fanno TICK_RATE passi al secondo", () => {
  assert.equal(ticksIn(1000, 1), TICK_RATE);
});

test("a velocità 0.5 servono 2 s per 60 passi, a 0.25 ne servono 4", () => {
  assert.equal(ticksIn(2000, 0.5), 60);
  assert.equal(ticksIn(4000, 0.25), 60);
});

// Ora degli snapshot (#320): due passi fatti nello stesso giro (orologio che sbanda) non hanno la stessa ora,
// se no il client li scarta come doppi o calcola velocità assurde e il movimento va a scatti
test("due passi nello stesso giro mandano snapshot a un passo di distanza", () => {
  const times: number[] = [];
  const io = {
    to: () => ({ emit: (_name: string, snap: { t: number }) => times.push(snap.t) }),
    in: () => ({ disconnectSockets: () => {} }),
  } as unknown as Server<ClientToServer, ServerToClient>;
  const room = new Room("scatti", io);
  room.destroy(); // niente timer veri: l'orologio lo muove la prova
  room.advance(1000 / TICK_RATE);
  room.advance((2 * 1000) / TICK_RATE + 0.5); // due passi maturati insieme
  assert.equal(times.length, 3);
  assert.ok(Math.abs(times[1] - times[0] - 1000 / TICK_RATE) < 0.01);
  assert.ok(Math.abs(times[2] - times[1] - 1000 / TICK_RATE) < 0.01);
});

// Sala d'attesa 3D: la stanza passa dalla sala alla partita e ritorno

const TICK = 1000 / TICK_RATE;

// Finto io che tiene i messaggi mandati, per nome
function recordingIo() {
  const sent: { event: string; data: unknown }[] = [];
  const io = {
    to: () => ({ emit: (event: string, data: unknown) => sent.push({ event, data }) }),
    in: () => ({ disconnectSockets: () => {} }),
  } as unknown as Server<ClientToServer, ServerToClient>;
  return { io, sent, names: () => sent.map((s) => s.event) };
}

function hallRoom(hooks: RoomHooks = {}, options: RoomOptions = {}) {
  const rec = recordingIo();
  const room = new Room("sala", rec.io, { prematch: true, hall: true, ...options }, hooks);
  room.destroy(); // niente timer veri: l'orologio lo muove la prova
  return { room, ...rec };
}

function play(room: Room, ms: number) {
  for (let t = 0; t < ms; t += TICK) room.advance(TICK);
  room.advance(0.5);
}

// Cammina come un giocatore, tenendo le frecce verso la zona, finché ci si ferma dentro
function walkInto(room: Room, id: string, kind: HallZone["kind"], zoneId?: string) {
  const hall = room.hall!;
  const z = hall.zones.find((q) => q.kind === kind && (zoneId === undefined || q.id === zoneId))!;
  for (let i = 0; i < 600; i++) {
    const p = hall.roster().find((q) => q.id === id)!;
    const dx = z.x - p.x;
    const dz = z.z - p.z;
    if (Math.hypot(dx, dz) < 25 && p.onGround) break;
    room.setInput(id, { ...emptyInput(), right: dx > 15, left: dx < -15, down: dz > 15, up: dz < -15 });
    room.advance(TICK);
  }
  room.setInput(id, emptyInput());
  play(room, 400);
}

test("sala: solo messaggi hall, uno ogni HALL.sendEveryTicks passi, con zone e giocatori", () => {
  const { room, sent, names } = hallRoom();
  room.addPlayer("a", "Marta");
  assert.equal(room.phase, "hall");
  play(room, 1000);
  assert.ok(!names().includes("snapshot"));
  const halls = sent.filter((s) => s.event === "hall");
  assert.equal(halls.length, Math.floor(TICK_RATE / HALL.sendEveryTicks));
  const snap = halls[0].data as HallSnapshot;
  assert.equal(snap.players[0].name, "Marta");
  assert.ok(snap.zones.length > 0);
  assert.ok(snap.events.some((e) => e.type === "join" && e.id === "a"));
});

test("sala: la stanza in allenamento o senza hall resta come prima", () => {
  for (const options of [{ rules: { mode: "training" as const }, hall: true }, {}]) {
    const rec = recordingIo();
    const room = new Room("vecchia", rec.io, { prematch: true, ...options });
    room.destroy();
    room.addPlayer("a", "A");
    play(room, 200);
    assert.equal(room.hall, null);
    assert.equal(room.phase, "match");
    assert.ok(rec.names().includes("snapshot"));
    assert.ok(!rec.names().includes("hall"));
  }
});

test("sala → partita: voti, cerchio, stage e poi snapshot con modalità, arena e lottatori scelti", () => {
  const built: { match: Match; bots: string[] }[] = [];
  const { room, sent, names } = hallRoom({ onMatchBuilt: (_r, match, bots) => built.push({ match, bots }) }, { rules: { stocks: 2 } });
  room.addPlayer("a", "Marta", "default");
  room.addPlayer("b", "Luca", "elvedeo");
  const botId = room.hall!.addBot("orsoblu")!;
  walkInto(room, "a", "mode", "teams");
  walkInto(room, "a", "stage", "isole");
  walkInto(room, "b", "fighter", "lampione");
  walkInto(room, "a", "ready");
  walkInto(room, "b", "ready");
  play(room, HALL.countdownMs + 200);
  assert.equal(room.phase, "match");
  const stageAt = names().indexOf("stage");
  assert.ok(stageAt > 0);
  assert.ok(!names().slice(0, stageAt).includes("snapshot"), "lo stage arriva prima degli snapshot");
  assert.ok(names().slice(stageAt).includes("snapshot"));
  const lastHall = sent.slice(0, stageAt).filter((s) => s.event === "hall").pop()!.data as HallSnapshot;
  assert.ok(lastHall.events.some((e) => e.type === "go"), "l'ultimo messaggio della sala ha il via");
  const stage = sent[stageAt].data as { stageId: string; rules: { mode: string; stocks: number } };
  assert.equal(stage.stageId, "isole");
  assert.equal(stage.rules.mode, "teams");
  assert.equal(stage.rules.stocks, 2, "le altre regole sono quelle del creatore");
  assert.equal(room.match.players.length, 3);
  assert.equal(room.match.players.find((p) => p.id === "b")?.characterId, "lampione");
  assert.ok(room.match.players.every((p) => p.team > 0), "squadre assegnate da sole");
  assert.deepEqual(built.map((b) => b.bots), [[botId]]);
  assert.equal(built[0].match, room.match);
  // Tutti pronti: presentazione e 3, 2, 1 senza aspettare
  const snap = sent.filter((s) => s.event === "snapshot").pop()!.data as GameSnapshot;
  assert.equal(snap.prematch?.phase, "starting");
});

function toMatch(room: Room) {
  room.addPlayer("a", "Marta");
  room.addPlayer("b", "Luca");
  walkInto(room, "a", "ready");
  walkInto(room, "b", "ready");
  play(room, HALL.countdownMs + 200);
  assert.equal(room.phase, "match");
  play(room, PREMATCH.introMs + PREMATCH.countdownMs + 200);
  assert.ok(room.match.started);
}

function endMatch(room: Room) {
  const loser = room.match.players.find((p) => p.id === "b")!;
  loser.eliminated = true;
  play(room, 100);
  assert.ok(room.match.ended);
}

test("partita finita: niente rivincita da sola; dopo HALL.returnAfterMs tutti nella sala, voti da capo", () => {
  const { room, sent } = hallRoom();
  toMatch(room);
  endMatch(room);
  play(room, MATCH_RESTART_MS + 500);
  assert.ok(room.match.ended, "non ricomincia da sola");
  assert.equal(room.phase, "match");
  play(room, HALL.returnAfterMs);
  assert.equal(room.phase, "hall");
  const snap = sent.filter((s) => s.event === "hall").pop()!.data as HallSnapshot;
  assert.equal(snap.players.length, 2);
  assert.ok(snap.players.every((p) => !p.ready && p.modeVote === null));
});

test("partita finita: hall riporta subito nella sala, rematch ricomincia; a partita in corso hall non vale", () => {
  const { room, names } = hallRoom();
  toMatch(room);
  room.requestHall();
  assert.equal(room.phase, "match", "a partita in corso non si torna nella sala");
  endMatch(room);
  room.requestRematch();
  assert.ok(!room.match.ended);
  play(room, PREMATCH.countdownMs + 200);
  endMatch(room);
  const before = names().length;
  room.requestHall();
  assert.equal(room.phase, "hall");
  assert.equal(names()[before], "hall");
  // Di nuovo nel cerchio: si riparte con una Match nuova
  const old = room.match;
  walkInto(room, "a", "ready");
  walkInto(room, "b", "ready");
  play(room, HALL.countdownMs + 200);
  assert.equal(room.phase, "match");
  assert.notEqual(room.match, old);
});

test("chi entra a partita in corso gioca subito ed è nella sala dopo; chi esce sparisce da tutte e due", () => {
  const { room } = hallRoom();
  toMatch(room);
  room.addPlayer("c", "Sara");
  assert.ok(room.match.players.some((p) => p.id === "c"));
  assert.ok(room.hall!.has("c"));
  assert.deepEqual(room.playerNames, ["Marta", "Luca", "Sara"]);
  room.removePlayer("a");
  assert.ok(!room.match.players.some((p) => p.id === "a"));
  assert.ok(!room.hall!.has("a"));
  assert.equal(room.hall!.hostId, "b", "il padrone di casa passa al prossimo");
});

test("sala: caduta di rete e rientro anche nella sala", () => {
  const { room } = hallRoom();
  room.addPlayer("a", "Marta");
  room.addPlayer("b", "Luca");
  room.holdPlayer("a");
  assert.equal(room.hall!.roster().find((p) => p.id === "a")?.away, true);
  room.resumePlayer("a");
  assert.equal(room.hall!.roster().find((p) => p.id === "a")?.away, false);
});

test("sala: il tabellone si legge dal provider, non a ogni messaggio", () => {
  let reads = 0;
  const row = { name: "X", rating: 1100, tier: "Orango", wins: 3, matches: 4, streak: 1 };
  const { room, sent } = hallRoom({}, { board: () => (reads++, [row]) });
  room.addPlayer("a", "Marta");
  play(room, 2000);
  assert.equal(reads, 1);
  assert.deepEqual((sent.filter((s) => s.event === "hall").pop()!.data as HallSnapshot).board, [row]);
});
