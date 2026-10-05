// Sito di Bonobo Game: niente server, solo l'API pubblica di GitHub letta dal browser.
// Tutto il testo che arriva da GitHub passa da textContent, mai da innerHTML.

const REPO = 'nicpanozzo/bonobo-game';
const API = `https://api.github.com/repos/${REPO}`;
const REPO_URL = `https://github.com/${REPO}`;
// Quando il gioco avrà un indirizzo fisso (issue #19), mettilo qui e il bottone "Gioca" punta lì
const GAME_URL = '';
const CACHE_MS = 5 * 60 * 1000; // l'API senza login concede 60 richieste l'ora: teniamo i dati 5 minuti

// Etichette che descrivono "cosa sai fare", nell'ordine dei bottoni di filtro
const ROLES = [
  { label: null, text: 'Tutto' },
  { label: 'good first issue', text: '🐣 Primo lavoro' },
  { label: 'arte', text: '🎨 Arte' },
  { label: 'audio', text: '🎤 Audio' },
  { label: 'design', text: '💡 Design' },
  { label: 'codice', text: '⌨️ Codice' },
  { label: 'community', text: '🦍 Community' },
];
const HIDDEN_LABELS = new Set(['pronto', 'in attesa']);
const FIGHTER_LABEL = 'personaggio'; // lo stesso del modulo "Il mio lottatore" (issue #21)
const PARLIAMENT_LABEL = 'parlamento';

// Le reazioni di GitHub sono i "pulsanti di voto" del Parlamento
const VOTE_EMOJI = {
  '👍': '+1', '👎': '-1', '😄': 'laugh', '🎉': 'hooray',
  '😕': 'confused', '❤️': 'heart', '🚀': 'rocket', '👀': 'eyes',
};

// ---------- utilità ----------

function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else if (key === 'style') Object.assign(node.style, value);
    else node.setAttribute(key, value);
  }
  for (const child of children) if (child) node.append(child);
  return node;
}

function readCache(key) {
  try {
    const hit = JSON.parse(sessionStorage.getItem(key) ?? 'null');
    return hit && Date.now() - hit.at < CACHE_MS ? hit.data : null;
  } catch {
    return null;
  }
}

function writeCache(key, data) {
  try {
    sessionStorage.setItem(key, JSON.stringify({ at: Date.now(), data }));
  } catch {
    // sessionStorage pieno o bloccato: pazienza, rifaremo la richiesta
  }
}

async function gh(path) {
  const cached = readCache(path);
  if (cached) return cached;
  const res = await fetch(`${API}${path}`, { headers: { Accept: 'application/vnd.github+json' } });
  if (!res.ok) throw new Error(res.status === 403 ? 'troppe richieste a GitHub, riprova tra un po\'' : `GitHub ha risposto ${res.status}`);
  const data = await res.json();
  writeCache(path, data);
  return data;
}

function showError(container, err) {
  container.replaceChildren(el('p', { class: 'muted', text: `Non riesco a leggere GitHub: ${err.message}.` }));
}

function avatar(user, size = 22) {
  return el('img', { src: `${user.avatar_url}&s=${size * 2}`, width: size, height: size, alt: user.login, loading: 'lazy' });
}

function labelChip(label) {
  // Colore dell'etichetta su GitHub, con testo scuro o chiaro a seconda della luminosità
  const hex = label.color || '888888';
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16));
  const light = r * 0.299 + g * 0.587 + b * 0.114 > 150;
  return el('span', { class: 'label', text: label.name, style: { background: `#${hex}`, color: light ? '#111' : '#fff' } });
}

function shortDate(iso) {
  return new Date(iso).toLocaleDateString('it-IT', { day: 'numeric', month: 'short' });
}

// ---------- link per giocare ----------

if (GAME_URL) {
  const link = document.getElementById('play-link');
  link.href = GAME_URL;
  link.textContent = 'Gioca adesso';
  document.getElementById('play-note').textContent = 'Crea una stanza e manda il link sul canale.';
}

// ---------- roadmap ----------

let allIssues = [];
let activeRole = null;

function issueCard(issue) {
  const meta = el('div', { class: 'meta' });
  for (const label of issue.labels) if (!HIDDEN_LABELS.has(label.name)) meta.append(labelChip(label));
  if (issue.assignees.length > 0) {
    meta.append(el('span', { text: 'preso da' }), ...issue.assignees.map((u) => avatar(u, 18)));
  } else {
    meta.append(el('span', { text: '· libero' }));
  }
  return el('a', { class: 'issue', href: issue.html_url },
    el('span', { class: 'num', text: `#${issue.number}` }),
    el('div', { class: 'body' }, el('div', { class: 'title', text: issue.title }), meta),
  );
}

function renderIssues() {
  const ready = document.getElementById('issues-ready');
  const waiting = document.getElementById('issues-waiting');
  const visible = allIssues.filter((i) => !activeRole || i.labels.some((l) => l.name === activeRole));
  const has = (issue, name) => issue.labels.some((l) => l.name === name);
  const fill = (container, list, empty) => {
    container.replaceChildren(...(list.length ? list.map(issueCard) : [el('p', { class: 'muted', text: empty })]));
  };
  fill(ready, visible.filter((i) => has(i, 'pronto')), 'Niente di libero qui per ora: prova un altro filtro o proponi un\'idea.');
  fill(waiting, visible.filter((i) => has(i, 'in attesa')), 'Niente in attesa.');
}

function renderRoleFilter() {
  const box = document.getElementById('role-filter');
  for (const role of ROLES) {
    const chip = el('button', { class: 'chip', type: 'button', 'aria-pressed': String(role.label === activeRole), text: role.text });
    chip.addEventListener('click', () => {
      activeRole = role.label;
      for (const c of box.children) c.setAttribute('aria-pressed', String(c === chip));
      renderIssues();
    });
    box.append(chip);
  }
}

function prCard(pr, when) {
  const meta = el('div', { class: 'meta' }, avatar(pr.user, 18), el('span', { text: `${pr.user.login} · ${when}` }));
  return el('a', { class: 'issue', href: pr.html_url },
    el('span', { class: 'num', text: `#${pr.number}` }),
    el('div', { class: 'body' }, el('div', { class: 'title', text: pr.title }), meta),
  );
}

async function loadRoadmap() {
  const ready = document.getElementById('issues-ready');
  const waiting = document.getElementById('issues-waiting');
  try {
    const issues = await gh('/issues?state=open&per_page=100');
    // L'API delle issue restituisce anche le PR: le togliamo
    allIssues = issues.filter((i) => !i.pull_request);
    renderIssues();
  } catch (err) {
    showError(ready, err);
    waiting.replaceChildren();
  }

  const open = document.getElementById('prs-open');
  const merged = document.getElementById('prs-merged');
  try {
    const [openPrs, closedPrs] = await Promise.all([
      gh('/pulls?state=open&per_page=20'),
      gh('/pulls?state=closed&sort=updated&direction=desc&per_page=30'),
    ]);
    open.replaceChildren(...(openPrs.length
      ? openPrs.slice(0, 6).map((pr) => prCard(pr, pr.draft ? 'bozza' : 'da provare'))
      : [el('p', { class: 'muted', text: 'Nessuno al lavoro adesso. Tocca a te?' })]));
    const done = closedPrs.filter((pr) => pr.merged_at).sort((a, b) => b.merged_at.localeCompare(a.merged_at));
    merged.replaceChildren(...(done.length
      ? done.slice(0, 6).map((pr) => prCard(pr, shortDate(pr.merged_at)))
      : [el('p', { class: 'muted', text: 'Ancora niente.' })]));
  } catch (err) {
    showError(open, err);
    merged.replaceChildren();
  }
}

// ---------- Parlamento e lottatori ----------

// Chi apre l'issue dal sito senza permessi sul repo non può mettere etichette:
// riconosciamo le sedute e le schede anche dal titolo
const SEDUTA_TITLE = /^(🏛️?\s*)?SEDUTA/iu;
const FIGHTER_TITLE = /^Lottatore:/i;
const hasLabel = (issue, name) => issue.labels.some((l) => l.name === name);
let everyIssuePromise;
function everyIssue() {
  everyIssuePromise ??= gh('/issues?state=all&per_page=100').then((list) => list.filter((i) => !i.pull_request));
  return everyIssuePromise;
}

// Le opzioni di una seduta sono righe della issue come "- 🎉 Il giusto (12%)"
function parseOptions(body) {
  const options = [];
  for (const line of (body ?? '').split('\n')) {
    const match = /^\s*[-*]\s*(👍|👎|😄|🎉|😕|❤️|❤|🚀|👀)\s*(.+)$/u.exec(line);
    if (!match) continue;
    const emoji = match[1] === '❤' ? '❤️' : match[1];
    options.push({ emoji, text: match[2].trim(), key: VOTE_EMOJI[emoji] });
  }
  return options;
}

function sedutaCard(issue) {
  const options = parseOptions(issue.body);
  const votes = options.map((o) => issue.reactions?.[o.key] ?? 0);
  const total = votes.reduce((a, b) => a + b, 0);
  const best = Math.max(...votes);
  const closed = issue.state === 'closed';
  const card = el('article', { class: 'seduta' },
    el('h3', { text: issue.title }),
    el('div', { class: 'stato', text: `${closed ? '🔨 Deliberato' : '🗳️ Seduta aperta'} · ${total} vot${total === 1 ? 'o' : 'i'} · #${issue.number}` }),
  );
  if (options.length === 0) {
    card.append(el('p', { class: 'muted small', text: 'Questa seduta non ha opzioni nel formato "- 🎉 opzione".' }));
  }
  options.forEach((o, i) => {
    const pct = total ? Math.round((votes[i] / total) * 100) : 0;
    const winner = closed && total > 0 && votes[i] === best;
    card.append(el('div', { class: `opzione${winner ? ' vince' : ''}` },
      el('div', { class: 'riga' }, el('span', { text: `${o.emoji} ${o.text}` }), el('span', { text: String(votes[i]) })),
      el('div', { class: 'bar' }, el('span', { style: { width: `${pct}%` } })),
    ));
  });
  card.append(el('a', { class: 'btn', href: issue.html_url, text: closed ? 'Leggi la delibera' : 'Vota su GitHub' }));
  if (!closed) {
    // Annuncio da incollare nel canale: chi non ha GitHub vota nel sondaggio Discord, e alla chiusura si sommano
    const share = el('button', { class: 'btn', type: 'button', text: 'Copia per il Discord' });
    share.addEventListener('click', async () => {
      const text = `🏛️ **${issue.title}**\n` +
        options.map((o) => `${o.emoji} ${o.text}`).join('\n') +
        `\nVota con la reazione qui: <${issue.html_url}>\nVoti dal vivo: ${location.href.split('#')[0]}#parlamento`;
      try {
        await navigator.clipboard.writeText(text);
        share.textContent = 'Copiato!';
      } catch {
        share.textContent = 'Copia non riuscita';
      }
    });
    card.append(' ', share);
  }
  return card;
}

const NEW_SEDUTA_BODY = `Ordine del giorno: <la questione, in una frase>

Si vota con la reazione corrispondente a questo messaggio. Almeno un'opzione assurda è obbligatoria.

- 👍 <opzione 1>
- 🎉 <opzione 2>
- 🚀 <opzione 3>
- 😄 <opzione assurda>

La seduta si chiude il <data>. Il risultato va nella PR e in \`constants.ts\`.`;

async function loadParliament() {
  const box = document.getElementById('sedute');
  document.getElementById('new-seduta').href = `${REPO_URL}/issues/new?${new URLSearchParams({
    title: '🏛️ SEDUTA DEL PARLAMENTO DEI BONOBI: ',
    labels: PARLIAMENT_LABEL,
    body: NEW_SEDUTA_BODY,
  })}`;
  try {
    const sedute = (await everyIssue()).filter((i) => hasLabel(i, PARLIAMENT_LABEL) || SEDUTA_TITLE.test(i.title));
    const open = sedute.filter((i) => i.state === 'open');
    const closed = sedute.filter((i) => i.state === 'closed').slice(0, 2);
    if (open.length + closed.length === 0) {
      box.replaceChildren(el('p', { class: 'muted', text: 'Il Parlamento non è ancora stato convocato. Convoca la prima seduta qui sotto!' }));
      return;
    }
    box.replaceChildren(...open.map(sedutaCard), ...closed.map(sedutaCard));
  } catch (err) {
    showError(box, err);
  }
}

// ---------- lottatore ----------

// Barre a occhio per ogni stile: servono solo a dare un'idea nell'anteprima
const STYLE_STATS = {
  equilibrato: { Velocità: 3, Potenza: 3, Salto: 3, Peso: 3 },
  veloce: { Velocità: 5, Potenza: 2, Salto: 3, Peso: 2 },
  pesante: { Velocità: 2, Potenza: 5, Salto: 2, Peso: 5 },
  saltatore: { Velocità: 3, Potenza: 2, Salto: 5, Peso: 2 },
};

const form = document.getElementById('fighter-form');
const formMsg = document.getElementById('form-msg');

function fighterData() {
  const data = Object.fromEntries(new FormData(form));
  for (const key of Object.keys(data)) if (typeof data[key] === 'string') data[key] = data[key].trim();
  return data;
}

function updatePreview() {
  const d = fighterData();
  const svg = document.getElementById('fighter-svg');
  for (const id of ['f-body', 'f-head']) svg.querySelector(`#${id}`).setAttribute('fill', d.color1);
  for (const id of ['f-belt', 'f-glove-l', 'f-glove-r']) svg.querySelector(`#${id}`).setAttribute('fill', d.color2);
  svg.querySelector('#f-face').setAttribute('fill', '#e8c9a0');
  // Lo stile cambia la sagoma: il pesante è largo, il veloce è snello
  const shape = { equilibrato: 'scale(1, 1)', veloce: 'scale(.88, 1.04)', pesante: 'scale(1.14, .96)', saltatore: 'scale(.95, 1.08)' };
  svg.style.transform = shape[d.style] ?? '';

  document.getElementById('p-name').textContent = d.name || 'Il tuo lottatore';
  document.getElementById('p-who').textContent = d.who ? `di ${d.who}` : 'di qualcuno del canale';
  document.getElementById('p-taunt').textContent = d.taunt ? `“${d.taunt}”` : '';
  const stats = document.getElementById('p-stats');
  stats.replaceChildren(...Object.entries(STYLE_STATS[d.style] ?? STYLE_STATS.equilibrato).map(([name, value]) =>
    el('div', { class: 'stat' }, el('span', { text: name }), el('div', { class: 'bar' }, el('span', { style: { width: `${value * 20}%` } }))),
  ));
}

function fighterIssueBody(d) {
  return `### Nome del lottatore
${d.name}

### Chi è nel canale
${d.who}

### Colori
${d.color1} (principale), ${d.color2} (secondario)

### Stile
${d.style}

### Mossa firma
${d.move || '_da decidere_'}

### Provocazione
${d.taunt || '_da decidere_'}

### Frase di vittoria
${d.win || '_da decidere_'}

### Riferimenti
${d.refs || '_nessuno per ora_'}

---
- [x] La persona è d'accordo ad avere un lottatore
_Proposto dal sito del progetto._`;
}

form.addEventListener('input', updatePreview);

form.addEventListener('submit', (event) => {
  event.preventDefault();
  const d = fighterData();
  const url = `${REPO_URL}/issues/new?${new URLSearchParams({
    title: `Lottatore: ${d.name}`,
    labels: FIGHTER_LABEL,
    body: fighterIssueBody(d),
  })}`;
  window.open(url, '_blank', 'noopener');
  formMsg.textContent = 'Si è aperta GitHub con la proposta già scritta: controlla e premi "Create". Serve un account GitHub.';
});

document.getElementById('copy-discord').addEventListener('click', async () => {
  const d = fighterData();
  if (!d.name) {
    formMsg.textContent = 'Dagli almeno un nome prima di copiarlo.';
    return;
  }
  const text = `🦍 **NUOVO SFIDANTE: ${d.name}** (${d.who || 'chi sarà?'})\n` +
    `Stile: ${d.style}` + (d.move ? ` · Mossa firma: ${d.move}` : '') +
    (d.taunt ? `\n🎤 "${d.taunt}"` : '') +
    `\nFai il tuo: ${location.href.split('#')[0]}#lottatore`;
  try {
    await navigator.clipboard.writeText(text);
    formMsg.textContent = 'Copiato! Incollalo nel canale Discord.';
  } catch {
    formMsg.textContent = 'Il browser non mi lascia copiare: seleziona il testo a mano.';
  }
});

async function loadFighters() {
  const box = document.getElementById('fighters');
  try {
    const fighters = (await everyIssue()).filter((i) => hasLabel(i, FIGHTER_LABEL) || FIGHTER_TITLE.test(i.title));
    if (fighters.length === 0) {
      box.replaceChildren(el('p', { class: 'muted', text: 'Nessuno ancora. Sarai il primo sfidante?' }));
      return;
    }
    box.replaceChildren(...fighters.map((i) => el('a', { class: 'issue', href: i.html_url },
      avatar(i.user, 28),
      el('div', { class: 'body' },
        el('div', { class: 'title', text: i.title.replace(/^Lottatore:\s*/i, '') }),
        el('div', { class: 'meta', text: i.state === 'closed' ? '✅ nel gioco' : `proposto da ${i.user.login}` }),
      ),
    )));
  } catch (err) {
    showError(box, err);
  }
}

// ---------- contributori ----------

async function loadContributors() {
  const box = document.getElementById('contributors');
  try {
    const people = await gh('/contributors?per_page=50');
    box.replaceChildren(...people.filter((p) => p.type === 'User').map((p) =>
      el('a', { href: p.html_url, title: `${p.contributions} commit` }, avatar(p, 56), el('span', { text: p.login })),
    ));
  } catch (err) {
    showError(box, err);
  }
}

// ---------- avvio ----------

renderRoleFilter();
updatePreview();
loadRoadmap();
loadParliament();
loadFighters();
loadContributors();
import('./demo.js').then((m) => m.startDemo(document.getElementById('demo')));
