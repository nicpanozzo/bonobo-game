import { AUDIO } from "../shared/constants";

// Preferenze di chi gioca, salvate nel browser. Le opzioni (menu) le cambiano,
// il resto del client le legge con getSettings() e ascolta i cambi con onSettingsChange().

// Le azioni che si possono assegnare a un tasto (le stesse di InputState)
export const ACTIONS = ["left", "right", "up", "down", "light", "heavy", "taunt"] as const;
export type Action = (typeof ACTIONS)[number];
// Tasti indicati con KeyboardEvent.code ("KeyA", "ArrowLeft", "Space"...): non dipendono dalla lingua della tastiera
export type Bindings = Record<Action, string[]>;

export const DEFAULT_BINDINGS: Bindings = {
  left: ["KeyA", "ArrowLeft"],
  right: ["KeyD", "ArrowRight"],
  up: ["KeyW", "ArrowUp", "Space"],
  down: ["KeyS", "ArrowDown"],
  light: ["KeyJ"],
  heavy: ["KeyK"],
  taunt: ["KeyT"],
};

export interface Settings {
  masterVolume: number; // 0-1
  sfxVolume: number;
  musicVolume: number;
  musicOn: boolean;
  bindings: Bindings;
}

const KEY = "bonobo.settings";
const DEFAULTS: Settings = {
  masterVolume: AUDIO.master,
  sfxVolume: AUDIO.sfx,
  musicVolume: AUDIO.music,
  musicOn: true,
  bindings: DEFAULT_BINDINGS,
};

let current: Settings = load();
const listeners = new Set<(s: Settings) => void>();

function load(): Settings {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) ?? "{}");
    const s = { ...DEFAULTS };
    for (const k of ["masterVolume", "sfxVolume", "musicVolume", "musicOn"] as const) {
      if (typeof saved[k] === typeof DEFAULTS[k]) (s as Record<string, unknown>)[k] = saved[k];
    }
    // Tasti: si tengono solo le azioni salvate bene, le altre tornano al default
    const b = saved.bindings ?? {};
    s.bindings = Object.fromEntries(
      ACTIONS.map((a) => [a, Array.isArray(b[a]) && b[a].every((c: unknown) => typeof c === "string") ? b[a].slice(0, 3) : DEFAULT_BINDINGS[a]]),
    ) as Bindings;
    return s;
  } catch {
    return { ...DEFAULTS };
  }
}

export function getSettings(): Readonly<Settings> {
  return current;
}

export function updateSettings(patch: Partial<Settings>) {
  current = { ...current, ...patch };
  try {
    localStorage.setItem(KEY, JSON.stringify(current));
  } catch {
    // Archiviazione bloccata: le preferenze valgono solo per questa visita
  }
  for (const l of listeners) l(current);
}

export function onSettingsChange(listener: (s: Settings) => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function resetSettings() {
  updateSettings({ ...DEFAULTS });
}
