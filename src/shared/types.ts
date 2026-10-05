// Messaggi scambiati tra client e server.

export interface InputState {
  left: boolean;
  right: boolean;
  jump: boolean;
  attack: boolean;
}

export interface PlayerState {
  id: string;
  name: string;
  color: number;
  x: number; // centro orizzontale
  y: number; // piedi
  vx: number;
  vy: number;
  facing: 1 | -1;
  hp: number;
  onGround: boolean;
  attacking: boolean; // il colpo è attivo in questo momento
  hitstun: boolean;
  ko: boolean;
  kos: number; // quante volte ha messo KO qualcuno
}

export interface GameSnapshot {
  t: number;
  players: PlayerState[];
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
