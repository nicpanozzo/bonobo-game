// Dojo: il tutorial delle mosse. Per ogni mossa o combo di un personaggio registra con il laboratorio delle combo
// (comboLab.ts) i tasti tick per tick che la fanno entrare su Bonobot fermo; Match li rifà al lottatore vero nella
// stanza, e il client li mostra a schermo mentre succede. Stessa arena, stessi passi: la fisica dà lo stesso risultato.

import { getCharacter } from "./characters";
import { chain, movesOf, showMove } from "./comboLab";
import { COMBO, COMBO_LAB, DOJO, FIGHTER } from "./constants";
import type { InputState } from "./types";

// I tasti di una dimostrazione, un bit ciascuno in quest'ordine (lo stesso ordine in godot/scripts/dojo.gd)
export const DEMO_KEYS = ["left", "right", "up", "down", "jump", "light", "heavy", "special", "shield", "run"] as const;

export interface DojoDemo {
  moves: string[]; // le mosse in fila (AttackKind del laboratorio)
  percent: number; // percentuale del manichino all'inizio
  gap: number; // pixel tra chi impara e il manichino all'inizio
  keys: number[] | null; // i tasti, un numero per tick (bit di DEMO_KEYS); null se il laboratorio non sa farla
  lands: boolean; // i colpi entrano sul manichino (altrimenti la mossa si fa a vuoto)
}

// Cosa si chiede al Dojo: una combo del personaggio (indice in combos) o una mossa sola
export interface DojoPick {
  combo?: number;
  move?: string;
}

export const keysMask = (keys: Partial<InputState>): number => DEMO_KEYS.reduce((m, k, i) => (keys[k] ? m | (1 << i) : m), 0);
export const maskKeys = (mask: number): Partial<InputState> => Object.fromEntries(DEMO_KEYS.map((k, i) => [k, (mask & (1 << i)) !== 0]));

// Le mosse di quello che si chiede, null se il personaggio non ce l'ha
export function dojoMoves(characterId: string, pick: DojoPick): string[] | null {
  if (pick.combo !== undefined) {
    const steps = getCharacter(characterId).combos?.[pick.combo]?.steps;
    return steps && steps.length <= COMBO.maxSteps ? steps.map((s) => s.move) : null;
  }
  if (pick.move !== undefined && movesOf(characterId).some((m) => m.id === pick.move && m.id !== "grab")) return [pick.move];
  return null;
}

const cache = new Map<string, DojoDemo>();

// La dimostrazione: la percentuale più bassa (a passi di COMBO_LAB) a cui la catena entra tutta su Bonobot fermo.
// Si calcola la prima volta che serve (pochi ms) e poi resta in memoria
export function dojoDemo(characterId: string, moves: string[]): DojoDemo {
  const key = `${characterId}:${moves.join(">")}`;
  const known = cache.get(key);
  if (known) return known;
  let demo: DojoDemo = { moves, percent: 0, gap: FIGHTER.width + 10, keys: null, lands: false };
  // Una mossa sola entra a 0% o mai: niente giro delle percentuali (ogni prova a vuoto costa al server)
  const top = moves.length === 1 ? 0 : COMBO_LAB.percentMax;
  for (let p = 0; p <= top; p += COMBO_LAB.percentStep) {
    const r = chain(characterId, moves, p, true);
    if (r.hits < moves.length || !r.world || r.world.keys.length > DOJO.maxDemoTicks) continue;
    demo = { moves, percent: p, gap: r.world.gap, keys: r.world.keys.map(keysMask), lands: true };
    break;
  }
  if (!demo.keys && moves.length === 1) {
    const w = showMove(characterId, moves[0]); // a vuoto: si vedono almeno i tasti e la mossa
    if (w) demo = { moves, percent: 0, gap: w.gap, keys: w.keys.map(keysMask), lands: false };
  }
  cache.set(key, demo);
  return demo;
}
