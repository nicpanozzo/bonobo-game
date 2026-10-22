import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { STATION, TICK_RATE, WORLD } from "../constants";
import { Match } from "../match";
import { STAGES, type StageSpec, type Station } from "../stages";
import type { InputState } from "../types";
import { createFighter, emptyInput, stepWorld, type Fighter, type PhysicsContext } from "./index";
import { stationSnapshot } from "./stations";

const DT = 1000 / TICK_RATE;
const FLOOR = 650;

// 0: la bombarda della squadra 1, che spara a destra; 1: le sue munizioni; 2: una bombarda di tutti, a tempo, con palle automatiche
const cannon: Station = { kind: "bombarda", x: 100, y: FLOOR, width: 80, team: 1, dir: 1, aimMinDeg: 0, aimMaxDeg: 45, ammoMax: 4 };
const ammo: Station = { kind: "munizioni", x: 400, y: FLOOR, width: 80, team: 1, feeds: 0, loadMs: 1000, deliveryMs: 2000, crate: 3 };
const free: Station = { kind: "bombarda", x: 900, y: FLOOR, width: 80, dir: -1, autoAmmoMs: 3000, on: [[0, 20000]] };

function stage(): StageSpec {
  return {
    id: "prova-postazioni",
    name: "Prova",
    solids: [{ x: 0, y: FLOOR, width: WORLD.width, height: 50 }],
    platforms: [],
    stations: [cannon, ammo, free],
    blastZone: { left: -500, right: WORLD.width + 500, top: -2000, bottom: WORLD.height + 500 },
    spawns: [{ x: 600, y: FLOOR }],
    respawn: { x: 600, y: 100 },
    colors: { sky: 0, solid: 0, solidEdge: 0, platform: 0 },
  };
}

function setup(...who: [x: number, team: number][]) {
  const s = stage();
  const ctx: PhysicsContext = { stage: s, events: [], timeMs: 0, canHit: (a, t) => !a.team || a.team !== t.team };
  const fighters = who.map(([x, team], i) => {
    const f = createFighter({ id: `p${i}`, name: `P${i}`, characterId: "default", color: 0, team, index: i, stocks: 3 }, s);
    f.x = x;
    f.y = FLOOR;
    f.onGround = true;
    return f;
  });
  run(fighters, ctx, 5); // tutti fermi a terra
  return { ctx, fighters };
}

function run(fighters: Fighter[], ctx: PhysicsContext, ticks: number, keys: Partial<InputState> = {}, who: Fighter[] = fighters) {
  for (const f of who) f.input = { ...emptyInput(), ...keys };
  for (let i = 0; i < ticks; i++) stepWorld(fighters, DT, ctx);
  for (const f of who) f.input = emptyInput();
}

// Una pressione: un tick col tasto giù, uno su
function tap(fighters: Fighter[], ctx: PhysicsContext, key: keyof InputState, who: Fighter[]) {
  run(fighters, ctx, 1, { [key]: true }, who);
  run(fighters, ctx, 1, {}, who);
}

const ms = (t: number) => Math.ceil(t / DT);
const stationEvents = (ctx: PhysicsContext, phase: string) => ctx.events.filter((e) => e.type === "station" && e.phase === phase);
const slots = (ctx: PhysicsContext) => ctx.stations!.slots;

describe("postazioni (#433)", () => {
  it("si entra premendo attacco da fermi sopra, si resta fermi e col salto si esce; poi un attimo di attesa", () => {
    const { ctx, fighters } = setup([140, 1]);
    const [f] = fighters;
    tap(fighters, ctx, "light", [f]);
    assert.equal(f.station, 0);
    assert.equal(slots(ctx)[0].user, "p0");
    assert.equal(f.attack, null, "la pressione non fa partire un attacco");
    assert.equal(stationEvents(ctx, "fire").length, 0, "e non spara");
    run(fighters, ctx, 30, { right: true });
    assert.equal(f.x, 140, "fermo anche tenendo una direzione");
    tap(fighters, ctx, "jump", [f]);
    assert.equal(f.station, undefined);
    assert.equal(slots(ctx)[0].user, null);
    assert.equal(stationEvents(ctx, "exit").length, 1);
    tap(fighters, ctx, "light", [f]);
    assert.equal(f.station, undefined, "non si rientra subito");
    run(fighters, ctx, ms(STATION.reenterMs));
    tap(fighters, ctx, "light", [f]);
    assert.equal(f.station, 0, "passata l'attesa sì");
  });

  it("un solo lottatore per postazione, e con team solo quella squadra", () => {
    const { ctx, fighters } = setup([130, 1], [160, 1], [430, 2]);
    const [a, b, enemy] = fighters;
    tap(fighters, ctx, "light", [a]);
    tap(fighters, ctx, "light", [b]);
    assert.equal(a.station, 0);
    assert.equal(b.station, undefined, "occupata");
    tap(fighters, ctx, "light", [enemy]);
    assert.equal(enemy.station, undefined, "le munizioni della squadra 1 non sono della 2");
    // Fuori dalle squadre (team 0) chiunque
    const ffa = setup([430, 0]);
    tap(ffa.fighters, ffa.ctx, "light", ffa.fighters);
    assert.equal(ffa.fighters[0].station, 1);
  });

  it("un colpo o una presa buttano fuori", () => {
    const { ctx, fighters } = setup([140, 1], [190, 2]);
    const [f, enemy] = fighters;
    tap(fighters, ctx, "light", [f]);
    assert.equal(f.station, 0);
    enemy.facing = -1;
    tap(fighters, ctx, "light", [enemy]);
    run(fighters, ctx, 20);
    assert.ok(ctx.events.some((e) => e.type === "hit" && e.targetId === "p0"), "preso");
    assert.equal(f.station, undefined);
    assert.equal(slots(ctx)[0].user, null);
    // La presa: chi è tenuto esce
    const g = setup([140, 1], [180, 2]);
    tap(g.fighters, g.ctx, "light", [g.fighters[0]]);
    g.fighters[1].facing = -1;
    run(g.fighters, g.ctx, 1, { shield: true }, [g.fighters[1]]);
    run(g.fighters, g.ctx, 20, { shield: true, light: true }, [g.fighters[1]]);
    assert.ok(g.ctx.events.some((e) => e.type === "grab" && e.targetId === "p0"), "preso");
    assert.equal(g.fighters[0].station, undefined);
  });

  it("su e giù mirano a velocità costante, dentro i limiti", () => {
    const { ctx, fighters } = setup([140, 1]);
    tap(fighters, ctx, "light", fighters);
    const start = slots(ctx)[0].aim;
    run(fighters, ctx, ms(100), { up: true });
    assert.ok(Math.abs(slots(ctx)[0].aim - start - STATION.aimDegS * 0.1) < 1.5, "gira di aimDegS al secondo");
    run(fighters, ctx, ms(3000), { up: true });
    assert.equal(slots(ctx)[0].aim, 45);
    run(fighters, ctx, ms(3000), { down: true });
    assert.equal(slots(ctx)[0].aim, 0);
  });

  it("spara solo con le palle e passata l'attesa tra un colpo e l'altro", () => {
    const { ctx, fighters } = setup([140, 1]);
    tap(fighters, ctx, "light", fighters);
    assert.equal(slots(ctx)[0].ammo, STATION.startAmmo);
    tap(fighters, ctx, "light", fighters);
    tap(fighters, ctx, "light", fighters);
    assert.equal(stationEvents(ctx, "fire").length, 1, "la seconda è troppo presto");
    for (let i = 0; i < STATION.startAmmo + 1; i++) {
      run(fighters, ctx, ms(STATION.fireMs));
      tap(fighters, ctx, "light", fighters);
    }
    assert.equal(stationEvents(ctx, "fire").length, STATION.startAmmo, "finite le palle non spara");
    assert.equal(slots(ctx)[0].ammo, 0);
  });

  it("la palla di mortadella prende l'avversario: danno, KO a chi spara e un punto torre; il compagno no", () => {
    const { ctx, fighters } = setup([140, 1], [330, 1], [420, 2]);
    const [gunner, mate, enemy] = fighters;
    tap(fighters, ctx, "light", [gunner]);
    run(fighters, ctx, ms(3000), { down: true }, [gunner]); // canna dritta
    tap(fighters, ctx, "light", [gunner]);
    run(fighters, ctx, 40);
    assert.equal(mate.percent, 0, "niente fuoco amico");
    assert.equal(enemy.percent, STATION.ballDamage);
    assert.equal(enemy.lastHitById, "p0", "il KO va a chi spara");
    assert.ok(ctx.events.some((e) => e.type === "hit" && e.itemKind === "mortadella" && e.targetId === "p2"));
    assert.equal(stationEvents(ctx, "boom").length, 1);
    assert.equal(ctx.stations!.balls.length, 0);
    assert.deepEqual(stationSnapshot(ctx).towerPoints, { 1: 1 });
  });

  it("la palla si schianta sui blocchi pieni", () => {
    const { ctx, fighters } = setup([140, 1]);
    tap(fighters, ctx, "light", fighters);
    tap(fighters, ctx, "light", fighters);
    assert.equal(ctx.stations!.balls.length, 1);
    run(fighters, ctx, ms(3000));
    assert.equal(ctx.stations!.balls.length, 0);
    assert.equal(stationEvents(ctx, "boom").length, 1, "cade sul pavimento");
  });

  it("munizioni: attacco tenuto per loadMs carica una cassa, che dopo deliveryMs arriva alla bombarda", () => {
    const { ctx, fighters } = setup([440, 1]);
    tap(fighters, ctx, "light", fighters);
    assert.equal(fighters[0].station, 1);
    run(fighters, ctx, ms(500), { light: true });
    run(fighters, ctx, 1);
    assert.equal(stationEvents(ctx, "load").length, 0, "lasciato prima: la carica si perde");
    assert.equal(slots(ctx)[1].loadAt, null);
    run(fighters, ctx, ms(1000) + 2, { light: true });
    assert.equal(stationEvents(ctx, "load").length, 1);
    assert.equal(slots(ctx)[1].crates.length, 1);
    assert.equal(slots(ctx)[0].ammo, STATION.startAmmo, "la cassa sta salendo");
    run(fighters, ctx, ms(2000) + 1);
    assert.equal(slots(ctx)[0].ammo, 4, "+3, ma non oltre ammoMax");
    assert.equal(stationEvents(ctx, "ammo").length, 1);
    // A metà carica col salto si esce e la carica si perde
    slots(ctx)[0].ammo = 0;
    run(fighters, ctx, ms(500), { light: true });
    tap(fighters, ctx, "jump", fighters);
    assert.equal(slots(ctx)[1].loadAt, null);
    assert.equal(stationEvents(ctx, "load").length, 1);
  });

  it("autoAmmoMs: una palla ogni tanto anche senza munizioni; fuori dalle finestre on la postazione non c'è", () => {
    const { ctx, fighters } = setup([940, 1]);
    slots(ctx)[2].ammo = 0;
    run(fighters, ctx, ms(3000) + 1);
    assert.equal(slots(ctx)[2].ammo, 1);
    run(fighters, ctx, ms(3000) + 1);
    assert.equal(slots(ctx)[2].ammo, 2);
    tap(fighters, ctx, "light", fighters);
    assert.equal(fighters[0].station, 2, "senza team la usa chiunque");
    ctx.timeMs = 20000 - 5;
    run(fighters, ctx, 2);
    assert.equal(fighters[0].station, undefined, "finita la finestra si esce");
    run(fighters, ctx, ms(STATION.reenterMs));
    tap(fighters, ctx, "light", fighters);
    assert.equal(fighters[0].station, undefined, "e non si rientra");
  });

  it("alla rivincita postazioni libere, munizioni e punti torre da capo", () => {
    STAGES["prova-postazioni"] = stage();
    try {
      const match = new Match({ stageId: "prova-postazioni", rules: { mode: "teams" }, items: false });
      match.addPlayer("a", "A");
      match.addPlayer("b", "B");
      const a = match.players.find((f) => f.team === 1)!;
      a.x = 140;
      a.y = FLOOR;
      for (let i = 0; i < 5; i++) match.step(DT);
      match.setInput(a.id, { ...emptyInput(), light: true });
      match.step(DT);
      match.setInput(a.id, emptyInput());
      match.step(DT);
      let snap = match.snapshot([], 0);
      assert.equal(snap.stations?.[0].user, a.id);
      assert.equal(snap.players.find((p) => p.id === a.id)?.station, 0);
      // Un punto torre finto: la palla vera la provano i test qui sopra
      (match as unknown as { ctx: PhysicsContext }).ctx.stations!.points[1] = 3;
      assert.deepEqual(match.snapshot([], 0).towerPoints, { 1: 3 });
      match.reset();
      match.step(DT);
      snap = match.snapshot([], 0);
      assert.equal(snap.stations?.[0].user, null);
      assert.equal(snap.players.find((p) => p.id === a.id)?.station, undefined);
      assert.deepEqual(snap.towerPoints, {});
      assert.equal(snap.stations?.[0].ammo, STATION.startAmmo);
    } finally {
      delete STAGES["prova-postazioni"];
    }
  });

  it("le arene senza postazioni non hanno niente nello snapshot", () => {
    const s = { ...stage(), stations: undefined };
    assert.deepEqual(stationSnapshot({ stage: s, events: [] }), {});
  });
});
