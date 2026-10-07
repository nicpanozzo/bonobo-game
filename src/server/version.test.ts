import assert from "node:assert/strict";
import { test } from "node:test";
import pkg from "../../package.json";
import { PROTOCOL_VERSION } from "../shared/constants";
import { checkProtocol, SERVER_VERSION } from "./version";

test("chi parla lo stesso protocollo entra, qualunque sia la versione del gioco", () => {
  assert.equal(checkProtocol(PROTOCOL_VERSION), null);
});

test("chi non manda il protocollo (app di prima) entra comunque", () => {
  assert.equal(checkProtocol(undefined), null);
});

test("un protocollo diverso è rifiutato con un messaggio che dice cosa fare", () => {
  const old = checkProtocol(PROTOCOL_VERSION - 1);
  assert.equal(old?.reason, "outdated");
  assert.match(old?.message ?? "", /scarica/);
  const newer = checkProtocol(PROTOCOL_VERSION + 1);
  assert.equal(newer?.reason, "outdated");
  assert.match(newer?.message ?? "", /server/);
});

test("la versione del server è quella di package.json", () => {
  assert.equal(SERVER_VERSION, pkg.version);
});
