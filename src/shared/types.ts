// Messaggi scambiati tra client e server.

import type { StageSpec } from "./stages";

export interface InputState {
  left: boolean;
  right: boolean;
  up: boolean; // direzione su: attacchi e lancio verso l'alto, recupero, oggetti in su
  jump: boolean; // salto (anche doppio salto in aria). Separato da up (E10): col pad un attacco in su non fa saltare
  down: boolean; // scende dalle piattaforme sottili, caduta veloce in aria
  light: boolean; // attacco leggero
  heavy: boolean; // attacco pesante
  taunt: boolean; // provocazione (#16): per ora produce solo l'evento
  dodge: boolean; // schivata (#3): invulnerabili per un attimo, spostandosi nella direzione tenuta
  shield: boolean; // scudo (#109): tenuto a terra para i colpi e si consuma; con una direzione rotola, con su si salta fuori
  special: boolean; // mossa speciale (E10): da fermi, con una direzione o con giù, diversa per ogni personaggio
  supreme: boolean; // suprema (#101): parte solo con la barra piena (PlayerState.supreme)
  run?: boolean; // corsa: tenuto con una direzione a terra si scatta e si corre (DASH). I client vecchi non lo mandano
  seq?: number; // E17: numero crescente del client (il suo tick), torna in PlayerState.predict. I client vecchi non lo mandano
}

// Le varianti direzionali (#2): su tenendo su, giù tenendo giù a terra, Air in aria; recovery: K + su in aria (#11)
// grab: scudo + leggero (#109); throw*: i lanci dalla presa nella direzione tenuta
export type AttackKind =
  | "light"
  | "heavy"
  | "lightUp"
  | "lightDown"
  | "lightAir"
  | "heavyUp"
  | "heavyDown"
  | "heavyAir"
  | "recovery"
  | "ledgeAttack"
  | "dashAttack" // attacco in corsa: il pesante mentre si corre, scivolando in avanti
  | "grab"
  | "throwForward"
  | "throwBack"
  | "throwUp"
  | "throwDown"
  | "supreme" // suprema (#101): con la barra piena, poi la barra torna a 0
  | SpecialKind;

// Le mosse speciali (E10): i numeri dipendono dal personaggio (specialsFor in characters.ts)
export type SpecialKind = "specialNeutral" | "specialSide" | "specialDown";

export interface PlayerState {
  id: string;
  name: string;
  characterId: string; // vedi src/shared/characters.ts
  skinId?: string; // skin scelta (#339): cambia solo il disegno; manca = aspetto base
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
  grabbedBy: string | null; // id di chi lo tiene con la presa (#109), null se libero
  dashing: boolean; // scatta o corre dopo un doppio tocco (#199)
  charge: number; // carica della speciale in corso (E10), da 0 a 1; 0 se non si carica
  supreme: number; // barra della suprema (#101), da 0 a SUPREME.max: piena, il tasto suprema la lancia
  powerup: string | null; // potenziamento in corso da un oggetto consumato (#231), null se nessuno
  powerupMs: number; // ms che restano del potenziamento, 0 se nessuno
  predict?: PredictionState; // E17: solo per chi manda InputState.seq
  companion?: CompanionState; // il compagno che lo segue (#369, il beagle di Lampione); manca se non ne ha
}

// Il compagno di un lottatore (#369): dove è e dove guarda
export interface CompanionState {
  x: number; // centro
  y: number; // piedi
  facing: 1 | -1;
  onGround: boolean;
}

// Quello che serve al client per rigiocare il proprio movimento da questo snapshot (E17):
// quale input il server sta usando, da quanti tick, e i timer del movimento che non viaggiano altrove
export interface PredictionState {
  seq: number; // InputState.seq dell'input in uso
  ticks: number; // tick di fisica giocati con quell'input
  jumps: number; // salti rimasti
  coyote: number; // ms in cui il salto vale ancora da terra
  rising: boolean; // si sta salendo per un salto: lasciando il tasto si accorcia
  drop: number; // ms in cui si attraversano le piattaforme sottili
  jumpBuffer: number; // ms in cui una pressione del salto vale ancora (E6)
  dash: number; // ms di scatto rimasti (#199)
  tapDir: number; // direzione dell'ultimo tocco, per il doppio tocco dello scatto
  tapTimer: number; // ms entro cui un secondo tocco fa scattare
  tapHold: number; // ms per cui si è tenuto l'ultimo tocco
  dodge: number; // ms di schivata in corso (#3)
  dodgeCooldown: number; // ms prima della prossima schivata
  airDodge: boolean; // la schivata in aria è già stata usata
  dodgeBuffer: number; // ms in cui una pressione della schivata vale ancora (E6)
  attackTimer: number; // ms dall'inizio dell'attacco in corso (PlayerState.attack)
  cooldown: number; // ms prima che possa partire un altro attacco
  hitstop: number; // ms di fermo dopo un colpo andato a segno (#15)
  recoveryUsed: boolean; // il recupero è già stato usato in questo salto (#11)
  helpless: boolean; // dopo il recupero niente attacchi fino all'atterraggio
  lightBuffer: number; // ms in cui una pressione del leggero vale ancora (E6)
  heavyBuffer: number; // ms in cui una pressione del pesante vale ancora (E6)
}

// Un proiettile in volo (E10): lo tira una speciale e colpisce come un attacco
export interface ProjectileState {
  id: number;
  ownerId: string; // chi l'ha tirato (o chi l'ha rimandato indietro col contrattacco)
  kind: SpecialKind; // quale speciale l'ha tirato
  characterId: string; // il personaggio di chi l'ha tirato: da qui il client prende forma e colore
  x: number; // centro
  y: number;
  vx: number;
  vy: number;
}

// Una pozza di merda dell'IRA di Lendmar (#13): a terra, chi ci sta sopra scivola (non chi l'ha tirata)
export interface PuddleState {
  id: number;
  ownerId: string;
  x: number; // centro
  y: number; // la superficie su cui è
  width: number;
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
  owner?: string; // il funghetto piantato (#302): chi l'ha piantato, solo lui lo vede bene
  load?: number; // il bong in carica (#302), da 0 a 1; assente se non lo si carica
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
  | { type: "powerUp"; itemId: number; id: string; kind: string; x: number; y: number } // id consuma l'oggetto e si potenzia (#231)
  | { type: "powerEnd"; id: string; kind: string } // il potenziamento di id finisce
  // Il bong (#302): load = comincia a caricarlo, smoke = soffia la nuvola (centro x,y, verso dir, danno), stun = troppo fatto, crolla
  | { type: "bong"; phase: "load" | "smoke" | "stun"; id: string; x: number; y: number; dir?: 1 | -1; damage?: number }
  | { type: "ledgeGrab"; id: string; x: number; y: number; invulnerable: boolean } // si aggrappa al bordo (#110)
  | { type: "ledgeGetup"; id: string; option: "climb" | "attack" | "jump" | "roll" | "drop" } // come lascia il bordo (#110)
  | { type: "shield"; id: string; attackerId: string; damage: number; shieldHp: number; x: number; y: number } // colpo parato (#109)
  | { type: "shieldBreak"; id: string; x: number; y: number } // lo scudo di id si è rotto
  | { type: "grab"; id: string; targetId: string; x: number; y: number } // id afferra targetId (#109)
  | { type: "grabRelease"; id: string; targetId: string } // la presa finisce senza lancio: targetId si è liberato
  | { type: "counter"; id: string; attackerId: string; x: number; y: number } // id para il colpo di attackerId col contrattacco (E10) e risponde
  | { type: "projectile"; id: string; projectileId: number; x: number; y: number } // id tira un proiettile (E10)
  | { type: "projectileEnd"; projectileId: number; reason: "hit" | "blocked" | "expired" | "wall"; x: number; y: number } // il proiettile sparisce
  | { type: "dash"; id: string; x: number; y: number } // parte uno scatto con il doppio tocco (#199)
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
  projectiles: ProjectileState[]; // proiettili in volo (E10)
  puddles: PuddleState[]; // pozze scivolose a terra (#13)
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
  join: (data: { room: string; name: string; characterId?: string; skinId?: string; stageId?: string; rules?: Partial<MatchRules>; bot?: string; token?: string; version?: string; protocol?: number }) => void;
  input: (input: InputState) => void;
  rematch: () => void; // a fine partita, ricomincia subito (#17)
  // Allenamento (#113): percentuale degli avversari, velocità dell'orologio (TRAINING.speeds), si ricomincia da capo.
  // Il server li accetta solo in una stanza "training" con un solo umano
  training: (data: { percent?: number; speed?: number; reset?: boolean }) => void;
}
