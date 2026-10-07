// Test dei posti tenuti per la riconnessione (#107)
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Seats } from "./seats";

describe("Seats", () => {
  it("dà token diversi e difficili da indovinare", () => {
    const seats = new Seats(1000);
    const a = seats.issue("a");
    const b = seats.issue("b");
    assert.notEqual(a, b);
    assert.ok(a.length >= 20);
  });

  it("un token riporta nel posto tenuto, una volta sola", () => {
    const seats = new Seats(1000);
    const token = seats.issue("a");
    assert.equal(seats.resume(token, 0), null, "il posto non è tenuto finché il giocatore è collegato");
    seats.hold("a", 0);
    assert.ok(seats.isHeld("a"));
    assert.equal(seats.resume(token, 999), "a");
    assert.equal(seats.isHeld("a"), false);
    assert.equal(seats.resume(token, 999), null);
  });

  it("dopo il tempo il posto scade e il token non vale più", () => {
    const seats = new Seats(1000);
    const token = seats.issue("a");
    seats.hold("a", 0);
    assert.deepEqual(seats.expired(500), []);
    assert.deepEqual(seats.expired(1000), ["a"]);
    assert.equal(seats.resume(token, 1000), null);
    seats.hold("a", 2000);
    assert.equal(seats.resume(token, 2000), null, "dopo release il token è dimenticato");
  });

  it("un token non vale in un'altra stanza né se è sconosciuto", () => {
    const room1 = new Seats(1000);
    const room2 = new Seats(1000);
    const token = room1.issue("a");
    room2.issue("a");
    room2.hold("a", 0);
    assert.equal(room2.resume(token, 0), null);
    assert.equal(room2.resume("inventato", 0), null);
  });
});
