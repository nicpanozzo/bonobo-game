// Sala d'attesa 3D: ci si muove davvero e si sceglie camminando (modalità, arena, lottatore, pronti).
// Pura e deterministica come la fisica: niente rete, niente orologio, niente Math.random.
// Il server la fa avanzare a passo fisso (src/server/Room.ts) e manda HallSnapshot.
// Coordinate in cm: x a destra, z verso la telecamera (su = -z), y in alto; (0, 0, 0) al centro del pavimento.

import { CHARACTERS, getCharacter, skinFor } from "./characters";
import { COLORS, HALL, MAX_PLAYERS_PER_ROOM } from "./constants";
import { emptyInput } from "./physics";
import { MAX_SEED, RANDOM_STAGE_PREFIX, rng } from "./stageGenerator";
import { DEFAULT_STAGE_ID, STAGES } from "./stages";
import type {
  BoardRow,
  ChessPiece,
  HallEvent,
  HallMode,
  HallPlayerState,
  HallPropKind,
  HallPropState,
  HallSnapshot,
  HallZone,
  InputState,
  MatchRules,
} from "./types";

export const HALL_MODES: { id: HallMode; label: string }[] = [
  { id: "ffa", label: "Tutti contro tutti" },
  { id: "teams", label: "Squadre" },
  { id: "flag", label: "Bandiera" },
  { id: "race", label: "Corsa" },
];
export const RANDOM_STAGE_ZONE = "casuale"; // il portale dell'arena generata: il seme lo decide la sala a ogni giro

// Le arene che la lobby fa scegliere: quelle di stages.ts senza hidden (#408) e senza traguardo, più la casuale
export function hallStageIds(): string[] {
  return [...Object.values(STAGES).filter((s) => !s.hidden && !s.goal).map((s) => s.id), RANDOM_STAGE_ZONE];
}

// Tutti i lottatori della lobby, nell'ordine di characters.ts
export function hallFighterIds(): string[] {
  return Object.keys(CHARACTERS);
}

// La pianta della sala. In fondo le pedane delle modalità, a sinistra la galleria dei lottatori,
// a destra i portali delle arene, al centro il cerchio dei pronti; davanti l'ingresso e le gabbie dei bot,
// negli angoli in fondo il trono e il gong. Ai lati la zona giochi: a sinistra la scacchiera gigante,
// a destra il mezzo campo da basket col canestro sul muro, rivolto verso la sala
export function hallLayout(): HallZone[] {
  const zones: HallZone[] = [];
  const modeX = [-660, -220, 220, 660];
  HALL_MODES.forEach((m, i) => zones.push({ kind: "mode", id: m.id, x: modeX[i], z: -680, r: HALL.padRadius, label: m.label }));
  // Galleria: tre colonne, file di 200 cm verso la telecamera
  hallFighterIds().forEach((id, i) =>
    zones.push({ kind: "fighter", id, x: -1380 + (i % 3) * 180, z: -380 + Math.floor(i / 3) * 200, r: HALL.pedestalRadius, label: getCharacter(id).name }),
  );
  // Portali: due colonne, file di 280 cm
  hallStageIds().forEach((id, i) =>
    zones.push({
      kind: "stage",
      id,
      x: 1080 + (i % 2) * 280,
      z: -400 + Math.floor(i / 2) * 280,
      r: HALL.portalRadius,
      label: id === RANDOM_STAGE_ZONE ? "Casuale" : STAGES[id].name,
    }),
  );
  zones.push({ kind: "ready", id: "ready", x: READY_X, z: READY_Z, r: HALL.readyRadius, label: "Pronti" });
  zones.push({ kind: "trampoline", id: "trampolino-sinistra", x: -620, z: 250, r: HALL.trampolineRadius, label: "Trampolino" });
  zones.push({ kind: "trampoline", id: "trampolino-destra", x: 620, z: 250, r: HALL.trampolineRadius, label: "Trampolino" });
  zones.push({ kind: "botAdd", id: "bot-chiama", x: -720, z: 650, r: HALL.cageRadius, label: "Chiama un bot" });
  zones.push({ kind: "botRemove", id: "bot-via", x: -480, z: 650, r: HALL.cageRadius, label: "Manda via un bot" });
  zones.push({ kind: "gong", id: "gong", x: 1250, z: -720, r: HALL.gongRadius, label: "Gong" });
  zones.push({ kind: "throne", id: "trono", x: -1250, z: -720, r: HALL.throneRadius, label: "Trono del campione" });
  // court: quadrato di lato 2r; hoop: centro del ferro (r = raggio del ferro), dentro il campo;
  // chessboard: 8x8 caselle da HALL.chessSquare, r = metà lato
  zones.push({ kind: "court", id: "campo", x: COURT_X, z: HOOP_Z, r: HALL.courtRadius, label: "Campo da basket" });
  zones.push({ kind: "hoop", id: "canestro", x: HOOP_X, z: HOOP_Z, r: HALL.rimRadius, label: "Canestro" });
  zones.push({ kind: "chessboard", id: "scacchiera", x: CHESS_X, z: CHESS_Z, r: CHESS_HALF, label: "Scacchi giganti" });
  // La rastrelliera dei palloni: i palloni ci tornano da soli; r copre i tre posti
  zones.push({ kind: "rack", id: "rastrelliera", x: HALL.rackX + HALL.rackGap, z: HALL.rackZ, r: HALL.rackGap * 2, label: "Palloni" });
  return zones;
}

const READY_X = 0;
const READY_Z = 100;
const ENTRANCE_Z = HALL.depth / 2 - 120; // si entra davanti, al centro
const ENTRANCE_STEP = 120; // cm tra un nuovo arrivato e l'altro
const BOT_RING = HALL.readyRadius + 90; // i bot aspettano dietro il cerchio, già "pronti"
const RETURN_RING = HALL.readyRadius + HALL.playerRadius + 40; // al ritorno dalla partita: appena fuori dal cerchio
const MOVING_SPEED = 30; // cm/s sotto cui si è fermi (posa) e non si cammina

// Zona giochi
const BOARD_X = HALL.width / 2 - HALL.boardInset; // faccia del tabellone verso la sala
const HOOP_X = BOARD_X - HALL.rimOffset; // centro del ferro
const HOOP_Z = 0;
const COURT_X = HALL.width / 2 - HALL.courtRadius; // il campo arriva al muro del canestro
const CHESS_X = -COURT_X; // la scacchiera, simmetrica dall'altra parte
const CHESS_Z = 0;
const CHESS_HALF = 4 * HALL.chessSquare;
const BEACH_HOME: [number, number][] = [
  [-400, -300],
  [400, -300],
];
const BACK_RANK: ChessPiece[] = ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"];
const FILES = "abcdefgh";
const REST_SPEED = 5; // cm/s: sotto un oggetto è fermo (per il ritorno al suo posto)

export interface HallOptions {
  seed: string; // il codice della stanza: stessa stanza, stesse arene casuali
  defaultMode?: HallMode; // senza voti si gioca questa (la modalità di chi ha creato la stanza)
  defaultStageId?: string; // senza voti l'arena di chi ha creato la stanza
}

export interface HallChoice {
  mode: HallMode;
  stageId: string;
}

interface HallPlayer extends HallPlayerState {
  vx: number;
  vz: number;
  vy: number;
  input: InputState;
  prev: InputState;
  slot: number; // posto 0-7: colore
  shoveCooldown: number; // ms
  cageMs: number; // ms passati fermi in una gabbia dei bot
  onThroneZone: boolean; // adesso sul trono (coi piedi per terra)
  wasOnThrone: boolean; // al passo prima: chi arriva adesso prende il trono
}

// Un oggetto della zona giochi con lo stato che non va nello snapshot
interface HallProp extends HallPropState {
  vx: number;
  vy: number;
  vz: number;
  mass: number;
  homeX: number;
  homeY: number;
  homeZ: number;
  homeYaw: number;
  lastBy: string | null; // l'ultimo che l'ha tirato, calciato o spinto
  shot: { by: string; points: 2 | 3 } | null; // pallone tirato e non ancora a terra: se entra è canestro
  touched: boolean; // il tiro ha toccato ferro o tabellone (niente swish)
  noPickId: string | null; // chi l'ha appena tirato non lo riprende subito
  noPickMs: number;
  idleMs: number; // ms fermo fuori posto
  hitMs: number; // ricarica di propHit
  toppled: boolean; // pezzo caduto (o che sta cadendo): non urta più niente
}

interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export class Hall {
  readonly zones: HallZone[] = hallLayout();
  private players = new Map<string, HallPlayer>();
  private events: HallEvent[] = [];
  private countdown: number | null = null;
  private choice: HallChoice | null = null;
  private gongCooldown = 0;
  private arrivals = 0; // quanti sono entrati: decide dove spunta il prossimo
  private botCount = 0;
  private round = 0; // quante volte si è partiti: cambia il seme dell'arena casuale
  private randomStageId: string;
  private readonly props: HallProp[] = makeProps();
  private readonly propById = new Map(this.props.map((c) => [c.id, c]));
  private readonly balls = this.props.filter((c) => c.kind !== "chess");
  private readonly pieces = this.props.filter((c) => c.kind === "chess");
  private chessResetIn: number | null = null; // ms al ritorno dei pezzi dopo uno scacco matto
  private chessIdle = 0; // ms con la scacchiera in disordine e nessuno vicino
  private readonly rand: { next: () => number }; // errore di mira dei tiri: stessa stanza, stessi tiri
  private readonly seed: number;
  private readonly defaultMode: HallMode;
  private readonly defaultStage: string;

  constructor(options: HallOptions) {
    this.seed = hashSeed(options.seed);
    this.defaultMode = options.defaultMode ?? "ffa";
    const wanted = options.defaultStageId;
    this.defaultStage =
      wanted && hallStageIds().includes(wanted) ? wanted : wanted?.startsWith(RANDOM_STAGE_PREFIX) ? RANDOM_STAGE_ZONE : DEFAULT_STAGE_ID;
    this.randomStageId = this.rollRandomStage();
    this.rand = rng(this.seed ^ 0x2545f491);
  }

  get size() {
    return this.players.size;
  }

  get isFull() {
    return this.players.size >= MAX_PLAYERS_PER_ROOM;
  }

  get hostId(): string | null {
    for (const p of this.players.values()) if (p.host) return p.id;
    return null;
  }

  get countdownMs(): number | null {
    return this.countdown;
  }

  has(id: string): boolean {
    return this.players.has(id);
  }

  names(): string[] {
    return [...this.players.values()].map((p) => p.name);
  }

  // Tutti, in ordine di arrivo: con questi si costruisce la partita
  roster(): readonly HallPlayerState[] {
    return [...this.players.values()];
  }

  botIds(): string[] {
    return [...this.players.values()].filter((p) => p.bot).map((p) => p.id);
  }

  fighter(id: string): { characterId: string; skinId: string } | null {
    const p = this.players.get(id);
    return p ? { characterId: p.characterId, skinId: p.skinId } : null;
  }

  // Si spunta all'ingresso, uno accanto all'altro. Il primo umano senza un padrone di casa lo diventa
  addPlayer(id: string, name: string, characterId?: string, skinId?: string, opts: { host?: boolean; bot?: boolean } = {}) {
    if (this.players.has(id) || this.isFull) return;
    const bot = !!opts.bot;
    const host = !bot && (!!opts.host || this.hostId === null);
    if (host) for (const p of this.players.values()) p.host = false;
    const n = this.arrivals++;
    const offset = n % 8 === 0 ? 0 : Math.ceil((n % 8) / 2) * ENTRANCE_STEP * (n % 2 ? -1 : 1);
    const cid = getCharacter(characterId).id;
    const slot = this.freeSlot();
    const p: HallPlayer = {
      id,
      name: shortName(name) || "Bonobo",
      characterId: cid,
      skinId: skinFor(cid, skinId) ?? "",
      color: COLORS[slot],
      x: offset,
      y: 0,
      z: ENTRANCE_Z,
      facing: 1,
      moving: false,
      onGround: true,
      ready: false,
      modeVote: null,
      stageVote: null,
      bot,
      away: false,
      host,
      emote: false,
      stunMs: 0,
      throne: false,
      holding: null,
      baskets: 0,
      vx: 0,
      vz: 0,
      vy: 0,
      input: emptyInput(),
      prev: emptyInput(),
      slot,
      shoveCooldown: 0,
      cageMs: 0,
      onThroneZone: false,
      wasOnThrone: false,
    };
    if (bot) this.placeBot(p, this.botIds().length);
    this.players.set(id, p);
    this.events.push({ type: "join", id });
  }

  // Un bot del server: lottatori a rotazione, da Bonobot in poi. null se la stanza è piena o ce ne sono già troppi
  addBot(characterId?: string): string | null {
    if (this.isFull || this.botIds().length >= HALL.maxBots) return null;
    const roster = hallFighterIds();
    const n = this.botCount++;
    const start = Math.max(0, roster.indexOf("bonobot"));
    const cid = characterId && Object.hasOwn(CHARACTERS, characterId) ? characterId : roster[(start + n) % roster.length];
    const id = `bot-sala-${n + 1}`;
    this.addPlayer(id, `Bot ${getCharacter(cid).name}`, cid, undefined, { bot: true });
    return id;
  }

  // Manda via l'ultimo bot arrivato
  removeBot(): string | null {
    const id = this.botIds().pop();
    if (!id) return null;
    this.removePlayer(id);
    return id;
  }

  removePlayer(id: string) {
    const p = this.players.get(id);
    if (!p) return;
    this.release(p);
    this.players.delete(id);
    this.events.push({ type: "leave", id });
    // Il padrone di casa se ne va: lo diventa il prossimo umano arrivato
    if (p.host) {
      const next = [...this.players.values()].find((q) => !q.bot);
      if (next) next.host = true;
    }
  }

  // Caduto dalla rete: fermo dov'è, non conta per partire e non si urta
  setAway(id: string, away: boolean) {
    const p = this.players.get(id);
    if (!p || p.away === away) return;
    p.away = away;
    p.ready = false;
    p.throne = false;
    p.vx = p.vz = 0;
    p.input = emptyInput();
    p.prev = emptyInput();
    this.release(p);
  }

  // I dati arrivano dalla rete: solo booleani
  setInput(id: string, input: InputState) {
    const p = this.players.get(id);
    if (!p || p.away || p.bot) return;
    const next = emptyInput();
    for (const k of Object.keys(next) as (keyof InputState)[]) (next as unknown as Record<string, boolean>)[k] = !!input[k];
    p.input = next;
  }

  // Dove si gioca se si partisse adesso
  leading(): HallChoice {
    const voters = this.voters();
    const hostP = voters.find((p) => p.host);
    const mode = pickVote(
      HALL_MODES.map((m) => m.id),
      voters.map((p) => p.modeVote),
      hostP?.modeVote ?? null,
      this.defaultMode,
    );
    const stage = pickVote(
      hallStageIds(),
      voters.map((p) => p.stageVote),
      hostP?.stageVote ?? null,
      this.defaultStage,
    );
    return { mode, stageId: stage === RANDOM_STAGE_ZONE ? this.randomStageId : stage };
  }

  // Perché non si parte, già da mostrare; null = si può partire (o si sta già partendo)
  need(): string | null {
    const humans = this.voters();
    if (humans.length === 0) return "Aspettiamo i giocatori";
    const fighters = humans.length + this.botIds().length;
    const missing = HALL.minFighters - fighters;
    if (missing > 0) {
      const head = missing === 1 ? "Serve un altro lottatore" : `Servono altri ${missing} lottatori`;
      return `${head}: manda il link o chiama un bot dalla gabbia`;
    }
    const out = humans.filter((p) => !p.ready).map((p) => p.name);
    if (out.length === 0) return null;
    return `${out.length === 1 ? "Manca" : "Mancano"} ${listNames(out)} nel cerchio`;
  }

  // La scelta finale, quando il conto alla rovescia è arrivato a zero
  result(): HallChoice | null {
    return this.choice;
  }

  // Di ritorno dalla partita: tutti appena fuori dal cerchio, voti azzerati, lottatori tenuti
  regroup() {
    this.round++;
    this.randomStageId = this.rollRandomStage();
    this.choice = null;
    this.countdown = null;
    this.gongCooldown = 0;
    const humans = [...this.players.values()].filter((p) => !p.bot);
    humans.forEach((p, i) => {
      const a = Math.PI / 2 + (2 * Math.PI * i) / Math.max(1, humans.length);
      this.reset(p, READY_X + Math.cos(a) * RETURN_RING, READY_Z + Math.sin(a) * RETURN_RING);
      p.modeVote = null;
      p.stageVote = null;
      p.ready = false;
    });
    this.botIds().forEach((id, i) => this.placeBot(this.players.get(id)!, i));
    this.resetProps();
  }

  // Lancia un oggetto da un punto (strumenti e test); con by conta come un tiro di by
  launchProp(id: string, x: number, y: number, z: number, vx = 0, vy = 0, vz = 0, by?: string) {
    const c = this.propById.get(id);
    if (!c) return;
    const holder = c.holder ? this.players.get(c.holder) : undefined;
    if (holder) holder.holding = null;
    c.holder = null;
    Object.assign(c, { x, y, z, vx, vy, vz, idleMs: 0, touched: false, lastBy: by ?? null });
    c.shot = by && c.kind === "basketball" ? { by, points: Math.hypot(x - HOOP_X, z - HOOP_Z) > HALL.threePointRadius ? 3 : 2 } : null;
  }

  // Un passo di simulazione: restituisce gli eventi nati da allora (anche ingressi e uscite)
  step(dtMs: number): HallEvent[] {
    if (this.choice) return this.flush();
    const dt = dtMs / 1000;
    this.gongCooldown = Math.max(0, this.gongCooldown - dtMs);
    const list = [...this.players.values()].filter((p) => !p.away);
    for (const p of list) this.move(p, dt, dtMs);
    this.collide(list);
    for (const p of list) this.clamp(p);
    this.stepProps(list, dt, dtMs);
    for (const p of list) this.clamp(p); // i pezzi degli scacchi spostano anche chi li spinge
    for (const p of list) this.zonesFor(p, dtMs);
    this.updateThrone(list);
    for (const p of list) {
      p.ready = p.bot || !!this.inZone(p, "ready");
      p.prev = p.input;
    }
    this.updateCountdown(dtMs);
    return this.flush();
  }

  snapshot(t: number, events: HallEvent[], board: BoardRow[], rules: MatchRules): HallSnapshot {
    const votes: HallSnapshot["votes"] = { mode: {}, stage: {} };
    for (const p of this.voters()) {
      if (p.modeVote) votes.mode[p.modeVote] = (votes.mode[p.modeVote] ?? 0) + 1;
      if (p.stageVote) votes.stage[p.stageVote] = (votes.stage[p.stageVote] ?? 0) + 1;
    }
    const leading = this.choice ?? this.leading();
    const players: HallPlayerState[] = [...this.players.values()].map((p) => ({
      id: p.id,
      name: p.name,
      characterId: p.characterId,
      skinId: p.skinId,
      color: p.color,
      x: Math.round(p.x),
      y: Math.round(p.y),
      z: Math.round(p.z),
      facing: p.facing,
      moving: p.moving,
      onGround: p.onGround,
      ready: p.ready,
      modeVote: p.modeVote,
      stageVote: p.stageVote,
      bot: p.bot,
      away: p.away,
      host: p.host,
      emote: p.emote,
      stunMs: Math.ceil(p.stunMs),
      throne: p.throne,
      holding: p.holding,
      baskets: p.baskets,
    }));
    return {
      t,
      width: HALL.width,
      depth: HALL.depth,
      zones: this.zones,
      players,
      votes,
      leading,
      countdownMs: this.countdown === null ? null : Math.max(0, Math.round(this.countdown)),
      need: this.need(),
      events,
      board,
      props: this.props.map(propState),
      rules: { ...rules, mode: leading.mode },
    };
  }

  // --- movimento ---

  private move(p: HallPlayer, dt: number, dtMs: number) {
    const input = p.input;
    const pressed = (k: keyof InputState) => !!input[k] && !p.prev[k];
    p.shoveCooldown = Math.max(0, p.shoveCooldown - dtMs);
    p.emote = !p.bot && input.taunt;
    let dx = 0;
    let dz = 0;
    if (p.stunMs > 0) {
      p.stunMs = Math.max(0, p.stunMs - dtMs); // spinto: vola via senza comandare
    } else {
      dx = (input.right ? 1 : 0) - (input.left ? 1 : 0);
      dz = (input.down ? 1 : 0) - (input.up ? 1 : 0);
    }
    const len = Math.hypot(dx, dz);
    if (len > 0) {
      // In diagonale non si va più veloci
      const tx = (dx / len) * HALL.walkSpeed;
      const tz = (dz / len) * HALL.walkSpeed;
      p.vx = approach(p.vx, tx, HALL.accel * dt);
      p.vz = approach(p.vz, tz, HALL.accel * dt);
      if (dx !== 0) p.facing = dx > 0 ? 1 : -1;
    } else if (p.onGround) {
      // Frenata lungo la direzione del movimento, così si ferma dritto
      const speed = Math.hypot(p.vx, p.vz);
      const next = Math.max(0, speed - HALL.friction * dt);
      const k = speed > 0 ? next / speed : 0;
      p.vx *= k;
      p.vz *= k;
    }
    if (pressed("jump") && p.onGround && p.stunMs <= 0) {
      p.vy = HALL.jumpSpeed;
      p.onGround = false;
      this.events.push({ type: "hop", id: p.id });
    }
    if (pressed("light") && p.shoveCooldown <= 0 && p.stunMs <= 0) {
      if (p.holding) this.throwBall(p);
      else this.shove(p);
    }
    p.x += p.vx * dt;
    p.z += p.vz * dt;
    if (!p.onGround) {
      p.vy -= HALL.gravity * dt;
      p.y += p.vy * dt;
      if (p.y <= 0) {
        p.y = 0;
        p.vy = 0;
        p.onGround = true;
        this.events.push({ type: "land", id: p.id });
      }
    }
    p.moving = p.onGround && Math.hypot(p.vx, p.vz) > MOVING_SPEED;
  }

  // Tasto leggero: chi è vicino vola via, senza danni. Dentro il gong lo si suona
  private shove(p: HallPlayer) {
    p.shoveCooldown = HALL.shoveCooldownMs;
    if (this.inZone(p, "gong") && this.gongCooldown <= 0) {
      this.gongCooldown = HALL.gongCooldownMs;
      this.events.push({ type: "gong", id: p.id });
    }
    const targets: string[] = [];
    for (const t of this.players.values()) {
      if (t === p || t.away) continue;
      const dx = t.x - p.x;
      const dz = t.z - p.z;
      const d = Math.hypot(dx, dz);
      if (d > HALL.shoveRadius || Math.abs(t.y - p.y) > HALL.collideHeight) continue;
      // Uno sopra l'altro: via nella direzione in cui si guarda
      const nx = d > 0.001 ? dx / d : p.facing;
      const nz = d > 0.001 ? dz / d : 0;
      t.vx = nx * HALL.shoveSpeed;
      t.vz = nz * HALL.shoveSpeed;
      t.vy = Math.max(t.vy, HALL.shoveLift);
      t.onGround = false;
      t.stunMs = HALL.shoveStunMs;
      this.release(t); // spinto: il pallone gli scappa di mano
      targets.push(t.id);
    }
    this.events.push({ type: "shove", id: p.id, targets });
    this.shoveProps(p);
  }

  // Due giocatori non si sovrappongono: ognuno si sposta di metà
  private collide(list: HallPlayer[]) {
    const min = HALL.playerRadius * 2;
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        if (Math.abs(a.y - b.y) > HALL.collideHeight) continue;
        const dx = b.x - a.x;
        const dz = b.z - a.z;
        const d = Math.hypot(dx, dz);
        if (d >= min) continue;
        const nx = d > 0.001 ? dx / d : 1;
        const nz = d > 0.001 ? dz / d : 0;
        const push = (min - d) / 2;
        a.x -= nx * push;
        a.z -= nz * push;
        b.x += nx * push;
        b.z += nz * push;
      }
    }
  }

  // I muri: si resta sul pavimento, e la velocità contro il muro si azzera
  private clamp(p: HallPlayer) {
    const maxX = HALL.width / 2 - HALL.playerRadius;
    const maxZ = HALL.depth / 2 - HALL.playerRadius;
    if (Math.abs(p.x) > maxX) {
      p.x = Math.sign(p.x) * maxX;
      if (Math.sign(p.vx) === Math.sign(p.x)) p.vx = 0;
    }
    if (Math.abs(p.z) > maxZ) {
      p.z = Math.sign(p.z) * maxZ;
      if (Math.sign(p.vz) === Math.sign(p.z)) p.vz = 0;
    }
  }

  // --- zona giochi: palloni e scacchi ---

  // Un passo degli oggetti, dopo che i giocatori si sono mossi
  private stepProps(list: HallPlayer[], dt: number, dtMs: number) {
    for (const b of this.balls) {
      b.hitMs = Math.max(0, b.hitMs - dtMs);
      b.noPickMs = Math.max(0, b.noPickMs - dtMs);
      if (b.noPickMs === 0) b.noPickId = null;
    }
    for (const p of list) if (!p.holding && !p.bot && p.stunMs <= 0) this.tryPickup(p);
    for (const b of this.balls) {
      const holder = b.holder ? this.players.get(b.holder) : undefined;
      if (holder) this.holdAt(b, holder);
      else b.holder = null;
    }
    for (const p of list) for (const c of this.pieces) if (!c.toppled) this.pushPiece(p, c);
    // I palloni a sottopassi corti: veloci come un tiro non attraversano il ferro né un giocatore
    const free = this.balls.filter((b) => !b.holder);
    const n = Math.max(1, Math.ceil(dtMs / HALL.propStepMs));
    const h = dt / n;
    for (let s = 0; s < n; s++) {
      for (const b of free) this.moveBall(b, h);
      for (let i = 0; i < free.length; i++) for (let j = i + 1; j < free.length; j++) this.ballBall(free[i], free[j]);
      for (const b of free) {
        for (const c of this.pieces) if (!c.toppled) this.ballPiece(b, c);
        for (const p of list) this.ballPlayer(b, p);
      }
    }
    for (const b of free) this.idleBall(b, dtMs);
    this.stepPieces(list, dt, dtMs);
  }

  // Camminando contro un pallone da basket (o col pesante lì vicino) lo si prende, anche al volo saltando
  private tryPickup(p: HallPlayer) {
    const reach = p.input.heavy && !p.prev.heavy ? HALL.heavyPickReach : HALL.pickReach;
    let best: HallProp | null = null;
    let bestD = Infinity;
    for (const b of this.balls) {
      if (b.kind !== "basketball" || b.holder || b.noPickId === p.id) continue;
      if (b.y - b.r > p.y + HALL.reachHeight || b.y + b.r < p.y) continue;
      const d = Math.hypot(b.x - p.x, b.z - p.z) - HALL.playerRadius - b.r;
      if (d <= reach && d < bestD) {
        best = b;
        bestD = d;
      }
    }
    if (!best) return;
    best.holder = p.id;
    best.shot = null;
    best.lastBy = p.id;
    best.idleMs = 0;
    p.holding = best.id;
    this.holdAt(best, p);
    this.events.push({ type: "pickup", id: p.id, prop: best.id });
  }

  // In mano: sopra la testa, un po' davanti
  private holdAt(b: HallProp, p: HallPlayer) {
    b.x = p.x + p.facing * HALL.holdForward;
    b.y = p.y + HALL.holdHeight;
    b.z = p.z;
    b.vx = p.vx;
    b.vy = p.onGround ? 0 : p.vy;
    b.vz = p.vz;
  }

  // Lascia andare il pallone che tiene (uscito, spinto, si parte): cade da dov'è
  private release(p: HallPlayer) {
    const b = p.holding ? this.propById.get(p.holding) : undefined;
    p.holding = null;
    if (!b || b.holder !== p.id) return;
    b.holder = null;
    b.noPickId = p.id;
    b.noPickMs = HALL.noPickMs;
    b.lastBy = p.id;
  }

  // Leggero col pallone in mano: a canestro se lo si guarda e non si è troppo lontani, altrimenti in avanti.
  // Il tiro a canestro è un arco calcolato verso il ferro, con un errore che cresce con la distanza e la velocità
  private throwBall(p: HallPlayer) {
    const b = this.propById.get(p.holding!)!;
    p.shoveCooldown = HALL.shoveCooldownMs;
    this.holdAt(b, p);
    const dx = HOOP_X - p.x;
    const dist = Math.hypot(dx, HOOP_Z - p.z);
    const aim = dist <= HALL.shotRange && p.x < BOARD_X && Math.sign(dx) === p.facing;
    let v: Vec3;
    if (aim) {
      const err = Math.min(
        HALL.aimErrorMax,
        Math.max(0, dist - HALL.aimFreeDist) * HALL.aimErrorPerCm + Math.hypot(p.vx, p.vz) * HALL.aimErrorPerSpeed + (p.onGround ? 0 : HALL.aimErrorAir),
      );
      // Punto a caso nel cerchio dell'errore attorno al centro del ferro
      const er = err * Math.sqrt(this.rand.next());
      const ea = 2 * Math.PI * this.rand.next();
      v = lob(b, { x: HOOP_X + er * Math.cos(ea), y: HALL.rimHeight, z: HOOP_Z + er * Math.sin(ea) });
    } else {
      v = { x: p.facing * HALL.throwSpeed + p.vx * 0.5, y: HALL.throwLift + Math.max(0, p.vy), z: p.vz };
    }
    this.release(p);
    b.vx = v.x;
    b.vy = v.y;
    b.vz = v.z;
    b.shot = { by: p.id, points: dist > HALL.threePointRadius ? 3 : 2 };
    b.touched = false;
    b.idleMs = 0;
    this.events.push({ type: "throw", id: p.id, prop: b.id });
  }

  // La spinta colpisce anche palloni e pezzi vicini: i pezzi leggeri cadono, il re scivola
  private shoveProps(p: HallPlayer) {
    for (const b of this.balls) {
      if (b.holder || b.y + b.r < p.y || b.y - b.r > p.y + HALL.playerHeight) continue;
      const dx = b.x - p.x;
      const dz = b.z - p.z;
      const d = Math.hypot(dx, dz);
      if (d > HALL.shoveRadius + b.r) continue;
      const nx = d > 0.001 ? dx / d : p.facing;
      const nz = d > 0.001 ? dz / d : 0;
      b.vx = nx * HALL.shoveBallSpeed;
      b.vz = nz * HALL.shoveBallSpeed;
      b.vy = Math.max(b.vy, HALL.shoveBallLift);
      b.lastBy = p.id;
      b.shot = null;
      b.idleMs = 0;
    }
    for (const c of this.pieces) {
      if (c.toppled || p.y >= c.h!) continue;
      const dx = c.x - p.x;
      const dz = c.z - p.z;
      const d = Math.hypot(dx, dz);
      if (d > HALL.shoveRadius + c.r) continue;
      const nx = d > 0.001 ? dx / d : p.facing;
      const nz = d > 0.001 ? dz / d : 0;
      const dv = HALL.shovePieceImpulse / c.mass;
      c.vx += nx * dv;
      c.vz += nz * dv;
      c.lastBy = p.id;
      if (dv > HALL.toppleSpeed) this.topple(c, Math.atan2(nz, nx), p.id);
    }
  }

  // Camminando contro un pezzo lo si sposta: i leggeri quasi del tutto, il re frena di più
  private pushPiece(p: HallPlayer, c: HallProp) {
    if (p.y >= c.h! - 5) return; // ci si salta sopra
    const dx = c.x - p.x;
    const dz = c.z - p.z;
    const d = Math.hypot(dx, dz);
    const min = HALL.playerRadius + c.r;
    if (d >= min) return;
    const nx = d > 1e-6 ? dx / d : p.facing;
    const nz = d > 1e-6 ? dz / d : 0;
    const pen = min - d;
    const share = HALL.playerMass / (HALL.playerMass + c.mass);
    c.x += nx * pen * share;
    c.z += nz * pen * share;
    p.x -= nx * pen * (1 - share);
    p.z -= nz * pen * (1 - share);
    const push = (p.vx * nx + p.vz * nz) * HALL.piecePushCarry;
    const cur = c.vx * nx + c.vz * nz;
    if (push > cur) {
      c.vx += nx * (push - cur);
      c.vz += nz * (push - cur);
    }
    c.lastBy = p.id;
  }

  private moveBall(b: HallProp, h: number) {
    const px = b.x;
    const py = b.y;
    const pz = b.z;
    const beach = b.kind === "beachball";
    if (beach) {
      const k = Math.exp(-HALL.beachDrag * h);
      b.vx *= k;
      b.vy *= k;
      b.vz *= k;
    }
    const grounded = b.y <= b.r + 0.01 && b.vy === 0;
    b.x += b.vx * h;
    b.z += b.vz * h;
    // Gira come se rotolasse (anche in aria si tiene la rotazione: basta per vederlo girare)
    const moved = Math.hypot(b.x - px, b.z - pz);
    if (moved > 0) {
      b.yaw = Math.atan2(b.vz, b.vx);
      b.spin = (b.spin + moved / b.r) % (2 * Math.PI);
    }
    if (grounded) {
      // Rotola: frena
      const speed = Math.hypot(b.vx, b.vz);
      if (speed > 0) {
        const next = Math.max(0, speed - (beach ? HALL.beachRollDecel : HALL.rollDecel) * h);
        b.vx *= next / speed;
        b.vz *= next / speed;
      }
    } else {
      // Gravità esatta nel passo: l'arco del tiro arriva dove è stato calcolato
      const g = HALL.gravity * (beach ? HALL.beachGravity : 1);
      b.y += b.vy * h - 0.5 * g * h * h;
      b.vy -= g * h;
    }
    if (b.y < b.r) {
      b.y = b.r;
      if (b.vy < 0) this.floorBounce(b);
    }
    this.ballWalls(b);
    if (b.x + b.r > BOARD_X - HALL.rimOffset - HALL.rimRadius - HALL.rimTube) {
      this.ballBoard(b);
      this.ballRim(b);
      // Nella retina il pallone perde la corsa e scende dritto
      const dh = Math.hypot(b.x - HOOP_X, b.z - HOOP_Z);
      if (dh < HALL.rimRadius && b.y < HALL.rimHeight && b.y > HALL.rimHeight - HALL.netDepth) {
        const k = Math.exp(-HALL.netDrag * h);
        b.vx *= k;
        b.vz *= k;
      }
      // Canestro: il centro passa in giù il piano del ferro dentro il cerchio
      if (b.shot && py > HALL.rimHeight && b.y <= HALL.rimHeight && b.vy < 0) {
        const t = (py - HALL.rimHeight) / (py - b.y);
        const cx = px + (b.x - px) * t;
        const cz = pz + (b.z - pz) * t;
        if (Math.hypot(cx - HOOP_X, cz - HOOP_Z) < HALL.rimRadius) this.score(b);
      }
    }
  }

  private floorBounce(b: HallProp) {
    const impact = -b.vy;
    const tramp = this.zones.some((z) => z.kind === "trampoline" && (b.x - z.x) ** 2 + (b.z - z.z) ** 2 <= z.r * z.r);
    const e = tramp ? HALL.trampolineBounce : b.kind === "beachball" ? HALL.beachBounce : HALL.ballBounce;
    b.vy = impact * e;
    if (b.vy < HALL.ballRestSpeed) b.vy = 0;
    b.shot = null; // a terra il tiro è finito
    this.hit(b, impact);
  }

  private ballWalls(b: HallProp) {
    const mx = HALL.width / 2 - b.r;
    const mz = HALL.depth / 2 - b.r;
    if (Math.abs(b.x) > mx) {
      const s = Math.sign(b.x);
      b.x = s * mx;
      if (b.vx * s > 0) {
        this.hit(b, Math.abs(b.vx));
        b.vx = -b.vx * HALL.wallBounce;
      }
    }
    if (Math.abs(b.z) > mz) {
      const s = Math.sign(b.z);
      b.z = s * mz;
      if (b.vz * s > 0) {
        this.hit(b, Math.abs(b.vz));
        b.vz = -b.vz * HALL.wallBounce;
      }
    }
  }

  // Il tabellone è una lastra: punto più vicino della scatola al centro del pallone
  private ballBoard(b: HallProp) {
    const q = {
      x: clamp(b.x, BOARD_X, BOARD_X + HALL.boardThickness),
      y: clamp(b.y, HALL.boardBottom, HALL.boardBottom + HALL.boardHeight),
      z: clamp(b.z, HOOP_Z - HALL.boardWidth / 2, HOOP_Z + HALL.boardWidth / 2),
    };
    const ex = b.x - q.x;
    const ey = b.y - q.y;
    const ez = b.z - q.z;
    const d = Math.hypot(ex, ey, ez);
    if (d >= b.r) return;
    const n = d > 1e-6 ? { x: ex / d, y: ey / d, z: ez / d } : { x: -1, y: 0, z: 0 };
    this.pushOut(b, n, b.r - d);
    this.bounceStatic(b, n, HALL.boardBounce, 1);
    b.touched = true;
  }

  // Il ferro è un anello: punto più vicino della circonferenza al centro del pallone
  private ballRim(b: HallProp) {
    const dx = b.x - HOOP_X;
    const dz = b.z - HOOP_Z;
    const dh = Math.hypot(dx, dz);
    const min = b.r + HALL.rimTube;
    if (Math.abs(b.y - HALL.rimHeight) >= min || Math.abs(dh - HALL.rimRadius) >= min) return;
    const ux = dh > 1e-6 ? dx / dh : 1;
    const uz = dh > 1e-6 ? dz / dh : 0;
    const ex = b.x - (HOOP_X + ux * HALL.rimRadius);
    const ey = b.y - HALL.rimHeight;
    const ez = b.z - (HOOP_Z + uz * HALL.rimRadius);
    const d = Math.hypot(ex, ey, ez);
    if (d >= min) return;
    const n = d > 1e-6 ? { x: ex / d, y: ey / d, z: ez / d } : { x: 0, y: 1, z: 0 };
    this.pushOut(b, n, min - d);
    this.bounceStatic(b, n, HALL.rimBounce, 0.85);
    b.touched = true;
  }

  private score(b: HallProp) {
    const shot = b.shot!;
    b.shot = null;
    const shooter = this.players.get(shot.by);
    if (shooter) shooter.baskets++;
    this.events.push({ type: "basket", id: shot.by, prop: b.id, points: shot.points, swish: !b.touched });
  }

  private ballBall(a: HallProp, b: HallProp) {
    const ex = b.x - a.x;
    const ey = b.y - a.y;
    const ez = b.z - a.z;
    const min = a.r + b.r;
    if (Math.abs(ex) >= min || Math.abs(ey) >= min || Math.abs(ez) >= min) return;
    const d = Math.hypot(ex, ey, ez);
    if (d >= min) return;
    const n = d > 1e-6 ? { x: ex / d, y: ey / d, z: ez / d } : { x: 1, y: 0, z: 0 };
    const ia = 1 / a.mass;
    const ib = 1 / b.mass;
    const k = (min - d) / (ia + ib);
    this.pushOut(a, n, -k * ia);
    this.pushOut(b, n, k * ib);
    const vrel = (b.vx - a.vx) * n.x + (b.vy - a.vy) * n.y + (b.vz - a.vz) * n.z;
    if (vrel >= 0) return;
    const j = (-(1 + HALL.ballBallBounce) * vrel) / (ia + ib);
    a.vx -= n.x * j * ia;
    a.vy -= n.y * j * ia;
    a.vz -= n.z * j * ia;
    b.vx += n.x * j * ib;
    b.vy += n.y * j * ib;
    b.vz += n.z * j * ib;
    this.hit(a, -vrel);
    this.hit(b, -vrel);
  }

  // Pallone contro un pezzo in piedi (cilindro): il pezzo scivola, e se il colpo è forte cade
  private ballPiece(b: HallProp, c: HallProp) {
    const hit = sphereCylinder(b, c.x, c.z, 0, c.h!, c.r);
    if (!hit) return;
    const { n, pen } = hit;
    const ib = 1 / b.mass;
    const ic = 1 / c.mass;
    const horiz = n.x * n.x + n.z * n.z; // il pezzo si muove solo in orizzontale
    const cs = horiz > 0 ? ic / (ib + ic) : 0;
    this.pushOut(b, n, pen * (1 - cs));
    c.x -= n.x * pen * cs;
    c.z -= n.z * pen * cs;
    const vrel = (b.vx - c.vx) * n.x + b.vy * n.y + (b.vz - c.vz) * n.z;
    if (vrel >= 0) return;
    const j = (-(1 + HALL.pieceBounce) * vrel) / (ib + ic * horiz);
    b.vx += n.x * j * ib;
    b.vy += n.y * j * ib;
    b.vz += n.z * j * ib;
    const dvx = -n.x * j * ic;
    const dvz = -n.z * j * ic;
    c.vx += dvx;
    c.vz += dvz;
    if (b.lastBy) c.lastBy = b.lastBy;
    this.hit(b, -vrel);
    if (Math.hypot(dvx, dvz) > HALL.toppleSpeed) this.topple(c, Math.atan2(dvz, dvx), b.lastBy);
  }

  // Pallone contro un giocatore (cilindro): chi ci cammina contro lo calcia, chi ci sta sotto lo prende di testa
  private ballPlayer(b: HallProp, p: HallPlayer) {
    const hit = sphereCylinder(b, p.x, p.z, p.y, HALL.playerHeight, HALL.playerRadius);
    if (!hit) return;
    const { n, pen } = hit;
    this.pushOut(b, n, pen);
    const pvy = p.onGround ? 0 : p.vy;
    const vrel = (b.vx - p.vx) * n.x + (b.vy - pvy) * n.y + (b.vz - p.vz) * n.z;
    if (vrel >= 0) return;
    b.vx -= (1 + HALL.kickBounce) * vrel * n.x;
    b.vy -= (1 + HALL.kickBounce) * vrel * n.y;
    b.vz -= (1 + HALL.kickBounce) * vrel * n.z;
    // Di lato, camminandoci contro: il calcio lo alza un po'
    const into = p.vx * n.x + p.vz * n.z;
    if (n.y < 0.5 && into > 0) b.vy += HALL.kickLift * (b.kind === "beachball" ? 1 : 1 / 3) * Math.min(1, into / HALL.walkSpeed);
    b.lastBy = p.id;
    b.shot = null;
    b.idleMs = 0;
    this.hit(b, -vrel);
  }

  // Fermo fuori posto da troppo: torna alla rastrelliera (o al suo posto)
  private idleBall(b: HallProp, dtMs: number) {
    const still = Math.hypot(b.vx, b.vy, b.vz) < REST_SPEED;
    const home = Math.hypot(b.x - b.homeX, b.y - b.homeY, b.z - b.homeZ) < 5;
    b.idleMs = still && !home ? b.idleMs + dtMs : 0;
    if (b.idleMs >= HALL.ballIdleMs) resetProp(b);
  }

  private stepPieces(list: HallPlayer[], dt: number, dtMs: number) {
    for (const c of this.pieces) {
      const speed = Math.hypot(c.vx, c.vz);
      if (speed > 0) {
        c.x += c.vx * dt;
        c.z += c.vz * dt;
        const next = Math.max(0, speed - HALL.pieceFriction * dt);
        c.vx *= next / speed;
        c.vz *= next / speed;
      }
      const mx = HALL.width / 2 - c.r;
      const mz = HALL.depth / 2 - c.r;
      c.x = clamp(c.x, -mx, mx);
      c.z = clamp(c.z, -mz, mz);
      if (c.toppled) {
        c.tilt = Math.min(Math.PI / 2, c.tilt + ((Math.PI / 2) * dtMs) / HALL.toppleMs);
        continue;
      }
      // Spinto fuori dalla scacchiera: cade verso fuori
      const ox = c.x - CHESS_X;
      const oz = c.z - CHESS_Z;
      if (Math.abs(ox) > CHESS_HALF || Math.abs(oz) > CHESS_HALF)
        this.topple(c, Math.abs(ox) - CHESS_HALF > Math.abs(oz) - CHESS_HALF ? (ox > 0 ? 0 : Math.PI) : oz > 0 ? Math.PI / 2 : -Math.PI / 2, c.lastBy);
    }
    // Pezzo contro pezzo: si spingono, e un urto forte fa cadere anche il vicino
    for (let i = 0; i < this.pieces.length; i++) {
      const a = this.pieces[i];
      if (a.toppled) continue;
      for (let j = i + 1; j < this.pieces.length; j++) {
        const b = this.pieces[j];
        if (b.toppled) continue;
        const dx = b.x - a.x;
        const dz = b.z - a.z;
        const min = a.r + b.r;
        if (Math.abs(dx) >= min || Math.abs(dz) >= min) continue;
        const d = Math.hypot(dx, dz);
        if (d >= min) continue;
        const nx = d > 1e-6 ? dx / d : 1;
        const nz = d > 1e-6 ? dz / d : 0;
        const ia = 1 / a.mass;
        const ib = 1 / b.mass;
        const k = (min - d) / (ia + ib);
        a.x -= nx * k * ia;
        a.z -= nz * k * ia;
        b.x += nx * k * ib;
        b.z += nz * k * ib;
        const vrel = (b.vx - a.vx) * nx + (b.vz - a.vz) * nz;
        if (vrel >= 0) continue;
        const imp = (-(1 + HALL.pieceBetweenBounce) * vrel) / (ia + ib);
        a.vx -= nx * imp * ia;
        a.vz -= nz * imp * ia;
        b.vx += nx * imp * ib;
        b.vz += nz * imp * ib;
        if (imp * ia > HALL.toppleSpeed) this.topple(a, Math.atan2(-nz, -nx), b.lastBy ?? a.lastBy);
        if (imp * ib > HALL.toppleSpeed) this.topple(b, Math.atan2(nz, nx), a.lastBy ?? b.lastBy);
      }
    }
    // La scacchiera si rimette a posto dopo uno scacco matto, o quando è in disordine e nessuno ci gioca
    if (this.chessResetIn !== null) {
      this.chessResetIn -= dtMs;
      if (this.chessResetIn <= 0) this.resetChess();
      return;
    }
    const messy = this.pieces.some((c) => c.toppled || Math.hypot(c.x - c.homeX, c.z - c.homeZ) > 1);
    const near = list.some((p) => Math.abs(p.x - CHESS_X) < CHESS_HALF + 100 && Math.abs(p.z - CHESS_Z) < CHESS_HALF + 100);
    this.chessIdle = messy && !near ? this.chessIdle + dtMs : 0;
    if (this.chessIdle >= HALL.chessIdleResetMs) this.resetChess();
  }

  // Un pezzo cade; se è un re è scacco matto e tra poco si ricomincia
  private topple(c: HallProp, dir: number, by: string | null) {
    if (c.toppled) return;
    c.toppled = true;
    c.tiltDir = dir;
    this.events.push({ type: "topple", prop: c.id, by });
    if (c.piece === "king" && this.chessResetIn === null) {
      this.chessResetIn = HALL.chessResetMs;
      this.events.push({ type: "checkmate", id: by ?? "", color: c.color! });
    }
  }

  // Tutti in piedi sulle case di partenza; i palloni rimasti sulla scacchiera tornano al loro posto
  private resetChess() {
    for (const c of this.pieces) resetProp(c);
    for (const b of this.balls)
      if (!b.holder && Math.abs(b.x - CHESS_X) < CHESS_HALF + b.r && Math.abs(b.z - CHESS_Z) < CHESS_HALF + b.r) resetProp(b);
    this.chessResetIn = null;
    this.chessIdle = 0;
  }

  private resetProps() {
    for (const p of this.players.values()) p.holding = null;
    for (const c of this.props) resetProp(c);
    this.chessResetIn = null;
    this.chessIdle = 0;
  }

  private pushOut(b: HallProp, n: Vec3, d: number) {
    b.x += n.x * d;
    b.y += n.y * d;
    b.z += n.z * d;
  }

  // Rimbalzo su qualcosa che non si muove (ferro, tabellone): keep = quanto resta della velocità di striscio
  private bounceStatic(b: HallProp, n: Vec3, e: number, keep: number) {
    const vn = b.vx * n.x + b.vy * n.y + b.vz * n.z;
    if (vn >= 0) return;
    const tx = b.vx - vn * n.x;
    const ty = b.vy - vn * n.y;
    const tz = b.vz - vn * n.z;
    b.vx = tx * keep - e * vn * n.x;
    b.vy = ty * keep - e * vn * n.y;
    b.vz = tz * keep - e * vn * n.z;
    this.hit(b, -vn);
  }

  // Urto forte: evento per il suono, non più di uno ogni tanto per oggetto
  private hit(b: HallProp, speed: number) {
    if (speed < HALL.propHitSpeed || b.hitMs > 0) return;
    b.hitMs = HALL.propHitCooldownMs;
    this.events.push({ type: "propHit", prop: b.id, speed: Math.round(speed) });
  }

  // --- zone ---

  private inZone(p: HallPlayer, kind: HallZone["kind"]): HallZone | undefined {
    return this.zones.find((z) => z.kind === kind && (p.x - z.x) ** 2 + (p.z - z.z) ** 2 <= z.r * z.r);
  }

  private zonesFor(p: HallPlayer, dtMs: number) {
    if (p.onGround && this.inZone(p, "trampoline")) {
      p.vy = HALL.trampolineSpeed;
      p.onGround = false;
      p.moving = false;
      this.events.push({ type: "bounce", id: p.id });
    }
    p.onThroneZone = p.onGround && !!this.inZone(p, "throne");
    // Si vota e si sceglie fermandosi sopra coi piedi per terra: passando di corsa sopra le altre zone non si cambia niente.
    // I bot non votano
    if (p.bot || !p.onGround || Math.hypot(p.vx, p.vz) > HALL.voteMaxSpeed) {
      p.cageMs = 0;
      return;
    }
    const mode = this.inZone(p, "mode");
    if (mode && p.modeVote !== mode.id) {
      p.modeVote = mode.id as HallMode;
      this.events.push({ type: "vote", id: p.id, what: "mode", value: mode.id });
    }
    const stage = this.inZone(p, "stage");
    if (stage && p.stageVote !== stage.id) {
      p.stageVote = stage.id;
      this.events.push({ type: "vote", id: p.id, what: "stage", value: stage.id });
    }
    const pedestal = this.inZone(p, "fighter");
    if (pedestal && p.characterId !== pedestal.id) {
      p.characterId = pedestal.id;
      p.skinId = "";
      this.events.push({ type: "pick", id: p.id, characterId: p.characterId, skinId: p.skinId });
    } else if (pedestal && p.input.heavy && !p.prev.heavy) {
      // Pesante sul piedistallo: la skin dopo (dopo l'ultima si torna all'aspetto base)
      const skins = ["", ...Object.keys(getCharacter(p.characterId).skins ?? {})];
      p.skinId = skins[(skins.indexOf(p.skinId) + 1) % skins.length];
      this.events.push({ type: "pick", id: p.id, characterId: p.characterId, skinId: p.skinId });
    }
    const cage = this.inZone(p, "botAdd") ?? this.inZone(p, "botRemove");
    if (!cage) {
      p.cageMs = 0;
      return;
    }
    p.cageMs += dtMs;
    if (p.cageMs < HALL.botHoldMs) return;
    p.cageMs = 0; // restando dentro se ne chiama (o manda via) un altro dopo botHoldMs
    const id = cage.kind === "botAdd" ? this.addBot() : this.removeBot();
    if (id) this.events.push({ type: "bot", id, added: cage.kind === "botAdd" });
  }

  // Chi sale sul trono si siede; chi ci sale dopo glielo prende. Scendendo lo si lascia a chi è ancora sopra
  private updateThrone(list: HallPlayer[]) {
    for (const p of this.players.values()) if (p.throne && (p.away || !p.onThroneZone)) p.throne = false;
    const arriving = list.find((p) => p.onThroneZone && !p.wasOnThrone);
    const taker = arriving ?? (list.some((p) => p.throne) ? undefined : list.find((p) => p.onThroneZone));
    if (taker && !taker.throne) {
      for (const q of this.players.values()) q.throne = false;
      taker.throne = true;
      this.events.push({ type: "throne", id: taker.id });
    }
    for (const p of list) p.wasOnThrone = p.onThroneZone;
  }

  // --- partenza ---

  private updateCountdown(dtMs: number) {
    const canStart = this.need() === null;
    if (this.countdown === null) {
      if (!canStart) return;
      this.countdown = HALL.countdownMs;
      this.events.push({ type: "countdown", ms: HALL.countdownMs });
      return;
    }
    if (!canStart) {
      this.countdown = null;
      this.events.push({ type: "cancel" });
      return;
    }
    this.countdown -= dtMs;
    if (this.countdown > 0) return;
    this.countdown = 0;
    for (const p of this.players.values()) this.release(p); // si parte: i palloni restano in sala
    this.choice = this.leading();
    this.events.push({ type: "go", mode: this.choice.mode, stageId: this.choice.stageId });
  }

  // --- aiuti ---

  private voters(): HallPlayer[] {
    return [...this.players.values()].filter((p) => !p.bot && !p.away);
  }

  private flush(): HallEvent[] {
    const events = this.events;
    this.events = [];
    return events;
  }

  private freeSlot(): number {
    const used = new Set([...this.players.values()].map((p) => p.slot));
    for (let i = 0; i < MAX_PLAYERS_PER_ROOM; i++) if (!used.has(i)) return i;
    return 0;
  }

  // I bot aspettano dietro il cerchio, a ventaglio
  private placeBot(p: HallPlayer, index: number) {
    const a = -Math.PI / 2 + (index - (HALL.maxBots - 1) / 2) * 0.55;
    this.reset(p, READY_X + Math.cos(a) * BOT_RING, READY_Z + Math.sin(a) * BOT_RING);
    p.facing = 1;
  }

  private reset(p: HallPlayer, x: number, z: number) {
    p.x = x;
    p.z = z;
    p.y = 0;
    p.vx = p.vy = p.vz = 0;
    p.onGround = true;
    p.moving = false;
    p.stunMs = 0;
    p.cageMs = 0;
    p.throne = false;
    p.onThroneZone = false;
    p.wasOnThrone = false;
    p.input = emptyInput();
    p.prev = emptyInput();
  }

  private rollRandomStage(): string {
    const r = rng(this.seed + this.round * 0x9e3779b1);
    return `${RANDOM_STAGE_PREFIX}${1 + Math.floor(r.next() * MAX_SEED)}`;
  }
}

// --- zona giochi: costruzione e geometria ---

function newProp(id: string, kind: HallPropKind, x: number, y: number, z: number, r: number, mass: number): HallProp {
  return {
    id,
    kind,
    x,
    y,
    z,
    r,
    yaw: 0,
    spin: 0,
    tilt: 0,
    tiltDir: 0,
    holder: null,
    vx: 0,
    vy: 0,
    vz: 0,
    mass,
    homeX: x,
    homeY: y,
    homeZ: z,
    homeYaw: 0,
    lastBy: null,
    shot: null,
    touched: false,
    noPickId: null,
    noPickMs: 0,
    idleMs: 0,
    hitMs: 0,
    toppled: false,
  };
}

// Id stabili: ball-1..3, beach-1..2, chess-w-king, chess-b-queen, chess-w-rook-a, chess-b-pawn-e...
// Scacchi: colonne a-h lungo x (a a sinistra), i bianchi verso la telecamera (traversa 1 a z positivo).
// x, z di un pezzo = centro della base; cadendo ruota attorno alla base verso tiltDir. yaw 0 = guarda verso -z
function makeProps(): HallProp[] {
  const props: HallProp[] = [];
  for (let i = 0; i < HALL.basketballs; i++) {
    const x = HALL.rackX + (i - (HALL.basketballs - 1) / 2) * HALL.rackGap;
    props.push(newProp(`ball-${i + 1}`, "basketball", x, HALL.basketballRadius, HALL.rackZ, HALL.basketballRadius, HALL.basketballMass));
  }
  BEACH_HOME.forEach(([x, z], i) => props.push(newProp(`beach-${i + 1}`, "beachball", x, HALL.beachballRadius, z, HALL.beachballRadius, HALL.beachballMass)));
  for (const color of ["white", "black"] as const) {
    const c = color === "white" ? "w" : "b";
    const side = color === "white" ? 1 : -1;
    const piece = (id: string, kind: ChessPiece, file: number, rank: number) => {
      const spec = HALL.chessPieces[kind];
      const x = CHESS_X + (file - 3.5) * HALL.chessSquare;
      const z = CHESS_Z + side * rank * HALL.chessSquare;
      const p = newProp(id, "chess", x, 0, z, spec.r, spec.mass);
      p.piece = kind;
      p.color = color;
      p.h = spec.h;
      p.yaw = p.homeYaw = color === "white" ? 0 : Math.PI;
      props.push(p);
    };
    BACK_RANK.forEach((kind, f) => piece(kind === "king" || kind === "queen" ? `chess-${c}-${kind}` : `chess-${c}-${kind}-${FILES[f]}`, kind, f, 3.5));
    for (let f = 0; f < 8; f++) piece(`chess-${c}-pawn-${FILES[f]}`, "pawn", f, 2.5);
  }
  return props;
}

function resetProp(c: HallProp) {
  c.x = c.homeX;
  c.y = c.homeY;
  c.z = c.homeZ;
  c.vx = c.vy = c.vz = 0;
  c.yaw = c.homeYaw;
  c.spin = 0;
  c.tilt = 0;
  c.tiltDir = 0;
  c.holder = null;
  c.lastBy = null;
  c.shot = null;
  c.touched = false;
  c.noPickId = null;
  c.noPickMs = 0;
  c.idleMs = 0;
  c.toppled = false;
}

const r3 = (v: number) => Math.round(v * 1000) / 1000;

function propState(c: HallProp): HallPropState {
  const s: HallPropState = {
    id: c.id,
    kind: c.kind,
    x: Math.round(c.x),
    y: Math.round(c.y),
    z: Math.round(c.z),
    r: c.r,
    yaw: r3(c.yaw),
    spin: r3(c.spin),
    tilt: r3(c.tilt),
    tiltDir: r3(c.tiltDir),
    holder: c.holder,
  };
  if (c.kind === "chess") {
    s.piece = c.piece;
    s.color = c.color;
    s.h = c.h;
  }
  return s;
}

// Sfera contro cilindro verticale (base a y0, alto h): normale verso la sfera e quanto entra, o null
function sphereCylinder(b: Vec3 & { r: number }, cx: number, cz: number, y0: number, h: number, rad: number): { n: Vec3; pen: number } | null {
  const dx = b.x - cx;
  const dz = b.z - cz;
  if (Math.abs(dx) >= rad + b.r || Math.abs(dz) >= rad + b.r) return null;
  const d = Math.hypot(dx, dz);
  const top = y0 + h;
  if (d >= rad + b.r || b.y + b.r <= y0 || b.y - b.r >= top) return null;
  const hx = d > 1e-6 ? dx / d : 1;
  const hz = d > 1e-6 ? dz / d : 0;
  if (b.y > top || b.y < y0) {
    // Sopra o sotto: il tappo, o il suo bordo
    const ey = b.y > top ? b.y - top : b.y - y0;
    if (d <= rad) return { n: { x: 0, y: Math.sign(ey), z: 0 }, pen: b.r - Math.abs(ey) };
    const ex = d - rad;
    const e = Math.hypot(ex, ey);
    if (e >= b.r) return null;
    return { n: { x: (hx * ex) / e, y: ey / e, z: (hz * ex) / e }, pen: b.r - e };
  }
  return { n: { x: hx, y: 0, z: hz }, pen: rad + b.r - d };
}

// Velocità per un arco da from a to che scende nel ferro con l'angolo HALL.shotEntryDeg (gravità esatta).
// tan(partenza) = tan(arrivo) + 2·dislivello/distanza: da vicino l'arco è più ripido
function lob(from: Vec3, to: Vec3): Vec3 {
  const g = HALL.gravity;
  const dx = to.x - from.x;
  const dz = to.z - from.z;
  const d = Math.max(1, Math.hypot(dx, dz));
  const dh = to.y - from.y;
  const deg = Math.PI / 180;
  const theta = clamp(Math.atan(Math.tan(HALL.shotEntryDeg * deg) + (2 * dh) / d), 10 * deg, HALL.maxLaunchDeg * deg);
  const den = 2 * Math.cos(theta) ** 2 * (d * Math.tan(theta) - dh);
  if (den <= 0) return { x: 0, y: Math.sqrt(2 * g * Math.max(50, dh + 50)), z: 0 }; // proprio sotto: in su
  const v = Math.sqrt((g * d * d) / den);
  const vh = v * Math.cos(theta);
  return { x: (vh * dx) / d, y: v * Math.sin(theta), z: (vh * dz) / d };
}

function clamp(v: number, min: number, max: number): number {
  return v < min ? min : v > max ? max : v;
}

// Il voto più votato; a pari voti quello di chi ha creato la stanza, se è tra i primi, altrimenti il primo in pianta.
// Nessun voto: fallback
function pickVote<T extends string>(order: T[], votes: (string | null)[], hostVote: string | null, fallback: T): T {
  const count = new Map<string, number>();
  for (const v of votes) if (v !== null) count.set(v, (count.get(v) ?? 0) + 1);
  const best = Math.max(0, ...count.values());
  if (best === 0) return fallback;
  const tied = order.filter((id) => count.get(id) === best);
  if (hostVote && tied.includes(hostVote as T)) return hostVote as T;
  return tied[0] ?? fallback;
}

function approach(v: number, target: number, step: number): number {
  return v < target ? Math.min(target, v + step) : Math.max(target, v - step);
}

// "Marta", "Marta e Luca", "Marta, Luca e Sara", "Marta, Luca e altri 3"
function listNames(names: string[]): string {
  if (names.length === 1) return names[0];
  if (names.length <= 3) return `${names.slice(0, -1).join(", ")} e ${names[names.length - 1]}`;
  return `${names.slice(0, 2).join(", ")} e altri ${names.length - 2}`;
}

// Seme dal codice stanza (FNV-1a, come gli oggetti in match.ts)
function hashSeed(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
  return h >>> 0;
}

const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const shortName = (name: string) =>
  Array.from(graphemes.segment(name), (s) => s.segment)
    .slice(0, 16)
    .join("");
