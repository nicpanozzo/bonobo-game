import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import { Server } from "socket.io";
import { NET_LIMITS } from "../shared/constants";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { attachGame } from "./game";
import { health } from "./health";
import { Leaderboard, leaderboardPage } from "./leaderboard";

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

// Classifica delle partite (#18): un file JSON accanto al server, o dove dice LEADERBOARD_FILE
const leaderboard = new Leaderboard(process.env.LEADERBOARD_FILE || path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../data/classifica.json"));
void leaderboard.load();
app.get("/classifica", (_req, res) => {
  res.type("html").send(leaderboardPage(leaderboard.week()));
});
app.get("/classifica.json", (_req, res) => {
  res.json(leaderboard.week());
});

// Stanze e messaggi dei giocatori: src/server/game.ts
const rooms = attachGame(io, { leaderboard, discordWebhookUrl: process.env.DISCORD_WEBHOOK_URL });

http.listen(PORT, () => {
  console.log(`Server di gioco su http://localhost:${PORT}`);
});
