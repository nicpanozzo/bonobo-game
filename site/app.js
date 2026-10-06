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

// ---------- scarica e gioca ----------

const DOWNLOAD = `${REPO_URL}/releases/latest/download`;
const SYSTEMS = {
  windows: { name: 'Windows', game: 'bonobo-game-windows.zip', server: 'bonobo-server-windows.zip' },
  mac: { name: 'Mac', game: 'bonobo-game-mac.zip', server: 'bonobo-server-mac.zip' },
  'mac-intel': { name: 'Mac Intel', game: 'bonobo-game-mac.zip', server: 'bonobo-server-mac-intel.zip' },
  linux: { name: 'Linux', game: 'bonobo-game-linux.zip', server: 'bonobo-server-linux.zip' },
};

// Che computer ha chi guarda la pagina. Sul Mac il browser non dice il chip: lo indovina la scheda video
function detectSystem() {
  const ua = navigator.userAgent;
  const platform = navigator.userAgentData?.platform || navigator.platform || '';
  if (/Android|iPhone|iPad|iPod/i.test(ua) || (/Mac/.test(platform) && navigator.maxTouchPoints > 1)) return 'mobile';
  if (/Win/i.test(platform)) return 'windows';
  if (/Mac/i.test(platform)) {
    try {
      const gl = document.createElement('canvas').getContext('webgl');
      const info = gl?.getExtension('WEBGL_debug_renderer_info');
      const gpu = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : '';
      if (/Intel|AMD|Radeon|NVIDIA/i.test(gpu)) return 'mac-intel';
    } catch {
      // niente WebGL: si va sul chip Apple, che hanno quasi tutti i Mac di oggi
    }
    return 'mac';
  }
  if (/Linux|X11/i.test(platform + ua)) return 'linux';
  return null;
}

function setupDownloads() {
  const system = detectSystem();
  const game = document.getElementById('dl-game');
  const server = document.getElementById('dl-server');
  const known = SYSTEMS[system];
  if (known) {
    game.href = `${DOWNLOAD}/${known.game}`;
    game.textContent = `Scarica per ${known.name === 'Mac Intel' ? 'Mac' : known.name}`;
    server.href = `${DOWNLOAD}/${known.server}`;
    server.textContent = `Scarica il server per ${known.name}`;
  } else if (system === 'mobile') {
    // Il gioco da scaricare è per computer: dal telefono si gioca nel browser
    game.href = 'godot/';
    game.textContent = 'Gioca nel browser';
    document.getElementById('dl-browser').hidden = true;
    document.getElementById('server-note').textContent = 'Il server si scarica da un computer.';
  }
}

async function loadRelease() {
  const info = document.getElementById('release-info');
  try {
    const release = await gh('/releases/latest');
    info.textContent = `Adesso è la ${release.tag_name}, uscita il ${shortDate(release.published_at)}.`;
    // Le Release più vecchie del server da scaricare (#78) non lo hanno ancora
    if (!release.assets.some((a) => a.name.startsWith('bonobo-server'))) {
      document.getElementById('server-note').textContent = 'Il server da scaricare arriva con la prossima versione: intanto si ospita dal codice con npm run host.';
    }
  } catch {
    // senza GitHub i link "latest" funzionano lo stesso
  }
}

// Dal link della serata (o dal solo indirizzo del server) all'indirizzo del gioco nel browser
function joinUrl(text) {
  const raw = text.trim();
  if (!raw) return null;
  let url;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  const params = new URLSearchParams();
  const room = url.searchParams.get('room');
  const server = url.searchParams.get('server');
  if (server) params.set('server', server);
  else if (!url.hostname.endsWith('github.io')) params.set('server', url.origin); // incollato solo il server
  else return null;
  if (room) params.set('room', room);
  return `godot/?${params}`;
}

function setupJoin() {
  const form = document.getElementById('join-form');
  const msg = document.getElementById('join-msg');
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    const target = joinUrl(document.getElementById('join-link').value);
    if (!target) {
      msg.textContent = 'Questo non sembra il link di una serata: chiedi a chi ospita di rimandarlo.';
      return;
    }
    msg.textContent = '';
    location.href = target;
  });
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
  // Le issue senza stato (appena aperte) non devono sparire: le mostriamo a parte.
  // Roadmap, sedute e proposte di lottatori hanno già la loro sezione.
  const fresh = visible.filter((i) => !has(i, 'pronto') && !has(i, 'in attesa') && !has(i, 'roadmap')
    && !has(i, PARLIAMENT_LABEL) && !has(i, FIGHTER_LABEL) && !SEDUTA_TITLE.test(i.title) && !FIGHTER_TITLE.test(i.title));
  document.getElementById('new-block').hidden = fresh.length === 0;
  fill(document.getElementById('issues-new'), fresh, '');
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

// Si vota con un sondaggio nel canale Discord: la issue è il verbale della seduta.
// Le opzioni sono le righe a elenco ("- Calcio rotante"), il link al sondaggio è un link discord.com
// e, a seduta chiusa, la riga "Esito: ..." dice chi ha vinto.
const DISCORD_LINK = /https:\/\/(?:www\.)?(?:discord\.com|discordapp\.com|discord\.gg)\/[^\s)>\]]+/;
const OUTCOME_LINE = /^\s*\**\s*Esito\s*:?\s*\**\s*:?\s*(.+)$/im;

function parseSeduta(body) {
  const text = body ?? '';
  const options = [];
  for (const line of text.split('\n')) {
    const match = /^\s*[-*]\s+(?!\[)(.+)$/.exec(line);
    if (match) options.push(match[1].replace(/\*\*/g, '').trim());
  }
  const outcome = OUTCOME_LINE.exec(text)?.[1].replace(/\*\*/g, '').trim();
  return { options, poll: DISCORD_LINK.exec(text)?.[0], outcome };
}

function sedutaCard(issue) {
  const { options, poll, outcome } = parseSeduta(issue.body);
  const closed = issue.state === 'closed';
  const card = el('article', { class: 'seduta' },
    el('h3', { text: issue.title.replace(/^(🏛\uFE0F?\s*)/u, '') }),
    el('div', { class: 'stato', text: `${closed ? '🔨 Deliberato' : '🗳️ Seduta aperta: si vota sul Discord'} · #${issue.number}` }),
  );
  const list = el('ul', { class: 'mozioni' });
  for (const option of options) {
    const winner = closed && outcome && outcome.toLowerCase().includes(option.toLowerCase());
    list.append(el('li', { class: winner ? 'vince' : '', text: winner ? `🏆 ${option}` : option }));
  }
  card.append(list);
  if (closed && outcome) card.append(el('p', { class: 'esito', text: `Esito: ${outcome}` }));
  if (!closed) {
    card.append(poll
      ? el('a', { class: 'btn btn-primary', href: poll, target: '_blank', rel: 'noopener', text: 'Vota sul Discord' })
      : el('p', { class: 'small muted', text: 'Il sondaggio è nel canale Discord dei Bonobi.' }));
  }
  card.append(' ', el('a', { class: 'btn', href: issue.html_url, text: closed ? 'Leggi la delibera' : 'Il verbale su GitHub' }));
  return card;
}

const NEW_SEDUTA_BODY = `Ordine del giorno: <la questione, in una frase>

Si vota nel sondaggio sul canale Discord. Almeno un'opzione assurda è obbligatoria.

- <opzione 1>
- <opzione 2>
- <opzione 3>
- <opzione assurda>

Sondaggio: <link al messaggio del sondaggio su Discord>

A seduta chiusa aggiungi la riga "Esito: <opzione vincente>" e chiudi l'issue. Il risultato va nella PR e in \`constants.ts\`.`;

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

setupDownloads();
setupJoin();
loadRelease();
renderRoleFilter();
updatePreview();
loadRoadmap();
loadParliament();
loadFighters();
loadContributors();
import('./demo.js').then((m) => m.startDemo(document.getElementById('demo')));
