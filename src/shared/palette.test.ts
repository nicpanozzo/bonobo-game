import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { COLORS, COLORS_COLORBLIND, TEAM_COLORS, TEAM_COLORS_COLORBLIND } from "./constants";

// Come vede un colore chi ha la deuteranopia (matrice di Machado, Oliveira e Fernandes 2009, gravità 1),
// poi in CIE Lab: la distanza tra due colori Lab è quanto li si distingue (sotto 10 si confondono)
const DEUTAN = [
  [0.367322, 0.860646, -0.227968],
  [0.280085, 0.672501, 0.047413],
  [-0.01182, 0.04294, 0.968881],
];

function toLinear(c: number): number {
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function deutanLab(hex: number): [number, number, number] {
  const rgb = [(hex >> 16) & 0xff, (hex >> 8) & 0xff, hex & 0xff].map((v) => toLinear(v / 255));
  const [r, g, b] = DEUTAN.map((row) => Math.min(1, Math.max(0, row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2])));
  const x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  const y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  const z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  const f = (t: number) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

function distance(a: number, b: number): number {
  const [p, q] = [deutanLab(a), deutanLab(b)];
  return Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]);
}

// La coppia di colori più difficile da distinguere
function minDistance(colors: number[]): number {
  let min = Infinity;
  for (let i = 0; i < colors.length; i++) {
    for (let j = i + 1; j < colors.length; j++) min = Math.min(min, distance(colors[i], colors[j]));
  }
  return min;
}

function minBetween(a: number[], b: number[]): number {
  return Math.min(...a.flatMap((x) => b.map((y) => distance(x, y))));
}

describe("palette per daltonici", () => {
  it("ha un colore al posto di ognuno dell'originale", () => {
    assert.equal(COLORS_COLORBLIND.length, COLORS.length);
    for (const t of [1, 2] as const) assert.equal(TEAM_COLORS_COLORBLIND[t].length, TEAM_COLORS[t].length);
  });

  it("un colore del server diventa sempre lo stesso colore", () => {
    // Il client rimappa per valore: se un colore sta in due tabelle, deve finire uguale in entrambe
    const map = new Map<number, number>();
    const pairs: [number[], number[]][] = [[COLORS, COLORS_COLORBLIND], [TEAM_COLORS[1], TEAM_COLORS_COLORBLIND[1]], [TEAM_COLORS[2], TEAM_COLORS_COLORBLIND[2]]];
    for (const [from, to] of pairs) {
      from.forEach((c, i) => {
        if (map.has(c)) assert.equal(map.get(c), to[i], c.toString(16));
        map.set(c, to[i]);
      });
    }
  });

  it("con la deuteranopia i giocatori si distinguono meglio di prima", () => {
    assert.ok(minDistance(COLORS_COLORBLIND) > 15, `minimo ${minDistance(COLORS_COLORBLIND)}`);
    assert.ok(minDistance(COLORS_COLORBLIND) > minDistance(COLORS));
  });

  it("con la deuteranopia le due squadre si distinguono meglio di prima", () => {
    const blind = minBetween(TEAM_COLORS_COLORBLIND[1], TEAM_COLORS_COLORBLIND[2]);
    assert.ok(blind > 40, `minimo ${blind}`);
    assert.ok(blind > minBetween(TEAM_COLORS[1], TEAM_COLORS[2]));
  });
});
