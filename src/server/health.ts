// Risposta di /health (#19 passo 3): dice se il server è vivo, quale versione e quale commit girano,
// e quanta gente sta giocando. Dopo un deploy basta un curl per sapere se è online quello nuovo.
// La versione arriva da package.json dentro il pacchetto (anche nell'eseguibile di bonobo-server).
import pkg from "../../package.json";

export interface Health {
  ok: true;
  version: string;
  /** Commit in esecuzione, o null se nessuno l'ha detto al server */
  commit: string | null;
  rooms: number;
  players: number;
}

/** Il minimo che serve di una stanza: quanti umani ci sono dentro */
export interface RoomCount {
  humanCount: number;
}

export function health(rooms: Iterable<RoomCount>, env: Record<string, string | undefined>): Health {
  let roomCount = 0;
  let players = 0;
  for (const room of rooms) {
    roomCount++;
    players += room.humanCount;
  }
  // Render mette il commit in RENDER_GIT_COMMIT; altrove si può passare GIT_COMMIT
  const commit = env.RENDER_GIT_COMMIT || env.GIT_COMMIT || null;
  return { ok: true, version: pkg.version, commit, rooms: roomCount, players };
}
