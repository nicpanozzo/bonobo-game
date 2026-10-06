import { AUDIO } from "../shared/constants";

// Preferenze di chi gioca, salvate nel browser. Le opzioni (menu) le cambiano,
// il resto del client le legge con getSettings() e ascolta i cambi con onSettingsChange().

export interface Settings {
  masterVolume: number; // 0-1
  sfxVolume: number;
  musicVolume: number;
  musicOn: boolean;
}

const KEY = "bonobo.settings";
const DEFAULTS: Settings = {
  masterVolume: AUDIO.master,
  sfxVolume: AUDIO.sfx,
  musicVolume: AUDIO.music,
  musicOn: true,
};

let current: Settings = load();
const listeners = new Set<(s: Settings) => void>();

function load(): Settings {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) ?? "{}");
    const s = { ...DEFAULTS };
    for (const k of Object.keys(DEFAULTS) as (keyof Settings)[]) {
      if (typeof saved[k] === typeof DEFAULTS[k]) (s as Record<string, unknown>)[k] = saved[k];
    }
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
