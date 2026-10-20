import { BIRRA, FUNGO, POWERUP } from "./constants";

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
  shroom?: boolean; // il fungo di Teemo: lanciato o posato si piazza dove atterra, armato scoppia sugli avversari (FUNGO)
  bong?: boolean; // si tiene in mano e si fuma in tre fasi (#302): J carica, K lancia come gli altri
}

// TODO community: oggetti ispirati ai meme del canale, uno per issue
export const ITEMS: Record<string, ItemSpec> = {
  banana: { id: "banana", name: "Banana", damage: 8, knockback: 300, width: 24, height: 16, color: 0xf1c40f, weight: 3 },
  // TODO community: il nome nel gioco (#231). Intoccabili, colpi più forti, passo lento (POWERUP)
  fiore: { id: "fiore", name: "Fiore", damage: 0, knockback: 0, width: 26, height: 26, color: 0x4caf50, weight: 1, consume: { powerup: "fiore", ms: POWERUP.flowerMs } },
  // TODO community: il nome nel gioco (#302). Carica, fatto, nuvola di fumo (BONG)
  // TODO community: il nome nel gioco. Teemo di LoL: un fungo grande, invisibile da armato, scoppia in una nube di veleno (FUNGO)
  fungo: { id: "fungo", name: "Fungo di Teemo", damage: FUNGO.thrownDamage, knockback: 200, width: 36, height: 34, color: 0x3fd14a, weight: 2, shroom: true },
  // TODO community: il nome nel gioco (#302). Cappello tirolese, colpi più forti, si barcolla (BIRRA)
  birra: { id: "birra", name: "Birra", damage: 0, knockback: 0, width: 22, height: 30, color: 0xf0b030, weight: 2, consume: { powerup: "birra", ms: BIRRA.ms } },
  bong: { id: "bong", name: "Bong", damage: 10, knockback: 380, width: 22, height: 40, color: 0x7fd8c4, weight: 2, bong: true },
};

// Gli oggetti che possono cadere dal cielo (peso 0 no), in ordine: si scelgono nelle regole della stanza
export const DROPPABLE_ITEMS: readonly string[] = Object.keys(ITEMS).filter((k) => (ITEMS[k].weight ?? 1) > 0).sort();
