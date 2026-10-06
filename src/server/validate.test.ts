// Test della validazione dei messaggi in arrivo (#105): niente di quello che arriva dalla rete deve far cadere il server
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { NET_LIMITS } from "../shared/constants";
import { parseInput, parseJoin, parseRoomCode } from "./validate";

const JUNK: unknown[] = [null, undefined, 42, "ciao", true, [], [1, 2], () => 1];

describe("parseJoin", () => {
  it("scarta tutto quello che non è un oggetto", () => {
    for (const junk of JUNK) assert.equal(parseJoin(junk), null);
  });

  it("tiene i campi giusti e ripulisce il codice stanza", () => {
    const data = parseJoin({ room: "Serata-1!", name: "Luca", characterId: "egiainuso", stageId: "palco", bot: "facile" });
    assert.deepEqual(data, { room: "serata-1", name: "Luca", characterId: "egiainuso", stageId: "palco", rules: undefined, bot: "facile" });
  });

  it("ignora i campi del tipo sbagliato", () => {
    const data = parseJoin({ room: 7, name: { a: 1 }, characterId: 3, stageId: [], rules: "tante", bot: null });
    assert.deepEqual(data, { room: "lobby", name: "", characterId: undefined, stageId: undefined, rules: undefined, bot: undefined });
  });

  it("taglia le stringhe enormi", () => {
    const huge = "x".repeat(1_000_000);
    const data = parseJoin({ room: huge, name: huge, characterId: huge });
    assert.equal(data?.room.length, 24);
    assert.equal(data?.name.length, NET_LIMITS.maxStringLength);
    assert.equal(data?.characterId?.length, NET_LIMITS.maxStringLength);
  });

  it("delle regole tiene solo valori semplici e mai __proto__", () => {
    const rules = JSON.parse('{"stocks": 5, "mode": "teams", "items": true, "deep": {"a": 1}, "list": [1], "__proto__": {"x": 1}}');
    const data = parseJoin({ room: "a", name: "b", rules });
    assert.deepEqual({ ...data?.rules }, { stocks: 5, mode: "teams", items: true });
    assert.equal(Object.getPrototypeOf(data?.rules), Object.prototype);
  });
});

describe("parseRoomCode", () => {
  it("usa lobby se non resta niente", () => {
    assert.equal(parseRoomCode(""), "lobby");
    assert.equal(parseRoomCode("!!!"), "lobby");
    assert.equal(parseRoomCode(undefined), "lobby");
  });
});

describe("parseInput", () => {
  it("scarta tutto quello che non è un oggetto", () => {
    for (const junk of JUNK) assert.equal(parseInput(junk), null);
  });

  it("conta come premuto solo true", () => {
    const input = parseInput({ left: true, right: 1, up: "true", down: {}, light: true, extra: true });
    assert.deepEqual(input, { left: true, right: false, up: false, down: false, light: true, heavy: false, taunt: false, dodge: false });
  });
});
