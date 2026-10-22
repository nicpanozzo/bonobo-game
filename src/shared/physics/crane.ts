// La gru delle postazioni (#433): un pezzo del Tetris appeso sopra un tratto dell'arena. Chi la usa lo sposta con destra e
// sinistra, lo gira con attacco leggero o su e lo lascia cadere con attacco pesante (salto per uscire, come le altre).
// Il pezzo lasciato è un normale pezzo del Tetris (arcade.ts: cade, fa male, si posa), ma si ferma sul ripiano `landY` e i suoi
// blocchi restano fino alla fine della partita (al massimo STATION.gruMaxBlocks per gru): le piattaforme per la zuffa.

import { STATION, TETRIS } from "../constants";
import type { Station } from "../stages";
import { arcadeWorld, pieceCells, TETROMINOES } from "./arcade";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";

const C = TETRIS.cellPx;
const KINDS = Object.keys(TETROMINOES);

// Il pezzo appeso: forma, colonna del quadretto centrale e quarti di giro; repeatMs per lo spostamento tenuto
export interface Held {
  kind: string;
  col: number;
  rot: number;
  repeatMs: number;
}

// Il pezzo sta tutto dentro il tratto della gru
function inRange(s: Station, kind: string, col: number, rot: number): boolean {
  const xs = pieceCells(kind, col, 0, rot).map(([x]) => x);
  return Math.min(...xs) >= (s.fromX ?? 0) && Math.max(...xs) + C <= (s.toX ?? 0);
}

// L'altezza del quadretto centrale del pezzo appeso, perché il suo fondo sia a dropY
const hangY = (s: Station, h: Held) => (s.dropY ?? 0) - Math.max(...pieceCells(h.kind, h.col, 0, h.rot).map(([, y]) => y + C));

// I quadretti del pezzo appeso
export const hangCells = (s: Station, h: Held) => pieceCells(h.kind, h.col, hangY(s, h), h.rot);

// Un pezzo nuovo (la forma la sceglie il caso dell'arena, sempre uguale a parità di partita), il più vicino al mezzo del tratto
export function newHeld(s: Station, ctx: PhysicsContext): Held | null {
  const kind = KINDS[Math.floor(arcadeWorld(ctx).random() * KINDS.length)];
  const mid = ((s.fromX ?? 0) + (s.toX ?? 0)) / 2 / C;
  const first = Math.floor((s.fromX ?? 0) / C) - 1;
  const cols = Array.from({ length: Math.ceil(((s.toX ?? 0) - (s.fromX ?? 0)) / C) + 4 }, (_, i) => first + i).sort((a, b) => Math.abs(a - mid) - Math.abs(b - mid));
  const col = cols.find((c) => inRange(s, kind, c, 0));
  return col === undefined ? null : { kind, col, rot: 0, repeatMs: 0 };
}

function craneEvent(phase: "move" | "rotate" | "drop", f: Fighter, s: Station, h: Held, ctx: PhysicsContext) {
  const [x, y] = hangCells(s, h)[0];
  ctx.events.push({ type: "tetris", phase, id: f.id, x: x + C / 2, y: y + C / 2 });
}

// I tasti di chi usa la gru. Torna true se il pezzo è stato lasciato cadere: è già tra i pezzi del Tetris
export function steerCrane(f: Fighter, s: Station, i: number, h: Held | null, dtMs: number, ctx: PhysicsContext): boolean {
  if (!h) {
    consume(f, "light", "heavy", "up"); // senza pezzo le pressioni non restano in coda
    return false;
  }
  const dir = f.input.left === f.input.right ? 0 : f.input.left ? -1 : 1;
  const fresh = (pressed(f, "left") && dir < 0) || (pressed(f, "right") && dir > 0);
  h.repeatMs = dir === 0 || fresh ? 0 : h.repeatMs - dtMs;
  if (dir !== 0 && h.repeatMs <= 0) {
    if (inRange(s, h.kind, h.col + dir, h.rot)) {
      h.col += dir;
      craneEvent("move", f, s, h, ctx);
    }
    h.repeatMs = STATION.gruMoveMs;
  }
  if (pressed(f, "light") || pressed(f, "up")) {
    // Se girato non sta nel tratto, prova una colonna più in là (come i "calci" del Tetris)
    const kick = [0, -1, 1].find((k) => inRange(s, h.kind, h.col + k, h.rot + 1));
    if (kick !== undefined) {
      h.col += kick;
      h.rot = (h.rot + 1) % 4;
      craneEvent("rotate", f, s, h, ctx);
    }
    consume(f, "light", "up");
  }
  if (!pressed(f, "heavy")) return false;
  consume(f, "heavy");
  const world = arcadeWorld(ctx);
  world.pieces.push({ id: world.nextId++, ownerId: f.id, kind: h.kind, col: h.col, y: hangY(s, h), rot: h.rot, drop: true, soft: false, repeatMs: 0, hit: [], crane: { slot: i, landY: s.landY ?? 0 } });
  craneEvent("drop", f, s, h, ctx);
  return true;
}
