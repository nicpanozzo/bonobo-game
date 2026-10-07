// Logica pura dell'editor delle arene (E12 passo 1): niente DOM, così la provano anche i test
// (src/shared/stageEditor.test.ts). I numeri del salto arrivano da game.json (stageCheck).

export const WORLD = { width: 1280, height: 720 };
export const GRID = 10; // pixel: passo a cui si agganciano posizioni e misure
const SPAWN_MARGIN = 30; // pixel di terreno che servono intorno a una partenza, per non partire sul bordo
const SPAWN_PAIRS = [0.6, 0.15, 0.95, 0.35]; // dove cadono le 4 coppie tra centro (0) e bordo (1), come nel Palco
const DEFAULT_RESPAWN_Y = 160;

// Stesso conto di reachable in src/shared/stageCheck.ts
export function reachable(stage, p, check) {
  return [...stage.solids, ...stage.platforms].some((s) => {
    if (s.y <= p.y) return false;
    const gap = Math.max(0, s.x - (p.x + p.width), p.x - (s.x + s.width));
    const rise = s.y - p.y;
    return (gap <= check.sideReach && rise <= check.jumpHeight) || (gap === 0 && rise <= check.doubleJumpHeight * 0.9);
  });
}

// La superficie più alta di un blocco pieno che copre tutto [x - margin, x + margin], o null
function groundAt(solids, x, margin) {
  let best = null;
  for (const s of solids) {
    if (x - margin < s.x || x + margin > s.x + s.width) continue;
    if (best === null || s.y < best) best = s.y;
  }
  return best;
}

// Un punto di partenza a x, sulla superficie y, ha vicino un ascensore o una trappola?
const FIGHTER_HEIGHT = 88;
function busy(stage, x, y) {
  const near = (top, bottom) => bottom >= y - FIGHTER_HEIGHT - 20 && top <= y + 20;
  const across = (left, right) => right >= x - SPAWN_MARGIN && left <= x + SPAWN_MARGIN;
  for (const h of stage.hazards ?? []) if (across(h.x, h.x + h.width) && near(h.y, h.y + h.height)) return true;
  for (const m of stage.movers ?? []) {
    const xs = m.path.map((p) => p.x);
    const ys = m.path.map((p) => p.y);
    if (across(Math.min(...xs), Math.max(...xs) + m.width) && near(Math.min(...ys), Math.max(...ys))) return true;
  }
  return false;
}

// 8 partenze in coppie simmetriche rispetto al centro, sui blocchi pieni, lontano da ascensori e trappole.
// [] se non c'è posto
export function generateSpawns(stage) {
  const center = WORLD.width / 2;
  const valid = [];
  for (let d = GRID * 2; d < center; d += GRID) {
    const yl = groundAt(stage.solids, center - d, SPAWN_MARGIN);
    const yr = groundAt(stage.solids, center + d, SPAWN_MARGIN);
    if (yl === null || yl !== yr || busy(stage, center - d, yl) || busy(stage, center + d, yr)) continue;
    valid.push({ d, y: yl });
  }
  if (valid.length === 0) return [];
  const spawns = [];
  for (const q of SPAWN_PAIRS) {
    const { d, y } = valid[Math.min(valid.length - 1, Math.floor(q * valid.length))];
    spawns.push({ x: center - d, y }, { x: center + d, y });
  }
  return spawns;
}

// Cosa non va nell'arena, in parole: vuoto se si può copiare in stages.ts
// taken: gli id delle arene che ci sono già
export function problems(stage, check, taken = []) {
  const out = [];
  if (!stage.name.trim()) out.push("Manca il nome.");
  if (!/^[a-z][a-z0-9-]*$/.test(stage.id)) out.push("L'id va scritto in minuscolo, senza spazi.");
  else if (taken.includes(stage.id)) out.push(`C'è già un'arena con id "${stage.id}": cambia il nome.`);
  if (stage.solids.length === 0) out.push("Serve almeno un blocco pieno.");
  if (stage.spawns.length === 0) out.push("Non c'è posto per le partenze: servono blocchi pieni a destra e a sinistra del centro, alla stessa altezza.");
  const unreachable = stage.platforms.filter((p) => !reachable(stage, p, check)).length;
  if (unreachable) out.push(`${unreachable === 1 ? "Una piattaforma rossa non si raggiunge" : `${unreachable} piattaforme rosse non si raggiungono`}: abbassala o avvicinala a un appoggio.`);
  return out;
}

// L'arena completa, nella forma di StageSpec in src/shared/stages.ts
export function toStageSpec(model) {
  const spec = {
    id: model.id,
    name: model.name,
    solids: model.solids.map(({ x, y, width, height }) => ({ x, y, width, height })),
    platforms: model.platforms.map(({ x, width, y }) => ({ x, width, y })),
    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },
    spawns: generateSpawns(model),
    respawn: model.respawn ?? { x: WORLD.width / 2, y: DEFAULT_RESPAWN_Y },
    colors: model.colors,
  };
  if (model.movers?.length) spec.movers = model.movers;
  if (model.hazards?.length) spec.hazards = model.hazards;
  return spec;
}

// Un valore scritto come in stages.ts: chiavi senza virgolette, colori in esadecimale
function literal(value, key) {
  if (Array.isArray(value)) return `[${value.map((v) => literal(v)).join(", ")}]`;
  if (value && typeof value === "object") return `{ ${Object.entries(value).map(([k, v]) => `${k}: ${literal(v, k)}`).join(", ")} }`;
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number" && COLOR_KEYS.has(key)) return `0x${value.toString(16).padStart(6, "0")}`;
  return String(value);
}
const COLOR_KEYS = new Set(["sky", "solid", "solidEdge", "platform"]);

// Il blocco da incollare dentro STAGES in src/shared/stages.ts
export function toStagesTs(spec) {
  const list = (items) => (items.length ? `[\n${items.map((i) => `      ${literal(i)},`).join("\n")}\n    ]` : "[]");
  const respawnX = spec.respawn.x === WORLD.width / 2 ? "WORLD.width / 2" : String(spec.respawn.x);
  const lines = [
    `  // Disegnata con l'editor delle arene (site/editor). TODO community: un posto nostro per quest'arena`,
    `  ${JSON.stringify(spec.id)}: {`,
    `    id: ${JSON.stringify(spec.id)},`,
    `    name: ${JSON.stringify(spec.name)},`,
    `    solids: ${list(spec.solids)},`,
    `    platforms: ${list(spec.platforms)},`,
  ];
  if (spec.movers) lines.push(`    movers: ${list(spec.movers)},`);
  if (spec.hazards) lines.push(`    hazards: ${list(spec.hazards)},`);
  lines.push(
    `    blastZone: { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 },`,
    `    spawns: ${list(spec.spawns)},`,
    `    respawn: { x: ${respawnX}, y: ${spec.respawn.y} },`,
    `    colors: ${literal(spec.colors)},`,
    `  },`,
  );
  return lines.join("\n");
}

// Un nome in un id: "La Mia Arena!" diventa "la-mia-arena"
export function slug(name) {
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/^[^a-z]+/, "");
}

export const snap = (v) => Math.round(v / GRID) * GRID;

// Come moverPosition in src/shared/physics/elements.ts: dove sta una piattaforma mobile al tempo t (ms)
export function moverPosition(m, t) {
  const pts = m.path;
  if (pts.length < 2) return pts[0] ?? { x: 0, y: 0 };
  const route = m.loop ? [...pts, pts[0]] : [...pts, ...pts.slice(0, -1).reverse()];
  const segments = route.length - 1;
  const pause = m.pauseMs ?? 0;
  const lengths = route.slice(1).map((p, i) => Math.hypot(p.x - route[i].x, p.y - route[i].y));
  const total = lengths.reduce((a, b) => a + b, 0);
  const travel = Math.max(1, m.periodMs - pause * segments);
  let left = mod(t + (m.offsetMs ?? 0), m.periodMs);
  for (let i = 0; i < segments; i++) {
    if (left < pause) return route[i];
    left -= pause;
    const segMs = total > 0 ? (travel * lengths[i]) / total : travel / segments;
    if (left < segMs) {
      const k = left / segMs;
      return { x: route[i].x + (route[i + 1].x - route[i].x) * k, y: route[i].y + (route[i + 1].y - route[i].y) * k };
    }
    left -= segMs;
  }
  return route[segments];
}

// Come hazardActive in src/shared/physics/elements.ts
export function hazardActive(h, t) {
  if (!h.periodMs) return true;
  return mod(t + (h.offsetMs ?? 0), h.periodMs) < (h.activeMs ?? h.periodMs / 2);
}

const mod = (a, n) => ((a % n) + n) % n;

// Gli elementi nuovi partono da questi numeri, gli stessi della Fabbrica
export const TEMPLATES = {
  ascensore: () => ({ width: 140, path: [{ x: 570, y: 540 }, { x: 570, y: 300 }], periodMs: 7000, pauseMs: 1200 }),
  navetta: () => ({ width: 150, path: [{ x: 300, y: 400 }, { x: 830, y: 400 }], periodMs: 9000, pauseMs: 600 }),
  spuntoni: () => ({ kind: "spuntoni", x: 600, y: 540, width: 80, height: 20, damage: 10, knockback: 500, knockbackGrowth: 6, angleDeg: 60 }),
  fuoco: () => ({ kind: "fuoco", x: 560, y: 610, width: 160, height: 30, damage: 8, knockback: 600, knockbackGrowth: 4, angleDeg: 80, periodMs: 4000, activeMs: 1500 }),
};

// "Proponi": il modulo Arena nuova su GitHub con nome e dati già scritti (i campi si riempiono dal loro id)
export function proposeUrl(spec) {
  const params = new URLSearchParams({
    template: "arena.yml",
    title: `Arena: ${spec.name}`,
    nome: spec.name,
    forma: "Disegnata con l'editor delle arene: i numeri sono in Dati.",
    dati: JSON.stringify(spec, null, 2),
  });
  return `https://github.com/nicpanozzo/bonobo-game/issues/new?${params}`;
}
