// Editor delle arene (E12 passo 1): disegno e trascinamento sul canvas. I conti stanno in arena.js.

import { GRID, WORLD, problems, reachable, slug, snap, toStageSpec, toStagesTs } from "./arena.js";

// Le arene e i numeri del salto vengono dal gioco su main; se non si caricano si parte da un palco semplice
const GAME_JSON = "https://raw.githubusercontent.com/nicpanozzo/bonobo-game/main/godot/data/game.json";
const FALLBACK = {
  stages: {
    palco: {
      id: "palco",
      name: "Il Palco",
      solids: [{ x: 240, y: 560, width: 800, height: 80 }],
      platforms: [],
      respawn: { x: 640, y: 160 },
      colors: { sky: 0x1d2b3a, solid: 0x5a3d26, solidEdge: 0x8b6a45, platform: 0xa0a8b8 },
    },
  },
  stageCheck: { jumpHeight: 160, doubleJumpHeight: 293, sideReach: 250 },
};
const HANDLE = 14; // pixel del quadratino per allargare
const MIN_SIZE = 40;
const PLATFORM_HIT = 14; // pixel sopra e sotto la linea di una piattaforma che contano come clic

const canvas = document.getElementById("stage");
const ctx = canvas.getContext("2d");
const $ = (id) => document.getElementById(id);

let game = FALLBACK;
let model = null; // l'arena che si sta disegnando
let selected = null; // { kind: "solid" | "platform", index }
let drag = null; // { mode: "move" | "width" | "height", dx, dy }

const hex = (n) => `#${n.toString(16).padStart(6, "0")}`;
const items = (kind) => (kind === "solid" ? model.solids : model.platforms);
const current = () => (selected ? items(selected.kind)[selected.index] : null);

async function load() {
  try {
    const res = await fetch(GAME_JSON, { cache: "no-cache" });
    if (res.ok) {
      const data = await res.json();
      game = { stages: data.stages, stageCheck: data.stageCheck ?? FALLBACK.stageCheck };
    }
  } catch {
    // Senza rete si parte dal palco di riserva
  }
  const select = $("base");
  for (const s of Object.values(game.stages)) {
    if (s.goal) continue;
    select.append(new Option(s.name, s.id));
  }
  select.append(new Option("Vuota", ""));
  select.addEventListener("change", () => start(select.value));
  start(select.value);
}

// Una copia dell'arena scelta, con il nome da cambiare
function start(baseId) {
  const base = game.stages[baseId] ?? { solids: [], platforms: [], colors: FALLBACK.stages.palco.colors };
  model = structuredClone({
    solids: base.solids,
    platforms: base.platforms,
    movers: base.movers,
    hazards: base.hazards,
    respawn: base.respawn,
    colors: base.colors,
  });
  model.name = $("name").value;
  model.id = slug(model.name);
  select(null);
  update();
}

function spec() {
  return toStageSpec(model);
}

// Ridisegna e ricontrolla tutto
function update() {
  const s = spec();
  draw(s);
  const list = problems(s, game.stageCheck, Object.keys(game.stages));
  const ul = $("problems");
  ul.replaceChildren(...(list.length ? list : ["Tutto a posto: si può copiare."]).map((t) => Object.assign(document.createElement("li"), { textContent: t })));
  ul.classList.toggle("ok", list.length === 0);
  $("output").value = toStagesTs(s);
  $("id").textContent = model.id || "?";
  $("delete").disabled = !selected;
  const c = current();
  $("selection").textContent = c
    ? `${selected.kind === "solid" ? "Blocco" : "Piattaforma"}: x ${c.x}, y ${c.y}, largo ${c.width}${c.height ? `, alto ${c.height}` : ""}. Frecce: sposta. Canc: elimina.`
    : "Clicca un blocco o una piattaforma per sceglierlo. Frecce: sposta di 10 pixel. Canc: elimina.";
}

function draw(s) {
  ctx.fillStyle = hex(model.colors.sky);
  ctx.fillRect(0, 0, WORLD.width, WORLD.height);
  // Griglia ogni 40 pixel, più marcata ogni 160, e il centro
  for (let x = 0; x <= WORLD.width; x += GRID * 4) line(x, 0, x, WORLD.height, x % 160 === 0 ? 0.12 : 0.05);
  for (let y = 0; y <= WORLD.height; y += GRID * 4) line(0, y, WORLD.width, y, y % 160 === 0 ? 0.12 : 0.05);
  line(WORLD.width / 2, 0, WORLD.width / 2, WORLD.height, 0.25, [8, 8]);

  // Trappole e percorsi degli ascensori: si vedono, si cambiano nel passo 2
  for (const h of model.hazards ?? []) {
    ctx.fillStyle = h.kind === "fuoco" ? "rgba(231, 76, 60, .45)" : "rgba(241, 196, 15, .5)";
    ctx.fillRect(h.x, h.y, h.width, h.height);
  }
  for (const m of model.movers ?? []) {
    ctx.strokeStyle = "rgba(255, 255, 255, .35)";
    ctx.setLineDash([6, 6]);
    ctx.lineWidth = 2;
    ctx.strokeRect(Math.min(...m.path.map((p) => p.x)), Math.min(...m.path.map((p) => p.y)), Math.max(...m.path.map((p) => p.x)) - Math.min(...m.path.map((p) => p.x)) + m.width, Math.max(...m.path.map((p) => p.y)) - Math.min(...m.path.map((p) => p.y)) + 8);
    ctx.setLineDash([]);
  }

  model.solids.forEach((b, i) => {
    ctx.fillStyle = hex(model.colors.solid);
    ctx.fillRect(b.x, b.y, b.width, b.height);
    ctx.fillStyle = hex(model.colors.solidEdge);
    ctx.fillRect(b.x, b.y, b.width, 6);
    if (selected?.kind === "solid" && selected.index === i) outline(b.x, b.y, b.width, b.height, true);
  });
  model.platforms.forEach((p, i) => {
    const ok = reachable(s, p, game.stageCheck);
    ctx.fillStyle = ok ? hex(model.colors.platform) : "#e74c3c";
    ctx.fillRect(p.x, p.y, p.width, 8);
    if (selected?.kind === "platform" && selected.index === i) outline(p.x, p.y, p.width, 8, false);
  });

  // Partenze numerate e punto di ritorno dopo un KO
  ctx.font = "bold 14px Nunito, sans-serif";
  ctx.textAlign = "center";
  s.spawns.forEach((p, i) => {
    ctx.fillStyle = "rgba(247, 201, 72, .9)";
    ctx.beginPath();
    ctx.arc(p.x, p.y - 14, 12, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#1b1b1b";
    ctx.fillText(String(i + 1), p.x, p.y - 9);
  });
  ctx.strokeStyle = "rgba(255, 255, 255, .6)";
  ctx.beginPath();
  ctx.arc(s.respawn.x, s.respawn.y, 10, 0, Math.PI * 2);
  ctx.stroke();
}

function line(x1, y1, x2, y2, alpha, dash = []) {
  ctx.strokeStyle = `rgba(255, 255, 255, ${alpha})`;
  ctx.lineWidth = 1;
  ctx.setLineDash(dash);
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.stroke();
  ctx.setLineDash([]);
}

// Bordo della scelta e quadratini per allargare (a destra) e, sui blocchi, per alzare (sotto)
function outline(x, y, w, h, tall) {
  ctx.strokeStyle = "#f7c948";
  ctx.lineWidth = 3;
  ctx.strokeRect(x - 2, y - 2, w + 4, h + 4);
  ctx.fillStyle = "#f7c948";
  ctx.fillRect(x + w - HANDLE / 2, y + h / 2 - HANDLE / 2, HANDLE, HANDLE);
  if (tall) ctx.fillRect(x + w / 2 - HANDLE / 2, y + h - HANDLE / 2, HANDLE, HANDLE);
}

function select(sel) {
  selected = sel;
}

// Coordinate del mondo dal puntatore, qualunque sia la grandezza del canvas sullo schermo
function worldPoint(e) {
  const r = canvas.getBoundingClientRect();
  return { x: ((e.clientX - r.left) / r.width) * WORLD.width, y: ((e.clientY - r.top) / r.height) * WORLD.height };
}

const near = (px, py, x, y) => Math.abs(px - x) <= HANDLE && Math.abs(py - y) <= HANDLE;

function hit(pt) {
  // Prima i quadratini della scelta, poi le piattaforme (sottili, stanno sopra), poi i blocchi
  const c = current();
  if (c) {
    const h = c.height ?? 8;
    if (near(pt.x, pt.y, c.x + c.width, c.y + h / 2)) return { sel: selected, mode: "width" };
    if (c.height && near(pt.x, pt.y, c.x + c.width / 2, c.y + c.height)) return { sel: selected, mode: "height" };
  }
  for (let i = model.platforms.length - 1; i >= 0; i--) {
    const p = model.platforms[i];
    if (pt.x >= p.x && pt.x <= p.x + p.width && Math.abs(pt.y - p.y - 4) <= PLATFORM_HIT) return { sel: { kind: "platform", index: i }, mode: "move" };
  }
  for (let i = model.solids.length - 1; i >= 0; i--) {
    const b = model.solids[i];
    if (pt.x >= b.x && pt.x <= b.x + b.width && pt.y >= b.y && pt.y <= b.y + b.height) return { sel: { kind: "solid", index: i }, mode: "move" };
  }
  return null;
}

canvas.addEventListener("pointerdown", (e) => {
  canvas.focus();
  const pt = worldPoint(e);
  const h = hit(pt);
  select(h?.sel ?? null);
  const c = current();
  drag = c ? { mode: h.mode, dx: pt.x - c.x, dy: pt.y - c.y } : null;
  if (drag) canvas.setPointerCapture(e.pointerId);
  update();
});

canvas.addEventListener("pointermove", (e) => {
  const pt = worldPoint(e);
  if (!drag) {
    const h = hit(pt);
    canvas.style.cursor = !h ? "default" : h.mode === "width" ? "ew-resize" : h.mode === "height" ? "ns-resize" : "move";
    return;
  }
  const c = current();
  if (drag.mode === "move") {
    c.x = snap(pt.x - drag.dx);
    c.y = snap(pt.y - drag.dy);
  } else if (drag.mode === "width") c.width = Math.max(MIN_SIZE, snap(pt.x - c.x));
  else c.height = Math.max(MIN_SIZE, snap(pt.y - c.y));
  clamp(c);
  update();
});

canvas.addEventListener("pointerup", () => (drag = null));

// Dentro lo schermo, con la superficie tra il bordo in alto e quello in basso
function clamp(c) {
  c.width = Math.min(c.width, WORLD.width);
  c.x = Math.max(0, Math.min(WORLD.width - c.width, c.x));
  c.y = Math.max(GRID, Math.min(WORLD.height - GRID, c.y));
  if (c.height) c.height = Math.min(c.height, WORLD.height - c.y);
}

canvas.addEventListener("keydown", (e) => {
  const c = current();
  if (!c) return;
  const step = { ArrowLeft: [-GRID, 0], ArrowRight: [GRID, 0], ArrowUp: [0, -GRID], ArrowDown: [0, GRID] }[e.key];
  if (step) {
    c.x += step[0];
    c.y += step[1];
    clamp(c);
  } else if (e.key === "Delete" || e.key === "Backspace") remove();
  else return;
  e.preventDefault();
  update();
});

function remove() {
  if (!selected) return;
  items(selected.kind).splice(selected.index, 1);
  select(null);
  update();
}

// I nuovi pezzi compaiono in mezzo, dove si vedono
$("add-solid").addEventListener("click", () => {
  model.solids.push({ x: 540, y: 600, width: 200, height: 80 });
  select({ kind: "solid", index: model.solids.length - 1 });
  update();
});
$("add-platform").addEventListener("click", () => {
  model.platforms.push({ x: 560, width: 160, y: 440 });
  select({ kind: "platform", index: model.platforms.length - 1 });
  update();
});
$("delete").addEventListener("click", remove);

$("name").addEventListener("input", () => {
  model.name = $("name").value;
  model.id = slug(model.name);
  update();
});

$("copy").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText($("output").value);
    $("copied").textContent = "Copiato: incollalo dentro STAGES in src/shared/stages.ts";
  } catch {
    $("output").closest("details").open = true;
    $("output").select();
    $("copied").textContent = "Copia a mano il testo qui sotto";
  }
});

load();
