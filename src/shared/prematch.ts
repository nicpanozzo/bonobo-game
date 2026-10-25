// Pre-partita: l'attesa nella stanza finché tutti sono pronti, poi la presentazione e il conto alla rovescia.
// Solo la macchina a stati, senza lottatori: match.ts decide cosa vuol dire per la fisica.
import { PREMATCH } from "./constants";
import type { PrematchState } from "./types";

export type PrematchStep = "begin" | "go" | null;

export class Prematch {
  phase: PrematchState["phase"] | null = "waiting";
  leftMs = 0; // in "starting": ms al VIA
  private waitedMs = 0; // in "waiting": da quanto ci sono almeno minFighters lottatori
  private ready = new Set<string>();

  setReady(id: string, ready: boolean) {
    if (ready) this.ready.add(id);
    else this.ready.delete(id);
  }

  forget(id: string) {
    this.ready.delete(id);
  }

  // Una nuova partita dopo la prima (rivincita, fine pausa): niente attesa né presentazione, solo 3, 2, 1
  countdown() {
    this.phase = "starting";
    this.leftMs = PREMATCH.countdownMs;
  }

  // Un passo: "begin" quando i lottatori vanno messi al loro posto, "go" al VIA.
  // waitingFor: i lottatori che devono dire Pronto (chi è caduto dalla rete non conta)
  step(dtMs: number, fighters: number, waitingFor: string[]): PrematchStep {
    if (this.phase === "starting") {
      this.leftMs -= dtMs;
      if (this.leftMs > 0) return null;
      this.phase = null;
      this.leftMs = 0;
      return "go";
    }
    if (this.phase !== "waiting") return null;
    if (fighters < PREMATCH.minFighters) {
      this.waitedMs = 0;
      return null;
    }
    this.waitedMs += dtMs;
    if (!waitingFor.every((id) => this.ready.has(id)) && this.waitedMs < PREMATCH.autoStartMs) return null;
    this.phase = "starting";
    this.leftMs = PREMATCH.introMs + PREMATCH.countdownMs;
    return "begin";
  }

  state(ids: string[]): PrematchState | undefined {
    if (!this.phase) return undefined;
    return {
      phase: this.phase,
      leftMs: Math.max(0, Math.round(this.leftMs)),
      ready: ids.filter((id) => this.ready.has(id)),
      autoStartMs: this.phase === "waiting" && ids.length >= PREMATCH.minFighters ? Math.max(0, Math.round(PREMATCH.autoStartMs - this.waitedMs)) : null,
    };
  }
}
