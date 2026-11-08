import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { FeedbackStore, feedbackMarkdown, githubFromEnv } from "./feedback";
import { parsePartyCommand } from "./validate";

const entry = { minigameId: "pioggia", id: "a", name: "Marta", characterId: "default", stars: 4, text: "bello <b>ma</b>\ncorto", place: 1 };

test("feedback: si salva nel file e, col token, diventa un commento nell'issue", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "feedback-"));
  const file = path.join(dir, "sub", "feedback.json");
  const calls: { url: string; body: string }[] = [];
  const store = new FeedbackStore(file, { token: "t", repo: "x/y", issue: 7 }, async (url, init) => {
    calls.push({ url, body: init.body });
    return { ok: true, status: 201 };
  });
  await store.add("stanza", [entry], 1000);
  const saved = JSON.parse(await readFile(file, "utf8"));
  assert.equal(saved.length, 1);
  assert.equal(saved[0].room, "stanza");
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://api.github.com/repos/x/y/issues/7/comments");
  const body = JSON.parse(calls[0].body).body as string;
  assert.ok(body.includes("pioggia") && body.includes("★★★★☆") && body.includes("Marta"));
  assert.ok(!body.includes("<b>"), "niente HTML dei giocatori nel commento");
  // Rileggendo il file da capo i pareri ci sono ancora
  assert.equal((await new FeedbackStore(file).list()).length, 1);
});

test("feedback: senza token né issue niente GitHub; il markdown fa la media delle stelle date", () => {
  assert.equal(githubFromEnv({}), undefined);
  assert.equal(githubFromEnv({ FEEDBACK_GITHUB_TOKEN: "t" }), undefined);
  assert.deepEqual(githubFromEnv({ FEEDBACK_GITHUB_TOKEN: " t ", FEEDBACK_ISSUE: "12" }), { token: "t", repo: "nicpanozzo/bonobo-game", issue: 12 });
  const md = feedbackMarkdown([
    { ...entry, t: 0, room: "r" },
    { ...entry, stars: 2, text: "", t: 0, room: "r" },
    { ...entry, stars: 0, text: "solo testo", t: 0, room: "r" },
  ]);
  assert.ok(md.includes("media 3.0 su 2 voti"));
});

test("comandi del tabellone: solo quelli noti, numeri e testi ripuliti", () => {
  assert.equal(parsePartyCommand(null), null);
  assert.equal(parsePartyCommand({ kind: "boh" }), null);
  assert.deepEqual(parsePartyCommand({ kind: "roll", useItem: "si" }), { kind: "roll", useItem: false });
  assert.deepEqual(parsePartyCommand({ kind: "path", next: 9 }), { kind: "path", next: 3 });
  assert.equal(parsePartyCommand({ kind: "path" }), null);
  assert.deepEqual(parsePartyCommand({ kind: "feedback", stars: 9, text: "ok" }), { kind: "feedback", stars: 5, text: "ok" });
  const long = parsePartyCommand({ kind: "feedback", stars: 3, text: "x".repeat(5000) });
  assert.ok(long?.kind === "feedback" && long.text.length <= 500);
  assert.deepEqual(parsePartyCommand({ kind: "buy", item: null }), { kind: "buy", item: null });
});
