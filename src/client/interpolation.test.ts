import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { NET } from "../shared/constants";
import { SnapshotBuffer } from "./interpolation";

const at = (x: number, y = 0) => new Map([["a", { x, y }]]);
const D = NET.interpolationDelayMs;

describe("interpolazione degli snapshot", () => {
  it("disegna a metà tra due snapshot, nel passato di interpolationDelayMs", () => {
    const b = new SnapshotBuffer();
    // ora del server 1000 e 1100, arrivati con 20 ms di ritardo
    b.push(1000, 5020, at(0));
    b.push(1100, 5120, at(100));
    // ora locale corrispondente al server 1050, più il ritardo di disegno
    assert.deepEqual(b.sample("a", 5020 + 50 + D), { x: 50, y: 0 });
  });

  it("i ritardi della rete non spostano l'orologio stimato", () => {
    const b = new SnapshotBuffer();
    b.push(1000, 5020, at(0));
    b.push(1100, 5300, at(100)); // arrivato tardi
    b.push(1200, 5220, at(200));
    assert.deepEqual(b.sample("a", 5020 + 150 + D), { x: 150, y: 0 });
  });

  it("dopo l'ultimo snapshot resta fermo sull'ultimo", () => {
    const b = new SnapshotBuffer();
    b.push(1000, 1000, at(0));
    b.push(1100, 1100, at(100));
    assert.deepEqual(b.sample("a", 5000), { x: 100, y: 0 });
  });

  it("non interpola un respawn: salta", () => {
    const b = new SnapshotBuffer();
    b.push(1000, 1000, at(0));
    b.push(1100, 1100, at(NET.teleportDistance + 500));
    assert.equal(b.sample("a", 1010 + D)!.x, 0);
    assert.equal(b.sample("a", 1090 + D)!.x, NET.teleportDistance + 500);
  });

  it("chi non c'è non ha posizione", () => {
    const b = new SnapshotBuffer();
    assert.equal(b.sample("a", 0), undefined);
    b.push(1000, 1000, at(0));
    assert.equal(b.sample("b", 2000), undefined);
  });
});
