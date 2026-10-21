// I power-up arcade (#427). Tetris: chi lo prende si assenta, fermo e intoccabile, e con i suoi tasti guida
// un pezzo che cade dall'alto dell'arena; il pezzo colpisce chi tocca e, posato, diventa blocchi solidi.
// Pac-Man: si va dritti nelle quattro direzioni attraverso tutto, si rientra dall'altro lato e si mangia chi si tocca.
//   playTetris()  dentro stepFighter, al posto dei controlli: compare, sposta e ruota il pezzo di chi gioca
//   playPacman()  dentro stepFighter, al posto di controlli e gravità
//   stepArcade()  alla fine di stepWorld: caduta, colpi, posa e durata dei blocchi; chi viene mangiato
//   arcadeSolids() i blocchi posati come blocchi pieni per collideWithStage

import { characterStats } from "../characters";
import { FIGHTER, HITSTOP, HITSTUN_PER_KNOCKBACK, PACMAN, TETRIS, WORLD } from "../constants";
import type { Rect } from "../stages";
import { rng } from "../stageGenerator";
import type { TetrisState } from "../types";
import { bodyBox } from "./attacks";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { clearStun, hitShield } from "./shield";
import { platformSurfaceY } from "./stage";
import { chargeFromHit } from "./supreme";

// Le sette forme, in quadretti attorno al centro di rotazione [0, 0] (y verso il basso)
export const TETROMINOES: Record<string, [number, number][]> = {
  I: [[-1, 0], [0, 0], [1, 0], [2, 0]],
  O: [[0, 0], [1, 0], [0, 1], [1, 1]],
  T: [[-1, 0], [0, 0], [1, 0], [0, -1]],
  L: [[-1, 0], [0, 0], [1, 0], [1, -1]],
  J: [[-1, 0], [0, 0], [1, 0], [-1, -1]],
  S: [[-1, 0], [0, 0], [0, -1], [1, -1]],
  Z: [[-1, -1], [0, -1], [0, 0], [1, 0]],
};
const KINDS = Object.keys(TETROMINOES);

export interface Piece {
  id: number;
  ownerId: string;
  kind: string;
  col: number; // colonna del quadretto centrale
  y: number; // bordo alto del quadretto centrale, pixel
  rot: number; // quarti di giro in senso orario
  drop: boolean; // K: cade di colpo fino a posarsi
  soft: boolean; // giù tenuto in questo tick
  repeatMs: number; // ms al prossimo spostamento tenendo destra o sinistra
  hit: string[]; // chi ha già preso questo pezzo
}

export interface Block {
  x: number;
  y: number;
  kind: string;
  lifeMs: number;
}

export interface ArcadeWorld {
  pieces: Piece[];
  blocks: Block[];
  nextId: number;
  random: () => number;
  eaten?: Record<string, number>; // Pac-Man: "chi/chi è stato mangiato" -> tempo dell'arena del boccone
}

const C = TETRIS.cellPx;
const COLS = Math.floor(WORLD.width / C);

function arcade(ctx: PhysicsContext): ArcadeWorld {
  // Il caso con un seme fisso: la partita resta ripetibile come per gli oggetti
  ctx.arcade ??= { pieces: [], blocks: [], nextId: 1, random: rng(427).next };
  return ctx.arcade;
}

// Le celle del pezzo in pixel (angolo in alto a sinistra), girato di rot quarti in senso orario
export function pieceCells(kind: string, col: number, y: number, rot: number): [number, number][] {
  return TETROMINOES[kind].map(([dx, dy]) => {
    let [x, z] = [dx, dy];
    if (kind !== "O") for (let r = 0; r < ((rot % 4) + 4) % 4; r++) [x, z] = [-z, x];
    return [(col + x) * C, y + z * C];
  });
}

const cellsOf = (p: Piece) => pieceCells(p.kind, p.col, p.y, p.rot);
const boxOverlap = (ax: number, ay: number, aw: number, ah: number, b: { x: number; y: number; width: number; height: number }) =>
  ax < b.x + b.width - 1 && ax + aw > b.x + 1 && ay < b.y + b.height - 1 && ay + ah > b.y + 1;

// Un pezzo sta dentro le colonne e non entra in un blocco pieno o in un blocco posato
function fits(cells: [number, number][], ctx: PhysicsContext): boolean {
  const solids = arcadeSolids(ctx);
  return cells.every(([x, y]) => x >= 0 && x + C <= COLS * C && !solids.some((s) => boxOverlap(x, y, C, C, s)));
}

// Il pezzo di chi gioca: ne compare uno se non ce l'ha, poi i suoi tasti lo guidano
export function playTetris(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const world = arcade(ctx);
  let p = world.pieces.find((q) => q.ownerId === f.id && !q.drop);
  if (!p) {
    const kind = KINDS[Math.floor(world.random() * KINDS.length)];
    const col = Math.max(1, Math.min(COLS - 3, Math.round(f.x / C)));
    p = { id: world.nextId++, ownerId: f.id, kind, col, y: TETRIS.spawnY, rot: 0, drop: false, soft: false, repeatMs: 0, hit: [] };
    world.pieces.push(p);
    tetrisEvent("spawn", p, ctx);
    return;
  }
  const dir = f.input.left === f.input.right ? 0 : f.input.left ? -1 : 1;
  const fresh = (pressed(f, "left") && dir < 0) || (pressed(f, "right") && dir > 0);
  p.repeatMs = dir === 0 || fresh ? 0 : p.repeatMs - dtMs;
  if (dir !== 0 && p.repeatMs <= 0) {
    if (fits(pieceCells(p.kind, p.col + dir, p.y, p.rot), ctx)) {
      p.col += dir;
      tetrisEvent("move", p, ctx);
    }
    p.repeatMs = TETRIS.repeatMs;
  }
  if (pressed(f, "up") || pressed(f, "jump") || pressed(f, "light")) {
    // Se girato non entra, prova una colonna più in là (come i "calci" del Tetris vero)
    const kick = [0, -1, 1].find((k) => fits(pieceCells(p!.kind, p!.col + k, p!.y, p!.rot + 1), ctx));
    if (kick !== undefined) {
      p.col += kick;
      p.rot = (p.rot + 1) % 4;
      tetrisEvent("rotate", p, ctx);
    }
    consume(f, "up", "jump", "light"); // col buffer la stessa pressione girerebbe il pezzo per più tick
  }
  p.soft = f.input.down;
  if (pressed(f, "heavy")) {
    p.drop = true; // da qui il pezzo è libero: al prossimo tick ne compare un altro
    consume(f, "heavy");
    tetrisEvent("drop", p, ctx);
  }
}

function tetrisEvent(phase: "spawn" | "move" | "rotate" | "drop" | "land", p: Piece, ctx: PhysicsContext) {
  ctx.events.push({ type: "tetris", phase, id: p.ownerId, x: p.col * C + C / 2, y: Math.round(p.y + C / 2) });
}

// Quanto può scendere una cella prima di toccare qualcosa sotto: pavimenti, piattaforme sottili, blocchi posati
function room(x: number, bottom: number, fall: number, ctx: PhysicsContext, blocks: Block[]): number {
  const cx = x + C / 2;
  let best = fall;
  const tops: number[] = [];
  for (const s of ctx.stage.solids) if (cx > s.x && cx < s.x + s.width) tops.push(s.y);
  for (const p of ctx.stage.platforms) if (cx > p.x && cx < p.x + p.width) tops.push(platformSurfaceY(p, cx));
  for (const b of blocks) if (cx > b.x && cx < b.x + C) tops.push(b.y);
  for (const top of tops) if (bottom <= top + 0.5 && bottom + best > top) best = Math.max(0, top - bottom);
  return best;
}

// Le frecce di Pac-Man: su vale anche col salto
const PAC_KEYS: [keyof Fighter["input"], number, number][] = [["left", -1, 0], ["right", 1, 0], ["up", 0, -1], ["jump", 0, -1], ["down", 0, 1]];

// Da Pac-Man si va sempre dritti: una freccia appena premuta cambia direzione. Si passa attraverso tutto
// e chi esce da un lato dello schermo rientra dall'altro
export function playPacman(f: Fighter, dtMs: number): void {
  const turn = PAC_KEYS.find(([k]) => f.input[k] && !f.prevInput[k]);
  if (turn) f.pacDir = { x: turn[1], y: turn[2] };
  const dir = f.pacDir ?? { x: f.facing, y: 0 };
  f.vx = dir.x * PACMAN.speedPxS;
  f.vy = dir.y * PACMAN.speedPxS;
  if (dir.x !== 0) f.facing = dir.x as 1 | -1;
  f.x = wrap(f.x + (f.vx * dtMs) / 1000, WORLD.width);
  f.y = wrap(f.y + (f.vy * dtMs) / 1000, WORLD.height);
  f.onGround = false;
  f.riding = -1;
}

const wrap = (v: number, size: number) => ((v % size) + size) % size;

// Chi entra nella bocca di Pac-Man viene mangiato: vola via, e per un po' non si rimangia
function eatWithPacman(fighters: Fighter[], ctx: PhysicsContext) {
  const pacmen = fighters.filter((f) => f.powerup === "pacman" && !f.eliminated && !f.respawning);
  if (pacmen.length === 0) return;
  const world = arcade(ctx);
  const eaten = (world.eaten ??= {});
  const now = ctx.timeMs ?? 0;
  for (const pac of pacmen) {
    const cx = pac.x;
    const cy = pac.y - FIGHTER.height / 2;
    for (const target of fighters) {
      if (target === pac || target.eliminated || target.respawning || target.invulnerable) continue;
      if (ctx.canHit && !ctx.canHit(pac, target)) continue;
      const key = `${pac.id}/${target.id}`;
      if (now - (eaten[key] ?? -Infinity) < PACMAN.eatAgainMs) continue;
      const body = bodyBox(target);
      const nx = Math.max(body.x, Math.min(cx, body.x + body.w));
      const ny = Math.max(body.y, Math.min(cy, body.y + body.h));
      if ((nx - cx) ** 2 + (ny - cy) ** 2 > PACMAN.radiusPx ** 2) continue;
      eaten[key] = now;
      const dir = pac.vx !== 0 ? (Math.sign(pac.vx) as 1 | -1) : target.x >= pac.x ? 1 : -1;
      arcadeHit(target, pac, PACMAN.damage, PACMAN.knockback, PACMAN.knockbackGrowth, PACMAN.angleDeg, dir, nx, ny, "pacman", ctx);
    }
  }
}

// Caduta, colpi e posa di tutti i pezzi; i blocchi posati invecchiano. Pac-Man mangia
export function stepArcade(fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  eatWithPacman(fighters, ctx);
  const world = ctx.arcade;
  if (!world) return;
  for (const b of world.blocks) b.lifeMs -= dtMs;
  world.blocks = world.blocks.filter((b) => b.lifeMs > 0);
  for (const p of world.pieces) {
    const speed = p.drop ? TETRIS.dropPxS : p.soft ? TETRIS.softPxS : TETRIS.fallPxS;
    const fall = (speed * dtMs) / 1000;
    const cells = cellsOf(p);
    const step = Math.min(...cells.map(([x, y]) => room(x, y + C, fall, ctx, world.blocks)));
    p.y += step;
    hitWithPiece(p, fighters, ctx);
    if (step < fall) {
      // Posato: diventa blocchi solidi
      for (const [x, y] of cellsOf(p)) world.blocks.push({ x, y: Math.round(y), kind: p.kind, lifeMs: TETRIS.blockMs });
      world.blocks.splice(0, Math.max(0, world.blocks.length - TETRIS.maxBlocks));
      tetrisEvent("land", p, ctx);
      p.y = Infinity; // via al filtro qui sotto
    }
  }
  world.pieces = world.pieces.filter((p) => p.y < ctx.stage.blastZone.bottom);
}

// Chi tocca un pezzo che cade vola via, una volta per pezzo
function hitWithPiece(p: Piece, fighters: Fighter[], ctx: PhysicsContext) {
  const owner = fighters.find((f) => f.id === p.ownerId);
  const cells = cellsOf(p);
  for (const target of fighters) {
    if (target.id === p.ownerId || target.eliminated || target.respawning || target.invulnerable || p.hit.includes(target.id)) continue;
    if (owner && ctx.canHit && !ctx.canHit(owner, target)) continue;
    const body = bodyBox(target);
    const cell = cells.find(([x, y]) => x < body.x + body.w && x + C > body.x && y < body.y + body.h && y + C > body.y);
    if (!cell) continue;
    p.hit.push(target.id);
    const dir = target.x >= cell[0] + C / 2 ? 1 : -1;
    arcadeHit(target, owner ?? null, TETRIS.damage, TETRIS.knockback, TETRIS.knockbackGrowth, TETRIS.angleDeg, dir, cell[0] + C / 2, cell[1] + C / 2, "tetris", ctx);
  }
}

// Un colpo di un power-up arcade: come un oggetto lanciato, lo scudo lo para
export function arcadeHit(target: Fighter, by: Fighter | null, damage: number, base: number, growth: number, angleDeg: number, dir: 1 | -1, x: number, y: number, kind: string, ctx: PhysicsContext): void {
  const id = by?.id ?? "";
  if (target.shielding) {
    hitShield(target, id, damage, dir, Math.round(x), Math.round(y), ctx);
    return;
  }
  target.percent = Math.min(999, target.percent + damage);
  chargeFromHit(by ?? undefined, target, damage);
  const knockback = (base + growth * target.percent) / characterStats(target.characterId).weight;
  const angle = (angleDeg * Math.PI) / 180;
  target.vx = dir * Math.cos(angle) * knockback;
  target.vy = -Math.sin(angle) * knockback;
  target.onGround = false;
  target.hitstunTimer = knockback * HITSTUN_PER_KNOCKBACK;
  target.attack = null;
  target.attackActive = false;
  target.facing = (-dir) as 1 | -1;
  target.lastHitById = by?.id ?? null;
  clearStun(target);
  target.hitstopTimer = Math.max(target.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * damage));
  ctx.events.push({ type: "hit", attackerId: id, targetId: target.id, kind: "item", itemKind: kind, damage, percent: target.percent, knockback: Math.round(knockback), x: Math.round(x), y: Math.round(y) });
}

// I blocchi posati come blocchi pieni: ci si sta sopra e ci si sbatte contro
export function arcadeSolids(ctx: PhysicsContext): Rect[] {
  return (ctx.arcade?.blocks ?? []).map((b) => ({ x: b.x, y: b.y, width: C, height: C }));
}

// Prendere un power-up arcade ferma quello che si stava facendo. Pac-Man parte verso dove si guarda
export function startArcade(f: Fighter): void {
  f.attack = null;
  f.attackActive = false;
  f.vx = 0;
  f.vy = 0;
  f.pacDir = { x: f.facing, y: 0 };
}

// Si torna in partita: dove si era, coi salti e un attimo intoccabili
export function endArcade(f: Fighter): void {
  f.vx = 0;
  f.vy = 0;
  f.jumpsLeft = FIGHTER.maxJumps;
  f.recoveryUsed = false;
  f.helpless = false;
  f.invulnerableTimer = Math.max(f.invulnerableTimer, TETRIS.returnInvulnerableMs);
}

export const isArcade = (f: Fighter) => f.powerup === "tetris" || f.powerup === "pacman";

// Quello che va nello snapshot, solo quando c'è qualcosa
export function tetrisState(ctx: PhysicsContext): TetrisState | undefined {
  const world = ctx.arcade;
  if (!world || (world.pieces.length === 0 && world.blocks.length === 0)) return undefined;
  return {
    pieces: world.pieces.map((p) => ({ id: p.id, ownerId: p.ownerId, kind: p.kind, cells: cellsOf(p).map(([x, y]) => [x, Math.round(y)] as [number, number]) })),
    blocks: world.blocks.map((b) => ({ x: b.x, y: b.y, kind: b.kind, ms: Math.ceil(b.lifeMs / 100) * 100 })),
  };
}
