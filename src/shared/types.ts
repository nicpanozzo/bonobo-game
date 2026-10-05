// Messaggi scambiati tra client e server.

export interface InputState {
  left: boolean;
  right: boolean;
  up: boolean; // salto (anche doppio salto in aria)
  down: boolean; // scende dalle piattaforme sottili, caduta veloce in aria
  light: boolean; // attacco leggero
  heavy: boolean; // attacco pesante
}

export type AttackKind = "light" | "heavy";

export interface PlayerState {
  id: string;
  name: string;
  color: number;
  x: number; // centro orizzontale
  y: number; // piedi
  vx: number;
  vy: number;
  facing: 1 | -1;
  percent: number; // danno accumulato: più è alto, più si vola lontano
  stocks: number; // vite rimaste
  onGround: boolean;
  attack: AttackKind | null; // attacco in corso
  attackActive: boolean; // la hitbox può colpire in questo momento
  hitstun: boolean;
  respawning: boolean; // ha appena perso una vita ed è fuori gioco
  invulnerable: boolean;
  eliminated: boolean; // vite finite
}

export interface GameSnapshot {
  t: number;
  players: PlayerState[];
  winnerId: string | null; // chi ha vinto la partita, se è finita
}

// Eventi Socket.IO tipizzati
export interface ServerToClient {
  welcome: (data: { id: string; room: string }) => void;
  snapshot: (snap: GameSnapshot) => void;
  roomFull: () => void;
}

export interface ClientToServer {
  join: (data: { room: string; name: string }) => void;
  input: (input: InputState) => void;
}
