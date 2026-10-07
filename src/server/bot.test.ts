// Test dei bot (#20): girano su una Match senza rete, come nel server.
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, FIGHTER, HITSTUN_PER_KNOCKBACK, LEDGE, TICK_RATE } from "../shared/constants";
import { Match } from "../shared/match";
import { ledgesOf } from "../shared/physics";
import { Bots, parseBotKind } from "./bot";

const DT = 1000 / TICK_RATE;

describe("bot", () => {
  it("accetta solo i tipi conosciuti", () => {
    assert.equal(parseBotKind("manichino"), "manichino");
    assert.equal(parseBotKind("boh"), null);
    assert.equal(parseBotKind("toString"), null);
    assert.equal(parseBotKind(42), null);
  });

  it("il manichino resta fermo e incassa i colpi", () => {
    const match = new Match();
    const bots = new Bots();
    match.addPlayer("a", "A");
    const botId = bots.add(match, "manichino")!;
    const [a, dummy] = match.players;
    assert.equal(dummy.id, botId);
    // Il manichino davanti al giocatore, che lo guarda
    a.x = 600;
    a.facing = 1;
    dummy.x = 600 + FIGHTER.width + 20;
    const start = { x: dummy.x, y: dummy.y };
    for (let i = 0; i < 30; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.deepEqual({ x: dummy.x, y: dummy.y }, start, "da solo non si muove");
    match.setInput("a", { left: false, right: false, up: false, down: false, light: true, heavy: false, taunt: false, dodge: false, shield: false });
    for (let i = 0; i < 15; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.ok(dummy.percent > 0, "il colpo è entrato");
  });

  it("il bot semplice va verso il giocatore e lo colpisce", () => {
    const match = new Match();
    const bots = new Bots();
    match.addPlayer("a", "A");
    bots.add(match, "semplice");
    const a = match.players.find((p) => p.id === "a")!;
    for (let i = 0; i < 60 * 5 && a.percent === 0; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.ok(a.percent > 0, "in 5 secondi ha colpito almeno una volta");
  });

  it("il bot semplice lanciato fuori torna sul palco", () => {
    const match = new Match();
    const bots = new Bots();
    match.addPlayer("a", "A");
    const id = bots.add(match, "semplice")!;
    const bot = match.players.find((p) => p.id === id)!;
    const ground = match.stage.solids[0];
    // Fuori dal bordo destro, un po' sotto la superficie, già senza doppio salto
    Object.assign(bot, { x: ground.x + ground.width + 120, y: ground.y + 60, vx: 0, vy: 200, onGround: false, jumpsLeft: 1 });
    const stocks = bot.stocks;
    for (let i = 0; i < 60 * 3 && !bot.onGround; i++) {
      bots.tick(match);
      match.step(DT);
    }
    assert.equal(bot.stocks, stocks, "non è caduto");
    assert.equal(bot.onGround, true, "è di nuovo a terra");
  });

  it("i livelli si chiamano facile, semplice e difficile", () => {
    for (const kind of ["facile", "semplice", "difficile"]) assert.equal(parseBotKind(kind), kind);
  });

  it("il bot difficile schiva il pesante che vede arrivare, il facile no", () => {
    const hitsBy = (kind: "facile" | "difficile") => {
      const match = new Match();
      const bots = new Bots();
      match.addPlayer("a", "A");
      const id = bots.add(match, kind)!;
      const a = match.players.find((p) => p.id === "a")!;
      const bot = match.players.find((p) => p.id === id)!;
      a.x = 600;
      a.facing = 1;
      bot.x = 600 + FIGHTER.width + 30;
      let hits = 0;
      // Il giocatore tira un pesante ogni secondo per 6 secondi
      for (let i = 0; i < 60 * 6; i++) {
        const heavy = i % 60 === 0;
        match.setInput("a", { left: false, right: false, up: false, down: false, light: false, heavy, taunt: false, dodge: false, shield: false });
        bots.tick(match);
        hits += match.step(DT).filter((e) => e.type === "hit" && e.targetId === id).length;
        // Il giocatore resta fermo dov'è: si riavvicina al bot per il prossimo colpo
        if (i % 60 === 59) {
          a.x = bot.x - (FIGHTER.width + 30);
          a.facing = 1;
        }
      }
      return hits;
    };
    const [hard, easy] = [hitsBy("difficile"), hitsBy("facile")];
    assert.ok(hard < easy, "il difficile ne prende meno");
  });

  it("il bot semplice lanciato fuori da 80% torna sul palco almeno 15 volte su 20 (#110)", () => {
    // 20 lanci: cinque colpi veri, dai due bordi, dallo spigolo o un po' più dentro
    const launches = (["light", "heavy", "lightAir", "heavyAir", "heavyDown"] as const).flatMap((kind) =>
      [1, -1].flatMap((side) => [30, 130].map((inset) => ({ kind, side, inset }))),
    );
    let back = 0;
    for (const { kind, side, inset } of launches) {
      const match = new Match();
      const bots = new Bots();
      match.addPlayer("a", "A");
      const id = bots.add(match, "semplice")!;
      const a = match.players.find((p) => p.id === "a")!;
      const bot = match.players.find((p) => p.id === id)!;
      const ground = match.stage.solids[0];
      // Come in resolveHits: spinta e stordimento del colpo a 80%
      const spec = ATTACKS[kind];
      const knockback = spec.baseKnockback + spec.knockbackGrowth * 80;
      const angle = (spec.angleDeg * Math.PI) / 180;
      a.x = ground.x + ground.width / 2;
      Object.assign(bot, {
        x: side === 1 ? ground.x + ground.width - inset : ground.x + inset,
        y: ground.y,
        percent: 80,
        vx: side * Math.cos(angle) * knockback,
        vy: -Math.sin(angle) * knockback,
        onGround: false,
        hitstunTimer: knockback * HITSTUN_PER_KNOCKBACK,
        facing: -side,
      });
      const stocks = bot.stocks;
      for (let i = 0; i < 60 * 8 && bot.stocks === stocks; i++) {
        bots.tick(match);
        match.step(DT);
        if (bot.onGround) {
          back++;
          break;
        }
      }
    }
    assert.equal(launches.length, 20);
    assert.ok(back >= 15, `tornato ${back} volte su 20`);
  });

  it("il bot difficile usa almeno 3 risalite diverse dal bordo in 20 prove (#110)", () => {
    const match = new Match();
    const bots = new Bots();
    match.addPlayer("a", "A");
    const id = bots.add(match, "difficile")!;
    const a = match.players.find((p) => p.id === "a")!;
    const bot = match.players.find((p) => p.id === id)!;
    const [left] = ledgesOf(match.stage);
    const options = new Set<string>();
    for (let n = 0; n < 20; n++) {
      // Il giocatore a volte aspetta sopra il bordo, a volte sta lontano
      Object.assign(a, { x: n % 3 === 0 ? left.x + 80 : left.x + 500, y: left.y, vx: 0, vy: 0, percent: 0 });
      // Il bot cade accanto al bordo sinistro
      Object.assign(bot, {
        x: left.x - FIGHTER.width / 2,
        y: left.y - 20 + LEDGE.hangOffsetY,
        vx: 0,
        vy: 0,
        onGround: false,
        ledge: null,
        ledgeIndex: -1,
        ledgeGrabs: 0,
        regrabTimer: 0,
        hitstunTimer: 0,
        attack: null,
      });
      for (let i = 0; i < 60 * 6; i++) {
        match.setInput("a", { left: false, right: false, up: false, down: false, light: false, heavy: false, taunt: false, dodge: false, shield: false });
        bots.tick(match);
        const getup = match.step(DT).find((e) => e.type === "ledgeGetup" && e.id === id);
        if (getup?.type === "ledgeGetup") {
          options.add(getup.option);
          break;
        }
      }
    }
    assert.ok(options.size >= 3, `risalite usate: ${[...options].join(", ")}`);
    assert.ok(!options.has("drop"), "non si lascia cadere");
  });

  it("il bot difficile si para da almeno metà dei leggeri, il semplice no (#109)", () => {
    const blocks = (kind: "semplice" | "difficile") => {
      const match = new Match();
      const bots = new Bots();
      match.addPlayer("a", "A");
      const id = bots.add(match, kind)!;
      const a = match.players.find((p) => p.id === "a")!;
      const bot = match.players.find((p) => p.id === id)!;
      let hits = 0;
      let parried = 0;
      // Il giocatore tira un leggero ogni 25 tick per 6 secondi, sempre attaccato al bot
      for (let i = 0; i < 60 * 6; i++) {
        if (i % 25 === 0) {
          a.x = bot.x - (FIGHTER.width + 20);
          a.facing = 1;
        }
        const light = i % 25 === 0;
        match.setInput("a", { left: false, right: false, up: false, down: false, light, heavy: false, taunt: false, dodge: false, shield: false });
        bots.tick(match);
        for (const e of match.step(DT)) {
          if (e.type === "hit" && e.targetId === id) hits++;
          if (e.type === "shield" && e.id === id) parried++;
        }
      }
      return { hits, parried };
    };
    const hard = blocks("difficile");
    assert.ok(hard.parried >= hard.hits, `difficile: ${hard.parried} parati, ${hard.hits} presi`);
    assert.ok(hard.parried > 0);
    assert.equal(blocks("semplice").parried, 0);
  });

  it("due bot dello stesso livello si fanno almeno 3 KO in 5 minuti, su ogni arena fissa (E11)", () => {
    // Prima si attraversavano restando girati al contrario, o aspettavano per sempre sotto una piattaforma
    for (const stageId of ["palco", "isole", "fabbrica"]) {
      for (const level of ["facile", "semplice", "difficile"] as const) {
        const match = new Match({ stageId });
        const bots = new Bots();
        bots.add(match, level);
        bots.add(match, level);
        let kos = 0;
        for (let tick = 0; tick < 300 * TICK_RATE; tick++) {
          bots.tick(match);
          kos += match.step(DT).filter((e) => e.type === "ko").length;
        }
        assert.ok(kos >= 3, `${level} su ${stageId}: ${kos} KO`);
      }
    }
  });
});
