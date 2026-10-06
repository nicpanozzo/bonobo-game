// Avversari del server (#20). Un bot è un giocatore come gli altri: a ogni tick scrive
// il suo InputState e passa dalla stessa fisica, non sposta mai il personaggio da sé.

import { ATTACKS, BOT, BOT_LEVELS, FIGHTER, TICK_RATE } from "../shared/constants";
import type { Match } from "../shared/match";
import { emptyInput, type Fighter } from "../shared/physics";
import type { StageSpec } from "../shared/stages";
import type { InputState } from "../shared/types";
import type { RoomHooks } from "./Room";

// manichino: sta fermo e incassa, per provare colpi e combo (passo 1)
// semplice: insegue, attacca e torna sul palco quando viene lanciato fuori (passo 2)
// facile e difficile: lo stesso bot, più lento o più svelto, e il difficile schiva (passo 3)
type BotLevel = keyof typeof BOT_LEVELS;
export type BotKind = "manichino" | BotLevel;

// TODO community: nomi nostri per i bot (es. un membro che si offre volontario)
const BOT_NAMES: Record<BotKind, string> = {
  manichino: "Manichino",
  facile: "Bot facile",
  semplice: "Bot",
  difficile: "Bot difficile",
};

// Il parametro arriva dalla rete: si accettano solo i tipi conosciuti
export function parseBotKind(value: unknown): BotKind | null {
  return typeof value === "string" && Object.hasOwn(BOT_NAMES, value) ? (value as BotKind) : null;
}

const reactionTicks = (level: BotLevel) => Math.max(1, Math.round((BOT_LEVELS[level].reactionMs * TICK_RATE) / 1000));

// Quello che un bot si ricorda tra un tick e l'altro
interface BotMemory {
  kind: BotKind;
  ticks: number;
  attacks: number; // attacchi fatti, per alternare leggero e pesante
  hold: InputState; // tasti di movimento tenuti fino alla prossima decisione
  last: InputState; // tasti del tick precedente: un tasto "premuto" deve prima essere rilasciato
}

// I bot di una stanza. hooks va passato alla Room, add() li fa entrare in partita.
export class Bots {
  private bots = new Map<string, BotMemory>();
  private count = 0;

  readonly hooks: RoomHooks = {
    onTick: (room) => this.tick(room.match),
  };

  add(match: Match, kind: BotKind): string | null {
    if (match.isFull) return null;
    const id = `bot-${kind}-${++this.count}`;
    match.addPlayer(id, BOT_NAMES[kind]);
    this.bots.set(id, { kind, ticks: 0, attacks: 0, hold: emptyInput(), last: emptyInput() });
    return id;
  }

  // Prima di ogni passo di fisica: ogni bot decide i suoi tasti
  tick(match: Match): void {
    const players = match.players;
    for (const f of players) {
      const mem = this.bots.get(f.id);
      if (!mem) continue;
      const input = mem.kind === "manichino" ? emptyInput() : decideSimple(f, players, match.stage, mem, mem.kind);
      mem.last = input;
      match.setInput(f.id, input);
    }
  }
}

// Il più vicino tra quelli che si possono colpire (niente compagni di squadra)
function nearestTarget(self: Fighter, players: readonly Fighter[]): Fighter | null {
  let best: Fighter | null = null;
  for (const p of players) {
    if (p === self || p.eliminated || p.respawning) continue;
    if (self.team && p.team === self.team) continue;
    if (!best || Math.abs(p.x - self.x) + Math.abs(p.y - self.y) < Math.abs(best.x - self.x) + Math.abs(best.y - self.y)) best = p;
  }
  return best;
}

// Il blocco pieno sotto x, se c'è
function groundUnder(stage: StageSpec, x: number) {
  return stage.solids.find((s) => x >= s.x && x <= s.x + s.width);
}

// Il punto del palco più vicino a x, dove tornare dopo un lancio
function nearestSolidX(stage: StageSpec, x: number): number {
  let best = stage.respawn.x;
  for (const s of stage.solids) {
    const cx = Math.max(s.x + BOT.edgeMargin, Math.min(s.x + s.width - BOT.edgeMargin, x));
    if (Math.abs(cx - x) < Math.abs(best - x)) best = cx;
  }
  return best;
}

function decideSimple(self: Fighter, players: readonly Fighter[], stage: StageSpec, mem: BotMemory, level: BotLevel): InputState {
  const skill = BOT_LEVELS[level];
  const input = emptyInput();
  if (self.eliminated || self.respawning) return input;
  // Un tasto conta come premuto solo se al tick prima era rilasciato
  const tap = (key: keyof InputState) => {
    if (!mem.last[key]) input[key] = true;
  };

  // Fuori dal palco: si torna verso il blocco più vicino, salti e recupero quando si sta cadendo
  const ground = groundUnder(stage, self.x);
  if (!self.onGround && (!ground || self.y > ground.y)) {
    const homeX = nearestSolidX(stage, self.x);
    input.left = homeX < self.x;
    input.right = homeX > self.x;
    if (self.vy > 0 && !self.hitstun) {
      if (self.jumpsLeft > 0) tap("up");
      else if (!self.recoveryUsed && !mem.last.heavy) {
        input.up = true;
        input.heavy = true;
      }
    }
    return input;
  }

  // Sul palco: si rivede la scelta ogni tot tick (il tempo di reazione), nel frattempo si tengono i tasti di movimento
  mem.ticks++;
  if (mem.ticks % reactionTicks(level) !== 0) {
    input.left = mem.hold.left;
    input.right = mem.hold.right;
    return input;
  }

  const target = nearestTarget(self, players);
  mem.hold = emptyInput();
  if (!target) return input;

  const dx = target.x - self.x;
  const dy = target.y - self.y;
  const spec = ATTACKS.heavy;
  const reach = FIGHTER.width / 2 + spec.range;
  const facingTarget = Math.sign(dx) === self.facing || dx === 0;

  // Il difficile schiva un attacco pesante che sta caricando a portata, allontanandosi
  const threat = target.attack?.startsWith("heavy") && !target.attackActive && Math.abs(dx) <= reach + FIGHTER.width;
  if (skill.dodges && threat && self.onGround && self.dodgeCooldown === 0) {
    tap("dodge");
    input.left = dx > 0;
    input.right = dx < 0;
    return input;
  }

  if (Math.abs(dx) <= reach && Math.abs(dy) < FIGHTER.height) {
    if (!facingTarget) {
      // Prima ci si gira verso il bersaglio, l'attacco al giro dopo
      mem.hold.left = dx < 0;
      mem.hold.right = dx > 0;
    } else {
      mem.attacks++;
      tap(mem.attacks % skill.heavyEvery === 0 ? "heavy" : "light");
    }
  } else {
    // Si insegue, ma senza buttarsi giù dal palco dietro a chi sta volando via
    const wantX = nearestSolidX(stage, target.x);
    if (Math.abs(wantX - self.x) > 8) {
      mem.hold.left = wantX < self.x;
      mem.hold.right = wantX > self.x;
    }
  }
  if (-dy > BOT.jumpAtHeight && Math.abs(dx) < 200 && self.onGround) tap("up");

  input.left = mem.hold.left;
  input.right = mem.hold.right;
  return input;
}
