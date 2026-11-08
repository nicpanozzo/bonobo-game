// Il Burattinaio (Uno contro tutti): uno sta sulla passerella in alto e lascia cadere cose: mattoni col Leggero, petardi
// col Pesante (scoppiano poco dopo essere atterrati), bucce di banana con lo Speciale. Gli altri, giù, resistono: un
// punto ogni tanto per chi non viene preso. Il Burattinaio fa punti a ogni colpo andato a segno.

import { MINIGAME } from "../../constants";
import { emptyInput, type Fighter, type PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent, InputState, PartyProp } from "../../types";
import { arena, surfaceBelow } from "../arena";
import { bump, TimedGame, touches, type MinigameDef } from "../minigame";

const C = MINIGAME.burattinaio;
const FLOOR = 580;
const BRIDGE = 110; // la passerella del Burattinaio

type Kind = "brick" | "boom" | "peel";

interface Drop {
  kind: Kind;
  x: number;
  y: number;
  vy: number;
  landed: boolean;
  ms: number; // da quanto è atterrato
}

class Burattinaio extends TimedGame {
  private drops: Drop[] = [];
  private cooldownMs = 0;
  private prev: InputState = emptyInput();
  private queued: Kind | null = null;
  private safeMs = new Map<string, number>();
  private flash: PartyProp[] = [];
  private flashMs = 0;

  constructor(private master: string) {
    super(C.durationMs, "punti");
  }

  // I tasti d'attacco del Burattinaio non fanno mosse: lanciano roba
  mapInput(id: string, input: InputState): InputState {
    if (id !== this.master) return input;
    if (input.light && !this.prev.light) this.queued = "brick";
    if (input.heavy && !this.prev.heavy) this.queued = "boom";
    if (input.special && !this.prev.special) this.queued = "peel";
    this.prev = { ...input };
    return { ...emptyInput(), left: input.left, right: input.right, run: input.run };
  }

  // Giù ci si spinge pure; il Burattinaio non lo tocca nessuno
  canHit(a: Fighter, t: Fighter) {
    return a.id !== this.master && t.id !== this.master;
  }

  private add(id: string, n: number) {
    this.scores[id] = (this.scores[id] ?? 0) + n;
  }

  protected onStep(fighters: Fighter[], ctx: PhysicsContext, dtMs: number, _events: readonly GameEvent[]) {
    const master = fighters.find((f) => f.id === this.master);
    // Il Burattinaio non scende mai dalla passerella: se ne cade (o rientra dopo un KO) ci torna sopra
    if (master && !master.respawning) {
      if (master.y > BRIDGE + 40 || master.x < 220 || master.x > 1060) {
        master.x = Math.max(220, Math.min(1060, master.x));
        master.y = BRIDGE;
        master.vx = 0;
        master.vy = 0;
        master.onGround = true;
      }
    }
    this.cooldownMs = Math.max(0, this.cooldownMs - dtMs);
    if (master && this.queued && this.cooldownMs <= 0 && !master.respawning) {
      this.drops.push({ kind: this.queued, x: master.x, y: BRIDGE + 20, vy: 0, landed: false, ms: 0 });
      this.cooldownMs = C.cooldownMs;
    }
    this.queued = null;
    const dt = dtMs / 1000;
    const victims = fighters.filter((f) => f.id !== this.master && !f.respawning && !f.eliminated);
    for (const d of this.drops) {
      if (!d.landed) {
        d.vy += MINIGAME.fallGravity * dt;
        const ny = d.y + d.vy * dt;
        const s = d.y > BRIDGE + 10 ? surfaceBelow(ctx.stage, d.x, d.y) : null;
        if (s !== null && ny >= s) {
          d.y = s;
          d.landed = true;
        } else d.y = ny;
        // Un mattone in volo che prende qualcuno
        if (d.kind === "brick" && !d.landed)
          for (const f of victims)
            if (touches(f, d.x, d.y, 26)) {
              bump(f, (f.x < d.x ? -1 : 1) * 320, -520);
              f.percent = Math.min(999, f.percent + 8);
              this.add(this.master, C.brickPoints);
              this.safeMs.set(f.id, 0);
              d.ms = 99999; // il mattone si rompe addosso
            }
      } else d.ms += dtMs;
      // Il petardo scoppia poco dopo essere atterrato: vola via chi è vicino
      if (d.kind === "boom" && d.landed && d.ms >= C.fuseMs && d.ms < 99999) {
        for (const f of victims) {
          if (Math.hypot(f.x - d.x, f.y - 30 - d.y) > C.boomR) continue;
          bump(f, (f.x < d.x ? -1 : 1) * 600, -720);
          f.percent = Math.min(999, f.percent + 12);
          this.add(this.master, C.boomPoints);
          this.safeMs.set(f.id, 0);
        }
        this.flash = [{ kind: "zone", x: Math.round(d.x), y: Math.round(d.y), w: C.boomR * 2, h: 60, color: 0xff8a2a }];
        this.flashMs = 250;
        d.ms = 99999;
      }
      // La buccia: chi ci passa sopra da terra scivola
      if (d.kind === "peel" && d.landed && d.ms < C.peelMs)
        for (const f of victims)
          if (f.onGround && Math.abs(f.x - d.x) < 24 && Math.abs(f.y - d.y) < 10) {
            bump(f, f.facing * 260, -380);
            this.add(this.master, C.peelPoints);
            this.safeMs.set(f.id, 0);
            d.ms = 99999;
          }
    }
    this.drops = this.drops.filter((d) => d.ms < (d.kind === "peel" ? C.peelMs : d.kind === "brick" ? 900 : C.fuseMs + 1) && d.y < ctx.stage.blastZone.bottom);
    // Chi non viene preso fa un punto ogni tanto
    for (const f of victims) {
      const ms = (this.safeMs.get(f.id) ?? 0) + dtMs;
      if (ms >= C.safeEveryMs) {
        this.add(f.id, 1);
        this.safeMs.set(f.id, ms - C.safeEveryMs);
      } else this.safeMs.set(f.id, ms);
    }
    this.flashMs -= dtMs;
    if (this.flashMs <= 0) this.flash = [];
    this.props = [
      ...this.drops.map((d): PartyProp => (d.kind === "brick" ? { kind: "brick", x: Math.round(d.x), y: Math.round(d.y - 14), w: 56, h: 26, color: 0xc0583a } : d.kind === "boom" ? { kind: "ball", x: Math.round(d.x), y: Math.round(d.y - 10), w: 10, color: d.landed && Math.floor(d.ms / 100) % 2 ? 0xffffff : 0xff4560 } : { kind: "banana", x: Math.round(d.x), y: Math.round(d.y) })),
      ...this.flash,
      ...(master && !master.respawning ? [{ kind: "marker", x: Math.round(master.x), y: Math.round(master.y - 120), color: 0xb48cff, text: "BURATTINAIO" }] : []),
    ];
  }

  // Il bot Burattinaio va sopra a chi è giù e lascia cadere qualcosa a turno; chi è giù scappa da sotto di lui
  botInput(f: Fighter, fighters: readonly Fighter[]): InputState | null {
    if (f.id !== this.master) return null;
    const target = fighters.find((o) => o.id !== this.master && !o.respawning);
    if (!target) return emptyInput();
    const input = emptyInput();
    input.left = target.x < f.x - 20;
    input.right = target.x > f.x + 20;
    if (Math.abs(target.x - f.x) < 60 && this.cooldownMs <= 0 && !this.prev.light && !this.prev.heavy && !this.prev.special) {
      const pick = this.drops.length % 3;
      input.light = pick === 0;
      input.heavy = pick === 1;
      input.special = pick === 2;
    }
    return input;
  }

  botGoal(f: Fighter, fighters: readonly Fighter[]) {
    if (f.id === this.master) return null;
    const m = fighters.find((o) => o.id === this.master);
    if (!m) return null;
    return { x: m.x < 640 ? Math.min(1060, m.x + 360) : Math.max(220, m.x - 360), y: FLOOR };
  }
}

export const burattinaio: MinigameDef = {
  info: {
    id: "burattinaio",
    title: "Il Burattinaio",
    category: "unoContro",
    howTo: "Uno sta sulla passerella in alto e lascia cadere mattoni (Leggero), petardi (Pesante) e bucce (Speciale). Gli altri resistono: fanno punti finché non vengono presi.",
    keys: "Giù: muoviti e scappa. Burattinaio: muoviti sulla passerella, Leggero, Pesante e Speciale per lanciare",
    durationSec: C.durationMs / 1000,
  },
  minPlayers: 2,
  build(seed, ids) {
    const master = ids[Math.floor(rng(seed).next() * ids.length)] ?? "";
    const spawns = Array.from({ length: 8 }, (_, i) => ({ x: 300 + (i % 4) * 230, y: FLOOR }));
    // Il Burattinaio parte sulla passerella: la sua partenza è quella col suo posto nella stanza
    const masterSlot = ids.indexOf(master);
    if (masterSlot >= 0) spawns[masterSlot] = { x: 640, y: BRIDGE };
    return {
      stage: arena({
        id: "burattinaio",
        name: "Il Burattinaio",
        solids: [
          { x: 180, y: FLOOR, width: 920, height: 90 },
          { x: 200, y: BRIDGE, width: 880, height: 18 },
        ],
        platforms: [
          { x: 260, y: 440, width: 180 },
          { x: 840, y: 440, width: 180 },
        ],
        spawns,
        respawn: { x: 640, y: 300 },
        sky: 0x2a2a3a,
        solid: 0x4a4a5a,
        edge: 0xb48cff,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      roles: { [master]: "Il Burattinaio" },
      runtime: new Burattinaio(master),
    };
  },
};
