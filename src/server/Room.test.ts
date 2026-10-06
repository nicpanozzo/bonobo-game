// Una stanza rotta non ferma le altre (#105 passo 4): errori nel passo o nei ganci restano nella stanza
import assert from "node:assert/strict";
import { test } from "node:test";
import type { Server } from "socket.io";
import { ROOM_MAX_ERRORS } from "../shared/constants";
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
