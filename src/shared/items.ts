import { PACMAN, POWERUP, TETRIS } from "./constants";

// Oggetti che cadono nell'arena (#17 passo 3). Caduta, raccolta e lancio sono in
// src/shared/physics/items.ts, i numeri comuni in ITEM_RULES (constants.ts).

export interface ItemSpec {
  id: string;
  name: string;
  damage: number; // percentuale aggiunta a chi viene colpito dall'oggetto lanciato
  knockback: number; // pixel/s
  width: number; // pixel
  height: number;
  color: number; // finché non c'è uno sprite
  weight?: number; // quanto spesso compare rispetto agli altri (1 se manca)
  // Oggetto da consumare (#231): raccolto non si tiene in mano, dà subito il potenziamento per ms
  consume?: { powerup: string; ms: number };
  mushrooms?: boolean; // il sacchetto dei funghetti di Teemo (#302): giù + J ne pianta uno, senza giù si lancia
  planted?: boolean; // un funghetto piantato: non si raccoglie, scatta su chi lo calpesta
  call?: boolean; // il telefono di Chiama Bassanese: raccolto sparisce e fa entrare il Bassanese (physics/bassanese.ts)
  bong?: boolean; // si tiene in mano e si fuma in tre fasi (#302): J carica, K lancia come gli altri
}

// TODO community: oggetti ispirati ai meme del canale, uno per issue
export const ITEMS: Record<string, ItemSpec> = {
  banana: { id: "banana", name: "Banana", damage: 8, knockback: 300, width: 24, height: 16, color: 0xf1c40f, weight: 3 },
  // TODO community: il nome nel gioco (#231). Intoccabili, colpi più forti, passo lento (POWERUP)
  fiore: { id: "fiore", name: "Fiore", damage: 0, knockback: 0, width: 26, height: 26, color: 0x4caf50, weight: 1, consume: { powerup: "fiore", ms: POWERUP.flowerMs } },
  // TODO community: il nome nel gioco (#302). Carica, fatto, nuvola di fumo (BONG)
  // TODO community: il nome nel gioco (#302). Teemo di LoL: trappole quasi invisibili che fanno "viaggiare" (FUNGHI)
  funghetti: { id: "funghetti", name: "Funghetti", damage: 4, knockback: 250, width: 24, height: 20, color: 0x9b59b6, weight: 2, mushrooms: true },
  fungo: { id: "fungo", name: "Funghetto", damage: 0, knockback: 0, width: 20, height: 16, color: 0xc0392b, weight: 0, planted: true },
  bong: { id: "bong", name: "Bong", damage: 10, knockback: 380, width: 22, height: 40, color: 0x7fd8c4, weight: 2, bong: true },
  // Pac-Man (#427): si diventa Pac-Man e si mangiano gli altri (PACMAN)
  pacman: { id: "pacman", name: "Pac-Man", damage: 0, knockback: 0, width: 28, height: 28, color: 0xffeb3b, weight: 1, consume: { powerup: "pacman", ms: PACMAN.ms } },
  // TODO community: il nome nel gioco. Il telefono: raccolto chiama il Bassanese, che gira l'arena e colpisce gli altri (BASSANESE)
  bassanese: { id: "bassanese", name: "Chiama Bassanese", damage: 0, knockback: 0, width: 18, height: 30, color: 0x2c3e50, weight: 1, call: true },
  // Il Tetris (#427): ci si assenta e si guidano i pezzi che cadono dall'alto (TETRIS)
  tetris: { id: "tetris", name: "Tetris", damage: 0, knockback: 0, width: 28, height: 28, color: 0x00bcd4, weight: 1, consume: { powerup: "tetris", ms: TETRIS.ms } },
};

// Gli oggetti che possono cadere dal cielo (i funghetti piantati no), in ordine: si scelgono nelle regole della stanza
export const DROPPABLE_ITEMS: readonly string[] = Object.keys(ITEMS).filter((k) => (ITEMS[k].weight ?? 1) > 0).sort();
