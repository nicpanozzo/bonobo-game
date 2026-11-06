// Gara di Provocazioni (Ritmo): l'annunciatore chiama una sequenza (salto, leggero, pesante, provocazione), una mossa
// alla volta; al VIA bisogna rifarla uguale, in tempo. Chi sbaglia una mossa è fuori dal giro. A ogni giro la sequenza
// si allunga di uno. Le mosse sono quelle di ogni personaggio: niente animazioni nuove, nessuno può colpire nessuno.

import { MINIGAME } from "../../constants";
import { emptyInput, type Fighter, type PhysicsContext } from "../../physics";
import { rng } from "../../stageGenerator";
import type { GameEvent, InputState } from "../../types";
import { arena } from "../arena";
import { TimedGame, type MinigameDef } from "../minigame";

const C = MINIGAME.provocazioni;
const MOVES = ["salto", "leggero", "pesante", "provocazione"] as const;
type Move = (typeof MOVES)[number];
const SHOUT: Record<Move, string> = { salto: "SALTO!", leggero: "LEGGERO!", pesante: "PESANTE!", provocazione: "PROVOCA!" };

// La mossa che un evento vuol dire, o null se non conta
export function moveOf(e: GameEvent): { id: string; move: Move } | null {
  if (e.type === "jump") return { id: e.id, move: "salto" };
  if (e.type === "taunt") return { id: e.id, move: "provocazione" };
  if (e.type === "attack" && e.kind.startsWith("light")) return { id: e.id, move: "leggero" };
  if (e.type === "attack" && (e.kind.startsWith("heavy") || e.kind === "dashAttack")) return { id: e.id, move: "pesante" };
  return null;
}

class Provocazioni extends TimedGame {
  private seq: Move[] = [];
  private phase: "show" | "go" | "pause" = "pause";
  private phaseMs = C.pauseMs;
  private progress = new Map<string, number>(); // quante mosse giuste ha fatto nel giro
  private failed = new Set<string>();
  private random: () => number;
  private botMs = new Map<string, number>();

  constructor(seed: number) {
    super(C.durationMs, "punti");
    this.random = rng(seed).next;
  }

  canHit() {
    return false;
  }

  private newRound() {
    const len = Math.min(C.maxLen, this.seq.length === 0 ? C.startLen : this.seq.length + 1);
    this.seq = Array.from({ length: len }, () => MOVES[Math.floor(this.random() * MOVES.length)]);
    this.phase = "show";
    this.phaseMs = len * C.showMs;
    this.progress.clear();
    this.failed.clear();
  }

  protected onStep(fighters: Fighter[], _ctx: PhysicsContext, dtMs: number, events: readonly GameEvent[]) {
    this.phaseMs -= dtMs;
    if (this.phase === "pause" && this.phaseMs <= 0) this.newRound();
    else if (this.phase === "show" && this.phaseMs <= 0) {
      this.phase = "go";
      this.phaseMs = this.seq.length * C.stepMs + C.graceMs;
    } else if (this.phase === "go") {
      for (const e of events) {
        const m = moveOf(e);
        if (!m || this.failed.has(m.id)) continue;
        const at = this.progress.get(m.id) ?? 0;
        if (at >= this.seq.length) continue;
        if (this.seq[at] !== m.move) {
          this.failed.add(m.id);
          continue;
        }
        this.progress.set(m.id, at + 1);
        // Finita giusta: un punto per mossa, e un premio a chi finisce per primo
        if (at + 1 === this.seq.length) {
          const first = ![...this.progress].some(([id, n]) => id !== m.id && n >= this.seq.length);
          this.scores[m.id] = (this.scores[m.id] ?? 0) + this.seq.length + (first ? 2 : 0);
        }
      }
      const everyone = fighters.every((f) => this.failed.has(f.id) || (this.progress.get(f.id) ?? 0) >= this.seq.length);
      if (this.phaseMs <= 0 || everyone) {
        this.phase = "pause";
        this.phaseMs = C.pauseMs;
      }
    }
    this.out = new Set(this.phase === "go" ? this.failed : []);
    // Cosa si vede: nella mostra la mossa di adesso in grande, al VIA la sequenza intera
    if (this.phase === "show") {
      const i = Math.min(this.seq.length - 1, Math.floor((this.seq.length * C.showMs - this.phaseMs) / C.showMs));
      this.text = `Ripeti dopo di me (${i + 1}/${this.seq.length})`;
      this.props = [{ kind: "sign", x: 640, y: 260, color: 0xffc928, text: SHOUT[this.seq[i]] }];
    } else if (this.phase === "go") {
      this.text = `VAI! ${this.seq.map((m) => SHOUT[m].replace("!", "")).join(" · ")}`;
      this.props = fighters
        .filter((f) => !f.respawning)
        .map((f) => {
          const n = this.progress.get(f.id) ?? 0;
          const done = n >= this.seq.length;
          return { kind: "marker", x: Math.round(f.x), y: Math.round(f.y - 120), color: this.failed.has(f.id) ? 0xff4560 : done ? 0x5ef0a0 : 0xffffff, text: this.failed.has(f.id) ? "FUORI" : done ? "FATTO" : `${n}/${this.seq.length}` };
        });
    } else {
      this.text = this.seq.length === 0 ? "Ascolta l'annunciatore..." : "Prossimo giro: una mossa in più!";
      this.props = [];
    }
  }

  // Il bot rifà la sequenza con calma, e ogni tanto sbaglia
  botInput(f: Fighter): InputState | null {
    if (this.phase !== "go" || this.failed.has(f.id)) return emptyInput();
    const at = this.progress.get(f.id) ?? 0;
    if (at >= this.seq.length) return emptyInput();
    const wait = (this.botMs.get(f.id) ?? C.botStepMs) - 1000 / 60;
    this.botMs.set(f.id, wait);
    if (wait > 0 || !f.onGround || f.attack) return emptyInput();
    this.botMs.set(f.id, C.botStepMs);
    const move = this.random() < C.botMissChance ? MOVES[Math.floor(this.random() * MOVES.length)] : this.seq[at];
    return { ...emptyInput(), jump: move === "salto", light: move === "leggero", heavy: move === "pesante", taunt: move === "provocazione" };
  }
}

export const provocazioni: MinigameDef = {
  info: {
    id: "provocazioni",
    title: "Gara di Provocazioni",
    category: "ritmo",
    howTo: "L'annunciatore chiama una sequenza di mosse. Al VIA rifalla uguale: salto, leggero, pesante, provocazione. Chi sbaglia è fuori dal giro; a ogni giro una mossa in più.",
    keys: "Salto, Leggero, Pesante e Provocazione (il tasto della provocazione)",
    durationSec: C.durationMs / 1000,
  },
  build(seed) {
    return {
      stage: arena({
        id: "provocazioni",
        name: "Gara di Provocazioni",
        solids: [{ x: 180, y: 570, width: 920, height: 90 }],
        sky: 0x3a1a2a,
        solid: 0x5a2a3a,
        edge: 0xff4560,
      }),
      rules: { mode: "ffa", stocks: 3 },
      unlimitedStocks: true,
      runtime: new Provocazioni(seed),
    };
  },
};
