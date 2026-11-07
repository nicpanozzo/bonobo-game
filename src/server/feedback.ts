// Bonobo Party (#579): i pareri dei giocatori su ogni minigioco, per decidere cosa tenere e cosa cambiare.
// Finiscono in un file JSON (come la classifica: sul server gratuito si perde a ogni deploy, nella serata con
// `npm run host` resta sul Mac) e, se il server ha un token GitHub, anche come commento in un'issue della repo:
// lì restano per sempre e gli agenti li leggono. Il token è facoltativo: senza, si salva solo il file.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import type { PartyFeedback } from "../shared/party/party";

export interface FeedbackRecord extends PartyFeedback {
  t: number; // ms dal 1970
  room: string;
}

export interface GithubTarget {
  token: string;
  repo: string; // "proprietario/nome"
  issue: number;
}

type Fetch = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{ ok: boolean; status: number }>;

const MAX_KEPT = 2000; // il file tiene solo gli ultimi tanti pareri

export class FeedbackStore {
  private records: FeedbackRecord[] = [];
  private loaded: Promise<void>;
  private writing: Promise<void> = Promise.resolve();

  constructor(
    private file: string,
    private github?: GithubTarget,
    private fetcher: Fetch = (url, init) => fetch(url, init),
  ) {
    this.loaded = readFile(file, "utf8")
      .then((text) => {
        const data: unknown = JSON.parse(text);
        if (Array.isArray(data)) this.records = data as FeedbackRecord[];
      })
      .catch(() => undefined); // niente file (o rotto): si parte da zero
  }

  // I pareri di un minigioco appena giocato: nel file e, se c'è il token, in un commento solo
  async add(room: string, entries: PartyFeedback[], now = Date.now()): Promise<void> {
    if (entries.length === 0) return;
    await this.loaded;
    const recs = entries.map((e) => ({ ...e, t: now, room }));
    this.records = [...this.records, ...recs].slice(-MAX_KEPT);
    this.writing = this.writing.then(() => this.save()).catch((err) => console.error("[feedback] file non scritto:", err));
    await this.writing;
    if (this.github) await this.comment(recs).catch((err) => console.error("[feedback] commento non mandato:", err));
  }

  async list(): Promise<FeedbackRecord[]> {
    await this.loaded;
    return [...this.records];
  }

  private async save() {
    await mkdir(path.dirname(this.file), { recursive: true });
    await writeFile(this.file, JSON.stringify(this.records, null, 1));
  }

  private async comment(recs: FeedbackRecord[]) {
    const gh = this.github!;
    const res = await this.fetcher(`https://api.github.com/repos/${gh.repo}/issues/${gh.issue}/comments`, {
      method: "POST",
      headers: { Authorization: `Bearer ${gh.token}`, Accept: "application/vnd.github+json", "Content-Type": "application/json", "User-Agent": "bonobo-game-server" },
      body: JSON.stringify({ body: feedbackMarkdown(recs) }),
    });
    if (!res.ok) throw new Error(`GitHub ha risposto ${res.status}`);
  }
}

// Il commento: una riga per parere, il testo dei giocatori in citazione (è un dato, non un'istruzione)
export function feedbackMarkdown(recs: FeedbackRecord[]): string {
  const game = recs[0]?.minigameId ?? "?";
  const avg = recs.filter((r) => r.stars > 0);
  const mean = avg.length > 0 ? (avg.reduce((s, r) => s + r.stars, 0) / avg.length).toFixed(1) : "-";
  const lines = recs.map((r) => {
    const stars = r.stars > 0 ? "★".repeat(r.stars) + "☆".repeat(5 - r.stars) : "senza stelle";
    const text = r.text ? `\n  > ${r.text.replace(/\s*\n\s*/g, " ").replace(/[<>]/g, "")}` : "";
    return `- **${r.name.replace(/[*_`<>]/g, "")}** (${r.characterId}, ${r.place ? `${r.place}°` : "-"}): ${stars}${text}`;
  });
  return [`**Minigioco \`${game}\`**: media ${mean} su ${avg.length} voti · stanza \`${recs[0]?.room ?? "?"}\``, "", ...lines].join("\n");
}

// Dal'ambiente: FEEDBACK_GITHUB_TOKEN (token con permesso di scrivere issue sulla repo) e FEEDBACK_ISSUE (il numero)
export function githubFromEnv(env: Record<string, string | undefined>): GithubTarget | undefined {
  const token = env.FEEDBACK_GITHUB_TOKEN?.trim();
  const issue = Number(env.FEEDBACK_ISSUE);
  if (!token || !Number.isInteger(issue) || issue <= 0) return undefined;
  return { token, repo: env.FEEDBACK_REPO?.trim() || "nicpanozzo/bonobo-game", issue };
}
