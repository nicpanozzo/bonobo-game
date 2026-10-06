// Il gioco in rete: stanze, ingresso, tasti e uscita dei giocatori.
// Separato da index.ts (HTTP e avvio) così i test possono accenderlo su un server vero (E4 passo 2).

import type { Server } from "socket.io";
import { NET_LIMITS } from "../shared/constants";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { Bots, parseBotKind } from "./bot";
import { discordHooks } from "./discord";
import type { Leaderboard } from "./leaderboard";
import { Flood, TokenBucket } from "./rateLimit";
import { combineHooks, Room } from "./Room";
import { parseInput, parseJoin } from "./validate";

export interface GameDeps {
  leaderboard?: Leaderboard;
  discordWebhookUrl?: string;
}

// Collega il gioco al server Socket.IO e restituisce le stanze aperte (per /health e per i test)
export function attachGame(io: Server<ClientToServer, ServerToClient>, deps: GameDeps = {}): Map<string, Room> {
  const rooms = new Map<string, Room>();

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
        const discord = discordHooks(deps.discordWebhookUrl, (id) => bots.isBot(id), deps.leaderboard);
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

  return rooms;
}
