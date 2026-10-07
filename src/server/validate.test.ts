// Test della validazione dei messaggi in arrivo (#105): niente di quello che arriva dalla rete deve far cadere il server
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { NET_LIMITS } from "../shared/constants";
import { parseInput, parseJoin, parseRoomCode, sanitizeName } from "./validate";

const JUNK: unknown[] = [null, undefined, 42, "ciao", true, [], [1, 2], () => 1];

describe("parseJoin", () => {
  it("scarta tutto quello che non è un oggetto", () => {
    for (const junk of JUNK) assert.equal(parseJoin(junk), null);
  });

  it("tiene i campi giusti e ripulisce il codice stanza", () => {
    const data = parseJoin({ room: "Serata-1!", name: "Luca", characterId: "egiainuso", stageId: "palco", bot: "facile" });
    assert.deepEqual(data, { room: "serata-1", name: "Luca", characterId: "egiainuso", stageId: "palco", rules: undefined, bot: "facile", token: undefined });
  });

  it("ignora i campi del tipo sbagliato", () => {
    const data = parseJoin({ room: 7, name: { a: 1 }, characterId: 3, stageId: [], rules: "tante", bot: null });
    assert.deepEqual(data, { room: "lobby", name: "", characterId: undefined, stageId: undefined, rules: undefined, bot: undefined, token: undefined });
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

describe("token di riconnessione", () => {
  it("tiene solo stringhe base64url corte", () => {
    assert.equal(parseJoin({ room: "a", token: "AbC_d-12" })?.token, "AbC_d-12");
    for (const token of [42, null, "", "x".repeat(33), "con spazi", "a/b+c=", { a: 1 }]) assert.equal(parseJoin({ room: "a", token })?.token, undefined);
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
    const input = parseInput({ left: true, right: 1, up: "true", down: {}, light: true, shield: 1, extra: true });
    assert.deepEqual(input, { left: true, right: false, up: false, down: false, light: true, heavy: false, taunt: false, dodge: false, shield: false });
  });
});

describe("sanitizeName", () => {
  const cp = (...codes: number[]) => String.fromCodePoint(...codes);
  const length = (s: string) => [...new Intl.Segmenter().segment(s)].length;

  it("toglie controllo, larghezza zero e RTL e comprime gli spazi", () => {
    assert.equal(sanitizeName(`${cp(0x202e)}Lu${cp(0x200b)}ca${cp(0)}  \t\n Bonobo `), "Luca Bonobo");
  });

  it("taglia a 16 caratteri veri senza spezzare le emoji composte", () => {
    const family = cp(0x1f468, 0x200d, 0x1f469, 0x200d, 0x1f467);
    const name = sanitizeName(family.repeat(20));
    assert.equal(length(name), NET_LIMITS.maxNameLength);
    assert.equal(name, family.repeat(NET_LIMITS.maxNameLength));
    // Una mezza emoji (tagliata da maxStringLength) sparisce invece di diventare un quadratino
    assert.equal(sanitizeName(`ab${cp(0x1f412)}`.slice(0, 3)), "ab");
  });

  it("vuoto o invisibile diventa Bonobo", () => {
    assert.equal(sanitizeName(""), "Bonobo");
    assert.equal(sanitizeName(`${cp(0x200d)} ${cp(0x200b)}`), "Bonobo");
  });

  it("un doppione nella stanza diventa Nome 2, Nome 3...", () => {
    assert.equal(sanitizeName("Luca", ["luca"]), "Luca 2");
    assert.equal(sanitizeName("Luca", ["Luca", "Luca 2"]), "Luca 3");
    assert.equal(sanitizeName("x".repeat(16), ["x".repeat(16)]), `${"x".repeat(14)} 2`);
  });
});
