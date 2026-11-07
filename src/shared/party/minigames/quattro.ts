// Il Bonobo a Quattro (Idee pazze): tutti insieme guidano un solo bonobo gigante contro il Rivale, un bot. Ognuno ha solo
// una parte dei comandi (sinistra, destra, salto, colpi): bisogna mettersi d'accordo a voce. I lottatori di tutti
// guardano dalla tribuna in alto. Si vince o si perde insieme: KO al Rivale contro cadute del bonobo.

import { MINIGAME } from "../../constants";
import { emptyInput, type Fighter, type PhysicsContext } from "../../physics";
import type { GameEvent, InputState } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameApi, type MinigameDef } from "../minigame";

const C = MINIGAME.quattro;
const BONOBO = "bonobo-a-quattro";
const RIVAL = "rivale";
const GROUND = { x: 220, y: 560, width: 840 };
const STAND = { x: 1150, y: 200, width: 220 }; // la tribuna, fuori dal palco

// Le parti dei comandi, da dividere tra i giocatori
const PARTS: { name: string; keys: (keyof InputState)[] }[] = [
  { name: "Sinistra", keys: ["left"] },
  { name: "Destra", keys: ["right"] },
  { name: "Salto", keys: ["jump", "up", "down"] },
  { name: "Colpi", keys: ["light", "heavy", "special", "shield"] },
];

// Le parti di ognuno: con meno di quattro giocatori qualcuno ne ha due
export function partsFor(ids: string[]): Record<string, number[]> {
  const out: Record<string, number[]> = Object.fromEntries(ids.map((id) => [id, []]));
  PARTS.forEach((_, p) => ids.length > 0 && out[ids[p % ids.length]].push(p));
  return out;
}

class Quattro extends TimedGame {
  private raw = new Map<string, InputState>();
  private score = 0;
  private thinkMs = 0;
  private rivalInput = emptyInput();

  constructor(
    private ids: string[],
    private parts: Record<string, number[]>,
  ) {
    super(C.durationMs, "punti");
  }

  // I lottatori dei giocatori stanno in tribuna: i loro tasti vanno al bonobo
  mapInput(id: string, input: InputState): InputState {
    this.raw.set(id, input);
    return emptyInput();
  }

  canHit(a: Fighter, t: Fighter) {
    return (a.id === BONOBO && t.id === RIVAL) || (a.id === RIVAL && t.id === BONOBO);
  }

  protected onStart(fighters: Fighter[], _ctx: PhysicsContext, api: MinigameApi) {
    const owner = this.ids[0];
    const bonobo = owner ? api.addGhost(BONOBO, owner) : null;
    if (bonobo) {
      bonobo.name = "Il Bonobo a Quattro";
      bonobo.x = GROUND.x + 220;
      bonobo.y = GROUND.y;
      bonobo.facing = 1;
    }
    const rival = owner ? api.addGhost(RIVAL, owner) : null;
    if (rival) {
      rival.name = "Il Rivale";
      rival.characterId = "bonobot";
      rival.skinId = "";
      rival.color = 0x9aa0a8;
      rival.x = GROUND.x + GROUND.width - 220;
      rival.y = GROUND.y;
      rival.facing = -1;
    }
    this.park(fighters);
  }

  // I lottatori dei giocatori in fila sulla tribuna
  private park(fighters: Fighter[]) {
    let k = 0;
    for (const f of fighters) {
      if (!this.ids.includes(f.id)) continue;
      f.x = STAND.x + 30 + (k++ % 5) * 40;
      f.y = STAND.y;
      f.vx = 0;
      f.vy = 0;
      f.onGround = true;
      f.input = emptyInput();
    }
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    this.park(fighters);
    const bonobo = fighters.find((f) => f.id === BONOBO);
    const rival = fighters.find((f) => f.id === RIVAL);
    if (bonobo) {
      bonobo.powerup = "colosso";
      bonobo.powerupMs = 10000;
      // I tasti del bonobo: ognuno porta solo la sua parte
      const input = emptyInput();
      for (const id of this.ids) {
        const mine = this.raw.get(id);
        if (!mine) continue;
        for (const p of this.parts[id] ?? []) for (const key of PARTS[p].keys) if (mine[key]) (input as unknown as Record<string, boolean>)[key] = true;
      }
      bonobo.input = input;
    }
    if (rival && bonobo) this.driveRival(rival, bonobo, dtMs);
    for (const e of events) {
      if (e.type !== "ko") continue;
      if (e.id === RIVAL) {
        this.score += C.koPoints;
        this.text = "Il Rivale è fuori!";
      } else if (e.id === BONOBO) {
        this.score -= C.fallPoints;
        this.text = "Il bonobo è caduto!";
      }
    }
    for (const id of this.ids) this.scores[id] = this.score;
    delete this.scores[BONOBO];
    delete this.scores[RIVAL];
    this.props = bonobo && !bonobo.respawning ? [{ kind: "marker", x: Math.round(bonobo.x), y: Math.round(bonobo.y - 190), color: 0xffc928, text: "TUTTI" }] : [];
  }

  // Il Rivale: va verso il bonobo, salta se è più in alto, colpisce quando è a tiro; fuori dal palco torna al centro
  private driveRival(r: Fighter, b: Fighter, dtMs: number) {
    this.thinkMs -= dtMs;
    if (this.thinkMs > 0) {
      r.input = { ...this.rivalInput, light: false, heavy: false, jump: false };
      return;
    }
    this.thinkMs = C.rivalThinkMs;
    const input = emptyInput();
    const off = r.x < GROUND.x || r.x > GROUND.x + GROUND.width || r.y > GROUND.y + 10;
    const tx = off || b.respawning ? GROUND.x + GROUND.width / 2 : b.x;
    input.left = tx < r.x - 20;
    input.right = tx > r.x + 20;
    if (off && r.vy > 0) input.jump = true;
    if (off && r.y > GROUND.y + 60) {
      input.up = true;
      input.special = true;
    }
    if (!off && !b.respawning && Math.abs(b.x - r.x) < C.rivalReach + 40 && Math.abs(b.y - r.y) < 120) {
      input.left = b.x < r.x;
      input.right = b.x > r.x;
      if ((this.tick++ & 1) === 0) input.light = true;
      else input.heavy = true;
    }
    if (!off && b.y < r.y - 80 && r.onGround) input.jump = true;
    this.rivalInput = input;
    r.input = input;
  }
  private tick = 0;

  places(ids: string[]) {
    // Insieme: se il bonobo ha vinto primi tutti, altrimenti ultimi tutti
    const p = this.score > 0 ? 1 : ids.length;
    return Object.fromEntries(ids.filter((id) => this.ids.includes(id)).map((id) => [id, p]));
  }
}

export const quattro: MinigameDef = {
  info: {
    id: "quattro",
    title: "Il Bonobo a Quattro",
    category: "pazze",
    howTo: "Guidate tutti insieme un solo bonobo gigante contro il Rivale. Ognuno ha solo una parte dei comandi: mettetevi d'accordo! Si vince o si perde insieme.",
    keys: "Solo la tua parte (la vedi sotto): sinistra, destra, salto o colpi",
    durationSec: C.durationMs / 1000,
  },
  build(_seed, ids) {
    const parts = partsFor(ids);
    return {
      stage: arena({
        id: "quattro",
        name: "Il Bonobo a Quattro",
        solids: [
          { x: GROUND.x, y: GROUND.y, width: GROUND.width, height: 90 },
          { x: STAND.x, y: STAND.y, width: STAND.width, height: 30 },
        ],
        platforms: [{ x: 540, y: 400, width: 200 }],
        width: 1400,
        spawns: Array.from({ length: 8 }, (_, i) => ({ x: STAND.x + 30 + (i % 5) * 40, y: STAND.y })),
        respawn: { x: 640, y: 200 },
        sky: 0x4a3a2a,
        solid: 0x6a5a3a,
        edge: 0xffc928,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      roles: Object.fromEntries(ids.map((id) => [id, (parts[id] ?? []).map((p) => PARTS[p].name).join(" + ")])),
      runtime: new Quattro([...ids], parts),
    };
  },
};
