// Bonobo Party (#579): il tabellone. Un giro ad anello attorno allo schermo, con una scorciatoia che taglia nel mezzo:
// all'incrocio si sceglie se fare il giro lungo (più caselle Banana) o la scorciatoia (più Eventi). Generato da un seme,
// così il server e i test hanno lo stesso tabellone. Le coordinate vanno da 0 a 1: il client le scala sullo schermo.

import { rng } from "../stageGenerator";
import type { PartySquare, PartySquareKind } from "../types";

export const BOARD_LOOP = 28; // caselle del giro lungo
const SHORTCUT = 5; // caselle della scorciatoia
const FORK = 6; // l'incrocio: da qui si va avanti nel giro o si prende la scorciatoia
const JOIN = 20; // dove la scorciatoia rientra nel giro

// Caselle del giro: sempre almeno due botteghe, e le Bucce mai di fila
export function makeBoard(seed: number): PartySquare[] {
  const r = rng(seed);
  const squares: PartySquare[] = [];
  // Il giro: un rettangolo con gli angoli arrotondati, in senso orario dall'angolo in basso a sinistra
  for (let i = 0; i < BOARD_LOOP; i++) {
    const p = loopPoint(i / BOARD_LOOP);
    squares.push({ x: round3(p.x), y: round3(p.y), kind: "banana", next: [(i + 1) % BOARD_LOOP] });
  }
  // La scorciatoia: una linea dritta dall'incrocio a dove rientra, passando per il centro
  const a = squares[FORK];
  const b = squares[JOIN];
  for (let k = 0; k < SHORTCUT; k++) {
    const t = (k + 1) / (SHORTCUT + 1);
    const bend = Math.sin(t * Math.PI) * 0.08; // un po' curva, così non sembra un errore
    squares.push({ x: round3(a.x + (b.x - a.x) * t), y: round3(a.y + (b.y - a.y) * t - bend), kind: "evento", next: [] });
  }
  for (let k = 0; k < SHORTCUT; k++) squares[BOARD_LOOP + k].next = [k + 1 < SHORTCUT ? BOARD_LOOP + k + 1 : JOIN];
  squares[FORK].next = [FORK + 1, BOARD_LOOP];
  // I tipi del giro: partenza, due botteghe opposte, poi a caso con le proporzioni giuste
  squares[0].kind = "start";
  squares[Math.round(BOARD_LOOP * 0.25)].kind = "bottega";
  squares[Math.round(BOARD_LOOP * 0.75)].kind = "bottega";
  for (let i = 1; i < BOARD_LOOP; i++) {
    if (squares[i].kind !== "banana" || i === FORK) continue;
    const roll = r.next();
    const kind: PartySquareKind = roll < 0.24 ? "buccia" : roll < 0.4 ? "evento" : "banana";
    if (kind === "buccia" && squares[i - 1].kind === "buccia") continue;
    squares[i].kind = kind;
  }
  // Nella scorciatoia una Buccia in mezzo: è più corta, ma qualcosa costa
  squares[BOARD_LOOP + Math.floor(SHORTCUT / 2)].kind = "buccia";
  return squares;
}

// Un punto del giro, t da 0 a 1: rettangolo da (0.08, 0.14) a (0.92, 0.88) percorso in senso orario
function loopPoint(t: number): { x: number; y: number } {
  const left = 0.08;
  const right = 0.92;
  const top = 0.14;
  const bottom = 0.88;
  const w = right - left;
  const h = bottom - top;
  const per = 2 * (w + h);
  let d = t * per;
  // Si parte dall'angolo in basso a sinistra e si sale
  if (d < h) return { x: left, y: bottom - d };
  d -= h;
  if (d < w) return { x: left + d, y: top };
  d -= w;
  if (d < h) return { x: right, y: top + d };
  d -= h;
  return { x: right - d, y: bottom };
}

const round3 = (v: number) => Math.round(v * 1000) / 1000;

// Le caselle dove può stare la Corona: non la partenza, non le botteghe, non la scorciatoia (deve costare un giro)
export function crownSpots(squares: PartySquare[]): number[] {
  return squares.map((s, i) => ({ s, i })).filter(({ s, i }) => i < BOARD_LOOP && s.kind !== "start" && s.kind !== "bottega").map(({ i }) => i);
}
