// Si arriva a ogni piattaforma? Lo stesso controllo vale per i test delle arene e per l'editor sul sito (E12),
// che ne legge i numeri da godot/data/game.json (stageCheck) e rifà il conto in site/editor/arena.js.

import { FIGHTER, STAGE_CHECK } from "./constants";
import type { Rect, ThinPlatform } from "./stages";

// Un salto sale di v²/2g pixel; con il doppio salto si arriva alla somma dei due
export const JUMP_HEIGHT = (FIGHTER.jumpSpeed * FIGHTER.jumpSpeed) / (2 * FIGHTER.gravity);
export const DOUBLE_JUMP_HEIGHT = JUMP_HEIGHT + (FIGHTER.doubleJumpSpeed * FIGHTER.doubleJumpSpeed) / (2 * FIGHTER.gravity);
export const SIDE_REACH = STAGE_CHECK.sideReach;

// Una piattaforma si raggiunge da una superficie più bassa vicina con un salto,
// o da una superficie proprio sotto con il doppio salto
// heightScale: per i personaggi con salto o gravità diversi (E11) l'altezza è jump² / gravity volte quella di base
export function reachable(stage: { solids: Rect[]; platforms: ThinPlatform[] }, p: ThinPlatform, heightScale = 1): boolean {
  return [...stage.solids, ...stage.platforms].some((s) => {
    if (s.y <= p.y) return false;
    const gap = Math.max(0, s.x - (p.x + p.width), p.x - (s.x + s.width));
    const rise = s.y - p.y;
    return (gap <= SIDE_REACH && rise <= JUMP_HEIGHT * heightScale) || (gap === 0 && rise <= DOUBLE_JUMP_HEIGHT * heightScale * 0.9);
  });
}

// I numeri che servono all'editor per rifare il conto
export const stageCheckData = () => ({ jumpHeight: JUMP_HEIGHT, doubleJumpHeight: DOUBLE_JUMP_HEIGHT, sideReach: SIDE_REACH });
