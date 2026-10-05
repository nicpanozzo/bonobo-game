#!/usr/bin/env node
// Parla col canale Discord del gruppo tramite un webhook.
// Niente dipendenze: Node 20+ ha già fetch, FormData e Blob.
// L'URL del webhook è un segreto: sta in DISCORD_WEBHOOK_URL, mai nel codice.
//
//   node scripts/discord.mjs post "Testo" [--image file.png|https://...]
//   node scripts/discord.mjs poll "Domanda?" "Risposta 1" "Risposta 2" [--hours 24] [--multi]
//   node scripts/discord.mjs results <id-messaggio>
//   node scripts/discord.mjs pr-merged          (usato dalla GitHub Action)
//   node scripts/discord.mjs weekly             (riepilogo del venerdì, dalla GitHub Action)

import { readFile } from 'node:fs/promises';
import { basename } from 'node:path';

const WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;
const BOT_NAME = 'Bonobo Game';
// Discord accetta sondaggi da 1 a 768 ore (32 giorni)
const MAX_POLL_HOURS = 768;
const MAX_POLL_ANSWERS = 10;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const FIRST_ISSUE_LABEL = 'good first issue';

function usage(message) {
  if (message) console.error(`Errore: ${message}\n`);
  console.error(`Uso:
  npm run discord -- post "Testo" [--image file.png|https://...]
  npm run discord -- poll "Domanda?" "Risposta 1" "Risposta 2" [--hours 24] [--multi]
  npm run discord -- results <id-messaggio>`);
  process.exit(1);
}

// Separa le opzioni (--image x, --multi) dagli argomenti posizionali
function parseArgs(argv) {
  const positional = [];
  const options = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) {
      positional.push(arg);
      continue;
    }
    const key = arg.slice(2);
    if (key === 'multi') options.multi = true;
    else options[key] = argv[++i];
  }
  return { positional, options };
}

// Legge un'immagine da file locale o da URL. Gli screenshot nelle PR di un repo
// privato non sono pubblici: se c'è GITHUB_TOKEN lo usiamo per scaricarli.
async function loadImage(source) {
  if (!/^https?:\/\//.test(source)) {
    return { name: basename(source), blob: new Blob([await readFile(source)]) };
  }
  const headers = {};
  if (process.env.GITHUB_TOKEN && new URL(source).hostname.endsWith('github.com')) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }
  const res = await fetch(source, { headers });
  const type = res.headers.get('content-type') ?? '';
  if (!res.ok || !type.startsWith('image/')) {
    throw new Error(`immagine non scaricabile (${res.status} ${type})`);
  }
  const ext = type.split('/')[1].split(';')[0].replace('jpeg', 'jpg');
  return { name: `screenshot.${ext}`, blob: await res.blob() };
}

// Manda un messaggio al webhook; ?wait=true fa restituire il messaggio creato (serve l'id)
async function send(payload, image) {
  const url = `${WEBHOOK_URL}?wait=true`;
  let body;
  const headers = {};
  if (image) {
    body = new FormData();
    body.append('payload_json', JSON.stringify(payload));
    body.append('files[0]', image.blob, image.name);
  } else {
    body = JSON.stringify(payload);
    headers['Content-Type'] = 'application/json';
  }
  const res = await fetch(url, { method: 'POST', headers, body });
  if (!res.ok) throw new Error(`Discord ha risposto ${res.status}: ${await res.text()}`);
  return res.json();
}

async function post(text, imageSource) {
  if (!text) usage('manca il testo');
  const image = imageSource ? await loadImage(imageSource) : undefined;
  const payload = { username: BOT_NAME, content: text };
  if (image) payload.embeds = [{ image: { url: `attachment://${image.name}` } }];
  const message = await send(payload, image);
  console.log(`Postato. Id messaggio: ${message.id}`);
}

async function poll(question, answers, options) {
  if (!question || answers.length < 2) usage('servono una domanda e almeno due risposte');
  if (answers.length > MAX_POLL_ANSWERS) usage(`al massimo ${MAX_POLL_ANSWERS} risposte`);
  const hours = Math.min(Math.max(Number(options.hours ?? 24), 1), MAX_POLL_HOURS);
  const message = await send({
    username: BOT_NAME,
    poll: {
      question: { text: question },
      answers: answers.map((text) => ({ poll_media: { text } })),
      duration: hours,
      allow_multiselect: Boolean(options.multi),
    },
  });
  console.log(`Sondaggio aperto per ${hours} ore. Id messaggio: ${message.id}`);
  console.log(`Per leggere i voti: npm run discord -- results ${message.id}`);
}

// Il webhook può rileggere i propri messaggi: i conteggi dei voti stanno in poll.results
async function results(messageId) {
  if (!messageId) usage("manca l'id del messaggio");
  const res = await fetch(`${WEBHOOK_URL}/messages/${messageId}`);
  if (!res.ok) throw new Error(`Discord ha risposto ${res.status}: ${await res.text()}`);
  const message = await res.json();
  if (!message.poll) throw new Error('quel messaggio non è un sondaggio');
  const counts = new Map(
    (message.poll.results?.answer_counts ?? []).map((a) => [a.id, a.count]),
  );
  console.log(message.poll.question.text);
  for (const answer of message.poll.answers) {
    console.log(`  ${counts.get(answer.answer_id) ?? 0}  ${answer.poll_media.text}`);
  }
  const closed = message.poll.results?.is_finalized;
  console.log(closed ? '(sondaggio chiuso)' : `(aperto fino a ${message.poll.expiry})`);
}

// Chiamata all'API di GitHub con il token dell'Action
async function github(path) {
  const res = await fetch(`https://api.github.com/repos/${process.env.GITHUB_REPOSITORY}${path}`, {
    headers: {
      Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
    },
  });
  if (!res.ok) throw new Error(`GitHub ha risposto ${res.status}: ${await res.text()}`);
  return res.json();
}

// Riepilogo della settimana: cosa è entrato nel gioco e cosa si può prendere,
// così anche chi non apre GitHub vede che il gioco cresce e trova da dove iniziare
async function weekly() {
  const since = Date.now() - WEEK_MS;
  const closed = await github('/pulls?state=closed&base=main&sort=updated&direction=desc&per_page=50');
  const merged = closed.filter((pr) => pr.merged_at && Date.parse(pr.merged_at) >= since);
  const easy = await github(`/issues?state=open&labels=${encodeURIComponent(FIRST_ISSUE_LABEL)}&per_page=5`);
  const takeable = easy.filter((issue) => !issue.pull_request && issue.assignees.length === 0);

  const lines = ['🦍 **La settimana dei Bonobi**', ''];
  if (merged.length > 0) {
    lines.push('**Entrato nel gioco:**');
    for (const pr of merged) lines.push(`• ${pr.title} (di ${pr.user.login})`);
  } else {
    lines.push('Questa settimana non è entrato niente nel gioco: tocca a voi! 👀');
  }
  if (takeable.length > 0) {
    lines.push('', '**Da prendere, anche se non hai mai programmato:**');
    for (const issue of takeable) lines.push(`• [${issue.title}](<${issue.html_url}>)`);
  }
  lines.push('', 'Commenta "ci penso io" su un\'issue e sei dentro.');
  await post(lines.join('\n'));
}

// Primo screenshot nella descrizione della PR: ![..](url) oppure <img src="url">
function firstImageUrl(markdown) {
  const match =
    /!\[[^\]]*\]\((https?:\/\/[^)\s]+)\)/.exec(markdown) ??
    /<img[^>]+src="(https?:\/\/[^"]+)"/.exec(markdown);
  return match?.[1];
}

// Letto dall'evento della GitHub Action, così titolo e testo della PR non passano dalla shell
async function prMerged() {
  const event = JSON.parse(await readFile(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const pr = event.pull_request;
  const text = `🦍 **${pr.title}** è entrato nel gioco!\nDi ${pr.user.login} · <${pr.html_url}>`;
  const imageUrl = firstImageUrl(pr.body ?? '');
  try {
    await post(text, imageUrl);
  } catch (err) {
    if (!imageUrl) throw err;
    // Se lo screenshot non passa, meglio un messaggio senza immagine che nessun messaggio
    console.warn(`Screenshot saltato: ${err.message}`);
    await post(text);
  }
}

const [command, ...rest] = process.argv.slice(2);
const { positional, options } = parseArgs(rest);

if (!command) usage();
if (!WEBHOOK_URL) {
  // Senza webhook non è un errore: chi non l'ha configurato semplicemente non posta
  console.warn('DISCORD_WEBHOOK_URL non impostata: niente da postare.');
  process.exit(0);
}

try {
  if (command === 'post') await post(positional[0], options.image);
  else if (command === 'poll') await poll(positional[0], positional.slice(1), options);
  else if (command === 'results') await results(positional[0]);
  else if (command === 'pr-merged') await prMerged();
  else if (command === 'weekly') await weekly();
  else usage(`comando sconosciuto: ${command}`);
} catch (err) {
  console.error(`Errore: ${err.message}`);
  process.exit(1);
}
