import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import { Server } from "socket.io";
import { NET_LIMITS, PING_INTERVAL_MS, PING_TIMEOUT_MS } from "../shared/constants";
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
  // Un client sparito si vede in ~10 s invece di 45 (#107): intanto il suo lottatore resta fermo nel posto tenuto
  pingInterval: PING_INTERVAL_MS,
  pingTimeout: PING_TIMEOUT_MS,
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

// Un errore sfuggito (in un gancio asincrono, in una libreria) non spegne il server per tutti: si registra e si va avanti.
// Solo se la porta non si apre non c'è niente da tenere acceso. host.ts ha un suo gestore che lo spiega a chi ospita.
process.on("uncaughtException", (err: NodeJS.ErrnoException) => {
  if (err.syscall === "listen") {
    if (process.listenerCount("uncaughtException") > 1) return;
    console.error(`[server] non riesco ad aprire la porta ${PORT}:`, err.message);
    process.exit(1);
  }
  console.error("[server] errore non gestito, il server resta acceso:", err);
});
process.on("unhandledRejection", (reason) => {
  console.error("[server] promessa rifiutata non gestita, il server resta acceso:", reason);
});

http.listen(PORT, () => {
  console.log(`Server di gioco su http://localhost:${PORT}`);
});
