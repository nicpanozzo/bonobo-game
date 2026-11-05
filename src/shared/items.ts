import { FUNGO, GEAR, ITEM_RARITY, PACMAN, POWERUP, RIDE, TETRIS, type ItemRarity } from "./constants";

// Oggetti che cadono nell'arena (#17 passo 3). Caduta, raccolta e lancio sono in
// src/shared/physics/items.ts, i numeri comuni in ITEM_RULES (constants.ts).

// Le categorie degli oggetti, per presa (docs/clip-flow/README.md, "L'obiettivo"): ogni categoria si usa allo stesso
// modo con tutti gli oggetti dentro, così un oggetto nuovo non costa animazioni nuove. In ordine per la lobby
export type ItemCategory = "lancio" | "consumo" | "impugnatura" | "sparo" | "peso" | "cavalcatura";
export const ITEM_CATEGORIES: { id: ItemCategory; name: string; hint: string }[] = [
  { id: "lancio", name: "Da lanciare", hint: "J o K per raccoglierlo, J o K per lanciarlo" },
  { id: "consumo", name: "Da consumare", hint: "fa effetto appena lo prendi" },
  { id: "impugnatura", name: "Da impugnare", hint: "J colpisce con l'oggetto, K lo lancia" },
  { id: "sparo", name: "Da sparo", hint: "J spara, K lo lancia" },
  { id: "peso", name: "Pesanti", hint: "sopra la testa: lenti, K lo scaglia" },
  { id: "cavalcatura", name: "Da cavalcare", hint: "ci sali sopra, J carica, K scendi" },
];

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
  category?: ItemCategory; // obbligatoria per chi cade dal cielo (items.test.ts)
  rareOf?: string; // la versione rara di quest'altro oggetto: fa la stessa cosa più una particolare
  throwSpec?: { throwSpeed: number; throwLift: number; throwUpSpeed: number; gravityMult: number }; // vola diverso dalla banana
  homing?: boolean; // lanciato insegue l'avversario più vicino (GEAR.ciabattaMamma)
  petardo?: "normale" | "grappolo" | "mini"; // si accende lanciato o posato, si attacca dove tocca e scoppia (GEAR.petardo)
  crate?: number; // la cassa (physics/ride.ts): rotta lascia tanti oggetti della stanza
  washer?: "normale" | "matta"; // la lavatrice (ride.ts): scagliata va in centrifuga; matta salta addosso agli avversari
  mount?: "monopattino" | "razzo" | "carrello"; // ci si sale sopra (ride.ts, RIDE)
  seats?: number; // il carrello: quanti ne tiene dentro
}

// TODO community: oggetti ispirati ai meme del canale, uno per issue
export const ITEMS: Record<string, ItemSpec> = {
  banana: { id: "banana", name: "Banana", damage: 8, knockback: 300, width: 24, height: 16, color: 0xf1c40f, rarity: "comune", category: "lancio" },
  // TODO community: il nome nel gioco (#231). Intoccabili, colpi più forti, passo lento (POWERUP)
  fiore: { id: "fiore", name: "Fiore", damage: 0, knockback: 0, width: 26, height: 26, color: 0x4caf50, rarity: "raro", category: "consumo", consume: { powerup: "fiore", ms: POWERUP.flowerMs } },
  // TODO community: il nome nel gioco (#302). Carica, fatto, nuvola di fumo (BONG)
  // TODO community: il nome nel gioco (#302). Teemo di LoL: trappole quasi invisibili che fanno "viaggiare" (FUNGHI)
  // Messi da parte per il fungo di Teemo (#419): il codice resta, ma non cadono più. Per riaverli: rarity "normale"
  funghetti: { id: "funghetti", name: "Funghetti", damage: 4, knockback: 250, width: 24, height: 20, color: 0x9b59b6, rarity: "mai", mushrooms: true },
  fungo: { id: "fungo", name: "Funghetto", damage: 0, knockback: 0, width: 20, height: 16, color: 0xc0392b, rarity: "mai", planted: true },
  // TODO community: il nome nel gioco (#419). Teemo di LoL: un fungo grande, invisibile da armato, scoppia in una nube di veleno (FUNGO)
  fungoTeemo: { id: "fungoTeemo", name: "Fungo di Teemo", damage: FUNGO.thrownDamage, knockback: 260, width: 36, height: 34, color: 0x5a7631, rarity: "normale", category: "lancio", shroom: true },
  bong: { id: "bong", name: "Bong", damage: 10, knockback: 380, width: 22, height: 40, color: 0x7fd8c4, rarity: "normale", category: "consumo", bong: true },
  // Pac-Man (#427): si diventa Pac-Man e si mangiano gli altri (PACMAN)
  pacman: { id: "pacman", name: "Pac-Man", damage: 0, knockback: 0, width: 28, height: 28, color: 0xffeb3b, rarity: "rarissimo", category: "consumo", consume: { powerup: "pacman", ms: PACMAN.ms } },
  // TODO community: il nome nel gioco. Il telefono: raccolto chiama il Bassanese, che gira l'arena e colpisce gli altri (BASSANESE)
  bassanese: { id: "bassanese", name: "Chiama Bassanese", damage: 0, knockback: 0, width: 18, height: 30, color: 0x2c3e50, rarity: "raro", category: "consumo", call: true },
  // Il Tetris (#427): ci si assenta e si guidano i pezzi che cadono dall'alto (TETRIS)
  tetris: { id: "tetris", name: "Tetris", damage: 0, knockback: 0, width: 28, height: 28, color: 0x00bcd4, rarity: "rarissimo", category: "consumo", consume: { powerup: "tetris", ms: TETRIS.ms } },
  // Oggetti per categoria (Nicola, 5 novembre 2026): due per categoria, ognuno con la sua versione rara. TODO community: i nomi
  ciabatta: { id: "ciabatta", name: "Ciabatta", damage: 7, knockback: 320, width: 30, height: 12, color: 0x3b82c4, rarity: "comune", category: "lancio", throwSpec: GEAR.ciabatta },
  ciabattaMamma: { id: "ciabattaMamma", name: "Ciabatta della mamma", damage: 12, knockback: 430, width: 30, height: 12, color: 0xe85d9e, rarity: "raro", category: "lancio", rareOf: "ciabatta", throwSpec: GEAR.ciabatta, homing: true },
  petardo: { id: "petardo", name: "Petardo", damage: 0, knockback: 0, width: 14, height: 30, color: 0xd63a2f, rarity: "normale", category: "lancio", petardo: "normale" },
  petardoGrappolo: { id: "petardoGrappolo", name: "Petardo a grappolo", damage: 0, knockback: 0, width: 24, height: 30, color: 0xf08a24, rarity: "raro", category: "lancio", rareOf: "petardo", petardo: "grappolo" },
  petardino: { id: "petardino", name: "Petardino", damage: 0, knockback: 0, width: 8, height: 16, color: 0xf08a24, rarity: "mai", petardo: "mini" },
  caffe: { id: "caffe", name: "Caffè", damage: 0, knockback: 0, width: 22, height: 20, color: 0x6f4426, rarity: "comune", category: "consumo", consume: { powerup: "caffe", ms: GEAR.caffe.ms } },
  moka: { id: "moka", name: "Moka a razzo", damage: 0, knockback: 0, width: 22, height: 32, color: 0xb8bcc4, rarity: "raro", category: "consumo", rareOf: "caffe", consume: { powerup: "razzo", ms: GEAR.moka.ms } },
  brownie: { id: "brownie", name: "Brownie spaziale", damage: 0, knockback: 0, width: 24, height: 18, color: 0x5b3a24, rarity: "normale", category: "consumo", consume: { powerup: "brownie", ms: GEAR.brownie.delayMs } },
  brownieNonna: { id: "brownieNonna", name: "Brownie della nonna", damage: 0, knockback: 0, width: 28, height: 20, color: 0x7a4a2a, rarity: "raro", category: "consumo", rareOf: "brownie", consume: { powerup: "colosso", ms: GEAR.brownie.nonnaMs } },
  // Pesanti e da cavalcare (physics/ride.ts, RIDE). TODO community: i nomi
  cassa: { id: "cassa", name: "Cassa", damage: 13, knockback: 440, width: 40, height: 36, color: 0xa86b32, rarity: "normale", category: "peso", throwSpec: RIDE.heavy, crate: 1 },
  cassaOro: { id: "cassaOro", name: "Cassa d'oro", damage: 13, knockback: 440, width: 40, height: 36, color: 0xf2c230, rarity: "raro", category: "peso", rareOf: "cassa", throwSpec: RIDE.heavy, crate: 3 },
  lavatrice: { id: "lavatrice", name: "Lavatrice", damage: 16, knockback: 480, width: 42, height: 46, color: 0xe8ecef, rarity: "normale", category: "peso", throwSpec: RIDE.heavy, washer: "normale" },
  lavatriceMatta: { id: "lavatriceMatta", name: "Lavatrice impazzita", damage: 16, knockback: 480, width: 42, height: 46, color: 0xff6fb5, rarity: "raro", category: "peso", rareOf: "lavatrice", throwSpec: RIDE.heavy, washer: "matta" },
  monopattino: { id: "monopattino", name: "Monopattino", damage: 9, knockback: 400, width: 44, height: 30, color: 0x2ecc71, rarity: "normale", category: "cavalcatura", mount: "monopattino" },
  monopattinoRazzo: { id: "monopattinoRazzo", name: "Monopattino a razzo", damage: 11, knockback: 460, width: 48, height: 30, color: 0xe74c3c, rarity: "raro", category: "cavalcatura", rareOf: "monopattino", mount: "razzo" },
  carrello: { id: "carrello", name: "Carrello della spesa", damage: 10, knockback: 420, width: 50, height: 40, color: 0x95a5a6, rarity: "normale", category: "cavalcatura", mount: "carrello", seats: 1 },
  carrelloTurbo: { id: "carrelloTurbo", name: "Carrello da tre", damage: 10, knockback: 420, width: 62, height: 42, color: 0xf39c12, rarity: "raro", category: "cavalcatura", rareOf: "carrello", mount: "carrello", seats: 3 },
};

// Gli oggetti che possono cadere dal cielo (rarity "mai" no), in ordine: si scelgono nelle regole della stanza
export const DROPPABLE_ITEMS: readonly string[] = Object.keys(ITEMS).filter((k) => itemWeight(k) > 0).sort();

// Quanto spesso cade un oggetto rispetto agli altri, dalla sua classe di frequenza
export function itemWeight(kind: string): number {
  return ITEM_RARITY[ITEMS[kind].rarity];
}
