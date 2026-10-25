import { FUNGO, ITEM_RARITY, PACMAN, POWERUP, TETRIS, type ItemRarity } from "./constants";

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
  // Classe di frequenza, obbligatoria: più l'oggetto cambia la partita, più è raro (Nicola). I pesi sono in ITEM_RARITY
  rarity: ItemRarity;
  // Oggetto da consumare (#231): raccolto non si tiene in mano, dà subito il potenziamento per ms
  consume?: { powerup: string; ms: number };
  mushrooms?: boolean; // il sacchetto dei funghetti di Teemo (#302): giù + J ne pianta uno, senza giù si lancia
  planted?: boolean; // un funghetto piantato: non si raccoglie, scatta su chi lo calpesta
  call?: boolean; // il telefono di Chiama Bassanese: raccolto sparisce e fa entrare il Bassanese (physics/bassanese.ts)
  bong?: boolean; // si tiene in mano e si fuma in tre fasi (#302): J carica, K lancia come gli altri
  shroom?: boolean; // il fungo di Teemo (#419): lanciato o posato si piazza dove atterra, armato scoppia sugli avversari (FUNGO)
}

// TODO community: oggetti ispirati ai meme del canale, uno per issue
export const ITEMS: Record<string, ItemSpec> = {
  banana: { id: "banana", name: "Banana", damage: 8, knockback: 300, width: 24, height: 16, color: 0xf1c40f, rarity: "comune" },
  // TODO community: il nome nel gioco (#231). Intoccabili, colpi più forti, passo lento (POWERUP)
  fiore: { id: "fiore", name: "Fiore", damage: 0, knockback: 0, width: 26, height: 26, color: 0x4caf50, rarity: "raro", consume: { powerup: "fiore", ms: POWERUP.flowerMs } },
  // TODO community: il nome nel gioco (#302). Carica, fatto, nuvola di fumo (BONG)
  // TODO community: il nome nel gioco (#302). Teemo di LoL: trappole quasi invisibili che fanno "viaggiare" (FUNGHI)
  // Messi da parte per il fungo di Teemo (#419): il codice resta, ma non cadono più. Per riaverli: rarity "normale"
  funghetti: { id: "funghetti", name: "Funghetti", damage: 4, knockback: 250, width: 24, height: 20, color: 0x9b59b6, rarity: "mai", mushrooms: true },
  fungo: { id: "fungo", name: "Funghetto", damage: 0, knockback: 0, width: 20, height: 16, color: 0xc0392b, rarity: "mai", planted: true },
  // TODO community: il nome nel gioco (#419). Teemo di LoL: un fungo grande, invisibile da armato, scoppia in una nube di veleno (FUNGO)
  fungoTeemo: { id: "fungoTeemo", name: "Fungo di Teemo", damage: FUNGO.thrownDamage, knockback: 260, width: 36, height: 34, color: 0x5a7631, rarity: "normale", shroom: true },
  bong: { id: "bong", name: "Bong", damage: 10, knockback: 380, width: 22, height: 40, color: 0x7fd8c4, rarity: "normale", bong: true },
  // Pac-Man (#427): si diventa Pac-Man e si mangiano gli altri (PACMAN)
  pacman: { id: "pacman", name: "Pac-Man", damage: 0, knockback: 0, width: 28, height: 28, color: 0xffeb3b, rarity: "rarissimo", consume: { powerup: "pacman", ms: PACMAN.ms } },
  // TODO community: il nome nel gioco. Il telefono: raccolto chiama il Bassanese, che gira l'arena e colpisce gli altri (BASSANESE)
  bassanese: { id: "bassanese", name: "Chiama Bassanese", damage: 0, knockback: 0, width: 18, height: 30, color: 0x2c3e50, rarity: "raro", call: true },
  // Il Tetris (#427): ci si assenta e si guidano i pezzi che cadono dall'alto (TETRIS)
  tetris: { id: "tetris", name: "Tetris", damage: 0, knockback: 0, width: 28, height: 28, color: 0x00bcd4, rarity: "rarissimo", consume: { powerup: "tetris", ms: TETRIS.ms } },
};

// Gli oggetti che possono cadere dal cielo (rarity "mai" no), in ordine: si scelgono nelle regole della stanza
export const DROPPABLE_ITEMS: readonly string[] = Object.keys(ITEMS).filter((k) => itemWeight(k) > 0).sort();

// Quanto spesso cade un oggetto rispetto agli altri, dalla sua classe di frequenza
export function itemWeight(kind: string): number {
  return ITEM_RARITY[ITEMS[kind].rarity];
}
