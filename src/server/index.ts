import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import { Server } from "socket.io";
import { NET_LIMITS } from "../shared/constants";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { Bots, parseBotKind } from "./bot";
import { discordHooks } from "./discord";
import { health } from "./health";
import { Leaderboard, leaderboardPage } from "./leaderboard";
import { Flood, TokenBucket } from "./rateLimit";
import { combineHooks, Room } from "./Room";
import { parseInput, parseJoin } from "./validate";

const PORT = Number(process.env.PORT) || 3000;
const app = express();
const http = createServer(app);
// Gli snapshot sono JSON molto ripetitivi (stessi nomi di campo 30 volte al secondo):
// la compressione del WebSocket li riduce di molto a un costo di CPU trascurabile anche con 8 giocatori
const io = new Server<ClientToServer, ServerToClient>(http, {
  cors: { origin: "*" },
  perMessageDeflate: { threshold: 256 },
  maxHttpBufferSize: NET_LIMITS.maxMessageBytes,
});

// In produzione lo stesso server serve anche il gioco già compilato (npm run build)
if (process.env.NODE_ENV === "production") {
  const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../dist");
  app.use(express.static(dist));
}
app.get("/health", (_req, res) => {
  res.json(health(rooms.values(), process.env));
});

const rooms = new Map<string, Room>();

// Classifica delle partite (#18): un file JSON accanto al server, o dove dice LEADERBOARD_FILE
const leaderboard = new Leaderboard(process.env.LEADERBOARD_FILE || path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../data/classifica.json"));
void leaderboard.load();
app.get("/classifica", (_req, res) => {
  res.type("html").send(leaderboardPage(leaderboard.week()));
});
app.get("/classifica.json", (_req, res) => {
  res.json(leaderboard.week());
});

io.on("connection", (socket) => {
  let room: Room | undefined;

  const inputBucket = new TokenBucket(NET_LIMITS.inputPerSecond, NET_LIMITS.inputBurst, Date.now());
  const rematchBucket = new TokenBucket(NET_LIMITS.rematchPerSecond, NET_LIMITS.rematchPerSecond, Date.now());
  const flood = new Flood(NET_LIMITS.floodCloseMs);
  // Scarta i messaggi oltre il limite e chiude chi continua a mandarne troppi
  const allow = (bucket: TokenBucket) => {
    const now = Date.now();
    const allowed = bucket.take(now);
    if (flood.record(allowed, now)) socket.disconnect(true);
    return allowed;
  };

  // I dati arrivano dalla rete: si leggono come unknown e si ripuliscono con validate.ts
  socket.on("join", (raw: unknown) => {
    if (room) return;
    const data = parseJoin(raw);
    if (!data) return;
    const { room: code, name, characterId, stageId, rules, bot } = data;
    let r = rooms.get(code);
    if (!r) {
      // Arena, regole e bot li decide chi crea la stanza
      const bots = new Bots();
      const discord = discordHooks(process.env.DISCORD_WEBHOOK_URL, (id) => bots.isBot(id), leaderboard);
      r = new Room(code, io, { stageId, rules }, combineHooks(bots.hooks, discord));
      rooms.set(code, r);
      const kind = parseBotKind(bot);
      if (kind) bots.add(r.match, kind);
    }
    if (r.isFull) {
      socket.emit("roomFull");
      return;
    }
    room = r;
    socket.join(code);
    r.addPlayer(socket.id, name, characterId);
    socket.emit("welcome", { id: socket.id, room: code, stageId: r.stage.id, rules: r.rules, stage: r.stage });
    console.log(`[${code}] entra ${socket.id}`);
  });

  socket.on("input", (raw: unknown) => {
    if (!room || !allow(inputBucket)) return;
    const input = parseInput(raw);
    if (input) room.setInput(socket.id, input);
  });
  socket.on("rematch", () => {
    if (room && allow(rematchBucket)) room.requestRematch();
  });

  socket.on("disconnect", () => {
    if (!room) return;
    room.removePlayer(socket.id);
    console.log(`[${room.code}] esce ${socket.id}`);
    if (room.isEmpty) {
      room.destroy();
      rooms.delete(room.code);
    }
  });
});

http.listen(PORT, () => {
  console.log(`Server di gioco su http://localhost:${PORT}`);
});
