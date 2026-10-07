// Versione del client nel join (E2 passo 2, #106). In questa fase il server non blocca chi ha
// un'altra versione del gioco: lo rifiuta solo se parla un altro protocollo. Chi non manda niente
// (app e pagine di prima) entra comunque.
import pkg from "../../package.json";
import { PROTOCOL_VERSION } from "../shared/constants";
import type { Refusal } from "../shared/types";

export const SERVER_VERSION: string = pkg.version;

const DOWNLOAD_PAGE = "nicpanozzo.github.io/bonobo-game";

/** Il rifiuto da mandare a chi entra con questo protocollo, o null se può giocare */
export function checkProtocol(protocol: number | undefined): Refusal | null {
  if (protocol === undefined || protocol === PROTOCOL_VERSION) return null;
  return protocol < PROTOCOL_VERSION
    ? { reason: "outdated", message: `Il tuo gioco è troppo vecchio per questo server: scarica quello nuovo da ${DOWNLOAD_PAGE}` }
    : { reason: "outdated", message: "Questo server è più vecchio del tuo gioco: chiedi a chi lo ospita di aggiornarlo" };
}

export const ROOM_FULL: Refusal = { reason: "full", message: "Stanza piena! Prova con un'altra stanza" };
export const TOO_MANY_ROOMS: Refusal = { reason: "limit", message: "Il server è pieno di stanze: riprova tra poco" };
