// I minigiochi di Bonobo Party (#579). Per aggiungerne uno: un file qui accanto con il suo MinigameDef, poi una riga
// nell'elenco. Il tabellone li pesca da qui; il client li conosce solo da MinigameInfo e dagli oggetti di scena.

import type { MinigameInfo } from "../../types";
import type { MinigameDef } from "../minigame";
import { contagio } from "./contagio";
import { crollo } from "./crollo";
import { mezzogiorno } from "./mezzogiorno";
import { pioggia } from "./pioggia";
import { scalata } from "./scalata";

export const MINIGAMES: Record<string, MinigameDef> = Object.fromEntries([pioggia, contagio, scalata, crollo, mezzogiorno].map((g) => [g.info.id, g]));

export function getMinigame(id: string): MinigameDef | undefined {
  return MINIGAMES[id];
}

// Quelli che si possono giocare in tanti
export function minigamesFor(players: number): MinigameInfo[] {
  return Object.values(MINIGAMES)
    .filter((g) => players >= (g.minPlayers ?? 1))
    .map((g) => g.info);
}
