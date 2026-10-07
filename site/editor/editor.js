// Editor delle arene (E12): disegno e trascinamento sul canvas. I conti stanno in arena.js.

import { GRID, TEMPLATES, WORLD, hazardActive, moverPosition, problems, proposeUrl, reachable, slug, snap, toStageSpec, toStagesTs } from "./arena.js";

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
const POINT = 11; // raggio dei punti del percorso di un ascensore
const MIN_SIZE = 20;
const PLATFORM_HIT = 14; // pixel sopra e sotto la linea di una piattaforma che contano come clic
const NAMES = { solid: "Blocco", platform: "Piattaforma", mover: "Piattaforma mobile", hazard: "Trappola" };

const canvas = document.getElementById("stage");
const ctx = canvas.getContext("2d");
const $ = (id) => document.getElementById(id);

let game = FALLBACK;
let model = null; // l'arena che si sta disegnando
let spec = null; // l'arena come finirà in stages.ts, ricalcolata a ogni modifica
let selected = null; // { kind: "solid" | "platform" | "mover" | "hazard", index, point? }
let drag = null; // { mode: "move" | "width" | "height", start, orig }

const hex = (n) => `#${n.toString(16).padStart(6, "0")}`;
const LISTS = { solid: "solids", platform: "platforms", mover: "movers", hazard: "hazards" };
const list = (kind) => (model[LISTS[kind]] ??= []);
const picked = () => (selected ? list(selected.kind)[selected.index] : null);

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
  requestAnimationFrame(frame);
}

// Una copia dell'arena scelta, con il nome da cambiare
function start(baseId) {
  const base = game.stages[baseId] ?? { solids: [], platforms: [], colors: FALLBACK.stages.palco.colors };
  model = structuredClone({
    solids: base.solids,
    platforms: base.platforms,
    movers: base.movers ?? [],
    hazards: base.hazards ?? [],
    respawn: base.respawn,
    colors: base.colors,
  });
  model.name = $("name").value;
  model.id = slug(model.name);
  selected = null;
  update();
}

// Ricontrolla tutto dopo una modifica; il disegno va da solo in frame().
// withProps false: non rifà i campi sotto il canvas (si sta scrivendo in uno di loro)
function update(withProps = true) {
  spec = toStageSpec(model);
  const found = problems(spec, game.stageCheck, Object.keys(game.stages));
  const ul = $("problems");
  ul.replaceChildren(...(found.length ? found : ["Tutto a posto: si può copiare o proporre."]).map((t) => Object.assign(document.createElement("li"), { textContent: t })));
  ul.classList.toggle("ok", found.length === 0);
  $("output").value = toStagesTs(spec);
  $("id").textContent = model.id || "?";
  $("delete").disabled = !selected;
  $("propose").href = proposeUrl(spec);
  if (withProps) describe();
}

// Sotto il canvas: cosa è scelto e i suoi numeri da cambiare
function describe() {
  const c = picked();
  const props = $("props");
  props.replaceChildren();
  if (!c) {
    $("selection").textContent = "Clicca un pezzo per sceglierlo. Frecce: sposta di 10 pixel. Canc: elimina.";
    return;
  }
  const where = selected.kind === "mover" ? `percorso di ${c.path.length} punti` : `x ${c.x}, y ${c.y}, largo ${c.width}${c.height ? `, alto ${c.height}` : ""}`;
  $("selection").textContent = `${NAMES[selected.kind]}: ${where}. Frecce: sposta. Canc: elimina.`;
  if (selected.kind === "mover") {
    field(props, "Giro (s)", c.periodMs / 1000, 1, 60, 0.5, (v) => (c.periodMs = v * 1000));
    field(props, "Sosta ai punti (s)", (c.pauseMs ?? 0) / 1000, 0, 10, 0.1, (v) => (c.pauseMs = v * 1000));
    check(props, "Giro chiuso", !!c.loop, (v) => (v ? (c.loop = true) : delete c.loop));
    button(props, "+ Punto", () => {
      const last = c.path[c.path.length - 1];
      c.path.push({ x: Math.min(WORLD.width - c.width, last.x + 120), y: last.y });
    });
    if (c.path.length > 2) button(props, "− Punto", () => c.path.pop());
  } else if (selected.kind === "hazard") {
    field(props, "Danno (%)", c.damage, 1, 40, 1, (v) => (c.damage = v));
    check(props, "A ciclo", !!c.periodMs, (v) => {
      if (v) Object.assign(c, { periodMs: 4000, activeMs: 1500 });
      else {
        delete c.periodMs;
        delete c.activeMs;
      }
    });
    if (c.periodMs) {
      field(props, "Ciclo (s)", c.periodMs / 1000, 1, 30, 0.5, (v) => (c.periodMs = v * 1000));
      field(props, "Accesa (s)", c.activeMs / 1000, 0.5, 30, 0.5, (v) => (c.activeMs = Math.min(v * 1000, c.periodMs)));
    }
  }
}

function field(parent, label, value, min, max, step, set) {
  const input = Object.assign(document.createElement("input"), { type: "number", value, min, max, step });
  input.addEventListener("change", () => {
    const v = Math.max(min, Math.min(max, Number(input.value) || min));
    set(v);
    update(false);
  });
  parent.append(wrap(label, input));
}

function check(parent, label, value, set) {
  const input = Object.assign(document.createElement("input"), { type: "checkbox", checked: value });
  input.addEventListener("change", () => {
    set(input.checked);
    setTimeout(update); // rifà i campi (es. Ciclo e Accesa) dopo che il clic è finito
  });
  parent.append(wrap(label, input));
}

function button(parent, label, onClick) {
  const b = Object.assign(document.createElement("button"), { className: "btn", textContent: label });
  b.addEventListener("click", () => {
    onClick();
    update();
  });
  parent.append(b);
}

function wrap(label, input) {
  const l = document.createElement("label");
  l.append(label, input);
  return l;
}

function frame(now) {
  if (spec) draw(spec, now);
  requestAnimationFrame(frame);
}

function draw(s, t) {
  ctx.fillStyle = hex(model.colors.sky);
  ctx.fillRect(0, 0, WORLD.width, WORLD.height);
  // Griglia ogni 40 pixel, più marcata ogni 160, e il centro
  for (let x = 0; x <= WORLD.width; x += GRID * 4) line(x, 0, x, WORLD.height, x % 160 === 0 ? 0.12 : 0.05);
  for (let y = 0; y <= WORLD.height; y += GRID * 4) line(0, y, WORLD.width, y, y % 160 === 0 ? 0.12 : 0.05);
  line(WORLD.width / 2, 0, WORLD.width / 2, WORLD.height, 0.25, [8, 8]);

  model.solids.forEach((b, i) => {
    ctx.fillStyle = hex(model.colors.solid);
    ctx.fillRect(b.x, b.y, b.width, b.height);
    ctx.fillStyle = hex(model.colors.solidEdge);
    ctx.fillRect(b.x, b.y, b.width, 6);
    if (is("solid", i)) outline(b.x, b.y, b.width, b.height, true);
  });
  model.platforms.forEach((p, i) => {
    ctx.fillStyle = reachable(s, p, game.stageCheck) ? hex(model.colors.platform) : "#e74c3c";
    ctx.fillRect(p.x, p.y, p.width, 8);
    if (is("platform", i)) outline(p.x, p.y, p.width, 8, false);
  });

  // Trappole: piene quando sono accese, solo il bordo quando sono spente
  model.hazards.forEach((h, i) => {
    const color = h.kind === "fuoco" || h.kind === "laser" ? "231, 76, 60" : "241, 196, 15";
    ctx.fillStyle = `rgba(${color}, ${hazardActive(h, t) ? 0.8 : 0.15})`;
    ctx.fillRect(h.x, h.y, h.width, h.height);
    ctx.strokeStyle = `rgba(${color}, .9)`;
    ctx.lineWidth = 2;
    ctx.strokeRect(h.x, h.y, h.width, h.height);
    if (is("hazard", i)) outline(h.x, h.y, h.width, h.height, true);
  });

  // Piattaforme mobili: il percorso tratteggiato, una sagoma a ogni punto e la piattaforma dove sta adesso
  model.movers.forEach((m, i) => {
    const mid = (p) => ({ x: p.x + m.width / 2, y: p.y + 4 });
    const route = m.loop ? [...m.path, m.path[0]] : m.path;
    ctx.strokeStyle = "rgba(255, 255, 255, .45)";
    ctx.setLineDash([6, 6]);
    ctx.lineWidth = 2;
    ctx.beginPath();
    route.forEach((p, k) => (k ? ctx.lineTo(mid(p).x, mid(p).y) : ctx.moveTo(mid(p).x, mid(p).y)));
    ctx.stroke();
    for (const p of m.path) ctx.strokeRect(p.x, p.y, m.width, 8);
    ctx.setLineDash([]);
    const now = moverPosition(m, t);
    ctx.fillStyle = hex(model.colors.platform);
    ctx.fillRect(now.x, now.y, m.width, 8);
    if (is("mover", i)) outline(m.path[0].x, m.path[0].y, m.width, 8, false);
    m.path.forEach((p, k) => {
      const c = mid(p);
      ctx.fillStyle = is("mover", i) && selected.point === k ? "#f7c948" : "rgba(255, 255, 255, .85)";
      ctx.beginPath();
      ctx.arc(c.x, c.y, POINT, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#1b1b1b";
      ctx.font = "bold 12px Nunito, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(String(k + 1), c.x, c.y + 4);
    });
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

const is = (kind, index) => selected?.kind === kind && selected.index === index;

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

// Bordo della scelta e quadratini per allargare (a destra) e, se ha un'altezza, per alzare (sotto)
function outline(x, y, w, h, tall) {
  ctx.strokeStyle = "#f7c948";
  ctx.lineWidth = 3;
  ctx.strokeRect(x - 2, y - 2, w + 4, h + 4);
  ctx.fillStyle = "#f7c948";
  ctx.fillRect(x + w - HANDLE / 2, y + h / 2 - HANDLE / 2, HANDLE, HANDLE);
  if (tall) ctx.fillRect(x + w / 2 - HANDLE / 2, y + h - HANDLE / 2, HANDLE, HANDLE);
}

// Coordinate del mondo dal puntatore, qualunque sia la grandezza del canvas sullo schermo
function worldPoint(e) {
  const r = canvas.getBoundingClientRect();
  return { x: ((e.clientX - r.left) / r.width) * WORLD.width, y: ((e.clientY - r.top) / r.height) * WORLD.height };
}

const near = (px, py, x, y, d = HANDLE) => Math.abs(px - x) <= d && Math.abs(py - y) <= d;
const inside = (pt, x, y, w, h) => pt.x >= x && pt.x <= x + w && pt.y >= y && pt.y <= y + h;

// Cosa c'è sotto il puntatore, al tempo t (le piattaforme mobili si prendono dove stanno adesso)
function hit(pt, t) {
  const c = picked();
  if (c) {
    // Prima i quadratini della scelta: per una piattaforma mobile si allarga dal primo punto
    const box = selected.kind === "mover" ? { ...c.path[0], width: c.width } : c;
    const h = box.height ?? 8;
    if (near(pt.x, pt.y, box.x + box.width, box.y + h / 2)) return { sel: { ...selected, point: undefined }, mode: "width" };
    if (box.height && near(pt.x, pt.y, box.x + box.width / 2, box.y + box.height)) return { sel: selected, mode: "height" };
  }
  for (let i = model.movers.length - 1; i >= 0; i--) {
    const m = model.movers[i];
    const k = m.path.findIndex((p) => near(pt.x, pt.y, p.x + m.width / 2, p.y + 4, POINT));
    if (k >= 0) return { sel: { kind: "mover", index: i, point: k }, mode: "move" };
    const now = moverPosition(m, t);
    if (inside(pt, now.x, now.y - PLATFORM_HIT, m.width, PLATFORM_HIT * 2)) return { sel: { kind: "mover", index: i }, mode: "move" };
  }
  for (let i = model.hazards.length - 1; i >= 0; i--) {
    const h = model.hazards[i];
    if (inside(pt, h.x, h.y - 4, h.width, h.height + 8)) return { sel: { kind: "hazard", index: i }, mode: "move" };
  }
  for (let i = model.platforms.length - 1; i >= 0; i--) {
    const p = model.platforms[i];
    if (inside(pt, p.x, p.y + 4 - PLATFORM_HIT, p.width, PLATFORM_HIT * 2)) return { sel: { kind: "platform", index: i }, mode: "move" };
  }
  for (let i = model.solids.length - 1; i >= 0; i--) {
    const b = model.solids[i];
    if (inside(pt, b.x, b.y, b.width, b.height)) return { sel: { kind: "solid", index: i }, mode: "move" };
  }
  return null;
}

canvas.addEventListener("pointerdown", (e) => {
  canvas.focus();
  const pt = worldPoint(e);
  const h = hit(pt, performance.now());
  selected = h?.sel ?? null;
  const c = picked();
  drag = c ? { mode: h.mode, start: pt, orig: structuredClone(c) } : null;
  if (drag) canvas.setPointerCapture(e.pointerId);
  update();
});

canvas.addEventListener("pointermove", (e) => {
  const pt = worldPoint(e);
  if (!drag) {
    const h = hit(pt, performance.now());
    canvas.style.cursor = !h ? "default" : h.mode === "width" ? "ew-resize" : h.mode === "height" ? "ns-resize" : "move";
    return;
  }
  const dx = pt.x - drag.start.x;
  const dy = pt.y - drag.start.y;
  const c = picked();
  const o = drag.orig;
  if (drag.mode === "width") c.width = Math.max(MIN_SIZE * 2, snap((o.width ?? 0) + dx));
  else if (drag.mode === "height") c.height = Math.max(MIN_SIZE, snap(o.height + dy));
  else if (selected.kind !== "mover") Object.assign(c, { x: snap(o.x + dx), y: snap(o.y + dy) });
  else if (selected.point !== undefined) Object.assign(c.path[selected.point], { x: snap(o.path[selected.point].x + dx), y: snap(o.path[selected.point].y + dy) });
  else c.path.forEach((p, k) => Object.assign(p, { x: snap(o.path[k].x + dx), y: snap(o.path[k].y + dy) }));
  clamp(c);
  update();
});

canvas.addEventListener("pointerup", () => (drag = null));

// Dentro lo schermo, con la superficie tra il bordo in alto e quello in basso
function clamp(c) {
  c.width = Math.min(c.width, WORLD.width);
  const fit = (p) => {
    p.x = Math.max(0, Math.min(WORLD.width - c.width, p.x));
    p.y = Math.max(GRID, Math.min(WORLD.height - GRID, p.y));
  };
  if (c.path) c.path.forEach(fit);
  else fit(c);
  if (c.height) c.height = Math.min(c.height, WORLD.height - c.y);
}

canvas.addEventListener("keydown", (e) => {
  const c = picked();
  if (!c) return;
  const step = { ArrowLeft: [-GRID, 0], ArrowRight: [GRID, 0], ArrowUp: [0, -GRID], ArrowDown: [0, GRID] }[e.key];
  if (step) {
    const targets = !c.path ? [c] : selected.point !== undefined ? [c.path[selected.point]] : c.path;
    for (const p of targets) {
      p.x += step[0];
      p.y += step[1];
    }
    clamp(c);
  } else if (e.key === "Delete" || e.key === "Backspace") remove();
  else return;
  e.preventDefault();
  update();
});

function remove() {
  if (!selected) return;
  list(selected.kind).splice(selected.index, 1);
  selected = null;
  update();
}

// I nuovi pezzi compaiono in mezzo, dove si vedono
function add(kind, item) {
  list(kind).push(item);
  selected = { kind, index: list(kind).length - 1 };
  update();
}
$("add-solid").addEventListener("click", () => add("solid", { x: 540, y: 600, width: 200, height: 80 }));
$("add-platform").addEventListener("click", () => add("platform", { x: 560, width: 160, y: 440 }));
for (const [name, make] of Object.entries(TEMPLATES)) {
  $(`add-${name}`).addEventListener("click", () => add(make().path ? "mover" : "hazard", make()));
}
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
