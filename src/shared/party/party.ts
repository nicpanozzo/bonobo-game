// Bonobo Party (#579): la partita sul tabellone. Solo la macchina a stati, senza rete e senza lottatori:
// Room.ts la fa avanzare, le passa i comandi dei giocatori e, quando qui si arriva al minigioco, costruisce la partita
// (match.ts) e poi le ridà i posti d'arrivo. Il server è l'arbitro: dado, caselle e banane si decidono solo qui.
//
// Un giro: ognuno a turno tira il dado e cammina (all'incrocio sceglie la strada, passando sulla Corona la compra se ha
// le banane), la casella dove si ferma fa il suo effetto. Finiti i turni, un minigioco per tutti (a caso o a voto),
// poi il feedback sul minigioco. Dopo l'ultimo giro i premi e il podio: vince chi ha più Corone, poi più banane.

import { PARTY } from "../constants";
import { rng } from "../stageGenerator";
import type { MinigameInfo, PartyCommand, PartyEvent, PartyPhase, PartyPick, PartyPlayer, PartySnapshot, PartySquare } from "../types";
import { crownSpots, makeBoard } from "./board";

export interface PartyMember {
  id: string;
  name: string;
  characterId: string;
  skinId: string;
  color: number;
  bot: boolean;
}

export interface PartyOptions {
  seed: number;
  rounds: number;
  pick: PartyPick;
  players: PartyMember[];
  minigames: MinigameInfo[]; // quelli che si possono pescare (già filtrati per numero di giocatori)
}

// Un parere su un minigioco appena giocato, da salvare per gli sviluppi futuri (src/server/feedback.ts)
export interface PartyFeedback {
  minigameId: string;
  id: string;
  name: string;
  characterId: string;
  stars: number; // da 1 a 5
  text: string;
  place: number | null; // com'era arrivato nel minigioco
}

// Oggetti da tabellone, comprati in bottega: uno alla volta in tasca, si usano al proprio tiro
export const PARTY_ITEMS: Record<string, { name: string; price: number; text: string; rare?: boolean }> = {
  moka: { name: "Moka", price: 6, text: "tiri due dadi" },
  monopattino: { name: "Monopattino", price: 4, text: "+3 caselle al tiro" },
  ciabatta: { name: "Ciabatta", price: 5, text: "la lanci al primo in classifica: salta il prossimo tiro" },
  telefono: { name: "Telefono di Bassanese", price: 15, text: "ti porta dritto alla Corona", rare: true },
};

interface Member extends PartyMember {
  away: boolean;
  square: number;
  bananas: number;
  crowns: number;
  item: string | null;
  wins: number;
  skip: boolean; // colpito dalla ciabatta: salta il prossimo tiro
}

export class Party {
  readonly squares: PartySquare[];
  phase: PartyPhase = "intro";
  private phaseMs: number = PARTY.introMs; // tempo che resta nella fase (o prima di passare alla prossima)
  private thinkMs = 0; // il bot di turno ci pensa ancora
  round = 1;
  readonly rounds: number;
  readonly pick: PartyPick;
  private order: string[]; // ordine dei turni
  private turn = 0; // indice in order
  private dice: number | null = null;
  private moveLeft = 0;
  private landed = false; // in move: già arrivati, la casella sta facendo effetto
  private members = new Map<string, Member>();
  private crownSquare: number;
  private options: MinigameInfo[] = [];
  private votes: Record<string, string> = {};
  private feedbackDone = new Set<string>();
  private feedback: PartyFeedback[] = [];
  private lastResults: Extract<PartyEvent, { type: "results" }> | null = null;
  private recent: string[] = [];
  private shopList: string[] = [];
  private text: string | null = null;
  private events: PartyEvent[] = [];
  private winnerId: string | null = null;
  private random: () => number;
  // Il minigioco da giocare: Room lo legge in fase minigame, costruisce la partita e poi chiama minigameDone
  minigame: MinigameInfo | null = null;
  private pool: MinigameInfo[];
  finished = false; // il podio è finito: Room riporta tutti in sala

  constructor(o: PartyOptions) {
    this.random = rng(o.seed).next;
    this.squares = makeBoard(o.seed);
    this.rounds = Math.max(PARTY.minRounds, Math.min(PARTY.maxRounds, Math.round(o.rounds)));
    this.pick = o.pick;
    this.pool = o.minigames;
    for (const p of o.players) this.addMember(p);
    // L'ordine dei turni lo decide il dado iniziale, cioè il seme
    this.order = this.shuffle([...this.members.keys()]);
    const spots = crownSpots(this.squares);
    this.crownSquare = spots[Math.floor(spots.length / 2)]; // la prima Corona sta dall'altra parte del tabellone
  }

  private addMember(p: PartyMember) {
    this.members.set(p.id, { ...p, away: false, square: 0, bananas: PARTY.startBananas, crowns: 0, item: null, wins: 0, skip: false });
  }

  // Chi entra a partita in corso parte dalla partenza, con le banane di tutti e senza Corone; gioca dal giro dopo
  addPlayer(p: PartyMember) {
    if (this.members.has(p.id)) return;
    this.addMember(p);
    this.order.push(p.id);
  }

  removePlayer(id: string) {
    if (!this.members.delete(id)) return;
    const wasTurn = this.turnId === id;
    const idx = this.order.indexOf(id);
    this.order.splice(idx, 1);
    if (idx < this.turn) this.turn--;
    if (this.order.length === 0 || !wasTurn) return;
    // Toccava a lui: tocca al prossimo (o si va al minigioco se era l'ultimo)
    if (this.turn >= this.order.length) this.endTurns();
    else this.beginTurn();
  }

  setAway(id: string, away: boolean) {
    const m = this.members.get(id);
    if (m) m.away = away;
  }

  get playerIds(): string[] {
    return [...this.order];
  }

  get turnId(): string | null {
    return ["roll", "move", "path", "shop"].includes(this.phase) ? (this.order[this.turn] ?? null) : null;
  }

  // Un comando di un giocatore: vale solo se tocca a lui o se è il momento giusto
  command(id: string, cmd: PartyCommand) {
    const m = this.members.get(id);
    if (!m) return;
    switch (cmd.kind) {
      case "roll":
        if (this.phase === "roll" && this.turnId === id) this.roll(m, cmd.useItem === true);
        break;
      case "path":
        if (this.phase === "path" && this.turnId === id) this.choosePath(m, cmd.next);
        break;
      case "buy":
        if (this.phase === "shop" && this.turnId === id) this.buy(m, cmd.item);
        break;
      case "vote":
        if (this.phase === "vote" && this.options.some((o) => o.id === cmd.minigameId)) {
          this.votes[id] = cmd.minigameId;
          this.events.push({ type: "vote", id, minigameId: cmd.minigameId });
          if (this.humansDone((p) => !!this.votes[p.id])) this.phaseMs = Math.min(this.phaseMs, 600);
        }
        break;
      case "feedback":
        if (this.phase === "feedback" && !this.feedbackDone.has(id)) this.giveFeedback(m, cmd.stars, cmd.text);
        break;
      case "hall":
        if (this.phase === "podium") this.finished = true;
        break;
    }
  }

  // Tutti gli umani collegati hanno fatto (votato, mandato il feedback)?
  private humansDone(did: (m: Member) => boolean): boolean {
    return [...this.members.values()].every((m) => m.bot || m.away || did(m));
  }

  step(dtMs: number) {
    if (this.finished || this.order.length === 0) return;
    this.phaseMs -= dtMs;
    const turnM = this.turnId ? this.members.get(this.turnId) : undefined;
    // Il bot di turno (o chi è caduto dalla rete) fa da solo dopo averci pensato un attimo
    if (turnM && (turnM.bot || turnM.away) && ["roll", "path", "shop"].includes(this.phase)) {
      this.thinkMs += dtMs;
      if (this.thinkMs >= PARTY.botThinkMs) this.autoAct(turnM);
      return;
    }
    switch (this.phase) {
      case "intro":
        if (this.phaseMs <= 0) this.beginTurn();
        break;
      case "roll":
        if (this.phaseMs <= 0 && turnM) this.roll(turnM, false);
        break;
      case "move":
        if (this.phaseMs <= 0 && turnM) this.walk(turnM);
        break;
      case "path":
        if (this.phaseMs <= 0 && turnM) this.choosePath(turnM, 0);
        break;
      case "shop":
        if (this.phaseMs <= 0 && turnM) this.buy(turnM, null);
        break;
      case "vote":
        for (const m of this.members.values()) if (m.bot && !this.votes[m.id] && this.phaseMs < PARTY.voteMs - PARTY.botThinkMs) this.command(m.id, { kind: "vote", minigameId: this.pickOne(this.options).id });
        if (this.phaseMs <= 0) this.closeVote();
        break;
      case "minigame":
        break; // aspetta minigameDone da Room
      case "feedback":
        if (this.phaseMs <= 0) this.nextRound();
        break;
      case "podium":
        if (this.phaseMs <= 0) this.finished = true;
        break;
    }
  }

  private autoAct(m: Member) {
    this.thinkMs = 0;
    if (this.phase === "roll") this.roll(m, !!m.item && (m.item !== "telefono" || m.bananas >= PARTY.crownPrice));
    else if (this.phase === "path") this.choosePath(m, this.random() < 0.5 ? 0 : 1);
    else if (this.phase === "shop") {
      // Il bot compra quello che si può permettere lasciando le banane per la Corona, se gli mancano poche
      const affordable = this.shopList.filter((k) => PARTY_ITEMS[k].price <= m.bananas - (m.bananas >= PARTY.crownPrice ? PARTY.crownPrice : 0));
      this.buy(m, m.item ? null : (affordable[0] ?? null));
    }
  }

  private setPhase(phase: PartyPhase, ms: number) {
    this.phase = phase;
    this.phaseMs = ms;
    this.thinkMs = 0;
  }

  private beginTurn() {
    const m = this.members.get(this.order[this.turn]);
    if (!m) return this.endTurns();
    this.dice = null;
    this.moveLeft = 0;
    this.landed = false;
    if (m.skip) {
      // La ciabatta: si salta il tiro, ma dopo un attimo per far vedere perché
      m.skip = false;
      this.text = `${m.name} salta il tiro: ha ancora la ciabatta in faccia`;
      this.setPhase("move", PARTY.squareMs);
      this.landed = true;
      return;
    }
    this.text = null;
    this.setPhase("roll", PARTY.rollMs);
  }

  private roll(m: Member, useItem: boolean) {
    const item = useItem ? m.item : null;
    if (item) m.item = null;
    const die = () => 1 + Math.floor(this.random() * PARTY.dice);
    let value = die();
    if (item === "moka") value += die();
    if (item === "monopattino") value += 3;
    this.events.push({ type: "roll", id: m.id, value, ...(item && { item }) });
    if (item === "ciabatta") {
      const target = this.standings().find((p) => p.id !== m.id);
      if (target) {
        const t = this.members.get(target.id)!;
        t.skip = true;
        this.events.push({ type: "item", id: m.id, item, targetId: t.id });
      }
    }
    if (item === "telefono") {
      // Il Bassanese ti accompagna alla Corona: si arriva lì e si compra (se si può), senza tirare
      this.events.push({ type: "item", id: m.id, item });
      m.square = this.crownSquare;
      this.events.push({ type: "step", id: m.id, square: m.square });
      this.dice = 0;
      this.moveLeft = 0;
      this.text = `${m.name} chiama il Bassanese: dritto alla Corona!`;
      this.tryCrown(m);
      this.landed = true;
      this.setPhase("move", PARTY.squareMs);
      return;
    }
    this.dice = value;
    this.moveLeft = value;
    this.text = item ? `${m.name} usa ${PARTY_ITEMS[item].name}: ${value}!` : null;
    this.setPhase("move", PARTY.stepMs * 2);
  }

  // Un passo di cammino; all'incrocio ci si ferma a scegliere; all'arrivo la casella fa effetto
  private walk(m: Member) {
    if (this.landed) return this.nextTurn();
    if (this.moveLeft <= 0) return this.land(m);
    const next = this.squares[m.square].next;
    if (next.length > 1) {
      this.setPhase("path", m.bot || m.away ? PARTY.botThinkMs : PARTY.pathMs);
      return;
    }
    this.stepTo(m, next[0]);
  }

  private stepTo(m: Member, square: number) {
    m.square = square;
    this.moveLeft--;
    this.events.push({ type: "step", id: m.id, square });
    if (square === this.crownSquare) this.tryCrown(m);
    // Passando dalla partenza: una mancia, così il giro lungo conviene anche lui
    if (square === 0) {
      m.bananas += PARTY.squareBananas;
      this.events.push({ type: "square", id: m.id, kind: "start", bananas: PARTY.squareBananas, text: `${m.name} passa dal via: +${PARTY.squareBananas}` });
    }
    this.setPhase("move", this.moveLeft > 0 ? PARTY.stepMs : PARTY.stepMs * 2);
  }

  private choosePath(m: Member, index: number) {
    const next = this.squares[m.square].next;
    this.stepTo(m, next[Math.max(0, Math.min(next.length - 1, Math.round(index) || 0))]);
  }

  private tryCrown(m: Member) {
    if (m.bananas < PARTY.crownPrice) {
      this.text = `${m.name} passa sulla Corona ma non ha ${PARTY.crownPrice} banane`;
      return;
    }
    m.bananas -= PARTY.crownPrice;
    m.crowns++;
    const spots = crownSpots(this.squares).filter((s) => s !== this.crownSquare && ![...this.members.values()].some((p) => p.square === s));
    this.crownSquare = spots.length > 0 ? this.pickOne(spots) : this.crownSquare;
    this.events.push({ type: "crown", id: m.id, square: this.crownSquare });
    this.text = `${m.name} compra la Corona!`;
  }

  // Arrivati: l'effetto della casella
  private land(m: Member) {
    this.landed = true;
    const sq = this.squares[m.square];
    let delta = 0;
    let text = "";
    switch (sq.kind) {
      case "banana":
        delta = PARTY.squareBananas;
        text = `${m.name}: +${delta} banane`;
        break;
      case "buccia":
        delta = -Math.min(m.bananas, PARTY.squareBananas);
        text = `${m.name} scivola su una buccia: ${delta} banane`;
        break;
      case "evento":
        text = this.event(m);
        break;
      case "bottega":
        this.openShop(m);
        return;
      case "start":
        text = `${m.name} si riposa alla partenza`;
        break;
    }
    m.bananas += delta;
    this.events.push({ type: "square", id: m.id, kind: sq.kind, bananas: delta, text });
    this.text = text;
    this.setPhase("move", PARTY.squareMs);
  }

  // Le carte Evento: piccole sorprese che rimescolano la classifica senza decidere la partita
  private event(m: Member): string {
    const all = [...this.members.values()];
    const card = Math.floor(this.random() * 6);
    switch (card) {
      case 0:
        for (const p of all) p.bananas += PARTY.squareBananas;
        return `Piovono banane dal cielo: +${PARTY.squareBananas} a tutti!`;
      case 1: {
        const rich = [...all].sort((a, b) => b.bananas - a.bananas)[0];
        const poor = [...all].sort((a, b) => a.bananas - b.bananas)[0];
        const taken = Math.min(5, rich.bananas);
        rich.bananas -= taken;
        poor.bananas += taken;
        return `Passa il Bassanese: prende ${taken} banane a ${rich.name} e le dà a ${poor.name}`;
      }
      case 2: {
        const others = all.filter((p) => p.id !== m.id);
        if (others.length === 0) return `${m.name} trova un posto tranquillo`;
        const o = this.pickOne(others);
        [m.square, o.square] = [o.square, m.square];
        this.events.push({ type: "step", id: m.id, square: m.square }, { type: "step", id: o.id, square: o.square });
        return `Scambio! ${m.name} e ${o.name} si scambiano di posto`;
      }
      case 3:
        m.bananas += 6;
        return `La nonna allunga una mancia a ${m.name}: +6`;
      case 4: {
        const fine = Math.min(5, m.bananas);
        m.bananas -= fine;
        return `Multa per divieto di sosta a ${m.name}: -${fine}`;
      }
      default: {
        const to = this.pickOne(crownSpots(this.squares));
        m.square = to;
        this.events.push({ type: "step", id: m.id, square: to });
        return `Un tornado porta ${m.name} dall'altra parte`;
      }
    }
  }

  private openShop(m: Member) {
    // Tre oggetti normali, e a volte il raro al posto di uno
    const common = Object.keys(PARTY_ITEMS).filter((k) => !PARTY_ITEMS[k].rare);
    const rare = Object.keys(PARTY_ITEMS).filter((k) => PARTY_ITEMS[k].rare);
    this.shopList = this.random() < 0.34 && rare.length > 0 ? [...common.slice(0, 2), rare[0]] : common;
    this.text = `${m.name} entra in bottega`;
    this.setPhase("shop", m.bot || m.away ? PARTY.botThinkMs : PARTY.shopMs);
  }

  private buy(m: Member, item: string | null) {
    const spec = item ? PARTY_ITEMS[item] : undefined;
    if (item && spec && this.shopList.includes(item) && m.bananas >= spec.price) {
      m.bananas -= spec.price;
      m.item = item; // una sola cosa in tasca: la nuova prende il posto della vecchia
      this.events.push({ type: "item", id: m.id, item });
      this.text = `${m.name} compra ${spec.name}`;
    } else this.text = `${m.name} esce dalla bottega a mani vuote`;
    this.shopList = [];
    this.setPhase("move", PARTY.squareMs);
  }

  private nextTurn() {
    this.turn++;
    if (this.turn >= this.order.length) return this.endTurns();
    this.beginTurn();
  }

  // Tutti hanno tirato: si sceglie il minigioco
  private endTurns() {
    this.turn = 0;
    this.dice = null;
    const fresh = this.pool.filter((g) => !this.recent.includes(g.id));
    const pool = fresh.length >= (this.pick === "vote" ? PARTY.voteOptions : 1) ? fresh : this.pool;
    if (this.pick === "vote") {
      this.options = this.shuffle([...pool]).slice(0, PARTY.voteOptions);
      this.votes = {};
      this.text = "Votate il minigioco!";
      this.setPhase("vote", PARTY.voteMs);
    } else {
      this.startMinigame(this.pickOne(pool));
    }
  }

  private closeVote() {
    const count = new Map<string, number>();
    for (const v of Object.values(this.votes)) count.set(v, (count.get(v) ?? 0) + 1);
    const best = Math.max(0, ...count.values());
    const top = this.options.filter((o) => (count.get(o.id) ?? 0) === best);
    this.startMinigame(this.pickOne(top));
  }

  private startMinigame(g: MinigameInfo) {
    this.minigame = g;
    this.options = [g];
    this.recent = [...this.recent, g.id].slice(-PARTY.recentMinigames);
    this.events.push({ type: "minigame", minigameId: g.id });
    this.text = g.title;
    this.setPhase("minigame", PARTY.revealMs);
  }

  // Room: il tempo del cartellone è finito, si può costruire la partita del minigioco
  get minigameReady(): boolean {
    return this.phase === "minigame" && this.phaseMs <= 0 && !!this.minigame;
  }

  // Room: il minigioco è finito con questi posti (1 = primo); chi non c'era non prende niente
  minigameDone(places: Record<string, number>) {
    if (this.phase !== "minigame" || !this.minigame) return;
    const bananas: Record<string, number> = {};
    for (const [id, place] of Object.entries(places)) {
      const m = this.members.get(id);
      if (!m) continue;
      const prize = PARTY.placeBananas[place - 1] ?? 0;
      m.bananas += prize;
      bananas[id] = prize;
      if (place === 1) m.wins++;
    }
    this.lastResults = { type: "results", minigameId: this.minigame.id, places: { ...places }, bananas };
    this.events.push(this.lastResults);
    this.feedbackDone = new Set([...this.members.values()].filter((m) => m.bot).map((m) => m.id));
    this.text = "Com'era il minigioco?";
    this.setPhase("feedback", PARTY.feedbackMs);
    if (this.humansDone((p) => this.feedbackDone.has(p.id))) this.phaseMs = 800; // solo bot (o tutti caduti): non c'è niente da aspettare
  }

  private giveFeedback(m: Member, stars: number, text: string) {
    this.feedbackDone.add(m.id);
    this.events.push({ type: "feedback", id: m.id });
    const s = Math.round(stars);
    const clean = String(text ?? "").trim().slice(0, PARTY.feedbackMaxChars);
    // Zero stelle e niente testo = ha saltato: non si salva niente
    if (this.minigame && (s >= 1 || clean)) {
      this.feedback.push({ minigameId: this.minigame.id, id: m.id, name: m.name, characterId: m.characterId, stars: Math.max(0, Math.min(5, s)), text: clean, place: this.lastResults?.places[m.id] ?? null });
    }
    if (this.humansDone((p) => this.feedbackDone.has(p.id))) this.phaseMs = Math.min(this.phaseMs, 800);
  }

  // Room: i pareri arrivati da salvare (e li toglie da qui)
  drainFeedback(): PartyFeedback[] {
    const out = this.feedback;
    this.feedback = [];
    return out;
  }

  private nextRound() {
    this.minigame = null;
    this.options = [];
    if (this.round >= this.rounds) return this.podium();
    this.round++;
    this.text = `Giro ${this.round} di ${this.rounds}`;
    this.beginTurn();
  }

  // Fine: i premi a sorpresa, poi il podio
  private podium() {
    const all = [...this.members.values()];
    const bonus = (score: (m: Member) => number, label: string) => {
      const best = Math.max(...all.map(score));
      if (best <= 0) return [];
      const winners = all.filter((m) => score(m) === best);
      for (const m of winners) m.crowns += PARTY.bonusCrowns;
      return [`${label}: ${winners.map((m) => m.name).join(", ")}`];
    };
    const awards = [...bonus((m) => m.wins, "Re dei minigiochi"), ...bonus((m) => m.bananas, "Il più ricco")];
    this.winnerId = this.standings()[0]?.id ?? null;
    this.events.push({ type: "end", winnerId: this.winnerId });
    this.text = awards.length > 0 ? `Premi: ${awards.join(" · ")}` : null;
    this.setPhase("podium", PARTY.podiumMs);
  }

  // Classifica: Corone, poi banane, poi minigiochi vinti
  standings(): Member[] {
    return [...this.members.values()].sort((a, b) => b.crowns - a.crowns || b.bananas - a.bananas || b.wins - a.wins);
  }

  snapshot(t: number): PartySnapshot {
    const ranked = this.standings();
    const place = (m: Member) => {
      const i = ranked.indexOf(m);
      const first = ranked.findIndex((r) => r.crowns === m.crowns && r.bananas === m.bananas);
      return (first >= 0 ? first : i) + 1;
    };
    const players: PartyPlayer[] = this.order.map((id) => {
      const m = this.members.get(id)!;
      return { id, name: m.name, characterId: m.characterId, skinId: m.skinId, color: m.color, bot: m.bot, away: m.away, square: m.square, bananas: m.bananas, crowns: m.crowns, item: m.item, wins: m.wins, place: place(m) };
    });
    const events = this.events;
    this.events = [];
    return {
      t,
      phase: this.phase,
      phaseLeftMs: Math.max(0, Math.round(this.phaseMs)),
      round: this.round,
      rounds: this.rounds,
      pick: this.pick,
      turnId: this.turnId,
      dice: this.dice,
      moveLeft: this.moveLeft,
      squares: this.squares,
      crownSquare: this.crownSquare,
      players,
      options: this.options,
      votes: { ...this.votes },
      feedbackDone: [...this.feedbackDone],
      lastResults: this.lastResults,
      shop: this.shopList.map((k) => ({ item: k, price: PARTY_ITEMS[k].price, name: `${PARTY_ITEMS[k].name}: ${PARTY_ITEMS[k].text}` })),
      text: this.text,
      events,
      winnerId: this.winnerId,
    };
  }

  private pickOne<T>(list: readonly T[]): T {
    return list[Math.floor(this.random() * list.length) % list.length];
  }

  private shuffle<T>(list: T[]): T[] {
    for (let i = list.length - 1; i > 0; i--) {
      const j = Math.floor(this.random() * (i + 1));
      [list[i], list[j]] = [list[j], list[i]];
    }
    return list;
  }
}
