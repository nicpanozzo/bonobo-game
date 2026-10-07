// Messaggi scambiati tra client e server.

import type { StageSpec } from "./stages";

export interface InputState {
  left: boolean;
  right: boolean;
  up: boolean; // salto (anche doppio salto in aria)
  down: boolean; // scende dalle piattaforme sottili, caduta veloce in aria
  light: boolean; // attacco leggero
  heavy: boolean; // attacco pesante
  taunt: boolean; // provocazione (#16): per ora produce solo l'evento
  dodge: boolean; // schivata (#3): invulnerabili per un attimo, spostandosi nella direzione tenuta
  shield: boolean; // scudo (#109): tenuto a terra para i colpi e si consuma; con una direzione rotola, con su si salta fuori
}

// Le varianti direzionali (#2): su tenendo su, giù tenendo giù a terra, Air in aria; recovery: K + su in aria (#11)
export type AttackKind = "light" | "heavy" | "lightUp" | "lightDown" | "lightAir" | "heavyUp" | "heavyDown" | "heavyAir" | "recovery" | "ledgeAttack";

export interface PlayerState {
  id: string;
  name: string;
  characterId: string; // vedi src/shared/characters.ts
  color: number;
  team: number; // 0 = nessuna squadra (tutti contro tutti), 1 e 2 = squadre (#17)
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
  carrier: boolean; // porta la bandiera della sua squadra (modalità "flag", #56)
  ledge: "hang" | "climb" | "roll" | null; // appeso al bordo del palco o in risalita (#110), null altrimenti
  away: boolean; // disconnesso, posto tenuto per la riconnessione: fermo e intoccabile (#107)
  shielding: boolean; // scudo alzato (#109)
  shieldHp: number; // punti di scudo, da 0 a SHIELD.maxHp: la bolla è grande in proporzione
  stunned: boolean; // stordito dopo che lo scudo si è rotto: fermo e colpibile
}

// Un oggetto nell'arena (#17): a terra, in volo o in mano a qualcuno
export interface ItemState {
  id: number;
  kind: string; // vedi src/shared/items.ts
  x: number; // centro
  y: number; // base
  vx: number;
  vy: number;
  heldBy: string | null; // chi lo tiene in mano
  thrown: boolean; // lanciato: colpisce chi tocca
}

// Regole della partita, scelte da chi crea la stanza (#17). Default in src/shared/rules.ts
export interface MatchRules {
  mode: "ffa" | "teams" | "flag" | "race" | "training"; // tutti contro tutti, squadre, Bandiera (#56), Corsa (#57) o Allenamento (#113)
  stocks: number; // vite a testa; in Bandiera i punti per vincere; in Corsa non conta (vite infinite)
  timeLimitSec: number; // 0 = senza limite di tempo
  friendlyFire: boolean; // nelle squadre, se ci si può colpire tra compagni
}

// Cose successe tra uno snapshot e l'altro. La fisica le produce, e chi disegna,
// suona, muove la telecamera o scrive sul Discord le ascolta senza toccare la fisica.
export type GameEvent =
  | { type: "jump"; id: string; x: number; y: number; air: boolean } // air = doppio salto
  | { type: "land"; id: string; x: number; y: number }
  | { type: "attack"; id: string; kind: AttackKind } // inizio di un attacco (il colpo può andare a vuoto)
  | {
      type: "hit";
      attackerId: string;
      targetId: string;
      kind: AttackKind | "item"; // "item": un oggetto lanciato (#17), il tipo è in itemKind
      itemKind?: string;
      damage: number;
      percent: number; // percentuale del bersaglio dopo il colpo
      knockback: number; // pixel/s: utile per dosare effetti e suoni
      x: number; // punto d'impatto
      y: number;
    }
  | { type: "ko"; id: string; byId: string | null; x: number; y: number; stocksLeft: number } // uscito dall'arena
  | { type: "respawn"; id: string }
  | { type: "dodge"; id: string; x: number; y: number; air: boolean } // parte una schivata (#113)
  | { type: "taunt"; id: string }
  | { type: "flag"; scoringTeam: number; byId: string | null; team: number; carrierId: string | null } // portabandiera di "team" buttato fuori: punto a scoringTeam, la bandiera passa a carrierId
  | { type: "checkpoint"; id: string; index: number } // in Corsa: nuovo punto da cui si riparte
  | { type: "hazard"; id: string; index: number; damage: number; percent: number; knockback: number; x: number; y: number } // preso da una trappola (stage.hazards[index], #14)
  | { type: "itemSpawn"; itemId: number; kind: string; x: number; y: number } // un oggetto comincia a cadere (#17)
  | { type: "itemPick"; itemId: number; id: string } // id lo raccoglie
  | { type: "itemThrow"; itemId: number; id: string; x: number; y: number }
  | { type: "ledgeGrab"; id: string; x: number; y: number; invulnerable: boolean } // si aggrappa al bordo (#110)
  | { type: "ledgeGetup"; id: string; option: "climb" | "attack" | "jump" | "roll" | "drop" } // come lascia il bordo (#110)
  | { type: "shield"; id: string; attackerId: string; damage: number; shieldHp: number; x: number; y: number } // colpo parato (#109)
  | { type: "shieldBreak"; id: string; x: number; y: number } // lo scudo di id si è rotto
  | { type: "matchStart" }
  | { type: "away"; id: string } // id si è disconnesso: il suo posto resta tenuto per un po' (#107)
  | { type: "back"; id: string } // id è rientrato nel suo posto
  | { type: "matchEnd"; winnerId: string | null; winnerTeam: number; durationMs: number };

export interface GameSnapshot {
  t: number;
  players: PlayerState[];
  winnerId: string | null; // chi ha vinto la partita, se è finita
  timeLeftMs: number | null; // null se la partita non ha limite di tempo
  teamScores: Record<1 | 2, number> | null; // punti delle squadre in Bandiera, null nelle altre modalità
  items: ItemState[]; // oggetti nell'arena (#17)
  events: GameEvent[]; // tutto quello che è successo dallo snapshot precedente
  stageMs: number; // tempo dell'arena: da qui il client calcola dove sono ascensori e trappole (#14)
}

// Eventi Socket.IO tipizzati
export interface ServerToClient {
  // stage è l'arena intera: chi non ha il codice di src/shared (client Godot, #59) non sa rigenerare
  // le arene casuali e i percorsi della Corsa dal loro id
  // token: segreto di questo giocatore in questa stanza, mai negli snapshot; si rimanda nel join per rientrare (#107)
  // resumed: true = rientrato nel posto tenuto, con lo stesso lottatore
  // serverVersion: versione del gioco sul server (package.json), il client avvisa se è diversa dalla sua (E2)
  welcome: (data: { id: string; room: string; stageId: string; rules: MatchRules; stage: StageSpec; token: string; resumed: boolean; serverVersion: string }) => void;
  snapshot: (snap: GameSnapshot) => void;
  roomFull: () => void; // resta per i client di prima; i nuovi leggono refused
  refused: (data: Refusal) => void; // unico rifiuto con motivo: protocollo diverso, stanza piena, troppe stanze (E2, E4)
}

// Perché il server non fa entrare: outdated = protocollo diverso, full = stanza piena, limit = troppe stanze sul server
export interface Refusal {
  reason: "outdated" | "full" | "limit";
  message: string; // già pronto da mostrare a chi gioca
}

export interface ClientToServer {
  // stageId e rules contano solo per chi crea la stanza; gli altri entrano in quella che c'è
  // bot: chi crea la stanza può aggiungere un avversario del server, es. "manichino" (#20)
  // token: quello del welcome, dopo una caduta di rete; se il posto è ancora tenuto si rientra nello stesso lottatore (#107)
  // version e protocol: versione del gioco (package.json) e PROTOCOL_VERSION del client; mancano nei client di prima (E2)
  join: (data: { room: string; name: string; characterId?: string; stageId?: string; rules?: Partial<MatchRules>; bot?: string; token?: string; version?: string; protocol?: number }) => void;
  input: (input: InputState) => void;
  rematch: () => void; // a fine partita, ricomincia subito (#17)
  // Allenamento (#113): percentuale degli avversari, velocità dell'orologio (TRAINING.speeds), si ricomincia da capo.
  // Il server li accetta solo in una stanza "training" con un solo umano
  training: (data: { percent?: number; speed?: number; reset?: boolean }) => void;
}
