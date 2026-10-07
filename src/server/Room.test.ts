// Una stanza rotta non ferma le altre (#105 passo 4): errori nel passo o nei ganci restano nella stanza
import assert from "node:assert/strict";
import { test } from "node:test";
import type { Server } from "socket.io";
import { ROOM_MAX_ERRORS, TICK_RATE } from "../shared/constants";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { Room } from "./Room";

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
