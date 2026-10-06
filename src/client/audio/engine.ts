import { getSettings, onSettingsChange } from "../settings";

// Il motore audio: un AudioContext con tre volumi in cascata (generale → effetti / musica).
// I browser lo tengono muto finché chi gioca non preme un tasto o clicca: lo sblocchiamo lì.

export interface AudioBus {
  ctx: AudioContext;
  sfx: GainNode;
  music: GainNode;
}

let bus: AudioBus | null = null;

export function getBus(): AudioBus | null {
  return bus;
}

function create(): AudioBus | null {
  const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctx) return null;
  const ctx = new Ctx();
  const master = ctx.createGain();
  // Un compressore evita che tanti colpi insieme gracchino
  const comp = ctx.createDynamicsCompressor();
  master.connect(comp).connect(ctx.destination);
  const sfx = ctx.createGain();
  const music = ctx.createGain();
  sfx.connect(master);
  music.connect(master);
  const apply = () => {
    const s = getSettings();
    master.gain.value = s.masterVolume;
    sfx.gain.value = s.sfxVolume;
    music.gain.value = s.musicOn ? s.musicVolume : 0;
  };
  apply();
  onSettingsChange(apply);
  return { ctx, sfx, music };
}

// Da chiamare una volta all'avvio: il contesto nasce e si sblocca al primo gesto
export function setupAudioUnlock(onReady?: (bus: AudioBus) => void) {
  const unlock = () => {
    if (!bus) bus = create();
    if (!bus) return;
    if (bus.ctx.state === "suspended") void bus.ctx.resume();
    window.removeEventListener("keydown", unlock);
    window.removeEventListener("pointerdown", unlock);
    onReady?.(bus);
  };
  window.addEventListener("keydown", unlock);
  window.addEventListener("pointerdown", unlock);
}
