// Tutorial a tappe (E15, #113): ogni tappa si completa con un evento della fisica fatto da chi gioca.
// Sono dati: scripts/export-godot.ts li copia in game.json e godot/scripts/tutorial.gd li mostra.
// Si gioca in una stanza "training" sull'arena "palestra" con il bot "sparring".
// TODO community: testi con i tormentoni del canale (#16)

import type { GameEvent, InputState } from "./types";

export interface Lesson {
  id: string;
  title: string;
  text: string;
  actions: (keyof InputState)[]; // tasti da mostrare, nel dispositivo in uso
  event: GameEvent["type"]; // l'evento che completa la tappa
  who: "id" | "attackerId" | "byId"; // il campo dell'evento che deve essere il proprio id
  match?: Record<string, string | number | boolean>; // altri campi che devono valere così
}

export const TUTORIAL_STAGE_ID = "palestra";
export const TUTORIAL_BOT = "sparring";

export const LESSONS: Lesson[] = [
  { id: "salto", title: "Muoviti e salta", text: "Corri a destra e a sinistra, poi salta.", actions: ["left", "right", "jump"], event: "jump", who: "id", match: { air: false } },
  { id: "doppio", title: "Doppio salto", text: "In aria puoi saltare una seconda volta.", actions: ["jump"], event: "jump", who: "id", match: { air: true } },
  { id: "leggero", title: "Attacco leggero", text: "Veloce e debole: fai un attacco leggero.", actions: ["light"], event: "attack", who: "id", match: { kind: "light" } },
  { id: "pesante", title: "Attacco pesante", text: "Lento ma forte: fai un attacco pesante.", actions: ["heavy"], event: "attack", who: "id", match: { kind: "heavy" } },
  { id: "su", title: "Attacco in su", text: "Tieni su mentre attacchi per colpire sopra la testa.", actions: ["up", "light"], event: "attack", who: "id", match: { kind: "lightUp" } },
  { id: "colpo", title: "Colpisci lo sparring", text: "Avvicinati al compagno di allenamento e colpiscilo.", actions: ["light", "heavy"], event: "hit", who: "attackerId" },
  { id: "schivata", title: "Schivata", text: "Per un attimo nessuno ti può colpire.", actions: ["dodge"], event: "dodge", who: "id" },
  { id: "scudo", title: "Scudo", text: "Tieni lo scudo quando lo sparring attacca: para il colpo.", actions: ["shield"], event: "shield", who: "id" },
  { id: "recupero", title: "Recupero", text: "In aria, attacco leggero tenendo su: ti riporta verso l'alto.", actions: ["up", "light"], event: "attack", who: "id", match: { kind: "recovery" } },
  { id: "bordo", title: "Aggrappati al bordo", text: "Cadi oltre il bordo del palco e torna verso lo spigolo: ti ci aggrappi.", actions: ["left", "right"], event: "ledgeGrab", who: "id" },
  { id: "fuori", title: "Buttalo fuori", text: "Più la percentuale è alta più si vola: lancia lo sparring fuori dall'arena.", actions: ["heavy"], event: "ko", who: "byId" },
];

// La tappa è fatta da questo evento? Solo se l'ha fatto chi gioca (myId) e i campi corrispondono
export function lessonDone(lesson: Lesson, e: GameEvent, myId: string): boolean {
  if (e.type !== lesson.event) return false;
  const fields = e as unknown as Record<string, unknown>; // ogni tipo di evento ha campi suoi: si leggono per nome
  if (fields[lesson.who] !== myId) return false;
  return Object.entries(lesson.match ?? {}).every(([k, v]) => fields[k] === v);
}
