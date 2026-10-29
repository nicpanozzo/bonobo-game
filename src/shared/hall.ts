// Sala d'attesa 3D: ci si muove davvero e si sceglie camminando (modalità, arena, lottatore, pronti).
// Pura e deterministica come la fisica: niente rete, niente orologio, niente Math.random.
// Il server la fa avanzare a passo fisso (src/server/Room.ts) e manda HallSnapshot.
// Coordinate in cm: x a destra, z verso la telecamera (su = -z), y in alto; (0, 0, 0) al centro del pavimento.

import { CHARACTERS, getCharacter, skinFor } from "./characters";
import { COLORS, HALL, MAX_PLAYERS_PER_ROOM } from "./constants";
import { emptyInput } from "./physics";
import { MAX_SEED, RANDOM_STAGE_PREFIX, rng } from "./stageGenerator";
import { DEFAULT_STAGE_ID, STAGES } from "./stages";
import type { BoardRow, HallEvent, HallMode, HallPlayerState, HallSnapshot, HallZone, InputState, MatchRules } from "./types";

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
// negli angoli in fondo il trono e il gong
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
  return zones;
}

const READY_X = 0;
const READY_Z = 100;
const ENTRANCE_Z = HALL.depth / 2 - 120; // si entra davanti, al centro
const ENTRANCE_STEP = 120; // cm tra un nuovo arrivato e l'altro
const BOT_RING = HALL.readyRadius + 90; // i bot aspettano dietro il cerchio, già "pronti"
const RETURN_RING = HALL.readyRadius + HALL.playerRadius + 40; // al ritorno dalla partita: appena fuori dal cerchio
const MOVING_SPEED = 30; // cm/s sotto cui si è fermi (posa) e non si cammina

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
    if (pressed("light") && p.shoveCooldown <= 0 && p.stunMs <= 0) this.shove(p);
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
      targets.push(t.id);
    }
    this.events.push({ type: "shove", id: p.id, targets });
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
