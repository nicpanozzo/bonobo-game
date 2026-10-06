import type { GameEvent, GameSnapshot, MatchRules } from "../../shared/types";

// Quello che il server dice entrando nella stanza
export interface MatchInfo {
  myId: string;
  room: string;
  stageId: string;
  rules: MatchRules;
}

// Un pezzo della scena di gioco (personaggi, HUD, effetti, telecamera, audio...).
// GameScene li chiama tutti allo stesso modo: ognuno vive nel suo file e
// reagisce agli eventi di gioco senza sapere degli altri.
export interface RenderModule {
  onWelcome?(info: MatchInfo): void;
  onSnapshot?(snap: GameSnapshot): void;
  onEvent?(event: GameEvent): void;
  update?(time: number, delta: number): void;
}
