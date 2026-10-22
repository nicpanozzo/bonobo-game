// Si arriva a ogni piattaforma? Lo stesso controllo vale per i test delle arene e per l'editor sul sito (E12),
// che ne legge i numeri da godot/data/game.json (stageCheck) e rifà il conto in site/editor/arena.js.

import { FIGHTER, STAGE_CHECK } from "./constants";
import { stageAt } from "./physics/timed";
import type { Rect, StageSpec, ThinPlatform } from "./stages";

// Un salto sale di v²/2g pixel; con il doppio salto si arriva alla somma dei due
export const JUMP_HEIGHT = (FIGHTER.jumpSpeed * FIGHTER.jumpSpeed) / (2 * FIGHTER.gravity);
export const DOUBLE_JUMP_HEIGHT = JUMP_HEIGHT + (FIGHTER.doubleJumpSpeed * FIGHTER.doubleJumpSpeed) / (2 * FIGHTER.gravity);
export const SIDE_REACH = STAGE_CHECK.sideReach;

// Una piattaforma si raggiunge da una superficie più bassa vicina con un salto,
// o da una superficie proprio sotto con il doppio salto
// heightScale: per i personaggi con salto o gravità diversi (E11) l'altezza è jump² / gravity volte quella di base
export function reachable(stage: { solids: Rect[]; platforms: ThinPlatform[] }, p: ThinPlatform, heightScale = 1): boolean {
  // Una scala (#246) si prende dal punto più basso, e ci si arriva anche camminando da una superficie alla stessa altezza
  const py = Math.max(p.y, p.y2 ?? p.y);
  return [...stage.solids, ...stage.platforms].some((s) => {
    if (s.y < py || (s.y === py && p.y2 === undefined)) return false;
    const gap = Math.max(0, s.x - (p.x + p.width), p.x - (s.x + s.width));
    const rise = s.y - py;
    return (gap <= SIDE_REACH && rise <= JUMP_HEIGHT * heightScale) || (gap === 0 && rise <= DOUBLE_JUMP_HEIGHT * heightScale * 0.9);
  });
}

// Arene che cambiano nel tempo (#433): si guarda all'inizio di ogni fase e a ogni bordo delle finestre dei blocchi
// e delle piattaforme, cioè ogni volta che cambia cosa c'è. Senza fasi né pezzi a tempo basta l'istante 0
export function checkTimes(stage: StageSpec): number[] {
  const times = [0, ...(stage.phases ?? []).map((p) => p.startMs)];
  for (const piece of [...stage.solids, ...stage.platforms]) for (const [from, to] of piece.on ?? []) times.push(from, to);
  return [...new Set(times)].filter((t) => t >= 0).sort((a, b) => a - b);
}

// Le piattaforme che in qualche istante ci sono ma non si raggiungono con i pezzi presenti in quel momento
export function timedReachProblems(stage: StageSpec, heightScale = 1): string[] {
  const out: string[] = [];
  // Con un premio (forLeader) si controlla l'arena con ognuna delle squadre in testa, e con nessuna
  const leaders = [0, ...new Set([...stage.solids, ...stage.platforms].flatMap((p) => (p.forLeader ? [p.forLeader] : [])))];
  for (const t of checkTimes(stage)) {
    for (const leader of leaders) {
      const now = stageAt(stage, t, leader);
      for (const p of now.platforms) if (!reachable(now, p, heightScale)) out.push(`a ${t} ms${leader ? ` (premio squadra ${leader})` : ""}: piattaforma a ${p.x},${p.y} irraggiungibile`);
    }
  }
  return out;
}

// I numeri che servono all'editor per rifare il conto
export const stageCheckData = () => ({ jumpHeight: JUMP_HEIGHT, doubleJumpHeight: DOUBLE_JUMP_HEIGHT, sideReach: SIDE_REACH });
