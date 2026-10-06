import assert from "node:assert/strict";
import { test } from "node:test";
import pkg from "../../package.json";
import { health } from "./health";

test("/health conta stanze e giocatori umani", () => {
  const h = health([{ humanCount: 2 }, { humanCount: 1 }], {});
  assert.equal(h.ok, true);
  assert.equal(h.rooms, 2);
  assert.equal(h.players, 3);
});

test("/health senza stanze", () => {
  const h = health([], {});
  assert.equal(h.rooms, 0);
  assert.equal(h.players, 0);
});

test("/health dice la versione di package.json", () => {
  assert.equal(health([], {}).version, pkg.version);
});

test("/health prende il commit da Render, poi da GIT_COMMIT, altrimenti null", () => {
  assert.equal(health([], { RENDER_GIT_COMMIT: "abc123", GIT_COMMIT: "def" }).commit, "abc123");
  assert.equal(health([], { GIT_COMMIT: "def" }).commit, "def");
  assert.equal(health([], {}).commit, null);
});
