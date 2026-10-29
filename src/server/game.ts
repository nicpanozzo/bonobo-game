// Il gioco in rete: stanze, ingresso, tasti e uscita dei giocatori.
// Separato da index.ts (HTTP e avvio) così i test possono accenderlo su un server vero (E4 passo 2).

import type { Server, Socket } from "socket.io";
import { HALL, NET_LIMITS, ROOM_IDLE_MS, VOICE } from "../shared/constants";
import type { ClientToServer, IceServer, ServerToClient, VoiceState } from "../shared/types";
import { botCharacter, Bots, parseBotKind } from "./bot";
import { discordHooks } from "./discord";
import type { Leaderboard } from "./leaderboard";
import { clientIp, Flood, IpLimits, TokenBucket } from "./rateLimit";
import { combineHooks, Room } from "./Room";
import { parseInput, parseJoin, parseTraining, parseVoiceSignal, parseVoiceState, sanitizeName } from "./validate";
import { checkProtocol, ROOM_FULL, SERVER_VERSION, TOO_MANY_ROOMS } from "./version";

export interface GameDeps {
  leaderboard?: Leaderboard;
  discordWebhookUrl?: string;
  limits?: Partial<typeof NET_LIMITS>; // per i test: limiti diversi da quelli di constants.ts
  roomIdleMs?: number;
  reconnectHoldMs?: number; // per i test: posto tenuto più corto di RECONNECT_HOLD_MS
  turn?: IceServer; // server TURN per la chat vocale (index.ts lo legge dall'ambiente con turnFromEnv)
}

// TURN dall'ambiente: TURN_URL (anche più indirizzi separati da virgola), TURN_USERNAME, TURN_CREDENTIAL.
// Senza TURN_URL niente TURN: la voce passa solo dove STUN basta
export function turnFromEnv(env: Record<string, string | undefined>): IceServer | undefined {
  const urls = (env.TURN_URL ?? "").split(",").map((u) => u.trim()).filter(Boolean);
  if (urls.length === 0) return undefined;
  return { urls, ...(env.TURN_USERNAME && { username: env.TURN_USERNAME }), ...(env.TURN_CREDENTIAL && { credential: env.TURN_CREDENTIAL }) };
}

// Stato di chi esce dalla voce: agli altri basta on false per chiudere il collegamento
const voiceOff = (id: string): VoiceState => ({ id, on: false, muted: false, deafened: false });

// Collega il gioco al server Socket.IO e restituisce le stanze aperte (per /health e per i test)
export function attachGame(io: Server<ClientToServer, ServerToClient>, deps: GameDeps = {}): Map<string, Room> {
  const rooms = new Map<string, Room>();
  const limits = { ...NET_LIMITS, ...deps.limits };
  const perIp = new IpLimits(limits.maxConnectionsPerIp, limits.newRoomsPerIpPerMinute);
  const idleMs = deps.roomIdleMs ?? ROOM_IDLE_MS;
  // Chi controlla ogni lottatore: dopo una riconnessione il lottatore (playerId) passa a un socket nuovo (#107)
  const owners = new Map<string, Socket<ClientToServer, ServerToClient>>();
  const replaced = new Set<string>(); // socket vecchi chiusi perché il loro giocatore è rientrato da un altro
  // Chi è nella chat vocale di ogni stanza (assente = fuori). Per oggetto Room e non per codice: una stanza chiusa
  // si porta via il suo elenco, e una nuova con lo stesso codice parte vuota
  const voices = new WeakMap<Room, Map<string, VoiceState>>();
  const voicesOf = (r: Room) => {
    let states = voices.get(r);
    if (!states) voices.set(r, (states = new Map()));
    return states;
  };
  // Il giocatore esce dalla voce (uscito, caduto o rientrato da un altro socket): gli altri chiudono il collegamento
  const leaveVoice = (r: Room, id: string) => {
    if (voicesOf(r).delete(id)) io.to(r.code).emit("voiceState", voiceOff(id));
  };
  // L'audio va da browser a browser: il server dà gli indirizzi STUN (e TURN se c'è) e chi è già in voce
  const iceServers: IceServer[] = [{ urls: [...VOICE.stunUrls] }, ...(deps.turn ? [deps.turn] : [])];
  const sendVoiceConfig = (socket: Socket<ClientToServer, ServerToClient>, r: Room) =>
    socket.emit("voiceConfig", { iceServers, states: [...voicesOf(r).values()] });

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
    let playerId = socket.id; // resta quello della prima connessione anche dopo una riconnessione
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
      const { room: code, characterId, stageId, rules, bot, botCharacterId } = data;
      const refusal = checkProtocol(data.protocol);
      if (refusal) {
        socket.emit("refused", refusal);
        console.log(`[${code}] rifiutato: protocollo ${data.protocol}, versione ${data.version ?? "?"}`);
        return;
      }
      let r = rooms.get(code);
      // Rientro dopo una caduta di rete: il token del welcome riporta nello stesso lottatore, con vite e percentuale
      const { token } = data;
      const resumedId = r && token ? r.seats.resume(token, Date.now()) : null;
      if (r && token && resumedId) {
        const old = owners.get(resumedId);
        if (old && old.id !== socket.id) {
          // Il vecchio socket non si è ancora accorto di essere morto: vince il nuovo, e l'uscita del vecchio non tocca il posto
          replaced.add(old.id);
          old.disconnect(true);
        }
        room = r;
        playerId = resumedId;
        owners.set(playerId, socket);
        socket.join(code);
        r.resumePlayer(playerId);
        // Il client rientrato riparte senza voce: i collegamenti di prima sono morti col socket vecchio
        leaveVoice(r, playerId);
        socket.emit("welcome", { id: playerId, room: code, stageId: r.stage.id, rules: r.rules, stage: r.stage, token, resumed: true, serverVersion: SERVER_VERSION, hall: !!r.hall, phase: r.phase });
        sendVoiceConfig(socket, r);
        console.log(`[${code}] rientra ${playerId}`);
        return;
      }
      if (!r) {
        if (rooms.size >= limits.maxRooms || !perIp.createRoom(ip, Date.now())) {
          console.log(`[${code}] stanza non creata: troppe stanze (${rooms.size}) o troppe nuove da ${ip}`);
          socket.emit("refused", TOO_MANY_ROOMS);
          socket.disconnect(true);
          return;
        }
        // Arena, regole e bot li decide chi crea la stanza
        const bots = new Bots();
        const discord = discordHooks(deps.discordWebhookUrl, (id) => bots.isBot(id), deps.leaderboard);
        const kind = parseBotKind(bot);
        // Sala d'attesa: i suoi bot entrano in ogni partita nuova; giocano come il bot scelto dal creatore (mai fermi)
        const hallKind = kind === "facile" || kind === "difficile" ? kind : "semplice";
        const hallBots = {
          onMatchBuilt: (_room: Room, match: Room["match"], botIds: string[]) => {
            bots.reset();
            for (const id of botIds) bots.adopt(match, id, hallKind);
          },
        };
        const board = () => deps.leaderboard?.board(HALL.boardRows) ?? [];
        r = new Room(code, io, { stageId, rules, prematch: true, hall: data.hall, board }, combineHooks(bots.hooks, discord, hallBots), deps.reconnectHoldMs);
        rooms.set(code, r);
        r.onClose = () => rooms.delete(code);
        if (kind && r.hall) r.hall.addBot(botCharacter(botCharacterId));
        else if (kind) bots.add(r.match, kind, botCharacterId);
      }
      if (r.isFull) {
        socket.emit("roomFull");
        socket.emit("refused", ROOM_FULL);
        return;
      }
      room = r;
      socket.join(code);
      const name = sanitizeName(data.name, r.playerNames);
      r.addPlayer(playerId, name, characterId, data.skinId, data.team);
      owners.set(playerId, socket);
      const fresh = r.seats.issue(playerId);
      socket.emit("welcome", { id: playerId, room: code, stageId: r.stage.id, rules: r.rules, stage: r.stage, token: fresh, resumed: false, serverVersion: SERVER_VERSION, hall: !!r.hall, phase: r.phase });
      sendVoiceConfig(socket, r);
      console.log(`[${code}] entra ${playerId}`);
    });

    socket.on("input", (raw: unknown) => {
      if (!room || !allow(inputBucket)) return;
      const input = parseInput(raw);
      if (input) room.setInput(playerId, input);
    });
    socket.on("rematch", () => {
      if (room && allow(rematchBucket)) room.requestRematch();
    });
    // A partita finita: tutti nella sala d'attesa (solo nelle stanze con la sala)
    socket.on("hall", () => {
      if (room && allow(rematchBucket)) room.requestHall();
    });
    // Pre-partita: Pronto (o non più); conta solo finché la partita non è cominciata
    socket.on("ready", (raw: unknown) => {
      if (room && allow(rematchBucket) && typeof raw === "object" && raw !== null) room.match.setReady(playerId, (raw as { ready?: unknown }).ready === true);
    });
    // Cambio di squadra (#409): la Match accetta solo una squadra che esiste in queste regole
    socket.on("team", (raw: unknown) => {
      if (room && allow(rematchBucket) && typeof raw === "object" && raw !== null) room.match.setTeam(playerId, (raw as { team?: unknown }).team);
    });
    // Allenamento (#113): solo in palestra e da soli, altrimenti si rallenterebbero gli altri
    const trainingBucket = new TokenBucket(NET_LIMITS.trainingPerSecond, NET_LIMITS.trainingPerSecond, Date.now());
    socket.on("training", (raw: unknown) => {
      if (!room || room.rules.mode !== "training" || room.humanCount !== 1 || !allow(trainingBucket)) return;
      const cmd = parseTraining(raw);
      if (!cmd) return;
      if (cmd.reset) room.match.reset();
      if (cmd.speed !== undefined) room.setSpeed(cmd.speed);
      // La percentuale è quella degli avversari (il bot), non la propria
      if (cmd.percent !== undefined) for (const f of room.match.players) if (f.id !== playerId) room.match.setPercent(f.id, cmd.percent);
    });

    // Chat vocale: il server fa solo da centralino tra due giocatori della stessa stanza.
    // Il mittente è sempre quello di questo socket, mai quello scritto dal client; i bot non hanno socket, quindi niente voce
    const voiceBucket = new TokenBucket(VOICE.signalsPerSecond, VOICE.signalBurst, Date.now());
    const voiceStateBucket = new TokenBucket(VOICE.statesPerSecond, VOICE.statesPerSecond, Date.now());
    socket.on("voice", (raw: unknown) => {
      if (!room || !allow(voiceBucket)) return;
      const signal = parseVoiceSignal(raw);
      if (!signal || signal.to === playerId) return;
      const target = owners.get(signal.to);
      if (!target?.rooms.has(room.code)) return;
      target.emit("voice", { kind: signal.kind, data: signal.data, from: playerId });
    });
    socket.on("voiceState", (raw: unknown) => {
      if (!room || !allow(voiceStateBucket)) return;
      const next = parseVoiceState(raw);
      if (!next) return;
      if (!next.on) {
        leaveVoice(room, playerId);
        return;
      }
      const states = voicesOf(room);
      const prev = states.get(playerId);
      if (prev && prev.muted === next.muted && prev.deafened === next.deafened) return; // niente di nuovo da dire
      const state: VoiceState = { id: playerId, ...next };
      states.set(playerId, state);
      io.to(room.code).emit("voiceState", state);
    });

    socket.on("disconnect", (reason) => {
      perIp.disconnect(ip);
      if (replaced.delete(socket.id)) return;
      if (owners.get(playerId) === socket) owners.delete(playerId);
      if (!room || rooms.get(room.code) !== room) return;
      // Fuori dalla voce sia chi esce sia chi cade: al rientro il client si ricollega da capo
      leaveVoice(room, playerId);
      // Chi esce apposta (il client chiude il namespace) libera subito il posto;
      // chi perde la rete lo ritrova tenuto per RECONNECT_HOLD_MS (#107)
      if (reason !== "client namespace disconnect" && reason !== "server namespace disconnect") {
        room.holdPlayer(playerId);
        console.log(`[${room.code}] perso ${playerId} (${reason}): posto tenuto`);
        return;
      }
      room.removePlayer(playerId);
      console.log(`[${room.code}] esce ${playerId}`);
      if (room.isEmpty) {
        room.destroy();
        rooms.delete(room.code);
      }
    });
  });

  return rooms;
}
