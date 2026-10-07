// Sfide con medaglie (E15 passo 3, #113): dati, come le tappe del tutorial.
// scripts/export-godot.ts le copia in game.json e godot/scripts/challenge_run.gd le gioca:
// una palestra tutta propria ("training") col bot giusto, la percentuale di partenza data
// coi comandi dell'allenamento e il tempo letto da stageMs degli snapshot, non dall'orologio del client.
// La medaglia è solo per chi gioca: il server non ne sa niente, non decide niente.
// TODO community: nomi e frasi delle sfide coi tormentoni del canale (#16)

import type { GameEvent } from "./types";

export type ChallengeGoal =
  | "koTime" // secondi per buttare fuori il bot: meno è meglio
  | "juggle" // colpi di fila prima che il bersaglio torni a terra (palleggio)
  | "damage" // percentuale fatta in tutto
  | "survive"; // secondi prima di essere buttati fuori

export interface Challenge {
  id: string;
  title: string;
  text: string;
  stage: string; // arena (stages.ts)
  bot: "manichino" | "sparring" | "facile" | "semplice" | "difficile";
  botPercent: number; // percentuale del bot alla partenza
  goal: ChallengeGoal;
  limitSec: number; // il tentativo finisce qui (in koTime senza KO non c'è medaglia)
  medals: [number, number, number]; // soglie di bronzo, argento e oro
}

export const MEDALS = ["", "Bronzo", "Argento", "Oro"];

export const CHALLENGES: Challenge[] = [
  { id: "primo-ko", title: "Primo KO", text: "Il manichino parte da 0%: buttalo fuori il prima possibile.", stage: "palco", bot: "manichino", botPercent: 0, goal: "koTime", limitSec: 60, medals: [12, 7, 5] },
  { id: "colpo-di-grazia", title: "Colpo di grazia", text: "Il manichino è già al 150%: un colpo pesante ben dato basta.", stage: "palestra", bot: "manichino", botPercent: 150, goal: "koTime", limitSec: 20, medals: [5, 3, 2] },
  { id: "palleggio", title: "Palleggio", text: "Lancia in alto il manichino e colpiscilo di fila prima che tocchi terra.", stage: "palestra", bot: "manichino", botPercent: 0, goal: "juggle", limitSec: 30, medals: [3, 5, 7] },
  { id: "mitraglia", title: "Mitraglia", text: "Più danno possibile al manichino in 15 secondi.", stage: "palestra", bot: "manichino", botPercent: 0, goal: "damage", limitSec: 15, medals: [60, 85, 100] },
  { id: "sparring", title: "Contro lo sparring", text: "Lo sparring risponde: buttalo fuori partendo dal 50%.", stage: "palestra", bot: "sparring", botPercent: 50, goal: "koTime", limitSec: 60, medals: [12, 7, 4] },
  { id: "resisti", title: "Resisti", text: "Il bot difficile ti dà la caccia: resta in piedi 60 secondi.", stage: "palco", bot: "difficile", botPercent: 0, goal: "survive", limitSec: 60, medals: [20, 40, 60] },
];

// Meno è meglio solo per il tempo del KO
export const lowerIsBetter = (goal: ChallengeGoal) => goal === "koTime";

// 0 nessuna, 1 bronzo, 2 argento, 3 oro
export function medalFor(c: Challenge, score: number | null): number {
  if (score === null) return 0;
  let medal = 0;
  c.medals.forEach((t, i) => {
    if (lowerIsBetter(c.goal) ? score <= t : score >= t) medal = i + 1;
  });
  return medal;
}

// Un tentativo, dagli eventi e dal tempo dell'arena. Lo stesso conto lo fa challenge_run.gd:
// qui serve ai test e a provare che le soglie si raggiungono.
export class ChallengeRun {
  score: number | null = null; // null finché in koTime non c'è il KO
  done = false;
  private startMs: number | null = null;
  private hits = 0; // palleggio in corso
  private juggled = ""; // chi stiamo palleggiando

  constructor(
    readonly challenge: Challenge,
    readonly myId: string,
  ) {
    if (challenge.goal !== "koTime") this.score = 0;
  }

  // Secondi dall'inizio del tentativo (il primo snapshot)
  elapsed(stageMs: number): number {
    return this.startMs === null ? 0 : (stageMs - this.startMs) / 1000;
  }

  onEvent(e: GameEvent, stageMs: number): void {
    if (this.done) return;
    this.startMs ??= stageMs;
    const c = this.challenge;
    const t = Math.min(this.elapsed(stageMs), c.limitSec);
    if (c.goal === "koTime" && e.type === "ko" && e.byId === this.myId && e.id !== this.myId) this.finish(round1(t));
    if (c.goal === "survive" && e.type === "ko" && e.id === this.myId) this.finish(round1(t));
    if (e.type === "hit" && e.attackerId === this.myId) {
      if (c.goal === "damage") this.score = (this.score ?? 0) + e.damage;
      if (c.goal === "juggle") {
        if (e.targetId !== this.juggled) this.hits = 0;
        this.juggled = e.targetId;
        this.hits++;
        this.score = Math.max(this.score ?? 0, this.hits);
        if (this.score >= c.medals[2]) this.finish(this.score); // oro: inutile aspettare la fine
      }
    }
  }

  // A ogni snapshot: il tempo che passa e se il palleggiato è ancora in gioco (in aria o stordito).
  // Tornato a terra e ripreso, il palleggio ricomincia da zero
  onTick(stageMs: number, inPlay: (id: string) => boolean): void {
    if (this.done) return;
    this.startMs ??= stageMs;
    if (this.juggled !== "" && !inPlay(this.juggled)) {
      this.hits = 0;
      this.juggled = "";
    }
    const c = this.challenge;
    if (this.elapsed(stageMs) >= c.limitSec) this.finish(c.goal === "survive" ? c.limitSec : c.goal === "damage" ? Math.round(this.score ?? 0) : this.score);
  }

  get medal(): number {
    return this.done ? medalFor(this.challenge, this.score) : 0;
  }

  private finish(score: number | null): void {
    this.score = score;
    this.done = true;
  }
}

const round1 = (s: number) => Math.round(s * 10) / 10;
