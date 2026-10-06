// Prove del gioco su un server vero (E4 passo 2): porta casuale e client socket.io-client
import assert from "node:assert/strict";
import { createServer } from "node:http";
import type { AddressInfo } from "node:net";
import { after, before, test } from "node:test";
import { Server } from "socket.io";
import { io as connect, type Socket } from "socket.io-client";
import { MAX_PLAYERS_PER_ROOM, NET_LIMITS } from "../shared/constants";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { attachGame } from "./game";
import type { Room } from "./Room";

type Client = Socket<ServerToClient, ClientToServer>;

let io: Server<ClientToServer, ServerToClient>;
let rooms: Map<string, Room>;
let url = "";
const clients: Client[] = [];
// Un messaggio che non arriva fa fallire la prova invece di bloccare npm test
const LIMIT = { timeout: 5000 };

before(async () => {
  const http = createServer();
  io = new Server<ClientToServer, ServerToClient>(http, { maxHttpBufferSize: NET_LIMITS.maxMessageBytes });
  rooms = attachGame(io);
  await new Promise<void>((resolve) => http.listen(0, "127.0.0.1", resolve));
  url = `http://127.0.0.1:${(http.address() as AddressInfo).port}`;
});

after(async () => {
  for (const c of clients) c.disconnect();
  for (const r of rooms.values()) r.destroy();
  await io.close();
});

async function client(): Promise<Client> {
  const c: Client = connect(url, { transports: ["websocket"], reconnection: false, forceNew: true });
  clients.push(c);
  await new Promise<void>((resolve, reject) => {
    c.once("connect", resolve);
    c.once("connect_error", reject);
  });
  return c;
}

function join(c: Client, room: string, name = "Prova") {
  return new Promise<"welcome" | "roomFull">((resolve) => {
    c.once("welcome", () => resolve("welcome"));
    c.once("roomFull", () => resolve("roomFull"));
    c.emit("join", { room, name });
  });
}

// L'uscita di un client arriva al server un attimo dopo: si aspetta che lo stato cambi
async function until(done: () => boolean, ms = 2000) {
  const end = Date.now() + ms;
  while (!done()) {
    assert.ok(Date.now() < end, "il server non ha aggiornato lo stato in tempo");
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

// Un giro completo client → server → client: se risponde, il server è vivo e ha letto i messaggi prima
async function roundTrip(room: string) {
  const probe = await client();
  assert.equal(await join(probe, room), "welcome");
  probe.disconnect();
}

test("join: welcome con id, stanza e arena", LIMIT, async () => {
  const c = await client();
  const welcome = new Promise<Parameters<ServerToClient["welcome"]>[0]>((resolve) => c.once("welcome", resolve));
  c.emit("join", { room: "Prova Uno!", name: "Ada" });
  const w = await welcome;
  assert.equal(w.id, c.id);
  assert.equal(w.room, "provauno");
  assert.ok(w.stage);
  assert.ok(rooms.get("provauno")?.match.players.some((p) => p.id === c.id));
  c.disconnect();
});

test("messaggi malformati: il server li ignora e resta acceso", LIMIT, async () => {
  const c = await client();
  const bad = c as unknown as { emit: (event: string, ...args: unknown[]) => void };
  for (const raw of [null, 42, "stanza", [1, 2], undefined]) bad.emit("join", raw);
  bad.emit("input", null);
  bad.emit("rematch", null);
  bad.emit("evento-che-non-esiste", 1);
  await roundTrip("malformati");
  // Dopo un join vero, input sbagliati non toccano il lottatore
  assert.equal(await join(c, "malformati"), "welcome");
  for (const raw of [null, 7, "su", [true], { left: "sì", up: 1 }]) bad.emit("input", raw);
  await roundTrip("malformati");
  assert.ok(c.connected);
  c.disconnect();
});

test("join con campi sbagliati: si entra con valori ripuliti", LIMIT, async () => {
  const c = await client();
  const welcome = new Promise<Parameters<ServerToClient["welcome"]>[0]>((resolve) => c.once("welcome", resolve));
  (c as unknown as { emit: (event: string, raw: unknown) => void }).emit("join", {
    room: { x: 1 },
    name: "x".repeat(10_000),
    rules: JSON.parse('{"__proto__": {"inquinato": true}, "stocks": "tante"}'),
    extra: [1, 2, 3],
  });
  const w = await welcome;
  assert.equal(w.room, "lobby");
  assert.equal(({} as Record<string, unknown>).inquinato, undefined);
  assert.ok((rooms.get("lobby")?.match.players.find((p) => p.id === c.id)?.name.length ?? 99) <= 16);
  c.disconnect();
});

test("messaggio oltre maxHttpBufferSize: il server chiude quel socket", LIMIT, async () => {
  const c = await client();
  const closed = new Promise<void>((resolve) => c.once("disconnect", () => resolve()));
  c.emit("join", { room: "grosso", name: "x".repeat(NET_LIMITS.maxMessageBytes * 2) });
  await closed;
  await roundTrip("grosso");
});

test("stanza piena: chi arriva in più riceve roomFull", LIMIT, async () => {
  const inside: Client[] = [];
  for (let i = 0; i < MAX_PLAYERS_PER_ROOM; i++) {
    const c = await client();
    assert.equal(await join(c, "piena", `G${i}`), "welcome");
    inside.push(c);
  }
  const extra = await client();
  assert.equal(await join(extra, "piena"), "roomFull");
  assert.equal(rooms.get("piena")?.match.players.length, MAX_PLAYERS_PER_ROOM);
  for (const c of [...inside, extra]) c.disconnect();
});

test("l'ultimo che esce chiude la stanza", LIMIT, async () => {
  const a = await client();
  const b = await client();
  await join(a, "vuota");
  await join(b, "vuota");
  a.disconnect();
  await until(() => rooms.get("vuota")?.match.players.length === 1);
  assert.ok(rooms.has("vuota"));
  b.disconnect();
  await until(() => !rooms.has("vuota"));
});
