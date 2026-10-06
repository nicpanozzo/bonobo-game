// Test del limite di messaggi per client (#105)
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { clientIp, Flood, IpLimits, TokenBucket } from "./rateLimit";

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

describe("clientIp", () => {
  it("da fuori usa l'indirizzo della connessione, anche se l'intestazione dice altro", () => {
    assert.equal(clientIp("::ffff:8.8.8.8", { "cf-connecting-ip": "1.2.3.4" }), "8.8.8.8");
  });

  it("dietro il tunnel o un proxy legge l'IP vero dalle intestazioni", () => {
    assert.equal(clientIp("127.0.0.1", { "cf-connecting-ip": "1.2.3.4" }), "1.2.3.4");
    assert.equal(clientIp("10.0.0.7", { "x-forwarded-for": "5.6.7.8, 10.0.0.1" }), "5.6.7.8");
    assert.equal(clientIp("::1", {}), "::1");
    assert.equal(clientIp("192.168.1.20", {}), "192.168.1.20");
  });
});

describe("IpLimits", () => {
  it("chiude la connessione oltre il limite e la riapre quando una esce", () => {
    const limits = new IpLimits(2, 5);
    assert.deepEqual([limits.connect("a"), limits.connect("a"), limits.connect("a"), limits.connect("b")], [true, true, false, true]);
    limits.disconnect("a");
    assert.equal(limits.connect("a"), true);
  });

  it("concede tot stanze nuove al minuto per IP", () => {
    const limits = new IpLimits(8, 2);
    assert.deepEqual([limits.createRoom("a", 0), limits.createRoom("a", 1000), limits.createRoom("a", 2000)], [true, true, false]);
    assert.equal(limits.createRoom("b", 2000), true);
    assert.equal(limits.createRoom("a", 60_000), true);
  });
});
