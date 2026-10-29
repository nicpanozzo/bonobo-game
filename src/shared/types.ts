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
  team: number; // 0 = nessuna squadra (tutti contro tutti), da 1 a MAX_TEAMS = squadre (#17, #409)
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
  nextTeam?: number; // la squadra in cui passerà alla prossima partita (#409); assente se resta dov'è
  ledge: "hang" | "climb" | "roll" | null; // appeso al bordo del palco o in risalita (#110), null altrimenti
  away: boolean; // disconnesso, posto tenuto per la riconnessione: fermo e intoccabile (#107)
  shielding: boolean; // scudo alzato (#109)
  shieldHp: number; // punti di scudo, da 0 a SHIELD.maxHp: la bolla è grande in proporzione
  stunned: boolean; // stordito dopo che lo scudo si è rotto: fermo e colpibile
  grabbedBy: string | null; // id di chi lo tiene con la presa (#109), null se libero
  dashing: boolean; // scatta o corre dopo un doppio tocco (#199)
  jumpSquat?: number; // ms di preparazione al salto che restano, a terra (#384 A3); manca se non ci si prepara
  landing?: number; // ms di pausa all'atterraggio che restano (#384 A3); manca se non si sta atterrando
  charge: number; // carica della speciale in corso (E10), da 0 a 1; 0 se non si carica
  supreme: number; // barra della suprema (#101), da 0 a SUPREME.max: piena, il tasto suprema la lancia
  powerup: string | null; // potenziamento in corso da un oggetto consumato (#231), null se nessuno
  powerupMs: number; // ms che restano del potenziamento, 0 se nessuno
  predict?: PredictionState; // E17: solo per chi manda InputState.seq
  companion?: CompanionState; // il compagno che lo segue (#369, il beagle di Lampione); manca se non ne ha
  station?: number; // indice della postazione che sta usando (#433, stage.stations): fermo, i tasti guidano lei; manca se nessuna
}

// Il compagno di un lottatore (#369): dove è e dove guarda
export interface CompanionState {
  x: number; // centro
  y: number; // piedi
  facing: 1 | -1;
  onGround: boolean;
  percent: number; // danni presi (#369 passo 3); manca mentre è KO, perché manca tutto il compagno
  bite?: boolean; // l'attacco in corso del padrone è un suo morso: solo se era lì vicino quando è partito
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
  attackAir?: boolean; // l'attacco in corso è partito in aria: atterrando si interrompe con la sua pausa (#384 A3)
  dropHold?: number; // ms di giù tenuto a terra prima di scendere da una sottile, -1 bloccato (Fighter.dropHold); manca se 0
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
  supreme?: boolean; // tirato dalla suprema (l'aquila dell'Elefante di Elvedeo): numeri e disegno da lì, non dalla speciale
}

// Una pozza di merda dell'IRA di Lendmar (#13): a terra, chi ci sta sopra scivola (non chi l'ha tirata)
export interface PuddleState {
  id: number;
  ownerId: string;
  x: number; // centro
  y: number; // la superficie su cui è
  width: number;
}

// Il power-up Tetris (#427): i pezzi che cadono e i blocchi posati. Le celle sono quadretti di TETRIS.cellPx
// pixel, con [x, y] l'angolo in alto a sinistra; kind è la forma (I, O, T, L, J, S, Z) e decide il colore
export interface TetrisState {
  pieces: { id: number; ownerId: string; kind: string; cells: [number, number][]; fall: number }[]; // fall: pixel che mancano alla posa, per l'ombra
  blocks: { x: number; y: number; kind: string; ms: number; keep?: true }[]; // ms: quanto resta prima che il blocco sparisca; keep: posato da una gru (#433), resta per tutta la partita
}

// Il Bassanese chiamato col telefono (Chiama Bassanese): x e y sono i piedi. phase: cammina, salta o si guarda in giro (cerca qualcosa)
export interface BassaneseState {
  id: number;
  ownerId: string; // chi l'ha chiamato: lui e i compagni non vengono colpiti
  x: number;
  y: number;
  facing: 1 | -1;
  phase: "walk" | "jump" | "look";
}

// Una postazione dell'arena (#433), nello stesso ordine di stage.stations. I tempi sono stageMs
export interface StationState {
  user: string | null; // chi la sta usando
  aim?: number; // bombarda: gradi sopra l'orizzontale
  ammo?: number; // bombarda: palle di mortadella dentro
  readyAt?: number; // bombarda: da quando può sparare di nuovo
  load?: number; // munizioni: quando è pronta la cassa in carica; manca se non se ne carica una
  crates?: number[]; // munizioni: quando arriva su ognuna delle casse in salita
  cart?: number; // teleferica: dove sta il cestello lungo il cavo, da 0 (path[0] del mover) a 1 (path[1])
  shield?: number; // ombrellone: il bordo sinistro dello scudo
  piece?: { kind: string; cells: [number, number][] }; // gru: il pezzo appeso (forma e quadretti in pixel, angolo in alto a sinistra); manca se non ce n'è. readyAt: da quando pende il prossimo
}

// Una palla di mortadella sparata da una bombarda (#433): fa l'arco con STATION.ballGravityPxS2
export interface CannonballState {
  id: number;
  ownerId: string; // chi l'ha sparata
  x: number; // centro
  y: number;
  vx: number;
  vy: number;
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
  teamCount: number; // quante squadre in modalità Squadre, da 2 a MAX_TEAMS (#409); in Bandiera sempre 2
  supremeSpeed: number; // moltiplicatore della carica della suprema, uno dei SUPREME_SPEEDS (1 = normale)
  itemAmount: number; // quanti oggetti cadono: indice in ITEM_AMOUNTS (0 = nessuno)
  itemKinds: string[]; // quali oggetti possono cadere (id di ITEMS); vuoto = nessuno
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
  | { type: "pad"; index: number; sound: string; id: string; x: number; y: number } // id ha premuto il bottone sonoro stage.pads[index] (#423)
  // Postazione stage.stations[index] (#433): enter/exit = id entra o esce, fire = la bombarda spara, load = una cassa
  // parte in salita, ammo = le palle arrivano alla bombarda, boom = una palla di mortadella si schianta (x, y)
  | { type: "station"; phase: "enter" | "exit" | "fire" | "load" | "ammo" | "boom"; index: number; id: string | null; x: number; y: number }
  | { type: "hazard"; id: string; index: number; damage: number; percent: number; knockback: number; x: number; y: number } // preso da una trappola (stage.hazards[index], #14)
  | { type: "itemSpawn"; itemId: number; kind: string; x: number; y: number } // un oggetto comincia a cadere (#17)
  | { type: "itemPick"; itemId: number; id: string } // id lo raccoglie
  | { type: "itemThrow"; itemId: number; id: string; x: number; y: number }
  | { type: "powerUp"; itemId: number; id: string; kind: string; x: number; y: number } // id consuma l'oggetto e si potenzia (#231)
  | { type: "powerEnd"; id: string; kind: string } // il potenziamento di id finisce
  | { type: "bassanese"; phase: "call" | "leave"; id: string; x: number; y: number } // Chiama Bassanese: id ha chiamato
  | { type: "tetris"; phase: "spawn" | "move" | "rotate" | "drop" | "land" | "line"; id: string; x: number; y: number; width?: number } // il pezzo di Tetris di id (#427); line: esplode una riga larga width pixel, x e y al centro
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
  pads?: (number | null)[]; // bottoni sonori (#423): stageMs dell'ultima pressione di ognuno, null se mai premuto
  tetris?: TetrisState; // pezzi e blocchi del power-up Tetris (#427), solo quando ce ne sono
  bassanese?: BassaneseState[]; // i Bassanesi chiamati col telefono, solo quando ce n'è uno in giro
  stations?: StationState[]; // postazioni (#433), solo nelle arene che ne hanno
  cannonballs?: CannonballState[]; // palle di mortadella in volo (#433), con stations
  towerPoints?: Record<number, number>; // punti torre per squadra (#433): colpi di bombarda a segno sugli avversari, con stations
  prizeTeam?: number; // premio (#433): la squadra in testa ai punti torre congelata a prizeAtMs; assente prima, o se era pareggio
  prematch?: PrematchState; // pre-partita: c'è solo finché la partita non è cominciata (attesa, presentazione, 3, 2, 1)
}

// Pre-partita. waiting: si aspetta che tutti dicano Pronto, intanto ci si scalda senza perdere vite;
// starting: lottatori fermi al loro posto, leftMs al VIA (più di PREMATCH.countdownMs = c'è ancora la presentazione)
export interface PrematchState {
  phase: "waiting" | "starting";
  leftMs: number; // in starting: ms al VIA; in waiting 0
  ready: string[]; // id di chi ha detto Pronto
  autoStartMs: number | null; // in waiting: ms dopo cui si parte comunque; null se manca qualcuno con cui giocare
}

// Sala d'attesa 3D: prima di ogni serie di partite ci si ritrova in una sala, ci si muove davvero e si vota
// camminando (pedane delle modalità, portali delle arene, piedistalli dei lottatori, cerchio dei pronti).
// Il server è l'arbitro anche qui: calcola dove sono tutti (src/shared/hall.ts) e manda HallSnapshot.
// Coordinate in centimetri: x verso destra, z verso la telecamera (su = -z), y in alto; (0, 0, 0) al centro del pavimento.
export type HallMode = "ffa" | "teams" | "flag" | "race";
export type HallZoneKind = "mode" | "stage" | "fighter" | "ready" | "trampoline" | "botAdd" | "botRemove" | "gong" | "throne";
export interface HallZone {
  kind: HallZoneKind;
  id: string; // mode: id della modalità; stage: id dell'arena o "casuale"; fighter: id del lottatore; gli altri: un nome unico
  x: number;
  z: number;
  r: number; // raggio in cui si è "dentro", cm
  label: string; // già pronto da mostrare
}
export interface HallPlayerState {
  id: string;
  name: string;
  characterId: string;
  skinId: string;
  color: number;
  x: number;
  y: number; // altezza da terra, cm (salti e trampolini)
  z: number;
  facing: 1 | -1;
  moving: boolean; // cammina: il client mostra la camminata invece della posa ferma
  onGround: boolean;
  ready: boolean; // dentro il cerchio dei pronti
  modeVote: HallMode | null; // l'ultima pedana su cui è salito (il voto resta anche quando scende)
  stageVote: string | null; // l'ultimo portale in cui è entrato
  bot: boolean;
  away: boolean; // caduto dalla rete, posto tenuto
  host: boolean; // chi ha creato la stanza: a parità di voti vince la sua scelta
  emote: boolean; // tiene premuta la provocazione: fa l'inchino
  stunMs: number; // ms in cui vola via dopo una spinta
  throne: boolean; // seduto sul trono del campione
}
export type HallEvent =
  | { type: "hop"; id: string }
  | { type: "land"; id: string }
  | { type: "bounce"; id: string } // trampolino
  | { type: "shove"; id: string; targets: string[] } // spinta col tasto leggero: chi è vicino vola via, senza danni
  | { type: "vote"; id: string; what: "mode" | "stage"; value: string }
  | { type: "pick"; id: string; characterId: string; skinId: string } // ha cambiato lottatore su un piedistallo
  | { type: "gong"; id: string }
  | { type: "throne"; id: string } // si è seduto sul trono
  | { type: "bot"; id: string; added: boolean }
  | { type: "join"; id: string }
  | { type: "leave"; id: string }
  | { type: "countdown"; ms: number } // tutti pronti: parte il conto alla rovescia
  | { type: "cancel" } // qualcuno è uscito dal cerchio: conto annullato
  | { type: "go"; mode: HallMode; stageId: string }; // si parte: subito dopo arriva l'evento stage
// Una riga della classifica a punti (src/server/rating.ts)
export interface BoardRow {
  name: string;
  rating: number; // punti Elo, si parte da RATING.start
  tier: string; // il grado, da RATING.tiers
  wins: number;
  matches: number;
  streak: number; // vittorie di fila (0 se l'ultima è persa)
}
export interface HallSnapshot {
  t: number;
  width: number; // pavimento, cm
  depth: number;
  zones: HallZone[];
  players: HallPlayerState[];
  votes: { mode: Partial<Record<HallMode, number>>; stage: Record<string, number> };
  leading: { mode: HallMode; stageId: string }; // cosa si giocherebbe se si partisse adesso
  countdownMs: number | null; // ms al via, null se non tutti sono pronti
  need: string | null; // perché non si può ancora partire, già pronto da mostrare (null = basta entrare nel cerchio)
  events: HallEvent[];
  board: BoardRow[]; // i primi della classifica, per il tabellone della sala
  rules: MatchRules; // regole di chi ha creato la stanza (vite, tempo, oggetti): la modalità la decide il voto
}
// Punti guadagnati o persi a fine partita, per la schermata dei risultati
export interface RatingChange {
  id: string;
  name: string;
  rating: number;
  delta: number;
  tier: string;
  rank: number | null; // posizione in classifica dopo la partita
}

// Eventi Socket.IO tipizzati
export interface ServerToClient {
  // stage è l'arena intera: chi non ha il codice di src/shared (client Godot, #59) non sa rigenerare
  // le arene casuali e i percorsi della Corsa dal loro id
  // token: segreto di questo giocatore in questa stanza, mai negli snapshot; si rimanda nel join per rientrare (#107)
  // resumed: true = rientrato nel posto tenuto, con lo stesso lottatore
  // serverVersion: versione del gioco sul server (package.json), il client avvisa se è diversa dalla sua (E2)
  // phase: "hall" = la stanza è nella sala d'attesa (arrivano i messaggi hall), "match" = partita; hall: la stanza ha la sala
  welcome: (data: { id: string; room: string; stageId: string; rules: MatchRules; stage: StageSpec; token: string; resumed: boolean; serverVersion: string; hall?: boolean; phase?: "hall" | "match" }) => void;
  snapshot: (snap: GameSnapshot) => void;
  roomFull: () => void; // resta per i client di prima; i nuovi leggono refused
  refused: (data: Refusal) => void; // unico rifiuto con motivo: protocollo diverso, stanza piena, troppe stanze (E2, E4)
  hall: (snap: HallSnapshot) => void; // la stanza è nella sala d'attesa: al posto degli snapshot della partita
  stage: (data: { stageId: string; rules: MatchRules; stage: StageSpec }) => void; // dalla sala si parte: arena e regole della partita
  ratings: (data: { changes: RatingChange[] }) => void; // a fine partita, i punti in classifica di chi ha giocato
}

// Perché il server non fa entrare: outdated = protocollo diverso, full = stanza piena, limit = troppe stanze sul server
export interface Refusal {
  reason: "outdated" | "full" | "limit";
  message: string; // già pronto da mostrare a chi gioca
}

export interface ClientToServer {
  // stageId e rules contano solo per chi crea la stanza; gli altri entrano in quella che c'è
  // bot: chi crea la stanza può aggiungere un avversario del server, es. "manichino" (#20)
  // botCharacterId: il lottatore di quel bot (#383); manca o non esiste = Bonobot. Il manichino è quel lottatore fermo
  // token: quello del welcome, dopo una caduta di rete; se il posto è ancora tenuto si rientra nello stesso lottatore (#107)
  // version e protocol: versione del gioco (package.json) e PROTOCOL_VERSION del client; mancano nei client di prima (E2)
  // team: la squadra che si vorrebbe (#409), da 1 a teamCount; manca o 0 = quella con meno giocatori
  // hall: chi crea la stanza la vuole con la sala d'attesa (i client di prima e palestra, tutorial e sfide non la chiedono)
  join: (data: { room: string; name: string; characterId?: string; skinId?: string; team?: number; stageId?: string; rules?: Partial<MatchRules>; bot?: string; botCharacterId?: string; token?: string; version?: string; protocol?: number; hall?: boolean }) => void;
  input: (input: InputState) => void;
  rematch: () => void; // a fine partita, ricomincia subito (#17)
  ready: (data: { ready: boolean }) => void; // pre-partita: pronto o non più pronto; quando lo sono tutti si comincia
  // Cambio di squadra (#409), solo a squadre: subito se la partita non è in corso, altrimenti dalla prossima
  team: (data: { team: number }) => void;
  // Allenamento (#113): percentuale degli avversari, velocità dell'orologio (TRAINING.speeds), si ricomincia da capo.
  // Il server li accetta solo in una stanza "training" con un solo umano
  training: (data: { percent?: number; speed?: number; reset?: boolean }) => void;
  hall: () => void; // a partita finita: tutti tornano nella sala d'attesa (solo nelle stanze con la sala)
}
