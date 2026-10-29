import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CHARACTERS } from "./characters";
import { HALL, MAX_PLAYERS_PER_ROOM, TICK_RATE } from "./constants";
import { Hall, hallFighterIds, hallLayout, hallStageIds, RANDOM_STAGE_ZONE } from "./hall";
import { emptyInput } from "./physics";
import { DEFAULT_RULES } from "./rules";
import { getStage } from "./stages";
import type { HallEvent, HallPropState, HallZone, InputState } from "./types";

const DT = 1000 / TICK_RATE;

function run(hall: Hall, ms: number): HallEvent[] {
  const events: HallEvent[] = [];
  for (let t = 0; t < ms; t += DT) events.push(...hall.step(DT));
  return events;
}

const keys = (k: Partial<InputState>): InputState => ({ ...emptyInput(), ...k });
const pos = (hall: Hall, id: string) => hall.roster().find((p) => p.id === id)!;
const zone = (hall: Hall, kind: HallZone["kind"], id?: string) => hall.zones.find((z) => z.kind === kind && (id === undefined || z.id === id))!;

// Tiene premute le frecce verso (x, z) finché ci si arriva: come farebbe chi gioca
function walkTo(hall: Hall, id: string, x: number, z: number, maxMs = 8000): HallEvent[] {
  const events: HallEvent[] = [];
  for (let t = 0; t < maxMs; t += DT) {
    const p = pos(hall, id);
    const dx = x - p.x;
    const dz = z - p.z;
    if (Math.hypot(dx, dz) < 25 && p.onGround) break;
    hall.setInput(id, keys({ right: dx > 15, left: dx < -15, down: dz > 15, up: dz < -15 }));
    events.push(...hall.step(DT));
  }
  hall.setInput(id, emptyInput());
  events.push(...run(hall, 400)); // si ferma
  return events;
}
const walkInto = (hall: Hall, id: string, z: HallZone) => walkTo(hall, id, z.x, z.z);

function twoHumans(seed = "prova") {
  const hall = new Hall({ seed });
  hall.addPlayer("a", "Marta", "default", undefined, { host: true });
  hall.addPlayer("b", "Luca", "elvedeo");
  hall.step(DT);
  return hall;
}

describe("sala d'attesa: pianta", () => {
  it("le zone stanno sul pavimento e non si sovrappongono", () => {
    const zones = hallLayout();
    for (const z of zones) {
      assert.ok(Math.abs(z.x) + z.r <= HALL.width / 2, `${z.id} esce a destra o a sinistra`);
      assert.ok(Math.abs(z.z) + z.r <= HALL.depth / 2, `${z.id} esce davanti o dietro`);
    }
    // Il canestro sta dentro il suo campo per forza; tutto il resto non si tocca
    const nested = (a: HallZone, b: HallZone) => [a.kind, b.kind].sort().join() === "court,hoop";
    for (let i = 0; i < zones.length; i++)
      for (let j = i + 1; j < zones.length; j++) {
        const a = zones[i];
        const b = zones[j];
        if (nested(a, b)) continue;
        assert.ok(Math.hypot(a.x - b.x, a.z - b.z) >= a.r + b.r, `${a.id} e ${b.id} si sovrappongono`);
      }
  });

  it("una pedana per modalità, un portale per arena della lobby (con la casuale), un piedistallo per lottatore", () => {
    const zones = hallLayout();
    assert.deepEqual(zones.filter((z) => z.kind === "mode").map((z) => z.id), ["ffa", "teams", "flag", "race"]);
    assert.deepEqual(zones.filter((z) => z.kind === "stage").map((z) => z.id), hallStageIds());
    assert.ok(hallStageIds().includes(RANDOM_STAGE_ZONE));
    assert.ok(!hallStageIds().includes("padova-palazzo"), "le arene nascoste restano fuori");
    assert.deepEqual(zones.filter((z) => z.kind === "fighter").map((z) => z.id), Object.keys(CHARACTERS));
    for (const k of ["ready", "botAdd", "botRemove", "gong", "throne"] as const) assert.equal(zones.filter((z) => z.kind === k).length, 1);
    assert.equal(zones.filter((z) => z.kind === "trampoline").length, 2);
    for (const k of ["hoop", "court", "chessboard"] as const) assert.equal(zones.filter((z) => z.kind === k).length, 1);
    assert.equal(new Set(zones.map((z) => `${z.kind}:${z.id}`)).size, zones.length, "id unici");
    assert.ok(zones.every((z) => z.label.length > 0));
  });

  it("chi entra spunta all'ingresso, davanti, e non sopra un altro", () => {
    const hall = twoHumans();
    const a = pos(hall, "a");
    const b = pos(hall, "b");
    assert.ok(a.z > HALL.depth / 4 && b.z > HALL.depth / 4);
    assert.ok(Math.hypot(a.x - b.x, a.z - b.z) >= HALL.playerRadius * 2);
    assert.equal(a.host, true);
    assert.equal(b.host, false);
  });
});

describe("sala d'attesa: movimento", () => {
  it("destra = +x, su = -z, giù = +z; si guarda dove si va e si cammina", () => {
    const hall = twoHumans();
    const start = { ...pos(hall, "a") };
    hall.setInput("a", keys({ right: true, up: true }));
    run(hall, 500);
    const p = pos(hall, "a");
    assert.ok(p.x > start.x + 100);
    assert.ok(p.z < start.z - 100);
    assert.equal(p.facing, 1);
    assert.equal(p.moving, true);
    hall.setInput("a", keys({ left: true }));
    run(hall, 300);
    assert.equal(pos(hall, "a").facing, -1);
    hall.setInput("a", keys({ down: true }));
    const z0 = pos(hall, "a").z;
    run(hall, 200);
    assert.ok(pos(hall, "a").z > z0);
  });

  it("in diagonale non si va più veloci della camminata", () => {
    const hall = twoHumans();
    const s = { ...pos(hall, "a") };
    hall.setInput("a", keys({ left: true, up: true }));
    run(hall, 1000);
    const p = pos(hall, "a");
    assert.ok(Math.hypot(p.x - s.x, p.z - s.z) <= HALL.walkSpeed * 1.0 + 1);
  });

  it("senza tasti si frena e ci si ferma", () => {
    const hall = twoHumans();
    hall.setInput("a", keys({ up: true }));
    run(hall, 500);
    hall.setInput("a", emptyInput());
    run(hall, 400);
    const z = pos(hall, "a").z;
    run(hall, 300);
    assert.equal(pos(hall, "a").z, z);
    assert.equal(pos(hall, "a").moving, false);
  });

  it("i muri tengono sul pavimento", () => {
    const hall = twoHumans();
    hall.setInput("a", keys({ left: true, up: true }));
    run(hall, 10_000);
    const p = pos(hall, "a");
    assert.equal(p.x, -HALL.width / 2 + HALL.playerRadius);
    assert.equal(p.z, -HALL.depth / 2 + HALL.playerRadius);
    hall.setInput("b", keys({ right: true, down: true }));
    run(hall, 10_000);
    assert.equal(pos(hall, "b").x, HALL.width / 2 - HALL.playerRadius);
    assert.equal(pos(hall, "b").z, HALL.depth / 2 - HALL.playerRadius);
  });

  it("salto: hop, in aria, poi land", () => {
    const hall = twoHumans();
    hall.setInput("a", keys({ jump: true }));
    const up = run(hall, 100);
    assert.ok(up.some((e) => e.type === "hop" && e.id === "a"));
    assert.ok(pos(hall, "a").y > 0);
    assert.equal(pos(hall, "a").onGround, false);
    const down = run(hall, 1500);
    assert.ok(down.some((e) => e.type === "land" && e.id === "a"));
    assert.equal(pos(hall, "a").y, 0);
    assert.ok(!down.some((e) => e.type === "hop"), "tenendo il tasto non si risalta");
  });

  it("due giocatori non si sovrappongono", () => {
    const hall = twoHumans();
    const b = pos(hall, "b");
    walkTo(hall, "a", b.x, b.z, 3000);
    const a = pos(hall, "a");
    const b2 = pos(hall, "b");
    assert.ok(Math.hypot(a.x - b2.x, a.z - b2.z) >= HALL.playerRadius * 2 - 1);
  });

  it("spinta: chi è vicino vola via senza comandare, con ricarica", () => {
    const hall = twoHumans();
    const b = pos(hall, "b");
    walkTo(hall, "a", b.x + 100, b.z);
    hall.setInput("a", keys({ light: true }));
    const events = run(hall, DT);
    const shove = events.find((e) => e.type === "shove");
    assert.deepEqual(shove, { type: "shove", id: "a", targets: ["b"] });
    assert.ok(pos(hall, "b").stunMs > 0);
    const before = pos(hall, "b").x;
    hall.setInput("b", keys({ right: true })); // non comanda: vola via comunque
    run(hall, 200);
    assert.ok(pos(hall, "b").x < before - 50);
    // Tenendo premuto non si spinge di nuovo; ripremendo prima della ricarica nemmeno
    hall.setInput("a", emptyInput());
    run(hall, DT);
    hall.setInput("a", keys({ light: true }));
    assert.ok(!run(hall, DT).some((e) => e.type === "shove"));
  });

  it("trampolino: si rimbalza in alto", () => {
    const hall = twoHumans();
    const events = walkInto(hall, "a", zone(hall, "trampoline"));
    assert.ok(events.some((e) => e.type === "bounce" && e.id === "a"));
  });

  it("provocazione tenuta = inchino", () => {
    const hall = twoHumans();
    hall.setInput("a", keys({ taunt: true }));
    hall.step(DT);
    assert.equal(pos(hall, "a").emote, true);
  });
});

describe("sala d'attesa: voti e scelte", () => {
  it("salire su una pedana vota la modalità e il voto resta scendendo", () => {
    const hall = twoHumans();
    const events = walkInto(hall, "a", zone(hall, "mode", "flag"));
    assert.ok(events.some((e) => e.type === "vote" && e.what === "mode" && e.value === "flag"));
    walkTo(hall, "a", 0, 300);
    assert.equal(pos(hall, "a").modeVote, "flag");
    assert.equal(hall.leading().mode, "flag");
    const snap = hall.snapshot(0, [], [], DEFAULT_RULES);
    assert.deepEqual(snap.votes.mode, { flag: 1 });
    assert.equal(snap.rules.mode, "flag");
  });

  it("portale: vota l'arena; piedistallo: cambia lottatore, il pesante cambia skin", () => {
    const hall = twoHumans();
    walkInto(hall, "a", zone(hall, "stage", "bologna"));
    assert.equal(pos(hall, "a").stageVote, "bologna");
    assert.equal(hall.leading().stageId, "bologna");
    const events = walkInto(hall, "b", zone(hall, "fighter", "lampione"));
    assert.ok(events.some((e) => e.type === "pick" && e.id === "b" && e.characterId === "lampione" && e.skinId === ""));
    assert.deepEqual(hall.fighter("b"), { characterId: "lampione", skinId: "" });
    hall.setInput("b", keys({ heavy: true }));
    hall.step(DT);
    assert.deepEqual(hall.fighter("b"), { characterId: "lampione", skinId: "jax" });
    hall.setInput("b", emptyInput());
    hall.step(DT);
    hall.setInput("b", keys({ heavy: true }));
    hall.step(DT);
    assert.deepEqual(hall.fighter("b"), { characterId: "lampione", skinId: "" }, "dopo l'ultima skin si torna all'aspetto base");
  });

  it("pari voti: vince la scelta di chi ha creato la stanza", () => {
    const hall = twoHumans();
    walkInto(hall, "b", zone(hall, "mode", "teams"));
    walkInto(hall, "a", zone(hall, "mode", "race"));
    assert.equal(hall.leading().mode, "race");
    // Senza il voto del padrone di casa tra i primi, il primo in pianta
    const other = new Hall({ seed: "x" });
    other.addPlayer("h", "Host", undefined, undefined, { host: true });
    other.addPlayer("p", "P");
    other.addPlayer("q", "Q");
    walkInto(other, "p", zone(other, "mode", "flag"));
    walkInto(other, "q", zone(other, "mode", "teams"));
    assert.equal(other.leading().mode, "teams");
  });

  it("senza voti: la modalità e l'arena di chi ha creato la stanza", () => {
    assert.deepEqual(new Hall({ seed: "x" }).leading().mode, "ffa");
    const hall = new Hall({ seed: "x", defaultMode: "teams", defaultStageId: "fabbrica" });
    assert.deepEqual(hall.leading(), { mode: "teams", stageId: "fabbrica" });
    assert.equal(new Hall({ seed: "x", defaultStageId: "non-esiste" }).leading().stageId, "palco");
  });

  it("la casuale diventa un'arena generata, uguale per lo stesso codice e diversa al giro dopo", () => {
    const a = new Hall({ seed: "stanza", defaultStageId: "casuale-12" });
    const b = new Hall({ seed: "stanza", defaultStageId: "casuale-99" });
    const id = a.leading().stageId;
    assert.match(id, /^casuale-\d+$/);
    assert.equal(b.leading().stageId, id);
    assert.equal(getStage(id).id, id, "il server la sa generare");
    a.regroup();
    assert.notEqual(a.leading().stageId, id);
    assert.notEqual(new Hall({ seed: "altra", defaultStageId: "casuale-1" }).leading().stageId, id);
  });

  it("chi è caduto dalla rete non vota e non fa aspettare", () => {
    const hall = twoHumans();
    walkInto(hall, "b", zone(hall, "mode", "flag"));
    hall.setAway("b", true);
    assert.equal(hall.leading().mode, "ffa");
    hall.addBot();
    walkInto(hall, "a", zone(hall, "ready"));
    assert.ok(hall.countdownMs !== null);
  });
});

describe("sala d'attesa: bot", () => {
  it("fermi nella gabbia si chiama un bot, nell'altra lo si manda via", () => {
    const hall = twoHumans();
    const add = zone(hall, "botAdd");
    const events = walkTo(hall, "a", add.x, add.z);
    run(hall, HALL.botHoldMs);
    events.push(...run(hall, DT));
    const bots = hall.botIds();
    assert.ok(bots.length >= 1);
    assert.ok(hall.roster().find((p) => p.id === bots[0])?.ready, "i bot sono sempre pronti");
    assert.equal(hall.roster().find((p) => p.id === bots[0])?.characterId, "bonobot", "il primo bot è Bonobot");
    // Restando dentro se ne chiamano altri, fino al massimo
    run(hall, HALL.botHoldMs * (HALL.maxBots + 2));
    assert.equal(hall.botIds().length, HALL.maxBots);
    const chars = hall.roster().filter((p) => p.bot).map((p) => p.characterId);
    assert.equal(new Set(chars).size, chars.length, "lottatori a rotazione");
    const rem = zone(hall, "botRemove");
    const out = walkTo(hall, "a", rem.x, rem.z);
    out.push(...run(hall, HALL.botHoldMs + DT));
    assert.ok(out.some((e) => e.type === "bot" && !e.added));
    assert.ok(hall.botIds().length < HALL.maxBots);
  });

  it("una stanza piena non prende bot", () => {
    const hall = new Hall({ seed: "piena" });
    for (let i = 0; i < MAX_PLAYERS_PER_ROOM; i++) hall.addPlayer(`p${i}`, `P${i}`);
    assert.equal(hall.addBot(), null);
    assert.equal(hall.size, MAX_PLAYERS_PER_ROOM);
  });
});

describe("sala d'attesa: partenza", () => {
  it("da soli serve un altro lottatore, anche dentro il cerchio", () => {
    const hall = new Hall({ seed: "solo" });
    hall.addPlayer("a", "Marta");
    assert.equal(hall.need(), "Serve un altro lottatore: manda il link o chiama un bot dalla gabbia");
    walkInto(hall, "a", zone(hall, "ready"));
    assert.equal(hall.countdownMs, null);
  });

  it("need dice chi manca nel cerchio", () => {
    const hall = new Hall({ seed: "nomi" });
    for (const n of ["Marta", "Luca", "Sara", "Ugo", "Ada"]) hall.addPlayer(n, n);
    assert.equal(hall.need(), "Mancano Marta, Luca e altri 3 nel cerchio");
    hall.removePlayer("Ugo");
    hall.removePlayer("Ada");
    assert.equal(hall.need(), "Mancano Marta, Luca e Sara nel cerchio");
    hall.removePlayer("Sara");
    assert.equal(hall.need(), "Mancano Marta e Luca nel cerchio");
    walkInto(hall, "Marta", zone(hall, "ready"));
    assert.equal(hall.need(), "Manca Luca nel cerchio");
  });

  it("tutti nel cerchio: conto alla rovescia; chi esce lo annulla; a zero go e result", () => {
    const hall = twoHumans();
    walkInto(hall, "a", zone(hall, "mode", "teams"));
    walkInto(hall, "b", zone(hall, "stage", "isole"));
    const ready = zone(hall, "ready");
    walkTo(hall, "a", ready.x - 80, ready.z);
    const events = walkTo(hall, "b", ready.x + 80, ready.z);
    assert.ok(events.some((e) => e.type === "countdown" && e.ms === HALL.countdownMs));
    assert.equal(hall.need(), null);
    assert.ok(hall.countdownMs! < HALL.countdownMs);
    // Luca esce: si annulla
    const out = walkTo(hall, "b", ready.x + ready.r + 150, ready.z);
    assert.ok(out.some((e) => e.type === "cancel"));
    assert.equal(hall.countdownMs, null);
    walkTo(hall, "b", ready.x + 80, ready.z);
    const go = run(hall, HALL.countdownMs + 100);
    assert.deepEqual(go.find((e) => e.type === "go"), { type: "go", mode: "teams", stageId: "isole" });
    assert.deepEqual(hall.result(), { mode: "teams", stageId: "isole" });
    assert.equal(go.filter((e) => e.type === "go").length, 1);
  });

  it("con un bot si parte anche da soli", () => {
    const hall = new Hall({ seed: "bot" });
    hall.addPlayer("a", "Marta");
    hall.addBot();
    walkInto(hall, "a", zone(hall, "ready"));
    run(hall, HALL.countdownMs + 100);
    assert.ok(hall.result());
  });

  it("stessi tasti, stesso risultato: la sala è deterministica", () => {
    const play = () => {
      const hall = twoHumans("det");
      walkInto(hall, "a", zone(hall, "stage", RANDOM_STAGE_ZONE));
      walkInto(hall, "b", zone(hall, "stage", RANDOM_STAGE_ZONE));
      walkInto(hall, "a", zone(hall, "ready"));
      walkInto(hall, "b", zone(hall, "ready"));
      run(hall, HALL.countdownMs + 100);
      return { result: hall.result(), snap: hall.snapshot(0, [], [], DEFAULT_RULES) };
    };
    const one = play();
    assert.deepEqual(one, play());
    assert.match(one.result!.stageId, /^casuale-\d+$/);
  });

  it("al ritorno dalla partita: tutti appena fuori dal cerchio, voti azzerati, lottatori tenuti", () => {
    const hall = twoHumans();
    walkInto(hall, "a", zone(hall, "fighter", "orsoblu"));
    walkInto(hall, "a", zone(hall, "mode", "race"));
    hall.addBot();
    walkInto(hall, "a", zone(hall, "ready"));
    walkInto(hall, "b", zone(hall, "ready"));
    run(hall, HALL.countdownMs + 100);
    assert.ok(hall.result());
    hall.regroup();
    assert.equal(hall.result(), null);
    assert.equal(hall.countdownMs, null);
    const ready = zone(hall, "ready");
    for (const p of hall.roster().filter((q) => !q.bot)) {
      assert.equal(p.modeVote, null);
      assert.ok(Math.hypot(p.x - ready.x, p.z - ready.z) > ready.r);
    }
    assert.equal(hall.fighter("a")?.characterId, "orsoblu");
    assert.equal(hall.botIds().length, 1);
    hall.step(DT);
    assert.equal(hall.need(), "Mancano Marta e Luca nel cerchio");
  });

  it("se esce chi ha creato la stanza, il padrone di casa diventa il prossimo umano", () => {
    const hall = new Hall({ seed: "host" });
    hall.addPlayer("a", "A", undefined, undefined, { host: true });
    hall.addBot();
    hall.addPlayer("b", "B");
    hall.removePlayer("a");
    assert.equal(hall.hostId, "b");
    const events = hall.step(DT);
    assert.ok(events.some((e) => e.type === "leave" && e.id === "a"));
  });
});

describe("sala d'attesa: gong e trono", () => {
  it("leggero dentro il gong lo suona, con ricarica", () => {
    const hall = twoHumans();
    walkInto(hall, "a", zone(hall, "gong"));
    hall.setInput("a", keys({ light: true }));
    assert.ok(hall.step(DT).some((e) => e.type === "gong" && e.id === "a"));
    hall.setInput("a", emptyInput());
    hall.step(DT);
    run(hall, HALL.shoveCooldownMs);
    hall.setInput("a", keys({ light: true }));
    assert.ok(!hall.step(DT).some((e) => e.type === "gong"), "il gong si ricarica");
  });

  it("il primo sul trono si siede, chi arriva dopo glielo prende", () => {
    const hall = twoHumans();
    const throne = zone(hall, "throne");
    const sit = walkTo(hall, "a", throne.x + 30, throne.z);
    assert.ok(sit.some((e) => e.type === "throne" && e.id === "a"));
    assert.equal(pos(hall, "a").throne, true);
    const take = walkTo(hall, "b", throne.x - 40, throne.z);
    assert.ok(take.some((e) => e.type === "throne" && e.id === "b"));
    assert.equal(pos(hall, "b").throne, true);
    assert.equal(pos(hall, "a").throne, false);
    walkTo(hall, "b", 0, 0);
    assert.equal(pos(hall, "b").throne, false);
  });
});

describe("sala d'attesa: snapshot", () => {
  it("ha zone, misure, giocatori e regole con la modalità votata", () => {
    const hall = twoHumans();
    const snap = hall.snapshot(123, [{ type: "gong", id: "a" }], [{ name: "X", rating: 1000, tier: "Scimmietta", wins: 0, matches: 1, streak: 0 }], DEFAULT_RULES);
    assert.equal(snap.t, 123);
    assert.equal(snap.width, HALL.width);
    assert.equal(snap.depth, HALL.depth);
    assert.equal(snap.zones.length, hallLayout().length);
    assert.equal(snap.players.length, 2);
    assert.equal(snap.board.length, 1);
    assert.equal(snap.countdownMs, null);
    assert.equal(typeof snap.need, "string");
    assert.equal(snap.players[0].skinId, "");
    assert.ok(Object.keys(snap.players[0]).every((k) => !["vx", "input", "prev", "slot"].includes(k)), "niente stato interno");
    assert.equal(hallFighterIds().length, Object.keys(CHARACTERS).length);
  });
});

// --- zona giochi ---

const prop = (hall: Hall, id: string): HallPropState => hall.snapshot(0, [], [], DEFAULT_RULES).props.find((c) => c.id === id)!;
const props = (hall: Hall) => hall.snapshot(0, [], [], DEFAULT_RULES).props;
const HOOP = () => zone(new Hall({ seed: "x" }), "hoop");
const CHESS = () => zone(new Hall({ seed: "x" }), "chessboard");
// Centro della casella (colonna 0-7 = a-h, traversa 1-8): i bianchi verso la telecamera
const square = (file: number, rank: number) => ({ x: CHESS().x + (file - 3.5) * HALL.chessSquare, z: CHESS().z + (4.5 - rank) * HALL.chessSquare });

function solo(seed = "basket") {
  const hall = new Hall({ seed });
  hall.addPlayer("a", "Marta", "default", undefined, { host: true });
  hall.step(DT);
  return hall;
}

// Va alla rastrelliera e prende un pallone
function grabBall(hall: Hall, id: string): HallEvent[] {
  return walkTo(hall, id, HALL.rackX - HALL.rackGap, HALL.rackZ + 40);
}

// Si mette fermo a dist cm dal canestro, guardandolo, e tira
function shootFrom(hall: Hall, id: string, dist: number): HallEvent[] {
  const hoop = HOOP();
  walkTo(hall, id, hoop.x - dist - 40, hoop.z);
  walkTo(hall, id, hoop.x - dist, hoop.z);
  hall.setInput(id, keys({ light: true }));
  const events = run(hall, 3000);
  hall.setInput(id, emptyInput());
  return events;
}

describe("sala d'attesa: zona giochi, pianta", () => {
  it("il canestro sta sul muro di destra dentro il campo; la scacchiera 8x8 a sinistra", () => {
    const zones = hallLayout();
    const hoop = zones.find((z) => z.kind === "hoop")!;
    const court = zones.find((z) => z.kind === "court")!;
    const chess = zones.find((z) => z.kind === "chessboard")!;
    assert.equal(hoop.x, HALL.width / 2 - HALL.boardInset - HALL.rimOffset);
    assert.equal(hoop.r, HALL.rimRadius);
    assert.ok(Math.abs(hoop.x - court.x) <= court.r && Math.abs(hoop.z - court.z) <= court.r, "il canestro è nel campo");
    assert.equal(court.x + court.r, HALL.width / 2, "il campo arriva al muro del canestro");
    assert.ok(chess.x < 0);
    assert.equal(chess.r, 4 * HALL.chessSquare);
  });

  it("3 palloni da basket sulla rastrelliera, 2 da spiaggia, 32 pezzi sulle case di partenza", () => {
    const list = props(new Hall({ seed: "x" }));
    assert.equal(list.filter((c) => c.kind === "basketball").length, 3);
    assert.equal(list.filter((c) => c.kind === "beachball").length, 2);
    const chess = list.filter((c) => c.kind === "chess");
    assert.equal(chess.length, 32);
    assert.equal(new Set(list.map((c) => c.id)).size, list.length, "id unici");
    const at = (id: string) => chess.find((c) => c.id === id)!;
    assert.deepEqual([at("chess-w-king").x, at("chess-w-king").z], [square(4, 1).x, square(4, 1).z], "re bianco in e1");
    assert.deepEqual([at("chess-b-queen").x, at("chess-b-queen").z], [square(3, 8).x, square(3, 8).z], "donna nera in d8");
    assert.deepEqual([at("chess-w-pawn-a").x, at("chess-w-pawn-a").z], [square(0, 2).x, square(0, 2).z]);
    assert.equal(at("chess-w-king").h, HALL.chessPieces.king.h);
    assert.ok(chess.every((c) => c.tilt === 0 && c.y === 0 && c.piece && c.color));
    for (const b of list.filter((c) => c.kind === "basketball")) {
      assert.equal(b.y, HALL.basketballRadius, "a terra");
      assert.ok(Math.abs(b.x - HALL.rackX) <= HALL.rackGap && b.z === HALL.rackZ);
    }
  });

  it("da fermi gli oggetti non si muovono e non fanno eventi", () => {
    const hall = new Hall({ seed: "x" });
    const before = props(hall);
    assert.deepEqual(run(hall, 2000), []);
    assert.deepEqual(props(hall), before);
  });
});

describe("sala d'attesa: palloni", () => {
  it("un pallone lasciato cadere rimbalza sempre meno e si ferma a terra", () => {
    const hall = solo();
    hall.launchProp("ball-1", 1700, 300, 300);
    const events = run(hall, 4000);
    const hits = events.filter((e) => e.type === "propHit" && e.prop === "ball-1");
    assert.ok(hits.length >= 2, "rimbalza");
    const speeds = hits.map((e) => (e.type === "propHit" ? e.speed : 0));
    assert.ok(speeds[0] > speeds[1], "ogni rimbalzo è più basso");
    const b = prop(hall, "ball-1");
    assert.equal(b.y, HALL.basketballRadius);
    assert.deepEqual(run(hall, 500), []);
    assert.deepEqual(prop(hall, "ball-1"), b, "fermo");
  });

  it("camminando contro il pallone da spiaggia lo si calcia via", () => {
    const hall = solo();
    const home = prop(hall, "beach-1");
    const events = walkTo(hall, "a", home.x + 200, home.z);
    walkTo(hall, "a", home.x - 300, home.z, 3000);
    const b = prop(hall, "beach-1");
    assert.ok(Math.hypot(b.x - home.x, b.z - home.z) > 100, "si è spostato");
    assert.ok(b.x < home.x, "verso dove si camminava");
    assert.ok(b.spin !== 0, "rotola");
    assert.ok(!events.some((e) => e.type === "pickup"), "quello da spiaggia non si prende in mano");
  });

  it("si prende un pallone camminandoci contro, lo si tiene sopra la testa, e chi esce lo lascia cadere", () => {
    const hall = solo();
    hall.addPlayer("b", "Luca");
    const events = grabBall(hall, "a");
    const pick = events.find((e) => e.type === "pickup");
    assert.ok(pick && pick.type === "pickup" && pick.id === "a");
    const id = pick.prop;
    assert.equal(pos(hall, "a").holding, id);
    const held = prop(hall, id);
    assert.equal(held.holder, "a");
    assert.equal(held.y, HALL.holdHeight + HALL.basketballRadius - HALL.basketballRadius + pos(hall, "a").y);
    // Saltando il pallone sale con chi lo tiene
    hall.setInput("a", keys({ jump: true }));
    run(hall, 150);
    assert.ok(prop(hall, id).y > held.y);
    hall.setInput("a", emptyInput());
    run(hall, 1000);
    hall.removePlayer("a");
    assert.equal(prop(hall, id).holder, null);
    run(hall, 3000);
    assert.ok(prop(hall, id).y < 3 * HALL.basketballRadius, "cade giù (anche tra gli altri palloni della rastrelliera)");
  });

  it("chi viene spinto o cade dalla rete perde il pallone", () => {
    const hall = solo();
    hall.addPlayer("b", "Luca");
    grabBall(hall, "a");
    assert.ok(pos(hall, "a").holding);
    hall.setAway("a", true);
    assert.equal(pos(hall, "a").holding, null);
    hall.setAway("a", false);
    run(hall, 2000);
    grabBall(hall, "a");
    assert.ok(pos(hall, "a").holding);
    const a = pos(hall, "a");
    walkTo(hall, "b", a.x - 110, a.z);
    hall.setInput("b", keys({ light: true }));
    run(hall, DT);
    assert.equal(pos(hall, "a").holding, null);
  });

  it("dalla lunetta, fermi: canestro da 2 pulito (swish)", () => {
    const hall = solo();
    grabBall(hall, "a");
    const events = shootFrom(hall, "a", HALL.freeThrowDist);
    const thr = events.find((e) => e.type === "throw");
    assert.ok(thr && thr.type === "throw" && thr.id === "a");
    assert.equal(pos(hall, "a").holding, null);
    const basket = events.find((e) => e.type === "basket");
    assert.deepEqual(basket, { type: "basket", id: "a", prop: thr.prop, points: 2, swish: true });
    assert.equal(pos(hall, "a").baskets, 1);
    assert.equal(events.filter((e) => e.type === "basket").length, 1, "un canestro solo");
    assert.equal(hall.snapshot(0, [], [], DEFAULT_RULES).players[0].baskets, 1);
  });

  it("da oltre la linea da tre il canestro vale 3", () => {
    const hall = solo();
    grabBall(hall, "a");
    const events = shootFrom(hall, "a", HALL.threePointRadius + 80);
    const basket = events.find((e) => e.type === "basket");
    assert.ok(basket && basket.type === "basket" && basket.points === 3);
    assert.equal(pos(hall, "a").baskets, 1);
  });

  it("di corsa e da lontano si sbaglia spesso, da fermi vicino mai", () => {
    let near = 0;
    let far = 0;
    for (const seed of ["s1", "s2", "s3", "s4", "s5", "s6"]) {
      const a = solo(seed);
      grabBall(a, "a");
      if (shootFrom(a, "a", 300).some((e) => e.type === "basket")) near++;
      const b = solo(seed);
      grabBall(b, "a");
      if (shootFrom(b, "a", HALL.shotRange - 60).some((e) => e.type === "basket")) far++;
    }
    assert.equal(near, 6);
    assert.ok(far < 6, `da lontano ${far} su 6`);
  });

  it("un pallone che cade sul ferro rimbalza fuori, senza canestro", () => {
    const hall = solo();
    const hoop = HOOP();
    hall.launchProp("ball-1", hoop.x - HALL.rimRadius - 6, HALL.rimHeight + 150, hoop.z, 0, 0, 0, "a");
    const events = run(hall, 8000);
    assert.ok(events.some((e) => e.type === "propHit" && e.prop === "ball-1"), "sbatte sul ferro");
    assert.ok(!events.some((e) => e.type === "basket"));
    const b = prop(hall, "ball-1");
    assert.equal(b.y, HALL.basketballRadius);
    assert.ok(b.x < hoop.x - HALL.rimRadius, "fuori, davanti al canestro");
  });

  it("un pallone fermo fuori posto torna alla rastrelliera", () => {
    const hall = solo();
    const home = prop(hall, "ball-2");
    hall.launchProp("ball-2", 0, HALL.basketballRadius, -500);
    run(hall, HALL.ballIdleMs + 100);
    assert.deepEqual(prop(hall, "ball-2"), home);
  });
});

describe("sala d'attesa: scacchi giganti", () => {
  it("un pallone veloce fa cadere un pedone, uno lento lo sposta soltanto", () => {
    const hall = solo();
    const a2 = square(0, 2);
    hall.launchProp("ball-1", a2.x - 150, 40, a2.z, 1000, 0, 0, "a");
    const events = run(hall, 200);
    assert.deepEqual(events.find((e) => e.type === "topple"), { type: "topple", prop: "chess-w-pawn-a", by: "a" });
    assert.ok(!events.some((e) => e.type === "checkmate"));
    run(hall, HALL.toppleMs);
    assert.equal(prop(hall, "chess-w-pawn-a").tilt, Math.round((Math.PI / 2) * 1000) / 1000);
    const slow = solo();
    const h2 = square(7, 2);
    slow.launchProp("ball-1", h2.x + 150, 40, h2.z, -300, 0, 0);
    assert.ok(!run(slow, 1000).some((e) => e.type === "topple"));
    const pawn = prop(slow, "chess-b-pawn-h");
    assert.equal(pawn.tilt, 0);
  });

  it("la spinta butta giù i pezzi vicini, il re invece scivola", () => {
    const hall = solo();
    const e1 = square(4, 1);
    walkTo(hall, "a", e1.x, e1.z + 100);
    hall.setInput("a", keys({ light: true }));
    const events = run(hall, 600);
    const fallen = events.filter((e) => e.type === "topple").map((e) => (e.type === "topple" ? e.prop : ""));
    assert.ok(fallen.includes("chess-w-queen"));
    assert.ok(!fallen.includes("chess-w-king"));
    assert.ok(prop(hall, "chess-w-king").z < e1.z - 5, "il re scivola via");
  });

  it("re caduto: scacco matto di chi l'ha colpito, poi la scacchiera torna a posto", () => {
    const hall = solo();
    const start = props(hall).filter((c) => c.kind === "chess");
    const e1 = square(4, 1);
    hall.launchProp("ball-1", e1.x, 60, e1.z + 200, 0, 0, -1600, "a");
    const events = run(hall, 300);
    assert.ok(events.some((e) => e.type === "topple" && e.prop === "chess-w-king" && e.by === "a"));
    assert.deepEqual(events.find((e) => e.type === "checkmate"), { type: "checkmate", id: "a", color: "white" });
    run(hall, HALL.toppleMs);
    assert.ok(prop(hall, "chess-w-king").tilt > 1.5, "steso a terra");
    run(hall, HALL.chessResetMs);
    assert.deepEqual(
      props(hall).filter((c) => c.kind === "chess"),
      start,
      "tutti in piedi sulle case di partenza",
    );
  });

  it("spinto fuori dalla scacchiera un pezzo cade; senza nessuno vicino la scacchiera si rimette a posto", () => {
    const hall = solo();
    const start = props(hall).filter((c) => c.kind === "chess");
    // Il pedone in a2 scivola verso sinistra, piano (nessun urto): cade appena passa il bordo
    const a2 = square(0, 2);
    hall.launchProp("chess-w-pawn-a", a2.x, 0, a2.z, -600, 0, 0, "a");
    const events = run(hall, 1000);
    assert.deepEqual(events.find((e) => e.type === "topple"), { type: "topple", prop: "chess-w-pawn-a", by: "a" });
    const pawn = prop(hall, "chess-w-pawn-a");
    assert.equal(pawn.tiltDir, Math.round(Math.PI * 1000) / 1000, "cade verso fuori");
    assert.ok(pawn.x < CHESS().x - CHESS().r);
    run(hall, HALL.chessIdleResetMs + 100);
    assert.deepEqual(props(hall).filter((c) => c.kind === "chess"), start);
  });
});

describe("sala d'attesa: zona giochi e partita", () => {
  it("si parte: il pallone resta in sala; al ritorno tutto torna al suo posto", () => {
    const hall = solo();
    const start = props(hall);
    hall.addBot();
    grabBall(hall, "a");
    assert.ok(pos(hall, "a").holding);
    hall.launchProp("beach-1", 0, 300, -400, 200, 0, 0);
    walkInto(hall, "a", zone(hall, "ready"));
    run(hall, HALL.countdownMs + 100);
    assert.ok(hall.result());
    assert.equal(pos(hall, "a").holding, null);
    assert.ok(props(hall).every((c) => c.holder === null));
    hall.regroup();
    assert.deepEqual(props(hall), start);
    assert.equal(pos(hall, "a").baskets, 0);
  });

  it("stessi tasti, stessi palloni e stessi pezzi", () => {
    const play = () => {
      const hall = solo("det-giochi");
      grabBall(hall, "a");
      shootFrom(hall, "a", 900);
      walkTo(hall, "a", 400, -200);
      walkTo(hall, "a", 400, -400);
      hall.launchProp("ball-3", -2400, 50, 175, 1500, 0, 0, "a");
      run(hall, 1000);
      return hall.snapshot(0, [], [], DEFAULT_RULES);
    };
    assert.deepEqual(play(), play());
  });
});
