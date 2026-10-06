// Percorsi della modalità Corsa (#57): un livello platformer lungo qualche schermo, generato
// da un seme come le arene casuali. Si va da sinistra a destra saltando tra blocchi pieni e
// piattaforme sottili sospese sul vuoto; chi cade riparte dall'ultimo checkpoint.
// Ogni appoggio si raggiunge con un salto dal precedente (lo controlla stages.test.ts).

import { COURSE, MAX_PLAYERS_PER_ROOM, WORLD } from "./constants";
import { MAX_SEED, PALETTES, rng } from "./stageGenerator";
import type { Rect, StageSpec, ThinPlatform } from "./stages";

export const COURSE_PREFIX = "corsa-";

export function randomCourseId(): string {
  return `${COURSE_PREFIX}${Math.floor(Math.random() * MAX_SEED)}`;
}

export function seedFromCourseId(id: string): number | null {
  const m = /^corsa-(\d{1,6})$/.exec(id);
  return m ? Number(m[1]) : null;
}

// Un appoggio del percorso, nell'ordine in cui si incontra
export interface CourseStep {
  x: number;
  y: number;
  width: number;
  solid: boolean;
}

export function generateCourse(seed: number): StageSpec {
  const r = rng(seed);
  const [minY, maxY] = COURSE.y;
  const clampY = (y: number) => Math.max(minY, Math.min(maxY, y));
  // Blocchi pieni alti fino a sotto lo schermo: di lato fanno da muro, si scavalcano saltando
  const block = (x: number, y: number, width: number): Rect => ({ x, y, width, height: WORLD.height - y + 80 });

  const steps: CourseStep[] = [{ x: 80, y: 560, width: COURSE.startWidth, solid: true }];
  const goalX = 80 + COURSE.length;
  for (;;) {
    const prev = steps[steps.length - 1];
    const x = prev.x + prev.width + r.range(COURSE.gap);
    if (x > goalX - COURSE.goalWidth) break;
    const solid = r.next() >= COURSE.platformChance;
    const width = r.range(solid ? COURSE.solidWidth : COURSE.platformWidth);
    // Si sale al massimo di COURSE.rise, si scende anche di più
    const y = clampY(prev.y - COURSE.rise + Math.round((r.next() * (COURSE.rise + 160)) / 10) * 10);
    steps.push({ x, y, width, solid });
  }
  const last = steps[steps.length - 1];
  const finalY = clampY(last.y - Math.round((r.next() * COURSE.rise) / 10) * 10);
  steps.push({ x: last.x + last.width + r.range(COURSE.gap), y: finalY, width: COURSE.goalWidth, solid: true });

  const solids: Rect[] = [];
  const platforms: ThinPlatform[] = [];
  for (const s of steps) {
    if (s.solid) solids.push(block(s.x, s.y, s.width));
    else platforms.push({ x: s.x, y: s.y, width: s.width });
  }

  // Checkpoint al centro degli appoggi, distanziati: il primo è la partenza
  const checkpoints: { x: number; y: number }[] = [];
  for (const s of steps.slice(0, -1)) {
    const cx = Math.round(s.x + s.width / 2);
    if (checkpoints.length === 0 || cx - checkpoints[checkpoints.length - 1].x >= COURSE.checkpointEvery) checkpoints.push({ x: cx, y: s.y });
  }

  const end = steps[steps.length - 1];
  const goal: Rect = { x: end.x + end.width - 180, y: end.y - 200, width: 120, height: 200 };
  const width = end.x + end.width + 200;
  const start = steps[0];
  const spawns = Array.from({ length: MAX_PLAYERS_PER_ROOM }, (_, i) => ({
    x: Math.round(start.x + 60 + (i * (start.width - 120)) / (MAX_PLAYERS_PER_ROOM - 1)),
    y: start.y,
  }));

  return {
    id: `${COURSE_PREFIX}${seed}`,
    name: `Percorso n. ${seed}`,
    solids,
    platforms,
    blastZone: { left: -250, right: width + 250, top: -400, bottom: WORLD.height + 200 },
    spawns,
    respawn: { x: checkpoints[0].x, y: checkpoints[0].y - COURSE.respawnHeight },
    colors: PALETTES[Math.floor(r.next() * PALETTES.length)],
    width,
    checkpoints,
    goal,
  };
}

// Gli appoggi del percorso in ordine, per i test e per chi disegna una minimappa
export function courseSteps(stage: StageSpec): CourseStep[] {
  return [
    ...stage.solids.map((s) => ({ x: s.x, y: s.y, width: s.width, solid: true })),
    ...stage.platforms.map((p) => ({ x: p.x, y: p.y, width: p.width, solid: false })),
  ].sort((a, b) => a.x - b.x);
}
