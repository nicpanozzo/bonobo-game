// Prove del gioco su un server vero (E4 passo 2): porta casuale e client socket.io-client
import assert from "node:assert/strict";
import { createServer } from "node:http";
import type { AddressInfo } from "node:net";
import { after, before, test } from "node:test";
import { Server } from "socket.io";
import { io as connect, type Socket } from "socket.io-client";
import { MAX_PLAYERS_PER_ROOM, NET_LIMITS, PROTOCOL_VERSION } from "../shared/constants";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { attachGame, type GameDeps } from "./game";
import type { Room } from "./Room";
import { SERVER_VERSION } from "./version";

type Client = Socket<ServerToClient, ClientToServer>;

interface TestServer {
  io: Server<ClientToServer, ServerToClient>;
  rooms: Map<string, Room>;
  url: string;
}

const servers: TestServer[] = [];
const clients: Client[] = [];
// Un messaggio che non arriva fa fallire la prova invece di bloccare npm test
const LIMIT = { timeout: 5000 };

async function startServer(deps: GameDeps = {}): Promise<TestServer> {
  const http = createServer();
  const io = new Server<ClientToServer, ServerToClient>(http, { maxHttpBufferSize: NET_LIMITS.maxMessageBytes });
  const rooms = attachGame(io, deps);
  await new Promise<void>((resolve) => http.listen(0, "127.0.0.1", resolve));
  const server = { io, rooms, url: `http://127.0.0.1:${(http.address() as AddressInfo).port}` };
  servers.push(server);
  return server;
}

// Il server delle prove generali: tutti i client arrivano da 127.0.0.1, quindi niente limiti per IP
let rooms: Map<string, Room>;
let url = "";
before(async () => {
  ({ rooms, url } = await startServer({ limits: { maxConnectionsPerIp: 1000, newRoomsPerIpPerMinute: 1000 } }));
});

after(async () => {
  for (const c of clients) c.disconnect();
  for (const s of servers) {
    for (const r of s.rooms.values()) r.destroy();
    await s.io.close();
  }
});

async function client(to = url): Promise<Client> {
  const c: Client = connect(to, { transports: ["websocket"], reconnection: false, forceNew: true });
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

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// L'uscita di un client arriva al server un attimo dopo: si aspetta che lo stato cambi
async function until(done: () => boolean, ms = 2000) {
  const end = Date.now() + ms;
  while (!done()) {
    assert.ok(Date.now() < end, "il server non ha aggiornato lo stato in tempo");
    await sleep(10);
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
  assert.equal(typeof w.token, "string");
  assert.equal(w.resumed, false);
  const snap = await new Promise<Parameters<ServerToClient["snapshot"]>[0]>((resolve) => c.once("snapshot", resolve));
  assert.equal(snap.players.find((p) => p.id === c.id)?.away, false);
  assert.ok(!JSON.stringify(snap).includes(w.token), "il token non finisce mai negli snapshot");
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

test("versione nel join: protocollo uguale entra e sa la versione del server, protocollo diverso è rifiutato", LIMIT, async () => {
  const ok = await client();
  const welcome = new Promise<string>((resolve) => ok.once("welcome", (d) => resolve(d.serverVersion)));
  ok.emit("join", { room: "versioni", name: "Nuovo", version: "0.0.1", protocol: PROTOCOL_VERSION });
  assert.equal(await welcome, SERVER_VERSION);
  const old = await client();
  const refused = new Promise<string>((resolve) => old.once("refused", (r) => resolve(r.reason)));
  old.emit("join", { room: "versioni", name: "Vecchio", protocol: PROTOCOL_VERSION + 1 });
  assert.equal(await refused, "outdated");
  await roundTrip("versioni-dopo");
  assert.equal(rooms.get("versioni")?.match.players.length, 1);
  for (const c of [ok, old]) c.disconnect();
});

test("stanza piena: arriva anche il rifiuto con motivo", LIMIT, async () => {
  const inside: Client[] = [];
  for (let i = 0; i < MAX_PLAYERS_PER_ROOM; i++) {
    const c = await client();
    assert.equal(await join(c, "piena2", `G${i}`), "welcome");
    inside.push(c);
  }
  const extra = await client();
  const refused = new Promise<string>((resolve) => extra.once("refused", (r) => resolve(r.reason)));
  extra.emit("join", { room: "piena2", name: "Extra" });
  assert.equal(await refused, "full");
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

test("limite per IP: la nona connessione dallo stesso indirizzo viene chiusa", LIMIT, async () => {
  const server = await startServer();
  const first: Client[] = [];
  for (let i = 0; i < NET_LIMITS.maxConnectionsPerIp; i++) first.push(await client(server.url));
  const ninth = await client(server.url);
  await until(() => !ninth.connected);
  assert.ok(first.every((c) => c.connected));
  // Quando uno esce si libera il posto
  // (il server non dice quando ha contato l'uscita: si aspetta un attimo)
  first[0].disconnect();
  await sleep(50);
  const again = await client(server.url);
  await sleep(50);
  assert.ok(again.connected);
  for (const c of [...first, again]) c.disconnect();
});

test("nome con caratteri RTL, emoji e 40 caratteri esce pulito e lungo 16", LIMIT, async () => {
  const c = await client();
  const rtl = String.fromCodePoint(0x202e);
  const zeroWidth = String.fromCodePoint(0x200b);
  assert.equal(await join(c, "nomi", `${rtl}Bo${zeroWidth}nobo 🐒🐒   ${"x".repeat(40)}`), "welcome");
  const name = rooms.get("nomi")?.match.players.find((p) => p.id === c.id)?.name;
  assert.equal(name, "Bonobo 🐒🐒 xxxxxx");
  assert.equal([...new Intl.Segmenter().segment(name ?? "")].length, 16);
  // Lo stesso nome nella stessa stanza diventa "Nome 2"
  const twin = await client();
  assert.equal(await join(twin, "nomi", "bonobo 🐒🐒 xxxxxx"), "welcome");
  assert.equal(rooms.get("nomi")?.match.players.find((p) => p.id === twin.id)?.name, "bonobo 🐒🐒 xxxx 2");
  c.disconnect();
  twin.disconnect();
});

test("stanze: oltre il limite di stanze nuove per IP il socket si chiude", LIMIT, async () => {
  const server = await startServer({ limits: { newRoomsPerIpPerMinute: 2 } });
  const a = await client(server.url);
  const b = await client(server.url);
  const c = await client(server.url);
  assert.equal(await join(a, "uno"), "welcome");
  assert.equal(await join(b, "due"), "welcome");
  c.emit("join", { room: "tre", name: "C" });
  await until(() => !c.connected);
  assert.equal(server.rooms.has("tre"), false);
  // In una stanza che esiste già si entra ancora
  const d = await client(server.url);
  assert.equal(await join(d, "uno"), "welcome");
  for (const x of [a, b, d]) x.disconnect();
});

test("stanza senza tasti per troppo tempo: si chiude e scollega chi è dentro", LIMIT, async () => {
  const server = await startServer({ roomIdleMs: 100 });
  const c = await client(server.url);
  assert.equal(await join(c, "ferma"), "welcome");
  await until(() => !c.connected);
  assert.equal(server.rooms.has("ferma"), false);
});

test("caduta di rete: il lottatore resta fermo nel posto tenuto, poi esce (#107)", LIMIT, async () => {
  const server = await startServer({ reconnectHoldMs: 300 });
  const a = await client(server.url);
  const b = await client(server.url);
  assert.equal(await join(a, "caduta", "A"), "welcome");
  assert.equal(await join(b, "caduta", "B"), "welcome");
  const room = server.rooms.get("caduta")!;
  const lost = a.id!;
  const away = new Promise<void>((resolve) =>
    b.on("snapshot", (s) => {
      if (s.events.some((e) => e.type === "away" && e.id === lost)) resolve();
    }),
  );
  a.io.engine.close(); // la rete cade: niente uscita dal namespace
  await away;
  assert.equal(room.match.players.find((p) => p.id === lost)?.away, true);
  await until(() => !room.match.players.some((p) => p.id === lost));
  assert.ok(server.rooms.has("caduta"), "chi resta continua a giocare");
  // Se cade anche l'ultimo, la stanza aspetta il suo posto e poi si chiude
  b.io.engine.close();
  await sleep(50);
  assert.ok(server.rooms.has("caduta"));
  await until(() => !server.rooms.has("caduta"));
});

type Welcome = Parameters<ServerToClient["welcome"]>[0];
function joinWith(c: Client, data: Parameters<ClientToServer["join"]>[0]) {
  return new Promise<Welcome>((resolve) => {
    c.once("welcome", resolve);
    c.emit("join", data);
  });
}

test("rientro con il token: stesso lottatore, stesse vite e percentuale (#107)", LIMIT, async () => {
  const server = await startServer({ reconnectHoldMs: 400 });
  const a = await client(server.url);
  const b = await client(server.url);
  const first = await joinWith(a, { room: "rientro", name: "A" });
  await joinWith(b, { room: "rientro", name: "B" });
  const room = server.rooms.get("rientro")!;
  const fighter = room.match.players.find((p) => p.id === first.id)!;
  fighter.percent = 42;
  fighter.stocks = 2;

  a.io.engine.close();
  await until(() => fighter.away);
  const a2 = await client(server.url);
  const back = await joinWith(a2, { room: "rientro", name: "A", token: first.token });
  assert.deepEqual([back.id, back.resumed, back.token], [first.id, true, first.token]);
  assert.equal(room.match.players.length, 2, "bot, Discord e classifica vedono sempre due giocatori");
  assert.deepEqual([fighter.away, fighter.percent, fighter.stocks], [false, 42, 2]);

  // Il client si accorge della caduta prima del server: il socket nuovo vince, quello vecchio si chiude
  const a3 = await client(server.url);
  const stale = new Promise<void>((resolve) => a2.once("disconnect", () => resolve()));
  assert.equal((await joinWith(a3, { room: "rientro", name: "A", token: first.token })).resumed, true);
  await stale;
  await sleep(50);
  assert.equal(fighter.away, false, "l'uscita del vecchio socket non tocca il posto");
  assert.equal(room.match.players.length, 2);

  // I tasti del socket nuovo muovono lo stesso lottatore
  a3.emit("input", { left: false, right: true, up: false, down: false, light: false, heavy: false, taunt: false, dodge: false, shield: false, special: false });
  await until(() => fighter.input.right);

  // Posto scaduto: il token non vale più e si rientra da capo
  a3.io.engine.close();
  await until(() => !room.match.players.some((p) => p.id === first.id));
  const a4 = await client(server.url);
  const fresh = await joinWith(a4, { room: "rientro", name: "A", token: first.token });
  assert.equal(fresh.resumed, false);
  assert.notEqual(fresh.id, first.id);
  for (const c of [b, a4]) c.disconnect();
});

// Allenamento (#113): i comandi valgono solo in palestra e da soli
test("allenamento: percentuale al bot da soli, comandi ignorati con due umani o fuori dalla palestra", LIMIT, async () => {
  const a = await client();
  const me = (await joinWith(a, { room: "palestra", name: "A", rules: { mode: "training" }, bot: "manichino" })).id;
  const bot = () => rooms.get("palestra")!.match.players.find((f) => f.id !== me);
  a.emit("training", { percent: 100 });
  await until(() => bot()?.percent === 100);
  const snap = await new Promise<number | undefined>((resolve) => a.once("snapshot", (s) => resolve(s.players.find((p) => p.id !== me)?.percent)));
  assert.equal(snap, 100);
  assert.equal(rooms.get("palestra")!.match.players.find((f) => f.id === me)?.percent, 0, "la propria percentuale non cambia");

  const b = await client();
  await joinWith(b, { room: "palestra", name: "B" });
  a.emit("training", { percent: 0, reset: true });
  await roundTrip("palestra");
  assert.equal(bot()?.percent, 100, "con due umani il comando non vale");
  b.disconnect();
  a.disconnect();

  const c = await client();
  await joinWith(c, { room: "non-palestra", name: "C", bot: "manichino" });
  c.emit("training", { percent: 100 });
  await roundTrip("non-palestra");
  assert.ok(rooms.get("non-palestra")!.match.players.every((f) => f.percent === 0), "fuori dall'allenamento il comando non vale");
  c.disconnect();
});

