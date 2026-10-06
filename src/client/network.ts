import { io, type Socket } from "socket.io-client";
import type { ClientToServer, ServerToClient } from "../shared/types";

export type GameSocket = Socket<ServerToClient, ClientToServer>;

// Stanza, nome e personaggio si leggono dall'indirizzo: ?room=amici&name=Nico&char=egiainuso
// Senza stanza ne creiamo una a caso e la mettiamo nell'URL, così il link si può condividere.
export function readRoomAndName() {
  const params = new URLSearchParams(location.search);
  let room = params.get("room");
  if (!room) {
    room = Math.random().toString(36).slice(2, 7);
    params.set("room", room);
    history.replaceState(null, "", `?${params}`);
  }
  const name = params.get("name") || `Bonobo${Math.floor(Math.random() * 100)}`;
  // Finché non c'è la lobby (#5) il personaggio si sceglie con ?char=
  const characterId = params.get("char") || undefined;
  return { room, name, characterId };
}

export function connect(): GameSocket {
  // Stesso indirizzo della pagina: in sviluppo ci pensa il proxy di Vite.
  // Se il server sta altrove, imposta VITE_SERVER_URL.
  const url = import.meta.env.VITE_SERVER_URL as string | undefined;
  return url ? io(url) : io();
}
