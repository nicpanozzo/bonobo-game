// Test del limite di messaggi per client (#105)
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Flood, TokenBucket } from "./rateLimit";

describe("TokenBucket", () => {
  it("lascia passare lo scatto iniziale e poi il ritmo concesso", () => {
    const bucket = new TokenBucket(10, 3, 0);
    assert.deepEqual([bucket.take(0), bucket.take(0), bucket.take(0), bucket.take(0)], [true, true, true, false]);
    assert.equal(bucket.take(50), false); // mezzo gettone
    assert.equal(bucket.take(100), true); // dopo 100 ms a 10/s torna un gettone
  });

  it("non accumula più dello scatto", () => {
    const bucket = new TokenBucket(10, 2, 0);
    let passed = 0;
    for (let i = 0; i < 10; i++) if (bucket.take(60_000)) passed++;
    assert.equal(passed, 2);
  });

  it("a 1000 messaggi al secondo ne passano circa quanti concessi", () => {
    const bucket = new TokenBucket(120, 30, 0);
    let passed = 0;
    for (let t = 0; t < 1000; t++) if (bucket.take(t)) passed++;
    assert.ok(passed >= 140 && passed <= 160, `passati ${passed}`);
  });
});

describe("Flood", () => {
  it("chiude solo chi resta oltre il limite abbastanza a lungo", () => {
    const flood = new Flood(1000);
    assert.equal(flood.record(false, 0), false);
    assert.equal(flood.record(false, 999), false);
    assert.equal(flood.record(false, 1000), true);
  });

  it("riparte da zero quando un messaggio passa", () => {
    const flood = new Flood(1000);
    flood.record(false, 0);
    flood.record(true, 500);
    assert.equal(flood.record(false, 1200), false);
  });
});
