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
//   node scripts/discord.mjs seduta             (sondaggio di una seduta del Parlamento, dalla GitHub Action)

import { readFile } from 'node:fs/promises';
import { basename } from 'node:path';

const WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;
const BOT_NAME = 'Bonobo Game';
// Discord accetta sondaggi da 1 a 768 ore (32 giorni)
const MAX_POLL_HOURS = 768;
const MAX_POLL_ANSWERS = 10;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const FIRST_ISSUE_LABEL = 'good first issue';
// Etichetta delle PR da annunciare sul Discord: solo cambi che un giocatore nota
const PLAYER_LABEL = 'per-giocatori';

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

// Link cliccabile al messaggio: il webhook sa in quale server (guild) e canale scrive
async function messageLink(message) {
  const res = await fetch(WEBHOOK_URL);
  if (!res.ok) return `id ${message.id}`;
  const webhook = await res.json();
  return `https://discord.com/channels/${webhook.guild_id}/${message.channel_id}/${message.id}`;
}

async function post(text, imageSource) {
  if (!text) usage('manca il testo');
  const image = imageSource ? await loadImage(imageSource) : undefined;
  const payload = { username: BOT_NAME, content: text };
  if (image) payload.embeds = [{ image: { url: `attachment://${image.name}` } }];
  const message = await send(payload, image);
  console.log(`Postato: ${await messageLink(message)}`);
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
  const link = await messageLink(message);
  console.log(`Sondaggio aperto per ${hours} ore: ${link}`);
  console.log(`Per leggere i voti: npm run discord -- results ${message.id}`);
  return link;
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

// Chiamata all'API di GitHub con il token dell'Action (body: per scrivere, con PATCH o POST)
async function github(path, method = 'GET', body = undefined) {
  const api = process.env.GITHUB_API_URL ?? 'https://api.github.com';
  const res = await fetch(`${api}/repos/${process.env.GITHUB_REPOSITORY}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`GitHub ha risposto ${res.status}: ${await res.text()}`);
  return res.json();
}

// Riepilogo della settimana: cosa è entrato nel gioco e cosa si può prendere,
// così anche chi non apre GitHub vede che il gioco cresce e trova da dove iniziare
async function weekly() {
  const since = Date.now() - WEEK_MS;
  const closed = await github('/pulls?state=closed&base=main&sort=updated&direction=desc&per_page=50');
  // Solo le PR che un giocatore nota: CI, documenti e refactor non interessano al canale
  const merged = closed.filter(
    (pr) =>
      pr.merged_at &&
      Date.parse(pr.merged_at) >= since &&
      pr.labels.some((label) => label.name === PLAYER_LABEL),
  );
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

// ---------- Parlamento ----------
// Una seduta convocata dal sito è un'issue "🏛️ SEDUTA ..." (o con l'etichetta parlamento, o col modulo del sito): qui diventa da sola
// il sondaggio sul Discord e il link torna nell'issue, così nessuno deve ricordarsi di pubblicarlo.
// Il canale è del gruppo: chi non è collaboratore del repo non posta da solo, la sua seduta parte quando un
// collaboratore le mette l'etichetta (solo chi ha permessi sul repo può mettere etichette).
const PARLIAMENT_LABEL = 'parlamento';
const SEDUTA_TITLE = /^(🏛️?\s*)?SEDUTA/iu;
const DISCORD_LINK = /https:\/\/(?:www\.)?(?:discord\.com|discordapp\.com|discord\.gg)\/[^\s)>\]]+/;
// Chi apre dal sito a volte cambia il titolo precompilato: la seduta si riconosce anche dal modulo
const SEDUTA_BODY = /^[ \t]*Ordine del giorno[ \t]*:/im;
const POLL_LINE = /^[ \t]*Sondaggio[ \t]*:.*$/im;
const TRUSTED = ['OWNER', 'MEMBER', 'COLLABORATOR'];
const SEDUTA_HOURS = 48;
// Limiti di Discord: caratteri della domanda e di ogni risposta
const MAX_QUESTION = 300;
const MAX_ANSWER = 55;
// Segni nei commenti del bot, per non ripetere lo stesso avviso a ogni modifica dell'issue
const WAIT_MARK = '<!-- seduta:attesa -->';
const FIX_MARK = '<!-- seduta:incompleta -->';

// Dal modulo del sito: "Ordine del giorno: ..." e le righe a elenco; i segnaposto "<opzione 1>" si tolgono
function parseSeduta(issue) {
  const text = issue.body ?? '';
  const clean = (line) => line.replace(/<[^>]*>/g, '').replace(/\*\*/g, '').trim();
  const topic = clean(/^\s*Ordine del giorno\s*:\s*(.+)$/im.exec(text)?.[1] ?? '');
  const options = [];
  for (const line of text.split('\n')) {
    const match = /^\s*[-*]\s+(?!\[)(.+)$/.exec(line);
    const option = match && clean(match[1]);
    if (option) options.push(option.slice(0, MAX_ANSWER));
  }
  return { topic, options };
}

async function commentOnce(issue, mark, text) {
  const comments = await github(`/issues/${issue.number}/comments?per_page=100`);
  if (comments.some((c) => c.body?.includes(mark))) return;
  await github(`/issues/${issue.number}/comments`, 'POST', { body: `${mark}\n${text}` });
}

async function seduta() {
  const event = JSON.parse(await readFile(process.env.GITHUB_EVENT_PATH, 'utf8'));
  // Si rilegge l'issue: due eventi vicini (aperta e poi etichettata) non devono aprire due sondaggi
  const issue = await github(`/issues/${event.issue.number}`);
  const labelled = issue.labels.some((l) => l.name === PARLIAMENT_LABEL);
  const isSeduta = labelled || SEDUTA_TITLE.test(issue.title) || SEDUTA_BODY.test(issue.body ?? '');
  if (issue.state !== 'open' || !isSeduta) return console.log('Non è una seduta aperta.');
  if (DISCORD_LINK.test(issue.body ?? '')) return console.log('Il sondaggio è già sul Discord.');
  const { topic, options } = parseSeduta(issue);
  if (!topic || options.length < 2 || options.length > MAX_POLL_ANSWERS) {
    await commentOnce(issue, FIX_MARK, `Per aprire il sondaggio sul Discord servono la riga "Ordine del giorno: ..." e da 2 a ${MAX_POLL_ANSWERS} opzioni a elenco (\`- Opzione\`). Sistema la descrizione e il sondaggio parte da solo.`);
    return console.log('Seduta incompleta.');
  }
  if (!labelled && !TRUSTED.includes(issue.author_association)) {
    await commentOnce(issue, WAIT_MARK, `Seduta ricevuta! Il sondaggio parte sul Discord appena un collaboratore aggiunge l'etichetta \`${PARLIAMENT_LABEL}\`.`);
    return console.log('In attesa di un collaboratore.');
  }
  const question = `🏛️ SEDUTA DEL PARLAMENTO DEI BONOBI, convocata da ${issue.user.login}. Ordine del giorno: ${topic}`;
  const link = await poll(question.slice(0, MAX_QUESTION), options, { hours: SEDUTA_HOURS });
  const body = issue.body ?? '';
  const line = `Sondaggio: ${link}`;
  await github(`/issues/${issue.number}`, 'PATCH', {
    body: POLL_LINE.test(body) ? body.replace(POLL_LINE, line) : `${body}\n\n${line}`,
    // il titolo è quello che il sito mostra nella sezione Parlamento
    title: SEDUTA_TITLE.test(issue.title) ? issue.title : `🏛️ SEDUTA DEL PARLAMENTO DEI BONOBI: ${topic}`,
  });
  if (!labelled) await github(`/issues/${issue.number}/labels`, 'POST', { labels: [PARLIAMENT_LABEL] });
  await github(`/issues/${issue.number}/comments`, 'POST', { body: `🗳️ La seduta è aperta: si vota sul Discord per ${SEDUTA_HOURS} ore. ${link}` });
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
  else if (command === 'seduta') await seduta();
  else usage(`comando sconosciuto: ${command}`);
} catch (err) {
  console.error(`Errore: ${err.message}`);
  process.exit(1);
}
