// Il gioco in rete: stanze, ingresso, tasti e uscita dei giocatori.
// Separato da index.ts (HTTP e avvio) così i test possono accenderlo su un server vero (E4 passo 2).

import type { Server } from "socket.io";
import { NET_LIMITS, ROOM_IDLE_MS } from "../shared/constants";
import type { ClientToServer, ServerToClient } from "../shared/types";
import { Bots, parseBotKind } from "./bot";
import { discordHooks } from "./discord";
import type { Leaderboard } from "./leaderboard";
import { clientIp, Flood, IpLimits, TokenBucket } from "./rateLimit";
import { combineHooks, Room } from "./Room";
import { parseInput, parseJoin, sanitizeName } from "./validate";

export interface GameDeps {
  leaderboard?: Leaderboard;
  discordWebhookUrl?: string;
  limits?: Partial<typeof NET_LIMITS>; // per i test: limiti diversi da quelli di constants.ts
  roomIdleMs?: number;
}

// Collega il gioco al server Socket.IO e restituisce le stanze aperte (per /health e per i test)
export function attachGame(io: Server<ClientToServer, ServerToClient>, deps: GameDeps = {}): Map<string, Room> {
  const rooms = new Map<string, Room>();
  const limits = { ...NET_LIMITS, ...deps.limits };
  const perIp = new IpLimits(limits.maxConnectionsPerIp, limits.newRoomsPerIpPerMinute);
  const idleMs = deps.roomIdleMs ?? ROOM_IDLE_MS;

  // Una stanza dove nessun umano preme tasti da troppo si chiude come una vuota: chi è dentro viene scollegato
  const sweep = setInterval(() => {
    const now = Date.now();
    perIp.prune(now);
    for (const r of rooms.values()) {
      if (now - r.lastHumanInput < idleMs) continue;
      console.log(`[${r.code}] chiusa: nessun tasto da ${Math.round(idleMs / 60_000)} minuti`);
      io.in(r.code).disconnectSockets(true);
      r.destroy();
      rooms.delete(r.code);
    }
  }, Math.min(idleMs, 60_000));
  sweep.unref(); // non tiene acceso il processo (test, chiusura del server)

  io.on("connection", (socket) => {
    let room: Room | undefined;
    const ip = clientIp(socket.handshake.address, socket.handshake.headers);
    if (!perIp.connect(ip)) {
      console.log(`[rete] troppe connessioni da ${ip}: chiusa`);
      socket.disconnect(true);
      return;
    }

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
      const { room: code, characterId, stageId, rules, bot } = data;
      let r = rooms.get(code);
      if (!r) {
        if (rooms.size >= limits.maxRooms || !perIp.createRoom(ip, Date.now())) {
          console.log(`[${code}] stanza non creata: troppe stanze (${rooms.size}) o troppe nuove da ${ip}`);
          socket.disconnect(true);
          return;
        }
        // Arena, regole e bot li decide chi crea la stanza
        const bots = new Bots();
        const discord = discordHooks(deps.discordWebhookUrl, (id) => bots.isBot(id), deps.leaderboard);
        r = new Room(code, io, { stageId, rules }, combineHooks(bots.hooks, discord));
        rooms.set(code, r);
        r.onClose = () => rooms.delete(code);
        const kind = parseBotKind(bot);
        if (kind) bots.add(r.match, kind);
      }
      if (r.isFull) {
        socket.emit("roomFull");
        return;
      }
      room = r;
      socket.join(code);
      const name = sanitizeName(data.name, r.match.players.map((p) => p.name));
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
      perIp.disconnect(ip);
      if (!room || rooms.get(room.code) !== room) return;
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
