import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import { Server } from "socket.io";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { Bots, parseBotKind } from "./bot";
import { discordHooks } from "./discord";
import { combineHooks, Room } from "./Room";

const PORT = Number(process.env.PORT) || 3000;
const app = express();
const http = createServer(app);
// Gli snapshot sono JSON molto ripetitivi (stessi nomi di campo 30 volte al secondo):
// la compressione del WebSocket li riduce di molto a un costo di CPU trascurabile anche con 8 giocatori
const io = new Server<ClientToServer, ServerToClient>(http, { cors: { origin: "*" }, perMessageDeflate: { threshold: 256 } });

// In produzione lo stesso server serve anche il gioco già compilato (npm run build)
if (process.env.NODE_ENV === "production") {
  const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../dist");
  app.use(express.static(dist));
}
app.get("/health", (_req, res) => {
  res.json({ ok: true, rooms: rooms.size });
});

const rooms = new Map<string, Room>();

io.on("connection", (socket) => {
  let room: Room | undefined;

  socket.on("join", ({ room: rawCode, name, characterId, stageId, rules, bot }) => {
    if (room) return;
    const code = String(rawCode || "lobby").toLowerCase().replace(/[^a-z0-9-]/g, "").slice(0, 24) || "lobby";
    let r = rooms.get(code);
    if (!r) {
      // Arena, regole e bot li decide chi crea la stanza
      const bots = new Bots();
      const discord = discordHooks(process.env.DISCORD_WEBHOOK_URL, (id) => bots.isBot(id));
      r = new Room(code, io, { stageId: typeof stageId === "string" ? stageId : undefined, rules }, combineHooks(bots.hooks, discord));
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
    r.addPlayer(socket.id, String(name || ""), typeof characterId === "string" ? characterId : undefined);
    socket.emit("welcome", { id: socket.id, room: code, stageId: r.stage.id, rules: r.rules, stage: r.stage });
    console.log(`[${code}] entra ${socket.id}`);
  });

  socket.on("input", (input) => room?.setInput(socket.id, input));
  socket.on("rematch", () => room?.requestRematch());

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
